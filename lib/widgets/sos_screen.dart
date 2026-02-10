import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart'; // 🚨 Needed for token check
import 'package:usafe_front_end/features/auth/screens/login_screen.dart'; // 🚨 Needed for redirect
import 'package:usafe_front_end/src/pages/home_screen.dart';
import 'sos_hold_button.dart';

class SOSScreen extends StatefulWidget {
  final bool autoStart;

  const SOSScreen({super.key, this.autoStart = false});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerController;
  static const int _countdownSeconds = 10;
  bool _isSosSent = false;
  String _triggeredTime = "";

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _countdownSeconds),
    );

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _sendSOS();
      }
    });

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _timerController.forward();
      });
    }
  }

  void _sendSOS() {
    if (!mounted) return;
    setState(() {
      _isSosSent = true;
      _triggeredTime = DateFormat('hh:mm:ss a').format(DateTime.now());
    });
  }

  // 🚨 NEW SECURE NAVIGATION LOGIC
  Future<void> _navigateToSafeExit() async {
    final token = await AuthService.getToken();
    if (!mounted) return;

    if (token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // If no token, force them back to Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _handleBackAction() {
    _timerController.stop();
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      _navigateToSafeExit(); // Use secure exit
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSosSent
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: _handleBackAction,
              ),
        title: Text(
          _isSosSent ? "SYSTEM LOCKED" : "EMERGENCY MODE",
          style: const TextStyle(fontSize: 16, color: Colors.white54),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isSosSent ? "EMERGENCY ACTIVATED" : "SOS ACTIVATING",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: 200,
                height: 200,
                child: _isSosSent
                    ? const Icon(Icons.gpp_maybe_rounded,
                        color: Colors.redAccent, size: 150)
                    : AnimatedBuilder(
                        animation: _timerController,
                        builder: (context, child) {
                          return CircularProgressIndicator(
                            value: _timerController.value,
                            strokeWidth: 12,
                            backgroundColor: Colors.red.withOpacity(0.1),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(Colors.red),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 30),
              if (_isSosSent)
                Column(
                  children: [
                    const Text(
                      "Triggered SOS System",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Alert successfully sent at $_triggeredTime",
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                )
              else
                AnimatedBuilder(
                  animation: _timerController,
                  builder: (context, child) {
                    final remaining =
                        (_countdownSeconds * (1 - _timerController.value))
                            .ceil();
                    return Text(
                      "Sending alert in $remaining seconds",
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    );
                  },
                ),
              const SizedBox(height: 50),
              if (!_isSosSent) ...[
                if (!widget.autoStart && !_timerController.isAnimating)
                  SOSHoldButton(
                      onSOSTriggered: () => _timerController.forward())
                else
                  const Icon(Icons.sensors, color: Colors.red, size: 80),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: _handleBackAction,
                  child: const Text("CANCEL SOS",
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: OutlinedButton(
                    onPressed: _navigateToSafeExit, // Use secure exit
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 30),
                    ),
                    child: const Text("I AM SAFE - DISMISS",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
