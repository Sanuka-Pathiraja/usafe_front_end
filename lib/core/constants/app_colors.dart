import 'package:flutter/material.dart';

class AppColors {
  // Base Backgrounds (Modern Slate)
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceElevated = Color(0xFF334155);

  // Accents (Trustworthy Blue)
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF2563EB);
  
  // Emergency/Alerts (High Contrast Red)
  static const Color alert = Color(0xFFEF4444);
  static const Color alertDark = Color(0xFFDC2626);
  static const Color alertBg = Color(0x33EF4444); // 20% opacity

  // Success/Safe (Emerald Green)
  static const Color success = Color(0xFF10B981);
  
  // Typography
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFF475569);

  // Borders & Dividers
  static const Color border = Color(0xFF334155);
  
  // Aliases for compatibility
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color surfaceCard = surface;
  static const Color primarySky = primary;
  static const Color primaryNavy = primaryDark;
  static const Color safetyTeal = success;
  static const Color alertRed = alert;
  static const Color textGrey = textSecondary;
  static const Color successGreen = success;
  static const Color bgDark = background;
  static const Color bgLight = surface;
  static const Color textSub = textSecondary;
  static const Color glass = Color(0x1AF8FAFC);
  static const Color glassBorder = Color(0x33F8FAFC);
}
