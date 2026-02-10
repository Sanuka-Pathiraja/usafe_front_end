import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/config/safety_api_config.dart';
import 'features/auth/auth_service.dart';

Future<String?> _loadPlacesKeyFromPlatform() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  const channel = MethodChannel('usafe/config');
  try {
    final key = await channel.invokeMethod<String>('getGoogleMapsApiKey');
    return key?.trim().isEmpty == true ? null : key;
  } catch (_) {
    return null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Configure optional Google Places key from build-time env.
  const envKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  String? placesKey = envKey.trim().isEmpty ? null : envKey;
  placesKey ??= await _loadPlacesKeyFromPlatform();
  SafetyApiConfig.setGooglePlacesApiKey(placesKey);
  // App is optimized for Sri Lanka; past incidents use Sri Lanka data only (no Crimeometer/UK).
  await MockDatabase.loadUserSession();
  runApp(const USafeApp());
}
