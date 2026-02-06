import 'package:flutter/material.dart';
import 'dart:async';
import 'config.dart'; // Ensure this file exists from previous steps

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Navigation State
  int _currentIndex = 0;
  
  // SOS State
  bool _isSOSActive = false;
  int _countdown = 180; // 3 minutes
  Timer? _timer;

  // AI Simulation State (To demo the "Intelligent" features)
  bool _isHighRiskArea = false; 

  void _toggleSOS() {
    setState(() {
      _isSOSActive = !_isSOSActive;
      if (_isSOSActive) {
        _startCountdown();
      } else {
        _stopCountdown();
      }
    });
  }

  void _startCountdown() {
    _countdown = 180;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        _stopCountdown();
        // Here you would navigate to the "Help Sent" screen
      }
    });
  }

  void _stopCountdown() {
    _timer?.cancel();
    setState(() {
      _isSOSActive = false;
      _countdown = 180;
    });
  }

  // Toggle "Demo Mode" to show High Risk UI
  void _toggleSimulation() {
    setState(() {
      _isHighRiskArea = !_isHighRiskArea;
    });
    
    // Show a snackbar to explain what happened
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isHighRiskArea 
          ? "Simulating: Entered High Risk Area (AI Active)" 
          : "Simulating: Safe Zone"),
        backgroundColor: _isHighRiskArea ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Hi Nimali,",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _isHighRiskArea ? "High Risk Area" : "You are in a Safe Zone",
              style: TextStyle(
                color: _isHighRiskArea ? Colors.redAccent : AppColors.primarySky,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          // SIMULATION TOGGLE (For Demo/Testing)
          IconButton(
            icon: Icon(_isHighRiskArea ? Icons.warning : Icons.bug_report, color: Colors.white54),
            tooltip: "Toggle Simulation",
            onPressed: _toggleSimulation,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ---------------------------------------------------------
              // 1. AI PROACTIVE STATUS CHIPS (The New "Intelligent" Part)
              // ---------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AIStatusChip(
                    label: "Sound Detect",
                    icon: Icons.mic,
                    isActive: _isHighRiskArea, // Active only in high risk
                    activeColor: Colors.redAccent,
                  ),
                  _AIStatusChip(
                    label: "Motion Sense",
                    icon: Icons.directions_walk,
                    isActive: _isHighRiskArea,
                    activeColor: Colors.orangeAccent,
                  ),
                  const _AIStatusChip(
                    label: "GPS Tracking",
                    icon: Icons.gps_fixed,
                    isActive: true, // Always active
                    activeColor: AppColors.primarySky,
                  ),
                ],
              ),

              const Spacer(),

              // ---------------------------------------------------------
              // 2. SOS RING (The Core Feature)
              // ---------------------------------------------------------
              GestureDetector(
                onLongPress: _toggleSOS, // Hold to activate
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 260,
                  width: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isSOSActive 
                        ? [Colors.redAccent, Colors.deepOrange]
                        : [AppColors.surfaceCard, AppColors.backgroundBlack],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isSOSActive 
                          ? Colors.redAccent.withOpacity(0.5) 
                          : AppColors.primarySky.withOpacity(0.1),
                        blurRadius: _isSOSActive ? 50 : 30,
                        spreadRadius: _isSOSActive ? 20 : 5,
                      )
                    ],
                    border: Border.all(
                      color: _isSOSActive ? Colors.white : AppColors.primarySky.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app, 
                        size: 60, 
                        color: _isSOSActive ? Colors.white : AppColors.textGrey
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isSOSActive ? "$_countdown" : "HOLD SOS",
                        style: TextStyle(
                          fontSize: _isSOSActive ? 60 : 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_isSOSActive)
                        const Text("Seconds to cancel", style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ---------------------------------------------------------
              // 3. SAFETY TIPS / FOOTER
              // ---------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_moon, color: AppColors.primarySky, size: 30),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Home Mode Active", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(
                            "We are monitoring your perimeter.", 
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      
      // ---------------------------------------------------------
      // 4. BOTTOM NAVIGATION
      // ---------------------------------------------------------
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.background,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.primarySky,
        unselectedItemColor: Colors.white24,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Contacts'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CUSTOM WIDGET: ANIMATED AI STATUS CHIP
// ---------------------------------------------------------------------------
class _AIStatusChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;

  const _AIStatusChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
  });

  @override
  State<_AIStatusChip> createState() => _AIStatusChipState();
}

class _AIStatusChipState extends State<_AIStatusChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _AIStatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isActive ? widget.activeColor.withOpacity(0.2) : AppColors.surfaceCard,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isActive ? widget.activeColor : Colors.white10,
              width: 1.5,
            ),
            boxShadow: widget.isActive ? [
              BoxShadow(
                color: widget.activeColor.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ] : [],
          ),
          child: widget.isActive
            ? FadeTransition( // The Pulsing Effect
                opacity: _pulseAnimation,
                child: Icon(widget.icon, color: widget.activeColor, size: 24),
              )
            : Icon(widget.icon, color: Colors.white24, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: TextStyle(
            color: widget.isActive ? Colors.white : Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}