import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class DiagnosticsService {
  static Future<void> runStartupDiagnostics() async {
    print('\n=====================================');
    print('🚀 USAFE STARTUP HEALTH REPORT 🚀');
    print('=====================================\n');

    // 1. Check Supabase & Auth
    try {
      final supabase = Supabase.instance.client;
      print('✅ Supabase: Initialized successfully.');
      
      final session = supabase.auth.currentSession;
      if (session != null) {
        print('✅ Auth: User session is ACTIVE.');
      } else {
        print('⚠️ Auth: No active session (User needs to log in).');
      }
    } catch (e) {
      print('❌ Supabase: Initialization FAILED - $e');
    }

    // 2. Check Native Permissions
    try {
      final micStatus = await Permission.microphone.status;
      final locStatus = await Permission.location.status;
      print('🎤 Microphone: ${micStatus.isGranted ? "✅ GRANTED" : "❌ NOT GRANTED"}');
      print('📍 Location: ${locStatus.isGranted ? "✅ GRANTED" : "❌ NOT GRANTED"}');
    } catch (e) {
      print('❌ Permissions Check FAILED - $e');
    }

    print('\n=====================================\n');
  }
}
