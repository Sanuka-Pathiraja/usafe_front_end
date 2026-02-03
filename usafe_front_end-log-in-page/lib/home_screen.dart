import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'config.dart';
import 'contacts_screen.dart';
import 'safety_score_screen.dart'; // IMPORT THE NEW FILE

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Navigation State
  int _selectedIndex = 0;

  // SOS Logic
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
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Placeholder for map navigation
  void _goToLiveMap() {
    print("Navigate to Live Map Page");
    // You can push a new route here later
  }

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
        _holdProgress += 0.012;
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

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: Stack(
        children: [
          // 1. HOME SCREEN (Index 0)
          Offstage(
            offstage: _selectedIndex != 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 30),

                    // Status Pill
                    if (!_isPanicMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(30),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: AppColors.safetyTeal,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                          color: AppColors.safetyTeal
                                              .withOpacity(0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1)
                                    ])),
                            const SizedBox(width: 10),
                            const Text("Your Area: Safe",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),

                    // SOS Interface
                    Expanded(
                      child: Center(
                        child: _isPanicMode ? _buildPanicUI() : _buildSafeUI(),
                      ),
                    ),

                    // Action Buttons
                    if (_isPanicMode) ...[
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
                            backgroundColor: AppColors.safetyTeal,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          child: const Text("CANCEL SOS",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.send, color: Colors.white),
                          label: const Text("SEND HELP NOW",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.alertRed,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.2), width: 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 120),
                    ] else ...[
                      const SizedBox(height: 100),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 2. SAFETY SCORE / MAP SCREEN (Index 1) - UPDATED
          Offstage(
            offstage: _selectedIndex != 1,
            child: SafetyScoreScreen(onViewMap: _goToLiveMap),
          ),

          // 3. CONTACTS SCREEN (Index 2)
          Offstage(
            offstage: _selectedIndex != 2,
            child: const ContactsScreen(),
          ),

          // 4. PROFILE SCREEN (Index 3)
          Offstage(
            offstage: _selectedIndex != 3,
            child: const Center(
                child: Text("Profile Feature Coming Soon",
                    style: TextStyle(color: Colors.white))),
          ),
        ],
      ),

      // --- FOOTER ---
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            selectedItemColor: AppColors.primarySky,
            unselectedItemColor: Colors.white38,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.shield_outlined, size: 28),
                  activeIcon: Icon(Icons.shield, size: 28),
                  label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined, size: 28),
                  activeIcon: Icon(Icons.map, size: 28),
                  label: 'Map'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline, size: 28),
                  activeIcon: Icon(Icons.people, size: 28),
                  label: 'Contacts'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline, size: 28),
                  activeIcon: Icon(Icons.person, size: 28),
                  label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  // --- SUB-WIDGETS ---
  Widget _buildSafeUI() {
    return GestureDetector(
      onTapDown: (_) => _startHolding(),
      onTapUp: (_) => _stopHolding(),
      onTapCancel: () => _stopHolding(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.08).animate(_pulseController),
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySky.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primarySky.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5)
                  ]),
            ),
          ),
          SizedBox(
            width: 260,
            height: 260,
            child: CustomPaint(
              painter: ModernRingPainter(
                  progress: _holdProgress,
                  color: AppColors.primarySky,
                  trackColor: AppColors.surfaceCard.withOpacity(0.5)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined,
                  color: Colors.white.withOpacity(0.8), size: 32),
              const SizedBox(height: 10),
              const Text("Hold to Activate",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text("SOS",
                  style: TextStyle(
                      color: AppColors.primarySky,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPanicUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("SOS ACTIVATED",
            style: TextStyle(
                color: AppColors.alertRed,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        const SizedBox(height: 40),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                BoxShadow(
                    color: AppColors.alertRed.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 5)
              ]),
            ),
            SizedBox(
              width: 280,
              height: 280,
              child: CircularProgressIndicator(
                value: _secondsRemaining / 180,
                strokeWidth: 12,
                backgroundColor: AppColors.surfaceCard,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.alertRed),
              ),
            ),
            Text(
                "${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        const SizedBox(height: 30),
        const Text("An alert will be sent to your emergency contacts.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
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
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round);
    if (progress > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          2 * math.pi * progress,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(ModernRingPainter old) =>
      old.progress != progress || old.color != color;
}
