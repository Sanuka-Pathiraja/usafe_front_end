import 'dart:async';
import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:usafe_front_end/src/services/audio_analysis_service.dart';

class SafetyMapScreen extends StatefulWidget {
  final bool showToneDetailsOnLoad;

  const SafetyMapScreen({Key? key, this.showToneDetailsOnLoad = false})
      : super(key: key);

  @override
  _SafetyMapScreenState createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> with SingleTickerProviderStateMixin {
  late GoogleMapController _mapController;
  String _darkMapStyle = '';

  // Animation for pulsing danger zones.
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isSafetyModeActive = false;
  bool _isDangerCountdownActive = false;
  Timer? _dangerTimer;
  int _dangerSeconds = 10;
  bool _audioReady = false;
  bool _isDangerDialogOpen = false;
  bool _hasShownToneDetails = false;
  StateSetter? _dangerDialogSetState;
  String _micStatusText = 'Safety Mode Off';
  Color _micStatusColor = Colors.white70;
  final AudioAnalysisService _audioService = AudioAnalysisService();
  // Initial Camera Position (San Francisco placeholder)
  static final CameraPosition _kInitialPosition = const CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 14.0,
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
    _maybeShowToneDetails();
  }

  void _maybeShowToneDetails() {
    if (!widget.showToneDetailsOnLoad || _hasShownToneDetails) return;
    _hasShownToneDetails = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showToneRecognitionDetailsSheet();
    });
  }

  void _showToneRecognitionDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const Text(
                        'Tone Recognition in USafe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'The tone recognition feature in USafe is an AI-powered safety mechanism designed to detect auditory signs of distress such as screaming, shouting, or crying and automatically trigger an emergency response without manual input.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'How it works',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'USafe uses YAMNet (Yet Another Mobile Network), a deep learning model pre-trained on millions of audio samples to recognize 521 distinct sound classes. Instead of relying on volume spikes, YAMNet analyzes the spectral fingerprint of sound.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailStep(
                        title: '1) Audio Streaming',
                        body:
                            'The device microphone captures raw audio at a 16 kHz sample rate.',
                      ),
                      _buildDetailStep(
                        title: '2) Inference',
                        body:
                            'Audio is buffered into ~0.975-second segments (15,600 samples) and passed through the assets/models/yamnet.tflite model.',
                      ),
                      _buildDetailStep(
                        title: '3) Classification',
                        body:
                            'The model outputs probability scores for various sounds. If distress-related classes such as "Scream" exceed the confidence threshold (0.4), a distress event is registered.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Implementation in USafe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The AudioAnalysisService runs fully on-device with the YAMNet model bundled as a local asset for privacy and offline functionality. When Safety Mode is active, it continuously monitors audio in the background. If a scream is detected, the service triggers a callback to the SafetyMapScreen, launching a 10-second warning countdown. If the user does not cancel, the app escalates to the SOS dashboard to alert emergency contacts.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
      final ok = await _audioService.initialize();
      if (!mounted) return;
      setState(() {
        _audioReady = ok;
        if (!ok) {
          _micStatusText =
              _audioService.lastError ?? 'Audio model unavailable.';
          _micStatusColor = Colors.orangeAccent;
        }
      });
      if (!ok) {
        _showStatusSnack(_audioService.lastError ?? 'Audio model is not ready.');
        return;
      }
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
            _micStatusText = 'Listening for distress signals';
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
                'Suspicious Noise Detected',
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
    // Static + animated overlays representing risk zones.
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
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
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
                    // TODO: implement re-center to current location.
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
                  label:
                      const Text("Report Incident", style: TextStyle(color: Colors.white)),
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

  Widget _buildDetailStep({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}
