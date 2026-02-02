import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'config.dart';

// Home screen redesigned
// Home screen redesign test

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

  // Animation Controller for "Breathing" effect
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
          // Timer finished
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

    // Smooth progress update (60fps)
    _holdTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        _holdProgress += 0.015; // Speed of fill
        if (_holdProgress >= 1.0) {
          _holdTimer?.cancel();
          _isPanicMode = true;
          _startCountdown(); // Trigger the 3-minute timer
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          // Deep Navy Radial Gradient matches Login Page vibe
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.4,
            colors: [AppColors.surfaceCard, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),

              // --- 1. STATUS PILL (Glassmorphism) ---
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Blinking Green Dot
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(seconds: 1),
                      builder: (context, val, child) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.successGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppColors.successGreen.withOpacity(val),
                                  blurRadius: 8)
                            ],
                          ),
                        );
                      },
                      onEnd: () => setState(() {}),
                    ),
                    const SizedBox(width: 10),
                    const Text("STATUS: SAFE",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 12)),
                  ],
                ),
              ),

              const Spacer(),

              // --- 2. TIMER DISPLAY (Only visible in Panic Mode) ---
              if (_isPanicMode)
                Column(
                  children: [
                    const Text("SOS SIGNAL LIVE",
                        style: TextStyle(
                            color: AppColors.dangerRed,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      _formatTime(_secondsRemaining),
                      style: const TextStyle(
                        fontFamily: 'monospace', // Digital clock look
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: AppColors.dangerRed, blurRadius: 20)
                        ],
                      ),
                    ),
                  ],
                ),

              if (!_isPanicMode)
                const Spacer(), // Spacer to push button down if no timer

              // --- 3. SOS BUTTON (The Core Interaction) ---
              GestureDetector(
                onTapDown: (_) => _startHolding(),
                onTapUp: (_) => _stopHolding(),
                onTapCancel: () => _stopHolding(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse Effect (Only when not holding)
                    if (!_isPanicMode && !_isHolding)
                      ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.1)
                            .animate(_pulseController),
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primarySky.withOpacity(0.2),
                                width: 1),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primarySky.withOpacity(0.1),
                                  blurRadius: 20)
                            ],
                          ),
                        ),
                      ),

                    // Progress Ring
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: CustomPaint(
                        painter: RingPainter(
                          progress: _holdProgress,
                          color: _isPanicMode
                              ? AppColors.dangerRed
                              : AppColors.primarySky,
                          trackColor: Colors.white10,
                        ),
                      ),
                    ),

                    // Central Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isHolding
                          ? 210
                          : 220, // Shrink slightly when pressing
                      height: _isHolding ? 210 : 220,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isPanicMode
                              ? AppColors.dangerRed.withOpacity(0.1)
                              : AppColors.surfaceCard,
                          boxShadow: [
                            BoxShadow(
                              color: _isPanicMode
                                  ? AppColors.dangerRed.withOpacity(0.4)
                                  : Colors.black.withOpacity(0.5),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: _isPanicMode
                                ? AppColors.dangerRed
                                : Colors.white10,
                          )),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isPanicMode
                                ? Icons.warning_amber_rounded
                                : Icons.fingerprint,
                            size: 50,
                            color: _isPanicMode
                                ? AppColors.dangerRed
                                : AppColors.primarySky,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isPanicMode ? "SENDING\nALERT" : "HOLD FOR\nSOS",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isPanicMode
                                  ? AppColors.dangerRed
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
              const Spacer(),

              // --- 4. CANCEL BUTTON ---
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _isPanicMode ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isPanicMode = false;
                          _countdownTimer?.cancel();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 5,
                      ),
                      child: const Text("CANCEL SOS",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- RING PAINTER (Smooth & Neon) ---
class RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  RingPainter(
      {required this.progress, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4); // Neon Glow

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.progress != progress || old.color != color;
}
