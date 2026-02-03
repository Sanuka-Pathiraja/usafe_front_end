import 'package:flutter/material.dart';
import 'config.dart';
import 'auth_screens.dart'; // Ensure this is imported

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
        useMaterial3: true,
      ),
      // CHANGE THIS LINE:
      home: const SplashScreen(),
    );
  }
}
