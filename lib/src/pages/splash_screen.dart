import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/auth/screens/login_screen.dart';
import 'package:usafe_front_end/src/pages/home_screen.dart';
import 'package:usafe_front_end/widgets/sos_screen.dart';

const platform = MethodChannel('com.usafe_frontend/sos');

class SplashScreen extends StatefulWidget {
  final bool launchedFromSOSWidget;

  const SplashScreen({super.key, this.launchedFromSOSWidget = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup the fade controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Using easeInOut for a more premium "Pro" feel
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.forward();

    // Start the navigation logic
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    // 1. Minimum time to show the logo during NORMAL conditions (2.5 seconds)
    final minDisplayTime = Future.delayed(const Duration(milliseconds: 2500));

    bool launchedFromWidget = widget.launchedFromSOSWidget;

    // 2. Check the native side for the SOS flag
    try {
      final bool? nativeTrigger =
          await platform.invokeMethod<bool>('checkSOSTrigger');
      if (nativeTrigger != null) {
        launchedFromWidget = nativeTrigger;
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get SOS trigger: '${e.message}'.");
    }

    // 🚨 3. EMERGENCY BYPASS
    // If it's an emergency, we don't wait for animations or tokens.
    // We navigate IMMEDIATELY.
    if (launchedFromWidget) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const SOSScreen(autoStart: true),
        ),
      );
      return; // Stop execution here
    }

    // 🔐 4. NORMAL FLOW
    // Wait for the minimum display time to finish so the UI doesn't flicker
    await minDisplayTime;

    final token = await AuthService.getToken();
    if (!mounted) return;

    if (token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, AppColors.backgroundBlack],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Logo Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primarySky.withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primarySky.withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Image.asset(
                    'assets/usafe_logo.png',
                    height: 120,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.shield,
                      size: 100,
                      color: AppColors.primarySky,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "USafe",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Intelligent Personal Safety",
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
