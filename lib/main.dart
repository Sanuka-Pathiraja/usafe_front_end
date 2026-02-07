import 'package:flutter/material.dart';
import 'app.dart';
import 'features/auth/auth_service.dart'; // Make sure this has getToken() method

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional: You can pre-load the token to check if user is logged in
  final token = await AuthService.getToken();
  // You can also preload user info if needed
  // final user = await AuthService.getCurrentUser(); // if you implement this

  runApp(USafeApp());
}
