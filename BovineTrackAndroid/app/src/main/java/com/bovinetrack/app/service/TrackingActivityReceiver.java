package com.bovinetrack.app.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.google.android.gms.location.ActivityRecognitionResult;
import com.google.android.gms.location.DetectedActivity;

public class TrackingActivityReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !ActivityRecognitionResult.hasResult(intent)) {
            return;
        }
        ActivityRecognitionResult result = ActivityRecognitionResult.extractResult(intent);
        if (result == null) {
            return;
        }
        DetectedActivity probable = result.getMostProbableActivity();
        if (probable == null) {
            return;
        }
        TrackingService.TrackingStateStore.updateActivity(probable.getType(), probable.getConfidence());
    }
}
