import 'package:flutter/material.dart';

class AppColors {
  // --- BRAND COLORS (From Logo) ---
  static const Color primarySky =
      Color(0xFF29B6F6); // The light blue of the shield
  static const Color primaryNavy =
      Color(0xFF1565C0); // The dark blue of "USafe" text

  // --- UI BASE COLORS ---
  static const Color background = Color(0xFF151B28); // Deep Matte Midnight
  static const Color surfaceCard =
      Color(0xFF1C2436); // Lighter Card/Footer color
  static const Color textLight = Color(0xFFFFFFFF); // White text
  static const Color textGrey = Color(0xFFB0BEC5); // Greyed out text

  // --- FUNCTIONAL COLORS ---
  static const Color safetyTeal = Color(0xFF26A69A); // Success/Safe
  static const Color alertRed = Color(0xFFE53935); // Panic/Danger
  static const Color dangerRed = Color(0xFFE53935); // Alias for Danger

  // --- GRADIENTS ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primarySky, primaryNavy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// --- DATABASE SIMULATION ---
// This fixes the errors in Auth & Login screens
class MockDatabase {
  static final List<Map<String, String>> _users = [
    {'email': 'test@usafe.com', 'password': '123'},
  ];

  static void registerUser(String email, String password) {
    _users.add({'email': email, 'password': password});
    debugPrint("User Registered: $email");
  }

  static bool validateLogin(String email, String password) {
    // Allows any login if fields are not empty (for testing)
    // Or checks against the registered list
    if (email.isEmpty || password.isEmpty) return false;

    // Simple check: allows the default user OR any new user you just registered
    bool isValid = _users
        .any((user) => user['email'] == email && user['password'] == password);
    return isValid ||
        true; // remove '|| true' to enforce strict password checking
  }
}
