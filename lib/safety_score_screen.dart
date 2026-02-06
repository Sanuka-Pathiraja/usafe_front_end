import 'package:flutter/material.dart';
import 'config.dart'; // Imports AppColors for brand consistency

/// ---------------------------------------------------------------------------
/// SAFETY SCORE SCREEN
///
/// This screen displays the user's current safety rating based on their location.
/// It appears when the user taps the "Map" tab in the bottom navigation.
///
/// Features:
/// 1. A large "Main Score Card" showing the current safety score (e.g., 85/100).
/// 2. A button to navigate to the detailed Live Map.
/// 3. A list of "Other States" (Caution, High Risk) for quick reference.
/// ---------------------------------------------------------------------------

class SafetyScoreScreen extends StatelessWidget {
  // Callback function to handle navigation when "View Details" is clicked.
  // This allows the parent widget (HomeScreen) to control the actual navigation logic.
  final VoidCallback onViewMap;

  const SafetyScoreScreen({super.key, required this.onViewMap});

  // ---------------------------------------------------------------------------
  // MAIN UI BUILDER
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Deep Matte Midnight

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SECTION 1: HEADER ---
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

              // --- SECTION 2: MAIN SCORE CARD ---
              // This is the large colored card showing the primary status.
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy, // Deep Navy Brand Color
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3), // Adds depth
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // A. Logo Circle
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.1), // Subtle glass effect
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/usafe_logo.png',
                        height: 50,
                        color:
                            Colors.white, // Render logo in white for contrast
                      ),
                    ),
                    const SizedBox(height: 20),

                    // B. Score Text (e.g., "85/100")
                    // Uses RichText to style the "85" differently from "/100"
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

                    // C. Status Message
                    const Text(
                      "You are in a safe area",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 30),

                    // D. "View Details" Button
                    ElevatedButton(
                      onPressed:
                          onViewMap, // Triggers the callback passed from Parent
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor:
                            AppColors.primaryNavy, // Text matches card bg
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

              // --- SECTION 3: OTHER STATES LIST ---
              const Text(
                "Other States",
                style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              // Item 1: Caution Card (Amber)
              _buildStateCard(
                color: const Color(0xFFFBC02D),
                icon: Icons.warning_amber_rounded,
                score: "62/100",
                status: "Proceed with Caution",
              ),

              const SizedBox(height: 15),

              // Item 2: High Risk Card (Red)
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

  // ---------------------------------------------------------------------------
  // HELPER WIDGET: STATE CARD
  // ---------------------------------------------------------------------------
  /// Reusable widget to build the rows for "Caution" and "High Risk" states.
  ///
  /// [color]  - The background color of the icon circle (e.g., Red, Amber).
  /// [icon]   - The icon data to display.
  /// [score]  - The score string (e.g., "28/100").
  /// [status] - The descriptive text (e.g., "High Risk Area").
  Widget _buildStateCard(
      {required Color color,
      required IconData icon,
      required String score,
      required String status}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard, // Dark background card
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.white.withOpacity(0.05)), // Subtle border
      ),
      child: Row(
        children: [
          // Colored Icon Circle
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),

          // Text Details
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

          // Trailing Arrow
          const Icon(Icons.chevron_right, color: Colors.white38),
        ],
      ),
    );
  }
}
