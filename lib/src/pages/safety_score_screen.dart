import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:usafe_front_end/core/services/api_service.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'safety_map_screen.dart';

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
  Map<String, dynamic> _factors = {};
  double? _latitude;
  double? _longitude;
  bool _isLoading = true;
  String _errorMessage = '';

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
        throw Exception('Location services are disabled.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
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
          if (response['tips'] != null) {
            final rawTips = response['tips'] as List<dynamic>;
            _tips = rawTips.map((e) => e.toString()).toList();
          }
          _factors =
              (response['factors'] as Map?)?.cast<String, dynamic>() ?? {};
          _latitude = latitude;
          _longitude = longitude;
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
      case 'Risk':
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
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Score Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(),
                              _getStatusColor().withOpacity(0.8)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor().withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 20,
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
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield_rounded,
                                  color: Colors.white, size: 48),
                            ),
                            const SizedBox(height: 24),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${_safetyScore ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 72,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
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
                              _status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
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
                                      builder: (context) => SafetyMapScreen(
                                        factors: _factors,
                                        latitude: _latitude,
                                        longitude: _longitude,
                                      ),
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
                                label: const Icon(Icons.arrow_forward_rounded,
                                    size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (_tips.isNotEmpty) ...[
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
                        ..._tips.map((tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: _buildTipCard(tip),
                            )),
                      ] else ...[
                        const Text(
                          'OTHER AREA CONDITIONS',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStateCard(
                          score: '62/100',
                          status: 'Proceed with Caution',
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFFF59E0B), // Amber-500
                          bgColor: AppColors.surface,
                        ),
                        const SizedBox(height: 16),
                        _buildStateCard(
                          score: '28/100',
                          status: 'High Risk Area',
                          icon: Icons.cancel_outlined,
                          iconColor: AppColors.alert,
                          bgColor: AppColors.surface,
                        ),
                      ],
                      const SizedBox(
                          height: 120), // Bottom padding for floating nav
                    ],
                  ),
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

  Widget _buildFactorGrid() {
    final time = (_factors['time'] as Map?)?.cast<String, dynamic>() ?? {};
    final location =
        (_factors['location'] as Map?)?.cast<String, dynamic>() ?? {};
    final environment =
        (_factors['environment'] as Map?)?.cast<String, dynamic>() ?? {};

    final policeKm = _formatDistance(location['closestPoliceKm']);
    final hospitalKm = _formatDistance(location['closestHospitalKm']);
    final trafficLevel = (environment['trafficLevel'] ?? 'unknown').toString();
    final populationDensity =
        (environment['populationDensity'] ?? 'unknown').toString();
    final trafficSource =
        (environment['trafficSource'] ?? 'time-estimate').toString();
    final populationSource =
        (environment['populationSource'] ?? 'places-density-estimate')
            .toString();
    final trafficFallback = environment['trafficFallback'] == true;
    final populationFallback = environment['populationFallback'] == true;
    final hour24 = time['hour24']?.toString() ?? '--';
    final graveyard = (time['isGraveyardShift'] == true) ? 'Yes' : 'No';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildFactorCard(
                    'Closest Police', policeKm, Icons.local_police_rounded)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildFactorCard('Closest Hospital', hospitalKm,
                    Icons.local_hospital_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildFactorCard(
                    'Traffic', trafficLevel, Icons.traffic_rounded)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildFactorCard(
                    'Population', populationDensity, Icons.groups_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildFactorCard(
                    'Hour (24h)', hour24, Icons.schedule_rounded)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildFactorCard(
                    'Graveyard Shift', graveyard, Icons.nightlight_round)),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSourceBadge(
                label: 'Traffic',
                source: trafficSource,
                isFallback: trafficFallback,
              ),
              _buildSourceBadge(
                label: 'Population',
                source: populationSource,
                isFallback: populationFallback,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSourceBadge({
    required String label,
    required String source,
    required bool isFallback,
  }) {
    final bgColor = isFallback
        ? const Color(0xFFF59E0B).withOpacity(0.12)
        : const Color(0xFF00E676).withOpacity(0.12);
    final borderColor = isFallback
        ? const Color(0xFFF59E0B).withOpacity(0.35)
        : const Color(0xFF00E676).withOpacity(0.35);
    final textColor =
        isFallback ? const Color(0xFFB45309) : const Color(0xFF047857);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        '$label: ${isFallback ? 'Fallback' : 'Live'} ($source)',
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFactorCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(dynamic kmValue) {
    if (kmValue == null) return 'Not available';
    final parsed = (kmValue as num).toDouble();
    return '${parsed.toStringAsFixed(2)} km';
  }

  Widget _buildStateCard({
    required String score,
    required String status,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textDisabled, size: 28),
        ],
      ),
    );
  }
}
