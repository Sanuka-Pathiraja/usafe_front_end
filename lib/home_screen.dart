import 'package:flutter/material.dart';
import 'dart:async'; // For Timer if needed later
import 'config.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _isPanic = false;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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