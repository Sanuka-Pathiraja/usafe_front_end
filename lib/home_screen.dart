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
  bool _isPanicMode = false;
  bool _isHolding = false;
  double _holdProgress = 0.0;
  Timer? _holdTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 180;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _secondsRemaining = 180;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0)
          _secondsRemaining--;
        else
          _countdownTimer?.cancel();
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
        _holdProgress += 0.01;
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
    if (!_isPanicMode)
      setState(() {
        _isHolding = false;
        _holdProgress = 0.0;
      });
  }

  @override
  Widget build(BuildContext context) {
    final Color safeColor = const Color(0xFF26A69A);
    final Color panicColor = const Color(0xFFE53935);

    return Scaffold(
      backgroundColor: const Color(0xFF151B28), // Professional Blueish Matte
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 30),
              if (!_isPanicMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: safeColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text("Your Area: Safe",
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ]),
                ),
              // FIXED: Expanded + Center ensures perfect vertical and horizontal centering
              Expanded(
                child: Center(
                  child: _isPanicMode
                      ? _buildPanicUI(panicColor)
                      : _buildSafeUI(safeColor),
                ),
              ),
              if (_isPanicMode) ...[
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () => setState(() {
                      _isPanicMode = false;
                      _countdownTimer?.cancel();
                    }),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: safeColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30))),
                    child: const Text("Cancel SOS",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                    onPressed: () {},
                    child: const Text("Send Now",
                        style: TextStyle(
                            color: Color(0xFFE53935),
                            fontSize: 16,
                            fontWeight: FontWeight.bold))),
              ] else
                const SizedBox(height: 60),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeUI(Color color) {
    return GestureDetector(
      onTapDown: (_) => _startHolding(),
      onTapUp: (_) => _stopHolding(),
      onTapCancel: () => _stopHolding(),
      child: Stack(alignment: Alignment.center, children: [
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.05).animate(_pulseController),
          child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color.withOpacity(0.1))),
        ),
        SizedBox(
            width: 260,
            height: 260,
            child: CustomPaint(
                painter: ModernRingPainter(
                    progress: _holdProgress,
                    color: color,
                    trackColor: Colors.white.withOpacity(0.05)))),
        const Text("Hold to Activate SOS",
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildPanicUI(Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text("SOS ACTIVATED",
          style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0)),
      const SizedBox(height: 40),
      Stack(alignment: Alignment.center, children: [
        SizedBox(
            width: 280,
            height: 280,
            child: CircularProgressIndicator(
                value: _secondsRemaining / 180,
                strokeWidth: 12,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(color))),
        Text(
            "${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
            style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ]),
      const SizedBox(height: 30),
      const Text(
          "An alert will be sent to emergency contacts\nwhen the timer ends.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
    ]);
  }
}

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
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round);
    if (progress > 0)
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          2 * math.pi * progress,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(ModernRingPainter old) =>
      old.progress != progress || old.color != color;
}
