import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

class SafePathSchedulerScreen extends StatefulWidget {
  const SafePathSchedulerScreen({super.key});

  @override
  State<SafePathSchedulerScreen> createState() => _SafePathSchedulerScreenState();
}

class _SafePathSchedulerScreenState extends State<SafePathSchedulerScreen> {
  final List<String> _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final Set<int> _selectedDays = {};
  
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'SafePath Scheduler',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Trip Name'),
              const SizedBox(height: 12),
              _buildTextField('e.g. Going to school'),
              
              const SizedBox(height: 32),
              _buildSectionTitle('Recurring Days'),
              const SizedBox(height: 16),
              _buildDaysRow(),

              const SizedBox(height: 32),
              _buildSectionTitle('Start Time'),
              const SizedBox(height: 16),
              _buildTimePicker(),

              const SizedBox(height: 32),
              _buildSectionTitle('Checkpoints'),
              const SizedBox(height: 12),
              _buildTextField('Search place to add checkpoint'),

              const SizedBox(height: 32),
              _buildSectionTitle('Notify Priority Contacts'),
              const SizedBox(height: 4),
              const Text(
                'Add trusted contacts first in the Contacts tab.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildWarningBox(),

              const SizedBox(height: 48),
              _buildSaveButton(),
              const SizedBox(height: 120), // Bottom nav bar clearance
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField(String hint) {
    return TextField(
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: AppColors.surfaceElevated.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }

  Widget _buildDaysRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_days.length, (index) {
        final isSelected = _selectedDays.contains(index);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedDays.remove(index);
              } else {
                _selectedDays.add(index);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surfaceElevated.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _days[index],
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimePicker() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.2), // Subtle deep blue matching screenshot
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Custom Highlight overlay
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          CupertinoTheme(
            data: const CupertinoThemeData(
              brightness: Brightness.dark,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800, // Matches bold style from wireframe
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: DateTime.now(),
              use24hFormat: true, // Typically better suited for modern schedulers unless AM/PM requested
              onDateTimeChanged: (DateTime newDateTime) {
                setState(() {
                  _selectedTime = TimeOfDay.fromDateTime(newDateTime);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1B16), // Dark amber subtle background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No trusted contacts yet. Add them first.',
              style: TextStyle(
                color: const Color(0xFFF59E0B).withOpacity(0.9),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 64, // Massive touch target
      child: ElevatedButton(
        onPressed: () {
          // Save functionality
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FFD1), // Neon Cyan exactly matching wireframe
          foregroundColor: const Color(0xFF022C22), // Deep dark green/black for high contrast text
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: const Text(
          'Save SafePath Schedule',
          style: TextStyle(
            fontWeight: FontWeight.w900, // Extra bold
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
