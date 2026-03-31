import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/alert_model.dart';
import '../models/geofence_model.dart';
import '../models/rbac_models.dart';

class RbacRepository {
  RbacRepository._();
  static final RbacRepository instance = RbacRepository._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> getRole(String uid) async {
    final snapshot = await _db.ref('users/$uid/role').get();
    return snapshot.value as String?;
  }

  Future<void> setOwnRole(String role) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return;
    }
    await _db.ref('users/$uid').update({
      'role': role,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> registerDeviceToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _db.ref('deviceTokens/$uid/$token').set(true);
  }

  Stream<List<ManagedClient>> watchAdminClients(String adminUid) {
    return _db.ref('adminClients/$adminUid').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return <ManagedClient>[];
      }
      final out = <ManagedClient>[];
      value.forEach((key, row) {
        if (row is Map) {
          out.add(
            ManagedClient(
              uid: key.toString(),
              label: (row['label'] ?? key).toString(),
              active: row['active'] == true,
            ),
          );
        }
      });
      return out;
    });
  }

  Stream<List<AlertModel>> watchAdminAlerts(
    String adminUid, {
    bool includeResolved = false,
  }) {
    return _db
        .ref('alerts/$adminUid')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value is! Map) {
            return <AlertModel>[];
          }
          final out = <AlertModel>[];
          value.forEach((key, row) {
            if (row is Map) {
              out.add(
                AlertModel(
                  id: null,
                  deviceId: (row['clientUid'] ?? '').toString(),
                  type: (row['type'] ?? 'ALERT').toString(),
                  message: (row['message'] ?? '').toString(),
                  lat: (row['lat'] as num?)?.toDouble() ?? 0,
                  lng: (row['lng'] as num?)?.toDouble() ?? 0,
                  createdAt: DateTime.fromMillisecondsSinceEpoch(
                    (row['timestamp'] as num?)?.toInt() ??
                        DateTime.now().millisecondsSinceEpoch,
                  ),
                  synced: true,
                  remoteKey: key.toString(),
                  resolved: row['resolved'] == true,
                ),
              );
            }
          });
          if (!includeResolved) {
            out.removeWhere((a) => a.resolved);
          }
          out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return out;
        });
  }

  Future<void> createClientAccount({
    required String email,
    required String password,
    required String label,
  }) async {
    try {
      final callable = _functions.httpsCallable('createClientAccount');
      await callable.call({
        'email': email,
        'password': password,
        'label': label,
      });
      return;
    } catch (_) {
      // Fall back to direct Firebase Auth REST provisioning for prototype mode.
    }

    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null || adminUid.isEmpty) {
      throw Exception('Admin session missing. Please sign in again.');
    }

    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
    );
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': false,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Client creation failed: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final clientUid = (body['localId'] ?? '').toString();
    if (clientUid.isEmpty) {
      throw Exception('Client account created but UID missing in response.');
    }

    try {
      await _db.ref('users/$clientUid').update({
        'role': 'client',
        'email': email,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {
      // If rules block this path, client can still self-bootstrap role on first login.
    }

    await _db.ref('adminClients/$adminUid/$clientUid').update({
      'label': label,
      'active': true,
      'createdAt': ServerValue.timestamp,
    });
    await _db.ref('clientAssignments/$clientUid').update({'adminId': adminUid});
  }

  Future<void> createBoundary({
    required String adminUid,
    required String farmId,
    required String farmName,
    required GeofenceModel fence,
    required List<String> assignedClientIds,
  }) async {
    final ref = _db.ref('boundaries/$adminUid').push();
    final assigned = <String, bool>{};
    for (final id in assignedClientIds) {
      assigned[id] = true;
    }

    await ref.set({
      'farmId': farmId,
      'farmName': farmName,
      'name': fence.name,
      'vertices': fence.verticesText,
      'isRestricted': fence.isRestricted,
      'assignedClients': assigned,
      'createdAt': ServerValue.timestamp,
    });

    for (final clientId in assignedClientIds) {
      await _db.ref('clientAssignments/$clientId').update({
        'adminId': adminUid,
        'boundaryIds/${ref.key}': true,
      });
    }
  }

  Future<AdminSnapshot> getAdminSnapshot(String adminUid) async {
    final clientsSnapshot = await _db.ref('adminClients/$adminUid').get();
    final boundariesSnapshot = await _db.ref('boundaries/$adminUid').get();
    final alertsSnapshot = await _db
        .ref('alerts/$adminUid')
        .orderByChild('timestamp')
        .limitToLast(30)
        .get();

    final clients = <ManagedClient>[];
    if (clientsSnapshot.value is Map) {
      (clientsSnapshot.value as Map).forEach((key, row) {
        if (row is Map) {
          clients.add(
            ManagedClient(
              uid: key.toString(),
              label: (row['label'] ?? key).toString(),
              active: row['active'] == true,
            ),
          );
        }
      });
    }

    final alerts = <AlertModel>[];
    if (alertsSnapshot.value is Map) {
      final map = alertsSnapshot.value as Map;
      map.forEach((_, row) {
        if (row is Map) {
          alerts.add(
            AlertModel(
              id: null,
              deviceId: (row['clientUid'] ?? '').toString(),
              type: (row['type'] ?? 'ALERT').toString(),
              message: (row['message'] ?? '').toString(),
              lat: (row['lat'] as num?)?.toDouble() ?? 0,
              lng: (row['lng'] as num?)?.toDouble() ?? 0,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                (row['timestamp'] as num?)?.toInt() ??
                    DateTime.now().millisecondsSinceEpoch,
              ),
              synced: true,
            ),
          );
        }
      });
      alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final boundaryCount = boundariesSnapshot.value is Map
        ? (boundariesSnapshot.value as Map).length
        : 0;

    return AdminSnapshot(
      clients: clients,
      alerts: alerts,
      boundaryCount: boundaryCount,
    );
  }

  Future<ClientContext?> getClientContext(String clientUid) async {
    final assignmentSnapshot = await _db
        .ref('clientAssignments/$clientUid')
        .get();
    if (assignmentSnapshot.value is! Map) {
      return null;
    }
    final assignment = assignmentSnapshot.value as Map;
    final adminId = (assignment['adminId'] ?? '').toString();
    if (adminId.isEmpty) {
      return null;
    }

    final boundaryIdsRaw = assignment['boundaryIds'];
    final boundaryIds = <String>{};
    if (boundaryIdsRaw is Map) {
      boundaryIdsRaw.forEach((key, value) {
        if (value == true) {
          boundaryIds.add(key.toString());
        }
      });
    }

    final boundariesSnapshot = await _db.ref('boundaries/$adminId').get();
    final boundaries = <ManagedBoundary>[];
    if (boundariesSnapshot.value is Map) {
      (boundariesSnapshot.value as Map).forEach((key, row) {
        if (row is! Map) {
          return;
        }
        final assigned = <String>[];
        final assignedRaw = row['assignedClients'];
        if (assignedRaw is Map) {
          assignedRaw.forEach((clientId, enabled) {
            if (enabled == true) {
              assigned.add(clientId.toString());
            }
          });
        }

        final id = key.toString();
        final assignedByIds = boundaryIds.contains(id);
        final assignedByBoundary = assigned.contains(clientUid);
        if (!assignedByIds && !assignedByBoundary) {
          return;
        }

        boundaries.add(
          ManagedBoundary(
            id: id,
            adminId: adminId,
            farmId: (row['farmId'] ?? '').toString(),
            farmName: (row['farmName'] ?? 'Unassigned Farm').toString(),
            name: (row['name'] ?? '').toString(),
            vertices: GeofenceModel.parseVertices(
              (row['vertices'] ?? '').toString(),
            ),
            isRestricted: row['isRestricted'] == true,
            assignedClients: assigned,
          ),
        );
      });
    }

    return ClientContext(adminId: adminId, boundaries: boundaries);
  }

  Future<void> publishClientLocation({
    required String adminUid,
    required String clientUid,
    required double lat,
    required double lng,
    required double speed,
    required double accuracy,
    required int battery,
    required String network,
    required int sessionStartedAt,
  }) async {
    final nowClient = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'clientUid': clientUid,
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'accuracy': accuracy,
      'battery': battery,
      'network': network,
      'clientTimestamp': nowClient,
      'timestamp': ServerValue.timestamp,
    };
    try {
      await _db.ref('locations/$adminUid/$clientUid').push().set(payload);
      await _db.ref('locationsLatest/$adminUid/$clientUid').set(payload);
      await _db.ref('clientStatus/$adminUid/$clientUid').set({
        'lastSeen': ServerValue.timestamp,
        'clientTimestamp': nowClient,
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'accuracy': accuracy,
        'battery': battery,
        'network': network,
        'sessionStartedAt': sessionStartedAt,
        'online': true,
      });
    } catch (_) {
      final legacyPayload = {
        'clientUid': clientUid,
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'clientTimestamp': nowClient,
        'timestamp': ServerValue.timestamp,
      };
      await _db.ref('locations/$adminUid/$clientUid').push().set(legacyPayload);
      await _db.ref('locationsLatest/$adminUid/$clientUid').set(legacyPayload);
      await _db.ref('clientStatus/$adminUid/$clientUid').set({
        'lastSeen': ServerValue.timestamp,
        'clientTimestamp': nowClient,
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'sessionStartedAt': sessionStartedAt,
        'online': true,
      });
    }
  }

  Future<void> setClientOffline({
    required String adminUid,
    required String clientUid,
  }) async {
    await _db.ref('clientStatus/$adminUid/$clientUid').update({
      'online': false,
      'offlineAt': ServerValue.timestamp,
      'sessionStartedAt': null,
    });
  }

  Stream<List<Map<String, dynamic>>> watchClientLocationHistory({
    required String adminUid,
    required String clientUid,
    required int sinceTimestamp,
    int limit = 1500,
  }) {
    return _db
        .ref('locations/$adminUid/$clientUid')
        .orderByChild('timestamp')
        .startAt(sinceTimestamp)
        .limitToLast(limit)
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          final out = <Map<String, dynamic>>[];
          if (value is Map) {
            value.forEach((key, row) {
              if (row is Map) {
                final map = Map<String, dynamic>.from(
                  row.map((k, v) => MapEntry(k.toString(), v)),
                );
                map['id'] = key.toString();
                out.add(map);
              }
            });
          }
          out.sort(
            (a, b) => ((a['timestamp'] as num?)?.toInt() ?? 0).compareTo(
              (b['timestamp'] as num?)?.toInt() ?? 0,
            ),
          );
          return out;
        });
  }

  Future<Map<String, dynamic>?> getClientPositionAtOrBefore({
    required String adminUid,
    required String clientUid,
    required int targetTimestamp,
  }) async {
    final snap = await _db
        .ref('locations/$adminUid/$clientUid')
        .orderByChild('timestamp')
        .endAt(targetTimestamp)
        .limitToLast(1)
        .get();
    if (snap.value is! Map) {
      return null;
    }
    final rows = snap.value as Map;
    if (rows.isEmpty) {
      return null;
    }
    final first = rows.values.first;
    if (first is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(
      first.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  Future<void> publishBoundaryAlert({
    required String adminUid,
    required String clientUid,
    required String type,
    required String message,
    required double lat,
    required double lng,
  }) async {
    await _db.ref('alerts/$adminUid').push().set({
      'clientUid': clientUid,
      'type': type,
      'message': message,
      'lat': lat,
      'lng': lng,
      'source': 'client',
      'resolved': false,
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> setAlertResolved({
    required String adminUid,
    required String alertKey,
    required bool resolved,
  }) async {
    await _db.ref('alerts/$adminUid/$alertKey').update({
      'resolved': resolved,
      'resolvedAt': resolved ? ServerValue.timestamp : null,
    });
  }

  Future<void> resolveAllAlerts(String adminUid) async {
    final snap = await _db.ref('alerts/$adminUid').get();
    if (snap.value is! Map) {
      return;
    }
    final updates = <String, dynamic>{};
    (snap.value as Map).forEach((key, _) {
      updates['$key/resolved'] = true;
      updates['$key/resolvedAt'] = ServerValue.timestamp;
    });
    await _db.ref('alerts/$adminUid').update(updates);
  }

  Future<void> clearAlert({
    required String adminUid,
    required String alertKey,
  }) async {
    await _db.ref('alerts/$adminUid/$alertKey').remove();
  }

  Future<void> clearAllAlerts(String adminUid) async {
    await _db.ref('alerts/$adminUid').remove();
  }

  Stream<List<TrackedDevice>> watchAdminDevices(String adminUid) {
    return _db.ref('adminDevices/$adminUid').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return <TrackedDevice>[];
      }
      final out = <TrackedDevice>[];
      value.forEach((key, row) {
        if (row is Map) {
          out.add(
            TrackedDevice(
              deviceId: key.toString(),
              clientUid: (row['clientUid'] ?? '').toString(),
              label: (row['label'] ?? key).toString(),
              active: row['active'] == true,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                (row['createdAt'] as num?)?.toInt() ?? 0,
              ),
            ),
          );
        }
      });
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    });
  }

  Stream<Map<String, Map<String, dynamic>>> watchLatestLocationsByClient(
    String adminUid,
  ) {
    return _db.ref('locationsLatest').onValue.asyncMap((event) async {
      final clientIds = await _loadAdminClientIds(adminUid);
      if (clientIds.isEmpty) {
        return <String, Map<String, dynamic>>{};
      }

      final global = event.snapshot.value;
      final out = <String, Map<String, dynamic>>{};
      if (global is Map) {
        global.forEach((outerKey, outerValue) {
          // Flat shape: locationsLatest/{clientUid}
          if (clientIds.contains(outerKey.toString()) && outerValue is Map) {
            out[outerKey.toString()] = Map<String, dynamic>.from(
              outerValue.map((k, v) => MapEntry(k.toString(), v)),
            );
            return;
          }
          // Nested shape: locationsLatest/{adminUid}/{clientUid}
          if (outerValue is! Map) {
            return;
          }
          outerValue.forEach((clientUid, row) {
            if (!clientIds.contains(clientUid.toString()) || row is! Map) {
              return;
            }
            final asMap = Map<String, dynamic>.from(
              row.map((k, v) => MapEntry(k.toString(), v)),
            );
            final existing = out[clientUid.toString()];
            if (existing == null || _extractTs(asMap) > _extractTs(existing)) {
              out[clientUid.toString()] = asMap;
            }
          });
        });
      }
      if (out.isNotEmpty) {
        return out;
      }

      // Fallback: build latest rows from admin-scoped history path.
      final historySnap = await _db.ref('locations/$adminUid').get();
      final historyOut = <String, Map<String, dynamic>>{};
      if (historySnap.value is Map) {
        (historySnap.value as Map).forEach((clientUid, clientRowsRaw) {
          if (!clientIds.contains(clientUid.toString()) ||
              clientRowsRaw is! Map) {
            return;
          }
          Map<String, dynamic>? newest;
          int newestTs = -1;
          clientRowsRaw.forEach((_, row) {
            if (row is! Map) {
              return;
            }
            final asMap = Map<String, dynamic>.from(
              row.map((k, v) => MapEntry(k.toString(), v)),
            );
            final ts = _extractTs(asMap);
            if (ts > newestTs) {
              newestTs = ts;
              newest = asMap;
            }
          });
          if (newest != null) {
            historyOut[clientUid.toString()] = newest!;
          }
        });
      }
      if (historyOut.isNotEmpty) {
        return historyOut;
      }
      return _fallbackLatestFromAnyAdmin(adminUid);
    });
  }

  Stream<Map<String, Map<String, dynamic>>> watchClientStatusByClient(
    String adminUid,
  ) {
    return _db.ref('clientStatus').onValue.asyncMap((event) async {
      final clientIds = await _loadAdminClientIds(adminUid);
      if (clientIds.isEmpty) {
        return <String, Map<String, dynamic>>{};
      }

      final global = event.snapshot.value;
      final out = <String, Map<String, dynamic>>{};
      if (global is Map) {
        global.forEach((outerKey, outerValue) {
          // Flat shape: clientStatus/{clientUid}
          if (clientIds.contains(outerKey.toString()) && outerValue is Map) {
            out[outerKey.toString()] = Map<String, dynamic>.from(
              outerValue.map((k, v) => MapEntry(k.toString(), v)),
            );
            return;
          }
          // Nested shape: clientStatus/{adminUid}/{clientUid}
          if (outerValue is! Map) {
            return;
          }
          outerValue.forEach((clientUid, row) {
            if (!clientIds.contains(clientUid.toString()) || row is! Map) {
              return;
            }
            final asMap = Map<String, dynamic>.from(
              row.map((k, v) => MapEntry(k.toString(), v)),
            );
            final existing = out[clientUid.toString()];
            if (existing == null || _extractTs(asMap) > _extractTs(existing)) {
              out[clientUid.toString()] = asMap;
            }
          });
        });
      }
      if (out.isNotEmpty) {
        return out;
      }
      return _fallbackStatusFromAnyAdmin(adminUid);
    });
  }

  Future<Set<String>> _loadAdminClientIds(String adminUid) async {
    final clientsSnap = await _db.ref('adminClients/$adminUid').get();
    final ids = <String>{};
    if (clientsSnap.value is Map) {
      (clientsSnap.value as Map).forEach((k, _) => ids.add(k.toString()));
    }
    return ids;
  }

  Future<Map<String, Map<String, dynamic>>> _fallbackLatestFromAnyAdmin(
    String adminUid,
  ) async {
    final clientsSnap = await _db.ref('adminClients/$adminUid').get();
    final clientIds = <String>{};
    if (clientsSnap.value is Map) {
      (clientsSnap.value as Map).forEach((k, _) => clientIds.add(k.toString()));
    }
    if (clientIds.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    final globalLatestSnap = await _db.ref('locationsLatest').get();
    final result = <String, Map<String, dynamic>>{};
    if (globalLatestSnap.value is! Map) {
      return result;
    }

    (globalLatestSnap.value as Map).forEach((outerKey, outerValue) {
      // Handles flat shape: locationsLatest/{clientUid}
      if (clientIds.contains(outerKey.toString()) && outerValue is Map) {
        final flatRow = Map<String, dynamic>.from(
          outerValue.map((k, v) => MapEntry(k.toString(), v)),
        );
        final existing = result[outerKey.toString()];
        if (existing == null || _extractTs(flatRow) > _extractTs(existing)) {
          result[outerKey.toString()] = flatRow;
        }
        return;
      }

      // Handles nested shape: locationsLatest/{adminUid}/{clientUid}
      if (outerValue is! Map) {
        return;
      }
      outerValue.forEach((clientUid, row) {
        if (!clientIds.contains(clientUid.toString()) || row is! Map) {
          return;
        }
        final asMap = Map<String, dynamic>.from(
          row.map((k, v) => MapEntry(k.toString(), v)),
        );
        final existing = result[clientUid.toString()];
        if (existing == null || _extractTs(asMap) > _extractTs(existing)) {
          result[clientUid.toString()] = asMap;
        }
      });
    });
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _fallbackStatusFromAnyAdmin(
    String adminUid,
  ) async {
    final clientsSnap = await _db.ref('adminClients/$adminUid').get();
    final clientIds = <String>{};
    if (clientsSnap.value is Map) {
      (clientsSnap.value as Map).forEach((k, _) => clientIds.add(k.toString()));
    }
    if (clientIds.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    final globalStatusSnap = await _db.ref('clientStatus').get();
    final result = <String, Map<String, dynamic>>{};
    if (globalStatusSnap.value is! Map) {
      return result;
    }

    (globalStatusSnap.value as Map).forEach((outerKey, outerValue) {
      // Handles flat shape: clientStatus/{clientUid}
      if (clientIds.contains(outerKey.toString()) && outerValue is Map) {
        final flatRow = Map<String, dynamic>.from(
          outerValue.map((k, v) => MapEntry(k.toString(), v)),
        );
        final existing = result[outerKey.toString()];
        if (existing == null || _extractTs(flatRow) > _extractTs(existing)) {
          result[outerKey.toString()] = flatRow;
        }
        return;
      }

      // Handles nested shape: clientStatus/{adminUid}/{clientUid}
      if (outerValue is! Map) {
        return;
      }
      outerValue.forEach((clientUid, row) {
        if (!clientIds.contains(clientUid.toString()) || row is! Map) {
          return;
        }
        final asMap = Map<String, dynamic>.from(
          row.map((k, v) => MapEntry(k.toString(), v)),
        );
        final existing = result[clientUid.toString()];
        if (existing == null || _extractTs(asMap) > _extractTs(existing)) {
          result[clientUid.toString()] = asMap;
        }
      });
    });
    return result;
  }

  int _extractTs(Map<String, dynamic> row) {
    return (row['lastSeen'] as num?)?.toInt() ??
        (row['timestamp'] as num?)?.toInt() ??
        (row['clientTimestamp'] as num?)?.toInt() ??
        0;
  }

  Stream<List<ManagedBoundary>> watchBoundaries(String adminUid) {
    return _db.ref('boundaries/$adminUid').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return <ManagedBoundary>[];
      }
      final out = <ManagedBoundary>[];
      value.forEach((key, row) {
        if (row is Map) {
          final assigned = <String>[];
          final assignedRaw = row['assignedClients'];
          if (assignedRaw is Map) {
            assignedRaw.forEach((clientId, enabled) {
              if (enabled == true) {
                assigned.add(clientId.toString());
              }
            });
          }
          out.add(
            ManagedBoundary(
              id: key.toString(),
              adminId: adminUid,
              farmId: (row['farmId'] ?? '').toString(),
              farmName: (row['farmName'] ?? 'Unassigned Farm').toString(),
              name: (row['name'] ?? '').toString(),
              vertices: GeofenceModel.parseVertices(
                (row['vertices'] ?? '').toString(),
              ),
              isRestricted: row['isRestricted'] == true,
              assignedClients: assigned,
            ),
          );
        }
      });
      return out;
    });
  }

  Stream<List<FarmModel>> watchFarms(String adminUid) {
    return _db.ref('farms/$adminUid').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return <FarmModel>[];
      }
      final out = <FarmModel>[];
      value.forEach((key, row) {
        if (row is Map) {
          out.add(
            FarmModel(
              id: key.toString(),
              name: (row['name'] ?? '').toString(),
              locationHint: (row['locationHint'] ?? '').toString(),
              centerLat: (row['centerLat'] as num?)?.toDouble() ?? -0.6072,
              centerLng: (row['centerLng'] as num?)?.toDouble() ?? 30.6545,
              active: row['active'] != false,
            ),
          );
        }
      });
      out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return out;
    });
  }

  Future<void> addFarm({
    required String adminUid,
    required String name,
    required String locationHint,
    required double centerLat,
    required double centerLng,
  }) async {
    final ref = _db.ref('farms/$adminUid').push();
    await ref.set({
      'name': name.trim(),
      'locationHint': locationHint.trim(),
      'centerLat': centerLat,
      'centerLng': centerLng,
      'active': true,
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<void> updateFarm({
    required String adminUid,
    required String farmId,
    required String name,
    required String locationHint,
    required double centerLat,
    required double centerLng,
    required bool active,
  }) async {
    await _db.ref('farms/$adminUid/$farmId').update({
      'name': name.trim(),
      'locationHint': locationHint.trim(),
      'centerLat': centerLat,
      'centerLng': centerLng,
      'active': active,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> deleteFarm({
    required String adminUid,
    required String farmId,
  }) async {
    await _db.ref('farms/$adminUid/$farmId').remove();
  }

  Future<void> addTrackedDevice({
    required String adminUid,
    required String deviceId,
    required String clientUid,
    required String label,
  }) async {
    final trimmedDevice = deviceId.trim();
    final trimmedClient = clientUid.trim();
    final trimmedLabel = label.trim().isEmpty ? trimmedDevice : label.trim();
    await _db.ref('adminDevices/$adminUid/$trimmedDevice').set({
      'clientUid': trimmedClient,
      'label': trimmedLabel,
      'active': true,
      'createdAt': ServerValue.timestamp,
    });

    await _db.ref('adminClients/$adminUid/$trimmedClient').update({
      'label': trimmedLabel,
      'active': true,
      'deviceId': trimmedDevice,
      'createdAt': ServerValue.timestamp,
    });

    await _db.ref('clientAssignments/$trimmedClient').update({
      'adminId': adminUid,
    });
  }

  Future<void> setBoundaryAssignment({
    required String adminUid,
    required String boundaryId,
    required String clientUid,
    required bool assigned,
  }) async {
    final boundaryRef = _db.ref(
      'boundaries/$adminUid/$boundaryId/assignedClients/$clientUid',
    );
    final assignmentRef = _db.ref(
      'clientAssignments/$clientUid/boundaryIds/$boundaryId',
    );

    if (assigned) {
      await boundaryRef.set(true);
      await _db.ref('clientAssignments/$clientUid/adminId').set(adminUid);
      await assignmentRef.set(true);
    } else {
      await boundaryRef.remove();
      await assignmentRef.remove();
    }
  }

  Future<void> updateBoundary({
    required String adminUid,
    required String boundaryId,
    required String name,
    required String farmId,
    required String farmName,
    required String verticesText,
    required bool isRestricted,
  }) async {
    await _db.ref('boundaries/$adminUid/$boundaryId').update({
      'name': name,
      'farmId': farmId,
      'farmName': farmName,
      'vertices': verticesText,
      'isRestricted': isRestricted,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> deleteBoundary({
    required String adminUid,
    required String boundaryId,
    required List<String> assignedClientIds,
  }) async {
    await _db.ref('boundaries/$adminUid/$boundaryId').remove();
    for (final clientUid in assignedClientIds) {
      await _db
          .ref('clientAssignments/$clientUid/boundaryIds/$boundaryId')
          .remove();
    }
  }
}
