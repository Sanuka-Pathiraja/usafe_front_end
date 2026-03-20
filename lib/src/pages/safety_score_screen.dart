import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usafe_front_end/core/services/api_service.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/auth/screens/login_screen.dart';
import 'community_reports_portal_screen.dart';
import 'safepath_scheduler_screen.dart';
import 'safe_route_navigation_screen.dart'; // ← NEW import
import 'score_detail_page.dart';

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
  bool _isRefreshing = false;
  bool _requiresLogin = false;
  String _errorMessage = '';
  Map<String, dynamic> _fullResponse = {};
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchSafetyData();
    _startLiveRefresh();
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  void _startLiveRefresh() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isRefreshing) return;
      _fetchSafetyData(showLoader: false);
    });
  }

  Future<void> _fetchSafetyData({bool showLoader = true}) async {
    if (_isRefreshing) return;
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _requiresLogin = false;
      });
    }

    _isRefreshing = true;
    try {
      final token = await AuthService.getToken();
      if (token.isEmpty) {
        throw Exception('Session expired. Please re-login.');
      }

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
      final response = await ApiService.fetchSafetyScore(
        latitude: latitude,
        longitude: longitude,
        batteryLevel: batteryLevel,
        isLocationEnabled: serviceEnabled && position != null,
        jwt: token,
      );

      if (mounted) {
        setState(() {
          _safetyScore = (response['score'] is num)
              ? (response['score'] as num).toInt()
              : int.tryParse(response['score']?.toString() ?? '');
          _status = response['status']?.toString() ?? 'Unknown';
          _fullResponse = response;
          if (response['tips'] != null) {
            final rawTips = response['tips'] as List<dynamic>;
            _tips = rawTips.map((e) => e.toString()).toList();
          }
          _isLoading = false;
          _errorMessage = '';
          _requiresLogin = false;
        });
      }
    } catch (e) {
      final isAuthError = _isAuthError(e);
      if (isAuthError) {
        _liveRefreshTimer?.cancel();
      }
      if (mounted) {
        setState(() {
          _errorMessage =
              isAuthError ? 'Session expired. Please re-login.' : e.toString();
          _isLoading = false;
          _requiresLogin = isAuthError;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  bool _isAuthError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('401') ||
        message.contains('unauthorized') ||
        message.contains('no token provided') ||
        message.contains('re-login');
  }

  Future<void> _goToLogin() async {
    _liveRefreshTimer?.cancel();
    await AuthService.logout();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
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
    switch (_status.toLowerCase()) {
      case 'safe':
      case 'success':
        return const Color(0xFF00E676);
      case 'caution':
      case 'moderate':
        return Colors.orange;
      case 'high risk':
      case 'danger':
        return AppColors.alert;
      default:
        return AppColors.primary;
    }
  }

  Map<String, dynamic> _nestedMap(String key) {
    final nested = _fullResponse[key];
    if (nested is Map<String, dynamic>) return nested;
    return const {};
  }

  dynamic _lookupValue(List<String> keys) {
    for (final key in keys) {
      if (_fullResponse.containsKey(key)) {
        return _fullResponse[key];
      }
    }

    final details = _nestedMap('details');
    for (final key in keys) {
      if (details.containsKey(key)) {
        return details[key];
      }
    }

    final factors = _nestedMap('factors');
    for (final key in keys) {
      if (factors.containsKey(key)) {
        return factors[key];
      }
    }

    return null;
  }

  double? _lookupDouble(List<String> keys) {
    final value = _lookupValue(keys);
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? _lookupString(List<String> keys) {
    final value = _lookupValue(keys);
    if (value == null) return null;
    return value.toString();
  }

  double? get _closestHospitalKm => _lookupDouble([
        'closestHospitalKm',
        'closest_hospital_km',
        'hospitalKm',
        'hospital_km',
        'nearestHospitalKm',
        'nearest_hospital_km',
        'hospitalDistanceKm',
        'hospital_distance_km',
      ]);

  double? get _closestPoliceKm => _lookupDouble([
        'closestPoliceStationKm',
        'closest_police_station_km',
        'policeStationKm',
        'police_station_km',
        'nearestPoliceStationKm',
        'nearest_police_station_km',
        'policeDistanceKm',
        'police_distance_km',
      ]);

  String get _timeOfDayLabel {
    final backendValue = _lookupString([
      'timeOfDay',
      'time_of_day',
      'dayPeriod',
      'day_period',
    ]);
    if (backendValue != null && backendValue.trim().isNotEmpty) {
      return backendValue;
    }

    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 21) return 'Evening';
    return 'Night';
  }

  double? get _populationDensity => _lookupDouble([
        'populationDensityPerKm2',
        'population_density_per_km2',
        'populationDensity',
        'population_density',
        'populationPerKm2',
        'population_per_km2',
      ]);

  String? get _trafficLevel => _lookupString([
        'trafficLevel',
        'traffic_level',
        'traffic',
      ]);

  String _formatDistance(double? km) {
    if (km == null) return 'N/A';
    return '${km.toStringAsFixed(1)} km';
  }

  String get _populationLabel {
    final density = _populationDensity;
    if (density == null) return 'N/A';
    return '${density.toStringAsFixed(0)}/km2';
  }

  String get _trafficLabel {
    final traffic = _trafficLevel;
    if (traffic == null || traffic.trim().isEmpty) return 'N/A';
    return traffic;
  }

  Color _distanceColor(double? km) {
    if (km == null) return AppColors.textSecondary;
    if (km <= 2.5) return AppColors.success;
    if (km <= 8.0) return Colors.orange;
    return AppColors.alert;
  }

  Color get _timeOfDayColor {
    final normalized = _timeOfDayLabel.toLowerCase();
    if (normalized.contains('night')) return AppColors.alert;
    if (normalized.contains('evening')) return Colors.orange;
    return AppColors.success;
  }

  Color get _populationColor {
    final density = _populationDensity;
    if (density == null) return AppColors.textSecondary;
    if (density <= 2500) return AppColors.success;
    if (density <= 6000) return Colors.orange;
    return AppColors.alert;
  }

  Color get _trafficColor {
    final traffic = _trafficLevel?.toLowerCase() ?? '';
    if (traffic.isEmpty) return AppColors.textSecondary;
    if (traffic.contains('low') || traffic.contains('light')) {
      return AppColors.success;
    }
    if (traffic.contains('moderate') || traffic.contains('medium')) {
      return Colors.orange;
    }
    if (traffic.contains('high') || traffic.contains('heavy')) {
      return AppColors.alert;
    }
    return AppColors.primary;
  }

  double _distanceProgress(double? km) {
    if (km == null) return 0;
    final progress = 1 - (km / 12);
    return progress.clamp(0.0, 1.0);
  }

  double get _timeOfDayProgress {
    final normalized = _timeOfDayLabel.toLowerCase();
    if (normalized.contains('night')) return 0.35;
    if (normalized.contains('evening')) return 0.6;
    return 0.88;
  }

  double get _populationProgress {
    final density = _populationDensity;
    if (density == null) return 0;
    if (density <= 2500) return 0.9;
    if (density <= 6000) return 0.62;
    return 0.35;
  }

  double get _trafficProgress {
    final traffic = _trafficLevel?.toLowerCase() ?? '';
    if (traffic.contains('low') || traffic.contains('light')) return 0.9;
    if (traffic.contains('moderate') || traffic.contains('medium')) return 0.58;
    if (traffic.contains('high') || traffic.contains('heavy')) return 0.3;
    final numeric = double.tryParse(_trafficLevel ?? '');
    if (numeric != null) {
      return (1 - (numeric / 100)).clamp(0.0, 1.0);
    }
    return 0;
  }

  // ── Navigation handlers ───────────────────────────────────────────────────

  void _navigateToCommunityReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CommunityReportsPortalScreen(),
      ),
    );
  }

  /// Tapping "Safepath Navigation" now opens SafeRouteNavigationScreen.
  void _navigateToSafePathNavigation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SafeRouteNavigationScreen(),
      ),
    );
  }

  void _navigateToSafetyScoreDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScoreDetailPage(
          categoryKey: 'safety_score',
          categoryTitle: 'Safety Score Parameters',
          icon: Icons.shield_rounded,
          status: _status,
          statusColor: _getStatusColor(),
          parameters: [
            ScoreParameter(
              label: 'Live Safety Score',
              value: '${_safetyScore ?? 0}',
              progress: ((_safetyScore ?? 0) / 100).clamp(0.0, 1.0).toDouble(),
              color: _getStatusColor(),
              description: 'Current overall safety score from backend',
            ),
            ScoreParameter(
              label: 'Closest Hospital',
              value: _formatDistance(_closestHospitalKm),
              progress: _distanceProgress(_closestHospitalKm),
              color: _distanceColor(_closestHospitalKm),
              description: 'Distance to nearest hospital',
            ),
            ScoreParameter(
              label: 'Closest Police Station',
              value: _formatDistance(_closestPoliceKm),
              progress: _distanceProgress(_closestPoliceKm),
              color: _distanceColor(_closestPoliceKm),
              description: 'Distance to nearest police station',
            ),
            ScoreParameter(
              label: 'Time of Day',
              value: _timeOfDayLabel,
              progress: _timeOfDayProgress,
              color: _timeOfDayColor,
              description: 'Current day period used by risk model',
            ),
            ScoreParameter(
              label: 'Population Density',
              value: _populationLabel,
              progress: _populationProgress,
              color: _populationColor,
              description: 'People per square kilometer in your area',
            ),
            ScoreParameter(
              label: 'Traffic Level',
              value: _trafficLabel,
              progress: _trafficProgress,
              color: _trafficColor,
              description: 'Current traffic congestion status',
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSafePathGuardian() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SafePathSchedulerScreen(),
      ),
    );
  }

  // ── Shared card widget ────────────────────────────────────────────────────

  Widget _buildScoreBar({
    required String title,
    required IconData icon,
    required String summary,
    required Color summaryColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.15),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: summaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ── AppBar with Back to Home button ──────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
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
          'Safety Score',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      // ─────────────────────────────────────────────────────────────────────
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
                        const SizedBox(height: 24),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            if (_requiresLogin) {
                              _goToLogin();
                              return;
                            }
                            _fetchSafetyData();
                          },
                          child: Text(_requiresLogin ? 'Re-Login' : 'Retry'),
                        )
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──
                      const SizedBox(height: 4),
                      const Text(
                        'Your current safety overview',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Live updates every 30 seconds',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Central Score Card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 40, horizontal: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.2),
                              AppColors.primary.withOpacity(0.05),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                color: AppColors.primary,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '${_safetyScore ?? 0}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 68,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                letterSpacing: -2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Status badge → Safety Score Details
                            GestureDetector(
                              onTap: _navigateToSafetyScoreDetails,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor().withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getStatusColor().withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  _status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── Breakdown Section ──
                      const Text(
                        'Breakdown',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Community Reports
                      _buildScoreBar(
                        title: 'Community Reports',
                        icon: Icons.forum_rounded,
                        summary: 'View live community updates',
                        summaryColor: AppColors.primary,
                        onTap: _navigateToCommunityReports,
                      ),
                      const SizedBox(height: 12),

                      // 2. Safepath Navigation → SafeRouteNavigationScreen
                      _buildScoreBar(
                        title: 'Safepath Navigation',
                        icon: Icons.navigation_rounded,
                        summary: _formatDistance(_closestHospitalKm),
                        summaryColor: _distanceColor(_closestHospitalKm),
                        onTap: _navigateToSafePathNavigation,
                      ),
                      const SizedBox(height: 12),

                      // 3. Safepath Guardian
                      _buildScoreBar(
                        title: 'Safepath Guardian',
                        icon: Icons.shield_rounded,
                        summary: _timeOfDayLabel,
                        summaryColor: _timeOfDayColor,
                        onTap: _navigateToSafePathGuardian,
                      ),

                      // ── Quick Actions hint (shown when no tips) ──
                      if (_tips.isEmpty) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SafePathSchedulerScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SafePath Scheduler',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Schedule a trip with contacts',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
