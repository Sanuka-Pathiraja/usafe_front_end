import 'package:flutter/material.dart';

class AppColors {
  /// Primary trust and authority colors
  static const Color primary = Color(0xFF1E3A8A); // Deep Navy
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF172554); // Slate/Navy Dark

  /// Background and Surface colors for Light Theme
  static const Color backgroundLight = Color(0xFFF8FAFC); // Clean Light Slate
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A); // High Contrast Dark Slate
  static const Color textSecondaryLight = Color(0xFF475569);

  /// Background and Surface colors for Dark Theme
  static const Color backgroundDark = Color(0xFF0F172A); // Dark Slate
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // High Contrast Light Slate
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  /// High-Alert Action Colors (Strictly for Emergency)
  static const Color alert = Color(0xFFDC2626); // Vibrant Warning Red
  static const Color alertLight = Color(0xFFFEF2F2); // Tint for background
  static const Color alertDark = Color(0xFF991B1B);

  /// Success and Safe states
  static const Color safe = Color(0xFF059669); // Emerald Green
  
  /// Neutral Borders / Dividers
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);

  /// Disabled states
  static const Color disabledBackground = Color(0xFFE2E8F0);
  static const Color disabledText = Color(0xFF94A3B8);

  /// Compatibility with previous variable names if needed by Skeleton
  static const Color background = backgroundDark;
  static const Color surface = surfaceDark;
  static const Color textPrimary = textPrimaryDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color border = borderDark;
}
