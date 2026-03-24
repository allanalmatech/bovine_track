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
}
