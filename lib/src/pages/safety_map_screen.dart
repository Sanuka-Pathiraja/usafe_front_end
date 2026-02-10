import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:usafe_front_end/src/services/audio_analysis_service.dart';
import 'package:usafe_front_end/src/services/live_safety_score_service.dart';
import 'package:usafe_front_end/src/services/motion_analysis_service.dart';

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({Key? key}) : super(key: key);

  @override
  _SafetyMapScreenState createState() => _SafetyMapScreenState();
}

class _LocationFetchResult {
  final LatLng position;
  final String source;
  final String? warning;

  const _LocationFetchResult(this.position, this.source, this.warning);
}

class _SafetyMapScreenState extends State<SafetyMapScreen> with SingleTickerProviderStateMixin {
  late GoogleMapController _mapController;
  String _darkMapStyle = '';

  // Animation for pulsing danger zones.
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isSafetyModeActive = false;
  bool _isAudioListening = false;
  bool _isMotionListening = false;
  bool _isDangerCountdownActive = false;
  Timer? _dangerTimer;
  int _dangerSeconds = 10;
  bool _audioReady = false;
  bool _isDangerDialogOpen = false;
  StateSetter? _dangerDialogSetState;
  String _micStatusText = 'Safety Mode Off';
  Color _micStatusColor = Colors.white70;
  final AudioAnalysisService _audioService = AudioAnalysisService();
  final MotionAnalysisService _motionService = MotionAnalysisService();

  // Live Safety Score (dynamic, from external APIs)
  final SafetyScoreInputsProvider _scoreProvider = SafetyScoreInputsProvider();
  LiveSafetyScoreResult? _liveScoreResult;
  String? _scoreDataSource; // e.g. "sunrise-sunset, openstreetmap"
  String? _scoreError; // null when last fetch succeeded
  String? _scoreWarning; // non-fatal warnings (e.g. fallback location)
  bool _scoreLoading = false;
  Timer? _scoreUpdateTimer;
  LatLng? _currentPosition;
  bool _scoreExpanded = false;
  String _locationSource = 'unknown';
  /// True when Safety Mode was auto-enabled by Red zone (Active Trigger). Used to return to passive in Green.
  bool _safetyModeAutoEnabled = false;

  // Initial camera: Sri Lanka (Colombo). App optimized for Sri Lanka.
  static final CameraPosition _kInitialPosition = const CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    // Prepare the dark map styling.
    _loadMapStyle();
    
    // Setup pulse animation for the high-risk circle.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 100, end: 300).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initAudioService();
    _initMotionService();
    _initLiveScore();
  }

  void _initLiveScore() {
    _updateLiveScore();
    _scoreUpdateTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _updateLiveScore();
    });
  }

  Future<void> _updateLiveScore() async {
    if (_scoreLoading) return;
    setState(() {
      _scoreLoading = true;
      _scoreError = null;
      _scoreWarning = null;
    });
    final locationResult = await _getScorePosition();
    if (!mounted) return;
    final position = locationResult.position;
    final safetyPosition = SafetyPosition(position.latitude, position.longitude);
    final previousZone = _liveScoreResult?.zone;
    if (locationResult.source == 'error' ||
        locationResult.source == 'fallback' ||
        locationResult.source == 'permission_denied' ||
        locationResult.source == 'permission_denied_forever' ||
        locationResult.source == 'gps_off') {
      setState(() {
        _scoreLoading = false;
        _currentPosition = position;
        _locationSource = locationResult.source;
        _scoreWarning = locationResult.warning ?? 'Location unavailable.';
        _scoreError = 'Cannot calculate without live location.';
      });
      return;
    }
    final fetchResult = await _scoreProvider.getScoreAt(position: safetyPosition);
    if (!mounted) return;
    setState(() {
      _scoreLoading = false;
      _currentPosition = position;
      _locationSource = locationResult.source;
      _scoreWarning = locationResult.warning;
      if (fetchResult.result != null) {
        _liveScoreResult = fetchResult.result;
        _scoreDataSource = fetchResult.dataSource;
        _scoreError = null;
      } else {
        _scoreError = fetchResult.error ?? 'Unable to update score';
      }
    });
    final result = fetchResult.result;
    if (result != null) {
      // Active Trigger: Red zone → silently warm start audio (per spec: "phone silently wakes up its sensors").
      if (result.isDanger && previousZone != SafetyZone.danger && !_isSafetyModeActive) {
        _warmStartMonitoring();
      }
      // Green zone: return to passive mode to save battery when we had auto-enabled in Red.
      if ((result.isSafe || result.isCaution) && previousZone == SafetyZone.danger && _safetyModeAutoEnabled) {
        _returnToPassiveMode();
      }
    }
  }

  Future<_LocationFetchResult> _getScorePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _fallbackLocation('gps_off', 'Location services are off.');
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) {
          return _fallbackLocation('permission_denied', 'Location permission denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return _fallbackLocation('permission_denied_forever', 'Location permission permanently denied.');
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      final lastKnownLatLng = lastKnown == null
          ? null
          : LatLng(lastKnown.latitude, lastKnown.longitude);

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        final current = LatLng(pos.latitude, pos.longitude);
        return _LocationFetchResult(current, 'gps', null);
      } catch (_) {
        if (lastKnownLatLng != null) {
          return _LocationFetchResult(lastKnownLatLng, 'last_known', 'Using last known location.');
        }
        return _fallbackLocation('fallback', 'Using fallback location.');
      }
    } catch (_) {
      return _fallbackLocation('error', 'Location unavailable.');
    }
  }

  _LocationFetchResult _fallbackLocation(String source, String warning) {
    final position = _currentPosition ?? _kInitialPosition.target;
    return _LocationFetchResult(position, source, warning);
  }

  /// Active Trigger: when score drops to Red, silently warm start monitoring
  /// (microphone and motion sensors wake up, ready to detect distress). No dialog—per spec.
  Future<void> _warmStartMonitoring() async {
    if (!mounted || _isSafetyModeActive) return;
    bool audioStarted = false;
    if (_audioReady) {
      audioStarted = await _audioService.startListening();
    }
    final motionStarted = await _motionService.startListening();
    if (!mounted) return;
    if (!audioStarted && !motionStarted) {
      _showStatusSnack(_audioService.lastError ?? 'Could not auto-enable monitoring.');
      return;
    }
    setState(() {
      _isSafetyModeActive = true;
      _isAudioListening = audioStarted;
      _isMotionListening = motionStarted;
      _safetyModeAutoEnabled = true;
      _micStatusText = audioStarted
          ? 'Auto: Listening (high-risk area)'
          : 'Auto: Motion monitoring (high-risk area)';
      _micStatusColor = Colors.redAccent;
    });
    if (audioStarted) {
      _showStatusSnack('High-risk area: monitoring auto-enabled. Mic is now listening for distress.');
    } else {
      _showStatusSnack('High-risk area: motion monitoring enabled. Mic unavailable.');
    }
  }

  /// Green zone: return to passive mode (mic off) to save battery when we had auto-enabled in Red.
  void _returnToPassiveMode() {
    if (!_safetyModeAutoEnabled || !_isSafetyModeActive) return;
    _audioService.stopListening();
    _motionService.stopListening();
    if (!mounted) return;
    setState(() {
      _isSafetyModeActive = false;
      _isAudioListening = false;
      _isMotionListening = false;
      _safetyModeAutoEnabled = false;
      _micStatusText = 'Safety Mode Off (passive)';
      _micStatusColor = Colors.white70;
    });
    _cancelDangerCountdown();
    _showStatusSnack('Back to safer area. Passive mode to save battery.');
  }

  Future<void> _initAudioService() async {
    final ok = await _audioService.initialize();
    if (!mounted) return;
    setState(() {
      _audioReady = ok;
      if (!ok) {
        _micStatusText = _audioService.lastError ?? 'Audio model unavailable.';
        _micStatusColor = Colors.orangeAccent;
      }
    });
    _audioService.onDistressDetected = (event, confidence) {
      if (!mounted) return;
      if (!_isSafetyModeActive) return;
      _startDangerCountdown(reason: event);
    };
  }

  void _initMotionService() {
    _motionService.onMotionDetected = (event, confidence) {
      if (!mounted) return;
      if (!_isSafetyModeActive) return;
      _startDangerCountdown(reason: event);
    };
  }

  Future<void> _toggleSafetyMode() async {
    if (_isSafetyModeActive) {
      setState(() {
        _isSafetyModeActive = false;
        _isAudioListening = false;
        _isMotionListening = false;
        _safetyModeAutoEnabled = false;
        _micStatusText = 'Safety Mode Off';
        _micStatusColor = Colors.white70;
      });
      await _audioService.stopListening();
      await _motionService.stopListening();
      _cancelDangerCountdown();
      return;
    }

    bool audioStarted = false;
    if (_audioReady) {
      audioStarted = await _audioService.startListening();
    }
    final motionStarted = await _motionService.startListening();
    if (!audioStarted && !motionStarted) {
      final message = _audioService.lastError ?? 'Microphone permission required.';
      _showStatusSnack(message);
      setState(() {
        _micStatusText = message;
        _micStatusColor = Colors.orangeAccent;
      });
      return;
    }

    setState(() {
      _isSafetyModeActive = true;
      _isAudioListening = audioStarted;
      _isMotionListening = motionStarted;
      _safetyModeAutoEnabled = false; // User chose to enable; don't auto-disable in Green.
      _micStatusText = audioStarted
          ? 'Listening for distress signals'
          : 'Motion monitoring only';
      _micStatusColor = Colors.redAccent;
    });

    if (audioStarted) {
      _showStatusSnack('Safety Mode Activated: Listening for distress signals...');
    } else {
      _showStatusSnack('Safety Mode Activated: Motion monitoring only.');
    }
  }

  void _startDangerCountdown({required String reason}) {
    if (_isDangerCountdownActive || !_isSafetyModeActive) return;

    setState(() {
      _isDangerCountdownActive = true;
      _dangerSeconds = 10;
      _micStatusText = 'Potential distress: $_dangerSeconds s';
      _micStatusColor = Colors.orangeAccent;
    });

    _dangerTimer?.cancel();
    _dangerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_dangerSeconds <= 1) {
        timer.cancel();
        setState(() {
          _isDangerCountdownActive = false;
          _dangerSeconds = 10;
          if (_isSafetyModeActive) {
            if (_isAudioListening) {
              _micStatusText = 'Listening for distress signals';
            } else if (_isMotionListening) {
              _micStatusText = 'Motion monitoring only';
            } else {
              _micStatusText = 'Safety Mode Off';
            }
            _micStatusColor = Colors.redAccent;
          }
        });
        _closeDangerDialog();
        _triggerAlarm(reason: reason);
        return;
      }
      setState(() {
        _dangerSeconds -= 1;
        _micStatusText = 'Potential distress: $_dangerSeconds s';
      });
      _dangerDialogSetState?.call(() {});
    });

    _isDangerDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dangerDialogSetState = setDialogState;
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                'Potential Distress Detected',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'Detected: $reason\n\nSOS will trigger in $_dangerSeconds seconds.\nAre you safe?',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _cancelDangerCountdown();
                  },
                  child: const Text("I'M SAFE",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _isDangerDialogOpen = false;
      _dangerDialogSetState = null;
    });
  }

  void _cancelDangerCountdown() {
    _dangerTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isDangerCountdownActive = false;
      _dangerSeconds = 10;
      if (_isSafetyModeActive) {
        if (_isAudioListening) {
          _micStatusText = 'Listening for distress signals';
        } else if (_isMotionListening) {
          _micStatusText = 'Motion monitoring only';
        } else {
          _micStatusText = 'Safety Mode Off';
        }
        _micStatusColor = Colors.redAccent;
      } else {
        _micStatusText = 'Safety Mode Off';
        _micStatusColor = Colors.white70;
      }
    });
    _closeDangerDialog();
  }

  void _triggerAlarm({required String reason}) {
    setState(() {
      _micStatusText = 'Distress detected';
      _micStatusColor = Colors.redAccent;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Text('DISTRESS DETECTED!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Detected signal: $reason\n\nTriggering Emergency Protocol...',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('CANCEL ALARM',
                style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('CALL SOS', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void _closeDangerDialog() {
    if (!_isDangerDialogOpen || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _isDangerDialogOpen = false;
    _dangerDialogSetState = null;
  }

  void _showStatusSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // Load custom JSON for Dark Mode map
  Future<void> _loadMapStyle() async {
    // You can paste a full JSON style here or load from assets/map_style.json
    // For now, this is a simplified dark style string
    _darkMapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [{"color": "#212121"}]
      },
      {
        "elementType": "labels.icon",
        "stylers": [{"visibility": "off"}]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#757575"}]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#212121"}]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [{"color": "#757575"}]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [{"color": "#181818"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [{"color": "#2c2c2c"}]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#8a8a8a"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#000000"}]
      }
    ]
    ''';
  }

  Set<Circle> _buildCircles(double pulseRadius) {
    // Example risk zones for Sri Lanka (Colombo area). Replace with real heat map data if needed.
    return {
      Circle(
        circleId: const CircleId('danger_zone_1'),
        center: const LatLng(6.9350, 79.8480),
        radius: pulseRadius,
        fillColor: const Color(0xFFE53935).withOpacity(0.3),
        strokeColor: const Color(0xFFE53935),
        strokeWidth: 2,
      ),
      Circle(
        circleId: const CircleId('moderate_zone_1'),
        center: const LatLng(6.9100, 79.8800),
        radius: 400,
        fillColor: Colors.orange.withOpacity(0.25),
        strokeColor: Colors.orange,
        strokeWidth: 1,
      ),
      Circle(
        circleId: const CircleId('safe_zone_1'),
        center: const LatLng(6.9500, 79.9000),
        radius: 500,
        fillColor: const Color(0xFF00E676).withOpacity(0.2),
        strokeColor: const Color(0xFF00E676),
        strokeWidth: 1,
      ),
    };
  }

  @override
  void dispose() {
    _scoreUpdateTimer?.cancel();
    _pulseController.dispose();
    _dangerTimer?.cancel();
    if (_isSafetyModeActive) {
      _audioService.stopListening();
      _motionService.stopListening();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // --- The Map ---
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return GoogleMap(
                initialCameraPosition: _kInitialPosition,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  if (_darkMapStyle.isNotEmpty) {
                    _mapController.setMapStyle(_darkMapStyle);
                  }
                },
                circles: _buildCircles(_pulseAnimation.value),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              );
            },
          ),

          // --- Top Overlay (Legend) ---
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem("High Risk", const Color(0xFFE53935)),
                  _buildLegendItem("Moderate", Colors.orange),
                  _buildLegendItem("Safe", const Color(0xFF00E676)),
                ],
              ),
            ),
          ),

          Positioned(
            top: 120,
            left: 20,
            child: _buildMicStatusPill(),
          ),

          // Live Safety Score card (dynamic 0–100, Green / Orange / Red)
          Positioned(
            top: 170,
            left: 20,
            right: 20,
            child: _buildLiveSafetyScoreCard(),
          ),

          // --- Bottom Floating Action Buttons ---
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "recenter",
                  backgroundColor: const Color(0xFF1E1E1E),
                  onPressed: () async {
                    final locationResult = await _getScorePosition();
                    if (!mounted) return;
                    _mapController.animateCamera(
                      CameraUpdate.newLatLng(locationResult.position),
                    );
                    _updateLiveScore();
                  },
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "safety_mode",
                  backgroundColor: _isSafetyModeActive
                      ? Colors.redAccent
                      : const Color(0xFF1E1E1E),
                  onPressed: _toggleSafetyMode,
                  child: Icon(
                    _isSafetyModeActive ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                FloatingActionButton.extended(
                  heroTag: "report",
                  backgroundColor: const Color(0xFFE53935),
                  onPressed: () {
                    // TODO: navigate to a report flow.
                  },
                  icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  label: const Text("Report Incident", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildMicStatusPill() {
    final icon = _isAudioListening
        ? Icons.hearing
        : (_isMotionListening ? Icons.sensors : Icons.mic_off);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _micStatusColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: _micStatusColor,
          ),
          const SizedBox(width: 6),
          Text(
            _micStatusText,
            style: TextStyle(color: _micStatusColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _scoreZoneColor(SafetyZone zone) {
    switch (zone) {
      case SafetyZone.safe:
        return AppColors.successGreen;
      case SafetyZone.caution:
        return Colors.orange;
      case SafetyZone.danger:
        return AppColors.alertRed;
    }
  }

  Widget _buildLiveSafetyScoreCard() {
    final result = _liveScoreResult;
    if (result == null && !_scoreLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
            SizedBox(width: 12),
            Text('Calculating…', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      );
    }
    if (result == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
            SizedBox(width: 12),
            Text('Fetching live data…', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      );
    }
    final zoneColor = _scoreZoneColor(result.zone);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _scoreExpanded = !_scoreExpanded),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: zoneColor.withOpacity(0.6), width: 1.5),
            boxShadow: [BoxShadow(color: zoneColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield, color: zoneColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Live Safety Score',
                    style: TextStyle(color: Colors.grey[300], fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  if (_scoreLoading) ...[
                    const SizedBox(width: 6),
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white54)),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: zoneColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${result.score}/100',
                      style: TextStyle(color: zoneColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    result.label,
                    style: TextStyle(color: zoneColor, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(_scoreExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white70, size: 20),
                ],
              ),
              if (_scoreError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _scoreError!,
                    style: TextStyle(color: Colors.orange[300], fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (_scoreWarning != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _scoreWarning!,
                    style: TextStyle(color: Colors.orange[200], fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (_scoreExpanded) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                _buildPillarRow('Time of day', result.breakdown.timeLight),
                _buildPillarRow('Isolation (low density)', result.breakdown.environment),
                _buildPillarRow('Distance to help', result.breakdown.proximity),
                _buildPillarRow('Past incidents (Sri Lanka)', result.breakdown.history),
                if (result.debugInfo != null) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
                  _buildDebugRow('Location source', _locationSource),
                  _buildDebugRow('Lat', result.debugInfo!.latitude.toStringAsFixed(5)),
                  _buildDebugRow('Lng', result.debugInfo!.longitude.toStringAsFixed(5)),
                  _buildDebugRow('District', result.debugInfo!.districtName ?? 'unknown'),
                  _buildDebugRow('Current time', _formatLocalTime(result.debugInfo!.localTime)),
                  _buildDebugRow('Population density', result.debugInfo!.populationDensity.toStringAsFixed(2)),
                  _buildDebugRow('Nearest police', _formatAmenity(
                    result.debugInfo!.nearestPoliceName,
                    result.debugInfo!.nearestPoliceDistanceMeters,
                  )),
                  _buildDebugRow('Nearest hospital', _formatAmenity(
                    result.debugInfo!.nearestHospitalName,
                    result.debugInfo!.nearestHospitalDistanceMeters,
                  )),
                  _buildDebugRow('Time penalty', '-${result.debugInfo!.timePenalty}'),
                  _buildDebugRow('Infra penalty', '-${result.debugInfo!.infraPenalty}'),
                  _buildDebugRow('Isolation penalty', '-${result.debugInfo!.isolationPenalty}'),
                  _buildDebugRow('Weather penalty', '-${result.debugInfo!.weatherPenalty}'),
                  _buildDebugRow('History penalty', '-${result.debugInfo!.historyPenalty}'),
                  _buildDebugRow('Police bonus', '+${result.debugInfo!.distanceBonus}'),
                  _buildDebugRow('Crowd bonus', '+${result.debugInfo!.crowdBonus}'),
                  _buildDebugRow('Traffic bonus', '+${result.debugInfo!.trafficBonus}'),
                  _buildDebugRow('Open venues bonus', '+${result.debugInfo!.openVenueBonus}'),
                  _buildDebugRow('Embassy bonus', '+${result.debugInfo!.embassyBonus}'),
                  _buildDebugRow('Total penalties', '-${result.debugInfo!.totalPenalties}'),
                  _buildDebugRow('Total mitigations', '+${result.debugInfo!.totalMitigations}'),
                  _buildDebugRow('Crowd density', result.debugInfo!.crowdDensity.toStringAsFixed(2)),
                  _buildDebugRow('Traffic congestion', result.debugInfo!.trafficCongestion.toStringAsFixed(2)),
                  _buildDebugRow('Venue count', '${result.debugInfo!.nearbyVenueCount}'),
                  _buildDebugRow('Open venues', '${result.debugInfo!.openVenueCount}'),
                  _buildDebugRow('Help distance', _formatDistance(result.debugInfo!.distanceToHelpMeters)),
                  _buildDebugRow('Side lane', '${result.debugInfo!.isSideLane ?? 'unknown'}'),
                  _buildDebugRow('Well lit', '${result.debugInfo!.isWellLit ?? 'unknown'}'),
                  _buildDebugRow('Near embassy', '${result.debugInfo!.isNearEmbassy ?? 'unknown'}'),
                ],
                if (_scoreDataSource != null && _scoreDataSource!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Data: $_scoreDataSource',
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillarRow(String label, double risk) {
    final value = (risk * 100).round();
    final color = value > 66 ? AppColors.alertRed : (value > 33 ? Colors.orange : AppColors.successGreen);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: risk,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$value%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLocalTime(DateTime time) {
    final t = time.toLocal();
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final offset = t.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final offsetHours = offset.inHours.abs().toString().padLeft(2, '0');
    final offsetMinutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm $sign$offsetHours:$offsetMinutes';
  }

  String _formatAmenity(String? name, double? distanceMeters) {
    if (distanceMeters == null) return 'unavailable';
    final label = (name == null || name.trim().isEmpty) ? 'unknown' : name.trim();
    if (distanceMeters >= 1000) {
      final km = distanceMeters / 1000.0;
      return '$label (${km.toStringAsFixed(2)}km)';
    }
    return '$label (${distanceMeters.toStringAsFixed(1)}m)';
  }


  String _formatDistance(double distanceMeters) {
    if (distanceMeters >= 1000) {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(2)}km';
    }
    return '${distanceMeters.toStringAsFixed(1)}m';
  }
}
