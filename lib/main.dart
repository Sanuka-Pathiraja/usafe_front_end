import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app.dart';
import 'features/auth/auth_service.dart';
import 'core/services/tone_sos_bridge_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/diagnostics_service.dart';
import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnvironment();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await Supabase.initialize(
    url: _readRequiredConfig('SUPABASE_URL'),
    anonKey: _readRequiredConfig('SUPABASE_KEY'),
  );
  await DiagnosticsService.runStartupDiagnostics();
  await MockDatabase.loadUserSession();
  await PushNotificationService.initialize();
  await PushNotificationService.syncTokenWithBackend();
  final toneSosBridge = ToneSOSBridgeService();
  await toneSosBridge.initialize();
  if (toneSosBridge.isReady) {
    toneSosBridge.startListening();
  }
  runApp(const USafeApp());
}

Future<void> _loadEnvironment() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Fallback for CI/dev workflows that pass secrets via --dart-define.
    dotenv.testLoad(
      mergeWith: <String, String>{
        'SUPABASE_URL':
            const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
        'SUPABASE_KEY':
            const String.fromEnvironment('SUPABASE_KEY', defaultValue: ''),
      },
    );
  }
}

String _readRequiredConfig(String key) {
  final value = dotenv.env[key]?.trim() ?? '';
  if (value.isEmpty) {
    throw StateError(
      'Missing required config "$key". Create a .env file (based on .env.example) '
      'or pass it with --dart-define.',
    );
  }
  return value;
}
