import 'package:flutter/material.dart';
import 'config.dart'; // Imports global AppColors and configuration
import 'auth_screens.dart'; // Imports the SplashScreen for initial launch

/// ---------------------------------------------------------------------------
/// MAIN ENTRY POINT
///
/// This file is the root of the USafe application.
/// It is responsible for:
/// 1. Initializing the Flutter engine.
/// 2. Setting up the global visual theme (Dark Mode, Brand Colors).
/// 3. Defining the first screen the user sees (Splash Screen).
/// ---------------------------------------------------------------------------

void main() {
  // Inflate the widget tree and attach it to the screen
  runApp(const USafeApp());
}

/// The Root Widget of the application.
class USafeApp extends StatelessWidget {
  const USafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Hides the small "Debug" banner in the top-right corner
      debugShowCheckedModeBanner: false,

      // App Title (visible in Task Manager / Recent Apps)
      title: 'USafe',

      // --- GLOBAL THEME CONFIGURATION ---
      theme: ThemeData(
        brightness: Brightness.dark, // Enforce Dark Mode globally
        scaffoldBackgroundColor:
            AppColors.background, // Set the brand background color
        useMaterial3: true, // Use latest Material Design 3 components
      ),

      // --- APP STARTUP SCREEN ---
      // We start at the SplashScreen, which handles the logic to check
      // if the user is logged in or needs to authenticate.
      home: const SplashScreen(),
    );
  }
}
