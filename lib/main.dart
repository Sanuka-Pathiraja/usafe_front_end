import 'package:flutter/material.dart';
import 'app.dart';
import 'core/config/safety_api_config.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Configure optional Google Places key from build-time env.
  const placesKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  SafetyApiConfig.setGooglePlacesApiKey(placesKey);
  // App is optimized for Sri Lanka; past incidents use Sri Lanka data only (no Crimeometer/UK).
  await MockDatabase.loadUserSession();
  runApp(const USafeApp());
}
