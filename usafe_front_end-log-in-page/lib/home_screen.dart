import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'dart:async'; // For Timers (SOS hold & countdown)
import 'dart:math' as math; // For drawing arcs
import 'config.dart'; // Brand colors
import 'contacts_screen.dart';
import 'safety_score_screen.dart';
import 'profile_screen.dart'; // IMPORTED: Connects the new Profile Page

/// ---------------------------------------------------------------------------
/// HOME SCREEN DASHBOARD
///
/// The central hub of the application. It manages:
/// 1. The Bottom Navigation Bar (switching between Home, Map, Contacts, Profile).
/// 2. The SOS Mechanism (Hold-to-activate, Countdown, Panic Mode).
/// ---------------------------------------------------------------------------
=======
import 'dart:async'; // For Timer if needed later
import 'config.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

<<<<<<< HEAD
class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // STATE VARIABLES
  // ---------------------------------------------------------------------------

  // Tracks the active tab (0: Home, 1: Map, 2: Contacts, 3: Profile)
  int _selectedIndex = 0;

  // -- SOS Logic State --
  bool _isPanicMode = false; // True if SOS is triggered
  bool _isHolding = false; // True while user presses the button
  double _holdProgress = 0.0; // 0.0 -> 1.0 (Progress of the ring)

  // -- Timers & Animation --
  Timer? _holdTimer; // Fills the ring while holding
  Timer? _countdownTimer; // Counts down from 3 mins after activation
  int _secondsRemaining = 180; // 3 Minutes (180 seconds)
  late AnimationController
      _pulseController; // "Breathing" animation for the button

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------
=======
class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _isPanic = false;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    // Initialize the breathing animation (2 seconds in, 2 seconds out)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
=======
    // 1. SMOOTH BREATHING ANIMATION
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _fadeAnimation = Tween<double>(begin: 0.3, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387
  }

  @override
  void dispose() {
    // Cleanup timers and controllers to prevent memory leaks
    _pulseController.dispose();
    super.dispose();
  }

<<<<<<< HEAD
  // ---------------------------------------------------------------------------
  // NAVIGATION LOGIC
  // ---------------------------------------------------------------------------

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Navigation callback for the Safety Score Screen
  void _goToLiveMap() {
    print("Navigate to Live Map Page");
    // TODO: Add actual navigation to Google Maps widget here
  }

  // ---------------------------------------------------------------------------
  // SOS LOGIC
  // ---------------------------------------------------------------------------

  // Starts the 3-minute panic countdown
  void _startCountdown() {
    _secondsRemaining = 180;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _countdownTimer?.cancel();
          // TODO: Trigger Backend API Alert Here
        }
      });
    });
  }

  // Detects "Hold Down" gesture to fill the ring
  void _startHolding() {
    if (_isPanicMode) return;
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    _holdTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        _holdProgress += 0.012; // Adjust speed of fill here
        if (_holdProgress >= 1.0) {
          // Threshold reached: Activate Panic Mode
          _holdTimer?.cancel();
          _isPanicMode = true;
          _startCountdown();
        }
      });
    });
  }

  // Detects release of the button
  void _stopHolding() {
    _holdTimer?.cancel();
    if (!_isPanicMode) {
      setState(() {
        _isHolding = false;
        _holdProgress = 0.0;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILDER
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.background, // Deep Matte Midnight (Solid Color)

      // Stack allows us to keep the screens alive in the background
      // 'Offstage' hides screens without destroying their state
      body: Stack(
        children: [
          // --- TAB 0: HOME DASHBOARD (SOS) ---
          Offstage(
            offstage: _selectedIndex != 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 30),

                    // 1. Status Pill (Hidden during Panic Mode)
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

                    // 2. Main SOS Interface (Center of Screen)
                    Expanded(
                      child: Center(
                        child: _isPanicMode
                            ? _buildPanicUI() // Show Red Timer
                            : _buildSafeUI(), // Show Blue Ring
                      ),
                    ),

                    // 3. Action Buttons (Only visible in Panic Mode)
                    if (_isPanicMode) ...[
                      // Cancel Button
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

                      // Instant Send Button (Big Red Button)
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () {/* Instant Send Logic */},
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
                      const SizedBox(height: 120), // Spacer for footer
                    ] else ...[
                      const SizedBox(height: 100),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // --- TAB 1: MAP / SAFETY SCORE ---
          Offstage(
            offstage: _selectedIndex != 1,
            child: SafetyScoreScreen(onViewMap: _goToLiveMap),
          ),

          // --- TAB 2: CONTACTS ---
          Offstage(
            offstage: _selectedIndex != 2,
            child: const ContactsScreen(),
          ),

          // --- TAB 3: PROFILE ---
          Offstage(
            offstage: _selectedIndex != 3,
            child: const ProfileScreen(), // Displays the Profile UI
          ),
        ],
      ),

      // --- CUSTOM FLOATING FOOTER ---
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
=======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // 2. AMBIENT BACKGROUND GLOW
          Positioned.fill(
             child: Container(
               decoration: const BoxDecoration(
                 gradient: RadialGradient(
                   center: Alignment(0, -0.2), // Slightly top-center light
                   radius: 1.5,
                   colors: [AppColors.bgLight, AppColors.bgDark],
                   stops: [0.0, 1.0],
                 )
               ),
             ),
          ),
          
          // 3. MAIN CONTENT LAYOUT
          SafeArea(
            child: IndexedStack(
              index: _index,
              children: [
                _buildHomeContent(),
                const Center(child: Text("Map Feature Coming Soon", style: TextStyle(color: Colors.white54))),
                const ContactsScreen(),
                const ProfileScreen(), 
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        const SizedBox(height: 30),
        
        // STATUS PILL (Glassmorphism)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.success, blurRadius: 6)]
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Your Area: SAFE", 
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9), 
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5
                )
              )
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387
            ],
          ),
        ),
        
        // SPACER TO CENTER THE BUTTON
        const Spacer(),
        
        // PULSING SOS BUTTON
        GestureDetector(
          onTap: () {
            setState(() => _isPanic = !_isPanic);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Ripple (Fading)
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.5).animate(_pulseController),
                  child: Container(
                    width: 260, height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (_isPanic ? AppColors.alert : AppColors.primary).withOpacity(0.5),
                        width: 2
                      ),
                    ),
                  ),
                ),
              ),
              
              // Inner Glow (Breathing)
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_isPanic ? AppColors.alert : AppColors.primary).withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(
                        color: (_isPanic ? AppColors.alert : AppColors.primary).withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ]
                  ),
                ),
              ),
              
              // Solid Button Core
              Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isPanic 
                      ? [const Color(0xFFFF5252), const Color(0xFFB71C1C)]
                      : [AppColors.primary, const Color(0xFF0E7490)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isPanic ? AppColors.alert : AppColors.primary).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPanic ? Icons.notifications_active : Icons.touch_app_rounded, 
                      size: 52, 
                      color: Colors.white
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isPanic ? "SOS ACTIVE" : "HOLD SOS",
                      style: const TextStyle(
                        fontSize: 22, 
                        fontWeight: FontWeight.w800, 
                        color: Colors.white,
                        letterSpacing: 1.2
                      ),
                    ),
                    if (!_isPanic)
                      Text(
                        "Press & Hold", 
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7), 
                          fontSize: 12
                        )
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // SPACER TO PUSH BOTTOM NAV DOWN
        const Spacer(),
        const SizedBox(height: 60), // Extra space for Nav Bar
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.9), // Slate 800
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navIcon(Icons.shield_outlined, Icons.shield, 0),
          _navIcon(Icons.map_outlined, Icons.map, 1),
          _navIcon(Icons.people_outline, Icons.people, 2),
          _navIcon(Icons.person_outline, Icons.person, 3),
        ],
      ),
    );
  }

<<<<<<< HEAD
  // ---------------------------------------------------------------------------
  // HELPER WIDGETS (SOS STATES)
  // ---------------------------------------------------------------------------

  // State 1: Safe (Idle Mode)
  Widget _buildSafeUI() {
    return GestureDetector(
      onTapDown: (_) => _startHolding(),
      onTapUp: (_) => _stopHolding(),
      onTapCancel: () => _stopHolding(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse Animation (Blue)
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
          // Progress Ring (Draws the arc)
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
          // Center Icon & Text
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

  // State 2: Panic (Active Mode)
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
            // Red Alert Glow
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
            // Timer Progress Circle
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
            // Countdown Text
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

// ---------------------------------------------------------------------------
// CUSTOM PAINTER (RING ANIMATION)
// ---------------------------------------------------------------------------
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

    // Draw background track (Grey)
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round);

    // Draw progress arc (Colored)
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
=======
  Widget _navIcon(IconData iconOutlined, IconData iconFilled, int index) {
    final active = _index == index;
    return GestureDetector(
      onTap: () => setState(() => _index = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          active ? iconFilled : iconOutlined, 
          color: active ? AppColors.primary : AppColors.textSub, 
          size: 26
        ),
      ),
    );
  }
}
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387
