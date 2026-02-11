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

/// Returned up the navigation stack to show banner on Home.
class HomeEmergencyBannerPayload {
  final String title;
  final String subtitle;
  const HomeEmergencyBannerPayload({
    required this.title,
    required this.subtitle,
  });

  @override
  String toString() => "HomeEmergencyBannerPayload(title=$title, subtitle=$subtitle)";
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

  IconData get _bigIcon {
    switch (summary.outcome) {
      case EmergencyOutcome.completed:
        return Icons.verified_rounded;
      case EmergencyOutcome.cancelled:
        return Icons.pause_circle_filled_rounded;
      case EmergencyOutcome.failed:
        return Icons.error_rounded;
    }
  }

  String get _title {
    switch (summary.outcome) {
      case EmergencyOutcome.completed:
        return "Emergency Completed";
      case EmergencyOutcome.cancelled:
        return "Emergency Cancelled";
      case EmergencyOutcome.failed:
        return "Emergency Failed";
    }
  }

  String get _subtitle {
    switch (summary.outcome) {
      case EmergencyOutcome.completed:
        if (summary.emergencyServicesCalled) {
          return "Emergency contacts were notified and 119 was contacted.";
        }
        return "Emergency contacts were notified. 119 was not contacted.";
      case EmergencyOutcome.cancelled:
        return "You stopped the emergency process before it finished.";
      case EmergencyOutcome.failed:
        if (summary.failedStepTitle != null) {
          return "Something went wrong at: ${summary.failedStepTitle}";
        }
        return "Something went wrong during the emergency process.";
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

  String get _outcomeChipText {
    switch (summary.outcome) {
      case EmergencyOutcome.completed:
        return "COMPLETED";
      case EmergencyOutcome.cancelled:
        return "CANCELLED";
      case EmergencyOutcome.failed:
        return "FAILED";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF15171B),
        title: const Text("Emergency Summary"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            children: [
              _heroCard(),
              const SizedBox(height: 14),
              _detailsGrid(),
              const SizedBox(height: 14),
              _timelineCard(),
              const SizedBox(height: 16),
              _actions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF15171B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accent.withOpacity(0.28)),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // big icon with glow
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(color: _accent.withOpacity(0.35)),
            ),
            child: Icon(_bigIcon, size: 44, color: _accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // outcome chip
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _accent.withOpacity(0.35)),
                    ),
                    child: Text(
                      _outcomeChipText,
                      style: TextStyle(
                        color: _accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitle,
                  style: TextStyle(color: Colors.grey[300], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsGrid() {
    return Row(
      children: [
        Expanded(
          child: _miniCard(
            icon: Icons.phone_in_talk_rounded,
            title: "Answered",
            value: summary.someoneAnswered ? "YES" : "NO",
            accent: summary.someoneAnswered ? Colors.greenAccent : Colors.white70,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniCard(
            icon: Icons.local_phone_rounded,
            title: "119 Contacted",
            value: summary.emergencyServicesCalled ? "YES" : "NO",
            accent: summary.emergencyServicesCalled ? Colors.greenAccent : Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _miniCard({
    required IconData icon,
    required String title,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: Colors.grey[300], fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _timelineCard() {
    final items = _buildTimelineItems();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15171B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "What happened",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }

  List<Widget> _buildTimelineItems() {
    // We don't have per-step states in the summary,
    // so we present a clean narrative timeline.
    final List<_TimelineRow> rows = [
      _TimelineRow(
        icon: Icons.sms_rounded,
        title: "Emergency contacts messaged",
        status: "Sent",
        ok: true,
      ),
      _TimelineRow(
        icon: Icons.call_rounded,
        title: "Emergency contact calls attempted",
        status: summary.someoneAnswered ? "Answered" : "No answer",
        ok: summary.someoneAnswered,
      ),
      _TimelineRow(
        icon: Icons.support_agent_rounded,
        title: "Emergency services (119)",
        status: summary.emergencyServicesCalled ? "Contacted" : "Not contacted",
        ok: summary.emergencyServicesCalled,
      ),
    ];

    if (summary.outcome == EmergencyOutcome.failed) {
      rows.add(
        _TimelineRow(
          icon: Icons.warning_rounded,
          title: "Failure detected",
          status: summary.failedStepTitle ?? "Unknown step",
          ok: false,
        ),
      );
    }

    if (summary.outcome == EmergencyOutcome.cancelled) {
      rows.add(
        _TimelineRow(
          icon: Icons.pause_rounded,
          title: "User action",
          status: "Cancelled",
          ok: false,
        ),
      );
    }

    return List.generate(rows.length, (i) {
      final r = rows[i];
      final color = r.ok ? Colors.greenAccent : _accent;

      return Padding(
        padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.28)),
              ),
              child: Icon(r.icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.status,
                    style: TextStyle(color: Colors.grey[300], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _actions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context, _bannerPayload);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "CLOSE",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: () {
              // close but still return payload (same effect)
              Navigator.pop(context, _bannerPayload);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.18)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              "BACK TO HOME",
              style: TextStyle(
                color: Colors.grey[200],
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineRow {
  final IconData icon;
  final String title;
  final String status;
  final bool ok;

  _TimelineRow({
    required this.icon,
    required this.title,
    required this.status,
    required this.ok,
  });
}
