import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/core/services/api_service.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';

class SafePathSchedulerScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SafePathSchedulerScreen({super.key, this.onBack});

  @override
  State<SafePathSchedulerScreen> createState() =>
      _SafePathSchedulerScreenState();
}

class _SafePathSchedulerScreenState extends State<SafePathSchedulerScreen> {
  static const CameraPosition _initialMapCamera = CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 14,
  );

  // ── State toggle ──
  bool _isTripActive = false;
  bool _isStartingTrip = false;

  // ── Setup State ──
  final _tripNameController = TextEditingController();
  int _selectedDurationMins = 30;
  final List<int> _durationOptions = [15, 30, 45, 60];
  List<Map<String, String>> _contacts = [];
  final Set<int> _selectedContactIndices = {};
  bool _loadingContacts = true;

  // ── Active Trip State ──
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _scoreRefreshTimer;
  StreamSubscription<Position>? _tripLocationSubscription;
  final Set<Marker> _checkpoints = <Marker>{};
  final List<String> _checkpointOrder = <String>[];
  final Map<String, LatLng> _checkpointLocations = <String, LatLng>{};
  int _checkpointSeed = 0;
  String? _selectedCheckpointId;
  final Set<String> _passedCheckpointIds = <String>{};
  final Set<String> _checkpointAlertInFlight = <String>{};
  String? _activeTripId;
  Position? _lastTrackedPosition;
  int? _backendSafetyScore;
  String _backendSafetyStatus = '';
  bool _isFetchingBackendScore = false;

  static const double _checkpointPassRadiusMeters = 70;

  List<Map<String, dynamic>> get _orderedCheckpointPayload {
    final payload = <Map<String, dynamic>>[];
    for (var i = 0; i < _checkpointOrder.length; i++) {
      final id = _checkpointOrder[i];
      final location = _checkpointLocations[id];
      if (location == null) continue;
      payload.add({
        'index': i,
        'order': i + 1,
        'lat': location.latitude,
        'lng': location.longitude,
      });
    }
    return payload;
  }

  List<String> get _selectedContactIds {
    final ids = <String>[];
    for (final idx in _selectedContactIndices) {
      if (idx < 0 || idx >= _contacts.length) continue;
      final id = (_contacts[idx]['contactId'] ?? '').trim();
      if (id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  String get _selectedContactsSummary {
    if (_selectedContactIndices.isEmpty) return 'No contacts selected';
    final names = <String>[];
    for (final idx in _selectedContactIndices) {
      if (idx < 0 || idx >= _contacts.length) continue;
      final name = (_contacts[idx]['name'] ?? '').trim();
      if (name.isNotEmpty) names.add(name);
    }
    if (names.isEmpty) return 'Contacts selected';
    return names.join(', ');
  }

  int get _configuredTripSeconds => _selectedDurationMins * 60;

  int get _fallbackSafetyScore {
    final baseline = 35;
    final totalTripSeconds = math.max(1, _configuredTripSeconds);
    final activeSeconds = _isTripActive ? _remainingSeconds : totalTripSeconds;

    final timeRatio = (activeSeconds / totalTripSeconds).clamp(0.0, 1.0);
    final timeScore = (timeRatio * 40).round();
    final contactScore = math.min(_selectedContactIndices.length, 5) * 5;
    final checkpointScore = math.min(_checkpoints.length, 4) * 3;

    final lowTimePenalty = _isTripActive && _remainingSeconds < 180 ? 15 : 0;
    final criticalTimePenalty =
        _isTripActive && _remainingSeconds < 60 ? 10 : 0;

    final rawScore = baseline +
        timeScore +
        contactScore +
        checkpointScore -
        lowTimePenalty -
        criticalTimePenalty;
    return rawScore.clamp(0, 100);
  }

  int get _liveSafetyScore => _backendSafetyScore ?? _fallbackSafetyScore;

  String get _liveSafetyLabel {
    final backendStatus = _backendSafetyStatus.trim().toUpperCase();
    if (backendStatus.isNotEmpty &&
        backendStatus != 'UNKNOWN' &&
        backendStatus != 'CALCULATING...') {
      return backendStatus;
    }

    if (_liveSafetyScore >= 80) return 'GOOD';
    if (_liveSafetyScore >= 60) return 'CAUTION';
    return 'CRITICAL';
  }

  Color get _liveSafetyColor {
    final normalized = _backendSafetyStatus.toLowerCase();
    if (normalized.contains('safe') || normalized.contains('success')) {
      return AppColors.success;
    }
    if (normalized.contains('caution') || normalized.contains('moderate')) {
      return const Color(0xFFFFC658);
    }
    if (normalized.contains('high risk') || normalized.contains('danger')) {
      return AppColors.alert;
    }

    if (_liveSafetyScore >= 80) return AppColors.success;
    if (_liveSafetyScore >= 60) return const Color(0xFFFFC658);
    return AppColors.alert;
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _fetchBackendSafetyScore();
    _startBackendScoreRefresh();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _tripNameController.dispose();
    _countdownTimer?.cancel();
    _scoreRefreshTimer?.cancel();
    _tripLocationSubscription?.cancel();
    super.dispose();
  }

  void _startBackendScoreRefresh() {
    _scoreRefreshTimer?.cancel();
    _scoreRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isFetchingBackendScore) return;
      _fetchBackendSafetyScore(position: _lastTrackedPosition);
    });
  }

  Future<void> _fetchBackendSafetyScore({Position? position}) async {
    if (_isFetchingBackendScore) return;
    _isFetchingBackendScore = true;

    try {
      Position? safePosition = position;

      if (safePosition == null) {
        final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
        if (isLocationEnabled) {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          final hasPermission = permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever;
          if (hasPermission) {
            try {
              safePosition = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium,
                timeLimit: const Duration(seconds: 8),
              );
            } catch (_) {
              safePosition = await Geolocator.getLastKnownPosition();
            }
          }
        }
      }

      final token = await AuthService.getToken();
      Map<String, dynamic> response;
      if (_isTripActive && safePosition != null) {
        response = await ApiService.fetchGuardianSafetyScore(
          lat: safePosition.latitude,
          lng: safePosition.longitude,
          jwt: token.isEmpty ? null : token,
        );
      } else {
        final battery = Battery();
        final batteryLevel = await battery.batteryLevel;
        response = await ApiService.fetchSafetyScore(
          latitude: safePosition?.latitude ?? _initialMapCamera.target.latitude,
          longitude:
              safePosition?.longitude ?? _initialMapCamera.target.longitude,
          batteryLevel: batteryLevel,
          isLocationEnabled: safePosition != null,
          isSafePathActive: _isTripActive,
          jwt: token.isEmpty ? null : token,
        );
      }

      final rawScore = response['score'];
      int? parsedScore;
      if (rawScore is num) {
        parsedScore = rawScore.toInt();
      } else {
        parsedScore = int.tryParse(rawScore?.toString() ?? '');
      }

      if (mounted) {
        setState(() {
          _backendSafetyScore = parsedScore;
          _backendSafetyStatus = response['status']?.toString() ?? '';
        });
      }
    } catch (_) {
      // Keep UI responsive with local fallback score if backend request fails.
    } finally {
      _isFetchingBackendScore = false;
    }
  }

  Future<void> _loadContacts() async {
    try {
      final remote = await AuthService.fetchContacts();
      if (!mounted) return;
      setState(() {
        _contacts = remote
            .map((e) => <String, String>{
                  'contactId': (e['contactId'] ?? '').toString(),
                  'name': (e['name'] ?? '').toString(),
                  'phone': (e['phone'] ?? '').toString(),
                })
            .toList();
        _loadingContacts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingContacts = false);
    }
  }

  Future<void> _handleBack() async {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    await Navigator.of(context).maybePop();
  }

  void _startTrip() {
    if (_isStartingTrip) return;

    final tripName = _tripNameController.text.trim();
    if (tripName.isEmpty) {
      _showSnack('Trip name is required.', isError: true);
      return;
    }
    if (_selectedDurationMins <= 0) {
      _showSnack('Select an ETA to continue.', isError: true);
      return;
    }
    if (_checkpointOrder.isEmpty) {
      _showSnack('Add at least one checkpoint.', isError: true);
      return;
    }
    if (_selectedContactIndices.isEmpty) {
      _showSnack('Select at least one trusted contact.', isError: true);
      return;
    }

    _startTripFlow();
  }

  Future<void> _startTripFlow() async {
    setState(() => _isStartingTrip = true);

    final tripName = _tripNameController.text.trim();
    final contactIds = _selectedContactIds;
    if (contactIds.isEmpty) {
      setState(() => _isStartingTrip = false);
      _showSnack(
        'Selected contacts are missing contact IDs. Re-add contacts and retry.',
        isError: true,
      );
      return;
    }

    try {
      final token = await AuthService.getToken();
      final trackResponse = await ApiService.startGuardianTracking(
        tripName: tripName,
        etaMinutes: _selectedDurationMins,
        checkpoints: _orderedCheckpointPayload,
        contactIds: contactIds,
        jwt: token.isEmpty ? null : token,
      );

      final dynamic rawTripId = trackResponse['tripId'] ??
          trackResponse['id'] ??
          trackResponse['data']?['tripId'];
      final tripId = rawTripId?.toString() ?? '';
      if (tripId.isEmpty) {
        throw Exception('Backend did not return tripId.');
      }

      if (!mounted) return;
      setState(() {
        _activeTripId = tripId;
        _isTripActive = true;
        _remainingSeconds = _selectedDurationMins * 60;
        _passedCheckpointIds.clear();
        _checkpointAlertInFlight.clear();
      });
      _refreshCheckpointMarkerColors();

      _showSnack(
        'Trip started and contacts notified successfully.',
        isError: false,
      );

      _fetchBackendSafetyScore();
      await _startTripLocationTracking();

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _endTrip(reason: 'ETA expired', sendCompletionAlert: true);
          return;
        }
        if (mounted) {
          setState(() => _remainingSeconds--);
        }
      });
    } catch (error) {
      _showRetrySnack(
        message: 'Failed to start trip. Please retry.',
        onRetry: _startTripFlow,
      );
    } finally {
      if (mounted) {
        setState(() => _isStartingTrip = false);
      }
    }
  }

  Future<void> _endTrip({
    String reason = 'Trip completed',
    bool sendCompletionAlert = true,
  }) async {
    setState(() {
      _isTripActive = false;
      _remainingSeconds = 0;
    });

    _countdownTimer?.cancel();
    await _stopTripLocationTracking();

    if (sendCompletionAlert && (_activeTripId ?? '').isNotEmpty) {
      final fallback = _checkpointOrder.isNotEmpty
          ? _checkpointLocations[_checkpointOrder.last]
          : _initialMapCamera.target;
      final completionLat =
          _lastTrackedPosition?.latitude ?? fallback?.latitude ?? 0;
      final completionLng =
          _lastTrackedPosition?.longitude ?? fallback?.longitude ?? 0;

      try {
        final token = await AuthService.getToken();
        await ApiService.sendGuardianAlert(
          tripId: _activeTripId!,
          lat: completionLat,
          lng: completionLng,
          message: reason,
          jwt: token.isEmpty ? null : token,
        );
      } catch (_) {
        _showRetrySnack(
          message: 'Failed to send completion alert. Please retry.',
          onRetry: () => _endTrip(reason: reason, sendCompletionAlert: true),
        );
      }
    }

    setState(() {
      _passedCheckpointIds.clear();
      _checkpointAlertInFlight.clear();
      _activeTripId = null;
      _lastTrackedPosition = null;
    });
    _refreshCheckpointMarkerColors();
    _fetchBackendSafetyScore();

    if (mounted) {
      _showSnack(reason, isError: false);
    }
  }

  Future<void> _startTripLocationTracking() async {
    await _tripLocationSubscription?.cancel();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack(
        'Location services are disabled. Enable location to continue tracking.',
        isError: true,
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final hasPermission = permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
    if (!hasPermission) {
      _showSnack(
        'Location permission denied. Grant permission for SafePath tracking.',
        isError: true,
      );
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );

    _tripLocationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _handleLivePosition,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _stopTripLocationTracking() async {
    await _tripLocationSubscription?.cancel();
    _tripLocationSubscription = null;
  }

  void _handleLivePosition(Position currentPosition) {
    _lastTrackedPosition = currentPosition;
    _fetchBackendSafetyScore(position: currentPosition);

    if (!_isTripActive || _checkpoints.isEmpty) return;

    for (final marker in _checkpoints.toList(growable: false)) {
      final checkpointId = marker.markerId.value;
      if (_passedCheckpointIds.contains(checkpointId) ||
          _checkpointAlertInFlight.contains(checkpointId)) {
        continue;
      }

      final distance = _haversineDistanceMeters(
        currentPosition.latitude,
        currentPosition.longitude,
        marker.position.latitude,
        marker.position.longitude,
      );

      if (distance <= _checkpointPassRadiusMeters) {
        _onCheckpointPassed(
          marker: marker,
          currentPosition: currentPosition,
          distanceMeters: distance,
        );
      }
    }
  }

  Future<void> _onCheckpointPassed({
    required Marker marker,
    required Position currentPosition,
    required double distanceMeters,
  }) async {
    final checkpointId = marker.markerId.value;
    _checkpointAlertInFlight.add(checkpointId);

    if (mounted) {
      setState(() {
        _passedCheckpointIds.add(checkpointId);
      });
      _refreshCheckpointMarkerColors();
    }

    try {
      await _notifyCheckpointPassed(
        checkpointId: checkpointId,
        markerPosition: marker.position,
        currentPosition: currentPosition,
        distanceMeters: distanceMeters,
      );

      if (_passedCheckpointIds.length >= _checkpointOrder.length &&
          _checkpointOrder.isNotEmpty) {
        await _endTrip(
          reason: 'Trip completed: all checkpoints reached',
          sendCompletionAlert: true,
        );
      }
    } finally {
      _checkpointAlertInFlight.remove(checkpointId);
    }
  }

  Future<void> _notifyCheckpointPassed({
    required String checkpointId,
    required LatLng markerPosition,
    required Position currentPosition,
    required double distanceMeters,
  }) async {
    final tripId = _activeTripId;
    if (tripId == null || tripId.isEmpty) return;

    final tripName = _tripNameController.text.trim().isEmpty
        ? 'SafePath Trip'
        : _tripNameController.text.trim();
    final checkpointLabel = checkpointId.replaceFirst('checkpoint_', '#');
    final reachedAt = DateTime.now().toIso8601String();

    final message =
        '$tripName update: I passed checkpoint $checkpointLabel. Current location: '
        '${currentPosition.latitude.toStringAsFixed(6)}, ${currentPosition.longitude.toStringAsFixed(6)}. '
        'Checkpoint: ${markerPosition.latitude.toStringAsFixed(6)}, ${markerPosition.longitude.toStringAsFixed(6)}. '
        'Distance ${distanceMeters.toStringAsFixed(0)}m. Time: $reachedAt';

    final checkpointIndex = _checkpointOrder.indexOf(checkpointId);

    try {
      final token = await AuthService.getToken();
      await ApiService.sendGuardianAlert(
        tripId: tripId,
        checkpointIndex: checkpointIndex >= 0 ? checkpointIndex : null,
        lat: currentPosition.latitude,
        lng: currentPosition.longitude,
        message: message,
        jwt: token.isEmpty ? null : token,
      );
    } catch (_) {
      _showRetrySnack(
        message: 'Checkpoint alert failed. Retry suggested.',
        onRetry: () => _notifyCheckpointPassed(
          checkpointId: checkpointId,
          markerPosition: markerPosition,
          currentPosition: currentPosition,
          distanceMeters: distanceMeters,
        ),
      );
    }

    if (!mounted) return;
    final snack = 'Checkpoint $checkpointLabel reached and backend alerted.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(snack)));
  }

  void _addTime(int minutes) {
    setState(() {
      _remainingSeconds += minutes * 60;
    });
  }

  Future<void> _dropCheckpoint() async {
    if (_mapController == null) {
      _addCheckpointAt(_initialMapCamera.target, animateCamera: true);
      return;
    }

    try {
      final bounds = await _mapController!.getVisibleRegion();
      final center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );
      _addCheckpointAt(center, animateCamera: true);
    } catch (_) {
      _addCheckpointAt(_initialMapCamera.target, animateCamera: true);
    }
  }

  void _addCheckpointAt(LatLng position, {bool animateCamera = false}) {
    final id = 'checkpoint_${_checkpointSeed++}';
    final markerId = MarkerId(id);

    setState(() {
      _selectedCheckpointId = id;
      _checkpointOrder.add(id);
      _checkpointLocations[id] = position;
      _checkpoints
        ..removeWhere((m) => m.markerId == markerId)
        ..add(
          Marker(
            markerId: markerId,
            position: position,
            infoWindow:
                InfoWindow(title: 'Checkpoint ${_checkpointOrder.length}'),
            icon: _markerHueForCheckpoint(id),
            onTap: () => _selectCheckpoint(id),
          ),
        );
    });

    if (animateCamera && _mapController != null) {
      // The map animates to the newest checkpoint so user can immediately verify it.
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(position),
      );
    }

    _showSnack('${_checkpointLabel(id)} added on map.', isError: false);
  }

  Future<void> _onMapTap(LatLng position) async {
    _addCheckpointAt(position, animateCamera: false);
  }

  Future<void> _onMapLongPress(LatLng position) async {
    _addCheckpointAt(position, animateCamera: false);
  }

  void _selectCheckpoint(String checkpointId) {
    setState(() {
      _selectedCheckpointId = checkpointId;
    });
    _refreshCheckpointMarkerColors();
  }

  BitmapDescriptor _markerHueForCheckpoint(String checkpointId) {
    if (_passedCheckpointIds.contains(checkpointId)) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
    if (_selectedCheckpointId == checkpointId) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  void _refreshCheckpointMarkerColors() {
    if (_checkpoints.isEmpty) return;
    final updated = _checkpoints
        .map(
          (marker) => marker.copyWith(
            iconParam: _markerHueForCheckpoint(marker.markerId.value),
          ),
        )
        .toSet();

    if (!mounted) return;
    setState(() {
      _checkpoints
        ..clear()
        ..addAll(updated);
    });
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  GoogleMapController? _mapController;

  Set<Circle> get _checkpointCircles {
    final circles = <Circle>{};
    for (final id in _checkpointOrder) {
      final location = _checkpointLocations[id];
      if (location == null) continue;

      final isPassed = _passedCheckpointIds.contains(id);
      final isSelected = _selectedCheckpointId == id;
      final color = isPassed
          ? AppColors.success
          : (isSelected ? const Color(0xFFFFC658) : AppColors.primary);

      circles.add(
        Circle(
          circleId: CircleId('cp_circle_$id'),
          center: location,
          radius: _checkpointPassRadiusMeters,
          fillColor: color.withOpacity(0.14),
          strokeColor: color.withOpacity(0.7),
          strokeWidth: 2,
        ),
      );
    }
    return circles;
  }

  String _checkpointLabel(String checkpointId) {
    final index = _checkpointOrder.indexOf(checkpointId);
    if (index < 0) return 'CP ?';
    return 'CP ${index + 1}';
  }

  double _haversineDistanceMeters(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(endLat - startLat);
    final dLng = _degToRad(endLng - startLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(startLat)) *
            math.cos(_degToRad(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double degree) => degree * (math.pi / 180);

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.alert : AppColors.success,
      ),
    );
  }

  void _showRetrySnack({
    required String message,
    required Future<void> Function() onRetry,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message Please retry.'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            onRetry();
          },
        ),
      ),
    );
  }

  Future<void> _confirmEndTrip({required String reason}) async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'End Trip?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'This will stop live tracking and notify contacts that your trip is completed.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.alert,
                foregroundColor: Colors.white,
              ),
              child: const Text('End Trip'),
            ),
          ],
        );
      },
    );

    if (shouldEnd == true) {
      await _endTrip(reason: reason, sendCompletionAlert: true);
    }
  }

  Widget _buildCheckpointProgressPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Checkpoint Progress',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '${_passedCheckpointIds.length}/${_checkpointOrder.length}',
                style: TextStyle(
                  color: _checkpointOrder.isEmpty
                      ? AppColors.textSecondary
                      : AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_checkpointOrder.isEmpty)
            const Text(
              'No checkpoints added yet.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _checkpointOrder.length; i++)
                  _buildCheckpointBadge(i, _checkpointOrder[i]),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCheckpointBadge(int index, String checkpointId) {
    final isPassed = _passedCheckpointIds.contains(checkpointId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isPassed
            ? AppColors.success.withOpacity(0.2)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPassed
              ? AppColors.success.withOpacity(0.6)
              : AppColors.border.withOpacity(0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPassed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            size: 14,
            color: isPassed ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            'CP ${index + 1}',
            style: TextStyle(
              color: isPassed ? AppColors.success : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupCheckpointStrip() {
    if (_checkpointOrder.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
        ),
        child: const Text(
          'No checkpoints selected. Tap or long-press the map to add one.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _checkpointOrder.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final id = _checkpointOrder[index];
          final location = _checkpointLocations[id];
          final isSelected = _selectedCheckpointId == id;
          final subtitle = location == null
              ? ''
              : '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
          return GestureDetector(
            onTap: () => _selectCheckpoint(id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.22)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border.withOpacity(0.55),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _checkpointLabel(id),
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isTripActive ? 'Trip Active' : 'SafePath Setup',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        leading: _isTripActive
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary, size: 20),
                onPressed: _handleBack,
              ),
      ),
      body: SafeArea(
        child: _isTripActive ? _buildActiveTripView() : _buildSetupView(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // STATE 1: SETUP SCREEN
  // ═══════════════════════════════════════════════════════
  Widget _buildSetupView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Trip Name ──
          const Text('Trip Name',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _tripNameController,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'e.g. Walking to the car',
              hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.6),
                  fontWeight: FontWeight.w400),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: AppColors.border.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              prefixIcon: const Icon(Icons.edit_road_rounded,
                  color: AppColors.textSecondary, size: 22),
            ),
          ),

          const SizedBox(height: 24),

          // ── Duration / ETA ──
          const Text('Duration / ETA',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _durationOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final mins = _durationOptions[index];
                final isSelected = mins == _selectedDurationMins;
                final label = mins >= 60 ? '${mins ~/ 60} hr' : '$mins min';
                return GestureDetector(
                  onTap: () => setState(() => _selectedDurationMins = mins),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── Setup Map + Checkpoints ──
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: _initialMapCamera,
                    myLocationButtonEnabled: true,
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: _onMapTap,
                    onLongPress: _onMapLongPress,
                    markers: _checkpoints,
                    circles: _checkpointCircles,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: ElevatedButton.icon(
                      onPressed: _dropCheckpoint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16233A),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.fiber_manual_record,
                          size: 10, color: Color(0xFF13C48A)),
                      label: const Text(
                        'DROP CHECKPOINTS',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_checkpoints.length} checkpoint${_checkpoints.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          _buildSetupCheckpointStrip(),

          const SizedBox(height: 20),

          // ── Emergency Contacts ──
          const Text('NOTIFY CONTACTS',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 10),
          Text(
            _selectedContactsSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _selectedContactIndices.isEmpty
                  ? AppColors.alert
                  : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: _loadingContacts
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary)))
                : _contacts.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.alert.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.alert.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: AppColors.alert.withOpacity(0.9),
                                size: 18),
                            const SizedBox(width: 8),
                            Text('No trusted contacts yet',
                                style: TextStyle(
                                    color: AppColors.alert.withOpacity(0.9),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _contacts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final name = _contacts[index]['name'] ?? '?';
                          final isSelected =
                              _selectedContactIndices.contains(index);
                          return FilterChip(
                            label: Text(name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedContactIndices.add(index);
                                } else {
                                  _selectedContactIndices.remove(index);
                                }
                              });
                            },
                            selectedColor: AppColors.primary.withOpacity(0.3),
                            backgroundColor: AppColors.surface,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border.withOpacity(0.5),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            avatar: CircleAvatar(
                              backgroundColor: isSelected
                                  ? AppColors.primary
                                  : AppColors.surfaceElevated,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            showCheckmark: false,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                          );
                        },
                      ),
          ),

          const SizedBox(height: 20),

          // ── Start Trip Button ──
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _startTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              icon: _isStartingTrip
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.navigation_rounded, size: 24),
              label: Text(
                _isStartingTrip
                    ? 'STARTING...'
                    : 'START TRIP & NOTIFY CONTACTS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 120), // Bottom nav clearance
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // STATE 2: ACTIVE TRIP SCREEN
  // ═══════════════════════════════════════════════════════
  Widget _buildActiveTripView() {
    final tripName = _tripNameController.text.trim().isNotEmpty
        ? _tripNameController.text.trim()
        : 'Active Trip';
    final isUrgent = _remainingSeconds < 300; // < 5 mins = urgent
    final score = _liveSafetyScore;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ── Trip Info ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.navigation_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tripName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? AppColors.alert.withOpacity(0.2)
                        : AppColors.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isUrgent ? 'LOW TIME' : 'ACTIVE',
                    style: TextStyle(
                      color: isUrgent ? AppColors.alert : AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Live Safety Score ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  AppColors.primary.withOpacity(0.08),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.35)),
            ),
            child: Column(
              children: [
                const Text(
                  'LIVE SAFETY SCORE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$score',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _liveSafetyColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: _liveSafetyColor.withOpacity(0.35)),
                  ),
                  child: Text(
                    _liveSafetyLabel,
                    style: TextStyle(
                      color: _liveSafetyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Massive Countdown Timer ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isUrgent
                    ? [
                        AppColors.alert.withOpacity(0.15),
                        AppColors.alert.withOpacity(0.05)
                      ]
                    : [
                        AppColors.primary.withOpacity(0.15),
                        AppColors.primary.withOpacity(0.05)
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isUrgent
                    ? AppColors.alert.withOpacity(0.3)
                    : AppColors.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'TIME REMAINING',
                  style: TextStyle(
                    color: isUrgent ? AppColors.alert : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatTime(_remainingSeconds),
                  style: TextStyle(
                    color: isUrgent ? AppColors.alert : AppColors.textPrimary,
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Live Map + Checkpoints ──
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: _initialMapCamera,
                    myLocationButtonEnabled: true,
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: _onMapTap,
                    onLongPress: _onMapLongPress,
                    markers: _checkpoints,
                    circles: _checkpointCircles,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: ElevatedButton.icon(
                      onPressed: _dropCheckpoint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16233A),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.fiber_manual_record,
                          size: 10, color: Color(0xFF13C48A)),
                      label: const Text(
                        'DROP CHECKPOINTS',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  if (_selectedCheckpointId != null)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Selected: ${_selectedCheckpointId!.replaceFirst('checkpoint_', '#')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Bottom Feature Bars ──
          _buildFeatureBar(
            title: 'SafePath Navigation',
            icon: Icons.navigation_rounded,
            value: _checkpoints.isNotEmpty ? 'Enabled' : 'Standby',
            valueColor: _checkpoints.isNotEmpty
                ? AppColors.success
                : AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          _buildFeatureBar(
            title: 'Community Reports',
            icon: Icons.forum_rounded,
            value: _liveSafetyLabel,
            valueColor: _liveSafetyColor,
          ),
          const SizedBox(height: 10),
          _buildFeatureBar(
            title: 'SafePath Guardian Features',
            icon: Icons.shield_moon_rounded,
            value: _selectedContactIndices.isNotEmpty
                ? '${_selectedContactIndices.length} linked'
                : 'No contacts',
            valueColor: _selectedContactIndices.isNotEmpty
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          _buildCheckpointProgressPanel(),

          // ── Action Buttons Row ──
          Row(
            children: [
              // I'M SAFE Button (biggest)
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmEndTrip(
                      reason: 'Trip completed by user',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 22),
                    label: const Text(
                      "I'M SAFE",
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // +15 Min Button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _addTime(15),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.25),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      '+15 min',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
// SOS Button
              SizedBox(
                width: 56,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Trigger SOS
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.alert,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Icon(Icons.sos_rounded, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 120), // Bottom nav clearance
        ],
      ),
    );
  }

  Widget _buildFeatureBar({
    required String title,
    required IconData icon,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
