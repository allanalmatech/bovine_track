import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/tracking_repository.dart';
import '../models/alert_model.dart';
import '../models/geofence_model.dart';
import '../models/location_point_model.dart';
import '../models/rbac_models.dart';
import '../services/geofence_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _clientUid = _rbac.currentUser?.uid ?? '';
    _requestRequiredPermissions();
    _loadAssignments();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _positionSub?.cancel();
    super.dispose();
  }

  final _lifecycleObserver = _ClientLifecycleObserver();

  Future<void> _requestRequiredPermissions() async {
    await [Permission.location, Permission.notification].request();
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
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) async {
          setState(() {
            _latest = position;
            _status = 'Tracking and syncing';
          });

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
            await _evaluateBoundaryAndAlert(position);
          }
          await _repo.syncPending();
        });

    setState(() {
      _tracking = true;
      _status = 'Tracking started';
    });
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
  }

  Future<void> _stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
    setState(() {
      _tracking = false;
      _status = 'Tracking stopped';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client Tracking')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
