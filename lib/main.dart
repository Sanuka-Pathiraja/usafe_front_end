import 'package:flutter/material.dart';
import 'config.dart';
import 'auth_screens.dart';

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

        // Professional Card Theme
        cardTheme: CardTheme(
          color: AppColors.surfaceCard,
          elevation: 8,
          shadowColor: Colors.black54,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),

        // AppBar Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.textWhite),
          titleTextStyle: TextStyle(
              color: AppColors.textWhite,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5),
        ),

        // Input Fields
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
      home: const SplashScreen(),
    );
  }
}
