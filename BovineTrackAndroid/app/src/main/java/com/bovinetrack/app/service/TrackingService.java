package com.bovinetrack.app.service;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.location.Location;
import android.os.BatteryManager;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;

import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;

import com.bovinetrack.app.BovineTrackApp;
import com.bovinetrack.app.R;
import com.bovinetrack.app.data.DevicePreferences;
import com.bovinetrack.app.data.LocationRepository;
import com.bovinetrack.app.data.local.entity.LocationEntity;
import com.bovinetrack.app.ui.client.ClientDashboardActivity;
import com.google.android.gms.location.ActivityRecognition;
import com.google.android.gms.location.ActivityRecognitionClient;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;
import com.google.android.gms.location.DetectedActivity;

import java.util.concurrent.atomic.AtomicInteger;

import java.util.Random;

public class TrackingService extends Service {
    public static final String EXTRA_SIMULATION = "simulation";
    private static final String ACTIVITY_UPDATE_ACTION = "com.bovinetrack.app.ACTIVITY_UPDATE";

    private FusedLocationProviderClient fusedClient;
    private ActivityRecognitionClient activityRecognitionClient;
    private LocationRepository repository;
    private DevicePreferences prefs;
    private LocationCallback callback;
    private boolean simulation;
    private final Handler simulationHandler = new Handler(Looper.getMainLooper());
    private int simulationTick = 0;
    private long currentIntervalMs = -1L;
    private PendingIntent activityIntent;

    @Override
    public void onCreate() {
        super.onCreate();
        fusedClient = LocationServices.getFusedLocationProviderClient(this);
        activityRecognitionClient = ActivityRecognition.getClient(this);
        repository = LocationRepository.get(this);
        prefs = new DevicePreferences(this);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        simulation = intent != null && intent.getBooleanExtra(EXTRA_SIMULATION, false);
        startForeground(7, buildNotification("Tracking active"));
        prefs.setTrackingEnabled(true);

        if (simulation) {
            startSimulation();
        } else {
            registerActivityRecognition();
            requestLocationUpdates();
        }

        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        prefs.setTrackingEnabled(false);
        if (callback != null) {
            fusedClient.removeLocationUpdates(callback);
        }
        if (activityRecognitionClient != null && activityIntent != null) {
            activityRecognitionClient.removeActivityUpdates(activityIntent);
        }
        simulationHandler.removeCallbacksAndMessages(null);
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void requestLocationUpdates() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            stopSelf();
            return;
        }

        long desiredInterval = calculateAdaptiveInterval();
        if (callback != null && currentIntervalMs == desiredInterval) {
            return;
        }
        currentIntervalMs = desiredInterval;
        if (callback != null) {
            fusedClient.removeLocationUpdates(callback);
        }

        LocationRequest request = new LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, desiredInterval)
                .setMinUpdateDistanceMeters(10f)
                .build();

        callback = new LocationCallback() {
            @Override
            public void onLocationResult(LocationResult locationResult) {
                Location location = locationResult.getLastLocation();
                if (location != null) {
                    Location smoothed = repository.smoothLocation(location);
                    if (smoothed != null) {
                        persistLocation(smoothed, false);
                        repository.persistKalmanState();
                    }
                    requestLocationUpdates();
                }
            }
        };

        fusedClient.requestLocationUpdates(request, callback, Looper.getMainLooper());
    }

    private void startSimulation() {
        Runnable loop = new Runnable() {
            @Override
            public void run() {
                double originLat = -1.2921;
                double originLng = 36.8219;
                double step = (simulationTick % 40) / 10000.0;
                Location fake = new Location("simulation");
                fake.setLatitude(originLat + step);
                fake.setLongitude(originLng + (step / 2));
                fake.setSpeed((new Random().nextInt(9) + 1));
                persistLocation(fake, true);
                simulationTick++;
                simulationHandler.postDelayed(this, 9000L);
            }
        };
        simulationHandler.post(loop);
    }

    private void persistLocation(Location location, boolean isSimulated) {
        long ts = System.currentTimeMillis();
        if (prefs.isLocationStale(ts)) {
            return;
        }
        boolean firstSinceReboot = prefs.isFirstLocationSinceReboot();
        prefs.setLastLocationTimestamp(ts);

        LocationEntity entity = new LocationEntity();
        entity.deviceId = prefs.getDeviceId();
        entity.latitude = location.getLatitude();
        entity.longitude = location.getLongitude();
        entity.speed = location.getSpeed();
        entity.timestamp = ts;
        entity.battery = readBatteryPercent();
        entity.simulated = isSimulated;
        entity.synced = false;

        repository.saveLocation(entity, firstSinceReboot);
        repository.syncMessagingToken();
        repository.syncPending();
        if (entity.battery <= 15) {
            repository.addAlert(entity.deviceId, "BATTERY", "Low battery detected", entity.latitude, entity.longitude);
            dispatchAlertNotification("Low battery", "Device " + entity.deviceId + " battery at " + entity.battery + "%");
        }
    }

    private void registerActivityRecognition() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED) {
            TrackingStateStore.setMoving(false, 0);
            return;
        }
        Intent intent = new Intent(this, TrackingActivityReceiver.class);
        intent.setAction(ACTIVITY_UPDATE_ACTION);
        activityIntent = PendingIntent.getBroadcast(
                this,
                44,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        activityRecognitionClient.requestActivityUpdates(20_000L, activityIntent);
    }

    private long calculateAdaptiveInterval() {
        if (simulation) {
            return 8_000L;
        }
        if (!TrackingStateStore.isMoving()) {
            return 60_000L;
        }
        return 12_000L;
    }

    private int readBatteryPercent() {
        BatteryManager bm = (BatteryManager) getSystemService(Context.BATTERY_SERVICE);
        if (bm == null) {
            return 0;
        }
        return bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
    }

    private Notification buildNotification(String content) {
        Intent open = new Intent(this, ClientDashboardActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 12, open, PendingIntent.FLAG_IMMUTABLE);

        return new NotificationCompat.Builder(this, BovineTrackApp.TRACKING_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentTitle("BovineTrack Client")
                .setContentText(content)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build();
    }

    private void dispatchAlertNotification(String title, String body) {
        Notification notification = new NotificationCompat.Builder(this, BovineTrackApp.ALERT_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .build();
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            manager.notify((int) System.currentTimeMillis(), notification);
        }
    }

    public static class TrackingStateStore {
        private static final AtomicInteger ACTIVITY_TYPE = new AtomicInteger(DetectedActivity.STILL);
        private static final AtomicInteger ACTIVITY_CONFIDENCE = new AtomicInteger(0);

        public static void updateActivity(int type, int confidence) {
            ACTIVITY_TYPE.set(type);
            ACTIVITY_CONFIDENCE.set(confidence);
        }

        public static void setMoving(boolean moving, int confidence) {
            ACTIVITY_TYPE.set(moving ? DetectedActivity.ON_FOOT : DetectedActivity.STILL);
            ACTIVITY_CONFIDENCE.set(confidence);
        }

        public static boolean isMoving() {
            int type = ACTIVITY_TYPE.get();
            int confidence = ACTIVITY_CONFIDENCE.get();
            if (confidence < 45) {
                return false;
            }
            return type == DetectedActivity.IN_VEHICLE
                    || type == DetectedActivity.ON_BICYCLE
                    || type == DetectedActivity.ON_FOOT
                    || type == DetectedActivity.RUNNING
                    || type == DetectedActivity.WALKING;
        }
    }
}
