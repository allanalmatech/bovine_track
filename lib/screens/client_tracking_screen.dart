import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

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
  DateTime _lastBoundaryAlertAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _startPositionPushed = false;

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
    _mapController?.dispose();
    super.dispose();
  }

  final _lifecycleObserver = _ClientLifecycleObserver();

  Future<void> _requestRequiredPermissions() async {
    await [Permission.location, Permission.notification].request();
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
        await _rbac.publishClientLocation(
          adminUid: _adminUid,
          clientUid: _clientUid,
          lat: current.latitude,
          lng: current.longitude,
          speed: current.speed,
        );
      }
    } catch (_) {}

    await _startTracking();
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

          await _repo.saveLocation(
            LocationPointModel(
              id: null,
              deviceId: _clientUid,
              lat: position.latitude,
              lng: position.longitude,
              speed: position.speed,
              recordedAt: DateTime.now(),
              synced: false,
            ),
          );
          if (_adminUid.isNotEmpty) {
            await _rbac.publishClientLocation(
              adminUid: _adminUid,
              clientUid: _clientUid,
              lat: position.latitude,
              lng: position.longitude,
              speed: position.speed,
            );
            if (!_startPositionPushed) {
              await _pushStartPositionToAdmin(position);
            }
            await _evaluateBoundaryAndAlert(position);
          }
          await _repo.syncPending();
        });

    setState(() {
      _tracking = true;
      _status = 'Tracking started';
    });

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

    for (final boundary in _boundaries) {
      final inside = GeofenceService.isInside(
        point,
        boundary.toGeofenceModel(),
      );
      if (!boundary.isRestricted) {
        hasSafe = true;
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
        await _sendBoundaryAlert(
          type: 'SAFE_ZONE_EXIT',
          message: 'Client exited assigned safe boundary',
          lat: pos.latitude,
          lng: pos.longitude,
        );
      }
      _wasInsideSafe = insideSafe;
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
    }

    _startPositionPushed = false;
    setState(() {
      _tracking = false;
      _status = 'Tracking stopped';
    });
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
                            : Colors.green,
                        strokeWidth: 3,
                        fillColor:
                            (boundary.isRestricted ? Colors.red : Colors.green)
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
                  : 'Assigned by admin: $_adminUid | Boundaries: ${_boundaries.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Lifecycle Controller active: app state changes trigger pending-sync safeguards.',
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
