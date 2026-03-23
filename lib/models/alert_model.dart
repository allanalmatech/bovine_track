class AlertModel {
  AlertModel({
    required this.id,
    required this.deviceId,
    required this.type,
    required this.message,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.synced,
  });

  final int? id;
  final String deviceId;
  final String type;
  final String message;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final bool synced;

  factory AlertModel.fromMap(Map<String, Object?> map) {
    return AlertModel(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String,
      type: map['type'] as String,
      message: map['message'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      synced: (map['synced'] as int) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'type': type,
      'message': message,
      'lat': lat,
      'lng': lng,
      'created_at': createdAt.millisecondsSinceEpoch,
      'synced': synced ? 1 : 0,
    };
  }
}
