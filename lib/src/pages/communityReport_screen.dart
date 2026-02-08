import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:usafe_front_end/features/auth/community_report_service.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Set<int> selectedIndices = {};
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  bool _isSubmitting = false;

  // Issue types with their descriptions
  final List<Map<String, dynamic>> issueTypes = [
    {
      'icon': Icons.construction_rounded,
      'title': 'Road Issue',
      'color': Colors.orange,
      'description':
          'Potholes, cracks, or damaged road surfaces affecting traffic safety'
    },
    {
      'icon': Icons.lightbulb_rounded,
      'title': 'Street Lighting',
      'color': Colors.amber,
      'description':
          'Non-functional or dim street lights creating unsafe conditions'
    },
    {
      'icon': Icons.visibility_rounded,
      'title': 'Suspicious Activity',
      'color': Colors.red,
      'description': 'Unusual or concerning behavior observed in the area'
    },
    {
      'icon': Icons.groups_rounded,
      'title': 'Harassment',
      'color': Colors.pink,
      'description':
          'Incidents of verbal, physical, or psychological harassment'
    },
    {
      'icon': Icons.apartment_rounded,
      'title': 'Infrastructure',
      'color': Colors.blue,
      'description':
          'Damaged public facilities, broken sidewalks, or structural issues'
    },
    {
      'icon': Icons.security_rounded,
      'title': 'Theft/Security',
      'color': Colors.deepOrange,
      'description': 'Security concerns, theft incidents, or vulnerable areas'
    },
    {
      'icon': Icons.eco_rounded,
      'title': 'Environmental',
      'color': Colors.green,
      'description': 'Pollution, illegal dumping, or environmental hazards'
    },
    {
      'icon': Icons.broken_image_rounded,
      'title': 'Vandalism',
      'color': Colors.purple,
      'description':
          'Property damage, graffiti, or destruction of public assets'
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /* ================= AUTO-GENERATE REPORT DESCRIPTION ================= */
  void _updateReportDescription() {
    if (selectedIndices.isEmpty) {
      _descriptionController.clear();
      return;
    }

    final StringBuffer report = StringBuffer();
    report.writeln("═══════════════════════════════════════");
    report.writeln("        COMMUNITY SAFETY REPORT");
    report.writeln("═══════════════════════════════════════\n");

    report.writeln("📅 Date: ${DateTime.now().toString().split('.')[0]}");
    report.writeln("📍 Location: [Auto-detected or User Input]\n");

    if (selectedIndices.length == 1) {
      final issue = issueTypes[selectedIndices.first];
      report.writeln("🚨 REPORTED ISSUE:");
      report.writeln("   ${issue['title']}\n");
      report.writeln("📋 DESCRIPTION:");
      report.writeln("   ${issue['description']}\n");
    } else {
      report.writeln(
          "🚨 MULTIPLE ISSUES REPORTED (${selectedIndices.length}):\n");
      int count = 1;
      for (int index in selectedIndices) {
        final issue = issueTypes[index];
        report.writeln("$count. ${issue['title']}");
        report.writeln("   └─ ${issue['description']}\n");
        count++;
      }
    }

    report.writeln("───────────────────────────────────────");
    report.writeln("ADDITIONAL DETAILS:");
    report.writeln("Please add specific information about:");
    report.writeln("• Exact location/address");
    report.writeln("• Time of occurrence");
    report.writeln("• Severity level");
    report.writeln("• Any immediate dangers");
    report.writeln("• Additional context");
    report.writeln("───────────────────────────────────────");

    if (_selectedImages.isNotEmpty) {
      report.writeln(
          "\n📸 ATTACHED EVIDENCE: ${_selectedImages.length} photo(s)");
    }

    setState(() {
      _descriptionController.text = report.toString();
    });
  }

  /* ================= TOGGLE ISSUE SELECTION ================= */
  void _toggleIssue(int index) {
    setState(() {
      if (selectedIndices.contains(index)) {
        selectedIndices.remove(index);
      } else {
        selectedIndices.add(index);
      }
      _updateReportDescription();
    });
  }

  /* ================= CAMERA - REAL DEVICE PERMISSION ================= */
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo != null) {
        setState(() {
          _selectedImages.add(File(photo.path));
        });
        _updateReportDescription();
        showMessage("Photo added successfully");
      }
    } catch (e) {
      showMessage("Camera access denied or failed", isError: true);
    }
  }

  /* ================= GALLERY - REAL DEVICE PERMISSION ================= */
  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((img) => File(img.path)));
        });
        _updateReportDescription();
        showMessage("${images.length} photo(s) added");
      }
    } catch (e) {
      showMessage("Gallery access denied or failed", isError: true);
    }
  }

  /* ================= REMOVE IMAGE ================= */
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    _updateReportDescription();
    showMessage("Photo removed");
  }

  /* ================= SUBMIT TO BACKEND ================= */
  Future<void> _submitReport() async {
    if (selectedIndices.isEmpty) {
      showMessage("Please select at least one issue type", isError: true);
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      showMessage("Please describe the issue", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await CommunityReportService.submitReport(
        reportContent: _descriptionController.text,
        images: _selectedImages,
      );

      if (result['success']) {
        showMessage("Community report submitted successfully!");

        // Reset form
        setState(() {
          selectedIndices.clear();
          _descriptionController.clear();
          _selectedImages.clear();
        });
      } else {
        showMessage(result['error'] ?? 'Failed to submit report',
            isError: true);
      }
    } on SocketException {
      showMessage("No internet connection. Please check your network.",
          isError: true);
    } on TimeoutException {
      showMessage("Connection timeout. Server might be down.", isError: true);
    } catch (e) {
      showMessage("Error: ${e.toString()}", isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1128),
              Color(0xFF1B2845),
              Color(0xFF2E4057),
              Color(0xFF1B2845),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              /// HEADER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Community Reports",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Help make your community safer",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              /// SCROLLABLE CONTENT
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// SECTION TITLE
                      Row(
                        children: [
                          const Text(
                            "Select Issue Type(s)",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue, width: 1),
                            ),
                            child: Text(
                              "${selectedIndices.length} selected",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Tap to select multiple issues (you can choose any number)",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// ISSUE CARDS GRID
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: issueTypes.length,
                        itemBuilder: (context, index) {
                          final issue = issueTypes[index];
                          return IssueCard(
                            icon: issue['icon'],
                            text: issue['title'],
                            color: issue['color'],
                            selected: selectedIndices.contains(index),
                            onTap: () => _toggleIssue(index),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      /// DESCRIPTION SECTION
                      const Text(
                        "Auto-Generated Report",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Edit or add additional details below",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: TextField(
                          controller: _descriptionController,
                          maxLines: 12,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                "Select issue types above to generate report...",
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// PHOTOS SECTION
                      const Text(
                        "Add Photos (Optional)",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.camera_alt_rounded,
                              label: "Take Photo",
                              color: Colors.blue.shade600,
                              onPressed: _takePhoto,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.photo_library_rounded,
                              label: "Gallery",
                              color: Colors.purple.shade600,
                              onPressed: _pickFromGallery,
                            ),
                          ),
                        ],
                      ),

                      /// SELECTED IMAGES PREVIEW
                      if (_selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: const EdgeInsets.only(right: 12),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _selectedImages[index],
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade600,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      /// SUBMIT BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "Submit Community Report",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================= ISSUE CARD WIDGET ================= */
class IssueCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const IssueCard({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.3),
                    color.withOpacity(0.1),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.1),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            if (selected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: selected ? color : Colors.white70,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= ACTION BUTTON WIDGET ================= */
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
