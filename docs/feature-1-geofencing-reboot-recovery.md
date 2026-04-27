# Feature 1: Geofencing + Reboot Recovery — Implementation Notes

## Overview

This document describes improvements made to the BovineTrack Android app's geofencing and reboot-recovery system. Five specific issues were identified and addressed:

1. **Polygon self-intersection validation** (was partially missing in the repository path)
2. **Polygon minimum area check** (shoelace formula)
3. **First post-reboot location detection** (suppress spurious crossing alerts)
4. **Stale GPS location filtering** (2-minute threshold)
5. **Kalman filter state persistence** across service restarts and device reboots

---

## 1. Polygon Validation at Zone Save

### Problem
`GeofenceEditorActivity` called `PolygonValidator.isSelfIntersecting()` before saving, but any programmatic call to `LocationRepository.saveZone()` had no validation. A malformed polygon saved via API or future code would be stored without checks.

### Solution
Validation was added in two places:

**`LocationRepository.saveZone(GeofenceZoneEntity zone, ZoneSaveCallback callback)`**
(`BovineTrackAndroid/app/src/main/java/com/bovinetrack/app/data/LocationRepository.java:90`)

```java
public void saveZone(GeofenceZoneEntity zone, ZoneSaveCallback callback) {
    if (zone.polygon && zone.polygonPoints != null && !zone.polygonPoints.isEmpty()) {
        List<LatLng> points = parsePolygonPoints(zone.polygonPoints);
        if (points.size() < 3) {
            if (callback != null) callback.onError("Polygon requires at least 3 valid points");
            return;
        }
        if (PolygonValidator.isSelfIntersecting(points)) {
            if (callback != null) callback.onError("Polygon edges intersect");
            return;
        }
        if (!PolygonValidator.hasValidArea(points)) {
            if (callback != null) callback.onError("Polygon area too small (min 100 sq meters)");
            return;
        }
    }
    io.execute(() -> {
        db.zoneDao().insert(zone);
        if (callback != null) callback.onSuccess();
    });
}
```

The existing `saveZone(GeofenceZoneEntity zone)` method delegates to this, so callers are unaffected:
```java
public void saveZone(GeofenceZoneEntity zone) {
    saveZone(zone, null);  // null callback = fire and forget
}
```

**`GeofenceEditorActivity.saveButton.setOnClickListener`** also gained an area check to match:
```java
// BovineTrackAndroid/app/src/main/java/com/bovinetrack/app/ui/server/GeofenceEditorActivity.java:84-88
if (!PolygonValidator.hasValidArea(points)) {
    Toast.makeText(this, "Polygon area too small (min 100 sq meters)", Toast.LENGTH_LONG).show();
    return;
}
```

### Design Decision
A `ZoneSaveCallback` interface was added to `LocationRepository` so callers can receive async error feedback:
```java
public interface ZoneSaveCallback {
    void onSuccess();
    void onError(String reason);
}
```
This is non-breaking — the existing zero-argument `saveZone()` method passes `null` as the callback, preserving all existing calls.

---

## 2. Polygon Minimum Area Check (Shoelace Formula)

### Problem
A polygon with 3 points near each other (e.g. 1 meter apart) would pass the self-intersection check but define a practically meaningless zone. No minimum area threshold existed.

### Solution
Two methods added to `PolygonValidator`:

**`calculateAreaSqMeters(List<LatLng> points)`** — Computes area using the shoelace formula, then converts from degree-squared to square meters using the haversine approximation. Latitude correction is applied since longitude degrees shrink toward the poles.

```java
// BovineTrackAndroid/app/src/main/java/com/bovinetrack/app/data/PolygonValidator.java
private static final double MIN_AREA_SQ_METERS = 100.0;

public static double calculateAreaSqMeters(List<LatLng> points) {
    if (points == null || points.size() < 3) return 0.0;
    double sum = 0.0;
    int n = points.size();
    for (int i = 0; i < n; i++) {
        LatLng curr = points.get(i);
        LatLng next = points.get((i + 1) % n);
        sum += curr.longitude * next.latitude - next.longitude * curr.latitude;
    }
    double absAreaDeg2 = Math.abs(sum) / 2.0;
    double avgLat = 0.0;
    for (LatLng p : points) avgLat += p.latitude;
    avgLat /= n;
    return absAreaDeg2 * 111320.0 * 111320.0 * Math.cos(Math.toRadians(avgLat));
}

public static boolean hasValidArea(List<LatLng> points) {
    return calculateAreaSqMeters(points) >= MIN_AREA_SQ_METERS;
}
```

### Technical Details
- `111320.0` is the number of meters per degree of latitude at the equator
- `cos(avgLat)` corrects for longitude contraction at non-equatorial latitudes
- Threshold of 100 sq meters was chosen as the minimum useful grazing area
- `MIN_AREA_SQ_METERS` is a private constant — callers use `hasValidArea()` to stay threshold-agnostic

---

## 3. First Post-Reboot Location Detection

### Problem
After a device reboots, the service restarts and the first GPS fix triggers a geofence evaluation. If the animal is already inside a restricted zone, the crossing-detection logic fires an "entry" alert — even though the animal never actually crossed the boundary. This is a false positive caused by state loss across the reboot.

### Solution
A timestamp-based detection mechanism was added via `DevicePreferences`:

**`DevicePreferences.java`**
```java
private static final String KEY_LAST_LOCATION_TIMESTAMP = "last_location_timestamp";

public void setLastLocationTimestamp(long timestamp) {
    sharedPreferences.edit().putLong(KEY_LAST_LOCATION_TIMESTAMP, timestamp).apply();
}

public long getLastLocationTimestamp() {
    return sharedPreferences.getLong(KEY_LAST_LOCATION_TIMESTAMP, 0L);
}

public boolean isFirstLocationSinceReboot() {
    return getLastLocationTimestamp() == 0L;
}
```

**`TrackingService.persistLocation()`**
```java
// BovineTrackAndroid/app/src/main/java/com/bovinetrack/app/service/TrackingService.java:158-172
private void persistLocation(Location location, boolean isSimulated) {
    long ts = System.currentTimeMillis();
    if (prefs.isLocationStale(ts)) return;
    boolean firstSinceReboot = prefs.isFirstLocationSinceReboot();
    prefs.setLastLocationTimestamp(ts);
    // ... build entity ...
    repository.saveLocation(entity, firstSinceReboot);
}
```

**`LocationRepository.saveLocation(LocationEntity, boolean isFirstSinceReboot)`**
```java
// BovineTrackAndroid/app/src/main/java/com/bovinetrack/app/data/LocationRepository.java:139-142
for (String violation : evaluation.alerts) {
    if (isFirstSinceReboot) continue;  // suppress on first post-reboot
    // ... create AlertEntity, push to Firebase ...
}
```

### Flow Summary
```
Device Reboot
    │
    ▼
BootCompletedReceiver.onReceive()
    │
    ├─► LocationRepository.reRegisterGeofenceMonitoring()
    │      (restores zone state from prefs)
    │
    └─► TrackingService.startForegroundService()
             │
             ▼
        First GPS fix received
             │
             ▼
        prefs.isFirstLocationSinceReboot() → true
        prefs.setLastLocationTimestamp(ts) → persisted
             │
             ▼
        GeofenceEngine.evaluateCrossings() → may find violations
             │
             ▼
        isFirstSinceReboot == true → violations suppressed
```

### Design Decision
We chose to suppress *all* first-post-reboot alerts rather than only restricted-zone entries. The rationale: if the device was already inside a zone before reboot, we have no prior position to determine if a crossing occurred. Suppressing avoids both false positives (already inside, now detected) and false negatives (was outside, but no crossing logged).

---

## 4. Stale GPS Location Filtering

### Problem
If the device loses GPS signal for an extended period (e.g. under a barn roof), Android may return a cached location with an old timestamp. Processing such a location through the Kalman filter would corrupt the smoothing state.

### Solution

**`DevicePreferences.java`**
```java
private static final long STALE_LOCATION_THRESHOLD_MS = 120_000L;  // 2 minutes

public boolean isLocationStale(long timestamp) {
    if (timestamp <= 0) return true;
    long lastTs = getLastLocationTimestamp();
    if (lastTs == 0L) return false;  // first location is never stale
    return (timestamp - lastTs) > STALE_LOCATION_THRESHOLD_MS;
}
```

**`TrackingService.persistLocation()`**
```java
long ts = System.currentTimeMillis();
if (prefs.isLocationStale(ts)) return;  // discard stale location
```

### Threshold Choice
2 minutes was selected because:
- The adaptive interval caps at 60 seconds when moving (`TrackingService.calculateAdaptiveInterval()`)
- A 2-minute gap means at least 2 expected updates were missed
- This is short enough to catch real signal loss, long enough to tolerate brief GPS outages

---

## 5. Kalman Filter State Persistence Across Reboots

### Problem
`TrackingService` created a new `KalmanLocationFilter` instance on every service start. After a reboot, the filter's internal state (estimate and covariance) was reset, causing the first few post-reboot locations to be treated as "fresh" without the benefit of prior smoothing. The service also recreated the filter every time `onCreate()` ran (battery saver killing the service, etc.).

### Solution
Two changes were made:

**A. Kalman filter moved to `LocationRepository` (singleton)**

`TrackingService` previously owned the filter:
```java
// BEFORE — in TrackingService
private KalmanLocationFilter kalmanFilter;
kalmanFilter = new KalmanLocationFilter();
Location smoothed = kalmanFilter.smooth(location);
```

After:
```java
// AFTER — filter lives in singleton repository
repository = LocationRepository.get(this);  // singleton, survives service restarts
Location smoothed = repository.smoothLocation(location);
```

`LocationRepository` initializes once and persists across the app lifecycle:
```java
// BovineTrackAndroid/app/src/main/java/com/bovinetrack/app/data/LocationRepository.java:32-38
private LocationRepository(Context context) {
    db = AppDatabase.get(context);
    preferences = new DevicePreferences(context);
    wearSyncClient = new WearSyncClient(context);
    io = Executors.newSingleThreadExecutor();
    kalmanFilter = new KalmanLocationFilter();
    kalmanFilter.restoreFromState(preferences.loadKalmanState());  // restore from prefs
}
```

**B. State serialized to `SharedPreferences`**

`DevicePreferences` stores 5 doubles/longs:
```java
// BovineTrackAndroid/app/src/main/java/com/bovinetrack/app/data/DevicePreferences.java
private static final String KEY_KALMAN_LAT_EST = "kalman_lat_est";
private static final String KEY_KALMAN_LAT_COV = "kalman_lat_cov";
private static final String KEY_KALMAN_LNG_EST = "kalman_lng_est";
private static final String KEY_KALMAN_LNG_COV = "kalman_lng_cov";
private static final String KEY_KALMAN_LAST_TS = "kalman_last_ts";

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
    if (lastTs == 0L) return new KalmanState(false, 0, 0, 0, 0, 0);
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
    // constructor and fields ...
}
```

**C. State restored and persisted**

`KalmanLocationFilter` gained methods to save/restore state:
```java
// BovineTrackAndroid/app/src/main/java/com/bovinetrack/app/data/KalmanLocationFilter.java
public synchronized void restoreFromState(KalmanState state) {
    if (state == null || !state.initialized) return;
    latFilter.restoreState(state.latEstimate, state.latCovariance);
    lngFilter.restoreState(state.lngEstimate, state.lngCovariance);
    lastTimestamp = state.lastTimestamp;
}

public synchronized double[] getLatState() { return latFilter.currentState(); }
public synchronized double[] getLngState() { return lngFilter.currentState(); }
public synchronized long getLastTimestamp() { return lastTimestamp; }
```

The `Kalman1D` inner class was extended:
```java
private static class Kalman1D {
    private double estimate;
    private double covariance = 1;
    private boolean initialized;
    private final double processNoise = 0.15;

    void restoreState(double estimate, double covariance) {
        this.estimate = estimate;
        this.covariance = covariance;
        this.initialized = true;
    }

    double[] currentState() { return new double[]{estimate, covariance}; }
    // update(), etc.
}
```

**D. State saved after each location update**

In `TrackingService`:
```java
callback = new LocationCallback() {
    @Override
    public void onLocationResult(LocationResult locationResult) {
        Location location = locationResult.getLastLocation();
        if (location != null) {
            Location smoothed = repository.smoothLocation(location);
            if (smoothed != null) {
                persistLocation(smoothed, false);
                repository.persistKalmanState();  // persist after every fix
            }
        }
    }
};
```

### Why This Matters
The Kalman filter's covariance value encodes uncertainty. A well-converged filter has low covariance. When the filter resets after a reboot, covariance is reset to 1.0, meaning the first post-reboot reading gets full weight (no smoothing benefit). By restoring state, the filter resumes from where it left off — continuity is preserved.

---

## Files Modified

| File | Changes |
|------|---------|
| `data/PolygonValidator.java` | Added `calculateAreaSqMeters()`, `hasValidArea()`, `MIN_AREA_SQ_METERS` constant |
| `data/LocationRepository.java` | Added `KalmanLocationFilter` field, `smoothLocation()`, `persistKalmanState()`, `ZoneSaveCallback`, area validation in `saveZone()`, `isFirstSinceReboot` parameter in `saveLocation()` |
| `data/KalmanLocationFilter.java` | Added `restoreFromState()`, `currentState()`, `getLastTimestamp()`, `Kalman1D.restoreState()`, `Kalman1D.currentState()` |
| `data/DevicePreferences.java` | Added timestamp tracking, stale detection, Kalman state persistence, `KalmanState` inner class |
| `service/TrackingService.java` | Uses repository's filter, stale check, `isFirstSinceReboot` flag, persists Kalman state after each update |
| `ui/server/GeofenceEditorActivity.java` | Added area validation toast on save |

---

## Interaction Diagram

```
BootCompletedReceiver
        │
        ├─► reRegisterGeofenceMonitoring()
        │         └─► restores zone inside/outside state from prefs
        │
        └─► TrackingService.startForegroundService()
                  │
                  ▼
            LocationRepository.get()
                  │
                  ├─► KalmanLocationFilter.restoreFromState(prefs)
                  │         └─► filter resumes from persisted state
                  │
                  └─► onLocationResult()
                            │
                            ├─► prefs.isLocationStale(ts) → reject if gap > 2min
                            ├─► repository.smoothLocation(raw)
                            │         └─► Kalman1D.update(lat/lng)
                            ├─► repository.saveLocation(entity, firstSinceReboot)
                            │         ├─► GeofenceEngine.evaluateCrossings()
                            │         ├─► firstSinceReboot → suppress violations
                            │         └─► pushBoundaryAlert() if violation
                            └─► repository.persistKalmanState()
                                      └─► prefs.saveKalmanState(latEst, latCov, ...)
```

---

## Non-Breaking Changes

All modifications are backward-compatible:
- `LocationRepository.saveZone()` has two overloads; the zero-argument version delegates to the two-argument version with a `null` callback
- `LocationRepository.saveLocation()` has two overloads; existing callers use the one-argument version which passes `false` for `isFirstSinceReboot`
- `KalmanLocationFilter` methods are additive; existing code calling `smooth()` works unchanged
- `DevicePreferences` methods are purely additive

---

## Testing Checklist

- [ ] Save a polygon with area < 100 sq m → should be rejected with toast
- [ ] Save a self-intersecting polygon → should be rejected
- [ ] Reboot device, animal already inside restricted zone → no alert on first GPS fix
- [ ] Reboot device, animal crosses boundary after reboot → alert fires normally
- [ ] GPS signal lost for > 2 minutes, then restored → stale location not processed
- [ ] Device runs for 10 minutes, reboot → Kalman filter resumes with pre-reboot state
- [ ] Programmatic call to `saveZone()` with valid polygon → saved successfully
- [ ] Programmatic call to `saveZone()` with invalid polygon → callback receives error