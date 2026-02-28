import 'package:flutter/material.dart';
import 'app.dart';
import 'features/auth/auth_service.dart';
import 'core/services/tone_sos_bridge_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/diagnostics_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Before dotenv.load');
  await dotenv.load();
  print('After dotenv.load');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_KEY']!,
  );
  print('After Supabase.initialize');
  await DiagnosticsService.runStartupDiagnostics();
  print('After DiagnosticsService');
  await MockDatabase.loadUserSession();
  print('After MockDatabase.loadUserSession');
  await ToneSOSBridgeService().initialize();
  print('After ToneSOSBridgeService.initialize');
  ToneSOSBridgeService().startListening();
  print('After ToneSOSBridgeService.startListening');
  runApp(const USafeApp());
  print('After runApp');
}
