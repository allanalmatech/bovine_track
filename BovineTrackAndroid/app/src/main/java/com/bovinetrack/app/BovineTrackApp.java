package com.bovinetrack.app;

import android.app.Application;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.os.Build;

public class BovineTrackApp extends Application {
    public static final String TRACKING_CHANNEL_ID = "tracking_channel";
    public static final String ALERT_CHANNEL_ID = "alert_channel";

    @Override
    public void onCreate() {
        super.onCreate();
        createChannels();
    }

    private void createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager manager = getSystemService(NotificationManager.class);
            NotificationChannel tracking = new NotificationChannel(
                    TRACKING_CHANNEL_ID,
                    getString(R.string.notif_channel_tracking),
                    NotificationManager.IMPORTANCE_LOW
            );
            NotificationChannel alert = new NotificationChannel(
                    ALERT_CHANNEL_ID,
                    getString(R.string.notif_channel_alerts),
                    NotificationManager.IMPORTANCE_HIGH
            );
            manager.createNotificationChannel(tracking);
            manager.createNotificationChannel(alert);
        }
    }
}
