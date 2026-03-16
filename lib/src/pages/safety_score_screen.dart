import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usafe_front_end/core/services/api_service.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'safety_map_screen.dart';
import 'safepath_scheduler_screen.dart';

class SafetyScoreScreen extends StatefulWidget {
  final bool showBottomNav;
  final VoidCallback? onBackHome;

  const SafetyScoreScreen({
    super.key,
    this.showBottomNav = true,
    this.onBackHome,
  });

  @override
  State<SafetyScoreScreen> createState() => _SafetyScoreScreenState();
}

class _SafetyScoreScreenState extends State<SafetyScoreScreen> {
  int? _safetyScore;
  String _status = 'Calculating...';
  List<String> _tips = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _fullResponse = {};

  @override
  void initState() {
    super.initState();
    _fetchSafetyData();
  }

  Future<void> _fetchSafetyData() async {
    try {
      final battery = Battery();
      final batteryLevel = await battery.batteryLevel;

      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _setShareLocationPref(false);
        throw Exception('Location services are disabled.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await _setShareLocationPref(false);
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await _setShareLocationPref(false);
        throw Exception('Location permissions are permanently denied.');
      }

      final position =
          await _getSafePosition() ?? await Geolocator.getLastKnownPosition();
      final latitude = position?.latitude ?? 37.7749;
      final longitude = position?.longitude ?? -122.4194;
      final jwt = await AuthService.getToken();

      final response = await ApiService.fetchSafetyScore(
        latitude: latitude,
        longitude: longitude,
        batteryLevel: batteryLevel,
        jwt: jwt.isNotEmpty ? jwt : null,
      );

      if (mounted) {
        setState(() {
          _safetyScore = (response['score'] as num?)?.toInt();
          _status = response['status']?.toString() ?? 'Unknown';
          _fullResponse = response;
          if (response['tips'] != null) {
            final rawTips = response['tips'] as List<dynamic>;
            _tips = rawTips.map((e) => e.toString()).toList();
          }
          _isLoading = false;
        });
      }
    } catch (e, stacktrace) {
      if (mounted) {
        setState(() {
          _errorMessage = '${e.toString()}\n\n$stacktrace';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setShareLocationPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("share_location", value);
  }

  Future<Position?> _getSafePosition() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Avoid known emulator GNSS/NMEA crash path from live updates.
        return Geolocator.getLastKnownPosition();
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return null;
    }
  }

  Color _getStatusColor() {
    switch (_status) {
      case 'Safe':
        return const Color(0xFF00E676);
      case 'Caution':
        return Colors.orange;
      case 'High Risk':
        return AppColors.alert;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (widget.onBackHome != null) {
              widget.onBackHome!();
              return;
            }
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'My Safety Score',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Analyzing area and telemetry...',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.alert, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = '';
                            });
                            _fetchSafetyData();
                          },
                          child: const Text('Retry'),
                        )
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Compact Score Card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(),
                              _getStatusColor().withOpacity(0.8)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor().withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Score number on the left
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${_safetyScore ?? 0}',
                                          style: const TextStyle(
                                            fontSize: 56,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -2,
                                            height: 1.0,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '/100',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                Colors.white.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    onPressed: () =>
                                        _showDetailsBottomSheet(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                          color: Colors.white.withOpacity(0.4)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _status,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.expand_more_rounded,
                                            size: 18),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Shield icon on the right
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield_rounded,
                                  color: Colors.white, size: 36),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Section heading ──
                      Text(
                        _tips.isNotEmpty ? 'ACTIONABLE TIPS' : 'QUICK ACTIONS',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Scrollable content area ──
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 100),
                          children: [
                            if (_tips.isNotEmpty)
                              ..._tips.map((tip) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10.0),
                                    child: _buildTipCard(tip),
                                  ))
                            else ...[
                              _buildQuickActionCard(
                                title: 'SafePath Navigation',
                                subtitle: 'View safe routes on the map',
                                icon: Icons.map_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SafetyMapScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildQuickActionCard(
                                title: 'Community Report',
                                subtitle: 'Report a safety concern',
                                icon: Icons.campaign_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SafetyMapScreen(
                                            selectLocationForReport: true,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildQuickActionCard(
                                title: 'SafePath Scheduler',
                                subtitle: 'Schedule a guardian for your route',
                                icon: Icons.schedule_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SafePathSchedulerScreen(
                                        onBack: () => Navigator.pop(context),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  void _showDetailsBottomSheet(BuildContext context) {
    // Extract available variables from the full API response.
    final String status =
        _fullResponse['status']?.toString() ?? 'Data unavailable';
    final String timeOfDay = _fullResponse['timeOfDay']?.toString() ??
        _fullResponse['time_of_day']?.toString() ??
        _fullResponse['localTime']?.toString() ??
        'Data unavailable';
    final String batteryLevel = _fullResponse['batteryLevel']?.toString() ??
        _fullResponse['battery_level']?.toString() ??
        'Data unavailable';

    // Nearby services
    final nearestPolice = _fullResponse['nearestPoliceStation'] ??
        _fullResponse['nearest_police_station'] ??
        _fullResponse['closestPoliceStation'];
    final nearestHospital = _fullResponse['nearestHospital'] ??
        _fullResponse['nearest_hospital'] ??
        _fullResponse['closestHospital'];

    String policeName = 'Data unavailable';
    String policeDistance = '';
    if (nearestPolice is Map) {
      policeName = nearestPolice['name']?.toString() ?? 'Unknown Station';
      policeDistance = nearestPolice['distance']?.toString() ?? '';
    } else if (nearestPolice is String) {
      policeName = nearestPolice;
    }

    String hospitalName = 'Data unavailable';
    String hospitalDistance = '';
    if (nearestHospital is Map) {
      hospitalName = nearestHospital['name']?.toString() ?? 'Unknown Hospital';
      hospitalDistance = nearestHospital['distance']?.toString() ?? '';
    } else if (nearestHospital is String) {
      hospitalName = nearestHospital;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Score Breakdown',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                _detailRow(Icons.verified_rounded, 'Status', status),
                _detailRow(Icons.access_time_rounded, 'Time of Day', timeOfDay),
                _detailRow(
                    Icons.battery_charging_full_rounded,
                    'Battery Level',
                    batteryLevel == 'Data unavailable'
                        ? batteryLevel
                        : '$batteryLevel%'),
                _detailRow(
                  Icons.local_police_rounded,
                  'Nearest Police',
                  policeDistance.isNotEmpty
                      ? '$policeName ($policeDistance away)'
                      : policeName,
                ),
                _detailRow(
                  Icons.local_hospital_rounded,
                  'Nearest Hospital',
                  hospitalDistance.isNotEmpty
                      ? '$hospitalName ($hospitalDistance away)'
                      : hospitalName,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String tip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates,
              color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.25),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.35),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 28),
          ],
        ),
      ),
    );
  }
}
