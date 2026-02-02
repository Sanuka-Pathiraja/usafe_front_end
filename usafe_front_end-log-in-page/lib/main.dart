import 'package:flutter/material.dart';
import 'config.dart'; // Connects your colors and MockDatabase
import 'auth_screens.dart'; // Connects Splash, Login, and Signup

void main() {
  runApp(const USafeApp());
}

class USafeApp extends StatelessWidget {
  const USafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'USafe',

      // Applying the Modern Dark Theme globally
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primarySky,
        useMaterial3: true,
        fontFamily: 'Roboto',

        // Modernized Input Field Theme for the whole app
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceCard,
          labelStyle: const TextStyle(color: AppColors.textGrey),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          prefixIconColor: AppColors.primarySky,
        ),
      ),

      // Start the app at the modernized Splash Screen
      home: const SplashScreen(),
    );
  }
}
