import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use 10.0.2.2 for Android emulator to connect to local backend
  static const String backendUrl = "http://10.0.2.2:5000";

  // Backend login (email/password)
  static Future<String> login(String email, String password) async {
    final resp = await http.post(Uri.parse('$backendUrl/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final token = (data['token'] ?? data['jwt'] ?? '').toString();
      if (token.isEmpty) {
        throw Exception('Missing token in login response');
      }
      return token;
    } else {
      throw Exception("Invalid credentials");
    }
  }

  // Create Stripe Checkout session
  static Future<Map<String, dynamic>> createPaymentIntent(
      int amount, String jwt) async {
    final resp = await http.post(Uri.parse('$backendUrl/payment/checkout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'amount': amount}));

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    } else {
      throw Exception("PaymentIntent creation failed");
    }
  }
  // Send Distress Signal (SOS)
  static Future<void> sendDistressSignal(
      String event, double confidence, String jwt) async {
    final resp = await http.post(
      Uri.parse('$backendUrl/sos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({'event': event, 'confidence': confidence}),
    );
    // Optionally handle response, show UI, etc.
  }

  // Fetch Live Safety Score
  static Future<Map<String, dynamic>> fetchSafetyScore({
    required double latitude,
    required double longitude,
    required int batteryLevel,
    bool isLocationEnabled = true,
    bool isMicrophoneEnabled = true,
    bool isToneSosActive = false,
    bool isSafePathActive = false,
    String? jwt,
  }) async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (jwt != null && jwt.isNotEmpty) {
      headers['Authorization'] = 'Bearer $jwt';
    }

    final resp = await http.post(
      Uri.parse('$backendUrl/safety-score'),
      headers: headers,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'batteryLevel': batteryLevel,
        'localTime': DateTime.now().toIso8601String(),
        'isLocationEnabled': isLocationEnabled,
        'isMicrophoneEnabled': isMicrophoneEnabled,
        'isToneSosActive': isToneSosActive,
        'isSafePathActive': isSafePathActive,
      }),
    );

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    } else {
      throw Exception("Failed to fetch safety score: HTTP ${resp.statusCode} - ${resp.body}");
    }
  }
}
