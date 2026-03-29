import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:usafe_front_end/core/services/contact_alert_service.dart';
import 'package:usafe_front_end/core/services/phone_call_service.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/auth/screens/login_screen.dart';
import 'package:usafe_front_end/src/pages/emergency_process_screen.dart';
import 'package:usafe_front_end/src/pages/emergency_result_screen.dart';
import 'package:usafe_front_end/src/pages/home_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sos_hold_button.dart';

// ── Danger palette (SOS screen only) ──────────────────────────────────────
const Color _kBgDeep     = Color(0xFF090303);
const Color _kSosRed     = Color(0xFFFF2D2D);
const Color _kGlassRed   = Color(0x22FF2D2D);
const Color _kGlassBdr   = Color(0x55FF4444);
const Color _kGlassWhite = Color(0x0FFFFFFF);
const Color _kAmber      = Color(0xFFFFAA00);

class SOSScreen extends StatefulWidget {
  final bool autoStart;
  final String? triggerSource;

  const SOSScreen({super.key, this.autoStart = false, this.triggerSource});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen>
    with TickerProviderStateMixin {
  late AnimationController _timerController;
  late AnimationController _rippleController;
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

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

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
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyProcessScreen(
          onMessageAllContacts: _onMessageAllContacts,
          onCallContact: _onCallContact,
          onCall119: _onCall119,
          onCancelEmergency: _onCancelEmergency,
          onSessionFinished: _onSessionFinished,
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
    _rippleController.dispose();
    _statusPollTimer?.cancel();
    super.dispose();
  }

  Future<EmergencyActionResult> _onMessageAllContacts() async {
    if (_isGuestMode) {
      return _guestMessageAllContacts();
    }
    Map<String, dynamic> response;
    try {
      response = await AuthService.startEmergency(
        payload: await _buildEmergencyStartPayload(),
      );
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

  /// Fired by [EmergencyProcessScreen] just before it shows the result screen.
  /// For cancelled sessions the backend is already notified via [_onCancelEmergency];
  /// here we only update COMPLETED and FAILED outcomes.
  Future<void> _onSessionFinished(EmergencySummary summary) async {
    final sessionId = _emergencySessionId;
    if (sessionId == null || sessionId.isEmpty || _isGuestMode) return;
    if (summary.outcome == EmergencyOutcome.cancelled) return;

    final status = summary.outcome == EmergencyOutcome.completed
        ? 'COMPLETED'
        : 'FAILED';
    try {
      await AuthService.finishEmergencySession(
        sessionId: sessionId,
        status: status,
        details: {
          'someoneAnswered': summary.someoneAnswered,
          'emergencyServicesCalled': summary.emergencyServicesCalled,
          'contactsMessaged': summary.contactsMessaged,
          if (summary.failedStepTitle != null)
            'failedStepTitle': summary.failedStepTitle,
          if (summary.failedStepReason != null)
            'failedStepReason': summary.failedStepReason,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[SOS] finishEmergencySession failed: $e');
    }
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

  Future<Map<String, dynamic>> _buildEmergencyStartPayload() async {
    final payload = <String, dynamic>{};

    final currentUser = await AuthService.getCurrentUser();
    _debugEmergencyPayload('currentUser=$currentUser');
    final userName = _displayNameFromUser(currentUser);
    if (userName.isNotEmpty) {
      payload['userName'] = userName;
      _debugEmergencyPayload('resolved userName=$userName');
    } else {
      _debugEmergencyPayload('userName unavailable');
    }

    final position = await _getEmergencyPosition();
    if (position != null) {
      payload['latitude'] = position.latitude;
      payload['longitude'] = position.longitude;
      _debugEmergencyPayload(
        'resolved coordinates lat=${position.latitude}, lng=${position.longitude}',
      );

      final approximateAddress = await _resolveApproximateAddress(position);
      if (approximateAddress.isNotEmpty) {
        payload['approximateAddress'] = approximateAddress;
        _debugEmergencyPayload(
          'resolved approximateAddress=$approximateAddress',
        );
      } else {
        _debugEmergencyPayload('approximateAddress unavailable');
      }
    } else {
      _debugEmergencyPayload('coordinates unavailable');
    }

    _debugEmergencyPayload('final payload=$payload');
    return payload;
  }

  void _debugEmergencyPayload(String message) {
    if (kDebugMode) {
      debugPrint('[EmergencyStartPayload] $message');
    }
  }

  String _displayNameFromUser(Map<String, dynamic>? user) {
    if (user == null) return '';
    final first = '${user['firstName'] ?? ''}'.trim();
    final last = '${user['lastName'] ?? ''}'.trim();
    final full = [first, last]
        .where((value) => value.isNotEmpty)
        .join(' ')
        .trim();
    if (full.isNotEmpty) return full;
    final fallbackName = '${user['name'] ?? ''}'.trim();
    return fallbackName;
  }

  Future<Position?> _getEmergencyPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _debugEmergencyPayload(
          'location service disabled, falling back to last known position',
        );
        return Geolocator.getLastKnownPosition();
      }

      var permission = await Geolocator.checkPermission();
      _debugEmergencyPayload('location permission status=$permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        _debugEmergencyPayload(
          'location permission after request=$permission',
        );
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _debugEmergencyPayload(
          'location permission denied, falling back to last known position',
        );
        return Geolocator.getLastKnownPosition();
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        _debugEmergencyPayload(
          'getCurrentPosition failed: $e, falling back to last known position',
        );
        return Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      _debugEmergencyPayload('_getEmergencyPosition failed: $e');
      return null;
    }
  }

  Future<String> _resolveApproximateAddress(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 8));
      if (placemarks.isEmpty) return '';

      final place = placemarks.first;
      final parts = <String>[];
      if ((place.street ?? '').trim().isNotEmpty) {
        parts.add(place.street!.trim());
      }
      if ((place.subLocality ?? '').trim().isNotEmpty) {
        parts.add(place.subLocality!.trim());
      }
      if ((place.locality ?? '').trim().isNotEmpty) {
        parts.add(place.locality!.trim());
      }
      if ((place.subAdministrativeArea ?? '').trim().isNotEmpty) {
        parts.add(place.subAdministrativeArea!.trim());
      }
      if ((place.administrativeArea ?? '').trim().isNotEmpty) {
        parts.add(place.administrativeArea!.trim());
      }
      if ((place.postalCode ?? '').trim().isNotEmpty) {
        parts.add(place.postalCode!.trim());
      }
      if ((place.country ?? '').trim().isNotEmpty) {
        parts.add(place.country!.trim());
      }

      return parts.join(', ');
    } catch (e) {
      _debugEmergencyPayload('_resolveApproximateAddress failed: $e');
      return '';
    }
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

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sourceLabel =
        _formatTriggerSource(widget.triggerSource, widget.autoStart);
    debugPrint(
      'SOSScreen: triggerSource=${widget.triggerSource} '
      'autoStart=${widget.autoStart} label=$sourceLabel',
    );

    return Scaffold(
      backgroundColor: _kBgDeep,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildGlassAppBar(sourceLabel),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      _buildCentralRing(),
                      const SizedBox(height: 32),
                      _buildStatusCard(),
                      const SizedBox(height: 28),
                      _buildActionArea(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient layer
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.2),
              radius: 1.3,
              colors: [
                Color(0xFF2B0808), // warm dark-red core
                Color(0xFF160404),
                Color(0xFF090202), // near-black edges
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // Big watermark logo — centred, see-through
        Center(
          child: Opacity(
            opacity: 0.04,
            child: Image.asset(
              'assets/usafe_logo.png',
              width: 340,
              height: 340,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  // ── Glass App Bar ─────────────────────────────────────────────────────────

  Widget _buildGlassAppBar(String sourceLabel) {
    final triggerStatus = _formatTriggerStatus(sourceLabel);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            color: _kGlassRed,
            border: Border(
              bottom: BorderSide(
                color: _kSosRed.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            children: [
              // Back button / lock indicator
              _buildAppBarEndWidget(isLeading: true),
              const Spacer(),

              // Centre title stack
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isSosSent ? 'SYSTEM LOCKED' : 'EMERGENCY MODE',
                    style: TextStyle(
                      color: _isSosSent ? _kSosRed : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    triggerStatus,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),

              const Spacer(),
              // Live-dot badge
              _buildAppBarEndWidget(isLeading: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarEndWidget({required bool isLeading}) {
    if (isLeading) {
      if (_isSosSent) return const SizedBox(width: 38);
      return GestureDetector(
        onTap: _handleBackAction,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _kGlassWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white70,
                size: 15,
              ),
            ),
          ),
        ),
      );
    }

    // Trailing: live red dot
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _kGlassRed,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGlassBdr, width: 0.8),
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _kSosRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kSosRed.withValues(alpha: 0.85),
                    blurRadius: 10,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Central pulsing ring ──────────────────────────────────────────────────

  Widget _buildCentralRing() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple ring 1
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, _) {
              final t = _rippleController.value;
              return Opacity(
                opacity: (1 - t) * 0.35,
                child: Container(
                  width: 280 + t * 100,
                  height: 280 + t * 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kSosRed,
                      width: 1.5,
                    ),
                  ),
                ),
              );
            },
          ),

          // Ripple ring 2 (staggered by 0.5)
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, _) {
              final t = (_rippleController.value + 0.5) % 1.0;
              return Opacity(
                opacity: (1 - t) * 0.35,
                child: Container(
                  width: 280 + t * 100,
                  height: 280 + t * 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kSosRed,
                      width: 1.5,
                    ),
                  ),
                ),
              );
            },
          ),

          // Outermost ambient glow
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kSosRed.withValues(alpha: 0.07),
                  blurRadius: 70,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),

          // Outer decorative ring
          Container(
            width: 264,
            height: 264,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _kSosRed.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
          ),

          // Mid decorative ring
          Container(
            width: 232,
            height: 232,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _kSosRed.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
          ),

          // Progress ring / activated glow ring
          if (!_isSosSent)
            SizedBox(
              width: 210,
              height: 210,
              child: AnimatedBuilder(
                animation: _timerController,
                builder: (context, _) => CircularProgressIndicator(
                  value: _timerController.value,
                  strokeWidth: 5,
                  backgroundColor: _kSosRed.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(_kSosRed),
                  strokeCap: StrokeCap.round,
                ),
              ),
            )
          else
            Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _kSosRed.withValues(alpha: 0.55),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kSosRed.withValues(alpha: 0.25),
                    blurRadius: 36,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),

          // Glass core circle
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                width: 184,
                height: 184,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSosSent
                      ? _kSosRed.withValues(alpha: 0.20)
                      : const Color(0xFF1E0606).withValues(alpha: 0.90),
                  border: Border.all(
                    color: _kSosRed.withValues(alpha: _isSosSent ? 0.60 : 0.40),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Label
                    Text(
                      _isSosSent ? 'ACTIVATED' : 'SOS',
                      style: TextStyle(
                        color: _isSosSent ? _kSosRed : Colors.white,
                        fontSize: _isSosSent ? 15 : 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),

                    // Countdown number
                    if (!_isSosSent)
                      AnimatedBuilder(
                        animation: _timerController,
                        builder: (context, _) {
                          final remaining = (_countdownSeconds *
                                  (1 - _timerController.value))
                              .ceil();
                          return Text(
                            '$remaining',
                            style: TextStyle(
                              color: _kSosRed.withValues(alpha: 0.95),
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status glass card ─────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: _kGlassRed,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _kGlassBdr, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _isSosSent ? 'EMERGENCY ACTIVATED' : 'SOS ACTIVATING',
                  style: TextStyle(
                    color: _isSosSent ? _kSosRed : Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),

                if (_isSosSent) ...[
                  Text(
                    'Triggered SOS at $_triggeredTime',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_isGuestMode) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: _kAmber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _kAmber.withValues(alpha: 0.40),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _guestContactsError ??
                                _guestContactsNotice ??
                                'Guest mode: using phone favorites (up to 5).',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _kAmber.withValues(alpha: 0.90),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ] else
                  AnimatedBuilder(
                    animation: _timerController,
                    builder: (context, _) {
                      final remaining = (_countdownSeconds *
                              (1 - _timerController.value))
                          .ceil();
                      return Text(
                        'Sending alert in $remaining seconds...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.50),
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Action area ───────────────────────────────────────────────────────────

  Widget _buildActionArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          if (!_isSosSent) ...[
            if (!widget.autoStart && !_timerController.isAnimating)
              SOSHoldButton(
                  onSOSTriggered: () => _timerController.forward())
            else
              Icon(Icons.sensors, color: _kSosRed.withValues(alpha: 0.85), size: 52),
            const SizedBox(height: 22),
            _buildGlassButton(
              label: 'CANCEL SOS',
              onTap: _handleBackAction,
              borderColor: Colors.white.withValues(alpha: 0.25),
              labelColor: Colors.white.withValues(alpha: 0.55),
              fillColor: Colors.white.withValues(alpha: 0.05),
            ),
          ] else
            _buildGlassButton(
              label: _isStartingProcess
                  ? 'STARTING EMERGENCY...'
                  : 'I AM SAFE — DISMISS',
              onTap: _isStartingProcess ? null : _navigateToSafeExit,
              borderColor: _kSosRed.withValues(alpha: 0.55),
              labelColor: Colors.white,
              fillColor: _kSosRed.withValues(alpha: 0.18),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required VoidCallback? onTap,
    required Color borderColor,
    required Color labelColor,
    required Color fillColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: labelColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
