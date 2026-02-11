import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

enum EmergencyOutcome { completed, cancelled, failed }

class EmergencySummary {
  final EmergencyOutcome outcome;
  final bool someoneAnswered;
  final bool emergencyServicesCalled; // 119 called or attempted
  final int? failedStepIndex; // if failed
  final String? failedStepTitle;

  const EmergencySummary({
    required this.outcome,
    required this.someoneAnswered,
    required this.emergencyServicesCalled,
    this.failedStepIndex,
    this.failedStepTitle,
  });
}

/// This is what we return back to Home to show the floating notification.
class HomeEmergencyBannerPayload {
  final String title;
  final String subtitle;
  const HomeEmergencyBannerPayload({required this.title, required this.subtitle});
}

class EmergencyResultScreen extends StatelessWidget {
  final EmergencySummary summary;
  const EmergencyResultScreen({super.key, required this.summary});

  Color get _accent {
    switch (summary.outcome) {
      case EmergencyOutcome.completed:
        return Colors.greenAccent;
      case EmergencyOutcome.cancelled:
        return const Color(0xFF1DE9B6);
      case EmergencyOutcome.failed:
        return const Color(0xFFFF3D00);
    }
  }

  String get _title {
    switch (summary.outcome) {
      case EmergencyOutcome.completed:
        return "Emergency Process Completed";
      case EmergencyOutcome.cancelled:
        return "Emergency Process Cancelled";
      case EmergencyOutcome.failed:
        return "Emergency Process Failed";
    }
  }

  String get _subtitle {
    switch (summary.outcome) {
      case EmergencyOutcome.completed:
        return summary.emergencyServicesCalled
            ? "Emergency services were contacted."
            : "Completed before contacting emergency services.";
      case EmergencyOutcome.cancelled:
        return "You stopped the emergency process.";
      case EmergencyOutcome.failed:
        return summary.failedStepTitle != null
            ? "Failed at: ${summary.failedStepTitle}"
            : "A step failed during the process.";
    }
  }

  HomeEmergencyBannerPayload get _bannerPayload {
    switch (summary.outcome) {
      case EmergencyOutcome.completed:
        return HomeEmergencyBannerPayload(
          title: "Emergency activated",
          subtitle: summary.emergencyServicesCalled
              ? "Process completed (119 contacted)"
              : "Process completed",
        );
      case EmergencyOutcome.cancelled:
        return const HomeEmergencyBannerPayload(
          title: "Emergency cancelled",
          subtitle: "You stopped the process",
        );
      case EmergencyOutcome.failed:
        return const HomeEmergencyBannerPayload(
          title: "Emergency failed",
          subtitle: "Some actions may not have completed",
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF15171B),
        title: const Text("Emergency Result"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _accent.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: TextStyle(
                        color: _accent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _subtitle,
                      style: TextStyle(color: Colors.grey[300], fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    _infoRow("Someone answered", summary.someoneAnswered ? "Yes" : "No"),
                    _infoRow("119 contacted", summary.emergencyServicesCalled ? "Yes" : "No"),
                    if (summary.outcome == EmergencyOutcome.failed &&
                        summary.failedStepTitle != null)
                      _infoRow("Failed step", summary.failedStepTitle!),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // ✅ Close -> go straight back to Home and return banner payload
                    Navigator.pop(context, _bannerPayload);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "CLOSE",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          Text(v, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
