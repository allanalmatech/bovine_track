# BovineTrack (Flutter)

BovineTrack is a geofencing-based livestock security and asset management prototype for mobile computing coursework.

This implementation follows the requirements in `requirements.png` and adds role-based tracking in one app:

- **Admin (Server/Monitor)**: manages farms, fences, clients, devices, alerts, and map monitoring.
- **Client (Tracked device / simulated cow tag phone)**: streams GPS telemetry, checks boundaries, and sends alerts.

---

## Requirements Coverage Matrix

## 1) Role-based system (single app)
- **Implemented**
- Login routes users by Firebase role (`admin` / `client`) from `users/{uid}/role`.
- Files:
  - `lib/screens/auth_gate_screen.dart`
  - `lib/services/rbac_repository.dart`

## 2) Device compatibility / onboarding flow
- **Implemented**
- Splash + onboarding + role-gated flow.
- Files:
  - `lib/screens/splash_screen.dart`
  - `lib/screens/onboarding_screen.dart`

## 3) Permissions and operational readiness
- **Implemented**
- Requests and enforces key permissions (location, notifications, sms) before core workflow.
- Files:
  - `lib/screens/auth_gate_screen.dart`
  - `android/app/src/main/AndroidManifest.xml`

## 4) Client continuous location tracking
- **Implemented**
- Uses `geolocator` stream for real-time telemetry.
- Auto-starts tracking after login/bootstrap.
- Writes telemetry to Firebase:
  - `locations/{adminUid}/{clientUid}` (history)
  - `locationsLatest/{adminUid}/{clientUid}` (latest point)
  - `clientStatus/{adminUid}/{clientUid}` (last seen / online snapshot)
- Files:
  - `lib/screens/client_tracking_screen.dart`
  - `lib/services/rbac_repository.dart`

## 5) Geofencing (safe + restricted boundaries)
- **Implemented**
- Polygon-based boundary checks.
- Client compares live coordinates against assigned boundaries.
- Detects:
  - Safe zone exit
  - Restricted zone entry
- Files:
  - `lib/services/geofence_service.dart`
  - `lib/screens/client_tracking_screen.dart`

## 6) Alerting and notifications
- **Implemented**
- Client creates boundary alerts and pushes them to admin scope in Firebase.
- Local phone notifications:
  - Client: immediate local notification on boundary breach.
  - Admin: notification drawer alerts via Firebase alert stream + offline catch-up on next login.
- Alert lifecycle:
  - Active vs Resolved
  - Mark resolved / unresolve / resolve all
- Files:
  - `lib/services/local_notification_service.dart`
  - `lib/services/admin_alert_notification_service.dart`
  - `lib/screens/alerts_screen.dart`

## 7) Map visualization
- **Implemented**
- Admin map: live markers + fences.
- Client map: live position + movement polyline + fence overlays.
- Farm creation and fence creation support map coordinate picking.
- Files:
  - `lib/screens/map_tracking_screen.dart`
  - `lib/screens/client_tracking_screen.dart`
  - `lib/screens/farms_screen.dart`
  - `lib/screens/geofence_builder_screen.dart`

## 8) Farm management and boundary linkage
- **Implemented**
- Add/Edit/Delete farms with map-selected center coordinates.
- Attach fences to specific farms.
- Farm details include:
  - boundaries in farm
  - assigned clients/devices
  - quick map preview
- Files:
  - `lib/screens/farms_screen.dart`
  - `lib/screens/farm_details_screen.dart`
  - `lib/screens/geofence_builder_screen.dart`

## 9) Client and device management
- **Implemented**
- Admin can create clients, map devices to clients, and view tracked device list.
- Device list includes telemetry status and fallback display for unmapped client entries.
- Files:
  - `lib/screens/device_list_screen.dart`
  - `lib/services/rbac_repository.dart`

## 10) Boundary assignment per client
- **Implemented**
- Assign/unassign boundaries in client profile.
- Also available from a dedicated menu entry (Boundary Assignments).
- Files:
  - `lib/screens/client_profile_screen.dart`
  - `lib/screens/boundary_assignments_screen.dart`
  - `lib/services/rbac_repository.dart`

## 11) Historical tracking / offline-first
- **Implemented**
- Local persistence via `sqflite` for locations, geofences, and alerts.
- Sync mechanism for pending records when online.
- Files:
  - `lib/data/local_db.dart`
  - `lib/data/tracking_repository.dart`
  - `lib/services/sync_service.dart`

## 12) Dashboard UX and responsiveness
- **Implemented**
- Modern card-based dashboard with responsive sections.
- Drawer menu for module navigation.
- Scroll handling added across overflow-prone screens.
- Files:
  - `lib/screens/server_dashboard_screen.dart`
  - multiple screens using `SingleChildScrollView`

## 13) Extra utilities from requirements
- **Implemented**
- Hardware diagnostic module.
- Connectivity manager module.
- Files:
  - `lib/screens/hardware_diagnostic_screen.dart`
  - `lib/screens/network_monitor_screen.dart`

---

## Firebase Data Model Used

- `users/{uid}`
- `adminClients/{adminUid}/{clientUid}`
- `adminDevices/{adminUid}/{deviceId}`
- `farms/{adminUid}/{farmId}`
- `boundaries/{adminUid}/{boundaryId}`
- `clientAssignments/{clientUid}`
- `locations/{adminUid}/{clientUid}/{locationId}`
- `locationsLatest/{adminUid}/{clientUid}`
- `clientStatus/{adminUid}/{clientUid}`
- `alerts/{adminUid}/{alertId}`
- `deviceTokens/{uid}/{token}`

---

## Build and Run

## Debug APK
```bash
flutter pub get
flutter build apk --debug
```

## Release APK
```bash
flutter pub get
flutter build apk --release
```

APK output path:
- `build/app/outputs/flutter-apk/`

---

## Required Firebase Setup

1. Enable Email/Password in Firebase Authentication.
2. Configure FlutterFire for this app (`firebase_options.dart` already integrated).
3. Use Realtime Database rules aligned to RBAC paths above.
4. Seed at least:
   - one admin user with role `admin`
   - one client user with role `client`
   - admin-client assignment and boundary assignment

---

## Current Notes

- Boundary detection is client-side and immediate.
- Admin receives notification-drawer alerts for boundary events and tracking state events.
- If tracking data appears in Firebase but not in UI, check UID consistency across:
  - `adminClients`
  - `adminDevices`
  - `clientAssignments`
  - `locationsLatest` / `clientStatus`
