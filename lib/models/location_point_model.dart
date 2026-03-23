class LocationPointModel {
  LocationPointModel({
    required this.id,
    required this.deviceId,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.recordedAt,
    required this.synced,
  });

  final int? id;
  final String deviceId;
  final double lat;
  final double lng;
  final double speed;
  final DateTime recordedAt;
  final bool synced;

  factory LocationPointModel.fromMap(Map<String, Object?> map) {
    return LocationPointModel(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        map['recorded_at'] as int,
      ),
      synced: (map['synced'] as int) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'recorded_at': recordedAt.millisecondsSinceEpoch,
      'synced': synced ? 1 : 0,
    };
  }
}
