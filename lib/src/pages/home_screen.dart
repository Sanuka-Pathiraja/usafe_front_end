import 'dart:async';
import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'safety_score_screen.dart';
import 'emergency_process_screen.dart';
import 'emergency_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final Color bgDark = AppColors.background;
  final Color accentBlue = AppColors.primarySky;

  final GlobalKey<ContactsScreenState> _contactsKey =
      GlobalKey<ContactsScreenState>();

  // ✅ Banner state lives in HomeScreen so it shows on ANY tab
  HomeEmergencyBannerPayload? _banner;
  Timer? _bannerTimer;

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _showBanner(HomeEmergencyBannerPayload payload) {
    _bannerTimer?.cancel();
    setState(() => _banner = payload);

    _bannerTimer = Timer(const Duration(minutes: 2), () {
      if (!mounted) return;
      setState(() => _banner = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      SOSDashboard(onBanner: _showBanner),
      const SafetyScoreScreen(safetyScore: 85, showBottomNav: false),
      ContactsScreen(key: _contactsKey),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: pages,
            ),

            // ✅ Floating banner overlay (auto hides after 2 minutes)
            if (_banner != null)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15171B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primarySky.withOpacity(0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active,
                          color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _banner!.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _banner!.subtitle,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _bannerTimer?.cancel();
                          setState(() => _banner = null);
                        },
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),

            // Custom bottom navigation overlay.
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: _buildBottomNavBar(),
            ),

            // Show add-contact FAB only on Contacts tab.
            if (_currentIndex == 2)
              Positioned(
                left: 0,
                right: 0,
                bottom: 30 + 70 + 8,
                child: Center(
                  child: FloatingActionButton(
                    backgroundColor: AppColors.primarySky,
                    onPressed: () =>
                        _contactsKey.currentState?.addContactFromPhone(),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF15171B),
        borderRadius: BorderRadius.circular(35),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(Icons.home_filled, 0),
          _navItem(Icons.map, 1),
          _navItem(Icons.people, 2),
          _navItem(Icons.person, 3),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {
    final bool isActive = _currentIndex == index;
    return IconButton(
      onPressed: () => setState(() => _currentIndex = index),
      icon: Icon(
        icon,
        color: isActive ? accentBlue : Colors.grey[700],
        size: 28,
      ),
    );
  }
}

class SOSDashboard extends StatefulWidget {
  final void Function(HomeEmergencyBannerPayload payload) onBanner;

  const SOSDashboard({
    super.key,
    required this.onBanner,
  });

  @override
  State<SOSDashboard> createState() => _SOSDashboardState();
}

class _SOSDashboardState extends State<SOSDashboard>
    with TickerProviderStateMixin {
  bool isSOSActive = false;

  // 3-minute countdown before auto alert
  static const Duration _sosDuration = Duration(minutes: 3);
  Timer? _sosTimer;
  Duration _remaining = _sosDuration;

  final Color bgDark = AppColors.background;
  final Color accentBlue = AppColors.primarySky;
  final Color accentRed = const Color(0xFFFF3D00);
  final Color tealBtn = const Color(0xFF1DE9B6);

  @override
  void dispose() {
    _sosTimer?.cancel();
    super.dispose();
  }

  Future<void> _openEmergencyProcess() async {
    _sosTimer?.cancel();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmergencyProcessScreen()),
    );

    if (!mounted) return;

    // ✅ Always reset SOS UI when returning
    _resetSosCountdown();
    setState(() => isSOSActive = false);

    // If result screen returned a banner payload, show it in HomeScreen
    if (result is HomeEmergencyBannerPayload) {
      widget.onBanner(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgDark,
      child: Column(
        children: [
          const SizedBox(height: 20),
          if (!isSOSActive) _buildStatusPill(),
          if (isSOSActive) _buildSOSHeader(),
          const Spacer(),
          Center(
            child: isSOSActive ? _buildSOSActiveView() : _buildHoldButton(),
          ),
          const Spacer(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2228),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.tealAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Your Area: Safe',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSHeader() {
    return const Text(
      'SOS ACTIVATED',
      style: TextStyle(
        color: Color(0xFFFF3D00),
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildHoldButton() {
    return SOSHoldInteraction(
      accentColor: accentBlue,
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
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: _remaining.inSeconds / _sosDuration.inSeconds,
                strokeWidth: 15,
                backgroundColor: accentRed.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(accentRed),
              ),
            ),
            Text(
              _formatDuration(_remaining),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Text(
          'After the countdown, the emergency process will start.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 40),
        _buildActionButton('CANCEL SOS', tealBtn, Colors.black, () {
          _resetSosCountdown();
          setState(() => isSOSActive = false);
        }),
        const SizedBox(height: 15),
        _buildActionButton('SEND HELP NOW', accentRed, Colors.white, () async {
          await _openEmergencyProcess();
        }),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    Color bg,
    Color text,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: 280,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
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

      setState(() {
        _remaining = Duration(seconds: _remaining.inSeconds - 1);
      });
    });
  }

  void _resetSosCountdown() {
    _sosTimer?.cancel();
    _remaining = _sosDuration;
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
      duration: const Duration(seconds: 1),
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
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.accentColor.withOpacity(0.1),
                width: 15,
              ),
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
                  strokeWidth: 15,
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
              const Icon(Icons.touch_app_outlined,
                  color: Colors.white, size: 32),
              const SizedBox(height: 10),
              const Text(
                'Hold to Activate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'SOS',
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
