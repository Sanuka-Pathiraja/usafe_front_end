import 'package:flutter/material.dart';
import 'config.dart';
import 'auth_screens.dart';
import 'medical_id_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';
import 'help_support_screen.dart';
import 'contacts_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _bloodController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    final user = MockDatabase.currentUser ?? {
      'name': 'Guest User',
      'email': 'No Email',
      'blood': '--',
      'age': '--',
      'weight': '--'
    };
    _nameController = TextEditingController(text: user['name']);
    _emailController = TextEditingController(text: user['email']);
    _bloodController = TextEditingController(text: user['blood']);
    _ageController = TextEditingController(text: user['age']);
    _weightController = TextEditingController(text: user['weight']);
  }

  void _toggleEdit() async {
    if (_isEditing) {
      await MockDatabase.updateUserProfile(
        _nameController.text,
        _emailController.text,
        _bloodController.text,
        _ageController.text,
        _weightController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile Updated!"),
          backgroundColor: AppColors.safetyTeal,
          duration: Duration(seconds: 1),
        ),
      );
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bloodController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primarySky, width: 2),
                      ),
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.surfaceCardSoft,
                        child: Icon(Icons.person, size: 50, color: Colors.white38),
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleEdit,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isEditing
                              ? AppColors.safetyTeal
                              : AppColors.primarySky,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Icon(
                          _isEditing ? Icons.check : Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildEditableField(
                  controller: _nameController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  isTitle: true,
                ),
                const SizedBox(height: 8),
                _buildEditableField(
                  controller: _emailController,
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
                  isTitle: false,
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCardSoft,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildVitalInput("Blood", _bloodController),
                      _buildDivider(),
                      _buildVitalInput("Age", _ageController),
                      _buildDivider(),
                      _buildVitalInput("Weight", _weightController),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buildMenuTile(
                  icon: Icons.medical_services_outlined,
                  title: "Medical ID & Allergies",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MedicalIDScreen()),
                  ),
                ),
                _buildMenuTile(
                  icon: Icons.contacts_outlined,
                  title: "Trusted Contacts",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactsScreen()),
                  ),
                ),
                _buildMenuTile(
                  icon: Icons.notifications_outlined,
                  title: "Notifications",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
                _buildMenuTile(
                  icon: Icons.lock_outline,
                  title: "Privacy & Security",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
                _buildMenuTile(
                  icon: Icons.help_outline,
                  title: "Help & Support",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () async {
                      await MockDatabase.logout();
                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout, color: AppColors.alertRed),
                    label: const Text(
                      "Logout",
                      style: TextStyle(
                        color: AppColors.alertRed,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: AppColors.surfaceCardSoft.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required TextStyle style,
    required bool isTitle,
  }) {
    if (_isEditing) {
      return Container(
        width: isTitle ? 250 : 300,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primarySky.withOpacity(0.5)),
        ),
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          style: style.copyWith(fontSize: isTitle ? 18 : 14),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      );
    }
    return Text(controller.text, style: style);
  }

  Widget _buildVitalInput(String label, TextEditingController controller) {
    return Column(
      children: [
        _isEditing
            ? SizedBox(
                width: 60,
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              )
            : Text(
                controller.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 30, width: 1, color: Colors.white24);
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primarySky, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
