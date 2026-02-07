import 'package:flutter/material.dart';
import 'app.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // App is optimized for Sri Lanka; past incidents use Sri Lanka data only (no Crimeometer/UK).
  await MockDatabase.loadUserSession();
  runApp(const USafeApp());
}
