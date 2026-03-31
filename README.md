# BovineTrack (A group 2 Concept)

## Group 8 Members

| No. | Name                | Registration Number |
|-----|---------------------|---------------------|
| 1   | Ainamaani Allan M   | 2023/BSE/151/PS     |
| 2   | Murungi Kevin T     | 2023/BSE/094/PS     |
| 3   | Mwunvaneza Godfrey  | 2023/BSE/100/PS     |
| 4   | Ochwo Denis         | 2023/BSE/164/PS     |
| 5   | Mbabazi Patience    | 2023/BSE/079/PS     |
| 6   | Okello David        | 2023/BSE/XXX/PS     |
| 7   | Allan Nuwamanya     | 2023/BSE/XXX/PS     |
| 8   | Ainomujuni Yovan    | 2023/BSE/XXX/PS     |

BovineTrack is a real-time livestock intelligence platform for farmers and ranch managers. It combines continuous GPS tracking, geofence safety enforcement, rapid alerts, and map-based operational visibility across admin and field devices.

This repo contains:
- A Flutter app (`/lib`) used by admins and client trackers.
- A native Android module (`/BovineTrackAndroid`) with advanced tracking pipeline components (Kalman filtering, adaptive cadence, wearable sync, and high-volume rendering patterns).

---

## Summary

BovineTrack helps you answer three critical questions at your farm:
- Where is each cow right now?
- Is any cow outside safe boundaries?
- Where was that cow at a specific time?

It is designed for real farm operations: low-latency telemetry, boundary alerts, historical trace review, and operational dashboards with online status, network health, and battery visibility.

---

## Sample Login Accounts

- Admin: `admin@bovine.com` | `admin123`
- Client: `cow1@bovine.com` | `cow123`

---

## We Implemented 1,2,4,5,10 out of the given questions.

### 1) Geofencing + reboot recovery
- Polygon and safe/restricted boundary logic with crossing detection.
- Boundary/track state restoration paths after device restart.

### 2) Background livestock tracking (Android-compliant)
- Continuous tracking flow with modern Android permissions.
- Client keeps publishing telemetry while app is not foregrounded (subject to OS/device policies).

### 4) Fast alert notifications
- Boundary violations are published immediately to Firebase.
- Local notifications for both admin/client-side alert flows.

### 5) Live map for many cattle
- Admin map renders all active tracked clients with realtime updates.
- Online/offline status is derived from live telemetry + status heartbeat fields.

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

## More is yet to come!
