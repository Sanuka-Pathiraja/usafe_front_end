import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usafe_front_end/core/services/push_notification_service.dart';

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
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_session';
  static const String _contactsKey = 'trusted_contacts';

  static void _logContactAlert(String message) {
    debugPrint('[ContactAlert] $message');
  }

  static Future<void> _saveSession({
    required String token,
    Map<String, dynamic>? user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString('token', token); // Backward compatibility.
    if (user != null) {
      await prefs.setString(_userKey, jsonEncode(user));
    } else {
      // Prevent stale profile data from previous sessions.
      await prefs.remove(_userKey);
    }
    // Do not block login flow if push-token sync is slow/unavailable.
    try {
      await PushNotificationService.syncTokenWithBackend().timeout(
        const Duration(seconds: 5),
      );
    } on TimeoutException {
      debugPrint('[AuthService] push token sync timed out during login.');
    } catch (e) {
      debugPrint('[AuthService] push token sync failed during login: $e');
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

  static int communityReportCountFromUser(Map<String, dynamic>? user) {
    if (user == null) return 0;
    final dynamic raw = user['communityReportCount'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static Future<int> fetchCommunityReportCount() async {
    final token = await getToken();
    if (token.isEmpty) {
      return communityReportCountFromUser(await getCurrentUser());
    }

    final resp = await http.get(
      Uri.parse('$baseUrl/user/community-report-count'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode == 401) {
      await logout();
      throw Exception('Invalid or expired token. Please re-login.');
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final body = _decodeJsonMap(resp.body);
      final count = body['communityReportCount'];
      final parsedCount = count is int ? count : int.tryParse('$count') ?? 0;
      final user = await getCurrentUser() ?? <String, dynamic>{};
      user['communityReportCount'] = parsedCount;
      await _saveCurrentUser(user);
      MockDatabase.currentUser = user;
      return parsedCount;
    }

    // Fallback to /user/get payload cache if backend count endpoint fails.
    final cached = await getCurrentUser();
    return communityReportCountFromUser(cached);
  }

  static Future<void> incrementLocalCommunityReportCount([int by = 1]) async {
    final user = await getCurrentUser() ?? <String, dynamic>{};
    final current = communityReportCountFromUser(user);
    user['communityReportCount'] = current + by;
    await _saveCurrentUser(user);
    MockDatabase.currentUser = user;
  }

  static Future<void> _saveCurrentUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Map<String, dynamic>? _extractUserFromResponse(dynamic decoded) {
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded as Map);
    final userNode = map['user'];
    if (userNode is Map) return Map<String, dynamic>.from(userNode);

    final dataNode = map['data'];
    if (dataNode is Map) {
      final dataMap = Map<String, dynamic>.from(dataNode);
      final nestedUser = dataMap['user'];
      if (nestedUser is Map) return Map<String, dynamic>.from(nestedUser);
      return dataMap;
    }

    return map;
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    int? age,
  }) async {
    final payload = <String, dynamic>{};
    if (firstName != null) payload['firstName'] = firstName.trim();
    if (lastName != null) payload['lastName'] = lastName.trim();
    if (email != null) payload['email'] = email.trim();
    if (phone != null) payload['phone'] = phone.trim();
    if (age != null) payload['age'] = age;

    payload.removeWhere((_, value) => value == null || '$value'.isEmpty);
    if (payload.isEmpty) {
      throw Exception('No profile fields to update.');
    }

    final token = await getToken();
    if (token.isEmpty) throw Exception('Not authenticated');

    final endpoints = <String>[
      '/user/update',
      '/user/edit',
      '/user/profile',
      '/user/updateProfile',
    ];
    final methods = <String>['PUT', 'PATCH', 'POST'];

    http.Response? lastResp;

    for (final path in endpoints) {
      for (final method in methods) {
        final resp = await _sendAuthorizedJson(
          method: method,
          path: path,
          body: payload,
          token: token,
        );
        lastResp = resp;

        if (resp.statusCode == 401) {
          await logout();
          throw Exception('Invalid or expired token. Please re-login.');
        }

        if (resp.statusCode == 404 || resp.statusCode == 405) {
          continue;
        }

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final decoded = _decodeJsonMap(resp.body);
          final serverUser = _extractUserFromResponse(decoded);
          final current = await getCurrentUser() ?? <String, dynamic>{};
          final merged = <String, dynamic>{...current, ...payload};
          if (serverUser != null) merged.addAll(serverUser);
          await _saveCurrentUser(merged);
          MockDatabase.currentUser = merged;
          return merged;
        }

        final errorMap = _decodeJsonMap(resp.body);
        final message =
            (errorMap['message'] ?? 'Profile update failed').toString();
        throw Exception(message);
      }
    }

    throw Exception(
      'Profile update endpoint not found (${lastResp?.statusCode ?? 'no-response'}).',
    );
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
      // Preserve previously cached fields (e.g., avatar/birthday/phone from
      // googleLogin) if /user/get does not return them yet.
      final current = await getCurrentUser() ?? <String, dynamic>{};
      final merged = <String, dynamic>{...current, ...user};
      await _saveCurrentUser(merged);
      MockDatabase.currentUser = merged;
    }
    return true;
  }

  static Future<bool> login(String email, String password) async {
    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('$baseUrl/user/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      debugPrint('[AuthService] login timed out after $_requestTimeout');
      return false;
    } catch (e) {
      debugPrint('[AuthService] login request failed: $e');
      return false;
    }

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

  static Future<bool> googleLogin(String idToken, {String? accessToken}) async {
    final result = await googleLoginDetailed(
      idToken,
      accessToken: accessToken,
    );
    return result['success'] == true;
  }

  static Future<Map<String, dynamic>> googleLoginDetailed(
    String idToken, {
    String? accessToken,
  }) async {
    if (idToken.trim().isEmpty) {
      return <String, dynamic>{
        'success': false,
        'statusCode': 400,
        'message': 'Google idToken is empty.',
      };
    }

    final resp = await http.post(
      Uri.parse('$baseUrl/user/googleLogin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
        if ((accessToken ?? '').trim().isNotEmpty)
          'accessToken': accessToken!.trim(),
      }),
    );

    Map<String, dynamic> body = <String, dynamic>{};
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {}

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final message =
          (body['message'] ?? body['error'] ?? 'Google login failed')
              .toString();
      return <String, dynamic>{
        'success': false,
        'statusCode': resp.statusCode,
        'message': message,
      };
    }

    final token = (body['token'] ?? body['jwt'] ?? '').toString();
    if (token.isEmpty) {
      return <String, dynamic>{
        'success': false,
        'statusCode': resp.statusCode,
        'message': 'Backend returned success but token is missing.',
      };
    }

    final user = body['user'] is Map<String, dynamic>
        ? body['user'] as Map<String, dynamic>
        : null;
    await _saveSession(token: token, user: user);
    // Pull freshest server-side profile (phone, birthday, image, etc).
    await validateSession();
    return <String, dynamic>{
      'success': true,
      'statusCode': resp.statusCode,
      'message': (body['message'] ?? 'Google login successful').toString(),
    };
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
    await PushNotificationService.unregisterTokenFromBackend();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('token');
    await prefs.remove(_userKey);
    await prefs.remove(_contactsKey);
    MockDatabase.currentUser = null;
    MockDatabase.trustedContacts = <Map<String, String>>[];
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

  static Future<Map<String, dynamic>> sendContactAlert({
    String? contactId,
    required String phoneNumber,
    required String message,
  }) async {
    final trimmedPhone = phoneNumber.trim();
    final trimmedMessage = message.trim();

    if (trimmedPhone.isEmpty) {
      throw Exception('Contact phone number is missing.');
    }
    if (trimmedMessage.isEmpty) {
      throw Exception('Emergency message cannot be empty.');
    }

    final payload = <String, dynamic>{
      if ((contactId ?? '').trim().isNotEmpty) 'contactId': contactId!.trim(),
      'phoneNumber': trimmedPhone,
      'message': trimmedMessage,
    };

    _logContactAlert(
      'Sending contact alert. contactId=${(contactId ?? '').trim().isEmpty ? 'n/a' : contactId!.trim()}, phoneNumber=$trimmedPhone, messageLength=${trimmedMessage.length}',
    );

    final endpoints = <String>[
      if ((contactId ?? '').trim().isNotEmpty)
        '/contact/contacts/${contactId!.trim()}/alert',
      '/contact/alert',
      '/emergency/contact-alert',
      '/emergency/contacts/alert',
    ];

    EmergencyApiException? lastError;

    for (final path in endpoints) {
      try {
        _logContactAlert('Trying endpoint: $path');
        final response = await _authorizedRequest(
          method: 'POST',
          path: path,
          body: payload,
        );
        _logContactAlert(
          'Send success via $path. Response=${jsonEncode(response)}',
        );
        return response;
      } on EmergencyApiException catch (e) {
        if (e.statusCode == 401) {
          _logContactAlert('Unauthorized while sending alert via $path');
          await logout();
          throw Exception('Invalid or expired token. Please re-login.');
        }
        if (e.statusCode == 404 || e.statusCode == 405) {
          _logContactAlert(
            'Endpoint unavailable at $path. status=${e.statusCode}, message=${e.message}',
          );
          lastError = e;
          continue;
        }
        _logContactAlert(
          'Send failed via $path. status=${e.statusCode}, message=${e.message}',
        );
        throw Exception(e.message);
      } catch (e) {
        _logContactAlert('Unexpected error via $path: $e');
        rethrow;
      }
    }

    _logContactAlert(
      'No backend SMS endpoint available. lastStatus=${lastError?.statusCode ?? 'n/a'}',
    );
    throw Exception(
      'Backend SMS alert endpoint is not available yet'
      '${lastError == null ? '.' : ' (${lastError.statusCode}).'}',
    );
  }

  static Future<Map<String, dynamic>> sendSilentCall({
    required String message,
    required List<Map<String, String>> contacts,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw Exception('Emergency message cannot be empty.');
    }
    if (contacts.isEmpty) {
      throw Exception('Select at least one emergency contact.');
    }

    final payload = <String, dynamic>{
      'message': trimmedMessage,
      'contacts': contacts
          .map(
            (contact) => <String, dynamic>{
              'contactId': (contact['contactId'] ?? '').trim(),
              'name': (contact['name'] ?? '').trim(),
              'phone': (contact['phone'] ?? '').trim(),
            },
          )
          .toList(),
    };

    const endpoints = <String>[
      '/emergency/silent-call',
      '/contact/silent-call',
      '/emergency/contacts/silent-call',
    ];

    EmergencyApiException? lastError;
    debugPrint(
      '[SilentCall] Sending silent call. contacts=${contacts.length}, messageLength=${trimmedMessage.length}',
    );

    for (final path in endpoints) {
      try {
        debugPrint('[SilentCall] Trying endpoint: $path');
        final response = await _authorizedRequest(
          method: 'POST',
          path: path,
          body: payload,
        );
        debugPrint(
          '[SilentCall] Success via $path. Response=${jsonEncode(response)}',
        );
        return response;
      } on EmergencyApiException catch (e) {
        if (e.statusCode == 401) {
          debugPrint('[SilentCall] Unauthorized via $path');
          await logout();
          throw Exception('Invalid or expired token. Please re-login.');
        }
        if (e.statusCode == 404 || e.statusCode == 405) {
          debugPrint(
            '[SilentCall] Endpoint unavailable at $path. status=${e.statusCode}, message=${e.message}',
          );
          lastError = e;
          continue;
        }
        debugPrint(
          '[SilentCall] Failed via $path. status=${e.statusCode}, message=${e.message}',
        );
        throw Exception(e.message);
      } catch (e) {
        debugPrint('[SilentCall] Unexpected error via $path: $e');
        rethrow;
      }
    }

    debugPrint(
      '[SilentCall] No backend endpoint available. lastStatus=${lastError?.statusCode ?? 'n/a'}',
    );
    throw Exception(
      'Backend Silent Call endpoint is not available yet'
      '${lastError == null ? '.' : ' (${lastError.statusCode}).'}',
    );
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

  static Future<http.Response> _sendAuthorizedJson({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    switch (method.toUpperCase()) {
      case 'PUT':
        return http.put(uri, headers: headers, body: jsonEncode(body));
      case 'PATCH':
        return http.patch(uri, headers: headers, body: jsonEncode(body));
      case 'POST':
        return http.post(uri, headers: headers, body: jsonEncode(body));
      default:
        throw ArgumentError('Unsupported method: $method');
    }
  }

  static Future<Map<String, dynamic>> startEmergency({
    Map<String, dynamic>? payload,
  }) async {
    Map<String, dynamic>? sanitizedPayload;
    if (payload != null) {
      sanitizedPayload = Map<String, dynamic>.from(payload);
      sanitizedPayload.removeWhere(
        (_, value) => value == null || '$value'.trim().isEmpty,
      );
    }
    if (kDebugMode) {
      final payloadEntries = sanitizedPayload == null
          ? <String>[]
          : sanitizedPayload.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .toList(growable: false);
      debugPrint(
        '[EmergencyStart] sending payload values: ${jsonEncode(payloadEntries)}',
      );
    }
    return _authorizedRequest(
      method: 'POST',
      path: '/emergency/start',
      body: sanitizedPayload == null || sanitizedPayload.isEmpty
          ? null
          : sanitizedPayload,
    );
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
      messagingSuccessful:
          response['ok'] == false ? true : (response['success'] != false),
      message: (response['message'] ?? 'Emergency started').toString(),
    );
  }

  static Future<Map<String, dynamic>> attemptEmergencyContactCall({
    required String sessionId,
    required int contactIndex,
    int? timeoutSec,
    Map<String, dynamic>? payload,
  }) async {
    Map<String, dynamic>? requestBody;
    if (payload != null) {
      requestBody = Map<String, dynamic>.from(payload);
      requestBody.removeWhere(
        (_, value) => value == null || '$value'.trim().isEmpty,
      );
    }
    if (timeoutSec != null) {
      requestBody ??= <String, dynamic>{};
      requestBody['timeoutSec'] = timeoutSec;
    }
    if (kDebugMode) {
      final payloadEntries = requestBody == null
          ? <String>[]
          : requestBody.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .toList(growable: false);
      debugPrint(
        '[EmergencyCallContact] sending payload values: ${jsonEncode(payloadEntries)}',
      );
    }
    return _authorizedRequest(
      method: 'POST',
      path: '/emergency/$sessionId/call/$contactIndex/attempt',
      body: requestBody == null || requestBody.isEmpty ? null : requestBody,
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
    Map<String, dynamic>? payload,
  }) async {
    Map<String, dynamic>? sanitizedPayload;
    if (payload != null) {
      sanitizedPayload = Map<String, dynamic>.from(payload);
      sanitizedPayload.removeWhere(
        (_, value) => value == null || '$value'.trim().isEmpty,
      );
    }
    if (kDebugMode) {
      final payloadEntries = sanitizedPayload == null
          ? <String>[]
          : sanitizedPayload.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .toList(growable: false);
      debugPrint(
        '[EmergencyCall119] sending payload values: ${jsonEncode(payloadEntries)}',
      );
    }
    return _authorizedRequest(
      method: 'POST',
      path: '/emergency/$sessionId/call-119',
      body: sanitizedPayload == null || sanitizedPayload.isEmpty
          ? null
          : sanitizedPayload,
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
