import 'package:flutter/material.dart';

/// Minimal, clean design tokens and ThemeData for the "minimal" visual language.
class MinimalTokens {
  // Spacing scale
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;

  static const double radius8 = 8.0;
  static const double radius12 = 12.0;

  // Palette
  static const Color primary = Color(0xFF4666F6);
  static const Color surface = Color(0xFFF7F8FB);
  static const Color surfaceDark = Color(0xFF0B0D12);
  static const Color onSurface = Color(0xFF0F1724);
  static const Color muted = Color(0xFF6B7280);
}

ThemeData buildMinimalTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    primaryColor: MinimalTokens.primary,
    scaffoldBackgroundColor: isDark ? MinimalTokens.surfaceDark : MinimalTokens.surface,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: MinimalTokens.primary,
      onPrimary: Colors.white,
      secondary: MinimalTokens.primary.withOpacity(0.9),
      onSecondary: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
      background: isDark ? MinimalTokens.surfaceDark : MinimalTokens.surface,
      onBackground: isDark ? Colors.white : MinimalTokens.onSurface,
      surface: isDark ? const Color(0xFF0E1114) : Colors.white,
      onSurface: isDark ? Colors.white : MinimalTokens.onSurface,
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : MinimalTokens.onSurface),
      bodyMedium: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : MinimalTokens.onSurface),
      titleMedium: TextStyle(fontSize: 13, color: MinimalTokens.muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : MinimalTokens.onSurface),
      iconTheme: IconThemeData(color: isDark ? Colors.white : MinimalTokens.onSurface),
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF0F1316) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MinimalTokens.radius12)),
      margin: EdgeInsets.zero,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    useMaterial3: false,
  );
}
