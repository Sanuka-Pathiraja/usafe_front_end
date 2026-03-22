import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/onboarding/onboarding_controller.dart';
import 'package:usafe_front_end/src/pages/home_screen.dart';

class EmergencyContactsSetupScreen extends StatefulWidget {
  const EmergencyContactsSetupScreen({super.key});

  @override
  State<EmergencyContactsSetupScreen> createState() =>
      _EmergencyContactsSetupScreenState();
}

class _EmergencyContactsSetupScreenState
    extends State<EmergencyContactsSetupScreen>
    with SingleTickerProviderStateMixin {
  static const int _minContacts = 3;
  static const int _maxContacts = 5;

  final List<Map<String, String>> _contacts = [];
  bool _loading = true;
  bool _addingContact = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadContacts();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final remote = await AuthService.fetchContacts();
      if (mounted) {
        setState(() {
          _contacts
            ..clear()
            ..addAll(remote.map((e) => <String, String>{
                  'contactId': (e['contactId'] ?? '').toString(),
                  'name': (e['name'] ?? '').toString(),
                  'relationship': (e['relationship'] ?? 'Contact').toString(),
                  'phone': (e['phone'] ?? '').toString(),
                }));
          _loading = false;
        });
      }
    } catch (_) {
      try {
        final cached = await AuthService.loadTrustedContacts();
        if (mounted) {
          setState(() {
            _contacts
              ..clear()
              ..addAll(cached.map((e) => <String, String>{
                    'contactId': (e['contactId'] ?? '').toString(),
                    'name': (e['name'] ?? '').toString(),
                    'relationship':
                        (e['relationship'] ?? 'Contact').toString(),
                    'phone': (e['phone'] ?? '').toString(),
                  }));
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  String _statusMessage() {
    final n = _contacts.length;
    if (n == 0) return 'Add at least 3 emergency contacts to continue';
    if (n == 1) return 'Great start — add 2 more contacts to continue';
    if (n == 2) return 'Almost there — add 1 more contact to continue';
    return 'You\'re all set to go!';
  }

  Color _statusColor() =>
      _contacts.length >= _minContacts ? AppColors.success : AppColors.primary;

  // ── Add contact flow ──────────────────────────────────────────────────────

  Future<void> _addContact() async {
    if (_contacts.length >= _maxContacts) {
      _showSnack('You can add up to $_maxContacts contacts only.');
      return;
    }
    if (_addingContact) return;
    setState(() => _addingContact = true);

    try {
      // Check current permission status first so we can give a better message.
      final status = await Permission.contacts.status;

      if (status.isPermanentlyDenied) {
        setState(() => _addingContact = false);
        _showPermissionDeniedDialog(permanent: true);
        return;
      }

      final bool granted =
          await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        setState(() => _addingContact = false);
        _showPermissionDeniedDialog(permanent: false);
        return;
      }

      final Contact? picked = await FlutterContacts.openExternalPick();
      if (picked == null) return;

      final Contact? full =
          await FlutterContacts.getContact(picked.id, withProperties: true);
      if (full == null || full.phones.isEmpty) {
        _showSnack('This contact does not have a phone number.');
        return;
      }

      final String? phone = await _pickPhoneNumber(full.phones);
      if (phone == null) return;

      final String? relation = await _promptRelation();
      if (relation == null) return;

      final name =
          full.displayName.trim().isNotEmpty ? full.displayName : 'Unknown';

      final created = await AuthService.createContact(
        name: name,
        phone: phone,
        relationship: relation,
      );

      setState(() {
        _contacts.add({
          'contactId': (created['contactId'] ?? '').toString(),
          'name': (created['name'] ?? name).toString(),
          'relationship': (created['relationship'] ?? relation).toString(),
          'phone': (created['phone'] ?? phone).toString(),
        });
      });
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _addingContact = false);
    }
  }

  Future<String?> _pickPhoneNumber(List<Phone> phones) async {
    if (phones.length == 1) return phones.first.number;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: phones.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: AppColors.glassBorder),
          itemBuilder: (ctx, i) => ListTile(
            title: Text(phones[i].number,
                style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, phones[i].number),
          ),
        ),
      ),
    );
  }

  Future<String?> _promptRelation() async {
    String input = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Relationship',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          onChanged: (v) => input = v,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Mother, Partner, Friend',
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
                ctx, input.trim().isEmpty ? 'Contact' : input.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.alertRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showPermissionDeniedDialog({required bool permanent}) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Contacts Permission Needed',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          permanent
              ? 'Contact access was permanently denied. Please open Settings and enable it under Permissions to add emergency contacts.'
              : 'USafe needs access to your contacts to let you pick emergency contacts. Please allow access when prompted.',
          style: const TextStyle(color: AppColors.textGrey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          if (permanent)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Open Settings',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  void _skipForNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    await prefs.setBool('authorization_seen', true);
    // Mark both old contact tours as seen — EmergencyContactsSetupScreen replaces them
    await OnboardingController.markContactsPageTourSeen();
    await OnboardingController.markContactsTourSeen();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            const HomeScreen(initialTabIndex: 2),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (_) => false,
    );
  }

  // ── Continue to app ───────────────────────────────────────────────────────

  Future<void> _continueToApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    await prefs.setBool('authorization_seen', true); // backward compat
    // Mark both old contact tours as seen — EmergencyContactsSetupScreen replaces them
    await OnboardingController.markContactsPageTourSeen();
    await OnboardingController.markContactsTourSeen();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (_) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canContinue = _contacts.length >= _minContacts;
    final statusColor = _statusColor();

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
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Column(
                    children: [
                      // Icon
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor.withValues(alpha: 0.12),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.22),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Icon(
                            canContinue
                                ? Icons.check_circle_rounded
                                : Icons.group_add_rounded,
                            key: ValueKey(canContinue),
                            size: 52,
                            color: statusColor,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Emergency Contacts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Dynamic message
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _statusMessage(),
                          key: ValueKey(_contacts.length),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Progress pips (3 required slots)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_minContacts, (i) {
                          final filled = i < _contacts.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            width: filled ? 36 : 28,
                            height: 8,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: filled
                                  ? AppColors.success
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: filled
                                    ? AppColors.success
                                    : AppColors.glassBorder,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Contact list ─────────────────────────────────────────────
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : _contacts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_add_rounded,
                                    size: 64,
                                    color: AppColors.textGrey
                                        .withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No contacts added yet',
                                    style: TextStyle(
                                      color: AppColors.textGrey
                                          .withValues(alpha: 0.6),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap below to add your first\nemergency contact',
                                    style: TextStyle(
                                      color: AppColors.textGrey
                                          .withValues(alpha: 0.4),
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24),
                              itemCount: _contacts.length,
                              itemBuilder: (_, i) =>
                                  _ContactTile(contact: _contacts[i]),
                            ),
                ),

                // ── Bottom actions ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                  child: Column(
                    children: [
                      // Add contact button (hidden at max)
                      if (_contacts.length < _maxContacts) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed:
                                _addingContact ? null : _addContact,
                            icon: _addingContact
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_rounded,
                                    color: AppColors.primary),
                            label: Text(
                              _addingContact
                                  ? 'Adding contact...'
                                  : 'Add Emergency Contact',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.primary, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Continue button
                      AnimatedOpacity(
                        opacity: canContinue ? 1.0 : 0.35,
                        duration: const Duration(milliseconds: 400),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: canContinue ? _continueToApp : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Continue to App',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Skip option
                      if (!canContinue) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _skipForNow,
                          child: const Text(
                            "I'll set up contacts later",
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Contact tile ──────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final Map<String, String> contact;
  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact['name'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact['relationship'] ?? '',
                  style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 20),
        ],
      ),
    );
  }
}
