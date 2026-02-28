import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class ApiService {
  static const String backendUrl = "http://10.0.2.2:5000";
  static final Battery _battery = Battery();

  // Fetch live safety score from backend using REAL device telemetry
  static Future<Map<String, dynamic>> getLiveSafetyScore(String jwt) async {
    int batteryLevel = 50; // Default
    bool isLocationEnabled = false;
    bool isMicrophoneEnabled = false;
    double? lat;
    double? lng;

    try {
      // 1. Fetch Battery Level
      batteryLevel = await _battery.batteryLevel;

      // 2. Check Permissions
      final locStatus = await Permission.location.status;
      isLocationEnabled = locStatus.isGranted;

      final micStatus = await Permission.microphone.status;
      isMicrophoneEnabled = micStatus.isGranted;

      // 3. Fetch GPS Coordinates (if enabled)
      if (isLocationEnabled) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
        );
        lat = position.latitude;
        lng = position.longitude;
      }
    } catch (e) {
      print("Error gathering hardware telemetry: $e");
    }

    final String localTime = DateTime.now().toIso8601String();

    final payload = {
      'batteryLevel': batteryLevel,
      'isLocationEnabled': isLocationEnabled,
      'isMicrophoneEnabled': isMicrophoneEnabled,
      'isToneSosActive': true, // Assuming active for this context
      'isSafePathActive': false, 
      'localTime': localTime,
      'latitude': lat ?? 6.9271, // Fallback to Colombo
      'longitude': lng ?? 79.8612,
    };

    final resp = await http.post(
      Uri.parse('$backendUrl/safety-score'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    } else {
      throw Exception("Failed to fetch live safety score");
    }
  }

  // Preserve other methods...
  static Future<String> login(String email, String password) async { /* ... */ return ""; }
  static Future<Map<String, dynamic>> createPaymentIntent(int amount, String jwt) async { return {}; }
  static Future<void> sendDistressSignal(String event, double confidence, String jwt) async { /* ... */ }
}
