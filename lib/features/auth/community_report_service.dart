import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:usafe_front_end/features/auth/auth_service.dart';

class CommunityReportService {
  static const String baseUrl = "http://10.0.2.2:5000";

  /* ================= SUBMIT COMMUNITY REPORT ================= */
  static Future<Map<String, dynamic>> submitReport({
    required String reportContent,
    required List<File> images,
    String? location,
    List<String>? issueTypes,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token.isEmpty) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/report/add'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      request.fields['reportContent'] = reportContent;
      request.fields['reportDate_time'] = DateTime.now().toIso8601String();
      request.fields['location'] = (location == null || location.trim().isEmpty)
          ? 'Unknown'
          : location.trim();
      if (issueTypes != null && issueTypes.isNotEmpty) {
        request.fields['issueTypes'] = jsonEncode(issueTypes);
      }

      // Add images
      for (var image in images) {
        request.files.add(
          await http.MultipartFile.fromPath('images_proofs', image.path),
        );
      }

      // Send request
      var streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
          );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic parsed;
        try {
          parsed = jsonDecode(response.body);
        } catch (_) {
          parsed = {'message': response.body};
        }
        await AuthService.incrementLocalCommunityReportCount();
        return {
          'success': true,
          'data': parsed,
        };
      } else {
        if (response.statusCode == 401) {
          await AuthService.logout();
        }
        String backendError = 'Failed with status: ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic>) {
            backendError = (body['message'] ?? body['error'] ?? backendError)
                .toString();
          }
        } catch (_) {}
        return {
          'success': false,
          'error': backendError,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<int> getMyReportCount() async {
    return AuthService.fetchCommunityReportCount();
  }

  static Future<List<Map<String, dynamic>>> getMyReports() async {
    final token = await AuthService.getToken();
    if (token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/report/my-reports'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      await AuthService.logout();
      throw Exception('Invalid or expired token. Please re-login.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load reports (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded['reports'] is List) {
      return (decoded['reports'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (decoded is List) {
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  static Future<Map<String, dynamic>> getReportDetails(int reportId) async {
    final token = await AuthService.getToken();
    if (token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/report/$reportId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      await AuthService.logout();
      throw Exception('Invalid or expired token. Please re-login.');
    }

    if (response.statusCode == 404) {
      throw Exception('Report not found.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load report details (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded['report'] is Map) {
      return Map<String, dynamic>.from(decoded['report'] as Map);
    }
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Invalid report details response.');
  }

  static Future<Map<String, dynamic>> deleteReport(int reportId) async {
    final token = await AuthService.getToken();
    if (token.isEmpty) {
      return {
        'success': false,
        'error': 'Session expired. Please login again.',
      };
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/report/$reportId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      await AuthService.logout();
      return {
        'success': false,
        'error': 'Invalid or expired token. Please re-login.',
      };
    }

    if (response.statusCode == 404) {
      return {
        'success': false,
        'error': 'Report not found.',
      };
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {
        'success': false,
        'error': 'Failed to delete report (${response.statusCode})',
      };
    }

    if (response.body.isEmpty) {
      return {'success': true};
    }

    try {
      final decoded = jsonDecode(response.body);
      return {'success': true, 'data': decoded};
    } catch (_) {
      return {'success': true};
    }
  }
}
