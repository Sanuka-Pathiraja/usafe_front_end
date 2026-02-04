import 'package:flutter/material.dart';
import 'config.dart'; // Imports AppColors and MockDatabase
import 'auth_screens.dart'; // Imports LoginScreen
import 'home_screen.dart'; // Imports HomeScreen

/// ---------------------------------------------------------------------------
/// MAIN ENTRY POINT
/// ---------------------------------------------------------------------------

void main() async {
  // 1. Required for async operations like loading storage before app starts
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Check if a user is already logged in
  await MockDatabase.loadUserSession();

  runApp(const USafeApp());
}

class USafeApp extends StatelessWidget {
  const USafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'USafe',

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),

      // 3. LOGIC: If currentUser exists, go to Home. Otherwise, go to Login/Splash.
      // We skip SplashScreen if logged in for faster access,
      // or you can set home: const SplashScreen() and handle navigation there.
      home: MockDatabase.currentUser != null
          ? const HomeScreen()
          : const SplashScreen(),
    );
  }
}
