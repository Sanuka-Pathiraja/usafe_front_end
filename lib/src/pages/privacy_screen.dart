import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Privacy & Security",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _buildIntro(),
          const SizedBox(height: 20),
          _buildSection(
            icon: Icons.location_on_outlined,
            iconColor: AppColors.primary,
            title: "Location Data",
            points: [
              "Location is only accessed when SOS mode is active or the safety score is being calculated.",
              "Background location is used solely to broadcast your position to emergency contacts during an active session.",
              "Location data is never stored on our servers beyond the duration of an emergency session.",
            ],
          ),
          _buildSection(
            icon: Icons.mic_none_rounded,
            iconColor: AppColors.primary,
            title: "Microphone & Audio",
            points: [
              "Audio analysis is opt-in and only activates when your safety score drops below 30 and you have enabled the AI Microphone Listening setting.",
              "Audio is processed locally on your device using an on-device AI model — no audio is uploaded or stored.",
              "The microphone is never accessed in the background without your explicit permission and the setting being enabled.",
            ],
          ),
          _buildSection(
            icon: Icons.people_outline_rounded,
            iconColor: AppColors.primary,
            title: "Emergency Contacts",
            points: [
              "Your emergency contacts are stored securely and only used to send alerts during active SOS sessions.",
              "Contact information is never shared with third parties or used for marketing purposes.",
              "You can remove or update your contacts at any time from the Contacts tab.",
            ],
          ),
          _buildSection(
            icon: Icons.shield_outlined,
            iconColor: AppColors.success,
            title: "Data Security",
            points: [
              "All communication between the app and our servers is encrypted using industry-standard TLS.",
              "Your account credentials are hashed and never stored in plain text.",
              "We do not sell, rent, or trade your personal data to any third party under any circumstances.",
            ],
          ),
          _buildSection(
            icon: Icons.storage_outlined,
            iconColor: AppColors.textSecondary,
            title: "Data Retention",
            points: [
              "Emergency session data is retained for 30 days to allow review, then permanently deleted.",
              "Safety score snapshots are anonymised and may be retained for system improvement.",
              "Deleting your account removes all personal data from our servers within 7 business days.",
            ],
          ),
          _buildSection(
            icon: Icons.verified_user_outlined,
            iconColor: AppColors.success,
            title: "Your Rights",
            points: [
              "You can request a copy of all data we hold about you at any time via teamusafe@gmail.com.",
              "You have the right to correct inaccurate data or request complete deletion of your account.",
              "You can withdraw consent for any data processing by disabling the relevant feature in Settings.",
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.surfaceElevated.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.primary, size: 28),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your privacy is our priority",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "USafe is built for your safety. We only collect data that is strictly necessary to protect you, and we are fully transparent about how it is used.",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> points,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceElevated.withValues(alpha: 0.5),
            AppColors.surface.withValues(alpha: 0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
