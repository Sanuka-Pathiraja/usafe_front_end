import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ✅ FIX: Use 10.0.2.2 for Emulator AND add port :5000
  static const String backendUrl = "http://10.0.2.2:5000";

  // Simulate backend login
  static Future<String> login(String email, String password) async {
    final resp = await http.post(Uri.parse('$backendUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['token'];
    } else {
      throw Exception("Invalid credentials");
    }
  }

  // Create PaymentIntent
  static Future<Map<String, dynamic>> createPaymentIntent(
      int amount, String jwt) async {
    final resp = await http.post(Uri.parse('$backendUrl/payment/create'),
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

  static Future<int> fetchGuardianSafetyScore({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse(
      '$backendUrl/api/guardian/safety-score?lat=$lat&lng=$lng',
    );
    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      throw Exception('Guardian score request failed (${resp.statusCode})');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final scoreValue = data['score'];
    if (scoreValue is! num) {
      throw Exception('Guardian score missing or invalid');
    }

    return scoreValue.round().clamp(0, 100);
  }
}