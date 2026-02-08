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
  }) async {
    try {
      final token = await AuthService.getToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/report/add'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      request.fields['reportContent'] = reportContent;
      request.fields['reportDate_time'] = DateTime.now().toIso8601String();

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

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
