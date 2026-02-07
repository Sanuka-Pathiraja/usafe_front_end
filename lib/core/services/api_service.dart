import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get backendUrl {
    const envUrl = String.fromEnvironment('BACKEND_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kIsWeb) {
      return "http://localhost:5000";
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:5000";
    }
    return "http://localhost:5000";
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await http.post(Uri.parse('$backendUrl/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data as Map<String, dynamic>;
    }

    final error = _extractError(resp.body);
    throw Exception(error ?? "Invalid credentials");
  }

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required int age,
    required String phone,
    required String email,
    required String password,
  }) async {
    final resp = await http.post(Uri.parse('$backendUrl/user/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstName': firstName,
          'lastName': lastName,
          'age': age,
          'phone': phone,
          'email': email,
          'password': password,
        }));

    if (resp.statusCode == 201) {
      final data = jsonDecode(resp.body);
      return data as Map<String, dynamic>;
    } else {
      final error = _extractError(resp.body);
      throw Exception(error ?? "Registration failed");
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
      final error = _extractError(resp.body);
      throw Exception(error ?? "PaymentIntent creation failed");
    }
  }

  static Future<List<Map<String, dynamic>>> getContacts(String jwt) async {
    final resp = await http.get(
      Uri.parse('$backendUrl/contact'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final contacts = data['contacts'] as List<dynamic>? ?? [];
      return contacts.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    final error = _extractError(resp.body);
    throw Exception(error ?? 'Failed to load contacts');
  }

  static Future<Map<String, dynamic>> addContact({
    required String jwt,
    required String name,
    required String relationship,
    required String phone,
  }) async {
    final resp = await http.post(
      Uri.parse('$backendUrl/contact/add'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({
        'name': name,
        'relationship': relationship,
        'phone': phone,
      }),
    );

    if (resp.statusCode == 201) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return Map<String, dynamic>.from(data['contact'] as Map);
    }

    final error = _extractError(resp.body);
    throw Exception(error ?? 'Failed to add contact');
  }

  static Future<void> deleteContact({
    required String jwt,
    required int contactId,
  }) async {
    final resp = await http.delete(
      Uri.parse('$backendUrl/contact/delete/$contactId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
    );

    if (resp.statusCode == 200) {
      return;
    }

    final error = _extractError(resp.body);
    throw Exception(error ?? 'Failed to delete contact');
  }

  static Future<Map<String, dynamic>> updateUser({
    required String jwt,
    required int userId,
    required String firstName,
    required String lastName,
    required String email,
    required String age,
    required String phone,
  }) async {
    final resp = await http.put(
      Uri.parse('$backendUrl/user/update/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'age': int.tryParse(age),
        'phone': phone,
        'email': email,
      }),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return Map<String, dynamic>.from(data['user'] as Map);
    }

    final error = _extractError(resp.body);
    throw Exception(error ?? 'Failed to update profile');
  }

  static Future<void> sendSosSms({
    required String jwt,
    required List<String> numbers,
    String? message,
  }) async {
    final resp = await http.post(
      Uri.parse('$backendUrl/sms'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({
        'numbers': numbers,
        if (message != null && message.isNotEmpty) 'message': message,
      }),
    );

    if (resp.statusCode == 200) {
      return;
    }

    final error = _extractError(resp.body);
    throw Exception(error ?? 'Failed to send SOS SMS');
  }

  static Future<void> makeSosCall({
    required String jwt,
    required String to,
  }) async {
    final resp = await http.post(
      Uri.parse('$backendUrl/call'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({'to': to}),
    );

    if (resp.statusCode == 200) {
      return;
    }

    final error = _extractError(resp.body);
    throw Exception(error ?? 'Failed to initiate call');
  }

  static Future<Map<String, dynamic>> createCommunityReport({
    required String jwt,
    required String reportContent,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$backendUrl/report/add'));
    request.headers['Authorization'] = 'Bearer $jwt';
    request.fields['reportContent'] = reportContent;
    request.fields['reportDate_time'] = DateTime.now().toIso8601String();

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    final error = _extractError(resp.body);
    throw Exception(error ?? 'Failed to create report');
  }

  static String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] ?? decoded['message'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
