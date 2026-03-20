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

  // ── Setup State ──
  final _tripNameController = TextEditingController();
  int _selectedDurationMins = 30;
  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120];
  List<Map<String, String>> _contacts = [];
  final Set<int> _selectedContactIndices = {};
  bool _loadingContacts = true;

  // ── Active Trip State ──
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _scoreRefreshTimer;
  final Set<Marker> _checkpoints = <Marker>{};
  int _checkpointSeed = 0;
  String? _selectedCheckpointId;
  int? _backendSafetyScore;
  String _backendSafetyStatus = '';
  bool _isFetchingBackendScore = false;

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
    super.dispose();
  }

  void _startBackendScoreRefresh() {
    _scoreRefreshTimer?.cancel();
    _scoreRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isFetchingBackendScore) return;
      _fetchBackendSafetyScore();
    });
  }

  Future<void> _fetchBackendSafetyScore() async {
    if (_isFetchingBackendScore) return;
    _isFetchingBackendScore = true;

    try {
      final battery = Battery();
      final batteryLevel = await battery.batteryLevel;

      Position? position;
      var isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (isLocationEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        final hasPermission = permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever;
        if (hasPermission) {
          try {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 8),
            );
          } catch (_) {
            position = await Geolocator.getLastKnownPosition();
          }
        } else {
          isLocationEnabled = false;
        }
      }

      final token = await AuthService.getToken();
      final response = await ApiService.fetchSafetyScore(
        latitude: position?.latitude ?? _initialMapCamera.target.latitude,
        longitude: position?.longitude ?? _initialMapCamera.target.longitude,
        batteryLevel: batteryLevel,
        isLocationEnabled: isLocationEnabled && position != null,
        isSafePathActive: _isTripActive,
        jwt: token.isEmpty ? null : token,
      );

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
    setState(() {
      _isTripActive = true;
      _remainingSeconds = _selectedDurationMins * 60;
    });
    _fetchBackendSafetyScore();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        // TODO: Trigger SOS / timeout alert
        return;
      }
      if (mounted) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _endTrip() {
    _countdownTimer?.cancel();
    setState(() {
      _isTripActive = false;
      _remainingSeconds = 0;
    });
    _fetchBackendSafetyScore();
  }

  void _addTime(int minutes) {
    setState(() {
      _remainingSeconds += minutes * 60;
    });
  }

  void _dropCheckpoint() {
    _addCheckpointAt(_initialMapCamera.target, animateCamera: true);
  }

  void _addCheckpointAt(LatLng position, {bool animateCamera = false}) {
    final id = 'checkpoint_${_checkpointSeed++}';
    final markerId = MarkerId(id);

    setState(() {
      _selectedCheckpointId = id;
      _checkpoints
        ..removeWhere((m) => m.markerId == markerId)
        ..add(
          Marker(
            markerId: markerId,
            position: position,
            infoWindow: InfoWindow(title: 'Checkpoint $_checkpointSeed'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
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
  }

  Future<void> _onMapTap(LatLng position) async {
    _addCheckpointAt(position, animateCamera: false);
  }

  void _selectCheckpoint(String checkpointId) {
    setState(() {
      _selectedCheckpointId = checkpointId;
      final updated = _checkpoints
          .map(
            (marker) => marker.copyWith(
              iconParam: BitmapDescriptor.defaultMarkerWithHue(
                marker.markerId.value == checkpointId
                    ? BitmapDescriptor.hueAzure
                    : BitmapDescriptor.hueRed,
              ),
            ),
          )
          .toSet();

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
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: _onMapTap,
                    markers: _checkpoints,
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

          const SizedBox(height: 20),

          // ── Emergency Contacts ──
          const Text('NOTIFY CONTACTS',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
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
              icon: const Icon(Icons.navigation_rounded, size: 24),
              label: const Text(
                'START TRIP & NOTIFY CONTACTS',
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
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: _onMapTap,
                    markers: _checkpoints,
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

          // ── Action Buttons Row ──
          Row(
            children: [
              // I'M SAFE Button (biggest)
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _endTrip,
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
