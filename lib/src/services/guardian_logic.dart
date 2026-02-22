import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:usafe_front_end/core/services/api_service.dart';

/// GuardianLogic handles real GPS tracking for Guardian Mode.
/// 
/// This class:
/// - Listens to real-time GPS stream from the child's device
/// - Calculates distance to the next checkpoint using geodesic (earth-curved) math
/// - Triggers callbacks when distance updates or checkpoint is reached
/// - Manages permissions and battery-efficient location updates
/// - Falls back to mock locations on emulator due to Android 15 GNSS issues
class GuardianLogic {
  /// Listens to live GPS position updates
  StreamSubscription<Position>? _positionStream;

  /// Mock location timer for emulator (works around DeadSystemException)
  Timer? _mockPositionTimer;
  
  /// Timer for sending periodic location updates to backend (every 60 seconds)
  Timer? _locationUpdateTimer;
  
  /// Current route ID for tracking
  String? _routeId;
  
  /// Last known position for backend updates
  Position? _lastPosition;

  /// Callback fired when the user moves (distance to checkpoint updates)
  /// Parameter: distance in meters
  final Function(double distanceRemaining) onDistanceUpdate;

  /// Callback fired when user reaches a checkpoint (within 50m geofence)
  /// Parameter: index of the reached checkpoint
  final Function(int checkpointIndex) onCheckpointReached;

  /// Tracks current checkpoint index (which one we're heading toward)
  int _currentCheckpointIndex = 0;
  
  /// Flag to prevent recursive restart attempts
  bool _isRestarting = false;
  
  /// Flag to track if we're using mock locations (emulator)
  bool _useMockLocations = false;
  
  /// Simulated position for mock location stream
  double _mockLat = 6.9271; // Default: Colombo, SL
  double _mockLng = 79.8612;
  bool _mockSteppingForward = true;

  GuardianLogic({
    required this.onDistanceUpdate,
    required this.onCheckpointReached,
  });
  
  /// Check if running on emulator (Android only)
  static Future<bool> _isEmulator() async {
    return !Platform.isAndroid ? false : (await Geolocator.getCurrentPosition(timeLimit: Duration(milliseconds: 1)).then((_) => false).catchError((_) => true));
  }

  /// Starts real GPS tracking for Guardian Mode
  /// 
  /// This method:
  /// 1. Checks/requests location permissions
  /// 2. Starts listening to GPS stream (or mock on emulator)
  /// 3. Continuously calculates distance to next checkpoint
  /// 4. Triggers callbacks on distance updates and checkpoint arrival
  /// 5. Sends location updates to backend every 60 seconds
  /// 
  /// Parameters:
  /// - checkpoints: List of checkpoint maps with 'lat' and 'lng' keys
  /// - currentIndex: Starting checkpoint index (usually 0)
  /// - routeId: Route ID for backend tracking (optional)
  Future<void> startTracking(
    List<Map<String, dynamic>> checkpoints,
    int currentIndex, {
    String? routeId,
  }) async {
    _currentCheckpointIndex = currentIndex;
    _routeId = routeId;
    _useMockLocations = false;
    
    // Start periodic backend location updates (every 60 seconds)
    if (_routeId != null) {
      _startBackendLocationUpdates();
    }

    // STEP 1: Check and request location permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      // User denied permission
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied. Cannot start Guardian Mode.');
      }
    }

    // For Android 12+ background location tracking
    if (permission == LocationPermission.whileInUse) {
      final backgroundPermission =
          await Geolocator.requestPermission();
      // Note: Background permission is optional; tracking continues with in-use permission
    }

    // STEP 2: Try real GPS stream; fall back to mock on emulator
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 20,
        timeLimit: Duration(seconds: 45),
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _handlePositionUpdate(position, checkpoints);
        },
        onError: (Object e) {
          print('Guardian Logic Error: $e');
          // If system dies (DeadSystemException), fall back to mock
          if (e.toString().contains('DeadSystemException')) {
            _fallbackToMockLocations(checkpoints);
          }
        },
      );
    } catch (e) {
      print('Failed to start location stream: $e');
      // Fall back to mock locations
      _fallbackToMockLocations(checkpoints);
    }
  }
  
  /// Fallback to mock location updates for emulator testing
  void _fallbackToMockLocations(List<Map<String, dynamic>> checkpoints) {
    print('Falling back to mock location updates (emulator mode)');
    _useMockLocations = true;
    _mockLat = 6.9271;
    _mockLng = 79.8612;
    
    // Simulate location stream with timer
    _mockPositionTimer?.cancel();
    _mockPositionTimer = Timer.periodic(Duration(seconds: 3), (_) {
      // Slowly move toward first checkpoint
      if (checkpoints.isNotEmpty) {
        final target = checkpoints[_currentCheckpointIndex % checkpoints.length];
        final targetLat = target['lat'] as double;
        final targetLng = target['lng'] as double;
        
        // Move slightly toward target
        _mockLat += (targetLat - _mockLat) * 0.01;
        _mockLng += (targetLng - _mockLng) * 0.01;
      }
      
      final fakePos = Position(
        latitude: _mockLat,
        longitude: _mockLng,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      
      _handlePositionUpdate(fakePos, checkpoints);
    });
  }

  /// Internal handler for each GPS position update
  void _handlePositionUpdate(Position position, List<Map<String, dynamic>> checkpoints) {
    // Store latest position for backend updates
    _lastPosition = position;
    
    // Safety check: ensure we have checkpoints and valid index
    if (checkpoints.isEmpty || _currentCheckpointIndex >= checkpoints.length) {
      return;
    }

    // Get the next checkpoint coordinates
    final nextCheckpoint = checkpoints[_currentCheckpointIndex];
    final targetLat = nextCheckpoint['lat'] as double;
    final targetLng = nextCheckpoint['lng'] as double;

    // MATH: Calculate geodesic distance (accounts for Earth's curvature)
    // Returns distance in meters
    final double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      targetLat,
      targetLng,
    );

    // Fire distance update callback for UI
    onDistanceUpdate(distanceInMeters);

    // CHECK: Has the user reached this checkpoint? (50-meter geofence radius)
    if (distanceInMeters < 50) {
      // Trigger checkpoint reached callback
      onCheckpointReached(_currentCheckpointIndex);

      // Move to next checkpoint for future calculations
      _currentCheckpointIndex++;
    }
  }

  /// Recovery method: restart location stream if it crashes
  Future<void> _restartLocationStream(List<Map<String, dynamic>> checkpoints) async {
    print('Attempting to restart location stream...');
    try {
      stopTracking();
      await Future.delayed(Duration(seconds: 3));
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 20,
        timeLimit: Duration(seconds: 45),
      );
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _handlePositionUpdate(position, checkpoints);
        },
        onError: (Object e) {
          print('Guardian Logic Error (restart): $e');
          if (e.toString().contains('DeadSystemException')) {
            _fallbackToMockLocations(checkpoints);
          }
          _isRestarting = false;
        },
      );
      _isRestarting = false;
    } catch (e) {
      print('Failed to restart location stream: $e');
      _fallbackToMockLocations(checkpoints);
      _isRestarting = false;
    }
  }

  /// Start sending location updates to backend every 60 seconds
  void _startBackendLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 60), (_) async {
      if (_routeId != null && _lastPosition != null) {
        try {
          await ApiService.sendLocationUpdate(
            routeId: _routeId!,
            lat: _lastPosition!.latitude,
            lng: _lastPosition!.longitude,
          );
          print('Location update sent to backend: ${_lastPosition!.latitude}, ${_lastPosition!.longitude}');
        } catch (e) {
          print('Failed to send location update to backend: $e');
          // Don't crash Guardian Mode if backend is unavailable
        }
      }
    });
  }

  /// Stops GPS tracking and cleans up resources
  /// IMPORTANT: Call this when monitoring ends to save battery
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _mockPositionTimer?.cancel();
    _mockPositionTimer = null;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _useMockLocations = false;
    _routeId = null;
    _lastPosition = null;
  }

  /// Cleanup on disposal
  void dispose() {
    stopTracking();
  }
}
