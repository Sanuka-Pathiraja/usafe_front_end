import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// --- GLOBAL COLORS ---
class AppColors {
<<<<<<< HEAD
  static const Color background = Color(0xFF0A0E21);
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color surfaceCard = Color(0xFF1D1E33);
  static const Color primarySky = Color(0xFF448AFF);
  static const Color primaryNavy = Color(0xFF0D47A1);
  static const Color safetyTeal = Color(0xFF008080);
  static const Color alertRed = Color(0xFFFF2E2E);
  static const Color textGrey = Color(0xFF9CA3AF);
}

// --- MOCK DATABASE WITH PERSISTENCE ---
class MockDatabase {
  static Map<String, dynamic>? currentUser;
  
  // NEW: List to hold trusted contacts
  static List<Map<String, String>> trustedContacts = [];

  static Future<void> saveUserLocally(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    currentUser = user;
    await prefs.setString('user_session', jsonEncode(user));
  }

  static Future<void> loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user_session');
    if (userData != null) {
      currentUser = jsonDecode(userData);
    }
    await loadTrustedContacts(); // Load contacts when app starts
  }

  // --- NEW: CONTACTS LOGIC ---
  static Future<void> saveTrustedContacts(List<Map<String, String>> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    trustedContacts = contacts;
    // Save as a JSON string
    await prefs.setString('trusted_contacts', jsonEncode(contacts));
  }

  static Future<void> loadTrustedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('trusted_contacts');
    if (data != null) {
      List<dynamic> decoded = jsonDecode(data);
      trustedContacts = decoded.map((e) => Map<String, String>.from(e)).toList();
    }
  }
  // ---------------------------

  static Future<void> registerUser(String name, String email, String password) async {
    final newUser = {
      'name': name,
      'email': email,
      'password': password,
      'blood': 'Unknown',
      'age': '--',
      'weight': '--'
    };
    await saveUserLocally(newUser);
  }

  static Future<bool> validateLogin(String email, String password) async {
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        final user = {
          'name': 'Sanuka Pathiraja',
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
  
  static Future<void> updateUserProfile(String name, String email, String blood, String age, String weight) async {
    if (currentUser != null) {
      currentUser!['name'] = name;
      currentUser!['email'] = email;
      currentUser!['blood'] = blood;
      currentUser!['age'] = age;
      currentUser!['weight'] = weight;
      await saveUserLocally(currentUser!);
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');
    // Optional: Clear contacts on logout
    // await prefs.remove('trusted_contacts'); 
    currentUser = null;
=======
  // --- BACKGROUNDS ---
  static const bgDark = Color(0xFF020617); // Pitch black-blue
  static const bgLight = Color(0xFF0F172A); // Lighter navy
  static const surface = Color(0xFF1E293B); // Slate card color
  static final glass = Colors.white.withOpacity(0.05);
  static final glassBorder = Colors.white.withOpacity(0.1);

  // --- ACCENTS ---
  static const primary = Color(0xFF06B6D4); // Electric Cyan
  static const primaryDim = Color(0xFF0891B2);
  static const alert = Color(0xFFEF4444); // Vivid Red
  static const success = Color(0xFF10B981); // Emerald Green
  
  // --- TEXT ---
  static const textMain = Colors.white;
  static const textSub = Color(0xFF94A3B8); // Slate Grey
}

// --- MODELS ---
class EmergencyContact {
  final String id, name, phone, label;
  EmergencyContact({required this.id, required this.name, required this.phone, required this.label});
}

// --- DATABASE ---
class MockDatabase {
  static Map<String, dynamic> currentUser = {
    "name": "Sanuka Pathiraja",
    "email": "sanuka@example.com",
    "phone": "+94 77 123 4567"
  };

  // Used in Profile
  static List<EmergencyContact> emergencyContacts = [
    EmergencyContact(id: '1', name: "Jane Doe", phone: "0712345678", label: "Mother"),
    EmergencyContact(id: '2', name: "John Smith", phone: "0771234567", label: "Partner"),
  ];

  // Used in Contacts Screen
  static List<Map<String, String>> trustedContacts = [
    {"name": "Jane Doe", "phone": "0712345678", "relation": "Mother"},
    {"name": "John Smith", "phone": "0771234567", "relation": "Partner"},
    {"name": "Dr. Emily", "phone": "0771234567", "relation": "Doctor"},
  ];

  static Future<void> saveTrustedContacts(List<Map<String, String>> list) async {
    trustedContacts = list;
  }
  
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    currentUser.addAll(data);
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387
  }
}