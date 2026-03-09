import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../features/auth/auth_service.dart';
import '../../features/auth/screens/login_screen.dart';
import 'contacts_screen.dart';
import 'emergency_process_screen.dart';
import 'package:usafe_front_end/src/pages/profile_screen.dart'; // Adjust path
import 'safety_score_screen.dart';
import 'safepath_scheduler_screen.dart';
import 'settings_screen.dart'; // ← SettingsPage lives here

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final Set<int> _loadedTabs = {0};
  final GlobalKey<ContactsScreenState> _contactsKey =
      GlobalKey<ContactsScreenState>();

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const SOSDashboard(),
      SafetyScoreScreen(
        showBottomNav: false,
        onBackHome: () => _switchTab(0),
      ),
      ContactsScreen(
        key: _contactsKey,
        onBackHome: () => _switchTab(0),
      ),
      ProfileScreen(
        onBackHome: () => _switchTab(0),
        onOpenContacts: () => _switchTab(2),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: List.generate(
              pages.length,
              (index) => _loadedTabs.contains(index)
                  ? pages[index]
                  : const SizedBox.shrink(),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: _buildBottomNavBar(),
          ),
          if (_currentIndex == 2)
            Positioned(
              left: 0,
              right: 0,
              bottom: 32 + 76 + 16,
              child: Center(
                child: FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  onPressed: () => _contactsKey.currentState?.openAddContact(),
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text('Add Contact',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(Icons.shield_rounded, 'SOS', 0),
          _navItem(Icons.map_rounded, 'Score', 1),
          _navItem(Icons.people_alt_rounded, 'Contacts', 2),
          _navItem(Icons.person_rounded, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SOS DASHBOARD  (settings button → SettingsPage)
// ─────────────────────────────────────────────
class SOSDashboard extends StatefulWidget {
  const SOSDashboard({super.key});

  @override
  State<SOSDashboard> createState() => _SOSDashboardState();
}

class _SOSDashboardState extends State<SOSDashboard>
    with TickerProviderStateMixin {
  bool isSOSActive = false;
  bool _openingEmergencyProcess = false;
  String? _emergencySessionId;
  Timer? _statusPollTimer;
  bool _sessionAnswered = false;
  Map<String, dynamic>? _latestSessionStatus;

  static const Duration _sosDuration = Duration(minutes: 3);
  static const Duration _statusPollInterval = Duration(seconds: 3);
  Timer? _sosTimer;
  Duration _remaining = _sosDuration;

  @override
  void dispose() {
    _sosTimer?.cancel();
    _statusPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: AppColors.background,
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // ── SOS Button: True center of screen ──
            Center(
              child: isSOSActive ? _buildSOSActiveView() : _buildHoldButton(),
            ),
            // ── Top Bar: SAFE pill + Settings gear ──
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildStatusPill(),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: AppColors.textSecondary, size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.success, // High contrast safe green
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'SAFE',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lightbulb_outline,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                'Safety Tip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Share your live location with trusted contacts before walking alone at night. Stay on well-lit paths.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSHeader() {
    return Column(
      children: [
        const Text(
          'EMERGENCY\nACTIVATED',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.alert,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.alertBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Dispatching alerts...',
            style: TextStyle(
                color: AppColors.alert,
                fontSize: 16,
                fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildHoldButton() {
    return SOSHoldInteraction(
      accentColor: AppColors.alert,
      onComplete: () {
        setState(() => isSOSActive = true);
        _startSosCountdown();
      },
    );
  }

  Widget _buildSOSActiveView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 300,
              height: 300,
              child: CircularProgressIndicator(
                value: _remaining.inSeconds / _sosDuration.inSeconds,
                strokeWidth: 16,
                backgroundColor: AppColors.surfaceElevated,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.alert),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(_remaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
                const Text(
                  'Auto-dispatch in',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 56),
        _buildActionButton(
          label: 'SEND HELP NOW',
          bg: AppColors.alert,
          text: Colors.white,
          icon: Icons.flash_on_rounded,
          onTap: _openEmergencyProcess,
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          label: 'CANCEL SOS',
          bg: AppColors.surfaceElevated,
          text: Colors.white,
          icon: Icons.close_rounded,
          onTap: () {
            _resetSosCountdown();
            setState(() => isSOSActive = false);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color bg,
    required Color text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // Massive touch targets for high stress
    return SizedBox(
      width: double.infinity,
      height: 68,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: text,
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startSosCountdown() {
    _sosTimer?.cancel();
    _remaining = _sosDuration;
    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (_remaining.inSeconds <= 1) {
        timer.cancel();
        setState(() => _remaining = Duration.zero);
        await _openEmergencyProcess();
        return;
      }
      setState(() => _remaining = Duration(seconds: _remaining.inSeconds - 1));
    });
  }

  void _resetSosCountdown() {
    _sosTimer?.cancel();
    _remaining = _sosDuration;
  }

  Future<void> _openEmergencyProcess() async {
    if (_openingEmergencyProcess) return;
    _openingEmergencyProcess = true;
    _sosTimer?.cancel();
    _emergencySessionId = null;
    _sessionAnswered = false;
    _latestSessionStatus = null;
    _statusPollTimer?.cancel();

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
    _sessionAnswered = false;
    _latestSessionStatus = null;
    _openingEmergencyProcess = false;
    if (!mounted) return;
    _resetSosCountdown();
    setState(() => isSOSActive = false);
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
      final response =
          await AuthService.getEmergencyStatus(sessionId: sessionId);
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
    return EmergencyActionResult(success: true, message: assessment.message);
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
    final latestStatus =
        (_latestSessionStatus?['status'] ?? '').toString().toUpperCase();
    final answered = response['answered'] == true ||
        finalStatus == 'ANSWERED' ||
        latestStatus == 'ANSWERED' ||
        (response['answeredBy'] != null &&
            response['answeredBy'].toString().isNotEmpty);
    if (answered) _sessionAnswered = true;

    final explicitFail =
        response['success'] == false || response['ok'] == false;
    final providerFailed = finalStatus == 'FAILED' ||
        finalStatus == 'NO_ANSWER' ||
        finalStatus == 'BUSY';
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

    final explicitFail =
        response['success'] == false || response['ok'] == false;
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
      message:
          response['message']?.toString() ?? 'Emergency process cancelled.',
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

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────
//  SOS HOLD INTERACTION  (unchanged)
// ─────────────────────────────────────────────
class SOSHoldInteraction extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onComplete;

  const SOSHoldInteraction({
    required this.accentColor,
    required this.onComplete,
    super.key,
  });

  @override
  State<SOSHoldInteraction> createState() => _SOSHoldInteractionState();
}

class _SOSHoldInteractionState extends State<SOSHoldInteraction>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Visibility of System Status: Shows a ring filling up during hold.
    // Fitts's Law: Massive single touch element.
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer subtle pulse ring
          Container(
            width: 290,
            height: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.accentColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 20,
                )
              ],
            ),
          ),

          // Outer progress ring path (background line)
          SizedBox(
            width: 290,
            height: 290,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.surfaceElevated.withOpacity(0.3)),
            ),
          ),

          // Actual animated progress indicator that fills up
          SizedBox(
            width: 290,
            height: 290,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CircularProgressIndicator(
                  value: _controller.value,
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),

          // Core Massive Button (Visual Hierarchy King)
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor, // Vibrant Red
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app,
                    color: Colors.white, size: 56), // Signifier
                const SizedBox(height: 12),
                const Text(
                  'HOLD TO\nSOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white, // High Contrast
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
