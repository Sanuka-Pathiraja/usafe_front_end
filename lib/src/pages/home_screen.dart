import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../features/auth/auth_service.dart';
import '../../features/auth/screens/login_screen.dart';
import 'contacts_screen.dart';
import 'emergency_process_screen.dart';
import 'package:usafe_front_end/src/pages/profile_screen.dart'; // Adjust path
import 'score_detail_page.dart';
import 'safety_score_gate_screen.dart';
import 'safety_score_screen.dart';
import 'safepath_scheduler_screen.dart';
import 'package:showcaseview/showcaseview.dart';
import 'settings_screen.dart'; // ← SettingsPage lives here

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool startContactsTour;

  const HomeScreen({
    super.key,
    this.initialTabIndex = 0,
    this.startContactsTour = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  final Set<int> _loadedTabs = {0};
  final GlobalKey<ContactsScreenState> _contactsKey =
      GlobalKey<ContactsScreenState>();
  final GlobalKey _addContactFabKey = GlobalKey();
  final GlobalKey _contactsInfoKey = GlobalKey();
  final GlobalKey _silentCallFabKey = GlobalKey();
  int _contactCount = -1; // -1 = unknown/loading

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialTabIndex;
    _loadedTabs.add(_currentIndex);
    _loadContactCount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadContactCount();
    }
  }

  Future<void> _loadContactCount() async {
    try {
      final contacts = await AuthService.fetchContacts();
      if (mounted) setState(() => _contactCount = contacts.length);
    } catch (_) {
      try {
        final cached = await AuthService.loadTrustedContacts();
        if (mounted) setState(() => _contactCount = cached.length);
      } catch (_) {}
    }
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
    });
    if (index == 2) {
      _loadContactCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      SOSDashboard(contactCount: _contactCount),
      SafetyScoreGateScreen(
        showBottomNav: false,
        onBackHome: () => _switchTab(0),
      ),
      ContactsScreen(
        key: _contactsKey,
        infoKey: _contactsInfoKey,
        silentCallKey: _silentCallFabKey,
        onBackHome: () => _switchTab(0),
      ),
      ProfileScreen(
        onBackHome: () => _switchTab(0),
        onOpenContacts: () => _switchTab(2),
      ),
    ];

    return ShowCaseWidget(
      builder: (context) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: List.generate(
                  pages.length,
                  (index) => _loadedTabs.contains(index)
                      ? pages[index]
                      : const SizedBox.shrink(),
                ),
              ),
              Positioned(
                bottom: 32,
                left: 24,
                right: 24,
                child: _buildBottomNavBar(),
              ),
              // Persistent warning chip — shown on all tabs except contacts (which has its own banner)
              if (_contactCount >= 0 && _contactCount < 3 && _currentIndex != 2)
                Positioned(
                  bottom: 32 + 76 + 12,
                  left: 24,
                  right: 24,
                  child: GestureDetector(
                    onTap: () => _switchTab(2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.alert.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.alert.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.alert, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _contactCount == 0
                                  ? 'Add 3 contacts to enable SOS — Tap to set up'
                                  : 'Add ${3 - _contactCount} more contact${3 - _contactCount > 1 ? 's' : ''} to enable SOS',
                              style: const TextStyle(
                                color: AppColors.alert,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              color: AppColors.alert, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_currentIndex == 2)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32 + 76 + 16,
                  child: Center(
                    child: Showcase(
                      key: _addContactFabKey,
                      description:
                          'Tap here to add trusted contacts for SOS alerts.',
                      child: FloatingActionButton.extended(
                        backgroundColor: AppColors.primary,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        onPressed: () =>
                            _contactsKey.currentState?.openAddContact(),
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: const Text('Add Contact',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(Icons.shield_rounded, 'SOS', 0),
          _navItem(Icons.map_rounded, 'Score', 1),
          _navItem(Icons.people_alt_rounded, 'Contacts', 2),
          _navItem(Icons.person_rounded, 'Profile', 3),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _navItem(IconData icon, String label, int index) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SOS DASHBOARD  (settings button → SettingsPage)
// ─────────────────────────────────────────────
class SOSDashboard extends StatefulWidget {
  final int contactCount;
  const SOSDashboard({super.key, this.contactCount = -1});

  @override
  State<SOSDashboard> createState() => _SOSDashboardState();
}

class _SOSDashboardState extends State<SOSDashboard>
    with TickerProviderStateMixin {
  static const Duration _safetyRefreshInterval = Duration(seconds: 30);
  bool isSOSActive = false;
  bool _openingEmergencyProcess = false;
  String? _emergencySessionId;
  Timer? _statusPollTimer;
  Timer? _safetyRefreshTimer;
  bool _sessionAnswered = false;
  Map<String, dynamic>? _latestSessionStatus;
  Map<String, dynamic>? _emergencyContextPayload;
  int? _safetyScore;
  String _safetyStatus = 'Checking';
  Map<String, dynamic> _safetyResponse = const {};
  bool _isFetchingSafety = false;

  static const Duration _sosDuration = Duration(minutes: 3);
  static const Duration _statusPollInterval = Duration(seconds: 3);
  Timer? _sosTimer;
  Duration _remaining = _sosDuration;

  @override
  void initState() {
    super.initState();
    _fetchSafetySnapshot();
    _startSafetyRefresh();
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    _statusPollTimer?.cancel();
    _safetyRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: AppColors.background,
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // ── SOS Button: True center of screen ──
            Center(
              child: isSOSActive ? _buildSOSActiveView() : _buildHoldButton(),
            ),
            // ── Top Bar: SAFE pill + Settings gear ──
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildStatusPill(),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: AppColors.textSecondary, size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    final statusColor = _getSafetyStatusColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openSafetyDetails,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _safetyStatusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startSafetyRefresh() {
    _safetyRefreshTimer?.cancel();
    _safetyRefreshTimer = Timer.periodic(_safetyRefreshInterval, (_) {
      if (!mounted || _isFetchingSafety) return;
      _fetchSafetySnapshot();
    });
  }

  Future<void> _fetchSafetySnapshot() async {
    if (_isFetchingSafety) return;
    _isFetchingSafety = true;
    try {
      final token = await AuthService.getToken();
      if (token.isEmpty) {
        throw Exception('No session');
      }

      final batteryLevel = await Battery().batteryLevel;
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location disabled');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location denied');
      }

      final position =
          await _getSafePosition() ?? await Geolocator.getLastKnownPosition();
      if (position == null) {
        throw Exception('Location unavailable');
      }

      final response = await ApiService.fetchSafetyScore(
        latitude: position.latitude,
        longitude: position.longitude,
        batteryLevel: batteryLevel,
        isLocationEnabled: true,
        jwt: token,
      );

      final parsedScore = (response['score'] is num)
          ? (response['score'] as num).toInt()
          : int.tryParse(response['score']?.toString() ?? '');

      if (!mounted) return;
      setState(() {
        _safetyScore = parsedScore;
        _safetyStatus = response['status']?.toString() ?? 'Unknown';
        _safetyResponse = response;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _safetyStatus = _fallbackSafetyStatus();
      });
    } finally {
      _isFetchingSafety = false;
    }
  }

  Future<Position?> _getSafePosition() async {
    try {
      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return null;
    }
  }

  String get _safetyStatusLabel {
    final raw = _safetyStatus.trim();
    if (raw.isEmpty || raw.toLowerCase() == 'unknown') {
      return _fallbackSafetyStatus();
    }
    return raw.toUpperCase();
  }

  String _fallbackSafetyStatus() {
    final score = _safetyScore;
    if (score == null) return 'CHECKING';
    if (score >= 80) return 'SAFE';
    if (score >= 60) return 'CAUTION';
    return 'DANGER';
  }

  Color _getSafetyStatusColor() {
    switch (_safetyStatusLabel.toLowerCase()) {
      case 'safe':
      case 'success':
      case 'good':
        return AppColors.success;
      case 'caution':
      case 'moderate':
        return Colors.orange;
      case 'danger':
      case 'high risk':
        return AppColors.alert;
      default:
        return AppColors.primary;
    }
  }

  Map<String, dynamic> _nestedSafetyMap(String key) {
    final nested = _safetyResponse[key];
    if (nested is Map<String, dynamic>) return nested;
    return const {};
  }

  dynamic _lookupSafetyValue(List<String> keys) {
    for (final key in keys) {
      if (_safetyResponse.containsKey(key)) {
        return _safetyResponse[key];
      }
    }

    final details = _nestedSafetyMap('details');
    for (final key in keys) {
      if (details.containsKey(key)) {
        return details[key];
      }
    }

    final factors = _nestedSafetyMap('factors');
    for (final key in keys) {
      if (factors.containsKey(key)) {
        return factors[key];
      }
    }

    return null;
  }

  double? _lookupSafetyDouble(List<String> keys) {
    final value = _lookupSafetyValue(keys);
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? _lookupSafetyString(List<String> keys) {
    final value = _lookupSafetyValue(keys);
    if (value == null) return null;
    return value.toString();
  }

  double? get _closestHospitalKm => _lookupSafetyDouble([
        'closestHospitalKm',
        'closest_hospital_km',
        'hospitalKm',
        'hospital_km',
        'nearestHospitalKm',
        'nearest_hospital_km',
        'hospitalDistanceKm',
        'hospital_distance_km',
      ]);

  double? get _closestPoliceKm => _lookupSafetyDouble([
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
    final backendValue = _lookupSafetyString([
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

  double? get _populationDensity => _lookupSafetyDouble([
        'populationDensityPerKm2',
        'population_density_per_km2',
        'populationDensity',
        'population_density',
        'populationPerKm2',
        'population_per_km2',
      ]);

  String? get _trafficLevel => _lookupSafetyString([
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

  void _openSafetyDetails() {
    if (_safetyScore == null && _safetyResponse.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SafetyScoreScreen(showBottomNav: false),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScoreDetailPage(
          categoryKey: 'safety_score',
          categoryTitle: 'Safety Score Parameters',
          icon: Icons.shield_rounded,
          status: _safetyStatusLabel,
          statusColor: _getSafetyStatusColor(),
          parameters: [
            ScoreParameter(
              label: 'Live Safety Score',
              value: '${_safetyScore ?? 0}',
              progress: ((_safetyScore ?? 0) / 100).clamp(0.0, 1.0).toDouble(),
              color: _getSafetyStatusColor(),
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

  Widget _buildSafetyTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lightbulb_outline,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                'Safety Tip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Share your live location with trusted contacts before walking alone at night. Stay on well-lit paths.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSHeader() {
    return Column(
      children: [
        const Text(
          'EMERGENCY\nACTIVATED',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.alert,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.alertBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Dispatching alerts...',
            style: TextStyle(
                color: AppColors.alert,
                fontSize: 16,
                fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildHoldButton() {
    final bool sosLocked =
        widget.contactCount >= 0 && widget.contactCount < 3;
    if (sosLocked) {
      return IgnorePointer(
        child: Opacity(
          opacity: 0.35,
          child: SOSHoldInteraction(
            accentColor: AppColors.alert,
            onComplete: () {},
          ),
        ),
      );
    }
    return SOSHoldInteraction(
      accentColor: AppColors.alert,
      onComplete: () {
        setState(() => isSOSActive = true);
        _startSosCountdown();
      },
    );
  }

  Widget _buildSOSActiveView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 300,
              height: 300,
              child: CircularProgressIndicator(
                value: _remaining.inSeconds / _sosDuration.inSeconds,
                strokeWidth: 16,
                backgroundColor: AppColors.surfaceElevated,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.alert),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(_remaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
                const Text(
                  'Auto-dispatch in',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 56),
        _buildActionButton(
          label: 'SEND HELP NOW',
          bg: AppColors.alert,
          text: Colors.white,
          icon: Icons.flash_on_rounded,
          onTap: _openEmergencyProcess,
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          label: 'CANCEL SOS',
          bg: AppColors.surfaceElevated,
          text: Colors.white,
          icon: Icons.close_rounded,
          onTap: () {
            _resetSosCountdown();
            setState(() => isSOSActive = false);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color bg,
    required Color text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // Massive touch targets for high stress
    return SizedBox(
      width: double.infinity,
      height: 68,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: text,
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startSosCountdown() {
    _sosTimer?.cancel();
    _remaining = _sosDuration;
    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (_remaining.inSeconds <= 1) {
        timer.cancel();
        setState(() => _remaining = Duration.zero);
        await _openEmergencyProcess();
        return;
      }
      setState(() => _remaining = Duration(seconds: _remaining.inSeconds - 1));
    });
  }

  void _resetSosCountdown() {
    _sosTimer?.cancel();
    _remaining = _sosDuration;
  }

  Future<void> _openEmergencyProcess() async {
    if (_openingEmergencyProcess) return;
    _openingEmergencyProcess = true;
    _sosTimer?.cancel();
    _emergencySessionId = null;
    _sessionAnswered = false;
    _latestSessionStatus = null;
    _emergencyContextPayload = null;
    _statusPollTimer?.cancel();
    final contactAuthorities = await _isAuthorityCallingEnabled();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyProcessScreen(
          contactAuthoritiesDuringEmergency: contactAuthorities,
          onMessageAllContacts: _onMessageAllContacts,
          onCallContact: _onCallContact,
          onCall119: _onCall119,
          onCancelEmergency: _onCancelEmergency,
        ),
      ),
    );

    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _emergencySessionId = null;
    _sessionAnswered = false;
    _latestSessionStatus = null;
    _emergencyContextPayload = null;
    _openingEmergencyProcess = false;
    if (!mounted) return;
    _resetSosCountdown();
    setState(() => isSOSActive = false);
  }

  String? _extractSessionId(Map<String, dynamic> response) {
    final dynamic id =
        response['sessionId'] ?? response['sessionID'] ?? response['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  Future<void> _startStatusPolling() async {
    _statusPollTimer?.cancel();
    await _pollEmergencyStatus();
    _statusPollTimer = Timer.periodic(_statusPollInterval, (_) {
      _pollEmergencyStatus();
    });
  }

  Future<void> _pollEmergencyStatus() async {
    final sessionId = _emergencySessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    try {
      final response =
          await AuthService.getEmergencyStatus(sessionId: sessionId);
      _latestSessionStatus = response;
      final status = (response['status'] ?? response['finalStatus'] ?? '')
          .toString()
          .toUpperCase();
      if (status == 'ANSWERED' ||
          (response['answeredBy'] != null &&
              response['answeredBy'].toString().isNotEmpty)) {
        _sessionAnswered = true;
      }
      if (status == 'CANCELLED' ||
          status == 'FAILED' ||
          status == 'COMPLETED' ||
          status == 'ANSWERED') {
        _statusPollTimer?.cancel();
      }
    } catch (e) {
      await _handleUnauthorizedError(e);
    }
  }

  Future<EmergencyActionResult> _onMessageAllContacts() async {
    Map<String, dynamic> response;
    try {
      final emergencyPayload = await _getOrCreateEmergencyContextPayload();
      response = await AuthService.startEmergency(
        payload: emergencyPayload,
      );
    } catch (e) {
      if (await _handleUnauthorizedError(e)) {
        return const EmergencyActionResult(
          success: false,
          message: 'Session expired. Please re-login.',
        );
      }
      return EmergencyActionResult(success: false, message: e.toString());
    }

    final sessionId = _extractSessionId(response);
    if (sessionId == null || sessionId.isEmpty) {
      return const EmergencyActionResult(
        success: false,
        message: 'Emergency session id missing in response',
      );
    }

    _emergencySessionId = sessionId;
    await _startStatusPolling();
    final assessment = AuthService.assessEmergencyStartResponse(response);
    return EmergencyActionResult(success: true, message: assessment.message);
  }

  Future<Map<String, dynamic>> _buildEmergencyStartPayload() async {
    final payload = <String, dynamic>{};
    payload['triggeredAt'] = DateTime.now().toIso8601String();
    _debugEmergencyPayload('resolved triggeredAt=${payload['triggeredAt']}');

    final currentUser = await AuthService.getCurrentUser();
    _debugEmergencyPayload('currentUser=$currentUser');
    final userName = _displayNameFromUser(currentUser);
    if (userName.isNotEmpty) {
      payload['userName'] = userName;
      _debugEmergencyPayload('resolved userName=$userName');
    } else {
      _debugEmergencyPayload('userName unavailable');
    }

    final position = await _getEmergencyPosition();
    if (position != null) {
      payload['latitude'] = position.latitude;
      payload['longitude'] = position.longitude;
      _debugEmergencyPayload(
        'resolved coordinates lat=${position.latitude}, lng=${position.longitude}',
      );

      final approximateAddress = await _resolveApproximateAddress(position);
      if (approximateAddress.isNotEmpty) {
        payload['approximateAddress'] = approximateAddress;
        _debugEmergencyPayload(
          'resolved approximateAddress=$approximateAddress',
        );
      } else {
        _debugEmergencyPayload('approximateAddress unavailable');
      }
    } else {
      _debugEmergencyPayload('coordinates unavailable');
    }

    _debugEmergencyPayload('final payload=$payload');
    return payload;
  }

  Future<bool> _isAuthorityCallingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('contact_emergency_authorities') ?? true;
  }

  Future<Map<String, dynamic>> _getOrCreateEmergencyContextPayload() async {
    final cachedPayload = _emergencyContextPayload;
    if (cachedPayload != null && cachedPayload.isNotEmpty) {
      _debugEmergencyPayload('reusing cached emergency payload=$cachedPayload');
      return Map<String, dynamic>.from(cachedPayload);
    }

    final payload = await _buildEmergencyStartPayload();
    _emergencyContextPayload = Map<String, dynamic>.from(payload);
    return payload;
  }

  void _debugEmergencyPayload(String message) {
    if (kDebugMode) {
      debugPrint('[EmergencyStartPayload] $message');
    }
  }

  String _displayNameFromUser(Map<String, dynamic>? user) {
    if (user == null) return '';
    final first = '${user['firstName'] ?? ''}'.trim();
    final last = '${user['lastName'] ?? ''}'.trim();
    final full = [first, last]
        .where((value) => value.isNotEmpty)
        .join(' ')
        .trim();
    if (full.isNotEmpty) return full;
    final fallbackName = '${user['name'] ?? ''}'.trim();
    return fallbackName;
  }

  Future<Position?> _getEmergencyPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _debugEmergencyPayload(
          'location service disabled, falling back to last known position',
        );
        return Geolocator.getLastKnownPosition();
      }

      var permission = await Geolocator.checkPermission();
      _debugEmergencyPayload('location permission status=$permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        _debugEmergencyPayload(
          'location permission after request=$permission',
        );
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _debugEmergencyPayload(
          'location permission denied, falling back to last known position',
        );
        return Geolocator.getLastKnownPosition();
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        _debugEmergencyPayload(
          'getCurrentPosition failed: $e, falling back to last known position',
        );
        return Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      _debugEmergencyPayload('_getEmergencyPosition failed: $e');
      return null;
    }
  }

  Future<String> _resolveApproximateAddress(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 8));
      if (placemarks.isEmpty) return '';

      final place = placemarks.first;
      final parts = <String>[];
      if ((place.street ?? '').trim().isNotEmpty) {
        parts.add(place.street!.trim());
      }
      if ((place.subLocality ?? '').trim().isNotEmpty) {
        parts.add(place.subLocality!.trim());
      }
      if ((place.locality ?? '').trim().isNotEmpty) {
        parts.add(place.locality!.trim());
      }
      if ((place.subAdministrativeArea ?? '').trim().isNotEmpty) {
        parts.add(place.subAdministrativeArea!.trim());
      }
      if ((place.administrativeArea ?? '').trim().isNotEmpty) {
        parts.add(place.administrativeArea!.trim());
      }
      if ((place.postalCode ?? '').trim().isNotEmpty) {
        parts.add(place.postalCode!.trim());
      }
      if ((place.country ?? '').trim().isNotEmpty) {
        parts.add(place.country!.trim());
      }

      return parts.join(', ');
    } catch (e) {
      _debugEmergencyPayload('_resolveApproximateAddress failed: $e');
      return '';
    }
  }

  Future<EmergencyCallResult> _onCallContact(int contactIndex) async {
    if (_sessionAnswered) {
      return const EmergencyCallResult(success: true, answered: true);
    }

    final sessionId = _emergencySessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return const EmergencyCallResult(
        success: false,
        answered: false,
        message: 'Emergency session not initialized',
        finalStatus: 'session-missing',
      );
    }

    Map<String, dynamic> response;
    try {
      final emergencyPayload = await _getOrCreateEmergencyContextPayload();
      response = await AuthService.attemptEmergencyContactCall(
        sessionId: sessionId,
        contactIndex: contactIndex,
        timeoutSec: 30,
        payload: emergencyPayload,
      );
    } catch (e) {
      if (await _handleUnauthorizedError(e)) {
        return const EmergencyCallResult(
          success: false,
          answered: false,
          message: 'Session expired. Please re-login.',
          finalStatus: 'unauthorized',
        );
      }
      return EmergencyCallResult(
        success: false,
        answered: false,
        message: e.toString(),
        finalStatus: 'failed',
      );
    }

    final finalStatus = (response['finalStatus'] ?? response['status'] ?? '')
        .toString()
        .toUpperCase();
    final latestStatus =
        (_latestSessionStatus?['status'] ?? '').toString().toUpperCase();
    final answered = response['answered'] == true ||
        finalStatus == 'ANSWERED' ||
        latestStatus == 'ANSWERED' ||
        (response['answeredBy'] != null &&
            response['answeredBy'].toString().isNotEmpty);
    if (answered) _sessionAnswered = true;

    final explicitFail =
        response['success'] == false || response['ok'] == false;
    final providerFailed = finalStatus == 'FAILED' ||
        finalStatus == 'NO_ANSWER' ||
        finalStatus == 'BUSY';
    final success = answered ? true : !(explicitFail || providerFailed);

    return EmergencyCallResult(
      success: success,
      answered: answered,
      message: response['message']?.toString(),
      finalStatus: finalStatus.isEmpty ? null : finalStatus,
    );
  }

  Future<EmergencyActionResult> _onCall119() async {
    final sessionId = _emergencySessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return const EmergencyActionResult(
        success: false,
        message: 'Emergency session not initialized',
      );
    }

    Map<String, dynamic> response;
    try {
      final emergencyPayload = await _getOrCreateEmergencyContextPayload();
      response = await AuthService.callEmergency119(
        sessionId: sessionId,
        payload: emergencyPayload,
      );
    } catch (e) {
      if (await _handleUnauthorizedError(e)) {
        return const EmergencyActionResult(
          success: false,
          message: 'Session expired. Please re-login.',
        );
      }
      return EmergencyActionResult(success: false, message: e.toString());
    }

    final explicitFail =
        response['success'] == false || response['ok'] == false;
    final called = response['emergencyServicesCalled'];
    final callFlagFailed = called is bool && called == false;
    return EmergencyActionResult(
      success: !(explicitFail || callFlagFailed),
      message: response['message']?.toString(),
    );
  }

  Future<EmergencyActionResult> _onCancelEmergency() async {
    final sessionId = _emergencySessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return const EmergencyActionResult(
        success: true,
        message: 'Emergency process stopped',
      );
    }

    Map<String, dynamic> response;
    try {
      response = await AuthService.cancelEmergency(sessionId: sessionId);
    } catch (e) {
      if (await _handleUnauthorizedError(e)) {
        return const EmergencyActionResult(
          success: false,
          message: 'Session expired. Please re-login.',
        );
      }
      return const EmergencyActionResult(
        success: false,
        message:
            'Emergency was stopped. We could not confirm contact notifications.',
      );
    } finally {
      _statusPollTimer?.cancel();
    }

    final ok = response['ok'] != false && response['success'] != false;
    return EmergencyActionResult(
      success: ok,
      message:
          response['message']?.toString() ?? 'Emergency process cancelled.',
    );
  }

  Future<bool> _handleUnauthorizedError(Object error) async {
    if (error is EmergencyApiException && error.statusCode == 401) {
      await AuthService.logout();
      if (!mounted) return true;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return true;
    }

    final normalized = error.toString().toUpperCase();
    final unauthorized = normalized.contains('UNAUTHORIZED') ||
        normalized.contains('HTTP 401') ||
        normalized.contains('INVALID OR EXPIRED TOKEN') ||
        normalized.contains('NO TOKEN PROVIDED');
    if (!unauthorized) return false;

    await AuthService.logout();
    if (!mounted) return true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    return true;
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────
//  SOS HOLD INTERACTION  (unchanged)
// ─────────────────────────────────────────────
class SOSHoldInteraction extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onComplete;

  const SOSHoldInteraction({
    required this.accentColor,
    required this.onComplete,
    super.key,
  });

  @override
  State<SOSHoldInteraction> createState() => _SOSHoldInteractionState();
}

class _SOSHoldInteractionState extends State<SOSHoldInteraction>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
        _controller.reset();
      }
    });
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Visibility of System Status: Shows a ring filling up during hold.
    // Fitts's Law: Massive single touch element.
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: List.generate(2, (index) {
                  final double progress =
                      (_rippleController.value + (index * 0.5)) % 1;
                  final double size = 260 + (progress * 90);
                  final double opacity = (1 - progress) * 0.24;

                  return IgnorePointer(
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.accentColor.withOpacity(opacity),
                          width: 2.5 - progress,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),

          // Outer subtle pulse ring
          Container(
            width: 290,
            height: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.accentColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 20,
                )
              ],
            ),
          ),

          // Outer progress ring path (background line)
          SizedBox(
            width: 290,
            height: 290,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.surfaceElevated.withOpacity(0.3)),
            ),
          ),

          // Actual animated progress indicator that fills up
          SizedBox(
            width: 290,
            height: 290,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CircularProgressIndicator(
                  value: _controller.value,
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),

          // Core Massive Button (Visual Hierarchy King)
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor, // Vibrant Red
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app,
                    color: Colors.white, size: 56), // Signifier
                const SizedBox(height: 12),
                const Text(
                  'HOLD TO\nSOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white, // High Contrast
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
