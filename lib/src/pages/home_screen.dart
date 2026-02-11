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

  @override
  Widget build(BuildContext context) {
    final pages = [
      const SOSDashboard(),
      const SafetyScoreScreen(safetyScore: 85, showBottomNav: false),
      ContactsScreen(key: _contactsKey),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: pages),

            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: _buildBottomNavBar(),
            ),

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

/* ====================================================================== */
/* ============================ SOS DASHBOARD =========================== */
/* ====================================================================== */

class SOSDashboard extends StatefulWidget {
  const SOSDashboard({super.key});

  @override
  State<SOSDashboard> createState() => _SOSDashboardState();
}

class _SOSDashboardState extends State<SOSDashboard>
    with TickerProviderStateMixin {
  bool isSOSActive = false;

  // Floating banner payload shown after emergency flow returns
  HomeEmergencyBannerPayload? _banner;
  Timer? _bannerTimer;

  void _showHomeBanner(HomeEmergencyBannerPayload payload) {
    _bannerTimer?.cancel();
    setState(() => _banner = payload);

    _bannerTimer = Timer(const Duration(minutes: 2), () {
      if (!mounted) return;
      setState(() => _banner = null);
    });
  }

  // 3-minute countdown before auto alert.
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
    _bannerTimer?.cancel();
    super.dispose();
  }

  bool get _recentEmergencyActive => _banner != null;

  Future<void> _openEmergencyProcess() async {
    _sosTimer?.cancel();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmergencyProcessScreen()),
    );

    if (!mounted) return;

    // ALWAYS reset SOS UI when returning
    _resetSosCountdown();
    setState(() => isSOSActive = false);

    if (result is HomeEmergencyBannerPayload) {
      _showHomeBanner(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ripple behavior:
    // - calm mode normally
    // - intense red mode when SOS countdown is active OR emergency happened recently
    final rippleMode =
        (isSOSActive || _recentEmergencyActive) ? RippleMode.intense : RippleMode.calm;

    return Container(
      color: bgDark,
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 20),
              if (!isSOSActive) _buildStatusPill(),
              if (isSOSActive) _buildSOSHeader(),
              const Spacer(),
              Center(
                child: isSOSActive
                    ? _buildSOSActiveView()
                    : _buildHoldButton(rippleMode),
              ),
              const Spacer(),
              const SizedBox(height: 100),
            ],
          ),

          // ✅ Floating banner (auto hides after 2 min)
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
                  border: Border.all(color: AppColors.primarySky.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white),
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
                            style:
                                TextStyle(color: Colors.grey[300], fontSize: 12),
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

  Widget _buildHoldButton(RippleMode mode) {
    return SOSHoldInteraction(
      accentColor: accentBlue,
      mode: mode, // ✅ calm or intense ripple
      onComplete: () {
        setState(() {
          isSOSActive = true;
        });
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
          'An alert will be sent to your emergency contacts.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 40),
        _buildActionButton('CANCEL SOS', tealBtn, Colors.black, () {
          _resetSosCountdown();
          setState(() {
            isSOSActive = false;
          });
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

/* ====================================================================== */
/* ===================== SOS HOLD + RIPPLE ANIMATION ==================== */
/* ====================================================================== */

enum RippleMode { calm, intense }

class SOSHoldInteraction extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onComplete;
  final RippleMode mode;

  const SOSHoldInteraction({
    required this.accentColor,
    required this.onComplete,
    required this.mode,
    super.key,
  });

  @override
  State<SOSHoldInteraction> createState() => _SOSHoldInteractionState();
}

class _SOSHoldInteractionState extends State<SOSHoldInteraction>
    with TickerProviderStateMixin {
  late AnimationController _holdController;
  late AnimationController _rippleController;

  Duration get _rippleDuration =>
      widget.mode == RippleMode.intense
          ? const Duration(milliseconds: 2000)   // faster
          : const Duration(milliseconds: 2200); // slower

  @override
  void initState() {
    super.initState();

    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
        _holdController.reset();
      }
    });

    _rippleController = AnimationController(
      vsync: this,
      duration: _rippleDuration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant SOSHoldInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.mode != widget.mode) {
      _rippleController
        ..stop()
        ..duration = _rippleDuration
        ..repeat();
    }
  }

  @override
  void dispose() {
    _holdController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool intense = widget.mode == RippleMode.intense;
    final Color rippleColor = intense ? const Color(0xFFFF3D00) : widget.accentColor;

    // More rings + bigger scale in intense mode
    final int rings = intense ? 3 : 2;
    final double maxScale = intense ? 1.45 : 1.35;
    final double baseOpacity = intense ? 0.22 : 0.16;

    return GestureDetector(
      onTapDown: (_) => _holdController.forward(),
      onTapUp: (_) => _holdController.reverse(),
      onTapCancel: () => _holdController.reverse(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Water ripple rings behind everything
          for (int i = 0; i < rings; i++)
            _RippleRing(
              controller: _rippleController,
              color: rippleColor,
              baseSize: 240,
              phase: i / rings, // evenly stagger rings
              maxScale: maxScale,
              baseOpacity: baseOpacity,
              intense: intense,
            ),

          // Outer static ring
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: rippleColor.withOpacity(intense ? 0.18 : 0.10),
                width: 15,
              ),
            ),
          ),

          // Hold progress ring
          SizedBox(
            width: 240,
            height: 240,
            child: AnimatedBuilder(
              animation: _holdController,
              builder: (context, child) {
                return CircularProgressIndicator(
                  value: _holdController.value,
                  strokeWidth: 15,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    intense ? const Color(0xFFFF3D00) : widget.accentColor,
                  ),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),

          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_outlined,
                color: Colors.white,
                size: intense ? 34 : 32,
              ),
              const SizedBox(height: 10),
              Text(
                'Hold to Activate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: intense ? 0.4 : 0.0,
                ),
              ),
              Text(
                'SOS',
                style: TextStyle(
                  color: rippleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (intense) ...[
                const SizedBox(height: 6),
                Text(
                  "RECENT EMERGENCY",
                  style: TextStyle(
                    color: rippleColor.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RippleRing extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double baseSize;
  final double phase; // 0..1
  final double maxScale;
  final double baseOpacity;
  final bool intense;

  const _RippleRing({
    required this.controller,
    required this.color,
    required this.baseSize,
    required this.phase,
    required this.maxScale,
    required this.baseOpacity,
    required this.intense,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        double t = (controller.value + phase) % 1.0;

        // smooth curve
        final curved = Curves.easeOut.transform(t);

        // scale: 1.0 -> maxScale
        final scale = 1.0 + ((maxScale - 1.0) * curved);

        // opacity fades out as it expands
        final opacity = (1.0 - curved).clamp(0.0, 1.0);

        // thickness: stronger for intense
        final strokeBase = intense ? 7.0 : 5.5;
        final stroke = strokeBase - (intense ? 4.0 : 3.0) * curved;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: baseSize,
            height: baseSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(baseOpacity * opacity),
                width: stroke.clamp(2.0, strokeBase),
              ),
            ),
          ),
        );
      },
    );
  }
}
