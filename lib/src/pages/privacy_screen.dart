import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
        ],
      ),
    );
  }

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