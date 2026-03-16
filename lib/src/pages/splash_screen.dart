import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/auth/screens/login_screen.dart';
import 'package:usafe_front_end/src/pages/home_screen.dart';
import 'package:usafe_front_end/widgets/sos_screen.dart';

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

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.forward();

    // 🔔 Ask notification permission ONCE at app start
    _requestNotificationPermissionOnce();

    _handleNavigation();
  }

  Future<void> _requestNotificationPermissionOnce() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _handleNavigation() async {
    final prefEmergency = await _consumeSOSTriggerFlag();
    bool isEmergency = widget.launchedFromSOSWidget || prefEmergency;

    if (isEmergency) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final source = await _consumeSOSTriggerSource();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SOSScreen(autoStart: true, triggerSource: source),
        ),
      );
      return;
    }

    await Future.delayed(const Duration(milliseconds: 2500));

    final loggedIn = await AuthService.validateSession();
    if (!mounted) return;

    if (loggedIn) {
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

  Future<bool> _consumeSOSTriggerFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final triggered = prefs.getBool('SOS_TRIGGERED') ??
          prefs.getBool('flutter.SOS_TRIGGERED') ??
          false;
      final ts = prefs.getInt('SOS_TRIGGERED_TS') ??
          prefs.getInt('flutter.SOS_TRIGGERED_TS') ??
          0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final withinWindow = ts > 0 && (now - ts) <= (30 * 1000);
      if (triggered) {
        await prefs.setBool('SOS_TRIGGERED', false);
        await prefs.setBool('flutter.SOS_TRIGGERED', false);
        await prefs.setInt('SOS_TRIGGERED_TS', 0);
        await prefs.setInt('flutter.SOS_TRIGGERED_TS', 0);
      }
      return triggered && withinWindow;
    } catch (_) {
      return false;
    }
  }

  Future<String> _consumeSOSTriggerSource() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final source =
          prefs.getString('SOS_TRIGGER_SOURCE') ??
          prefs.getString('flutter.SOS_TRIGGER_SOURCE') ??
          'notification';
      await prefs.remove('SOS_TRIGGER_SOURCE');
      await prefs.remove('flutter.SOS_TRIGGER_SOURCE');
      return source;
    } catch (_) {
      return 'notification';
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
                    errorBuilder: (_, __, ___) => const Icon(Icons.shield,
                        size: 100, color: AppColors.primarySky),
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
