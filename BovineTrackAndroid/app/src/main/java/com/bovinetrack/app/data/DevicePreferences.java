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
    private static final String KEY_LAST_LOCATION_TIMESTAMP = "last_location_timestamp";
    private static final String KEY_KALMAN_LAT_EST = "kalman_lat_est";
    private static final String KEY_KALMAN_LAT_COV = "kalman_lat_cov";
    private static final String KEY_KALMAN_LNG_EST = "kalman_lng_est";
    private static final String KEY_KALMAN_LNG_COV = "kalman_lng_cov";
    private static final String KEY_KALMAN_LAST_TS = "kalman_last_ts";
    private static final long STALE_LOCATION_THRESHOLD_MS = 120_000L;

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

    public void setLastLocationTimestamp(long timestamp) {
        sharedPreferences.edit().putLong(KEY_LAST_LOCATION_TIMESTAMP, timestamp).apply();
    }

    public long getLastLocationTimestamp() {
        return sharedPreferences.getLong(KEY_LAST_LOCATION_TIMESTAMP, 0L);
    }

    public boolean isFirstLocationSinceReboot() {
        return getLastLocationTimestamp() == 0L;
    }

    public boolean isLocationStale(long timestamp) {
        if (timestamp <= 0) {
            return true;
        }
        long lastTs = getLastLocationTimestamp();
        if (lastTs == 0L) {
            return false;
        }
        return (timestamp - lastTs) > STALE_LOCATION_THRESHOLD_MS;
    }

    public void saveKalmanState(double latEst, double latCov, double lngEst, double lngCov, long lastTs) {
        sharedPreferences.edit()
                .putLong(KEY_KALMAN_LAST_TS, lastTs)
                .putFloat(KEY_KALMAN_LAT_EST, (float) latEst)
                .putFloat(KEY_KALMAN_LAT_COV, (float) latCov)
                .putFloat(KEY_KALMAN_LNG_EST, (float) lngEst)
                .putFloat(KEY_KALMAN_LNG_COV, (float) lngCov)
                .apply();
    }

    public KalmanState loadKalmanState() {
        long lastTs = sharedPreferences.getLong(KEY_KALMAN_LAST_TS, 0L);
        if (lastTs == 0L) {
            return new KalmanState(false, 0, 0, 0, 0, 0);
        }
        return new KalmanState(true,
                sharedPreferences.getFloat(KEY_KALMAN_LAT_EST, 0f),
                sharedPreferences.getFloat(KEY_KALMAN_LAT_COV, 1f),
                sharedPreferences.getFloat(KEY_KALMAN_LNG_EST, 0f),
                sharedPreferences.getFloat(KEY_KALMAN_LNG_COV, 1f),
                lastTs);
    }

    public static class KalmanState {
        public final boolean initialized;
        public final double latEstimate, latCovariance;
        public final double lngEstimate, lngCovariance;
        public final long lastTimestamp;

        public KalmanState(boolean initialized, double latEstimate, double latCovariance,
                           double lngEstimate, double lngCovariance, long lastTimestamp) {
            this.initialized = initialized;
            this.latEstimate = latEstimate;
            this.latCovariance = latCovariance;
            this.lngEstimate = lngEstimate;
            this.lngCovariance = lngCovariance;
            this.lastTimestamp = lastTimestamp;
        }
    }
}
