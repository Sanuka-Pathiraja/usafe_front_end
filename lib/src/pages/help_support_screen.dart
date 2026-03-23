import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Help & Support",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Hero card ──
          Container(
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
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.support_agent_rounded,
                        color: AppColors.primary, size: 26),
                    SizedBox(width: 10),
                    Text(
                      "How can we help?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "Browse the FAQ below or reach out directly. We prioritise safety-related queries.",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _QuickChip(label: "SOS & Emergency"),
                    _QuickChip(label: "AI Detection"),
                    _QuickChip(label: "Safety Score"),
                    _QuickChip(label: "Contacts"),
                    _QuickChip(label: "Privacy"),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── FAQ ──
          const Text(
            "Frequently Asked Questions",
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),

          _buildFaqItem(
            "How do I activate SOS?",
            "Press and hold the large SOS button on the home screen for 3 seconds. A countdown will begin — release early to cancel, or wait for it to complete to send an emergency alert to all your contacts.",
          ),
          _buildFaqItem(
            "Who receives my emergency alerts?",
            "Alerts are sent to all contacts listed in your Emergency Contacts tab. You need at least 3 contacts added for the emergency system to activate.",
          ),
          _buildFaqItem(
            "What is the AI Danger Detection?",
            "When enabled in Settings, the AI listens to surrounding audio using an on-device model to detect signs of distress such as screaming or shouting. It activates automatically when your safety score drops below 30. All processing happens locally — no audio is uploaded.",
          ),
          _buildFaqItem(
            "What is the Safety Score?",
            "Your safety score is a real-time risk assessment based on your location, time of day, proximity to emergency services, population density, and traffic levels. A score below 30 triggers additional protective features.",
          ),
          _buildFaqItem(
            "What is the Silent Call feature?",
            "Silent Call lets you place a call to a trusted contact that appears silent on your end. It can be used discreetly in situations where speaking aloud is not safe.",
          ),
          _buildFaqItem(
            "What does 'Contact Authorities' do?",
            "When enabled in Settings, the app will automatically attempt to call emergency services (119) during an active SOS session, in addition to notifying your personal contacts.",
          ),
          _buildFaqItem(
            "Does the app work offline?",
            "Basic SOS alerts via SMS can be sent without internet. However, live location sharing, safety score updates, and AI-backed features require an active internet connection.",
          ),
          _buildFaqItem(
            "How do I re-enable a page guide?",
            "Go to Settings → Page Guides and toggle on the guide for the page you want to revisit. The guide will play once on your next visit and then turn itself off automatically.",
          ),
          _buildFaqItem(
            "How do I delete my account?",
            "To permanently delete your account and all associated data, contact us at teamusafe@gmail.com with the subject 'Account Deletion'. We will process your request within 7 business days.",
          ),

          const SizedBox(height: 28),

          // ── Contact ──
          const Text(
            "Contact Us",
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),

          Container(
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
              border:
                  Border.all(color: AppColors.border.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _contactRow(
                  icon: Icons.email_outlined,
                  label: "Email",
                  value: "teamusafe@gmail.com",
                  note: "For general enquiries, bug reports, and account issues.",
                ),
                const SizedBox(height: 16),
                Divider(
                    color: AppColors.border.withValues(alpha: 0.4), height: 1),
                const SizedBox(height: 16),
                _contactRow(
                  icon: Icons.crisis_alert_rounded,
                  label: "Safety Issues",
                  value: "teamusafe@gmail.com",
                  note:
                      "Mark your subject as 'URGENT – Safety' for priority handling.",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    required String note,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 3),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text(note,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceElevated.withValues(alpha: 0.45),
            AppColors.surface.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Text(question,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textSecondary,
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
