import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:usafe_front_end/core/constants/app_colors.dart';

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
              const Center(
                child: Text(
                  "Settings",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                title: "Test Emergency System",
                subtitle: "Send a test alert",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const MyHomePage(title: "Community Reports"),
                  ),
                ),
              ),
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
}
