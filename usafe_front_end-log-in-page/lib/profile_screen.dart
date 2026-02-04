import 'package:flutter/material.dart';
import 'config.dart'; // Imports AppColors
import 'auth_screens.dart'; // For Logout navigation

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Matches Home Screen
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- 1. PROFILE HEADER ---
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  // Avatar Circle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primarySky, width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.surfaceCard,
                      backgroundImage:
                          AssetImage('assets/avatar_placeholder.png'),
                      // Fallback icon if image missing
                      child:
                          Icon(Icons.person, size: 50, color: Colors.white38),
                    ),
                  ),
                  // Edit Icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primarySky,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit,
                        color: AppColors.background, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name & Email
              const Text(
                "Sanuka Pathiraja",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "sanuka@example.com",
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 30),

              // --- 2. VITAL INFO CARD (Medical ID) ---
              // Crucial for a safety app
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy, // Deep Navy (Brand Color)
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildVitalItem("Blood", "O+"),
                    _buildDivider(),
                    _buildVitalItem("Age", "24"),
                    _buildDivider(),
                    _buildVitalItem("Weight", "72kg"),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- 3. SETTINGS MENU ---
              _buildMenuTile(
                icon: Icons.person_outline,
                title: "Personal Information",
                onTap: () {},
              ),
              _buildMenuTile(
                icon: Icons.medical_services_outlined,
                title: "Medical ID & Allergies",
                onTap: () {},
              ),
              _buildMenuTile(
                icon: Icons.notifications_outlined,
                title: "Notifications",
                onTap: () {},
              ),
              _buildMenuTile(
                icon: Icons.lock_outline,
                title: "Privacy & Security",
                onTap: () {},
              ),
              _buildMenuTile(
                icon: Icons.help_outline,
                title: "Help & Support",
                onTap: () {},
              ),

              const SizedBox(height: 20),

              // --- 4. LOGOUT BUTTON ---
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    // Navigate back to Login and remove all previous routes
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout, color: AppColors.alertRed),
                  label: const Text(
                    "Logout",
                    style: TextStyle(
                      color: AppColors.alertRed,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: AppColors.surfaceCard.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              // Extra padding for bottom nav bar
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildVitalItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white24,
    );
  }

  Widget _buildMenuTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primarySky, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
