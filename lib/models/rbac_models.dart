import 'alert_model.dart';
import 'geofence_model.dart';

class ManagedClient {
  ManagedClient({required this.uid, required this.label, required this.active});

  final String uid;
  final String label;
  final bool active;
}

class ManagedBoundary {
  ManagedBoundary({
    required this.id,
    required this.adminId,
    required this.farmId,
    required this.farmName,
    required this.name,
    required this.vertices,
    required this.isRestricted,
    required this.assignedClients,
  });

  final String id;
  final String adminId;
  final String farmId;
  final String farmName;
  final String name;
  final List<GeoPoint> vertices;
  final bool isRestricted;
  final List<String> assignedClients;

  GeofenceModel toGeofenceModel() {
    return GeofenceModel(
      id: null,
      name: name,
      vertices: vertices,
      isRestricted: isRestricted,
      createdAt: DateTime.now(),
    );
  }
}

class FarmModel {
  FarmModel({
    required this.id,
    required this.name,
    required this.locationHint,
    required this.active,
  });

  final String id;
  final String name;
  final String locationHint;
  final bool active;
}

class ClientContext {
  ClientContext({required this.adminId, required this.boundaries});

  final String adminId;
  final List<ManagedBoundary> boundaries;
}

class AdminSnapshot {
  AdminSnapshot({
    required this.clients,
    required this.alerts,
    required this.boundaryCount,
  });

  final List<ManagedClient> clients;
  final List<AlertModel> alerts;
  final int boundaryCount;
}

class TrackedDevice {
  TrackedDevice({
    required this.deviceId,
    required this.clientUid,
    required this.label,
    required this.active,
    required this.createdAt,
  });

  final String deviceId;
  final String clientUid;
  final String label;
  final bool active;
  final DateTime createdAt;
}
