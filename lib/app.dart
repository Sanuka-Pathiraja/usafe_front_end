import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'src/pages/splash_screen.dart'; // make sure path is correct

class USafeApp extends StatelessWidget {
  const USafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: SplashScreen(), // ❌ removed const
    );
  }
}
