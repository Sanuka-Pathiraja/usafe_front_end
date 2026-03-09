import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/auth/screens/login_screen.dart';
import 'package:usafe_front_end/src/pages/emergency_process_screen.dart';
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
  static const Duration _statusPollInterval = Duration(seconds: 3);

  bool _isSosSent = false;
  bool _isStartingProcess = false;
  String _triggeredTime = '';
  String? _emergencySessionId;
  Timer? _statusPollTimer;
  bool _sessionAnswered = false;
  Map<String, dynamic>? _latestSessionStatus;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _countdownSeconds),
    );

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _beginEmergencyFlow();
      }
    });

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _timerController.forward();
      });
    }
  }

  void _markSosTriggered() {
    if (!mounted) return;
    setState(() {
      _isSosSent = true;
      _triggeredTime = DateFormat('hh:mm:ss a').format(DateTime.now());
    });
  }

  Future<void> _beginEmergencyFlow() async {
    if (_isStartingProcess) return;
    _isStartingProcess = true;
    _timerController.stop();
    _markSosTriggered();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyProcessScreen(
          onMessageAllContacts: _onMessageAllContacts,
          onCallContact: _onCallContact,
          onCall119: _onCall119,
          onCancelEmergency: _onCancelEmergency,
        ),
      ),
    );

    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _emergencySessionId = null;
    _latestSessionStatus = null;
    _sessionAnswered = false;
    _isStartingProcess = false;

    if (mounted) {
      await _navigateToSafeExit();
    }
  }

  String? _extractSessionId(Map<String, dynamic> response) {
    final dynamic id =
        response['sessionId'] ?? response['sessionID'] ?? response['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  Future<void> _startStatusPolling() async {
    _statusPollTimer?.cancel();
    await _pollEmergencyStatus();
    _statusPollTimer = Timer.periodic(_statusPollInterval, (_) {
      _pollEmergencyStatus();
    });
  }

  Future<void> _pollEmergencyStatus() async {
    final sessionId = _emergencySessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    try {
      final response = await AuthService.getEmergencyStatus(sessionId: sessionId);
      _latestSessionStatus = response;

      final status = (response['status'] ?? response['finalStatus'] ?? '')
          .toString()
          .toUpperCase();
      if (status == 'ANSWERED' ||
          (response['answeredBy'] != null &&
              response['answeredBy'].toString().isNotEmpty)) {
        _sessionAnswered = true;
      }

      if (status == 'CANCELLED' ||
          status == 'FAILED' ||
          status == 'COMPLETED' ||
          status == 'ANSWERED') {
        _statusPollTimer?.cancel();
      }
    } catch (e) {
      await _handleUnauthorizedError(e);
    }
  }

  Future<void> _navigateToSafeExit() async {
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

  void _handleBackAction() {
    _timerController.stop();
    _statusPollTimer?.cancel();
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      _navigateToSafeExit();
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    _statusPollTimer?.cancel();
    super.dispose();
  }

  Future<EmergencyActionResult> _onMessageAllContacts() async {
    Map<String, dynamic> response;
    try {
      response = await AuthService.startEmergency();
    } catch (e) {
      if (await _handleUnauthorizedError(e)) {
        return const EmergencyActionResult(
          success: false,
          message: 'Session expired. Please re-login.',
        );
      }
      return EmergencyActionResult(success: false, message: e.toString());
    }

    final sessionId = _extractSessionId(response);
    if (sessionId == null || sessionId.isEmpty) {
      return const EmergencyActionResult(
        success: false,
        message: 'Emergency session id missing in response',
      );
    }

    _emergencySessionId = sessionId;
    await _startStatusPolling();

    final assessment = AuthService.assessEmergencyStartResponse(response);
    return EmergencyActionResult(
      success: true,
      message: assessment.message,
    );
  }

  Future<EmergencyCallResult> _onCallContact(int contactIndex) async {
    if (_sessionAnswered) {
      return const EmergencyCallResult(success: true, answered: true);
    }

    final sessionId = _emergencySessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return const EmergencyCallResult(
        success: false,
        answered: false,
        message: 'Emergency session not initialized',
        finalStatus: 'session-missing',
      );
    }

    Map<String, dynamic> response;
    try {
      response = await AuthService.attemptEmergencyContactCall(
        sessionId: sessionId,
        contactIndex: contactIndex,
        timeoutSec: 30,
      );
    } catch (e) {
      if (await _handleUnauthorizedError(e)) {
        return const EmergencyCallResult(
          success: false,
          answered: false,
          message: 'Session expired. Please re-login.',
          finalStatus: 'unauthorized',
        );
      }
      return EmergencyCallResult(
        success: false,
        answered: false,
        message: e.toString(),
        finalStatus: 'failed',
      );
    }

    final finalStatus = (response['finalStatus'] ?? response['status'] ?? '')
        .toString()
        .toUpperCase();
    final latestStatus = (_latestSessionStatus?['status'] ?? '')
        .toString()
        .toUpperCase();
    final answered = response['answered'] == true ||
        finalStatus == 'ANSWERED' ||
        latestStatus == 'ANSWERED' ||
        (response['answeredBy'] != null &&
            response['answeredBy'].toString().isNotEmpty);
    if (answered) _sessionAnswered = true;

    final explicitFail = response['success'] == false || response['ok'] == false;
    final providerFailed =
        finalStatus == 'FAILED' || finalStatus == 'NO_ANSWER' || finalStatus == 'BUSY';
    final success = answered ? true : !(explicitFail || providerFailed);

    return EmergencyCallResult(
      success: success,
      answered: answered,
      message: response['message']?.toString(),
      finalStatus: finalStatus.isEmpty ? null : finalStatus,
    );
  }

  Future<EmergencyActionResult> _onCall119() async {
    final sessionId = _emergencySessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return const EmergencyActionResult(
        success: false,
        message: 'Emergency session not initialized',
      );
    }

    Map<String, dynamic> response;
    try {
      response = await AuthService.callEmergency119(sessionId: sessionId);
    } catch (e) {
      if (await _handleUnauthorizedError(e)) {
        return const EmergencyActionResult(
          success: false,
          message: 'Session expired. Please re-login.',
        );
      }
      return EmergencyActionResult(success: false, message: e.toString());
    }

    final explicitFail = response['success'] == false || response['ok'] == false;
    final called = response['emergencyServicesCalled'];
    final callFlagFailed = called is bool && called == false;
    return EmergencyActionResult(
      success: !(explicitFail || callFlagFailed),
      message: response['message']?.toString(),
    );
  }

  Future<EmergencyActionResult> _onCancelEmergency() async {
    final sessionId = _emergencySessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return const EmergencyActionResult(
        success: true,
        message: 'Emergency process stopped',
      );
    }

    Map<String, dynamic> response;
    try {
      response = await AuthService.cancelEmergency(sessionId: sessionId);
    } catch (e) {
      if (await _handleUnauthorizedError(e)) {
        return const EmergencyActionResult(
          success: false,
          message: 'Session expired. Please re-login.',
        );
      }
      return const EmergencyActionResult(
        success: false,
        message:
            'Emergency was stopped. We could not confirm contact notifications.',
      );
    } finally {
      _statusPollTimer?.cancel();
    }

    final ok = response['ok'] != false && response['success'] != false;
    return EmergencyActionResult(
      success: ok,
      message: response['message']?.toString() ?? 'Emergency process cancelled.',
    );
  }

  Future<bool> _handleUnauthorizedError(Object error) async {
    if (error is EmergencyApiException && error.statusCode == 401) {
      await AuthService.logout();
      if (!mounted) return true;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return true;
    }

    final normalized = error.toString().toUpperCase();
    final unauthorized = normalized.contains('UNAUTHORIZED') ||
        normalized.contains('HTTP 401') ||
        normalized.contains('INVALID OR EXPIRED TOKEN') ||
        normalized.contains('NO TOKEN PROVIDED');
    if (!unauthorized) return false;

    await AuthService.logout();
    if (!mounted) return true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    return true;
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
          _isSosSent ? 'SYSTEM LOCKED' : 'EMERGENCY MODE',
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
                _isSosSent ? 'EMERGENCY ACTIVATED' : 'SOS ACTIVATING',
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
                      'Triggered SOS System',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Emergency process started at $_triggeredTime',
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
                      'Sending alert in $remaining seconds',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    );
                  },
                ),
              const SizedBox(height: 50),
              if (!_isSosSent) ...[
                if (!widget.autoStart && !_timerController.isAnimating)
                  SOSHoldButton(onSOSTriggered: () => _timerController.forward())
                else
                  const Icon(Icons.sensors, color: Colors.red, size: 80),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: _handleBackAction,
                  child: const Text('CANCEL SOS',
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: OutlinedButton(
                    onPressed: _isStartingProcess ? null : _navigateToSafeExit,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 30),
                    ),
                    child: Text(
                      _isStartingProcess
                          ? 'STARTING EMERGENCY...'
                          : 'I AM SAFE - DISMISS',
                      style: const TextStyle(color: Colors.white),
                    ),
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

