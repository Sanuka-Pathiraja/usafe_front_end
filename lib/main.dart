import 'package:flutter/material.dart';
import 'app.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MockDatabase.loadUserSession();
  runApp(const USafeApp());
}
