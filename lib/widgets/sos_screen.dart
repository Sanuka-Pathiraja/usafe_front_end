import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'sos_hold_button.dart';

class SOSScreen extends StatefulWidget {
  final bool
      autoStart; // This must be true when coming from the widget/notification

  const SOSScreen({super.key, this.autoStart = false});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerController;
  static const int _countdownSeconds = 5;
  bool _isSosSent = false;

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

    // 🚨 TRIGGER START: If autoStart is true, start the timer immediately on load
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _timerController.forward();
        }
      });
    }
  }

  void _sendSOS() {
    setState(() => _isSosSent = true);
    debugPrint("🚨 SOS ALERT SENT TO EMERGENCY CONTACTS");
    // TODO: Trigger your SMS/Backend API here
  }

  void _cancelSOS() {
    _timerController.stop();
    Navigator.of(context).pop();
  }

  void _startManualSOS() {
    _timerController.forward();
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
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🔴 DYNAMIC TITLE
              Text(
                _isSosSent ? "SOS SENT" : "SOS ACTIVATING",
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),

              const SizedBox(height: 50),

              // ⏱️ PROGRESS CIRCLE
              SizedBox(
                width: 200,
                height: 200,
                child: AnimatedBuilder(
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

              // 🧠 COUNTDOWN TEXT
              AnimatedBuilder(
                animation: _timerController,
                builder: (context, child) {
                  final remaining =
                      (_countdownSeconds * (1 - _timerController.value)).ceil();
                  return Text(
                    _isSosSent
                        ? "Help is on the way!"
                        : "Sending alert in $remaining seconds",
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  );
                },
              ),

              const SizedBox(height: 50),

              // 🔘 BUTTON LOGIC
              // Hide the hold button if the timer is already running (autoStart)
              if (!widget.autoStart &&
                  !_timerController.isAnimating &&
                  !_isSosSent)
                SOSHoldButton(onSOSTriggered: _startManualSOS)
              else if (widget.autoStart || _timerController.isAnimating)
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 80),

              const SizedBox(height: 40),

              // ❌ CANCEL BUTTON
              if (!_isSosSent)
                TextButton(
                  onPressed: _cancelSOS,
                  child: const Text(
                    "CANCEL",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
