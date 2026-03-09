import 'dart:async';
import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';

class SafePathSchedulerScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SafePathSchedulerScreen({super.key, this.onBack});

  @override
  State<SafePathSchedulerScreen> createState() =>
      _SafePathSchedulerScreenState();
}

class _SafePathSchedulerScreenState extends State<SafePathSchedulerScreen> {
  // ── State toggle ──
  bool _isTripActive = false;

  // ── Setup State ──
  final _tripNameController = TextEditingController();
  int _selectedDurationMins = 30;
  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120];
  List<Map<String, String>> _contacts = [];
  final Set<int> _selectedContactIndices = {};
  bool _loadingContacts = true;

  // ── Active Trip State ──
  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final remote = await AuthService.fetchContacts();
      if (!mounted) return;
      setState(() {
        _contacts = remote
            .map((e) => <String, String>{
                  'name': (e['name'] ?? '').toString(),
                  'phone': (e['phone'] ?? '').toString(),
                })
            .toList();
        _loadingContacts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingContacts = false);
    }
  }

  Future<void> _handleBack() async {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    await Navigator.of(context).maybePop();
  }

  void _startTrip() {
    setState(() {
      _isTripActive = true;
      _remainingSeconds = _selectedDurationMins * 60;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        // TODO: Trigger SOS / timeout alert
        return;
      }
      if (mounted) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _endTrip() {
    _countdownTimer?.cancel();
    setState(() {
      _isTripActive = false;
      _remainingSeconds = 0;
    });
  }

  void _addTime(int minutes) {
    setState(() {
      _remainingSeconds += minutes * 60;
    });
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isTripActive ? 'Trip Active' : 'SafePath Scheduler',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        leading: _isTripActive
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary, size: 20),
                onPressed: _handleBack,
              ),
      ),
      body: SafeArea(
        child: _isTripActive ? _buildActiveTripView() : _buildSetupView(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // STATE 1: SETUP SCREEN
  // ═══════════════════════════════════════════════════════
  Widget _buildSetupView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Trip Name ──
          const Text('Trip Name',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _tripNameController,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'e.g. Walking to the car',
              hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.6),
                  fontWeight: FontWeight.w400),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: AppColors.border.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              prefixIcon: const Icon(Icons.edit_road_rounded,
                  color: AppColors.textSecondary, size: 22),
            ),
          ),

          const SizedBox(height: 24),

          // ── Duration / ETA ──
          const Text('Duration / ETA',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _durationOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final mins = _durationOptions[index];
                final isSelected = mins == _selectedDurationMins;
                final label = mins >= 60 ? '${mins ~/ 60} hr' : '$mins min';
                return GestureDetector(
                  onTap: () => setState(() => _selectedDurationMins = mins),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── Emergency Contacts ──
          const Text('NOTIFY CONTACTS',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: _loadingContacts
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary)))
                : _contacts.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.alert.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.alert.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: AppColors.alert.withOpacity(0.9),
                                size: 18),
                            const SizedBox(width: 8),
                            Text('No trusted contacts yet',
                                style: TextStyle(
                                    color: AppColors.alert.withOpacity(0.9),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _contacts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final name = _contacts[index]['name'] ?? '?';
                          final isSelected =
                              _selectedContactIndices.contains(index);
                          return FilterChip(
                            label: Text(name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedContactIndices.add(index);
                                } else {
                                  _selectedContactIndices.remove(index);
                                }
                              });
                            },
                            selectedColor: AppColors.primary.withOpacity(0.3),
                            backgroundColor: AppColors.surface,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border.withOpacity(0.5),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            avatar: CircleAvatar(
                              backgroundColor: isSelected
                                  ? AppColors.primary
                                  : AppColors.surfaceElevated,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            showCheckmark: false,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                          );
                        },
                      ),
          ),

          const Spacer(),

          // ── Start Trip Button ──
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _startTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.navigation_rounded, size: 24),
              label: const Text(
                'START TRIP & NOTIFY CONTACTS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 120), // Bottom nav clearance
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // STATE 2: ACTIVE TRIP SCREEN
  // ═══════════════════════════════════════════════════════
  Widget _buildActiveTripView() {
    final tripName = _tripNameController.text.trim().isNotEmpty
        ? _tripNameController.text.trim()
        : 'Active Trip';
    final isUrgent = _remainingSeconds < 300; // < 5 mins = urgent

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ── Trip Info ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.navigation_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tripName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? AppColors.alert.withOpacity(0.2)
                        : AppColors.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isUrgent ? 'LOW TIME' : 'ACTIVE',
                    style: TextStyle(
                      color: isUrgent ? AppColors.alert : AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 1),

          // ── Massive Countdown Timer ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isUrgent
                    ? [
                        AppColors.alert.withOpacity(0.15),
                        AppColors.alert.withOpacity(0.05)
                      ]
                    : [
                        AppColors.primary.withOpacity(0.15),
                        AppColors.primary.withOpacity(0.05)
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isUrgent
                    ? AppColors.alert.withOpacity(0.3)
                    : AppColors.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'TIME REMAINING',
                  style: TextStyle(
                    color: isUrgent ? AppColors.alert : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatTime(_remainingSeconds),
                  style: TextStyle(
                    color: isUrgent ? AppColors.alert : AppColors.textPrimary,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Map Placeholder ──
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border.withOpacity(0.5)),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_rounded,
                        color: AppColors.textSecondary, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Live Map View',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Action Buttons Row ──
          Row(
            children: [
              // I'M SAFE Button (biggest)
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _endTrip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 22),
                    label: const Text(
                      "I'M SAFE",
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // +15 Min Button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _addTime(15),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.25),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      '+15 min',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // SOS Button
              SizedBox(
                width: 56,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Trigger SOS
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.alert,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Icon(Icons.sos_rounded, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 120), // Bottom nav clearance
        ],
      ),
    );
  }
}
