import 'package:flutter/material.dart';
import 'dart:async'; // For Timer logic (SOS hold & countdown)
import 'dart:math' as math; // For drawing arcs in the CustomPainter
import 'config.dart'; // Brand colors (AppColors)
import 'contacts_screen.dart';
import 'safety_score_screen.dart';

/// ---------------------------------------------------------------------------
/// HOME SCREEN
///
/// This is the main dashboard of the application. It handles:
/// 1. Bottom Navigation (Home, Map, Contacts, Profile).
/// 2. The Core SOS Logic (Hold-to-activate, Countdown, Panic State).
/// 3. Displaying the Safety Score screen when 'Map' is clicked.
/// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // STATE VARIABLES
  // ---------------------------------------------------------------------------

  // Controls which tab is currently visible (0: Home, 1: Map, 2: Contacts, 3: Profile)
  int _selectedIndex = 0;

  // -- SOS System State --
  bool _isPanicMode = false; // True if SOS has been triggered
  bool _isHolding = false; // True if user is currently pressing the button
  double _holdProgress = 0.0; // 0.0 to 1.0 (Progress of the hold circle)

  // -- Timers & Animation --
  Timer? _holdTimer; // Runs while holding the button (fills the ring)
  Timer? _countdownTimer; // Runs after SOS triggers (3 min countdown)
  int _secondsRemaining = 180; // 3 Minutes in seconds
  late AnimationController
      _pulseController; // Handles the "breathing" animation of the button

  // ---------------------------------------------------------------------------
  // LIFECYCLE METHODS
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    // Initialize the breathing animation (2 seconds in, 2 seconds out)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    // Always clean up timers and controllers to prevent memory leaks
    _pulseController.dispose();
    _holdTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOGIC & FUNCTIONS
  // ---------------------------------------------------------------------------

  /// Handles switching tabs in the bottom navigation bar.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Placeholder for future map navigation logic.
  void _goToLiveMap() {
    print("Navigate to Live Map Page");
    // TODO: Push the actual Google Maps route here
  }

  /// Starts the 3-minute countdown when Panic Mode is active.
  void _startCountdown() {
    _secondsRemaining = 180; // Reset to 3 mins
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _countdownTimer?.cancel();
          // TODO: Trigger the actual API call to send the emergency alert here
        }
      });
    });
  }

  /// Called when the user presses down on the SOS button.
  /// Increments progress every 16ms to fill the ring smoothly.
  void _startHolding() {
    if (_isPanicMode) return; // Prevent holding if already in panic mode

    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    _holdTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        _holdProgress +=
            0.012; // Increment speed (adjust this to change hold time)

        // Threshold reached (Ring full)
        if (_holdProgress >= 1.0) {
          _holdTimer?.cancel();
          _isPanicMode = true; // Trigger SOS
          _startCountdown(); // Start the timer
        }
      });
    });
  }

  /// Called when the user releases the button.
  /// Resets progress if the threshold wasn't reached.
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
  // MAIN UI BUILDER
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Deep Matte Midnight

      // Using a Stack to keep all screens alive in the background.
      // 'Offstage' hides screens without destroying their state.
      body: Stack(
        children: [
          // --- TAB 0: HOME DASHBOARD ---
          Offstage(
            offstage: _selectedIndex != 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 30),

                    // 1. Status Pill (Visual indicator of safety)
                    // Hides when in Panic Mode to reduce clutter
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

                    // 2. The Main Interface (Swaps between Safe Circle and Panic Timer)
                    Expanded(
                      child: Center(
                        child: _isPanicMode ? _buildPanicUI() : _buildSafeUI(),
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
                              _isPanicMode = false; // Reset State
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

                      // Instant Send Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement instant alert logic
                          },
                          icon: const Icon(Icons.send, color: Colors.white),
                          label: const Text("SEND HELP NOW",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.alertRed, // High contrast Red
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
          // Shows the SafetyScoreScreen (which links to the Map)
          Offstage(
            offstage: _selectedIndex != 1,
            child: SafetyScoreScreen(onViewMap: _goToLiveMap),
          ),

          // --- TAB 2: CONTACTS ---
          Offstage(
            offstage: _selectedIndex != 2,
            child: const ContactsScreen(),
          ),

          // --- TAB 3: PROFILE (Placeholder) ---
          Offstage(
            offstage: _selectedIndex != 3,
            child: const Center(
                child: Text("Profile Feature Coming Soon",
                    style: TextStyle(color: Colors.white))),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // CUSTOM BOTTOM NAVIGATION BAR (Floating Oval Style)
      // -----------------------------------------------------------------------
      extendBody: true, // Allows content to flow behind the floating footer
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
            showSelectedLabels: false, // Clean look without text
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

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------

  /// The UI shown when the app is in "Safe" mode (Idle state).
  /// Features a breathing circle and hold detection.
  Widget _buildSafeUI() {
    return GestureDetector(
      onTapDown: (_) => _startHolding(),
      onTapUp: (_) => _stopHolding(),
      onTapCancel: () => _stopHolding(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. The Breathing Pulse Animation
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.08).animate(_pulseController),
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      AppColors.primarySky.withOpacity(0.1), // Brand Blue Glow
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primarySky.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5)
                  ]),
            ),
          ),

          // 2. The Progress Ring (Fills up when held)
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

          // 3. Central Icon & Text
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

  /// The UI shown when SOS has been triggered.
  /// Features a countdown timer and Red alert styling.
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
                value: _secondsRemaining / 180, // Normalizes 180s to 0.0-1.0
                strokeWidth: 12,
                backgroundColor: AppColors.surfaceCard,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.alertRed),
              ),
            ),
            // Countdown Text (MM:SS)
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
// CUSTOM PAINTER (For the Hold-Progress Ring)
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

    // Draw the background track (Grey ring)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Draw the active progress arc (Blue ring)
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2, // Start from top
          2 * math.pi * progress, // Sweep angle based on hold progress
          false,
          progressPaint);
    }
  }

  @override
  bool shouldRepaint(ModernRingPainter old) =>
      old.progress != progress || old.color != color;
}
