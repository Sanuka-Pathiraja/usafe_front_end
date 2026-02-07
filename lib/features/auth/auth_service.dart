import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = "http://10.0.2.2:5000";
  // ⚠️ Android emulator uses 10.0.2.2 instead of localhost

  // ================= LOGIN =================
  static Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/user/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", data["token"]);
        await prefs.setString("user", jsonEncode(data["user"]));

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ================= SIGNUP =================
  static Future<bool> signup({
    required String firstName,
    required String lastName,
    required int age,
    required String phone,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/user/add"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "firstName": firstName,
        "lastName": lastName,
        "age": age,
        "phone": phone,
        "email": email,
        "password": password,
      }),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        "user",
        jsonEncode({
          "firstName": data["user"]["firstName"],
          "lastName": data["user"]["lastName"],
          "email": data["user"]["email"],
          "age": data["user"]["age"],
        }),
      );

      return true;
    }

    return false;
  }

  // ================= UPDATE USER =================
  static Future<bool> updateUser({
    String? firstName,
    String? lastName,
    int? age,
    String? phone,
  }) async {
    try {
      final token = await getToken();

      final response = await http.put(
        Uri.parse("$baseUrl/user/update"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          if (firstName != null) "firstName": firstName,
          if (lastName != null) "lastName": lastName,
          if (age != null) "age": age,
          if (phone != null) "phone": phone,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Update local SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("user", jsonEncode(data["user"]));

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // ================= GOOGLE LOGIN =================
  static Future<bool> googleLogin(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/user/googleLogin"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"idToken": idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", data["token"]);
        await prefs.setString("user", jsonEncode(data["user"]));
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /* ================= GET CONTACTS ================= */

  static Future<List<Map<String, dynamic>>> getContacts() async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/contact'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(body['contacts']);
    } else {
      throw Exception("Failed to load contacts");
    }
  }

  /* ================= ADD CONTACT ================= */

  static Future<void> addContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    final token = await getToken();

    final response = await http.post(
      Uri.parse('$baseUrl/contact/add'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "name": name,
        "phone": phone,
        "relationship": relationship,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception("Failed to add contact");
    }
  }

  /* ================= DELETE CONTACT ================= */

  static Future<void> deleteContact(int contactId) async {
    final token = await getToken();

    final response = await http.delete(
      Uri.parse('$baseUrl/contact/delete/$contactId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to delete contact");
    }
  }

  /* ================= TOKEN METHOD (already exists) ================= */

  static Future<String> getToken() async {
    // your existing token logic
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token") ?? "";
  }

  // ================= LOGOUT =================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("user");
    // Optionally, remove local-only medical data
    await prefs.remove("blood");
    await prefs.remove("medical_age");
    await prefs.remove("weight");
  }
}
