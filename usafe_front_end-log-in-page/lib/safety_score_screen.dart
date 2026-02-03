import 'package:flutter/material.dart';
import 'config.dart'; // Imports AppColors

class SafetyScoreScreen extends StatelessWidget {
  final VoidCallback onViewMap; // Function to handle "View Details" click

  const SafetyScoreScreen({super.key, required this.onViewMap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    "My Safety Score",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // --- MAIN SCORE CARD (UPDATED TO DARKER NAVY BLUE) ---
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  // FIXED: Switched to Deep Navy (Easier on eyes)
                  color: AppColors.primaryNavy,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.3), // Darker shadow for depth
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Logo Circle
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.1), // Subtle semi-transparent white
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/usafe_logo.png',
                        height: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Score Text
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: "85",
                            style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          TextSpan(
                            text: "/100",
                            style:
                                TextStyle(fontSize: 24, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "You are in a safe area",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 30),

                    // View Details Button
                    ElevatedButton(
                      onPressed: onViewMap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        // FIXED: Text matches the new Darker Navy
                        foregroundColor: AppColors.primaryNavy,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("View Details",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- "OTHER STATES" SECTION ---
              const Text(
                "Other States",
                style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              // Caution Card (Amber)
              _buildStateCard(
                color: const Color(0xFFFBC02D),
                icon: Icons.warning_amber_rounded,
                score: "62/100",
                status: "Proceed with Caution",
              ),

              const SizedBox(height: 15),

              // High Risk Card (Red)
              _buildStateCard(
                color: AppColors.alertRed,
                icon: Icons.cancel_outlined,
                score: "28/100",
                status: "High Risk Area",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateCard(
      {required Color color,
      required IconData icon,
      required String score,
      required String status}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style:
                      const TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38),
        ],
      ),
    );
  }
}
