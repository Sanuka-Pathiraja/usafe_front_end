import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

class GuardianCheckpoint {
  final String name;
  final double lat;
  final double lng;
  final int safetyScore;

  const GuardianCheckpoint({
    required this.name,
    required this.lat,
    required this.lng,
    required this.safetyScore,
  });

  bool get isSafe => safetyScore >= 60;
}

class GuardianBottomSheet extends StatelessWidget {
  final TextEditingController routeNameController;
  final List<GuardianCheckpoint> checkpoints;
  final bool isMonitoringActive;
  final ValueChanged<GuardianCheckpoint> onRemoveCheckpoint;
  final VoidCallback onStartMonitoring;
  final VoidCallback onStopMonitoring;
  final VoidCallback onClose;

  const GuardianBottomSheet({
    super.key,
    required this.routeNameController,
    required this.checkpoints,
    required this.isMonitoringActive,
    required this.onRemoveCheckpoint,
    required this.onStartMonitoring,
    required this.onStopMonitoring,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: isMonitoringActive ? _buildActiveState(context) : _buildSetupState(context),
    );
  }

  Widget _buildSetupState(BuildContext context) {
    final canStart = checkpoints.length >= 2;
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when user taps outside the input field
        FocusScope.of(context).unfocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle (visual affordance)
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
              margin: const EdgeInsets.only(bottom: 12),
            ),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SafePath Guardian Setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: routeNameController,
            style: const TextStyle(color: Colors.white),
            onTap: () {
              // Keyboard will appear; continue normally
            },
            decoration: InputDecoration(
              hintText: 'e.g., Sarah to School',
              hintStyle: const TextStyle(color: Colors.white38),
              labelText: 'Route name',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: AppColors.bgLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap on the map to add safety checkpoints.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: checkpoints.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    itemCount: checkpoints.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final checkpoint = checkpoints[index];
                      return _buildCheckpointTile(checkpoint);
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canStart
                  ? () {
                      // Dismiss keyboard before starting
                      FocusScope.of(context).unfocus();
                      onStartMonitoring();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canStart ? AppColors.successGreen : Colors.grey.shade700,
                disabledBackgroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                canStart ? 'Start Monitoring' : 'Add 2+ Checkpoints',
                style: TextStyle(
                  color: canStart ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveState(BuildContext context) {
    final nextCheckpoint = checkpoints.isNotEmpty ? checkpoints.first.name : 'Pending';
    final checkpointCount = checkpoints.length;
    final nextCheckpointIndex = 1; // Child starts at index 1 (after first one)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
            margin: const EdgeInsets.only(bottom: 12),
          ),
        ),
        Row(
          children: [
            const GuardianPulseDot(),
            const SizedBox(width: 10),
            const Text(
              'Monitoring Active',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${nextCheckpointIndex}/${checkpointCount}',
                style: const TextStyle(
                  color: AppColors.successGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Next: $nextCheckpoint',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 6),
        const Text(
          'In progress...  🚀',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onStopMonitoring,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Stop Monitoring',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: Text(
          'No checkpoints yet. Tap the map to drop flags.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCheckpointTile(GuardianCheckpoint checkpoint) {
    final badgeColor = checkpoint.isSafe ? AppColors.successGreen : Colors.redAccent;
    final badgeText = checkpoint.isSafe
        ? 'Safe (${checkpoint.safetyScore})'
        : 'Risk (${checkpoint.safetyScore})';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        title: Text(
          checkpoint.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${checkpoint.lat.toStringAsFixed(5)}, ${checkpoint.lng.toStringAsFixed(5)}',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: badgeColor),
              ),
              child: Text(
                badgeText,
                style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: () => onRemoveCheckpoint(checkpoint),
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class GuardianPulseDot extends StatefulWidget {
  const GuardianPulseDot({super.key});

  @override
  State<GuardianPulseDot> createState() => _GuardianPulseDotState();
}

class _GuardianPulseDotState extends State<GuardianPulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: AppColors.successGreen,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
