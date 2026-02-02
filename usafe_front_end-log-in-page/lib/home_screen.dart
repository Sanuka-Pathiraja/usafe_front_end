import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Logic Variables
  bool _isPanicMode = false;
  bool _isHolding = false;
  double _holdProgress = 0.0;

  // Timer Variables
  Timer? _holdTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 180; // 3 Minutes (180 seconds)

  // Animation for "Breathing" effect when idle
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // --- LOGIC ---

  void _startCountdown() {
    _secondsRemaining = 180;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _countdownTimer?.cancel();
          // Logic for when timer hits 0:00 (Send Alert)
        }
      });
    });
  }

  void _startHolding() {
    if (_isPanicMode) return;
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    _holdTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        _holdProgress += 0.01; // Slower, more deliberate fill (hold for ~1.5s)
        if (_holdProgress >= 1.0) {
          _holdTimer?.cancel();
          _isPanicMode = true;
          _startCountdown();
        }
      });
    });
  }

  void _stopHolding() {
    _holdTimer?.cancel();
    if (!_isPanicMode) {
      setState(() {
        _isHolding = false;
        _holdProgress = 0.0;
      });
    }
  }

  String _formatTime(int totalSeconds) {
    int mins = totalSeconds ~/ 60;
    int secs = totalSeconds % 60;
    return "$mins:${secs.toString().padLeft(2, '0')}";
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    // Colors inspired by your reference image
    final Color safeColor = const Color(0xFF26A69A); // Teal/Green
    final Color panicColor = const Color(0xFFE53935); // Matte Red
    final Color activeColor = _isPanicMode ? panicColor : safeColor;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // Deep matte navy/black
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 30),

              // --- 1. STATUS PILL (Top) ---
              if (!_isPanicMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: safeColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      const Text("Your Area: Safe",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),

              const Spacer(),

              // --- 2. MAIN CENTER UI ---
              if (_isPanicMode) ...[
                // PANIC MODE UI (Matches reference image right side)
                const Text("SOS ACTIVATED",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0)),
                const SizedBox(height: 40),

                // Red Progress Timer
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: _secondsRemaining / 180, // Countdown progress
                        strokeWidth: 12,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(panicColor),
                      ),
                    ),
                    Text(
                      _formatTime(_secondsRemaining),
                      style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                const Text(
                  "An alert with your location will be sent to\nyour emergency contacts when the timer ends.",
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                ),
              ] else ...[
                // SAFE MODE UI (Matches reference image left side)
                GestureDetector(
                  onTapDown: (_) => _startHolding(),
                  onTapUp: (_) => _stopHolding(),
                  onTapCancel: () => _stopHolding(),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background Pulse
                      ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.05)
                            .animate(_pulseController),
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: safeColor
                                .withOpacity(0.1), // Very subtle teal bg
                          ),
                        ),
                      ),

                      // Progress Ring
                      SizedBox(
                        width: 260,
                        height: 260,
                        child: CustomPaint(
                          painter: ModernRingPainter(
                            progress: _holdProgress,
                            color: safeColor,
                            trackColor: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),

                      // Text
                      const Text(
                        "Hold to Activate SOS",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // --- 3. BOTTOM BUTTONS ---
              if (_isPanicMode) ...[
                // Cancel Button (Filled Teal/Green like reference)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isPanicMode = false;
                        _countdownTimer?.cancel();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          safeColor, // Green to cancel, calming color
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("Cancel SOS",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    // Logic to skip timer
                  },
                  child: const Text("Send Now",
                      style: TextStyle(
                          color: Color(0xFFE53935),
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                // Placeholder for Navigation Bar (if not using Dashboard)
                const SizedBox(height: 60),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MODERN PAINTER (Crisp, Matte lines) ---
class ModernRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  ModernRingPainter(
      {required this.progress, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw Track (Grey background circle)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw Progress (Active color)
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start at top
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(ModernRingPainter old) =>
      old.progress != progress || old.color != color;
}
