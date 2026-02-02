import 'package:flutter/material.dart';

class AppColors {
  // Main Backgrounds
  static const Color background = Color(0xFF05111A);
  static const Color surfaceCard = Color(0xFF102027);

  // Brand Colors
  static const Color primarySky = Color(0xFF00B0FF);
  static const Color successGreen = Color(0xFF00E676);
  static const Color dangerRed = Color(0xFFFF3D00);

  // Text Colors
  static const Color textWhite = Color(0xFFECEFF1);
  static const Color textGrey = Color(0xFF90A4AE);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00B0FF), Color(0xFF01579B)],
  );
}

class MockDatabase {
  static final List<Map<String, String>> _users = [
    {'email': 'nimali@uni.lk', 'password': '123'},
  ];

  static void registerUser(String email, String password) {
    _users.add({'email': email, 'password': password});
    debugPrint("User Registered: $email");
  }

  static bool validateLogin(String email, String password) {
    // FIX: For testing, we allow ANY login if the fields are not empty.
    // This stops the "Invalid Credentials" error while you test the design.
    if (email.isNotEmpty && password.isNotEmpty) {
      return true;
    }
    return false;
  }
}
