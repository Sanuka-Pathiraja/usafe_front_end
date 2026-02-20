import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:usafe_front_end/features/auth/auth_service.dart';

class ApiService {
  // ✅ FIX: Use 10.0.2.2 for Emulator AND add port :5000
  static const String backendUrl = "http://10.0.2.2:5000";

  // Simulate backend login
  static Future<String> login(String email, String password) async {
    final resp = await http.post(Uri.parse('$backendUrl/user/login'),
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
    final token = await MockDatabase.getToken();
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse(
      '$backendUrl/api/guardian/safety-score?lat=$lat&lng=$lng',
    );
    final resp = await http.get(uri, headers: headers);

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

  static Future<String> saveGuardianRoute({
    required String routeName,
    required List<Map<String, dynamic>> checkpoints,
  }) async {
    final token = await MockDatabase.getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse('$backendUrl/api/guardian/routes');
    final resp = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'route_name': routeName,
        'name': routeName,
        'is_active': true,
        'checkpoints': checkpoints,
      }),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Route save failed (${resp.statusCode})');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['route_id'] as String? ?? 'unknown';
  }

  static Future<void> sendGuardianAlert({
    required String routeId,
    required int checkpointIndex,
    required double lat,
    required double lng,
  }) async {
    final token = await MockDatabase.getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse('$backendUrl/api/guardian/alert');
    final resp = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'route_id': routeId,
        'checkpoint_index': checkpointIndex,
        'lat': lat,
        'lng': lng,
      }),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Alert send failed (${resp.statusCode})');
    }
  }

  static Future<void> submitIncidentReport({
    required String incidentType,
    required String description,
    required bool isAnonymous,
    double? lat,
    double? lng,
  }) async {
    final token = await MockDatabase.getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse('$backendUrl/api/incident');
    final resp = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'incident_type': incidentType,
        'description': description,
        'lat': lat,
        'lng': lng,
        'is_anonymous': isAnonymous,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Incident report submission failed (${resp.statusCode})');
    }
  }
}