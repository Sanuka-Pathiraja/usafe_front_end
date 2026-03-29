import 'package:flutter/material.dart';

/// Lightweight fade + slide-up transition used for all routes.
/// Much cheaper than the default Material 3 zoom because the outgoing page
/// is not kept alive and re-painted during the animation.
class _FadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class AppTheme {
  // ── Core Palette ──
  static const Color backgroundColor = Color(0xFF0A1128); // Deep Navy
  static const Color surfaceColor = Color(0xFF162244); // Elevated Navy
  static const Color primaryAccent = Color(0xFF00B47D); // Emerald / Safe Color
  static const Color emergencyAccent = Color(0xFFFF4B4B); // Action Color / SOS

  // ── Text Colors ──
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure White
  static const Color textSecondary = Color(0xFFB0B5C1); // Light Grey

  /// Master Dark Theme Configuration
  static ThemeData get darkTheme {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryAccent,

      // ── Color Scheme ──
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        onPrimary: textPrimary,
        secondary: primaryAccent, // fallback for accents
        error: emergencyAccent,
        onError: textPrimary,
        surface: surfaceColor,
        onSurface: textPrimary,
        background: backgroundColor,
        onBackground: textPrimary,
      ),

      // ── AppBar Theme ──
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // ── Card Theme (Flat Navy Cards) ──
      cardTheme: const CardThemeData(
        color: surfaceColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // ── Bottom Navigation Bar Theme ──
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundColor,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryAccent, // Emerald Green
        unselectedItemColor: textSecondary, // Muted Grey
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          color: primaryAccent,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        selectedIconTheme: IconThemeData(color: primaryAccent, size: 26),
        unselectedIconTheme: IconThemeData(color: textSecondary, size: 24),
      ),

      // ── Text Field Theme (Input Decoration) ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 16),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 16),

        // No harsh borders, just subtle un-bordered feel
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        // When focused, subtle emerald hint
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: emergencyAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: emergencyAccent, width: 2.0),
        ),
      ),

      // ── Elevated Button Theme ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: textPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48), // 48dp minimum height
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ── Global Typography Configurations ──
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        displayMedium:
            TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        displaySmall:
            TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        headlineLarge:
            TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        headlineMedium:
            TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        headlineSmall:
            TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w400), // Grey subtitles
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        labelMedium:
            TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
        labelSmall:
            TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
      ),

      dividerTheme: DividerThemeData(
        color: surfaceColor.withOpacity(0.5),
        space: 1,
        thickness: 1,
      ),

      iconTheme: const IconThemeData(color: textPrimary),

      // ── Page Transitions ──
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeSlideTransitionsBuilder(),
          TargetPlatform.iOS: _FadeSlideTransitionsBuilder(),
        },
      ),
    );
  }
}
