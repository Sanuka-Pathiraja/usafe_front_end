import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'src/pages/splash_screen.dart';

class USafeApp extends StatelessWidget {
  final bool launchedFromSOSWidget;

  const USafeApp({
    super.key,
    this.launchedFromSOSWidget = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        // Using your custom constant for the background color
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        // Standardizing the red for emergency UI consistency
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: Brightness.dark,
        ),
      ),
      // The Splash Screen will handle the actual navigation logic
      home: SplashScreen(
        launchedFromSOSWidget: launchedFromSOSWidget,
      ),
    );
  }
}
