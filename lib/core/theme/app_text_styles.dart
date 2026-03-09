import 'package:flutter/material.dart';

class AppTextStyles {
  /// Defines the core font family. "Inter" or "Roboto" are highly legible sans-serif fonts.
  static const String fontFamily = 'Roboto';

  static const TextTheme textThemeLight = TextTheme(
    // Large, high-impact numbers (e.g., Live Safety Score)
    displayLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 56,
      fontWeight: FontWeight.bold,
      letterSpacing: -1.5,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    // Standard Headers
    headlineLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 32,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    // Body Text (High Legibility for older/visually impaired users)
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    // Small Labels
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
  );

  static const TextTheme textThemeDark = textThemeLight; // Structure is identical, colors will be applied by the Theme layer
}
