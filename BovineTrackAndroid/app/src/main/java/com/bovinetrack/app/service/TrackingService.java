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
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;

import java.util.Random;

public class TrackingService extends Service {
    public static final String EXTRA_SIMULATION = "simulation";

    private FusedLocationProviderClient fusedClient;
    private LocationRepository repository;
    private DevicePreferences prefs;
    private LocationCallback callback;
    private boolean simulation;
    private final Handler simulationHandler = new Handler(Looper.getMainLooper());
    private int simulationTick = 0;

    @Override
    public void onCreate() {
        super.onCreate();
        fusedClient = LocationServices.getFusedLocationProviderClient(this);
        repository = LocationRepository.get(this);
        prefs = new DevicePreferences(this);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        simulation = intent != null && intent.getBooleanExtra(EXTRA_SIMULATION, false);
        startForeground(7, buildNotification("Tracking active"));

        if (simulation) {
            startSimulation();
        } else {
            requestLocationUpdates();
        }

        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (callback != null) {
            fusedClient.removeLocationUpdates(callback);
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

        LocationRequest request = new LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10_000L)
                .setMinUpdateDistanceMeters(10f)
                .build();

        callback = new LocationCallback() {
            @Override
            public void onLocationResult(LocationResult locationResult) {
                Location location = locationResult.getLastLocation();
                if (location != null) {
                    persistLocation(location, false);
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
        LocationEntity entity = new LocationEntity();
        entity.deviceId = prefs.getDeviceId();
        entity.latitude = location.getLatitude();
        entity.longitude = location.getLongitude();
        entity.speed = location.getSpeed();
        entity.timestamp = System.currentTimeMillis();
        entity.battery = readBatteryPercent();
        entity.simulated = isSimulated;
        entity.synced = false;

        repository.saveLocation(entity);
        repository.syncPending();
        if (entity.battery <= 15) {
            repository.addAlert(entity.deviceId, "BATTERY", "Low battery detected", entity.latitude, entity.longitude);
            dispatchAlertNotification("Low battery", "Device " + entity.deviceId + " battery at " + entity.battery + "%");
        }
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
}
