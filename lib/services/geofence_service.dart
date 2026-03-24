import '../models/geofence_model.dart';

class GeofenceService {
  static bool isInside(GeoPoint point, GeofenceModel fence) {
    if (fence.vertices.length < 3) {
      return false;
    }

    var inside = false;
    final vertices = fence.vertices;
    for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
      final xi = vertices[i].lat;
      final yi = vertices[i].lng;
      final xj = vertices[j].lat;
      final yj = vertices[j].lng;

      final intersects =
          ((yi > point.lng) != (yj > point.lng)) &&
          (point.lat <
              (xj - xi) * (point.lng - yi) / ((yj - yi) + 0.000000001) + xi);
      if (intersects) {
        inside = !inside;
      }
    }
    return inside;
  }
}
