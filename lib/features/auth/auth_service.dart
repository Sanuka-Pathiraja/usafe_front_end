import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyStartAssessment {
  final bool messagingSuccessful;
  final String? message;
  final String? code;

  const EmergencyStartAssessment({
    required this.messagingSuccessful,
    this.message,
    this.code,
  });
}

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
      // Use the correct route here too
      Uri.parse('$baseUrl/contact/contacts'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      // Directly cast the list since the backend doesn't wrap it in a Map
      return List<Map<String, dynamic>>.from(body);
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
      // CHANGE THIS LINE: from /contact/add to /contact/contacts
      Uri.parse('$baseUrl/contact/contacts'),
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

    // ... rest of the method
  }

  /* ================= UPDATE CONTACT ================= */

  static Future<void> updateContact({
    required int contactId,
    String? name,
    String? phone,
    String? relationship,
  }) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/contact/contacts/$contactId'), // Matches Backend
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (name != null) "name": name,
        if (phone != null) "phone": phone,
        if (relationship != null) "relationship": relationship,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? "Failed to update contact");
    }
  }

  /* ================= DELETE CONTACT ================= */

  static Future<void> deleteContact(int contactId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/contact/contacts/$contactId'), // Matches Backend
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? "Failed to delete contact");
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

  // ================= EMERGENCY FLOW =================

  static Future<Map<String, dynamic>> startEmergency() async {
    final token = await getToken();
    if (token.isEmpty) {
      throw Exception("Missing auth token. Please log in again.");
    }

    final locationText = await _getCurrentLocationText();
    final dangerTime = _isoWithOffset(DateTime.now());

    final response = await http.post(
      Uri.parse("$baseUrl/emergency/start"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "locationText": locationText,
        "dangerTime": dangerTime,
        "unicode": true,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_buildHttpError(
        action: "start emergency session",
        response: response,
      ));
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception("Invalid emergency start response");
    }
    return body;
  }

  static Future<String> _getCurrentLocationText() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return "Unknown location";

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return "Unknown location";
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return "${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}";
    } catch (_) {
      return "Unknown location";
    }
  }

  static String _isoWithOffset(DateTime dt) {
    final local = dt.toLocal();
    final datePart =
        "${local.year.toString().padLeft(4, "0")}-${local.month.toString().padLeft(2, "0")}-${local.day.toString().padLeft(2, "0")}";
    final timePart =
        "${local.hour.toString().padLeft(2, "0")}:${local.minute.toString().padLeft(2, "0")}:${local.second.toString().padLeft(2, "0")}";
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? "-" : "+";
    final abs = offset.abs();
    final off =
        "${abs.inHours.toString().padLeft(2, "0")}:${(abs.inMinutes % 60).toString().padLeft(2, "0")}";
    return "${datePart}T$timePart$sign$off";
  }

  static EmergencyStartAssessment assessEmergencyStartResponse(
    Map<String, dynamic> response,
  ) {
    final ok = response["ok"];
    final success = response["success"];
    final rawMessage = response["message"]?.toString();
    final code = response["code"]?.toString().toUpperCase();

    final messaging = response["messaging"];
    int? attempted;
    int? sent;
    int? failed;
    if (messaging is Map) {
      attempted = int.tryParse(messaging["attempted"]?.toString() ?? "");
      sent = int.tryParse(messaging["sent"]?.toString() ?? "");
      failed = int.tryParse(messaging["failed"]?.toString() ?? "");
    }

    final explicitFailure = ok == false || success == false;
    final isPartialByCode = code == "PARTIAL_SEND";
    final isFailedByCode = code == "SEND_FAILED";
    final isPartialByCounts = attempted != null &&
        attempted > 0 &&
        sent != null &&
        sent > 0 &&
        failed != null &&
        failed > 0;
    final isFailedByCounts = attempted != null &&
        attempted > 0 &&
        sent != null &&
        sent == 0 &&
        failed != null &&
        failed >= attempted;

    final messagingSuccessful = !explicitFailure &&
        !isFailedByCode &&
        !isPartialByCode &&
        !isFailedByCounts &&
        !isPartialByCounts;

    if (messagingSuccessful) {
      return const EmergencyStartAssessment(messagingSuccessful: true);
    }

    final fallbackMessage = (isPartialByCode || isPartialByCounts)
        ? "Some emergency SMS messages were not delivered"
        : "Failed to message emergency contacts";

    return EmergencyStartAssessment(
      messagingSuccessful: false,
      message: rawMessage ?? fallbackMessage,
      code: code,
    );
  }

  static Future<Map<String, dynamic>> attemptEmergencyContactCall({
    required String sessionId,
    required int contactIndex,
    int timeoutSec = 30,
  }) async {
    final token = await getToken();
    if (token.isEmpty) {
      throw Exception("Missing auth token. Please log in again.");
    }

    final response = await http.post(
      Uri.parse(
        "$baseUrl/emergency/$sessionId/call/$contactIndex/attempt",
      ),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"timeoutSec": timeoutSec}),
    );

    // Missing contact index in the ordered list should not crash the flow.
    if (response.statusCode == 404) {
      return {
        "success": true,
        "answered": false,
        "finalStatus": "not-configured",
      };
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_buildHttpError(
        action: "attempt emergency call",
        response: response,
      ));
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception("Invalid emergency call response");
    }

    return body;
  }

  static Future<Map<String, dynamic>> callEmergency119({
    required String sessionId,
  }) async {
    final token = await getToken();
    if (token.isEmpty) {
      throw Exception("Missing auth token. Please log in again.");
    }

    final response = await http.post(
      Uri.parse("$baseUrl/emergency/$sessionId/call-119"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_buildHttpError(
        action: "call emergency services",
        response: response,
      ));
    }

    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) {
      return body;
    }
    return {"ok": true};
  }

  static Future<Map<String, dynamic>> cancelEmergency({
    required String sessionId,
  }) async {
    final token = await getToken();
    if (token.isEmpty) {
      throw Exception("Missing auth token. Please log in again.");
    }

    final response = await http.post(
      Uri.parse("$baseUrl/emergency/$sessionId/cancel"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_buildHttpError(
        action: "cancel emergency process",
        response: response,
      ));
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception("Invalid emergency cancel response");
    }
    return body;
  }

  static String _buildHttpError({
    required String action,
    required http.Response response,
  }) {
    String? serverMessage;
    String? code;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        serverMessage = decoded["message"]?.toString();
        code = decoded["code"]?.toString();
      }
    } catch (_) {
      // Keep fallback behavior when backend returns non-JSON payloads.
    }

    if (kDebugMode) {
      debugPrint(
        "[AuthService] $action failed status=${response.statusCode} body=${response.body}",
      );
    }

    final base = "Failed to $action (HTTP ${response.statusCode})";
    if (serverMessage != null && serverMessage.isNotEmpty) {
      if (code != null && code.isNotEmpty) {
        return "$base: $serverMessage [$code]";
      }
      return "$base: $serverMessage";
    }

    return base;
  }
}
