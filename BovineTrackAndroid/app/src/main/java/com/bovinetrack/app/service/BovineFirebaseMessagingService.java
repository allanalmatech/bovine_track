package com.bovinetrack.app.service;

import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;

import androidx.core.app.NotificationCompat;

import com.bovinetrack.app.BovineTrackApp;
import com.bovinetrack.app.R;
import com.bovinetrack.app.data.DevicePreferences;
import com.bovinetrack.app.ui.server.AlertsActivity;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

public class BovineFirebaseMessagingService extends FirebaseMessagingService {
    @Override
    public void onNewToken(String token) {
        DevicePreferences preferences = new DevicePreferences(this);
        String url = preferences.getFirebaseUrl();
        if (url == null || url.isEmpty()) {
            return;
        }
        try {
            FirebaseDatabase.getInstance(url)
                    .getReference("deviceTokens")
                    .child(preferences.getDeviceId())
                    .setValue(token);
        } catch (Exception ignored) {
        }
    }

    @Override
    public void onMessageReceived(RemoteMessage message) {
        String title = "BovineTrack Alert";
        String body = "Boundary violation detected";

        if (message.getNotification() != null) {
            if (message.getNotification().getTitle() != null) {
                title = message.getNotification().getTitle();
            }
            if (message.getNotification().getBody() != null) {
                body = message.getNotification().getBody();
            }
        }
        if (message.getData().containsKey("title")) {
            title = message.getData().get("title");
        }
        if (message.getData().containsKey("body")) {
            body = message.getData().get("body");
        }

        Intent intent = new Intent(this, AlertsActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                this,
                31,
                intent,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
        );

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, BovineTrackApp.ALERT_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body));

        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            manager.notify((int) System.currentTimeMillis(), builder.build());
        }
    }
}
