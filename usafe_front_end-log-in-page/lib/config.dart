import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// --- GLOBAL COLORS ---
class AppColors {
  static const Color background = Color(0xFF0A0E21);
  static const Color backgroundDeep = Color(0xFF070A16);
  static const Color backgroundBlack = Color(0xFF03050A);
  static const Color surfaceCard = Color(0xFF151A2D);
  static const Color surfaceCardSoft = Color(0xFF1C2240);
  static const Color primarySky = Color(0xFF4CC9F0);
  static const Color primaryNavy = Color(0xFF0B1E4A);
  static const Color safetyTeal = Color(0xFF1AA7A1);
  static const Color alertRed = Color(0xFFFF4D5A);
  static const Color textGrey = Color(0xFF9CA3AF);
  static const Color textSoft = Color(0xFFCBD5E1);
}

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background,
                  AppColors.backgroundDeep,
                  AppColors.backgroundBlack,
                ],
              ),
            ),
          ),
        ),
        const _GlowBlob(
          alignment: Alignment(-1.1, -0.9),
          size: 260,
          color: AppColors.primarySky,
          opacity: 0.12,
        ),
        const _GlowBlob(
          alignment: Alignment(1.0, 1.1),
          size: 240,
          color: AppColors.safetyTeal,
          opacity: 0.1,
        ),
        child,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;
  final double opacity;

  const _GlowBlob({
    required this.alignment,
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(opacity), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
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
  }
}