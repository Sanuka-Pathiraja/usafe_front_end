import 'package:flutter/material.dart';
import 'app.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final token = await AuthService.getToken();

  runApp(const USafeApp());
}
