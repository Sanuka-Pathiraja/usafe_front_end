import 'dart:async';
import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/core/services/api_service.dart';
import 'safety_map_screen.dart';

class SafetyScoreScreen extends StatefulWidget {
  final bool showBottomNav;

  const SafetyScoreScreen({
    super.key,
    this.showBottomNav = true,
  });

  @override
  State<SafetyScoreScreen> createState() => _SafetyScoreScreenState();
}

class _SafetyScoreScreenState extends State<SafetyScoreScreen> {
  bool _isLoading = true;
  int _safetyScore = 0;
  String _status = 'Standard';
  List<String> _tips = [];
  String _errorMessage = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchLiveScore();
    // Auto-refresh every 2 minutes as requested
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _fetchLiveScore();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveScore() async {
    try {
      final data = await ApiService.getLiveSafetyScore("mock-testing-token");
      if (mounted) {
        setState(() {
          _safetyScore = data['score'];
          _status = data['status'] ?? 'Caution';
          _tips = List<String>.from(data['tips'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Unable to fetch live score. Please check your connection.";
          _isLoading = false;
        });
      }
    }
  }

  Color get _scoreColor {
    if (_safetyScore >= 80) return const Color(0xFF10B981); // Emerald Green
    if (_safetyScore >= 50) return const Color(0xFFF59E0B); // Amber/Yellow
    return const Color(0xFFEF4444); // Red
  }

  String get _scoreStatusText {
    return _status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Safety Score',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchLiveScore();
            },
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage.isNotEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.alert, fontSize: 16)),
                ))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Score Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: _scoreColor.withOpacity(0.5),
                              spreadRadius: 4,
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _scoreColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.shield_rounded, color: _scoreColor, size: 48),
                            ),
                            const SizedBox(height: 24),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$_safetyScore',
                                    style: TextStyle(
                                      fontSize: 72,
                                      fontWeight: FontWeight.w900,
                                      color: _scoreColor,
                                      letterSpacing: -2,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '/100',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _scoreStatusText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 56, // Accessible touch target
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SafetyMapScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primaryDark,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: const Text(
                                  'View Map Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                label: const Icon(Icons.arrow_forward_rounded, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      const Text(
                        'ACTIONABLE TIPS',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_tips.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('You are doing great! No immediate action needed.', style: TextStyle(color: AppColors.textDisabled, fontSize: 16)),
                          ),
                        )
                      else  
                        ..._tips.map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildTipCard(tip),
                        )),
                      const SizedBox(height: 120), // Bottom padding for floating nav
                    ],
                  ),
                ),
    );
  }

  Widget _buildTipCard(String tip) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}