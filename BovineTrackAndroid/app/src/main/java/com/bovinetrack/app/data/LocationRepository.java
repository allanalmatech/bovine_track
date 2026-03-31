package com.bovinetrack.app.data;

import android.content.Context;

import androidx.lifecycle.LiveData;

import com.bovinetrack.app.data.local.AppDatabase;
import com.bovinetrack.app.data.local.entity.AlertEntity;
import com.bovinetrack.app.data.local.entity.GeofenceZoneEntity;
import com.bovinetrack.app.data.local.entity.LocationEntity;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class LocationRepository {
    private static volatile LocationRepository instance;

    private final AppDatabase db;
    private final DevicePreferences preferences;
    private final WearSyncClient wearSyncClient;
    private final ExecutorService io;

    private LocationRepository(Context context) {
        db = AppDatabase.get(context);
        preferences = new DevicePreferences(context);
        wearSyncClient = new WearSyncClient(context);
        io = Executors.newSingleThreadExecutor();
    }

    public static LocationRepository get(Context context) {
        if (instance == null) {
            synchronized (LocationRepository.class) {
                if (instance == null) {
                    instance = new LocationRepository(context.getApplicationContext());
                }
            }
        }
        return instance;
    }

    public LiveData<LocationEntity> observeLatestSelf() {
        return db.locationDao().observeLatest(preferences.getDeviceId());
    }

    public LiveData<List<LocationEntity>> observeRecentSelf() {
        return db.locationDao().observeRecent(preferences.getDeviceId());
    }

    public LiveData<List<LocationEntity>> observeRecentFleet() {
        return db.locationDao().observeLatestPerDevice();
    }

    public LiveData<List<AlertEntity>> observeAlerts() {
        return db.alertDao().observeRecent();
    }

    public LiveData<Integer> observeAlertCountToday() {
        return db.alertDao().countSince(System.currentTimeMillis() - 1000L * 60L * 60L * 24L);
    }

    public LiveData<List<GeofenceZoneEntity>> observeZones() {
        return db.zoneDao().observeAll();
    }

    public void saveZone(GeofenceZoneEntity zone) {
        io.execute(() -> db.zoneDao().insert(zone));
    }

    public void saveLocation(LocationEntity location) {
        io.execute(() -> {
            long id = db.locationDao().insert(location);
            maybeSyncLocation(location, id);
            wearSyncClient.publishLatestLocation(
                    location.deviceId,
                    location.latitude,
                    location.longitude,
                    location.timestamp,
                    location.battery
            );
            List<GeofenceZoneEntity> zones = db.zoneDao().getAll();
            Map<Long, Boolean> previous = new HashMap<>();
            for (GeofenceZoneEntity zone : zones) {
                Boolean state = preferences.getLastZoneInsideState(location.deviceId, zone.id);
                if (state != null) {
                    previous.put(zone.id, state);
                }
            }
            GeofenceEngine.GeofenceEvaluation evaluation = GeofenceEngine.evaluateCrossings(location, zones, previous);
            for (Map.Entry<Long, Boolean> entry : evaluation.zoneInsideState.entrySet()) {
                preferences.setLastZoneInsideState(location.deviceId, entry.getKey(), entry.getValue());
            }
            for (String violation : evaluation.alerts) {
                AlertEntity alert = new AlertEntity();
                alert.deviceId = location.deviceId;
                alert.type = "GEOFENCE";
                alert.message = violation;
                alert.latitude = location.latitude;
                alert.longitude = location.longitude;
                alert.timestamp = System.currentTimeMillis();
                db.alertDao().insert(alert);
                pushBoundaryAlert(location.deviceId, violation, location.latitude, location.longitude, alert.timestamp);
            }
        });
    }

    public void addAlert(String deviceId, String type, String message, double lat, double lng) {
        io.execute(() -> {
            AlertEntity alert = new AlertEntity();
            alert.deviceId = deviceId;
            alert.type = type;
            alert.message = message;
            alert.latitude = lat;
            alert.longitude = lng;
            alert.timestamp = System.currentTimeMillis();
            db.alertDao().insert(alert);
        });
    }

    public void loadHistoryPage(String deviceId, long beforeTimestamp, int limit, HistoryPageCallback callback) {
        io.execute(() -> {
            List<LocationEntity> page = db.locationDao().loadHistoryPage(deviceId, beforeTimestamp, limit);
            callback.onLoaded(page);
        });
    }

    public void syncMessagingToken() {
        String url = preferences.getFirebaseUrl();
        if (url == null || url.isEmpty()) {
            return;
        }
        FirebaseMessaging.getInstance().getToken().addOnSuccessListener(token -> {
            if (token == null || token.isEmpty()) {
                return;
            }
            io.execute(() -> {
                try {
                    FirebaseDatabase.getInstance(url)
                            .getReference("deviceTokens")
                            .child(preferences.getDeviceId())
                            .setValue(token);
                } catch (Exception ignored) {
                }
            });
        });
    }

    public void reRegisterGeofenceMonitoring() {
        io.execute(() -> {
            List<GeofenceZoneEntity> zones = db.zoneDao().getAll();
            for (GeofenceZoneEntity zone : zones) {
                String deviceId = preferences.getDeviceId();
                Boolean state = preferences.getLastZoneInsideState(deviceId, zone.id);
                if (state == null) {
                    preferences.setLastZoneInsideState(deviceId, zone.id, false);
                }
            }
        });
    }

    public void syncPending() {
        io.execute(() -> {
            List<LocationEntity> pending = db.locationDao().pendingSync();
            for (LocationEntity location : pending) {
                if (pushToFirebase(location)) {
                    db.locationDao().markSynced(location.id);
                }
            }
        });
    }

    private void maybeSyncLocation(LocationEntity location, long id) {
        boolean ok = pushToFirebase(location);
        if (ok) {
            db.locationDao().markSynced(id);
        }
    }

    private boolean pushToFirebase(LocationEntity location) {
        String url = preferences.getFirebaseUrl();
        if (url == null || url.isEmpty()) {
            return false;
        }
        try {
            FirebaseDatabase database = FirebaseDatabase.getInstance(url);
            DatabaseReference ref = database.getReference("devices")
                    .child(location.deviceId)
                    .child("history")
                    .push();

            Map<String, Object> payload = new HashMap<>();
            payload.put("deviceId", location.deviceId);
            payload.put("lat", location.latitude);
            payload.put("lng", location.longitude);
            payload.put("speed", location.speed);
            payload.put("timestamp", location.timestamp);
            payload.put("battery", location.battery);
            payload.put("simulated", location.simulated);

            ref.setValue(payload);
            database.getReference("devices").child(location.deviceId).child("latest").setValue(payload);
            return true;
        } catch (Exception ex) {
            return false;
        }
    }

    private void pushBoundaryAlert(String deviceId, String message, double lat, double lng, long timestamp) {
        String url = preferences.getFirebaseUrl();
        if (url == null || url.isEmpty()) {
            return;
        }
        try {
            FirebaseDatabase database = FirebaseDatabase.getInstance(url);
            DatabaseReference ref = database.getReference("boundaryAlerts").push();
            Map<String, Object> payload = new HashMap<>();
            payload.put("deviceId", deviceId);
            payload.put("message", message);
            payload.put("lat", lat);
            payload.put("lng", lng);
            payload.put("timestamp", timestamp);
            payload.put("priority", "high");
            ref.setValue(payload);
        } catch (Exception ignored) {
        }
    }

    public interface HistoryPageCallback {
        void onLoaded(List<LocationEntity> page);
    }
}
