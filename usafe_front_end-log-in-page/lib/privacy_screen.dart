import 'package:flutter/material.dart';
<<<<<<< HEAD
import '../config.dart';
=======
import 'config.dart'; // <--- Fixes AppColors error
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
<<<<<<< HEAD
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
=======
        title: const Text("Privacy Policy", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection("Data Collection", "We collect your location data only when you activate SOS mode to share it with your emergency contacts."),
          _buildSection("Data Security", "Your personal data is encrypted and stored securely. We do not sell your data to third parties."),
          _buildSection("Location Services", "USafe requires background location access to ensure your safety during an emergency."),
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387
        ],
      ),
    );
  }

<<<<<<< HEAD
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
=======
  Widget _buildSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.primarySky, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(content, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387
