import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'safety_map_screen.dart';

class SafetyScoreScreen extends StatelessWidget {
  final int safetyScore;
  final bool showBottomNav;

  const SafetyScoreScreen({
    super.key,
    this.safetyScore = 85,
    this.showBottomNav = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgDark = AppColors.background;
    final Color cardBlue = const Color(0xFF2962FF);
    final Color cardYellowBg = const Color(0xFF2C2514);
    final Color cardRedBg = const Color(0xFF2C1515);
    final Color textWhite = Colors.white;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Safety Score',
          style: TextStyle(color: textWhite, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: textWhite),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primary score card.
            Container(
              width: double.infinity,
              height: 360,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBlue,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 20),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$safetyScore',
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const TextSpan(
                          text: '/100',
                          style: TextStyle(fontSize: 24, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You are in a safe area',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      // Drill down into the map detail screen.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SafetyMapScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF009688),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View Details',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Example alternate states for context.
            Text(
              'Other States',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _buildStateCard(
              score: '62/100',
              status: 'Proceed with Caution',
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.white,
              circleColor: Colors.orange,
              bgColor: cardYellowBg,
            ),
            const SizedBox(height: 12),
            _buildStateCard(
              score: '28/100',
              status: 'High Risk Area',
              icon: Icons.cancel_outlined,
              iconColor: Colors.white,
              circleColor: Colors.redAccent,
              bgColor: cardRedBg,
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          showBottomNav ? _buildBottomNavBar(bgDark, cardBlue) : null,
    );
  }

  Widget _buildStateCard({
    required String score,
    required String status,
    required IconData icon,
    required Color iconColor,
    required Color circleColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: circleColor,
            radius: 22,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                score,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Icon(Icons.chevron_right, color: Colors.grey[600]),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(Color bg, Color activeColor) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(Icons.home_filled, false),
          _navIcon(Icons.map, true, activeColor: activeColor),
          _navIcon(Icons.people, false),
          _navIcon(Icons.person, false),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, bool isActive, {Color? activeColor}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isActive ? (activeColor ?? Colors.white) : Colors.grey[600],
          size: 26,
        ),
        if (isActive) const SizedBox(height: 4),
        if (isActive)
          Text(
            'Map',
            style: TextStyle(
              color: activeColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          )
      ],
    );
  }
}
