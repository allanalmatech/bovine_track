import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

import '../models/alert_model.dart';
import '../models/location_point_model.dart';

class SyncService {
  SyncService({required this.endpoint});

  final String endpoint;

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> syncLocation(LocationPointModel point) async {
    final payload = {
      'type': 'location',
      'deviceId': point.deviceId,
      'lat': point.lat,
      'lng': point.lng,
      'speed': point.speed,
      'timestamp': point.recordedAt.toIso8601String(),
    };
    final firebaseOk = await _postFirebase(
      path: 'devices/${point.deviceId}/locations',
      payload: payload,
    );
    if (firebaseOk) {
      return true;
    }
    return _post(payload);
  }

  Future<bool> syncAlert(AlertModel alert) async {
    final payload = {
      'type': 'alert',
      'deviceId': alert.deviceId,
      'alertType': alert.type,
      'message': alert.message,
      'lat': alert.lat,
      'lng': alert.lng,
      'timestamp': alert.createdAt.toIso8601String(),
    };
    final firebaseOk = await _postFirebase(
      path: 'server_alerts',
      payload: payload,
    );
    if (firebaseOk) {
      return true;
    }
    return _post(payload);
  }

  Future<bool> _postFirebase({
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        return false;
      }
      final ref = FirebaseDatabase.instance.ref(path).push();
      await ref.set(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _post(Map<String, dynamic> payload) async {
    if (endpoint.isEmpty) {
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
