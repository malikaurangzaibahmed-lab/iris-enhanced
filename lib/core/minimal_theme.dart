import 'package:flutter/material.dart';

/// Ultra-sleek Eco-OLED Low Power design tokens and ThemeData.
/// Designed for maximum battery preservation on OLED/AMOLED screens with zero GPU strain.
class MinimalTokens {
  // Spacing scale
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;

  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius24 = 24.0;

  // Ultra-Crisp Eco Palette
  static const Color primary = Color(0xFF38BDF8); // Crisp Sky Blue
  static const Color primaryDark = Color(0xFF0284C7);
  static const Color emerald = Color(0xFF10B981); // Crisp Emerald
  static const Color violet = Color(0xFF818CF8); // Neon Lavender

  // True OLED Black for dark mode (physical pixel shutdown = maximum battery saving)
  static const Color oledBlack = Color(0xFF000000);
  static const Color surfaceOledDark = Color(0xFF090B10);
  static const Color surfaceOledCard = Color(0xFF11141B);
  static const Color borderOledDark = Color(0xFF1E2433);

  // Pure Clean Light Mode
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceLightCard = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF0F172A);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF64748B);
}

ThemeData buildMinimalTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    primaryColor: MinimalTokens.primary,
    scaffoldBackgroundColor: isDark ? MinimalTokens.oledBlack : MinimalTokens.surfaceLight,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: MinimalTokens.primary,
      onPrimary: Colors.white,
      secondary: MinimalTokens.emerald,
      onSecondary: Colors.white,
      error: const Color(0xFFEF4444),
      onError: Colors.white,
      surface: isDark ? MinimalTokens.surfaceOledCard : MinimalTokens.surfaceLightCard,
      onSurface: isDark ? Colors.white : MinimalTokens.onSurfaceLight,
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: isDark ? Colors.white : MinimalTokens.onSurfaceLight,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: isDark ? Colors.white : MinimalTokens.onSurfaceLight,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: isDark ? const Color(0xFFCBD5E1) : MinimalTokens.onSurfaceLight,
      ),
      titleMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: MinimalTokens.muted,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: isDark ? Colors.white : MinimalTokens.onSurfaceLight,
      ),
      iconTheme: IconThemeData(
        color: isDark ? Colors.white : MinimalTokens.onSurfaceLight,
      ),
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: isDark ? MinimalTokens.surfaceOledCard : MinimalTokens.surfaceLightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MinimalTokens.radius24),
        side: BorderSide(
          color: isDark ? MinimalTokens.borderOledDark : MinimalTokens.borderLight,
          width: 1.0,
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerColor: isDark ? MinimalTokens.borderOledDark : MinimalTokens.borderLight,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    useMaterial3: false,
  );
}
