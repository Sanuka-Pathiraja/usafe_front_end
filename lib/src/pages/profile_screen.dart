import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/auth/screens/login_screen.dart';

import 'medical_id_screen.dart';
import 'contacts_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bloodController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString("user");

    if (userString != null) {
      final user = jsonDecode(userString);
      _nameController.text =
          "${user['firstName'] ?? ''} ${user['lastName'] ?? ''}";
      _emailController.text = user['email'] ?? "No email";
      _ageController.text = user['age']?.toString() ?? "";
    }

    _bloodController.text = prefs.getString("blood") ?? "";
    _weightController.text = prefs.getString("weight") ?? "";

    if (mounted) setState(() {});
  }

  Future<void> _toggleEdit() async {
    if (_isEditing) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString("blood", _bloodController.text);
      await prefs.setString("weight", _weightController.text);

      final names = _nameController.text.split(" ");
      await AuthService.updateUser(
        firstName: names.first,
        lastName: names.length > 1 ? names.sublist(1).join(" ") : "",
        age: int.tryParse(_ageController.text),
      );
    }

    setState(() => _isEditing = !_isEditing);
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
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              /// Avatar
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.surfaceCard,
                    child: Icon(Icons.person, size: 50, color: Colors.white38),
                  ),
                  InkWell(
                    onTap: _toggleEdit,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primarySky,
                      child: Icon(
                        _isEditing ? Icons.check : Icons.edit,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              _editableText(_nameController, 20, true),
              const SizedBox(height: 6),
              _editableText(_emailController, 14, false),

              const SizedBox(height: 30),

              /// Medical Vitals
              _vitalsCard(),

              const SizedBox(height: 30),

              /// ONLY ALLOWED MENU ITEMS
              _menuTile(
                Icons.medical_services_outlined,
                "Medical ID",
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicalIDScreen()),
                ),
              ),
              _menuTile(
                Icons.contacts_outlined,
                "Trusted Contacts",
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactsScreen()),
                ),
              ),
              _menuTile(
                Icons.settings_outlined,
                "Settings",
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),

              const SizedBox(height: 20),

              /// Logout
              TextButton.icon(
                onPressed: () async {
                  await AuthService.logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: AppColors.alertRed),
                label: const Text(
                  "Logout",
                  style: TextStyle(color: AppColors.alertRed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editableText(TextEditingController c, double size, bool bold) {
    if (_isEditing) {
      return SizedBox(
        width: 250,
        child: TextField(
          controller: c,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: size),
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      );
    }
    return Text(
      c.text,
      style: TextStyle(
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: Colors.white,
      ),
    );
  }

  Widget _vitalsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _vital("Blood", _bloodController),
          _vital("Age", _ageController),
          _vital("Weight", _weightController),
        ],
      ),
    );
  }

  Widget _vital(String label, TextEditingController c) {
    return Column(
      children: [
        _isEditing
            ? SizedBox(
                width: 50,
                child: TextField(
                  controller: c,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : Text(c.text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Widget _menuTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primarySky),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }
}
