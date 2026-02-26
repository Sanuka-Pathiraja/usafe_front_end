import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String backendUrl = "http://localhost:5000";

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
}
