import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/tracking_repository.dart';
import '../models/alert_model.dart';
import '../models/geofence_model.dart';
import '../models/location_point_model.dart';
import '../models/rbac_models.dart';
import '../services/geofence_service.dart';
import '../services/local_notification_service.dart';
import '../services/rbac_repository.dart';
import '../theme/app_theme.dart';

class ClientTrackingScreen extends StatefulWidget {
  const ClientTrackingScreen({super.key});

  @override
  State<ClientTrackingScreen> createState() => _ClientTrackingScreenState();
}

class _ClientTrackingScreenState extends State<ClientTrackingScreen> {
  final TrackingRepository _repo = TrackingRepository.instance;
  final RbacRepository _rbac = RbacRepository.instance;
  final Battery _battery = Battery();
  StreamSubscription<Position>? _positionSub;
  Position? _latest;
  bool _tracking = false;
  String _status = 'Idle';
  String _clientUid = '';
  String _adminUid = '';
  List<ManagedBoundary> _boundaries = const [];
  final Map<String, bool> _restrictedState = {};
  bool? _wasInsideSafe;
  final List<LatLng> _routePoints = <LatLng>[];
  GoogleMapController? _mapController;
  Timer? _assignmentRefreshTimer;
  Timer? _heartbeatTimer;
  Timer? _breachBlinkTimer;
  DateTime _lastBoundaryAlertAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _startPositionPushed = false;
  DateTime _lastPersistedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPublishedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _sessionStartedAt = 0;
  bool _outsideSafeZone = false;
  bool _blinkPhase = false;
  String _boundaryStateLabel = 'Boundary status unknown';
  Color _boundaryStateColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _clientUid = _rbac.currentUser?.uid ?? '';
    _bootstrapAutoTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _positionSub?.cancel();
    _assignmentRefreshTimer?.cancel();
    _heartbeatTimer?.cancel();
    _breachBlinkTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  final _lifecycleObserver = _ClientLifecycleObserver();

  Future<void> _requestRequiredPermissions() async {
    await [
      Permission.location,
      Permission.locationAlways,
      Permission.notification,
    ].request();
  }

  Future<void> _bootstrapAutoTracking() async {
    await _requestRequiredPermissions();
    await _loadAssignments();
    _assignmentRefreshTimer?.cancel();
    _assignmentRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _loadAssignments();
    });
    if (!mounted) {
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet = connectivity.any((r) => r != ConnectivityResult.none);
    if (!hasInternet) {
      setState(() {
        _status = 'Offline. Tracking can start and sync when internet returns.';
      });
    }

    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final currentPoint = LatLng(current.latitude, current.longitude);
      setState(() {
        _latest = current;
        _routePoints.add(currentPoint);
      });
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentPoint, zoom: 16),
        ),
      );
      if (_adminUid.isNotEmpty) {
        await _publishToAdmin(current);
      }
    } catch (_) {}

    final shouldAutoStart = await _isTrackingEnabled();
    if (shouldAutoStart) {
      await _startTracking();
    } else {
      setState(() {
        _status = 'Tracking paused';
      });
    }
  }

  Future<void> _loadAssignments() async {
    if (_clientUid.isEmpty) {
      return;
    }
    final contextInfo = await _rbac.getClientContext(_clientUid);
    if (!mounted || contextInfo == null) {
      return;
    }
    setState(() {
      _adminUid = contextInfo.adminId;
      _boundaries = contextInfo.boundaries;
      _status = 'Loaded ${contextInfo.boundaries.length} assigned boundaries';
    });
  }

  Future<void> _startTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _status = 'Enable location services to start tracking');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      setState(() => _status = 'Location permission is required');
      return;
    }

    _positionSub?.cancel();
    _startPositionPushed = false;
    _sessionStartedAt = DateTime.now().millisecondsSinceEpoch;
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) async {
          final currentPoint = LatLng(position.latitude, position.longitude);
          setState(() {
            _latest = position;
            _status = 'Tracking and syncing';
            _routePoints.add(currentPoint);
          });

          await _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: currentPoint, zoom: 16),
            ),
          );

          final now = DateTime.now();
          final moving = position.speed > 1.0;
          final persistInterval = moving
              ? const Duration(seconds: 10)
              : const Duration(seconds: 45);
          final publishInterval = moving
              ? const Duration(seconds: 8)
              : const Duration(seconds: 25);

          final shouldPersist =
              now.difference(_lastPersistedAt) >= persistInterval;
          if (shouldPersist) {
            _lastPersistedAt = now;
            await _repo.saveLocation(
              LocationPointModel(
                id: null,
                deviceId: _clientUid,
                lat: position.latitude,
                lng: position.longitude,
                speed: position.speed,
                recordedAt: now,
                synced: false,
              ),
            );
            await _repo.syncPending();
          }

          if (_adminUid.isNotEmpty) {
            final shouldPublish =
                now.difference(_lastPublishedAt) >= publishInterval;
            if (shouldPublish) {
              _lastPublishedAt = now;
              await _publishToAdmin(position);
            }
            if (!_startPositionPushed) {
              await _pushStartPositionToAdmin(position);
            }
            await _evaluateBoundaryAndAlert(position);
          }
        });

    setState(() {
      _tracking = true;
      _status = 'Tracking started';
    });
    _startHeartbeatPublishing();
    await _setTrackingEnabled(true);

    if (_adminUid.isNotEmpty) {
      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        await _pushStartPositionToAdmin(current);
      } catch (_) {}
    }
  }

  void _startHeartbeatPublishing() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
      if (!mounted || !_tracking || _adminUid.isEmpty) {
        return;
      }
      final latest = _latest;
      if (latest != null) {
        await _publishToAdmin(latest);
        return;
      }
      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _latest = current;
        });
        await _publishToAdmin(current);
      } catch (_) {}
    });
  }

  Future<void> _publishToAdmin(Position position) async {
    if (_sessionStartedAt == 0) {
      _sessionStartedAt = DateTime.now().millisecondsSinceEpoch;
    }
    final vitals = await _getClientVitals();
    await _rbac.publishClientLocation(
      adminUid: _adminUid,
      clientUid: _clientUid,
      lat: position.latitude,
      lng: position.longitude,
      speed: position.speed,
      accuracy: position.accuracy,
      battery: vitals.battery,
      network: vitals.network,
      sessionStartedAt: _sessionStartedAt,
    );
  }

  Future<_ClientVitals> _getClientVitals() async {
    int battery = -1;
    String network = 'unknown';
    try {
      battery = await _battery.batteryLevel;
    } catch (_) {}
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.any((c) => c == ConnectivityResult.mobile)) {
        network = 'mobile';
      } else if (connectivity.any((c) => c == ConnectivityResult.wifi)) {
        network = 'wifi';
      } else if (connectivity.any((c) => c == ConnectivityResult.ethernet)) {
        network = 'ethernet';
      } else if (connectivity.any((c) => c == ConnectivityResult.bluetooth)) {
        network = 'bluetooth';
      } else if (connectivity.any((c) => c == ConnectivityResult.none)) {
        network = 'offline';
      }
    } catch (_) {}
    return _ClientVitals(battery: battery, network: network);
  }

  Future<void> _pushStartPositionToAdmin(Position position) async {
    if (_startPositionPushed || _adminUid.isEmpty) {
      return;
    }
    _startPositionPushed = true;

    final primaryBoundary = _boundaries.isNotEmpty
        ? _boundaries.first.name
        : 'Unassigned Boundary';
    final user = _rbac.currentUser;
    final inferredName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : ((user?.email?.contains('@') ?? false)
              ? user!.email!.split('@').first
              : 'Client');

    await _rbac.publishBoundaryAlert(
      adminUid: _adminUid,
      clientUid: _clientUid,
      type: 'TRACKING_STARTED',
      message:
          'Bovine Track Alert: Tracking started for $inferredName in $primaryBoundary.',
      lat: position.latitude,
      lng: position.longitude,
    );
  }

  Future<void> _evaluateBoundaryAndAlert(Position pos) async {
    final point = GeoPoint(pos.latitude, pos.longitude);
    var hasSafe = false;
    var insideSafe = false;
    final safeBoundaryNames = <String>[];

    for (final boundary in _boundaries) {
      final inside = GeofenceService.isInside(
        point,
        boundary.toGeofenceModel(),
      );
      if (!boundary.isRestricted) {
        hasSafe = true;
        safeBoundaryNames.add(boundary.name);
        if (inside) {
          insideSafe = true;
        }
      }

      if (boundary.isRestricted) {
        final previous = _restrictedState[boundary.id] ?? false;
        if (!previous && inside) {
          await _sendBoundaryAlert(
            type: 'RESTRICTED_ENTRY',
            message: 'Client entered restricted boundary ${boundary.name}',
            lat: pos.latitude,
            lng: pos.longitude,
          );
        }
        _restrictedState[boundary.id] = inside;
      }
    }

    if (hasSafe) {
      final wasInside = _wasInsideSafe ?? true;
      if (wasInside && !insideSafe) {
        final boundariesLabel = safeBoundaryNames.isEmpty
            ? 'assigned safe boundary'
            : safeBoundaryNames.join(', ');
        await _sendBoundaryAlert(
          type: 'SAFE_ZONE_EXIT',
          message:
              'Bovine Track Alert: ${_clientDisplayName()} is outside boundary: $boundariesLabel.',
          lat: pos.latitude,
          lng: pos.longitude,
        );
      }
      _wasInsideSafe = insideSafe;
      _setSafeZoneBreach(!insideSafe);
      if (insideSafe) {
        _boundaryStateLabel = 'Inside safe zone';
        _boundaryStateColor = Colors.green;
      } else {
        _boundaryStateLabel = 'Outside safe zone';
        _boundaryStateColor = Colors.orange;
      }
    } else {
      _setSafeZoneBreach(false);
      _boundaryStateLabel = 'No safe boundary assigned';
      _boundaryStateColor = Colors.blueGrey;
    }

    for (final boundary in _boundaries) {
      final inside = GeofenceService.isInside(
        point,
        boundary.toGeofenceModel(),
      );
      if (boundary.isRestricted && inside) {
        _boundaryStateLabel = 'Inside restricted zone: ${boundary.name}';
        _boundaryStateColor = Colors.red;
        break;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  String _clientDisplayName() {
    final user = _rbac.currentUser;
    if (user?.displayName?.trim().isNotEmpty == true) {
      return user!.displayName!.trim();
    }
    if (user?.email?.contains('@') == true) {
      return user!.email!.split('@').first;
    }
    return 'Client';
  }

  void _setSafeZoneBreach(bool breached) {
    if (_outsideSafeZone == breached) {
      return;
    }
    _outsideSafeZone = breached;

    _breachBlinkTimer?.cancel();
    if (breached) {
      _breachBlinkTimer = Timer.periodic(const Duration(milliseconds: 550), (
        _,
      ) {
        if (!mounted) {
          return;
        }
        setState(() {
          _blinkPhase = !_blinkPhase;
        });
      });
    } else {
      _blinkPhase = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendBoundaryAlert({
    required String type,
    required String message,
    required double lat,
    required double lng,
  }) async {
    final now = DateTime.now();
    if (now.difference(_lastBoundaryAlertAt).inSeconds < 8) {
      return;
    }
    _lastBoundaryAlertAt = now;

    await _repo.addAlert(
      AlertModel(
        id: null,
        deviceId: _clientUid,
        type: type,
        message: message,
        lat: lat,
        lng: lng,
        createdAt: DateTime.now(),
        synced: false,
      ),
    );
    await _rbac.publishBoundaryAlert(
      adminUid: _adminUid,
      clientUid: _clientUid,
      type: type,
      message: message,
      lat: lat,
      lng: lng,
    );
    await LocalNotificationService.instance.showImmediateAlert(
      title: 'Boundary Alert: $type',
      body: message,
    );
    if (mounted) {
      setState(() {
        _status = 'Alert sent to admin: $type';
      });
    }
  }

  Future<void> _stopTracking() async {
    final wasTracking = _tracking || _positionSub != null;
    await _positionSub?.cancel();
    _positionSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _setTrackingEnabled(false);

    if (wasTracking && _adminUid.isNotEmpty) {
      final user = _rbac.currentUser;
      final inferredName = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : ((user?.email?.contains('@') ?? false)
                ? user!.email!.split('@').first
                : 'Client');
      final lat = _latest?.latitude ?? 0;
      final lng = _latest?.longitude ?? 0;
      await _rbac.publishBoundaryAlert(
        adminUid: _adminUid,
        clientUid: _clientUid,
        type: 'TRACKING_STOPPED',
        message: 'Bovine Track Alert: Tracking stopped for $inferredName.',
        lat: lat,
        lng: lng,
      );
      await _rbac.setClientOffline(adminUid: _adminUid, clientUid: _clientUid);
    }

    _startPositionPushed = false;
    setState(() {
      _tracking = false;
      _status = 'Tracking stopped';
    });
  }

  Future<bool> _isTrackingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('tracking_enabled') ?? false;
  }

  Future<void> _setTrackingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tracking_enabled', enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _stopTracking();
              await _rbac.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_outsideSafeZone)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _blinkPhase
                      ? const Color(0xFFFFB300)
                      : const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Warning: Device is outside safe zone!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Container(
              height: 260,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(-0.6072, 30.6545),
                  zoom: 13,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                markers: {
                  if (_latest != null)
                    Marker(
                      markerId: const MarkerId('client_current'),
                      position: LatLng(_latest!.latitude, _latest!.longitude),
                      infoWindow: const InfoWindow(title: 'Current Position'),
                    ),
                },
                polylines: {
                  if (_routePoints.length >= 2)
                    Polyline(
                      polylineId: const PolylineId('movement_route'),
                      points: _routePoints,
                      color: AppColors.primary,
                      width: 5,
                    ),
                },
                polygons: {
                  for (final boundary in _boundaries)
                    if (boundary.vertices.length >= 3)
                      Polygon(
                        polygonId: PolygonId(boundary.id),
                        points: boundary.vertices
                            .map((p) => LatLng(p.lat, p.lng))
                            .toList(),
                        strokeColor: boundary.isRestricted
                            ? Colors.red
                            : (_outsideSafeZone
                                  ? (_blinkPhase
                                        ? const Color(0xFFFFB300)
                                        : const Color(0xFFD32F2F))
                                  : Colors.green),
                        strokeWidth: 3,
                        fillColor:
                            (boundary.isRestricted
                                    ? Colors.red
                                    : (_outsideSafeZone
                                          ? (_blinkPhase
                                                ? const Color(0xFFFFB300)
                                                : const Color(0xFFD32F2F))
                                          : Colors.green))
                                .withValues(alpha: 0.12),
                      ),
                },
                zoomControlsEnabled: true,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield, color: _boundaryStateColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _boundaryStateLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _boundaryStateColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: $_status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _latest == null
                        ? 'Waiting for GPS data'
                        : 'Lat: ${_latest!.latitude.toStringAsFixed(6)}, Lng: ${_latest!.longitude.toStringAsFixed(6)}\nSpeed: ${_latest!.speed.toStringAsFixed(2)} m/s',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _tracking ? _stopTracking : _startTracking,
              child: Text(_tracking ? 'Stop Tracking' : 'Start Tracking'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                await _repo.syncPending();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Queued local data synced where online available',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Sync Pending Data'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _loadAssignments,
              child: const Text('Reload Boundary Assignments'),
            ),
            const SizedBox(height: 8),
            Text(
              _adminUid.isEmpty
                  ? 'No admin assignment found yet.'
                  : 'Assigned boundaries: ${_boundaries.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      TrackingRepository.instance.syncPending();
    }
  }
}

class _ClientVitals {
  const _ClientVitals({required this.battery, required this.network});

  final int battery;
  final String network;
}
