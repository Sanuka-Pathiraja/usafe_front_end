import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_contacts/flutter_contacts.dart';

class AppColors {
  // The "Deep Midnight" Palette
  static const Color background = Color(0xFF0A0E21);
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color surfaceCard = Color(0xFF1D1E33);
  static const Color primarySky = Color(0xFF448AFF);
  static const Color primaryNavy = Color(0xFF0D47A1);
  static const Color safetyTeal = Color(0xFF008080);
  static const Color alertRed = Color(0xFFFF2E2E);
  static const Color textGrey = Color(0xFF9CA3AF);
}

class MockDatabase {
  static Map<String, dynamic>? currentUser;
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
    await loadTrustedContacts();
  }

  static Future<void> saveTrustedContacts(List<Map<String, String>> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    trustedContacts = contacts;
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

  static Future<bool> validateLogin(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulating network
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

  static Future<void> registerUser(String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
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

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');
    currentUser = null;
  }
}