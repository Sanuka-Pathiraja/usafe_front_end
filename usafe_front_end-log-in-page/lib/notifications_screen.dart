import 'package:flutter/material.dart';
import 'config.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _pushEnabled = true;
  bool _smsEnabled = true;
  bool _emailEnabled = false;
  bool _promoEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSwitchTile(
              "Push Notifications",
              "Receive instant alerts on this device",
              _pushEnabled,
              (v) => setState(() => _pushEnabled = v),
            ),
            _buildSwitchTile(
              "SMS Alerts",
              "Receive emergency alerts via text",
              _smsEnabled,
              (v) => setState(() => _smsEnabled = v),
            ),
            _buildSwitchTile(
              "Email Notifications",
              "Receive weekly safety reports",
              _emailEnabled,
              (v) => setState(() => _emailEnabled = v),
            ),
            _buildSwitchTile(
              "Marketing & Updates",
              "Product updates and news",
              _promoEnabled,
              (v) => setState(() => _promoEnabled = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        activeColor: AppColors.primarySky,
        inactiveTrackColor: Colors.grey.withOpacity(0.3),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
