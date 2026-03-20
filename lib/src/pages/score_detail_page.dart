import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

class ScoreDetailPage extends StatelessWidget {
  final String categoryKey;
  final String categoryTitle;
  final IconData icon;
  final String status;
  final Color statusColor;
  final List<ScoreParameter> parameters;

  const ScoreDetailPage({
    super.key,
    required this.categoryKey,
    required this.categoryTitle,
    required this.icon,
    required this.status,
    required this.statusColor,
    required this.parameters,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          categoryTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card ──
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.2),
                      statusColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withOpacity(0.2),
                      ),
                      child: Icon(
                        icon,
                        color: statusColor,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      categoryTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: statusColor.withOpacity(0.35)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Parameters Section ──
              const Text(
                'Score Parameters',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              // ── Parameter Cards ──
              Expanded(
                child: ListView.separated(
                  itemCount: parameters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final param = parameters[index];
                    return _buildParameterCard(
                      label: param.label,
                      value: param.value,
                      progress: param.progress,
                      color: param.color,
                      description: param.description,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParameterCard({
    required String label,
    required String value,
    required double progress,
    required Color color,
    required String? description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.border.withOpacity(0.35),
              color: color,
            ),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ScoreParameter {
  final String label;
  final String value;
  final double progress;
  final Color color;
  final String? description;

  ScoreParameter({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
    this.description,
  });
}
