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
    if (jwt == null || jwt.isEmpty) {
      throw Exception('Missing auth token. Please login again.');
    }

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $jwt',
    };

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
    } else if (resp.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception(
          "Failed to fetch safety score: HTTP ${resp.statusCode} - ${resp.body}");
    }
  }

  static Future<Map<String, dynamic>> saveSafePathSchedule({
    required Map<String, dynamic> payload,
    required String jwt,
  }) async {
    if (jwt.isEmpty) {
      throw Exception('Missing auth token. Please login again.');
    }

    final resp = await http.post(
      Uri.parse('$backendUrl/safepath/schedule'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    if (resp.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    }

    throw Exception(
      'Failed to save SafePath schedule: HTTP ${resp.statusCode} - ${resp.body}',
    );
  }

  static Future<Map<String, dynamic>> sendSafePathPing({
    required double latitude,
    required double longitude,
    required String jwt,
    DateTime? timestamp,
  }) async {
    if (jwt.isEmpty) {
      throw Exception('Missing auth token. Please login again.');
    }

    late http.Response resp;
    try {
      resp = await http.post(
        Uri.parse('$backendUrl/safepath/ping'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
        }),
      );
    } catch (error) {
      print('🛑 FLUTTER NETWORK ERROR (ping): $error');
      throw Exception('Failed to send SafePath ping: $error');
    }

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    if (resp.statusCode == 401) {
      print(
        '🛑 FLUTTER NETWORK ERROR: Status Code: ${resp.statusCode}, Body: ${resp.body}',
      );
      throw Exception('Session expired. Please login again.');
    }

    print(
      '🛑 FLUTTER NETWORK ERROR: Status Code: ${resp.statusCode}, Body: ${resp.body}',
    );

    throw Exception(
      'Failed to send SafePath ping: HTTP ${resp.statusCode} - ${resp.body}',
    );
  }

  static Future<List<Map<String, dynamic>>> fetchPlacesAutocomplete({
    required String query,
    required String jwt,
    String? sessionToken,
  }) async {
    if (jwt.isEmpty) {
      throw Exception('Missing auth token. Please login again.');
    }

    final params = <String, String>{'input': query};
    if (sessionToken != null && sessionToken.isNotEmpty) {
      params['sessionToken'] = sessionToken;
    }

    final uri = Uri.parse('$backendUrl/api/places/autocomplete')
        .replace(queryParameters: params);

    late http.Response resp;
    try {
      resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $jwt',
        },
      );
    } catch (error) {
      print('🛑 FLUTTER NETWORK ERROR (autocomplete): $error');
      throw Exception('Failed to fetch places: $error');
    }

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final raw = body['predictions'] as List<dynamic>? ?? [];
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (resp.statusCode == 401) {
      print(
        '🛑 FLUTTER NETWORK ERROR: Status Code: ${resp.statusCode}, Body: ${resp.body}',
      );
      throw Exception('Session expired. Please login again.');
    }

    print(
      '🛑 FLUTTER NETWORK ERROR: Status Code: ${resp.statusCode}, Body: ${resp.body}',
    );

    throw Exception(
      'Failed to fetch places: HTTP ${resp.statusCode} - ${resp.body}',
    );
  }

  static Future<Map<String, dynamic>> fetchPlaceDetails({
    required String placeId,
    required String jwt,
    String? sessionToken,
  }) async {
    if (jwt.isEmpty) {
      throw Exception('Missing auth token. Please login again.');
    }

    final params = <String, String>{'placeId': placeId};
    if (sessionToken != null && sessionToken.isNotEmpty) {
      params['sessionToken'] = sessionToken;
    }

    final uri = Uri.parse('$backendUrl/api/places/details')
        .replace(queryParameters: params);

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $jwt',
      },
    );

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return Map<String, dynamic>.from(body['place'] as Map);
    }
    if (resp.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    }

    throw Exception(
      'Failed to fetch place details: HTTP ${resp.statusCode} - ${resp.body}',
    );
  }
}
