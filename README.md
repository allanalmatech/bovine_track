# BovineTrack

BovineTrack is a real-time livestock intelligence platform for farmers and ranch managers. It combines continuous GPS tracking, geofence safety enforcement, rapid alerts, and map-based operational visibility across admin and field devices.

This repo contains:
- A Flutter app (`/lib`) used by admins and client trackers.
- A native Android module (`/BovineTrackAndroid`) with advanced tracking pipeline components (Kalman filtering, adaptive cadence, wearable sync, and high-volume rendering patterns).

---

## Pitch Summary

BovineTrack helps you answer three critical questions in seconds:
- Where is each cow right now?
- Is any cow outside safe boundaries?
- Where was that cow at a specific time?

It is designed for real farm operations, not demos: low-latency telemetry, boundary alerts, historical trace review, and operational dashboards with online status, network health, and battery visibility.

---

## Sample Login Accounts

- Admin: `admin@bovine.com` | `admin123`
- Client: `cow1@bovine.com` | `cow123`

---

## What We Implemented

### 1) Geofencing + reboot recovery
- Polygon and safe/restricted boundary logic with crossing detection.
- Boundary/track state restoration paths after device restart.

### 2) Background livestock tracking (Android-compliant)
- Continuous tracking flow with modern Android permissions.
- Client keeps publishing telemetry while app is not foregrounded (subject to OS/device policies).

### 3) Historical movement at scale
- Large-history strategy with paged retrieval and bounded rendering.
- Per-client timeline + map trace for "where was the cow at time T?" workflows.

### 4) Fast alert notifications
- Boundary violations are published immediately to Firebase.
- Local notifications for both admin/client-side alert flows.

### 5) Live map for many cattle
- Admin map renders all active tracked clients with realtime updates.
- Online/offline status is derived from live telemetry + status heartbeat fields.

### 6) Polygon geofence drawing and validation
- Farmer/admin can define polygon boundaries.
- Self-intersection validation to block invalid polygons.

### 7) Battery-efficient tracking
- Adaptive tracking cadence (faster while moving, slower while still).
- Heartbeat + motion-aware publishing for practical battery tradeoffs.

### 8) Wear OS companion sync architecture
- Handheld-to-wear snapshot sync path included in native module.

### 9) Accessibility and usability
- Accessible list-based monitoring alternative for low-vision users.
- TalkBack-friendly labels/content descriptions in key flows.

### 10) GPS filtering pipeline
- Kalman smoothing integrated before geofence decisions (native pipeline path).

---

## Realtime Data Used (Firebase RTDB)

- `users/{uid}`
- `adminClients/{adminUid}/{clientUid}`
- `adminDevices/{adminUid}/{deviceId}`
- `clientAssignments/{clientUid}`
- `boundaries/{adminUid}/{boundaryId}`
- `locations/{adminUid}/{clientUid}/{locationId}`
- `locationsLatest/{adminUid}/{clientUid}` or flat fallback paths
- `clientStatus/{adminUid}/{clientUid}` or flat fallback paths
- `alerts/{adminUid}/{alertId}`
- `deviceTokens/{uid}/{token}`

Status payloads include fields such as:
- `lat`, `lng`, `speed`, `accuracy`, `battery`, `network`, `lastSeen`, `clientTimestamp`, `online`, `sessionStartedAt`

---

## Build and Run

```bash
flutter pub get
flutter build apk --debug
flutter install --debug -d <device-id>
```

APK output:
- `build/app/outputs/flutter-apk/app-debug.apk`

---

## Firebase Setup Checklist

1. Enable Email/Password auth in Firebase Authentication.
2. Ensure app uses the intended Firebase project (`bovinetrack-a10c9`).
3. Ensure RTDB rules allow reads/writes for:
   - `adminClients`, `clientAssignments`, `locationsLatest`, `clientStatus`, `alerts`, `locations`.
4. Add index for history performance:
   - `.indexOn: ["timestamp"]` under `locations/{adminUid}/{clientUid}`.
5. Seed at minimum:
   - one admin user and one client user,
   - admin-client mapping,
   - boundary assignment.

---

## Notes for Demos

- If admin sees alerts but not live status, verify client/admin mapping in `adminClients` and `clientAssignments`.
- If telemetry appears in Firebase console but not in UI, confirm the same Firebase project and matching UID paths are used on both devices.
- Some OEM Android builds (notably low-end variants) may report native tombstones; capture device logs if app launch instability appears.
