import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Help & Support", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("FAQ", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildFaqItem("How do I activate SOS?", "Press and hold the large button on the home screen for 3 seconds."),
          _buildFaqItem("Who receives my alerts?", "All contacts listed in your 'Emergency Contacts' tab."),
          _buildFaqItem("Does it work offline?", "Basic features work, but location sharing requires an internet connection."),
          
          const SizedBox(height: 40),
          const Text("Contact Us", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              children: [
                Icon(Icons.email, color: AppColors.primarySky),
                SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Email Support", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text("support@usafe.app", style: TextStyle(color: Colors.white70)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: const TextStyle(color: AppColors.textGrey)),
          )
        ],
        iconColor: AppColors.primarySky,
        collapsedIconColor: Colors.white70,
      ),
    );
  }
}