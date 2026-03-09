import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'src/pages/splash_screen.dart';

class USafeApp extends StatelessWidget {
  const USafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USafe',
      debugShowCheckedModeBanner: false,

      // Injecting the new Design System
      theme: AppTheme.darkTheme, // 👉 Locks in the new Master Theme
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // Keeping the original skeleton logic
      home: const SplashScreen(),
    );
  }
}
