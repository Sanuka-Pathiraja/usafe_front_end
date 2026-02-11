import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// GuardianLogic handles real GPS tracking for Guardian Mode.
/// 
/// This class:
/// - Listens to real-time GPS stream from the child's device
/// - Calculates distance to the next checkpoint using geodesic (earth-curved) math
/// - Triggers callbacks when distance updates or checkpoint is reached
/// - Manages permissions and battery-efficient location updates
class GuardianLogic {
  /// Listens to live GPS position updates
  StreamSubscription<Position>? _positionStream;

  /// Callback fired when the user moves (distance to checkpoint updates)
  /// Parameter: distance in meters
  final Function(double distanceRemaining) onDistanceUpdate;

  /// Callback fired when user reaches a checkpoint (within 50m geofence)
  /// Parameter: index of the reached checkpoint
  final Function(int checkpointIndex) onCheckpointReached;

  /// Tracks current checkpoint index (which one we're heading toward)
  int _currentCheckpointIndex = 0;

  GuardianLogic({
    required this.onDistanceUpdate,
    required this.onCheckpointReached,
  });

  /// Starts real GPS tracking for Guardian Mode
  /// 
  /// This method:
  /// 1. Checks/requests location permissions
  /// 2. Starts listening to GPS stream
  /// 3. Continuously calculates distance to next checkpoint
  /// 4. Triggers callbacks on distance updates and checkpoint arrival
  /// 
  /// Parameters:
  /// - checkpoints: List of checkpoint maps with 'lat' and 'lng' keys
  /// - currentIndex: Starting checkpoint index (usually 0)
  Future<void> startTracking(
    List<Map<String, dynamic>> checkpoints,
    int currentIndex,
  ) async {
    _currentCheckpointIndex = currentIndex;

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

    // STEP 2: Configure location settings (battery-efficient)
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      // Only update if user moves 10+ meters (saves massive battery)
      distanceFilter: 10,
      timeLimit: Duration(seconds: 30), // Force update every 30s max
    );

    // STEP 3: Start listening to GPS stream
    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _handlePositionUpdate(position, checkpoints);
      },
      onError: (Object e) {
        // Handle errors gracefully (GPS loss, permission revoked, etc.)
        print('Guardian Logic Error: $e');
      },
    );
  }

  /// Internal handler for each GPS position update
  void _handlePositionUpdate(Position position, List<Map<String, dynamic>> checkpoints) {
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

  /// Updates the checkpoint index when user confirms arrival
  /// (Can be called manually if needed)
  void updateCheckpointIndex(int newIndex) {
    _currentCheckpointIndex = newIndex;
  }

  /// Stops GPS tracking and cleans up resources
  /// IMPORTANT: Call this when monitoring ends to save battery
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Cleanup on disposal
  void dispose() {
    stopTracking();
  }
}
