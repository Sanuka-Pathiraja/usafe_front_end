import 'package:flutter/material.dart';
import '../config.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Privacy & Security",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildActionTile(Icons.lock_outline, "Change Password", () {}),
          _buildActionTile(
              Icons.location_on_outlined, "Location Permissions", () {}),
          _buildActionTile(
              Icons.remove_red_eye_outlined, "Data Visibility", () {}),
          _buildActionTile(Icons.devices, "Active Devices", () {}),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () {},
            child: const Text("Delete Account",
                style: TextStyle(color: AppColors.alertRed)),
          )
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primarySky),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
