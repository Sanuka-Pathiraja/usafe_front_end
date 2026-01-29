import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class AppColors {
  static const Color background = Color(0xFF05111A);
  static const Color surfaceCard = Color(0xFF102027);
  static const Color primarySky = Color(0xFF00B0FF);
  static const Color accentTeal = Color(0xFF1DE9B6);
  static const Color successGreen = Color(0xFF00E676);
  static const Color dangerRed = Color(0xFFFF3D00);
  static const Color warningOrange = Color(0xFFFF9100);
  static const Color textWhite = Color(0xFFECEFF1);
  static const Color textGrey = Color(0xFF90A4AE);
  static const Color textLight = Color(0xFFB0BEC5);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00B0FF), Color(0xFF01579B)],
  );
}

class EmergencyContact {
  final String name;
  final String phoneNumber;
  EmergencyContact({required this.name, required this.phoneNumber});
}

class MockDatabase {
  static final List<Map<String, String>> _users = [
    {'name': 'Nimali Perera', 'email': 'nimali@uni.lk', 'password': '123'},
  ];

  static List<Contact> savedPhoneContacts = [];
  static List<EmergencyContact> globalContacts = [];

  static bool validateLogin(String email, String password) =>
      _users.any((u) => u['email'] == email && u['password'] == password);

  static void registerUser(String name, String email, String password) =>
      _users.add({'name': name, 'email': email, 'password': password});

  static void syncContacts() {
    globalContacts = savedPhoneContacts
        .where((c) => c.phones.isNotEmpty)
        .map((c) => EmergencyContact(
              name: c.displayName,
              phoneNumber: c.phones.first.number,
            ))
        .toList();
  }
}
