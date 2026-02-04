import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import for storage
import 'dart:convert'; // Import for JSON encoding

// --- GLOBAL COLORS ---
class AppColors {
  // Deep Navy Background (Matches the preferred Blue design)
  static const Color background = Color(0xFF0A0E21);
  static const Color backgroundBlack = Color(0xFF000000);

  // Input Fields & Cards
  static const Color surfaceCard = Color(0xFF1D1E33);

  // Brand Colors
  static const Color primarySky = Color(0xFF448AFF); // Bright Blue
  static const Color primaryNavy =
      Color(0xFF0D47A1); // Darker Blue for gradients

  // Status Colors
  static const Color safetyTeal = Color(0xFF008080);
  static const Color alertRed = Color(0xFFFF2E2E);
  static const Color textGrey = Color(0xFF9CA3AF);
}

// --- MOCK DATABASE WITH PERSISTENCE ---
class MockDatabase {
  // We use 'dynamic' to handle JSON decoding safely
  static Map<String, dynamic>? currentUser;

  // 1. Save the current user to local phone storage
  static Future<void> saveUserLocally(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    currentUser = user;
    // We convert the user map to a String to save it
    await prefs.setString('user_session', jsonEncode(user));
  }

  // 2. Load the user when the app starts
  static Future<void> loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user_session');
    if (userData != null) {
      currentUser = jsonDecode(userData);
    }
  }

  // 3. Register User (Now saves automatically)
  static Future<void> registerUser(
      String name, String email, String password) async {
    final newUser = {
      'name': name,
      'email': email,
      'password': password,
      'blood': 'Unknown',
      'age': '--',
      'weight': '--'
    };

    // Simulate logging them in immediately after registration
    await saveUserLocally(newUser);
    print("User Registered & Saved: $name");
  }

  // 4. Validate Login
  static Future<bool> validateLogin(String email, String password) async {
    try {
      // NOTE: In a real app, you would check against a list or API.
      // For this prototype, we accept any non-empty login and create a session.
      if (email.isNotEmpty && password.isNotEmpty) {
        final user = {
          'name':
              'Sanuka Pathiraja', // Default name for testing if not registered
          'email': email,
          'password': password,
          'blood': 'O+',
          'age': '24',
          'weight': '72kg'
        };
        await saveUserLocally(user);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 5. Update Profile & Save
  static Future<void> updateUserProfile(String name, String email, String blood,
      String age, String weight) async {
    if (currentUser != null) {
      currentUser!['name'] = name;
      currentUser!['email'] = email;
      currentUser!['blood'] = blood;
      currentUser!['age'] = age;
      currentUser!['weight'] = weight;

      // Save the updated info to storage
      await saveUserLocally(currentUser!);
    }
  }

  // 6. Logout (Clear data)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');
    currentUser = null;
  }
}
