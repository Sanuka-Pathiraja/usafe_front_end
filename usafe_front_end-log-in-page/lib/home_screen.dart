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
  int _secondsRemaining = 180; // 3 Minutes

  // Animation Controller for subtle breathing
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Slower, calmer pulse
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
        _holdProgress += 0.015;
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

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final Color activeColor =
        _isPanicMode ? AppColors.dangerRed : AppColors.primarySky;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // --- 1. MINIMALIST STATUS INDICATOR ---
            // Simple text, no heavy borders
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.successGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text("SYSTEM ACTIVE",
                    style: TextStyle(
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        letterSpacing: 1.0)),
              ],
            ),

            const Spacer(),

            // --- 2. TIMER DISPLAY (Clean & Large) ---
            if (_isPanicMode)
              Column(
                children: [
                  const Text("SOS INITIATED",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          letterSpacing: 1.0)),
                  const SizedBox(height: 10),
                  Text(
                    _formatTime(_secondsRemaining),
                    style: TextStyle(
                      fontSize: 80,
                      fontWeight:
                          FontWeight.w300, // Thinner font looks more modern
                      color: activeColor,
                    ),
                  ),
                ],
              ),

            if (!_isPanicMode) const Spacer(),

            // --- 3. THE BUTTON (Professional & Matte) ---
            GestureDetector(
              onTapDown: (_) => _startHolding(),
              onTapUp: (_) => _stopHolding(),
              onTapCancel: () => _stopHolding(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Subtle Ring Background (Fixed)
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.surfaceCard, width: 2),
                    ),
                  ),

                  // Progress Ring (Clean Line)
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CustomPaint(
                      painter: CleanRingPainter(
                        progress: _holdProgress,
                        color: activeColor,
                      ),
                    ),
                  ),

                  // The Main Button (Solid, Matte)
                  // Scales slightly when breathing, shrinks when pressed
                  ScaleTransition(
                    scale: _isHolding
                        ? const AlwaysStoppedAnimation(0.95)
                        : Tween(begin: 1.0, end: 1.03)
                            .animate(_pulseController),
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isPanicMode
                            ? AppColors.dangerRed
                            : AppColors.surfaceCard,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isPanicMode
                                ? Icons.notifications_active
                                : Icons.touch_app,
                            size: 48,
                            color: _isPanicMode ? Colors.white : activeColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isPanicMode ? "CANCEL" : "HOLD SOS",
                            style: TextStyle(
                              color: _isPanicMode ? Colors.white : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),
            const Spacer(),

            // --- 4. BOTTOM ACTION (Clean Pill Button) ---
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isPanicMode ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isPanicMode = false;
                      _countdownTimer?.cancel();
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    backgroundColor: AppColors.surfaceCard,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text("STOP TIMER",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CLEAN PAINTER (No Blur/Glow) ---
class CleanRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  CleanRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8; // Solid, professional thickness

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CleanRingPainter old) =>
      old.progress != progress || old.color != color;
}
