import 'package:flutter/material.dart';

// --- GLOBAL COLORS ---
class AppColors {
  // Deep Navy Background (Matches the "Right" Design)
  static const Color background = Color(0xFF0A0E21);
  static const Color backgroundBlack = Color(0xFF000000); // For gradient fade

  // Input Fields & Cards
  static const Color surfaceCard = Color(0xFF1D1E33);

  // Brand Colors
  static const Color primarySky = Color(0xFF448AFF); // Bright Blue text/icons
  static const Color primaryNavy =
      Color(0xFF0D47A1); // Darker Blue for gradients

  // Status Colors
  static const Color safetyTeal = Color(0xFF008080);
  static const Color alertRed = Color(0xFFFF2E2E);
  static const Color textGrey = Color(0xFF9CA3AF);
}

// --- MOCK DATABASE ---
class MockDatabase {
  static final List<Map<String, String>> _users = [
    {
      'name': 'Sanuka Pathiraja',
      'email': 'test@usafe.com',
      'password': '123',
      'blood': 'O+',
      'age': '24',
      'weight': '72kg'
    },
  ];

  static Map<String, String>? currentUser;

  static void registerUser(String name, String email, String password) {
    _users.add({
      'name': name,
      'email': email,
      'password': password,
      'blood': 'Unknown',
      'age': '--',
      'weight': '--'
    });
    print("User Registered: $name");
  }

  static bool validateLogin(String email, String password) {
    try {
      final user = _users
          .firstWhere((u) => u['email'] == email && u['password'] == password);
      currentUser = user;
      return true;
    } catch (e) {
      return false;
    }
  }

  static void updateUserProfile(
      String name, String email, String blood, String age, String weight) {
    if (currentUser != null) {
      currentUser!['name'] = name;
      currentUser!['email'] = email;
      currentUser!['blood'] = blood;
      currentUser!['age'] = age;
      currentUser!['weight'] = weight;
    }
  }
}
