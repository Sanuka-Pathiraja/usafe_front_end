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

  // Animation for pulsing Red Zones
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isSafetyModeActive = false;
  bool _isDangerCountdownActive = false;
  Timer? _dangerTimer;
  int _dangerSeconds = 10;
  final AudioAnalysisService _audioService = AudioAnalysisService();

  // Initial Camera Position (San Francisco placeholder)
  static final CameraPosition _kInitialPosition = const CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    
    // Setup Pulse Animation for Danger Zones
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
    await _audioService.initialize();
    _audioService.onDistressDetected = (event, confidence) {
      if (!mounted) return;
      _startDangerCountdown(reason: event);
    };
  }

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

    setState(() {
      _isDangerCountdownActive = true;
      _dangerSeconds = 10;
    });

    _dangerTimer?.cancel();
    _dangerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_dangerSeconds <= 1) {
        timer.cancel();
        setState(() {
          _isDangerCountdownActive = false;
          _dangerSeconds = 10;
        });
        _triggerAlarm(reason: reason);
        return;
      }
      setState(() {
        _dangerSeconds -= 1;
      });
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                'Suspicious Noise Detected',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'SOS will trigger in $_dangerSeconds seconds.\nAre you safe?',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
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
    );
  }

  void _cancelDangerCountdown() {
    _dangerTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isDangerCountdownActive = false;
      _dangerSeconds = 10;
    });
  }

  void _triggerAlarm({required String reason}) {
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
                    // Logic to re-center on user
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
                    // Navigate to Report Screen
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
}
