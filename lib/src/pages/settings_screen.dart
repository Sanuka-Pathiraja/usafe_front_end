import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';

import './payment_screen.dart';
import './communityReport_screen.dart';
import './notifications_screen.dart';
import './privacy_screen.dart';
import './help_support_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool shareLocation = true;
  bool notificationsEnabled = false;
  bool _loadingTestContacts = false;
  List<Map<String, dynamic>> _testContacts = [];
  final Map<String, String> _callStates = <String, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSettings();
    }
  }

  // ================= LOAD SETTINGS =================
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationStatus = await Permission.notification.status;

    setState(() {
      shareLocation = prefs.getBool("share_location") ?? true;
      notificationsEnabled = notificationStatus.isGranted;
    });

    await _loadTestContacts();
  }

  Future<void> _loadTestContacts() async {
    if (_loadingTestContacts) return;
    setState(() => _loadingTestContacts = true);

    try {
      final contacts = await AuthService.fetchContacts();
      if (!mounted) return;
      setState(() {
        _testContacts = contacts;
        for (var i = 0; i < _testContacts.length; i++) {
          final key = _contactKey(_testContacts[i], i);
          _callStates.putIfAbsent(key, () => 'idle');
        }
      });
    } catch (e) {
      if (!mounted) return;
      final error = e.toString().replaceFirst('Exception: ', '');
      if (!error.toLowerCase().contains('not authenticated')) {
        _showSnack(error);
      }
      setState(() => _testContacts = []);
    } finally {
      if (mounted) {
        setState(() => _loadingTestContacts = false);
      }
    }
  }

  // ================= LOCATION =================
  Future<void> _toggleLocation(bool value) async {
    if (value) {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        await openAppSettings();
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("share_location", value);

    setState(() => shareLocation = value);

    _showSnack(
      value ? "📍 Location sharing enabled" : "📍 Location sharing disabled",
    );
  }

  // ================= NOTIFICATIONS =================
  Future<void> _openNotificationSettings() async {
    if (Platform.isAndroid) {
      // Android: direct app notification page
      final packageName =
          "com.yourcompany.yourapp"; // <-- REPLACE with your app id
      final uri = Uri.parse("android-app://$packageName/settings");
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        // fallback
        await openAppSettings();
      }
    } else if (Platform.isIOS) {
      // iOS: open app settings (cannot go directly to notification page)
      final url = Uri.parse("app-settings:");
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnack("Cannot open app settings");
      }
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _contactKey(Map<String, dynamic> contact, int index) {
    final id = (contact['contactId'] ?? contact['_id'] ?? '').toString();
    if (id.isNotEmpty) return id;
    final phone = (contact['phone'] ?? '').toString();
    if (phone.isNotEmpty) return phone;
    return 'idx_$index';
  }

  String _displayName(Map<String, dynamic> contact) {
    final name = (contact['name'] ?? contact['fullName'] ?? '').toString().trim();
    return name.isEmpty ? 'Unknown' : name;
  }

  String _displayRelationship(Map<String, dynamic> contact) {
    final relation =
        (contact['relationship'] ?? contact['relation'] ?? 'Contact').toString();
    return relation.trim().isEmpty ? 'Contact' : relation;
  }

  String _contactPhone(Map<String, dynamic> contact) {
    const phoneKeys = ['phone', 'phoneNumber', 'mobile', 'contactNumber'];
    for (final key in phoneKeys) {
      final value = (contact[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _normalizePhoneTo94(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0094')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('94') && digits.length == 11) return digits;
    if (digits.startsWith('0') && digits.length == 10) {
      return '94${digits.substring(1)}';
    }
    if (digits.length == 9) {
      return '94$digits';
    }
    throw Exception('Invalid contact phone number for test call.');
  }

  String _maskedPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return '****';
    final visible = digits.substring(digits.length - 4);
    return '${'*' * (digits.length - 4)}$visible';
  }

  String _callStateLabel(String state) {
    switch (state) {
      case 'calling':
        return 'Calling...';
      case 'success':
        return 'Call success';
      case 'failed':
        return 'Call failed';
      case 'idle':
      default:
        return 'Idle';
    }
  }

  Color _callStateColor(String state) {
    switch (state) {
      case 'calling':
        return Colors.orangeAccent;
      case 'success':
        return Colors.greenAccent;
      case 'failed':
        return Colors.redAccent;
      case 'idle':
      default:
        return Colors.white60;
    }
  }

  Future<void> _onTestCallPressed(Map<String, dynamic> contact, int index) async {
    final key = _contactKey(contact, index);
    if ((_callStates[key] ?? 'idle') == 'calling') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2026),
          title: const Text('Confirm', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Place a test call to this contact?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Call'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final rawPhone = _contactPhone(contact);
    String normalizedPhone;
    try {
      normalizedPhone = _normalizePhoneTo94(rawPhone);
    } catch (_) {
      setState(() => _callStates[key] = 'failed');
      _showSnack('Invalid phone number for this contact.');
      return;
    }

    setState(() => _callStates[key] = 'calling');
    try {
      await AuthService.triggerTestCall(to: normalizedPhone);
      if (!mounted) return;
      setState(() => _callStates[key] = 'success');
      _showSnack('Test call placed.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _callStates[key] = 'failed');
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                      tooltip: 'Back',
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Settings",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 30),
              _sectionTitle("Privacy & Permissions"),
              _premiumToggleTile(
                icon: Icons.location_on_outlined,
                title: "Share Location",
                subtitle: "Live location for emergencies",
                value: shareLocation,
                onChanged: _toggleLocation,
              ),
              _premiumToggleTile(
                icon: Icons.notifications_outlined,
                title: "Push Notifications",
                subtitle: notificationsEnabled
                    ? "Enabled in device settings"
                    : "Disabled in device settings",
                value: notificationsEnabled,
                onChanged: (_) => _openNotificationSettings(),
              ),
              _actionTile(
                icon: Icons.lock_outline,
                title: "Privacy & Security",
                subtitle: "Manage data and permissions",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              ),
              const SizedBox(height: 30),
              _sectionTitle("Safety"),
              _actionTile(
                icon: Icons.security,
                title: "Community Report Test",
                subtitle: "Send a test alert",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const MyHomePage(title: "Community Reports"),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _sectionTitle("Emergency Contacts Test Call"),
              _buildEmergencyContactsTestCallSection(),
              const SizedBox(height: 30),
              _sectionTitle("Support"),
              _actionTile(
                icon: Icons.help_outline,
                title: "Help & Support",
                subtitle: "FAQs and contact support",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                ),
              ),
              const SizedBox(height: 30),
              _sectionTitle("Premium"),
              _premiumCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ================= COMPONENTS =================
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _premiumToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? AppColors.safetyTeal.withOpacity(0.2)
                  : Colors.white10,
            ),
            child: Icon(
              icon,
              color: value ? AppColors.safetyTeal : Colors.white60,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.safetyTeal,
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primarySky),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }

  Widget _premiumCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaymentScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: const [
            Icon(Icons.workspace_premium, color: Colors.black, size: 30),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                "Upgrade to Pro",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsTestCallSection() {
    if (_loadingTestContacts) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_testContacts.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          "No emergency contacts found.",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      children: List.generate(_testContacts.length, (index) {
        final contact = _testContacts[index];
        final key = _contactKey(contact, index);
        final state = _callStates[key] ?? 'idle';
        final isCalling = state == 'calling';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(contact),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayRelationship(contact),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _maskedPhone(_contactPhone(contact)),
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _callStateLabel(state),
                      style: TextStyle(
                        color: _callStateColor(state),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 108,
                height: 40,
                child: ElevatedButton(
                  onPressed:
                      isCalling ? null : () => _onTestCallPressed(contact, index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySky,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white24,
                    disabledForegroundColor: Colors.white70,
                    minimumSize: const Size(108, 40),
                    maximumSize: const Size(108, 40),
                    fixedSize: const Size(108, 40),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(isCalling ? 'Calling...' : 'Test Call'),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
