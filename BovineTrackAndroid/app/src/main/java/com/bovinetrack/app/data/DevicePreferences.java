package com.bovinetrack.app.data;

import android.content.Context;
import android.content.SharedPreferences;

import com.bovinetrack.app.model.DeviceRole;

public class DevicePreferences {
    private static final String PREF = "bovinetrack_prefs";
    private static final String KEY_ROLE = "role";
    private static final String KEY_DEVICE_ID = "device_id";
    private static final String KEY_FIREBASE_URL = "firebase_url";
    private static final String KEY_FIRST_LAUNCH_DONE = "first_launch_done";
    private static final String KEY_TRACKING_ENABLED = "tracking_enabled";
    private static final String KEY_ACCESSIBILITY_MODE = "accessibility_mode";
    private static final String KEY_ZONE_STATE_PREFIX = "zone_state_";

    private final SharedPreferences sharedPreferences;

    public DevicePreferences(Context context) {
        sharedPreferences = context.getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    public void saveRole(DeviceRole role) {
        sharedPreferences.edit().putString(KEY_ROLE, role.name()).apply();
    }

    public DeviceRole getRole() {
        String value = sharedPreferences.getString(KEY_ROLE, null);
        if (value == null) {
            return null;
        }
        return DeviceRole.valueOf(value);
    }

    public String getDeviceId() {
        return sharedPreferences.getString(KEY_DEVICE_ID, "device-" + android.os.Build.MODEL.replace(" ", "-"));
    }

    public void setDeviceId(String deviceId) {
        sharedPreferences.edit().putString(KEY_DEVICE_ID, deviceId.trim()).apply();
    }

    public String getFirebaseUrl() {
        return sharedPreferences.getString(KEY_FIREBASE_URL, "");
    }

    public void setFirebaseUrl(String url) {
        sharedPreferences.edit().putString(KEY_FIREBASE_URL, url.trim()).apply();
    }

    public boolean isFirstLaunchDone() {
        return sharedPreferences.getBoolean(KEY_FIRST_LAUNCH_DONE, false);
    }

    public void setFirstLaunchDone(boolean done) {
        sharedPreferences.edit().putBoolean(KEY_FIRST_LAUNCH_DONE, done).apply();
    }

    public boolean isTrackingEnabled() {
        return sharedPreferences.getBoolean(KEY_TRACKING_ENABLED, false);
    }

    public void setTrackingEnabled(boolean enabled) {
        sharedPreferences.edit().putBoolean(KEY_TRACKING_ENABLED, enabled).apply();
    }

    public boolean isAccessibilityModeEnabled() {
        return sharedPreferences.getBoolean(KEY_ACCESSIBILITY_MODE, false);
    }

    public void setAccessibilityModeEnabled(boolean enabled) {
        sharedPreferences.edit().putBoolean(KEY_ACCESSIBILITY_MODE, enabled).apply();
    }

    public Boolean getLastZoneInsideState(String deviceId, long zoneId) {
        String key = zoneStateKey(deviceId, zoneId);
        if (!sharedPreferences.contains(key)) {
            return null;
        }
        return sharedPreferences.getBoolean(key, false);
    }

    public void setLastZoneInsideState(String deviceId, long zoneId, boolean inside) {
        sharedPreferences.edit().putBoolean(zoneStateKey(deviceId, zoneId), inside).apply();
    }

    private String zoneStateKey(String deviceId, long zoneId) {
        return KEY_ZONE_STATE_PREFIX + deviceId + "_" + zoneId;
    }
}
