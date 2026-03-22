import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/onboarding/screens/welcome_screen.dart';

class PermissionsOnboardingScreen extends StatefulWidget {
  const PermissionsOnboardingScreen({super.key});

  @override
  State<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState
    extends State<PermissionsOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isRequesting = false;

  static const _permissions = [
    _PermissionItem(
      icon: Icons.mic_rounded,
      color: Color(0xFF8B5CF6),
      title: 'Microphone Access',
      subtitle: 'FOR SOS SOUND DETECTION',
      description:
          'USafe uses your microphone to listen for distress sounds and automatically trigger emergency alerts when you need help most — even when you cannot tap your screen.',
      permission: Permission.microphone,
    ),
    _PermissionItem(
      icon: Icons.location_on_rounded,
      color: Color(0xFF10B981),
      title: 'Location Access',
      subtitle: 'FOR SAFETY NAVIGATION',
      description:
          'Real-time location helps USafe guide you along safe routes, share your position with emergency contacts, and coordinate help during an active safety incident.',
      permission: Permission.locationWhenInUse,
    ),
    _PermissionItem(
      icon: Icons.contacts_rounded,
      color: Color(0xFF3B82F6),
      title: 'Contact Access',
      subtitle: 'FOR EMERGENCY CONTACTS',
      description:
          'USafe needs access to your phonebook so you can quickly select trusted people as emergency contacts. Only contacts you choose are ever saved — your full contact list stays private.',
      permission: Permission.contacts,
    ),
    _PermissionItem(
      icon: Icons.notifications_rounded,
      color: Color(0xFFF59E0B),
      title: 'Notifications',
      subtitle: 'FOR SAFETY ALERTS',
      description:
          'Stay informed with real-time safety alerts, active SOS event notifications, and community-reported incidents in your area through timely push notifications.',
      permission: Permission.notification,
    ),
  ];

  Future<void> _requestCurrentAndAdvance() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);
    await _permissions[_currentPage].permission.request();
    setState(() => _isRequesting = false);
    _advance();
  }

  void _advance() {
    if (_currentPage < _permissions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _goToWelcome();
    }
  }

  void _goToWelcome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const WelcomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _permissions[_currentPage];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.backgroundBlack],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Row(
                  children: List.generate(
                    _permissions.length,
                    (i) => Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _currentPage
                              ? item.color
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _permissions.length,
                  itemBuilder: (_, index) =>
                      _PermissionPage(item: _permissions[index]),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            _isRequesting ? null : _requestCurrentAndAdvance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: item.color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isRequesting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _currentPage == _permissions.length - 1
                                    ? 'All Done — Continue'
                                    : 'Allow & Continue',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isRequesting ? null : _advance,
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Permission page widget ────────────────────────────────────────────────────

class _PermissionPage extends StatefulWidget {
  final _PermissionItem item;
  const _PermissionPage({required this.item});

  @override
  State<_PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<_PermissionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.color.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.28),
                      blurRadius: 50,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(item.icon, size: 58, color: item.color),
              ),
              const SizedBox(height: 36),
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                item.subtitle,
                style: TextStyle(
                  color: item.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item.color.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  item.description,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 15,
                    height: 1.65,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _PermissionItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;
  final Permission permission;

  const _PermissionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.permission,
  });
}
