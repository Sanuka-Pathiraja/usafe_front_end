import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

import './payment_screen.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import './communityReport_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with TickerProviderStateMixin {
  bool shareLocation = true;
  bool pushNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // ================= LOAD / SAVE =================
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      shareLocation = prefs.getBool("share_location") ?? true;
      pushNotifications = prefs.getBool("push_notifications") ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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

    await _saveSetting("share_location", value);
    setState(() => shareLocation = value);

    _showSnack(
      value ? "📍 Location sharing enabled" : "📍 Location sharing disabled",
    );
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
              const SizedBox(height: 30),
              _sectionTitle("Safety"),
              _actionTile(
                icon: Icons.security,
                title: "Test Emergency System",
                subtitle: "Send a test alert",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyHomePage(
                      title: "Community Reports",
                    ),
                  ),
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
        boxShadow: value
            ? [
                BoxShadow(
                  color: AppColors.safetyTeal.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
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
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: const [
            Icon(Icons.workspace_premium, color: Colors.black, size: 30),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Upgrade to Pro",
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    "Unlock advanced safety & offline features",
                    style: TextStyle(color: Colors.black87, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.black54, size: 16),
          ],
        ),
      ),
    );
  }
}
