import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/auth/google_auth_service.dart';
import 'package:usafe_front_end/features/auth/screens/login_screen.dart';
import 'package:usafe_front_end/src/pages/contacts_screen.dart';
import 'package:usafe_front_end/src/pages/my_reports_screen.dart';
import 'package:usafe_front_end/src/pages/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBackHome;
  final VoidCallback? onOpenContacts;

  const ProfileScreen({super.key, this.onBackHome, this.onOpenContacts});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  int _contactCount = 0;
  int _reportCount = 0;
  bool _isRefreshing = false;
  bool _isAddingAccount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isRefreshing = true);
    await AuthService.validateSession();
    final user = await AuthService.getCurrentUser();

    int contactsCount = _contactCount;
    int reportCount = AuthService.communityReportCountFromUser(user);

    try {
      final contacts = await AuthService.fetchContacts();
      contactsCount = contacts.length;
    } catch (_) {}

    try {
      reportCount = await AuthService.fetchCommunityReportCount();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _userData = user;
      _contactCount = contactsCount;
      _reportCount = reportCount;
      _isRefreshing = false;
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isRefreshing) {
      _loadData();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _asText(dynamic value) => value?.toString().trim() ?? '';

  String _pickFirstText(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = _asText(_userData?[key]);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  String _firstName() {
    final fromFirst = _asText(_userData?['firstName']);
    if (fromFirst.isNotEmpty) return fromFirst;
    final fullName = _asText(_userData?['name']);
    if (fullName.isEmpty) return '';
    return fullName.split(RegExp(r'\s+')).first;
  }

  String _lastName() {
    final fromLast = _asText(_userData?['lastName']);
    if (fromLast.isNotEmpty) return fromLast;
    final fullName = _asText(_userData?['name']);
    if (fullName.isEmpty) return '';
    final parts = fullName.split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  String _displayName() {
    final first = _firstName();
    final last = _lastName();
    final full = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
    return full.isNotEmpty ? full : 'User';
  }

  String _initials() {
    final first = _firstName();
    final last = _lastName();
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) return first[0].toUpperCase();
    final full = _displayName();
    final parts =
        full.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return full.isNotEmpty ? full[0].toUpperCase() : '?';
  }

  String? _profileImageUrl() {
    const keys = <String>[
      'picture', 'photoUrl', 'photoURL', 'photo', 'avatarUrl',
      'profileImage', 'avatar', 'imageUrl', 'image',
      'googlePhotoUrl', 'googlePicture',
    ];
    for (final key in keys) {
      final value = _asText(_userData?[key]);
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  // ── Edit profile dialog ───────────────────────────────────────────────────

  Future<void> _openEditProfileDialog() async {
    final firstCtrl = TextEditingController(text: _firstName());
    final lastCtrl  = TextEditingController(text: _lastName());
    final emailCtrl = TextEditingController(text: _asText(_userData?['email']));
    final phoneCtrl = TextEditingController(text: _asText(_userData?['phone']));
    final ageCtrl   = TextEditingController(text: _asText(_userData?['age']));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Edit Profile',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(controller: firstCtrl, label: 'First name', hintText: 'e.g. Ayesha'),
                const SizedBox(height: 10),
                _buildDialogField(controller: lastCtrl,  label: 'Last name',  hintText: 'e.g. Perera'),
                const SizedBox(height: 10),
                _buildDialogField(controller: emailCtrl, label: 'Email',      hintText: 'e.g. ayesha@example.com'),
                const SizedBox(height: 10),
                _buildDialogField(controller: phoneCtrl, label: 'Phone',      hintText: 'e.g. 0771234567'),
                const SizedBox(height: 10),
                _buildDialogField(controller: ageCtrl,   label: 'Age',        hintText: 'e.g. 22', keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, <String, dynamic>{
                  'firstName': firstCtrl.text.trim(),
                  'lastName':  lastCtrl.text.trim(),
                  'email':     emailCtrl.text.trim(),
                  'phone':     phoneCtrl.text.trim(),
                  'age':       int.tryParse(ageCtrl.text.trim()),
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      firstCtrl.dispose();
      lastCtrl.dispose();
      emailCtrl.dispose();
      phoneCtrl.dispose();
      ageCtrl.dispose();
    });

    if (!mounted || result == null) return;

    setState(() => _isRefreshing = true);
    try {
      final updated = await AuthService.updateUserProfile(
        firstName: result['firstName'] as String?,
        lastName:  result['lastName']  as String?,
        email:     result['email']     as String?,
        phone:     result['phone']     as String?,
        age:       result['age']       as int?,
      );
      if (!mounted) return;
      setState(() { _userData = updated; _isRefreshing = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _toggleEdit() => _openEditProfileDialog();

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Future<void> _handleAddAnotherAccount() async {
    if (_isAddingAccount) return;
    setState(() => _isAddingAccount = true);
    try {
      final googleResult = await GoogleAuthService.signInForBackend();
      if (!googleResult.success || (googleResult.idToken ?? '').isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(googleResult.message ?? 'Google sign-in failed.'),
          backgroundColor: AppColors.alertRed,
        ));
        return;
      }

      final result = await AuthService.googleLoginDetailed(
        googleResult.idToken!,
        accessToken: googleResult.accessToken,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account switched successfully.')),
        );
      } else {
        final message = (result['message'] ?? 'Google login failed.').toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.alertRed),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isAddingAccount = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomOverlaySpacing = 140.0 + bottomInset;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Hero gradient band at the top
          Positioned(
            top: 0, left: 0, right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.28),
                    AppColors.background.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── App bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white, size: 20),
                        onPressed: () {
                          if (widget.onBackHome != null) {
                            widget.onBackHome!();
                            return;
                          }
                          if (Navigator.canPop(context)) Navigator.pop(context);
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: InkWell(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const SettingsPage())),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    width: 0.8),
                              ),
                              child: const Icon(Icons.settings_outlined,
                                  color: Colors.white70, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Thin progress line ──
                if (_isRefreshing)
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                  )
                else
                  const SizedBox(height: 2),

                // ── Scrollable body ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, bottomOverlaySpacing),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _buildProfileHeader(),
                        const SizedBox(height: 28),
                        _buildStatsRow(),
                        const SizedBox(height: 20),
                        _buildInfoCard(),
                        const SizedBox(height: 20),
                        _buildAccountsSection(),
                        const SizedBox(height: 20),
                        _buildLogoutButton(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile header ────────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    final name     = _displayName();
    final email    = _asText(_userData?['email']);
    final imageUrl = _profileImageUrl();
    final initials = _initials();

    return Column(
      children: [
        // Avatar with glow + edit badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Outer glow ring
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
            // Border ring
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.60), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildInitialsAvatar(initials),
                        )
                      : _buildInitialsAvatar(initials),
                ),
              ),
            ),
            // Edit badge
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _toggleEdit,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.50),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Name
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),

        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Edit profile pill
        GestureDetector(
          onTap: _toggleEdit,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.40),
                      width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined,
                        color: AppColors.primary.withValues(alpha: 0.90),
                        size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.90),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar(String initials) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard(
          label: 'Contacts',
          value: _contactCount.toString(),
          icon: Icons.people_outline_rounded,
          onTap: () {
            if (widget.onOpenContacts != null) {
              widget.onOpenContacts!();
              return;
            }
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ContactsScreen()));
          },
        ),
        const SizedBox(width: 14),
        _buildStatCard(
          label: 'Reports',
          value: _reportCount.toString(),
          icon: Icons.description_outlined,
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyReportsScreen()));
            if (!mounted) return;
            _loadData();
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.28), width: 1),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    final phone = _pickFirstText(
      const ['phone', 'phoneNumber', 'mobile', 'contactNumber'],
      fallback: 'Not set',
    );
    final birthday = _pickFirstText(
      const ['birthday', 'birthDate', 'dob', 'dateOfBirth'],
      fallback: _pickFirstText(const ['age'], fallback: 'Not set'),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.10), width: 0.8),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _userData?['email']?.toString() ?? 'Not set',
              ),
              _buildInfoDivider(),
              _buildInfoRow(
                icon: Icons.phone_android_rounded,
                label: 'Phone',
                value: phone,
              ),
              _buildInfoDivider(),
              _buildInfoRow(
                icon: Icons.cake_outlined,
                label: 'Birthday / Age',
                value: birthday,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoDivider() {
    return Divider(
      height: 1,
      thickness: 0.6,
      color: Colors.white.withValues(alpha: 0.08),
      indent: 56,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
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

  // ── Accounts section ──────────────────────────────────────────────────────

  Widget _buildAccountsSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.10), width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Text(
                  'Accounts',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.6,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              InkWell(
                onTap: _isAddingAccount ? null : _handleAddAnotherAccount,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add another account',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isAddingAccount
                                  ? 'Opening Google sign-in...'
                                  : 'Sign in with another Google account',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.40),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isAddingAccount)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary.withValues(alpha: 0.70)),
                        )
                      else
                        Icon(Icons.chevron_right,
                            color: Colors.white.withValues(alpha: 0.30),
                            size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Logout button ─────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () async {
        await AuthService.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.alert.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: AppColors.alert.withValues(alpha: 0.35), width: 1),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: AppColors.alert, size: 18),
                SizedBox(width: 10),
                Text(
                  'Log Out',
                  style: TextStyle(
                    color: AppColors.alert,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
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
