import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/auth/google_auth_service.dart';
import 'package:usafe_front_end/features/auth/screens/login_screen.dart';
import 'package:usafe_front_end/src/pages/contacts_screen.dart';
import 'package:usafe_front_end/src/pages/my_reports_screen.dart';

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
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isRefreshing = true);
    await AuthService.validateSession(); // refreshes /user/get cache if available
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          // Matches your exact ContactsScreen back button
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            if (widget.onBackHome != null) {
              widget.onBackHome!();
              return;
            }
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'User Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            if (_isRefreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            _buildProfileHeader(),
            const SizedBox(height: 30),
            _buildStatsRow(),
            const SizedBox(height: 25),
            _buildInfoCard(),
            const SizedBox(height: 25),
            _buildAccountsSection(),
            const SizedBox(height: 25),
            _buildLogoutButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

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
    final parts = full.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return full.isNotEmpty ? full[0].toUpperCase() : '?';
  }

  String? _profileImageUrl() {
    const keys = <String>[
      'picture',
      'photoUrl',
      'photoURL',
      'photo',
      'avatarUrl',
      'profileImage',
      'avatar',
      'imageUrl',
      'image',
      'googlePhotoUrl',
      'googlePicture',
    ];
    for (final key in keys) {
      final value = _asText(_userData?[key]);
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> _openEditProfileDialog() async {
    final firstCtrl = TextEditingController(text: _firstName());
    final lastCtrl = TextEditingController(text: _lastName());
    final emailCtrl = TextEditingController(text: _asText(_userData?['email']));
    final phoneCtrl = TextEditingController(text: _asText(_userData?['phone']));
    final ageCtrl = TextEditingController(text: _asText(_userData?['age']));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2128),
          title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(controller: firstCtrl, label: 'First name'),
                const SizedBox(height: 10),
                _buildDialogField(controller: lastCtrl, label: 'Last name'),
                const SizedBox(height: 10),
                _buildDialogField(controller: emailCtrl, label: 'Email'),
                const SizedBox(height: 10),
                _buildDialogField(controller: phoneCtrl, label: 'Phone'),
                const SizedBox(height: 10),
                _buildDialogField(
                  controller: ageCtrl,
                  label: 'Age',
                  keyboardType: TextInputType.number,
                ),
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
                  'lastName': lastCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'age': int.tryParse(ageCtrl.text.trim()),
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    // Avoid disposing dialog controllers immediately after pop; let Flutter
    // complete route teardown first to prevent inherited dependents assertions.
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
        lastName: result['lastName'] as String?,
        email: result['email'] as String?,
        phone: result['phone'] as String?,
        age: result['age'] as int?,
      );
      if (!mounted) return;
      setState(() {
        _userData = updated;
        _isRefreshing = false;
      });
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

  // Backward-compatible method name for old hot-reload closures.
  void _toggleEdit() {
    _openEditProfileDialog();
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _displayName();
    final imageUrl = _profileImageUrl();
    final initials = _initials();
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2B3440),
              ),
              child: ClipOval(
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildInitialsAvatar(initials),
                      )
                    : _buildInitialsAvatar(initials),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleEdit,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          name.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar(String initials) {
    return Container(
      color: const Color(0xFF2B3440),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard("TRUSTED", _contactCount.toString(), Icons.people_outline,
            onTap: () {
          if (widget.onOpenContacts != null) {
            widget.onOpenContacts!();
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactsScreen()),
          );
        }),
        const SizedBox(width: 15),
        _buildStatCard(
          "REPORTS",
          _reportCount.toString(),
          Icons.description_outlined,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyReportsScreen()),
            );
            if (!mounted) return;
            _loadData();
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2128), // Matches Contact Card color
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white70, size: 24),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final phone = _pickFirstText(
      const ['phone', 'phoneNumber', 'mobile', 'contactNumber'],
      fallback: 'Not set',
    );
    final birthday = _pickFirstText(
      const ['birthday', 'birthDate', 'dob', 'dateOfBirth'],
      fallback: _pickFirstText(const ['age'], fallback: 'Not set'),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2128), // Consistent surface color
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildInfoRow(
              Icons.email_outlined, "Email", _userData?['email'] ?? 'Not set'),
          const Divider(color: Colors.white10, height: 24),
          _buildInfoRow(Icons.phone_android, "Phone", phone),
          const Divider(color: Colors.white10, height: 24),
          _buildInfoRow(Icons.cake_outlined, "Birthday", birthday),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 11)),
            Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        )
      ],
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: () async {
        await AuthService.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 12),
            Text(
              "LOG OUT",
              style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2128),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accounts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _isAddingAccount ? null : _handleAddAnotherAccount,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        Text(
                          _isAddingAccount
                              ? 'Opening Google sign-in...'
                              : 'Sign in with another Google account',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isAddingAccount)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          ),
        ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(googleResult.message ?? 'Google sign-in failed.'),
            backgroundColor: AppColors.alertRed,
          ),
        );
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
        final message =
            (result['message'] ?? 'Google login failed.').toString();
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
}
