import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'config.dart'; // Imports your AppColors

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isPanicMode = false;
  bool _isHolding = false;
  double _holdProgress = 0.0;
  Timer? _holdTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Setup a pulsing animation for the idle state
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
        }
      });
    });
  }

  void _stopHolding() {
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          // Subtle radial gradient to give depth to the dark background
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [AppColors.surfaceCard, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),

              // --- STATUS PILL (Modernized) ---
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.successGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.successGreen, blurRadius: 6)
                          ]),
                    ),
                    const SizedBox(width: 10),
                    const Text("STATUS: SAFE",
                        style: TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 12)),
                  ],
                ),
              ),

              const Spacer(),

              // --- SOS INTERACTION ---
              GestureDetector(
                onTapDown: (_) => _startHolding(),
                onTapUp: (_) => _stopHolding(),
                onTapCancel: () => _stopHolding(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Glow Ring (Animated)
                    if (!_isPanicMode)
                      ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.05)
                            .animate(_pulseController),
                        child: Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primarySky.withOpacity(0.1),
                                width: 1),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primarySky.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 0)
                            ],
                          ),
                        ),
                      ),

                    // Progress Painter
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CustomPaint(
                        painter: RingPainter(
                          progress: _holdProgress,
                          color: _isPanicMode
                              ? AppColors.dangerRed
                              : AppColors.primarySky,
                          trackColor: AppColors.surfaceCard,
                        ),
                      ),
                    ),

                    // Central Button
                    Container(
                      width: 220,
                      height: 220,
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
                            width: 1,
                          )),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              _isPanicMode
                                  ? Icons.warning_amber_rounded
                                  : Icons.fingerprint,
                              size: 48,
                              color: _isPanicMode
                                  ? AppColors.dangerRed
                                  : AppColors.primarySky),
                          const SizedBox(height: 16),
                          Text(
                            _isPanicMode ? "SOS\nACTIVE" : "HOLD FOR\nSOS",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isPanicMode
                                  ? AppColors.dangerRed
                                  : Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // --- CANCEL BUTTON (Only visible when active) ---
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isPanicMode ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Container(
                    height: 50,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.white24, blurRadius: 12)
                      ],
                    ),
                    child: TextButton(
                      onPressed: () => setState(() => _isPanicMode = false),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, color: Colors.black),
                          SizedBox(width: 8),
                          Text("CANCEL SOS",
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ],
                      ),
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

// --- CUSTOM PAINTER FOR RING ---
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

    // Draw the subtle track
    final trackPaint = Paint()
      ..color = trackColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, trackPaint);

    // Draw the progress arc (Neon Glow Effect)
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2); // Subtle glow

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
