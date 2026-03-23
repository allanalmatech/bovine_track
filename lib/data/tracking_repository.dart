import '../models/alert_model.dart';
import '../models/geofence_model.dart';
import '../models/location_point_model.dart';
import '../services/geofence_service.dart';
import '../services/sync_service.dart';
import 'local_db.dart';

class TrackingRepository {
  TrackingRepository._();
  static final TrackingRepository instance = TrackingRepository._();

  final SyncService _syncService = SyncService(
    endpoint: 'https://httpbin.org/post',
  );

  Future<void> addGeofence(GeofenceModel fence) async {
    final db = await LocalDb.instance.db;
    await db.insert('geofences', fence.toMap());
  }

  Future<List<GeofenceModel>> getGeofences() async {
    final db = await LocalDb.instance.db;
    final rows = await db.query('geofences', orderBy: 'created_at DESC');
    return rows.map(GeofenceModel.fromMap).toList();
  }

  Future<void> saveLocation(LocationPointModel point) async {
    final db = await LocalDb.instance.db;
    await db.insert('locations', point.toMap());
    await _evaluateGeofence(point);
  }

  Future<List<LocationPointModel>> getRecentLocations({int limit = 100}) async {
    final db = await LocalDb.instance.db;
    final rows = await db.query(
      'locations',
      orderBy: 'recorded_at DESC',
      limit: limit,
    );
    return rows.map(LocationPointModel.fromMap).toList();
  }

  Future<void> addAlert(AlertModel alert) async {
    final db = await LocalDb.instance.db;
    await db.insert('alerts', alert.toMap());
  }

  Future<List<AlertModel>> getRecentAlerts({int limit = 100}) async {
    final db = await LocalDb.instance.db;
    final rows = await db.query(
      'alerts',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(AlertModel.fromMap).toList();
  }

  Future<void> syncPending() async {
    if (!await _syncService.isOnline()) {
      return;
    }

    final db = await LocalDb.instance.db;

    final locationRows = await db.query(
      'locations',
      where: 'synced = 0',
      limit: 200,
    );
    for (final row in locationRows) {
      final point = LocationPointModel.fromMap(row);
      final ok = await _syncService.syncLocation(point);
      if (ok && point.id != null) {
        await db.update(
          'locations',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [point.id],
        );
      }
    }

    final alertRows = await db.query('alerts', where: 'synced = 0', limit: 200);
    for (final row in alertRows) {
      final alert = AlertModel.fromMap(row);
      final ok = await _syncService.syncAlert(alert);
      if (ok && alert.id != null) {
        await db.update(
          'alerts',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [alert.id],
        );
      }
    }
  }

  Future<void> _evaluateGeofence(LocationPointModel point) async {
    final geofences = await getGeofences();
    if (geofences.isEmpty) {
      return;
    }

    final p = GeoPoint(point.lat, point.lng);
    var insideSafe = false;
    var hasSafe = false;

    for (final fence in geofences) {
      final inside = GeofenceService.isInside(p, fence);
      if (!fence.isRestricted) {
        hasSafe = true;
      }
      if (!fence.isRestricted && inside) {
        insideSafe = true;
      }
      if (fence.isRestricted && inside) {
        await addAlert(
          AlertModel(
            id: null,
            deviceId: point.deviceId,
            type: 'RESTRICTED_ENTRY',
            message: 'Client crossed into restricted zone: ${fence.name}',
            lat: point.lat,
            lng: point.lng,
            createdAt: DateTime.now(),
            synced: false,
          ),
        );
      }
    }

    if (hasSafe && !insideSafe) {
      await addAlert(
        AlertModel(
          id: null,
          deviceId: point.deviceId,
          type: 'SAFE_ZONE_EXIT',
          message: 'Client left safe grazing boundary',
          lat: point.lat,
          lng: point.lng,
          createdAt: DateTime.now(),
          synced: false,
        ),
      );
    }
  }
}
