import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usafe_front_end/core/services/api_service.dart';

class MockDatabase {
  static Map<String, dynamic>? currentUser;
  static List<Map<String, String>> trustedContacts = [];
  static const String _tokenKey = 'auth_token';

  static Future<void> saveUserLocally(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    currentUser = user;
    await prefs.setString('user_session', jsonEncode(user));
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
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
    if (email.isEmpty || password.isEmpty) {
      return false;
    }

    final data = await ApiService.login(email, password);
    final token = data['token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;

    if (token == null || user == null) {
      return false;
    }

    await saveToken(token);
    await saveUserLocally(_mapUserToProfile(user));
    return true;
  }

  static Future<void> updateUserProfile(
    String name,
    String email,
    String blood,
    String age,
    String phone,
  ) async {
    if (currentUser == null) {
      return;
    }

    final token = await loadToken();
    final userId = currentUser?['id'];

    if (token != null && userId != null) {
      final parts = name.trim().split(RegExp(r"\s+"));
      final firstName = parts.isNotEmpty ? parts.first : name.trim();
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      final updated = await ApiService.updateUser(
        jwt: token,
        userId: userId,
        firstName: firstName.isEmpty ? 'User' : firstName,
        lastName: lastName,
        email: email,
        age: age,
        phone: phone,
      );

      currentUser = {
        ...currentUser!,
        'name': [updated['firstName'], updated['lastName']].where((p) => (p ?? '').toString().isNotEmpty).join(' '),
        'email': updated['email'] ?? email,
        'age': updated['age']?.toString() ?? age,
        'phone': updated['phone'] ?? phone,
      };
    } else {
      currentUser!['name'] = name;
      currentUser!['email'] = email;
      currentUser!['age'] = age;
      currentUser!['phone'] = phone;
    }

    currentUser!['blood'] = blood;
    currentUser!['weight'] = currentUser!['weight'] ?? '--';
    await saveUserLocally(currentUser!);
  }

  static Future<void> registerUser(String name, String email, String password) async {
    final parts = name.trim().split(RegExp(r"\s+"));
    final firstName = parts.isNotEmpty ? parts.first : name.trim();
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    await ApiService.register(
      firstName: firstName.isEmpty ? 'User' : firstName,
      lastName: lastName,
      age: 0,
      phone: '',
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');
    await prefs.remove(_tokenKey);
    currentUser = null;
  }

  static Map<String, dynamic> _mapUserToProfile(Map<String, dynamic> user) {
    final firstName = (user['firstName'] ?? '').toString().trim();
    final lastName = (user['lastName'] ?? '').toString().trim();
    final name = [firstName, lastName].where((p) => p.isNotEmpty).join(' ');

    return {
      'id': user['id'],
      'name': name.isEmpty ? 'User' : name,
      'email': user['email'] ?? '',
      'blood': user['blood'] ?? 'Unknown',
      'age': user['age']?.toString() ?? '--',
      'weight': user['weight'] ?? '--',
      'phone': user['phone'] ?? '',
    };
  }
}
