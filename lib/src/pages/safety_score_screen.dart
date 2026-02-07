import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/src/services/live_safety_score_service.dart';
import 'safety_map_screen.dart';

class SafetyScoreScreen extends StatefulWidget {
  final int initialScore;
  final bool showBottomNav;

  const SafetyScoreScreen({
    super.key,
    this.initialScore = 85,
    this.showBottomNav = true,
  });

  @override
  State<SafetyScoreScreen> createState() => _SafetyScoreScreenState();
}

class _SafetyScoreScreenState extends State<SafetyScoreScreen> {
  final SafetyScoreInputsProvider _scoreProvider = SafetyScoreInputsProvider();
  LiveSafetyScoreResult? _liveScoreResult;
  bool _scoreLoading = false;
  String? _scoreError;
  SafetyPosition? _currentPosition;
  Timer? _scoreTimer;

  @override
  void initState() {
    super.initState();
    _initLiveScore();
  }

  void _initLiveScore() {
    _updateLiveScore();
    _scoreTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _updateLiveScore();
    });
  }

  Future<void> _updateLiveScore() async {
    if (_scoreLoading) return;
    setState(() {
      _scoreLoading = true;
      _scoreError = null;
    });
    final position = await _getScorePosition();
    if (!mounted) return;
    final fetchResult = await _scoreProvider.getScoreAt(position: position);
    if (!mounted) return;
    setState(() {
      _scoreLoading = false;
      if (fetchResult.result != null) {
        _liveScoreResult = fetchResult.result;
        _scoreError = null;
      } else {
        _scoreError = fetchResult.error ?? 'Unable to update score';
      }
    });
  }

  Future<SafetyPosition> _getScorePosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return _currentPosition ?? const SafetyPosition(6.9271, 79.8612);
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final safetyPosition = SafetyPosition(pos.latitude, pos.longitude);
      _currentPosition = safetyPosition;
      return safetyPosition;
    } catch (_) {
      return _currentPosition ?? const SafetyPosition(6.9271, 79.8612);
    }
  }

  @override
  void dispose() {
    _scoreTimer?.cancel();
    super.dispose();
  }

  Color _zoneColor(SafetyZone? zone, Color fallback) {
    switch (zone) {
      case SafetyZone.safe:
        return AppColors.successGreen;
      case SafetyZone.caution:
        return Colors.orange;
      case SafetyZone.danger:
        return AppColors.alertRed;
      default:
        return fallback;
    }
  }

  String _statusLine(SafetyZone? zone) {
    switch (zone) {
      case SafetyZone.safe:
        return 'You are in a safe area';
      case SafetyZone.caution:
        return 'Proceed with caution';
      case SafetyZone.danger:
        return 'High risk area';
      default:
        return 'Calculating live safety score...';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define your local colors or fetch them from your theme/constants
    final Color bgDark = AppColors.background; // Ensure this is defined in your AppColors
    final Color cardBlue = const Color(0xFF2962FF);
    final Color cardYellowBg = const Color(0xFF2C2514);
    final Color cardRedBg = const Color(0xFF2C1515);
    final Color textWhite = Colors.white;

    final int displayScore = _liveScoreResult?.score ?? widget.initialScore;
    final zone = _liveScoreResult?.zone;
    final cardColor = _zoneColor(zone, cardBlue);

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
                color: cardColor,
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
                          text: '$displayScore',
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const TextSpan(
                          text: '/92',
                          style: TextStyle(fontSize: 24, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusLine(zone),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  if (_scoreLoading) ...[
                    const SizedBox(height: 8),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (_scoreError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _scoreError!,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
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
              score: '62/92',
              status: 'Proceed with Caution',
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.white,
              circleColor: Colors.orange,
              bgColor: cardYellowBg,
            ),
            const SizedBox(height: 12),
            _buildStateCard(
              score: '28/92',
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
          widget.showBottomNav ? _buildBottomNavBar(bgDark, cardBlue) : null,
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
          _navIcon(Icons.map, true, activeColor: activeColor), // Active tab
          _navIcon(Icons.people, false),
          _navIcon(Icons.person, false),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, bool isActive, {Color? activeColor}) {
    return InkWell(
      onTap: () {
        // Add navigation logic here if needed for bottom bar taps
      },
      child: Column(
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
      ),
    );
  }
}