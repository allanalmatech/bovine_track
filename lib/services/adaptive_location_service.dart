import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum ActivityState { still, moving }

class AdaptiveLocationService {
  static final AdaptiveLocationService _instance =
      AdaptiveLocationService._internal();
  factory AdaptiveLocationService() => _instance;
  AdaptiveLocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  ActivityState _currentActivityState = ActivityState.still;
  ActivityState get currentActivityState => _currentActivityState;

  final _activityController = StreamController<ActivityState>.broadcast();
  Stream<ActivityState> get activityStream => _activityController.stream;

  final _locationController = StreamController<Position>.broadcast();
  Stream<Position> get locationStream => _locationController.stream;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  static const Duration _movingUpdateInterval = Duration(seconds: 8);
  static const Duration _stillUpdateInterval = Duration(minutes: 2);
  static const LocationAccuracy _movingAccuracy = LocationAccuracy.high;
  static const LocationAccuracy _stillAccuracy = LocationAccuracy.low;

  static const double _movementThreshold = 1.5;
  int _movementSamples = 0;
  static const int _requiredMovementSamples = 3;

  Timer? _stillnessCheckTimer;

  Future<void> startTracking() async {
    if (_isTracking) return;

    _isTracking = true;
    _startAccelerometerMonitoring();
    _startLocationTracking();
  }

  void _startAccelerometerMonitoring() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 200),
        ).listen((event) {
          _processAccelerometerData(event);
        });
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final deviation = (magnitude - 9.8).abs();

    if (deviation > _movementThreshold) {
      _movementSamples++;
    } else {
      _movementSamples = max(0, _movementSamples - 1);
    }

    final newState = _movementSamples >= _requiredMovementSamples
        ? ActivityState.moving
        : ActivityState.still;

    if (newState != _currentActivityState) {
      _transitionToState(newState);
    }
  }

  void _transitionToState(ActivityState newState) {
    final previousState = _currentActivityState;
    _currentActivityState = newState;
    _activityController.add(newState);

    if (newState == ActivityState.still) {
      _stillnessCheckTimer?.cancel();
      _stillnessCheckTimer = Timer(const Duration(minutes: 2), () {
        if (_currentActivityState == ActivityState.still) {
          _movementSamples = 0;
        }
      });
    } else {
      _stillnessCheckTimer?.cancel();
    }

    _restartLocationStream();

    print('[AdaptiveLocation] Transition: $previousState -> $newState');
  }

  void _startLocationTracking() {
    _positionSubscription?.cancel();
    _restartLocationStream();
  }

  void _restartLocationStream() {
    _positionSubscription?.cancel();

    final interval = _currentActivityState == ActivityState.moving
        ? _movingUpdateInterval
        : _stillUpdateInterval;

    final accuracy = _currentActivityState == ActivityState.moving
        ? _movingAccuracy
        : _stillAccuracy;

    print(
      '[AdaptiveLocation] Restarting stream: interval=${interval.inSeconds}s, accuracy=$accuracy',
    );

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: LocationSettings(
            accuracy: accuracy,
            distanceFilter: _currentActivityState == ActivityState.moving
                ? 10
                : 50,
            timeLimit: interval,
          ),
        ).listen(
          (position) {
            _locationController.add(position);
          },
          onError: (error) {
            print('[AdaptiveLocation] Location stream error: $error');
          },
        );
  }

  Future<Position?> getCurrentLocation() async {
    final accuracy = _currentActivityState == ActivityState.moving
        ? _movingAccuracy
        : _stillAccuracy;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy),
      );
    } catch (e) {
      print('[AdaptiveLocation] Get current location failed: $e');
      return null;
    }
  }

  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _stillnessCheckTimer?.cancel();
    _positionSubscription = null;
    _accelerometerSubscription = null;
    _stillnessCheckTimer = null;
    print('[AdaptiveLocation] Tracking stopped');
  }

  void dispose() {
    stopTracking();
    _activityController.close();
    _locationController.close();
  }
}
