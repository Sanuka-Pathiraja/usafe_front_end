import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyApiException implements Exception {
  final int statusCode;
  final String? code;
  final String message;
  final Map<String, dynamic>? payload;

  const EmergencyApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.payload,
  });

  @override
  String toString() {
    final codePart = (code == null || code!.isEmpty) ? '' : ' [$code]';
    return 'EmergencyApiException($statusCode)$codePart: $message';
  }
}

class EmergencyStartAssessment {
  final bool messagingSuccessful;
  final String message;

  const EmergencyStartAssessment({
    required this.messagingSuccessful,
    required this.message,
  });
}

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:5000';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_session';
  static const String _contactsKey = 'trusted_contacts';

  static Future<void> _saveSession({
    required String token,
    Map<String, dynamic>? user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString('token', token); // Backward compatibility.
    if (user != null) {
      await prefs.setString(_userKey, jsonEncode(user));
    }
  }

  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) ?? prefs.getString('token') ?? '';
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<bool> isLoggedIn() async => (await getToken()).isNotEmpty;

  static Future<bool> validateSession() async {
    final token = await getToken();
    if (token.isEmpty) return false;

    final resp = await http.get(
      Uri.parse('$baseUrl/user/get'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode == 401) {
      await logout();
      return false;
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return true;
    }

    final body = jsonDecode(resp.body);
    final user = body is Map<String, dynamic> && body['user'] is Map
        ? Map<String, dynamic>.from(body['user'] as Map)
        : (body is Map<String, dynamic> ? body : null);
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    }
    return true;
  }

  static Future<bool> login(String email, String password) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/user/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return false;
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = (body['token'] ?? body['jwt'] ?? '').toString();
    if (token.isEmpty) return false;
    final user = body['user'] is Map<String, dynamic>
        ? body['user'] as Map<String, dynamic>
        : null;
    await _saveSession(token: token, user: user);
    return true;
  }

  static Future<bool> googleLogin(String idToken) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/user/googleLogin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return false;
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = (body['token'] ?? body['jwt'] ?? '').toString();
    if (token.isEmpty) return false;
    final user = body['user'] is Map<String, dynamic>
        ? body['user'] as Map<String, dynamic>
        : null;
    await _saveSession(token: token, user: user);
    return true;
  }

  static Future<bool> signup({
    required String firstName,
    required String lastName,
    required int age,
    required String phone,
    required String email,
    required String password,
  }) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/user/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'age': age,
        'phone': phone,
        'email': email,
        'password': password,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return false;
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = (body['token'] ?? body['jwt'] ?? '').toString();
    if (token.isNotEmpty) {
      final user = body['user'] is Map<String, dynamic>
          ? body['user'] as Map<String, dynamic>
          : null;
      await _saveSession(token: token, user: user);
      return true;
    }

    return login(email, password);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('token');
    await prefs.remove(_userKey);
  }

  static Future<List<Map<String, dynamic>>> fetchContacts() async {
    final token = await getToken();
    if (token.isEmpty) throw Exception('Not authenticated');

    final resp = await http.get(
      Uri.parse('$baseUrl/contact/contacts'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode == 401) {
      await logout();
      throw Exception('Invalid or expired token. Please re-login.');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Failed to load contacts (${resp.statusCode}).');
    }

    final decoded = jsonDecode(resp.body);
    final list = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic> && decoded['data'] is List
            ? decoded['data'] as List
            : <dynamic>[]);

    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    final token = await getToken();
    if (token.isEmpty) throw Exception('Not authenticated');

    final resp = await http.post(
      Uri.parse('$baseUrl/contact/contacts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'relationship': relationship,
      }),
    );

    if (resp.statusCode == 401) {
      await logout();
      throw Exception('Invalid or expired token. Please re-login.');
    }
    if (resp.statusCode == 409) {
      throw Exception('This phone number already exists in your contacts.');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Failed to add contact (${resp.statusCode}).');
    }

    return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
  }

  static Future<void> deleteContact(String contactId) async {
    final token = await getToken();
    if (token.isEmpty) throw Exception('Not authenticated');

    final resp = await http.delete(
      Uri.parse('$baseUrl/contact/contacts/$contactId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode == 401) {
      await logout();
      throw Exception('Invalid or expired token. Please re-login.');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Failed to remove contact (${resp.statusCode}).');
    }
  }

  static Future<void> saveTrustedContacts(
      List<Map<String, String>> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contactsKey, jsonEncode(contacts));
  }

  static Future<List<Map<String, String>>> loadTrustedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contactsKey);
    if (raw == null || raw.isEmpty) return <Map<String, String>>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Map<String, String>.from(e as Map<String, dynamic>))
        .toList();
  }

  static Map<String, dynamic> _decodeJsonMap(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'data': decoded};
  }

  static Future<Map<String, dynamic>> _authorizedRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final token = await getToken();
    if (token.isEmpty) {
      throw const EmergencyApiException(
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'No token provided',
      );
    }

    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    late http.Response resp;
    switch (method.toUpperCase()) {
      case 'GET':
        resp = await http.get(uri, headers: headers);
        break;
      case 'POST':
        resp = await http.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      default:
        throw ArgumentError('Unsupported method: $method');
    }

    final parsed = _decodeJsonMap(resp.body);
    if (resp.statusCode == 401) {
      throw EmergencyApiException(
        statusCode: 401,
        code: (parsed['code'] ?? 'UNAUTHORIZED').toString(),
        message: (parsed['message'] ?? 'Invalid or expired token').toString(),
        payload: parsed,
      );
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EmergencyApiException(
        statusCode: resp.statusCode,
        code: parsed['code']?.toString(),
        message: (parsed['message'] ?? 'Request failed').toString(),
        payload: parsed,
      );
    }

    return parsed;
  }

  static Future<Map<String, dynamic>> startEmergency() async {
    return _authorizedRequest(method: 'POST', path: '/emergency/start');
  }

  static EmergencyStartAssessment assessEmergencyStartResponse(
    Map<String, dynamic> response,
  ) {
    final messaging = response['messaging'];
    if (messaging is Map) {
      final sent = int.tryParse(messaging['sent']?.toString() ?? '') ?? 0;
      final attempted =
          int.tryParse(messaging['attempted']?.toString() ?? '') ?? 0;
      final failed = int.tryParse(messaging['failed']?.toString() ?? '') ?? 0;

      if (attempted > 0 && sent == 0) {
        return const EmergencyStartAssessment(
          messagingSuccessful: false,
          message: 'Could not message emergency contacts',
        );
      }
      if (failed > 0) {
        return EmergencyStartAssessment(
          messagingSuccessful: true,
          message: 'Emergency started with partial contact messaging',
        );
      }
    }

    return EmergencyStartAssessment(
      messagingSuccessful: response['ok'] == false
          ? true
          : (response['success'] != false),
      message: (response['message'] ?? 'Emergency started').toString(),
    );
  }

  static Future<Map<String, dynamic>> attemptEmergencyContactCall({
    required String sessionId,
    required int contactIndex,
    int? timeoutSec,
  }) async {
    return _authorizedRequest(
      method: 'POST',
      path: '/emergency/$sessionId/call/$contactIndex/attempt',
      body: timeoutSec == null ? null : {'timeoutSec': timeoutSec},
    );
  }

  static Future<Map<String, dynamic>> getEmergencyStatus({
    required String sessionId,
  }) async {
    return _authorizedRequest(
      method: 'GET',
      path: '/emergency/$sessionId/status',
    );
  }

  static Future<Map<String, dynamic>> getEmergencyCallStatus({
    required String sessionId,
    required String callId,
  }) async {
    return _authorizedRequest(
      method: 'GET',
      path: '/emergency/$sessionId/call/$callId/status',
    );
  }

  static Future<Map<String, dynamic>> callEmergency119({
    required String sessionId,
  }) async {
    return _authorizedRequest(
      method: 'POST',
      path: '/emergency/$sessionId/call-119',
    );
  }

  static Future<Map<String, dynamic>> cancelEmergency({
    required String sessionId,
  }) async {
    return _authorizedRequest(
      method: 'POST',
      path: '/emergency/$sessionId/cancel',
    );
  }
}

// Backward compatibility for older code paths that still use MockDatabase.
class MockDatabase {
  static Map<String, dynamic>? currentUser;
  static List<Map<String, String>> trustedContacts = [];

  static Future<void> saveUserLocally(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    currentUser = user;
    await prefs.setString('user_session', jsonEncode(user));
  }

  static Future<void> loadUserSession() async {
    currentUser = await AuthService.getCurrentUser();
    trustedContacts = await AuthService.loadTrustedContacts();
  }

  static Future<void> saveTrustedContacts(
      List<Map<String, String>> contacts) async {
    trustedContacts = contacts;
    await AuthService.saveTrustedContacts(contacts);
  }

  static Future<void> loadTrustedContacts() async {
    trustedContacts = await AuthService.loadTrustedContacts();
  }

  static Future<bool> validateLogin(String email, String password) async {
    return AuthService.login(email, password);
  }

  static Future<void> updateUserProfile(
    String name,
    String email,
    String blood,
    String age,
    String weight,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final user = await AuthService.getCurrentUser() ?? <String, dynamic>{};
    user['name'] = name;
    user['email'] = email;
    user['blood'] = blood;
    user['age'] = age;
    user['weight'] = weight;
    currentUser = user;
    await prefs.setString('user_session', jsonEncode(user));
  }

  static Future<void> registerUser(
      String name, String email, String phone, String password) async {
    final parts = name.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : name.trim();
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '-';
    await AuthService.signup(
      firstName: firstName,
      lastName: lastName,
      age: 0,
      phone: phone,
      email: email,
      password: password,
    );
  }

  static Future<void> logout() async {
    currentUser = null;
    await AuthService.logout();
  }
}
