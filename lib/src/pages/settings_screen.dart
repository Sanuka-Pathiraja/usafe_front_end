import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:usafe_front_end/core/constants/app_colors.dart';

import './payment_screen.dart';
import './privacy_screen.dart';
import './help_support_screen.dart';
import './detector_page.dart';

class SettingsPage extends StatefulWidget {
  final bool focusLocationSection;
  final bool highlightLocationSection;
  final bool returnToSafetyScoreOnEnable;

  const SettingsPage({
    super.key,
    this.focusLocationSection = false,
    this.highlightLocationSection = false,
    this.returnToSafetyScoreOnEnable = false,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool shareLocation = true;
  bool notificationsEnabled = false;
  bool activeMicrophoneListening = false;
  final GlobalKey _locationTileKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  AnimationController? _highlightController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    if (widget.highlightLocationSection) {
      _highlightController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    }
    if (widget.focusLocationSection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLocationTile();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _highlightController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSettings();
    }
  }

  // ================= LOAD SETTINGS =================
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationStatus = await Permission.notification.status;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    final permissionGranted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    setState(() {
      final storedShare = prefs.getBool("share_location") ?? true;
      final effectiveShare = storedShare && serviceEnabled && permissionGranted;
      if (storedShare && !effectiveShare) {
        prefs.setBool("share_location", false);
      }
      shareLocation = effectiveShare;
      notificationsEnabled = notificationStatus.isGranted;
      activeMicrophoneListening =
          prefs.getBool("active_microphone_listening") ?? false;
    });
  }

  // ================= LOCATION =================
  Future<bool> _toggleLocation(bool value) async {
    if (value) {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        _showSnack("Turn on device location services.");
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showSnack("Location permission is required.");
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        await openAppSettings();
        _showSnack("Allow location permission in app settings.");
        return false;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("share_location", value);

    setState(() => shareLocation = value);

    _showSnack(
      value ? "📍 Location sharing enabled" : "📍 Location sharing disabled",
    );

    if (value && widget.returnToSafetyScoreOnEnable) {
      if (!mounted) return true;
      Navigator.of(context).pop(true);
    }

    return true;
  }

  // ================= NOTIFICATIONS =================
  Future<void> _openNotificationSettings() async {
    if (Platform.isAndroid) {
      // Android: direct app notification page
      final packageName =
          "com.yourcompany.yourapp"; // <-- REPLACE with your app id
      final uri = Uri.parse("android-app://$packageName/settings");
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        // fallback
        await openAppSettings();
      }
    } else if (Platform.isIOS) {
      // iOS: open app settings (cannot go directly to notification page)
      final url = Uri.parse("app-settings:");
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnack("Cannot open app settings");
      }
    }
  }

  Future<void> _toggleActiveMicrophoneListening(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("active_microphone_listening", value);

    if (!mounted) return;
    setState(() => activeMicrophoneListening = value);
    _showSnack(
      value
          ? "Active microphone listening enabled"
          : "Active microphone listening disabled",
    );
  }

  void _openDetectorPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DetectorPage()),
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final highlightAnimation = _highlightController;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 24),
              _buildSettingsPanel(
                children: [
                  if (highlightAnimation != null)
                    AnimatedBuilder(
                      animation: highlightAnimation,
                      builder: (context, child) {
                        return _premiumToggleTile(
                          tileKey: _locationTileKey,
                          icon: Icons.location_on_outlined,
                          title: "Share Location",
                          subtitle: "Live location for emergencies",
                          value: shareLocation,
                          onChanged: _toggleLocation,
                          highlight: true,
                          highlightPulse: highlightAnimation.value,
                        );
                      },
                    )
                  else
                    _premiumToggleTile(
                      tileKey: _locationTileKey,
                      icon: Icons.location_on_outlined,
                      title: "Share Location",
                      subtitle: "Live location for emergencies",
                      value: shareLocation,
                      onChanged: _toggleLocation,
                    ),
                  _premiumToggleTile(
                    icon: Icons.notifications_outlined,
                    title: "Push Notifications",
                    subtitle: notificationsEnabled
                        ? "Enabled in device settings"
                        : "Disabled in device settings",
                    value: notificationsEnabled,
                    onChanged: (_) => _openNotificationSettings(),
                  ),
                  _actionTile(
                    icon: Icons.lock_outline,
                    title: "Privacy & Security",
                    subtitle: "Manage data and permissions",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                    ),
                  ),
                  _actionTile(
                    icon: Icons.help_outline,
                    title: "Help & Support",
                    subtitle: "FAQs and contact support",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAiFeaturesPanel(),
              const SizedBox(height: 20),
              _buildEmergencyPanel(),
              const SizedBox(height: 20),
              _premiumCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ================= COMPONENTS =================
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.35),
            AppColors.primary.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tune, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Control Center",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Manage privacy, safety tools, and app preferences",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _premiumToggleTile({
    Key? tileKey,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    bool highlight = false,
    double highlightPulse = 0,
  }) {
    final baseColor = AppColors.surface;
    final highlightColor = Color.lerp(
          AppColors.primary.withOpacity(0.2),
          AppColors.safetyTeal.withOpacity(0.25),
          highlightPulse,
        ) ??
        baseColor;
    final shadowOpacity = 0.18 + (0.22 * highlightPulse);
    return Container(
      key: tileKey,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? highlightColor : baseColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? AppColors.safetyTeal.withOpacity(0.6)
              : AppColors.border.withOpacity(0.6),
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: AppColors.safetyTeal.withOpacity(shadowOpacity),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? AppColors.safetyTeal.withOpacity(0.2)
                  : Colors.white10,
            ),
            child: Icon(
              icon,
              color: value ? AppColors.safetyTeal : Colors.white70,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (next) async {
              await onChanged(next);
            },
            activeColor: AppColors.safetyTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceElevated.withOpacity(0.5),
            AppColors.surface.withOpacity(0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border.withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildEmergencyPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.alert.withOpacity(0.35), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.alert.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.alert.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded,
                    color: AppColors.alert),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Emergency System",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "READY",
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Run a safe test to verify location, alerts, and UI readiness. No real alerts will be sent.",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openTestEmergencySheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.alert,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Run Emergency Test",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiFeaturesPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("AI Features"),
        _buildSettingsPanel(
          children: [
            _premiumToggleTile(
              icon: Icons.mic_none_rounded,
              title: "Active Microphone Listening",
              subtitle: "Allow AI features to listen in the background",
              value: activeMicrophoneListening,
              onChanged: _toggleActiveMicrophoneListening,
            ),
            _actionTile(
              icon: Icons.open_in_new_rounded,
              title: "Open AI Site",
              subtitle: "Temporary button for future site navigation",
              onTap: _openDetectorPage,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _scrollToLocationTile() async {
    final context = _locationTileKey.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.2,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primarySky, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _premiumCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaymentScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: const [
            Icon(Icons.workspace_premium, color: Colors.black, size: 30),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                "Upgrade to Pro",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTestEmergencySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.alert.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_rounded,
                        color: AppColors.alert),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Emergency System Test",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "This will simulate the SOS flow without notifying anyone. Use it to verify location, alerts, and UI readiness.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showSnack(
                          "Test started. No real alerts were sent.",
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.alert,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text("Run Test"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
