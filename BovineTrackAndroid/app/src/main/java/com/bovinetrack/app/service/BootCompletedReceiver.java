package com.bovinetrack.app.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import com.bovinetrack.app.data.DevicePreferences;
import com.bovinetrack.app.data.LocationRepository;

public class BootCompletedReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) {
            return;
        }
        String action = intent.getAction();
        boolean bootLike = Intent.ACTION_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_LOCKED_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action);
        if (!bootLike) {
            return;
        }

        DevicePreferences preferences = new DevicePreferences(context);
        LocationRepository.get(context).reRegisterGeofenceMonitoring();
        if (!preferences.isTrackingEnabled()) {
            return;
        }

        Intent start = new Intent(context, TrackingService.class);
        start.putExtra(TrackingService.EXTRA_SIMULATION, false);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(start);
        } else {
            context.startService(start);
        }
    }
}
