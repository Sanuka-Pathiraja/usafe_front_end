import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'safety_score_screen.dart';
import 'settings_screen.dart';

class SafetyScoreGateScreen extends StatefulWidget {
  final bool showBottomNav;
  final VoidCallback? onBackHome;

  const SafetyScoreGateScreen({
    super.key,
    this.showBottomNav = true,
    this.onBackHome,
  });

  @override
  State<SafetyScoreGateScreen> createState() => _SafetyScoreGateScreenState();
}

class _SafetyScoreGateScreenState extends State<SafetyScoreGateScreen>
    with WidgetsBindingObserver {
  bool _isReady = false;
  bool _isChecking = true;
  bool _shareLocationEnabled = true;
  bool _serviceEnabled = true;
  bool _permissionGranted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  @override
  void didUpdateWidget(covariant SafetyScoreGateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final shareLocation = prefs.getBool("share_location") ?? true;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    final permissionGranted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    if (!mounted) return;
    setState(() {
      _shareLocationEnabled = shareLocation;
      _serviceEnabled = serviceEnabled;
      _permissionGranted = permissionGranted;
      _isReady = shareLocation && serviceEnabled && permissionGranted;
      _isChecking = false;
    });
  }

  Future<void> _openSettingsToEnableLocation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsPage(
          focusLocationSection: true,
          highlightLocationSection: true,
          returnToSafetyScoreOnEnable: true,
        ),
      ),
    );
    await _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return SafetyScoreScreen(
        showBottomNav: widget.showBottomNav,
        onBackHome: widget.onBackHome,
      );
    }

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
      ),
      body: _isChecking
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.7),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Enable location to view your Safety Score",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "We use your device location to calculate a live safety score. Turn on location sharing and grant permission to continue.",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _statusRow(
                          label: "Location sharing",
                          enabled: _shareLocationEnabled,
                        ),
                        _statusRow(
                          label: "Device location",
                          enabled: _serviceEnabled,
                        ),
                        _statusRow(
                          label: "Location permission",
                          enabled: _permissionGranted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openSettingsToEnableLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        "Enable Location",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _statusRow({required String label, required bool enabled}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.safetyTeal.withOpacity(0.2)
                  : AppColors.alert.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              enabled ? Icons.check_rounded : Icons.close_rounded,
              color: enabled ? AppColors.safetyTeal : AppColors.alert,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
