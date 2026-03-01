import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_colors.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'safety_score_screen.dart';
import 'safepath_scheduler_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ContactsScreenState> _contactsKey =
      GlobalKey<ContactsScreenState>();

  @override
  Widget build(BuildContext context) {
    // Main tab pages rendered via the bottom navigation.
    final pages = [
      const SOSDashboard(),
      const SafetyScoreScreen(showBottomNav: false),
      const SafePathSchedulerScreen(),
      ContactsScreen(key: _contactsKey),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          // Custom modern floating bottom navigation overlay.
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: _buildBottomNavBar(),
          ),
          // Show the add-contact FAB only on the Contacts tab.
          if (_currentIndex == 3) // Adjusted index for Contacts
            Positioned(
              left: 0,
              right: 0,
              bottom: 32 + 76 + 16, // Above nav bar with spacing
              child: Center(
                child: FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () => _contactsKey.currentState?.openAddContact(),
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text('Add Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      onTap: () => setState(() => _currentIndex = index),
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
                color: isActive ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
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

class SOSDashboard extends StatefulWidget {
  const SOSDashboard({super.key});

  @override
  State<SOSDashboard> createState() => _SOSDashboardState();
}

class _SOSDashboardState extends State<SOSDashboard>
    with TickerProviderStateMixin {
  bool isSOSActive = false;

  // 3-minute countdown before auto alert.
  static const Duration _sosDuration = Duration(minutes: 3);
  Timer? _sosTimer;
  Duration _remaining = _sosDuration;

  @override
  void dispose() {
    _sosTimer?.cancel();
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
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusPill(),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                  onPressed: () {},
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
            const SizedBox(height: 120), // Compensate for floating nav bar
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
            style: TextStyle(color: AppColors.alert, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildHoldButton() {
    return SOSHoldInteraction(
      accentColor: AppColors.alert,
      onComplete: () {
        setState(() {
          isSOSActive = true;
        });
        // Start the visible countdown once SOS is activated.
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
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.alert),
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
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
          onTap: () {
            _triggerSOS();
          },
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          label: 'CANCEL SOS',
          bg: AppColors.surfaceElevated,
          text: AppColors.textPrimary,
          icon: Icons.close_rounded,
          onTap: () {
            _resetSosCountdown();
            setState(() {
              isSOSActive = false;
            });
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
      height: 64, // Massive touch target
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: text,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining.inSeconds <= 1) {
        timer.cancel();
        _triggerSOS();
        setState(() {
          _remaining = Duration.zero;
        });
        return;
      }
      setState(() {
        _remaining = Duration(seconds: _remaining.inSeconds - 1);
      });
    });
  }

  void _resetSosCountdown() {
    _sosTimer?.cancel();
    _remaining = _sosDuration;
  }

  Future<void> _triggerSOS() async {
    try {
      final jwt = Supabase.instance.client.auth.currentSession?.accessToken ?? "mock-testing-token";
      await ApiService.sendDistressSignal("Manual SOS", 1.0, jwt);
      debugPrint("✅ SOS signal sent successfully");
    } catch (e) {
      debugPrint("❌ Failed to send SOS signal: $e");
    }
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

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
          // Massive container base for Fitts's Law
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor.withOpacity(0.05),
            ),
          ),
          // Inner static ring
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
          // Animated progress ring
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
          // Center Icon & Text
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
