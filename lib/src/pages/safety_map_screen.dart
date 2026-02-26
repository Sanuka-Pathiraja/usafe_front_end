import 'dart:async';
import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:usafe_front_end/src/services/audio_analysis_service.dart';

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({Key? key}) : super(key: key);

  @override
  _SafetyMapScreenState createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> with SingleTickerProviderStateMixin {
  late GoogleMapController _mapController;
  String _darkMapStyle = '';

<<<<<<< HEAD
  // Animation for pulsing danger zones.
=======
  // Animation for pulsing Red Zones
>>>>>>> master
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isSafetyModeActive = false;
  bool _isDangerCountdownActive = false;
  Timer? _dangerTimer;
  int _dangerSeconds = 10;
<<<<<<< HEAD
  bool _audioReady = false;
  bool _isDangerDialogOpen = false;
  StateSetter? _dangerDialogSetState;
  String _micStatusText = 'Safety Mode Off';
  Color _micStatusColor = Colors.white70;
=======
>>>>>>> master
  final AudioAnalysisService _audioService = AudioAnalysisService();

  // Initial Camera Position (San Francisco placeholder)
  static final CameraPosition _kInitialPosition = const CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    // Prepare the dark map styling.
    _loadMapStyle();
    
    // Setup pulse animation for the high-risk circle.
=======
    _loadMapStyle();
    
    // Setup Pulse Animation for Danger Zones
>>>>>>> master
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 100, end: 300).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initAudioService();
  }

  Future<void> _initAudioService() async {
<<<<<<< HEAD
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
=======
    await _audioService.initialize();
    _audioService.onDistressDetected = (event, confidence) {
      if (!mounted) return;
>>>>>>> master
      _startDangerCountdown(reason: event);
    };
  }

<<<<<<< HEAD
  Future<void> _toggleSafetyMode() async {
    if (_isSafetyModeActive) {
      setState(() {
        _isSafetyModeActive = false;
        _micStatusText = 'Safety Mode Off';
        _micStatusColor = Colors.white70;
      });
      await _audioService.stopListening();
      _cancelDangerCountdown();
      return;
    }

    if (!_audioReady) {
      _showStatusSnack('Audio model is not ready.');
      setState(() {
        _micStatusText = _audioService.lastError ?? 'Audio model unavailable.';
        _micStatusColor = Colors.orangeAccent;
      });
      return;
    }

    final started = await _audioService.startListening();
    if (!started) {
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
      _micStatusText = 'Listening for distress signals';
      _micStatusColor = Colors.redAccent;
    });

    _showStatusSnack('Safety Mode Activated: Listening for distress signals...');
  }

  void _startDangerCountdown({required String reason}) {
    if (_isDangerCountdownActive || !_isSafetyModeActive) return;
=======
  void _toggleSafetyMode() {
    setState(() {
      _isSafetyModeActive = !_isSafetyModeActive;
    });

    if (_isSafetyModeActive) {
      _audioService.startListening();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Safety Mode Activated: Listening for distress signals...'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      _audioService.stopListening();
      _cancelDangerCountdown();
    }
  }

  void _startDangerCountdown({required String reason}) {
    if (_isDangerCountdownActive) return;
>>>>>>> master

    setState(() {
      _isDangerCountdownActive = true;
      _dangerSeconds = 10;
<<<<<<< HEAD
      _micStatusText = 'Potential distress: $_dangerSeconds s';
      _micStatusColor = Colors.orangeAccent;
=======
>>>>>>> master
    });

    _dangerTimer?.cancel();
    _dangerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_dangerSeconds <= 1) {
        timer.cancel();
        setState(() {
          _isDangerCountdownActive = false;
          _dangerSeconds = 10;
<<<<<<< HEAD
          if (_isSafetyModeActive) {
            _micStatusText = 'Listening for distress signals';
            _micStatusColor = Colors.redAccent;
          }
        });
        _closeDangerDialog();
=======
        });
>>>>>>> master
        _triggerAlarm(reason: reason);
        return;
      }
      setState(() {
        _dangerSeconds -= 1;
<<<<<<< HEAD
        _micStatusText = 'Potential distress: $_dangerSeconds s';
      });
      _dangerDialogSetState?.call(() {});
    });

    _isDangerDialogOpen = true;
=======
      });
    });

>>>>>>> master
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
<<<<<<< HEAD
            _dangerDialogSetState = setDialogState;
=======
>>>>>>> master
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                'Suspicious Noise Detected',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
<<<<<<< HEAD
                'Detected: $reason\n\nSOS will trigger in $_dangerSeconds seconds.\nAre you safe?',
=======
                'SOS will trigger in $_dangerSeconds seconds.\nAre you safe?',
>>>>>>> master
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
<<<<<<< HEAD
=======
                    Navigator.pop(context);
>>>>>>> master
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
<<<<<<< HEAD
    ).then((_) {
      _isDangerDialogOpen = false;
      _dangerDialogSetState = null;
    });
=======
    );
>>>>>>> master
  }

  void _cancelDangerCountdown() {
    _dangerTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isDangerCountdownActive = false;
      _dangerSeconds = 10;
<<<<<<< HEAD
      if (_isSafetyModeActive) {
        _micStatusText = 'Listening for distress signals';
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
=======
    });
  }

  void _triggerAlarm({required String reason}) {
>>>>>>> master
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

<<<<<<< HEAD
  void _closeDangerDialog() {
    if (!_isDangerDialogOpen || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _isDangerDialogOpen = false;
    _dangerDialogSetState = null;
  }

<<<<<<< HEAD
=======
  void _openGuardianSheet() {
    setState(() {
      _isGuardianSheetOpen = !_isGuardianSheetOpen;
    });
  }

  void _closeGuardianSheet() {
    if (!_isGuardianSheetOpen) return;
    setState(() {
      _isGuardianSheetOpen = false;
    });
  }

  Future<void> _handleGuardianMapTap(LatLng position) async {
    if (!_isGuardianSheetOpen) return;
    await _addGuardianCheckpoint(position);
  }

  Future<void> _addGuardianCheckpoint(LatLng position) async {
    final index = _guardianCheckpoints.length + 1;
    try {
      final score = await ApiService.fetchGuardianSafetyScore(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (!mounted) return;
      final checkpoint = GuardianCheckpoint(
        name: 'Checkpoint $index',
        lat: position.latitude,
        lng: position.longitude,
        safetyScore: score,
      );
      setState(() {
        _guardianCheckpoints.add(checkpoint);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch safety score: $e'),
          backgroundColor: AppColors.alertRed,
        ),
      );
    }
  }

  void _removeGuardianCheckpoint(GuardianCheckpoint checkpoint) {
    setState(() {
      _guardianCheckpoints.remove(checkpoint);
    });
  }

  Future<void> _startGuardianMonitoring() async {
    if (_guardianCheckpoints.length < 2) return;
    
    // Save route to backend first
    try {
      final routeId = await ApiService.saveGuardianRoute(
        routeName: _guardianRouteController.text.isEmpty
            ? 'Route ${DateTime.now().month}/${DateTime.now().day}'
            : _guardianRouteController.text,
        checkpoints: _guardianCheckpoints
            .map((c) => {
                  'name': c.name,
                  'lat': c.lat,
                  'lng': c.lng,
                  'safety_score': c.safetyScore,
                })
            .toList(),
      );
      if (!mounted) return;
      _guardianRouteId = routeId;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save route: $e'),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    setState(() {
      _isGuardianMonitoringActive = true;
      _isGuardianSheetOpen = false;
      _guardianCurrentCheckpointIndex = 0;
      _guardianDistance = 0.0;
    });

    // Initialize real GPS tracking
    _guardianLogic = GuardianLogic(
      onDistanceUpdate: (double distance) {
        if (mounted) {
          setState(() {
            _guardianDistance = distance;
          });
        }
      },
      onCheckpointReached: (int checkpointIndex) {
        if (!mounted) return;
        
        // Send alert to backend
        final checkpoint = _guardianCheckpoints[checkpointIndex];
        ApiService.sendGuardianAlert(
          routeId: _guardianRouteId ?? 'unknown',
          checkpointIndex: checkpointIndex,
          lat: checkpoint.lat,
          lng: checkpoint.lng,
        ).catchError((e) {
          print('Alert send failed: $e');
        });

        // Show notification for reached checkpoint
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${checkpoint.name} Reached!',
            ),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 3),
          ),
        );

        setState(() {
          _guardianCurrentCheckpointIndex++;
        });

        // Check if all checkpoints reached (arrived at destination)
        if (_guardianCurrentCheckpointIndex >= _guardianCheckpoints.length) {
          _guardianLogic?.stopTracking();
          setState(() {
            _isGuardianMonitoringActive = false;
          });
          _showArrivalDialog();
        }
      },
    );

    // Start real GPS tracking
    try {
      _guardianLogic!.startTracking(
        _guardianCheckpoints
            .asMap()
            .entries
            .map((e) => {
                  'lat': e.value.lat,
                  'lng': e.value.lng,
                  'name': e.value.name,
                })
            .toList(),
        0,
        routeId: _guardianRouteId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚀 Real GPS Tracking Started - Guardian Mode Active'),
          backgroundColor: AppColors.successGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Handle permission denied or other errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
        setState(() {
          _isGuardianMonitoringActive = false;
        });
      }
    }
  }

  void _stopGuardianMonitoring() {
    _guardianLogic?.stopTracking();
    setState(() {
      _isGuardianMonitoringActive = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏹️ Monitoring Stopped'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Shows arrival dialog when child reaches final destination
  void _showArrivalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          '🎉 Safe Arrival',
          style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your child has safely reached the destination. All checkpoints completed!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got It', style: TextStyle(color: AppColors.successGreen)),
          ),
        ],
      ),
    );
  }

>>>>>>> 5a5962c (Fix: Allow checkpoint selection when Guardian setup panel is open)
  void _showStatusSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

=======
>>>>>>> master
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
<<<<<<< HEAD
    // Static + animated overlays representing risk zones.
=======
>>>>>>> master
    return {
      // 🔴 HIGH RISK (Pulsing Animation)
      Circle(
        circleId: const CircleId('danger_zone_1'),
        center: const LatLng(37.7780, -122.4100),
        radius: pulseRadius, // Animated radius
        fillColor: const Color(0xFFE53935).withOpacity(0.3),
        strokeColor: const Color(0xFFE53935),
        strokeWidth: 2,
      ),
      // 🟠 MODERATE RISK (Static)
      Circle(
        circleId: const CircleId('moderate_zone_1'),
        center: const LatLng(37.7700, -122.4120),
        radius: 400,
        fillColor: Colors.orange.withOpacity(0.25),
        strokeColor: Colors.orange,
        strokeWidth: 1,
      ),
      // 🟢 SAFE ZONE (Static)
      Circle(
        circleId: const CircleId('safe_zone_1'),
        center: const LatLng(37.7800, -122.4250),
        radius: 500,
        fillColor: const Color(0xFF00E676).withOpacity(0.2),
        strokeColor: const Color(0xFF00E676),
        strokeWidth: 1,
      ),
    };
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dangerTimer?.cancel();
    if (_isSafetyModeActive) {
      _audioService.stopListening();
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

<<<<<<< HEAD
          Positioned(
            top: 120,
            left: 20,
            child: _buildMicStatusPill(),
          ),

=======
>>>>>>> master
          // --- Bottom Floating Action Buttons ---
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "recenter",
                  backgroundColor: const Color(0xFF1E1E1E),
                  onPressed: () {
<<<<<<< HEAD
                    // TODO: implement re-center to current location.
=======
                    // Logic to re-center on user
>>>>>>> master
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
<<<<<<< HEAD
                    // TODO: navigate to a report flow.
=======
                    // Navigate to Report Screen
>>>>>>> master
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
<<<<<<< HEAD

  Widget _buildMicStatusPill() {
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
            _isSafetyModeActive ? Icons.hearing : Icons.mic_off,
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
=======
>>>>>>> master
}
