import 'package:flutter/material.dart';
import '../config.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Help & Support",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text("FAQ",
              style: TextStyle(
                  color: AppColors.primarySky,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildExpansionTile("How does the SOS button work?",
              "Holding the button for 3 seconds triggers an alert to your saved contacts with your live location."),
          _buildExpansionTile("Who can see my location?",
              "Only your emergency contacts can see your location when an alert is active."),
          _buildExpansionTile(
              "Is this app free?", "Yes, USafe is currently free to use."),
          const SizedBox(height: 40),
          const Text("Contact Us",
              style: TextStyle(
                  color: AppColors.primarySky,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.email_outlined, color: Colors.white),
                SizedBox(width: 16),
                Text("support@usafe.com",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildExpansionTile(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500)),
          iconColor: AppColors.primarySky,
          collapsedIconColor: Colors.white54,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(content,
                  style: const TextStyle(color: AppColors.textGrey)),
            ),
          ],
        ),
      ),
    );
  }
}
