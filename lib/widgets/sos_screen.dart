import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/core/services/contact_alert_service.dart';
import 'package:usafe_front_end/core/services/phone_call_service.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/auth/screens/login_screen.dart';
import 'package:usafe_front_end/src/pages/emergency_process_screen.dart';
import 'package:usafe_front_end/src/pages/home_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sos_hold_button.dart';

class SOSScreen extends StatefulWidget {
  final bool autoStart;
  final String? triggerSource;

  const SOSScreen({super.key, this.autoStart = false, this.triggerSource});

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
  bool _isGuestMode = false;
  bool _guestContactsLoaded = false;
  String? _guestContactsError;
  String? _guestContactsNotice;
  final List<Map<String, String>> _guestContacts = [];

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

    _primeGuestMode();
  }

  Future<void> _primeGuestMode() async {
    final token = await AuthService.getToken();
    if (!mounted) return;
    if (token.isEmpty) {
      setState(() => _isGuestMode = true);
      await _loadGuestContacts();
      if (mounted) setState(() {});
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

    await _resolveEmergencyMode();

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
    if (_isGuestMode) return;
    _statusPollTimer?.cancel();
    await _pollEmergencyStatus();
    _statusPollTimer = Timer.periodic(_statusPollInterval, (_) {
      _pollEmergencyStatus();
    });
  }

  Future<void> _pollEmergencyStatus() async {
    if (_isGuestMode) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login required to access other pages.'),
        ),
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
    if (_isGuestMode) {
      return _guestMessageAllContacts();
    }
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
    if (_isGuestMode) {
      return _guestCallContact(contactIndex);
    }
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
    if (_isGuestMode) {
      return _guestCall119();
    }
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
    if (_isGuestMode) {
      return const EmergencyActionResult(
        success: true,
        message: 'Emergency process stopped',
      );
    }
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
    final token = await AuthService.getToken();
    if (token.isEmpty) {
      _isGuestMode = true;
      await _loadGuestContacts();
      if (mounted) setState(() {});
      return true;
    }

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

  Future<void> _resolveEmergencyMode() async {
    if (_isGuestMode) {
      await _loadGuestContacts();
      if (mounted) setState(() {});
      return;
    }

    final token = await AuthService.getToken();
    if (token.isEmpty) {
      _isGuestMode = true;
      await _loadGuestContacts();
      if (mounted) setState(() {});
      return;
    }

    if (!widget.autoStart) {
      final validSession = await AuthService.validateSession();
      if (!validSession) {
        _isGuestMode = true;
        await _loadGuestContacts();
        if (mounted) setState(() {});
        return;
      }
    }

    if (!widget.autoStart) {
      try {
        final contacts = await AuthService.fetchContacts();
        if (contacts.isEmpty) {
          _isGuestMode = true;
          await _loadGuestContacts();
        }
      } catch (e) {
        final normalized = e.toString().toLowerCase();
        if (normalized.contains('not authenticated') ||
            normalized.contains('unauthorized')) {
          _isGuestMode = true;
          await _loadGuestContacts();
        }
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadGuestContacts() async {
    if (_guestContactsLoaded) return;
    _guestContactsLoaded = true;
    _guestContactsError = null;
    _guestContactsNotice = null;
    _guestContacts.clear();

    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      _guestContactsError =
          'Contacts permission is required to use SOS in guest mode.';
      return;
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    final favorites =
        contacts.where((c) => c.isStarred && c.phones.isNotEmpty).toList();
    final fallback =
        contacts.where((c) => c.phones.isNotEmpty).toList(growable: false);
    final selected = favorites.isNotEmpty ? favorites : fallback;
    if (favorites.isEmpty && selected.isNotEmpty) {
      _guestContactsNotice =
          'No starred contacts found. Using first 5 contacts with numbers.';
    }

    for (final contact in selected.take(5)) {
      final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
      final normalized = ContactAlertService.normalizePhoneNumber(phone);
      if (normalized.isEmpty) continue;

      final name = contact.displayName.trim().isNotEmpty
          ? contact.displayName.trim()
          : 'Unknown';
      _guestContacts.add({
        'name': name,
        'phone': normalized,
      });
    }

    if (_guestContacts.isEmpty) {
      _guestContactsError =
          'No favorite contacts with phone numbers were found.';
    }

    if (mounted) setState(() {});
  }

  Future<EmergencyActionResult> _guestMessageAllContacts() async {
    await _loadGuestContacts();
    if (_guestContacts.isEmpty) {
      return const EmergencyActionResult(
        success: false,
        message: 'No favorite contacts available for SOS messaging.',
      );
    }

    final numbers =
        _guestContacts.map((c) => c['phone'] ?? '').where((n) => n.isNotEmpty);
    final recipientPath = numbers.join(',');
    if (recipientPath.isEmpty) {
      return const EmergencyActionResult(
        success: false,
        message: 'No valid phone numbers available for SOS messaging.',
      );
    }

    final uri = Uri(
      scheme: 'sms',
      path: recipientPath,
      queryParameters: {
        'body': ContactAlertService.defaultEmergencyMessage,
      },
    );

    try {
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        return const EmergencyActionResult(
          success: false,
          message: 'Could not open the SMS app for SOS messaging.',
        );
      }
      return const EmergencyActionResult(
        success: true,
        message: 'SMS composer opened for favorite contacts.',
      );
    } catch (e) {
      return EmergencyActionResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  Future<EmergencyCallResult> _guestCallContact(int contactIndex) async {
    await _loadGuestContacts();
    final idx = contactIndex - 1;
    if (idx < 0 || idx >= _guestContacts.length) {
      return const EmergencyCallResult(
        success: false,
        answered: false,
        message: 'Favorite contact not available.',
        finalStatus: 'contact-missing',
      );
    }

    final phone = _guestContacts[idx]['phone'] ?? '';
    if (phone.isEmpty) {
      return const EmergencyCallResult(
        success: false,
        answered: false,
        message: 'Contact phone number is missing.',
        finalStatus: 'phone-missing',
      );
    }

    try {
      await PhoneCallService.call(phone);
      return const EmergencyCallResult(success: true, answered: false);
    } catch (e) {
      return EmergencyCallResult(
        success: false,
        answered: false,
        message: e.toString(),
        finalStatus: 'call-failed',
      );
    }
  }

  Future<EmergencyActionResult> _guestCall119() async {
    try {
      await PhoneCallService.call('119');
      return const EmergencyActionResult(
        success: true,
        message: 'Emergency services call started.',
      );
    } catch (e) {
      return EmergencyActionResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceLabel =
        _formatTriggerSource(widget.triggerSource, widget.autoStart);
    debugPrint(
      'SOSScreen: triggerSource=${widget.triggerSource} '
      'autoStart=${widget.autoStart} label=$sourceLabel',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: _isSosSent
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: _handleBackAction,
              ),
        title: Text(
          _isSosSent ? 'SYSTEM LOCKED' : 'EMERGENCY MODE',
          style: const TextStyle(fontSize: 16, color: Colors.white70),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            _buildTopHeader(sourceLabel),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogoGlow(),
                    const SizedBox(height: 20),
                    Text(
                      _isSosSent ? 'EMERGENCY ACTIVATED' : 'SOS ACTIVATING',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.alert,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 34),
                    SizedBox(
                      width: 210,
                      height: 210,
                      child: _isSosSent
                          ? const Icon(Icons.gpp_maybe_rounded,
                              color: AppColors.alert, size: 160)
                          : AnimatedBuilder(
                              animation: _timerController,
                              builder: (context, child) {
                                return CircularProgressIndicator(
                                  value: _timerController.value,
                                  strokeWidth: 12,
                                  backgroundColor:
                                      AppColors.surfaceElevated.withOpacity(0.6),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          AppColors.alert),
                                  strokeCap: StrokeCap.round,
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 26),
                    if (_isSosSent)
                      Column(
                        children: [
                          const Text(
                            'Triggered SOS System',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Emergency process started at $_triggeredTime',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 14),
                          ),
                          if (_isGuestMode) ...[
                            const SizedBox(height: 8),
                            Text(
                              _guestContactsError ??
                                  _guestContactsNotice ??
                                  'Guest mode: using phone favorites (up to 5).',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
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
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          );
                        },
                      ),
                    const SizedBox(height: 36),
                    if (!_isSosSent) ...[
                      if (!widget.autoStart && !_timerController.isAnimating)
                        SOSHoldButton(
                            onSOSTriggered: () => _timerController.forward())
                      else
                        const Icon(Icons.sensors,
                            color: AppColors.alert, size: 84),
                      const SizedBox(height: 26),
                      TextButton(
                        onPressed: _handleBackAction,
                        child: const Text('CANCEL SOS',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 16)),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: OutlinedButton(
                          onPressed:
                              _isStartingProcess ? null : _navigateToSafeExit,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color:
                                    AppColors.border.withOpacity(0.8)),
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
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(String sourceLabel) {
    final sourceStatus = _formatTriggerStatus(sourceLabel);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withOpacity(0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.alert,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'SOS MODE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_active_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  sourceStatus,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTriggerSource(String? source, bool autoStart) {
    final raw = (source ?? '').trim();
    if (raw.isEmpty) {
      return autoStart ? 'Notification' : 'In-app';
    }

    switch (raw.toLowerCase()) {
      case 'widget':
        return 'Widget';
      case 'notification':
        return 'Notification';
      case 'usafe badge':
        return 'Quick Tile';
      default:
        return raw;
    }
  }

  String _formatTriggerStatus(String sourceLabel) {
    switch (sourceLabel) {
      case 'Widget':
        return 'Pressed Widget';
      case 'Quick Tile':
        return 'Pressed Quick Tile';
      case 'Notification':
        return 'Pressed Notification';
      default:
        return 'Triggered by $sourceLabel';
    }
  }

  Widget _buildLogoGlow() {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 28,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: AppColors.alert.withOpacity(0.18),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.8), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          'assets/usafe_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.shield,
            size: 40,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

