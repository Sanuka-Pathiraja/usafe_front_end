import 'package:flutter/material.dart';
import 'auth_screens.dart';
import 'config.dart';

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
        // Ensures inputs look good everywhere
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
      home: SplashScreen(),
    );
  }
}
