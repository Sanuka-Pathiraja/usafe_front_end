import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use 10.0.2.2 for Android emulator to connect to local backend
  static const String backendUrl = "http://10.0.2.2:5000";

  static Map<String, dynamic> _decodeJsonMap(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'data': decoded};
  }

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
      throw Exception(
          "Failed to fetch safety score: HTTP ${resp.statusCode} - ${resp.body}");
    }
  }

  static Future<Map<String, dynamic>> startGuardianTracking({
    required String tripName,
    required int etaMinutes,
    required List<Map<String, dynamic>> checkpoints,
    required List<String> contactIds,
    String? jwt,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (jwt != null && jwt.isNotEmpty) {
      headers['Authorization'] = 'Bearer $jwt';
    }

    final resp = await http.post(
      Uri.parse('$backendUrl/api/guardian/track'),
      headers: headers,
      body: jsonEncode({
        'tripName': tripName,
        'etaMinutes': etaMinutes,
        'checkpoints': checkpoints,
        'contactIds': contactIds,
      }),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return _decodeJsonMap(resp.body);
    }
    throw Exception(
      'Failed to start guardian tracking: HTTP ${resp.statusCode} - ${resp.body}',
    );
  }

  static Future<Map<String, dynamic>> sendGuardianAlert({
    required String tripId,
    int? checkpointIndex,
    required double lat,
    required double lng,
    required String message,
    String? jwt,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (jwt != null && jwt.isNotEmpty) {
      headers['Authorization'] = 'Bearer $jwt';
    }

    final resp = await http.post(
      Uri.parse('$backendUrl/api/guardian/alert'),
      headers: headers,
      body: jsonEncode({
        'tripId': tripId,
        if (checkpointIndex != null) 'checkpointIndex': checkpointIndex,
        'lat': lat,
        'lng': lng,
        'message': message,
      }),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return _decodeJsonMap(resp.body);
    }
    throw Exception(
      'Failed to send guardian alert: HTTP ${resp.statusCode} - ${resp.body}',
    );
  }

  static Future<Map<String, dynamic>> fetchGuardianSafetyScore({
    required double lat,
    required double lng,
    String? jwt,
  }) async {
    final uri = Uri.parse('$backendUrl/api/guardian/safety-score').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
      },
    );

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (jwt != null && jwt.isNotEmpty) {
      headers['Authorization'] = 'Bearer $jwt';
    }

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return _decodeJsonMap(resp.body);
    }
    throw Exception(
      'Failed to fetch guardian safety score: HTTP ${resp.statusCode} - ${resp.body}',
    );
  }
}
