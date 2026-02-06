import 'dart:async';

import 'package:flutter/material.dart';
import 'config.dart';

class SafetyScoreScreen extends StatefulWidget {
  final VoidCallback onViewMap;

  const SafetyScoreScreen({super.key, required this.onViewMap});

  @override
  State<SafetyScoreScreen> createState() => _SafetyScoreScreenState();
}

class _SafetyScoreScreenState extends State<SafetyScoreScreen> {
  Timer? _scoreTimer;
  int _score = 85;
  Color _scoreColor = AppColors.primarySky;
  String _scoreStatus = "You are in a safe area";

  int _reportCount = 0;

  @override
  void initState() {
    super.initState();
    _startScoreSimulation();
  }

  @override
  void dispose() {
    _scoreTimer?.cancel();
    super.dispose();
  }

  void _startScoreSimulation() {
    _scoreTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() {
        _score = (_score - 3).clamp(25, 100);
        if (_score >= 70) {
          _scoreColor = AppColors.primarySky;
          _scoreStatus = "You are in a safe area";
        } else if (_score >= 45) {
          _scoreColor = Colors.orange;
          _scoreStatus = "Proceed with caution";
        } else {
          _scoreColor = AppColors.alertRed;
          _scoreStatus = "High risk area";
        }
      });
    });
  }

  void _reportDanger() {
    setState(() {
      _reportCount += 1;
    });
  }

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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: Text(
                    "My Safety Score",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              _buildScoreCard(context),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      _buildMockMapPanel(),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.extended(
                          onPressed: _reportDanger,
                          backgroundColor: AppColors.alertRed,
                          icon: const Icon(Icons.report, color: Colors.white),
                          label: const Text(
                            "Report Danger",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 18,
                        child: _buildReportCountChip(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Other States",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textGrey,
                      letterSpacing: 0.6,
                    ),
              ),
              const SizedBox(height: 12),
              _buildStateCard(
                color: const Color(0xFFFBC02D),
                icon: Icons.warning_amber_rounded,
                score: "62/100",
                status: "Proceed with Caution",
              ),
              const SizedBox(height: 12),
              _buildStateCard(
                color: AppColors.alertRed,
                icon: Icons.cancel_outlined,
                score: "28/100",
                status: "High Risk Area",
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: _scoreColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _scoreColor.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _scoreColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "$_score",
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const TextSpan(
                  text: "/100",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _scoreStatus,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: widget.onViewMap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryNavy,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("View Details"),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockMapPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCardSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/usafe_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          _buildZoneBlob(
            alignment: const Alignment(-0.6, -0.2),
            color: Colors.greenAccent.withOpacity(0.35),
            size: 180,
          ),
          _buildZoneBlob(
            alignment: const Alignment(0.4, -0.4),
            color: Colors.orangeAccent.withOpacity(0.35),
            size: 150,
          ),
          _buildZoneBlob(
            alignment: const Alignment(0.0, 0.6),
            color: Colors.redAccent.withOpacity(0.35),
            size: 140,
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Community Safety Map",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneBlob({
    required Alignment alignment,
    required Color color,
    required double size,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCountChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        "Reports: $_reportCount",
        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStateCard({
    required Color color,
    required IconData icon,
    required String score,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardSoft,
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 13,
                  ),
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
