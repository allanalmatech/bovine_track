# BovineTrack (Native Android - Java)

This is a complete Java Android implementation of the BovineTrack prototype using a role-based architecture in one app.

## Implemented capabilities

- First-launch compatibility checks (SDK, GPS, Play Services, network, storage, permission readiness)
- Onboarding and role selection (Server / Client)
- Client foreground location tracking service (GPS) with simulation mode
- Room database local persistence for locations, geofences, and alerts
- Offline-first behavior with pending sync queue and retry
- Firebase Realtime Database sync support when a Database URL is configured in Settings
- Server dashboard with live metrics
- Geofence creation (safe/restricted circular zones)
- Geofence breach evaluation and alert creation
- Alerts log and client activity history
- Live map with real-time markers and geofence overlays

## Structure

- `app/src/main/java/com/bovinetrack/app/data` data and repositories
- `app/src/main/java/com/bovinetrack/app/service` foreground tracking service
- `app/src/main/java/com/bovinetrack/app/ui` presentation layer (MVVM + Activities)
- `app/src/main/java/com/bovinetrack/app/data/local` Room entities, DAOs, and DB

## Setup

1. Open `BovineTrackAndroid` in Android Studio (Giraffe or newer).
2. Add a valid Google Maps key in `AndroidManifest.xml` (`com.google.android.geo.API_KEY`).
3. Optional: set Firebase Realtime Database URL in app Settings to enable cloud sync.
4. Run on two Android devices:
   - Client mode device sends live location.
   - Server mode device monitors map/geofences/alerts.

## Design mapping

UI tokens and visual language are adapted from `Screens/verdant_field/DESIGN.md` and the provided screen references in `Screens/*`.
