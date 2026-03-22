import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/screens/login_screen.dart';

class PrivacyConsentScreen extends StatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  final ScrollController _scroll = ScrollController();
  bool _hasScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_hasScrolledToBottom &&
          _scroll.position.pixels >=
              _scroll.position.maxScrollExtent - 120) {
        setState(() => _hasScrolledToBottom = true);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _agreeAndContinue() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Privacy & Consent',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.backgroundBlack],
          ),
        ),
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_rounded,
                              color: AppColors.primary, size: 30),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Privacy Matters',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Please read how USafe uses your data to keep you safe before continuing.',
                                  style: TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    _buildSection(
                      icon: Icons.mic_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      title: 'Microphone Access',
                      points: [
                        _PolicyPoint(
                          heading: 'Why it is needed',
                          body:
                              'USafe uses your microphone to power its intelligent SOS sound detection system. The app listens for specific audio patterns — such as distress cues or a triggered alert tone — to automatically initiate an emergency response when you cannot manually activate it.',
                        ),
                        _PolicyPoint(
                          heading: 'When it may be used',
                          body:
                              'Microphone access is only active when the SOS monitoring feature is turned on by you. It is never used during normal app browsing, navigation, or contact management.',
                        ),
                        _PolicyPoint(
                          heading: 'How it supports your safety',
                          body:
                              'In dangerous situations where tapping your screen is not possible, sound-based detection means USafe can still respond and alert your emergency contacts — potentially saving your life.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSection(
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFF10B981),
                      title: 'Location Access',
                      points: [
                        _PolicyPoint(
                          heading: 'Why real-time location is needed',
                          body:
                              'Your location is central to USafe\'s safety features. It allows the app to provide safe route suggestions, display nearby community-reported incidents, and give emergency contacts your precise whereabouts if something goes wrong.',
                        ),
                        _PolicyPoint(
                          heading: 'Background location use',
                          body:
                              'When SOS monitoring is active, USafe may use background location to track your journey and update your emergency contacts in real time. This only occurs when the feature is explicitly enabled by you.',
                        ),
                        _PolicyPoint(
                          heading: 'How it helps in emergencies',
                          body:
                              'During an active emergency, your location is shared with your designated contacts so they can reach you or direct help to your exact position. Location data is never sold or shared with third parties.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSection(
                      icon: Icons.contacts_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      title: 'Contact Access',
                      points: [
                        _PolicyPoint(
                          heading: 'Why emergency contacts are required',
                          body:
                              'USafe requires you to designate at least 3 trusted people who will be notified in the event of an emergency. These contacts form your personal safety network and are essential for the app to function as intended.',
                        ),
                        _PolicyPoint(
                          heading: 'How contacts are selected',
                          body:
                              'USafe reads your phone contacts only when you actively choose to add someone. The app never scans, uploads, or stores your entire contact list — only the specific people you select are saved.',
                        ),
                        _PolicyPoint(
                          heading: 'How your contacts may be used',
                          body:
                              'During an active SOS event, your selected contacts receive an alert with your name and location. They will never be contacted for any marketing or non-safety purpose.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSection(
                      icon: Icons.notifications_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Push Notifications',
                      points: [
                        _PolicyPoint(
                          heading: 'What notifications are sent',
                          body:
                              'USafe sends notifications for active SOS events, incoming safety alerts from community members, and important app updates relevant to your safety. We do not send promotional or advertising notifications.',
                        ),
                        _PolicyPoint(
                          heading: 'Your control',
                          body:
                              'You can manage notification preferences at any time through your device settings or within the USafe settings screen.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildSection(
                      icon: Icons.lock_rounded,
                      iconColor: const Color(0xFFEC4899),
                      title: 'Data Responsibility',
                      points: [
                        _PolicyPoint(
                          heading: 'Your data stays yours',
                          body:
                              'USafe does not sell, share, or monetize your personal data. All information collected is used exclusively to provide and improve the safety features of the app.',
                        ),
                        _PolicyPoint(
                          heading: 'Consent is required',
                          body:
                              'By tapping "I Agree & Continue" below, you acknowledge that you have read and understood how USafe uses your data, and you consent to the use of the permissions described above for safety-related purposes only.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Scroll hint
                    if (!_hasScrolledToBottom)
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Scroll down to read all',
                              style: TextStyle(
                                color: AppColors.textGrey.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textGrey.withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Sticky agree button
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(color: AppColors.glassBorder),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _agreeAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'I Agree & Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<_PolicyPoint> points,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...points.map(_buildPoint),
      ],
    );
  }

  Widget _buildPoint(_PolicyPoint point) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              point.heading,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              point.body,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyPoint {
  final String heading;
  final String body;
  const _PolicyPoint({required this.heading, required this.body});
}
