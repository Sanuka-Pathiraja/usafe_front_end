import 'package:flutter/material.dart';
import 'config.dart';

class MedicalIDScreen extends StatefulWidget {
  const MedicalIDScreen({super.key});

  @override
  State<MedicalIDScreen> createState() => _MedicalIDScreenState();
}

class _MedicalIDScreenState extends State<MedicalIDScreen> {
  final _allergiesController =
      TextEditingController(text: "Peanuts, Penicillin");
  final _conditionsController = TextEditingController(text: "Asthma");
  final _medicationsController =
      TextEditingController(text: "Albuterol Inhaler");
  final _emergencyNotesController =
      TextEditingController(text: "In case of emergency, call my wife.");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Medical ID",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Critical Information"),
              const SizedBox(height: 16),
              _buildInputArea("Allergies & Reactions", _allergiesController, 3),
              const SizedBox(height: 20),
              _buildInputArea("Medical Conditions", _conditionsController, 2),
              const SizedBox(height: 20),
              _buildInputArea("Current Medications", _medicationsController, 3),
              const SizedBox(height: 30),
              _buildSectionHeader("Emergency Notes"),
              const SizedBox(height: 16),
              _buildInputArea(
                "Notes for First Responders",
                _emergencyNotesController,
                4,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Medical ID Saved"),
                        backgroundColor: AppColors.safetyTeal,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySky,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text("SAVE INFORMATION"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.primarySky,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInputArea(
    String label,
    TextEditingController controller,
    int maxLines,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCardSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}
