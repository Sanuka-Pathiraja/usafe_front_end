import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/src/pages/home_screen.dart';

class AppGuideScreen extends StatefulWidget {
  const AppGuideScreen({super.key});

  @override
  State<AppGuideScreen> createState() => _AppGuideScreenState();
}

class _AppGuideScreenState extends State<AppGuideScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroCtrl;
  late final AnimationController _cardsCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _buttonCtrl;

  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _buttonFade;
  late final Animation<double> _pulse;

  static const _guides = [
    _GuideItem(
      icon: Icons.shield_rounded,
      color: Color(0xFFEF4444),
      title: 'SOS Emergency',
      body: 'Hold the SOS button for 3 seconds to instantly alert all your trusted contacts.',
    ),
    _GuideItem(
      icon: Icons.people_rounded,
      color: Color(0xFF3B82F6),
      title: 'Trusted Contacts',
      body: 'Add at least 3 contacts. They\'ll receive your location and emergency alerts.',
    ),
    _GuideItem(
      icon: Icons.volume_off_rounded,
      color: Color(0xFF8B5CF6),
      title: 'Silent Call',
      body: 'Discreetly send a pre-set distress message to all contacts without making a sound.',
    ),
    _GuideItem(
      icon: Icons.route_rounded,
      color: Color(0xFF10B981),
      title: 'Safe Routes',
      body: 'Navigate using safety-aware routes and share your live location with contacts.',
    ),
  ];

  final List<AnimationController> _cardCtrls = [];
  final List<Animation<double>> _cardFades = [];
  final List<Animation<Offset>> _cardSlides = [];

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _cardsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _buttonCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _heroFade =
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
            begin: const Offset(0, -0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));

    _pulse = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _buttonFade =
        CurvedAnimation(parent: _buttonCtrl, curve: Curves.easeOut);

    // Per-card staggered controllers
    for (int i = 0; i < _guides.length; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
      final fade = CurvedAnimation(parent: ctrl, curve: Curves.easeOut);
      final slide = Tween<Offset>(
              begin: const Offset(0.12, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _cardCtrls.add(ctrl);
      _cardFades.add(fade);
      _cardSlides.add(slide);
    }

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _heroCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    for (int i = 0; i < _cardCtrls.length; i++) {
      _cardCtrls[i].forward();
      await Future.delayed(const Duration(milliseconds: 130));
    }
    await Future.delayed(const Duration(milliseconds: 200));
    _buttonCtrl.forward();
  }

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_guide_seen', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _cardsCtrl.dispose();
    _pulseCtrl.dispose();
    _buttonCtrl.dispose();
    for (final c in _cardCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF0D1B2E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                // ── Hero ──────────────────────────────────────
                SlideTransition(
                  position: _heroSlide,
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: Column(
                      children: [
                        _AnimatedLogo(pulseAnim: _pulse),
                        const SizedBox(height: 20),
                        const Text(
                          'You\'re all set!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Here\'s a quick look at what USafe can do.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // ── Cards ─────────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _guides.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => SlideTransition(
                      position: _cardSlides[i],
                      child: FadeTransition(
                        opacity: _cardFades[i],
                        child: _GuideCard(item: _guides[i]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // ── Button ────────────────────────────────────
                FadeTransition(
                  opacity: _buttonFade,
                  child: _GlowButton(onTap: _continue),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Guide item data ────────────────────────────────────────────────────────────

class _GuideItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _GuideItem(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body});
}

// ── Animated logo ──────────────────────────────────────────────────────────────

class _AnimatedLogo extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _AnimatedLogo({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: pulseAnim,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)],
          ),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.shield_rounded,
            color: AppColors.primary, size: 38),
      ),
    );
  }
}

// ── Guide card ────────────────────────────────────────────────────────────────

class _GuideCard extends StatelessWidget {
  final _GuideItem item;
  const _GuideCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.color.withValues(alpha: 0.18), width: 1),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon bubble
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: item.color.withValues(alpha: 0.25), width: 1),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
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

// ── Glow button ───────────────────────────────────────────────────────────────

class _GlowButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GlowButton({required this.onTap});

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 2.0).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (_, __) {
          return Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Shimmer sweep
                  Positioned.fill(
                    child: Transform(
                      transform: Matrix4.translationValues(
                          _shimmer.value * 300, 0, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                            transform: const GradientRotation(math.pi / 6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Get Started',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
