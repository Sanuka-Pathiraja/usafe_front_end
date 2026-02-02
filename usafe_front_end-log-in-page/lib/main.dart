import 'package:flutter/material.dart';
import 'config.dart'; // Connects your colors
import 'auth_screens.dart'; // Connects Splash, Login
import 'home_screen.dart'; // <--- MAKE SURE THIS IS IMPORTED

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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primarySky,
        useMaterial3: true,
        fontFamily: 'Roboto',
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
      // CHANGE THIS LINE BELOW:
      home: const HomeScreen(),
    );
  }
}
