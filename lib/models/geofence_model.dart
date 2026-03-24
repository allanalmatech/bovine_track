class GeofenceModel {
  GeofenceModel({
    required this.id,
    required this.name,
    required this.vertices,
    required this.isRestricted,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final List<GeoPoint> vertices;
  final bool isRestricted;
  final DateTime createdAt;

  String get verticesText => vertices.map((v) => '${v.lat},${v.lng}').join(';');

  factory GeofenceModel.fromMap(Map<String, Object?> map) {
    return GeofenceModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      vertices: parseVertices((map['vertices'] as String?) ?? ''),
      isRestricted: (map['is_restricted'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'vertices': verticesText,
      'is_restricted': isRestricted ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  static List<GeoPoint> parseVertices(String text) {
    final out = <GeoPoint>[];
    for (final part in text.split(';')) {
      final pieces = part.trim().split(',');
      if (pieces.length != 2) {
        continue;
      }
      final lat = double.tryParse(pieces[0].trim());
      final lng = double.tryParse(pieces[1].trim());
      if (lat != null && lng != null) {
        out.add(GeoPoint(lat, lng));
      }
    }
    return out;
  }
}

class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;
}
