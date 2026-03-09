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
      SafePathSchedulerScreen(
        onBack: () => _switchTab(0),
      ),
      ContactsScreen(
        key: _contactsKey,
        onBackHome: () => _switchTab(0),
      ),
      ProfileScreen(
        onBackHome: () => _switchTab(0),
        onOpenContacts: () => _switchTab(3),
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
          if (_currentIndex == 3)
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
          _navItem(Icons.route_rounded, 'SafePath', 2),
          _navItem(Icons.people_alt_rounded, 'Contacts', 3),
          _navItem(Icons.person_rounded, 'Profile', 4),
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
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusPill(),
                // ── Settings button ──────────────────────────────────────
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: AppColors.textSecondary),
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
            const SizedBox(height: 32),
            if (isSOSActive) _buildSOSHeader(),
            if (!isSOSActive)
              const Text(
                'Hold button in emergency',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
            const Spacer(),
            Center(
              child: isSOSActive ? _buildSOSActiveView() : _buildHoldButton(),
            ),
            const Spacer(),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Your Area: Safe',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
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
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.alertBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Dispatching alerts...',
            style:
                TextStyle(color: AppColors.alert, fontWeight: FontWeight.bold),
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
              width: 260,
              height: 260,
              child: CircularProgressIndicator(
                value: _remaining.inSeconds / _sosDuration.inSeconds,
                strokeWidth: 12,
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
                    color: AppColors.textPrimary,
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                ),
                const Text(
                  'Auto-dispatch in',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 48),
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
          text: AppColors.textPrimary,
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
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: text,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 1.0,
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor.withOpacity(0.05),
            ),
          ),
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.accentColor.withOpacity(0.15),
                width: 2,
              ),
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.1),
                  blurRadius: 40,
                  spreadRadius: 10,
                )
              ],
            ),
          ),
          SizedBox(
            width: 240,
            height: 240,
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.fingerprint_rounded,
                    color: widget.accentColor, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'SOS',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Press & Hold',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

