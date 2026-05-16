import 'package:flutter/material.dart';

class NeoTokens {
  // Palette - Obsidian Dark
  static const Color onyx = Color(0xFF050505);
  static const Color surfaceDark = Color(0xFF0E0E10);
  static const Color surfaceDarkElevated = Color(0xFF161618);
  static const Color borderDark = Color(0xFF1F1F22);
  static const Color textDark = Color(0xFFF5F5F7);
  static const Color textDarkMuted = Color(0xFFA1A1A6);

  // Palette - Alabaster Light
  static const Color alabaster = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFBFBFD);
  static const Color surfaceLightElevated = Color(0xFFF5F5F7);
  static const Color borderLight = Color(0xFFE5E5E7);
  static const Color textLight = Color(0xFF1D1D1F);
  static const Color textLightMuted = Color(0xFF86868B);

  // Accents
  static const Color irisBlue = Color(0xFF007AFF);
  static const Color electricPurple = Color(0xFFBF5AF2);
  static const Color vividGreen = Color(0xFF30D158);
  static const Color alertRed = Color(0xFFFF453A);

  // Gradients
  static const List<Color> blueGradient = [Color(0xFF007AFF), Color(0xFF0A84FF)];
  static const List<Color> darkGradient = [onyx, Color(0xFF121214)];

  // Spacing & Radius
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius24 = 24.0;
  static const double radiusFull = 999.0;

  static const double space8 = 8.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
}

ThemeData buildNeoTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final surface = isDark ? NeoTokens.surfaceDark : NeoTokens.alabaster;
  final background = isDark ? NeoTokens.onyx : NeoTokens.surfaceLight;
  final text = isDark ? NeoTokens.textDark : NeoTokens.textLight;
  final border = isDark ? NeoTokens.borderDark : NeoTokens.borderLight;

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: background,
    primaryColor: NeoTokens.irisBlue,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: NeoTokens.irisBlue,
      onPrimary: Colors.white,
      secondary: NeoTokens.electricPurple,
      onSecondary: Colors.white,
      error: NeoTokens.alertRed,
      onError: Colors.white,
      background: background,
      onBackground: text,
      surface: surface,
      onSurface: text,
      outline: border,
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeoTokens.radius16),
        side: BorderSide(color: border, width: 1),
      ),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: text,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: text,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: text,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: isDark ? NeoTokens.textDarkMuted : NeoTokens.textLightMuted,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      iconTheme: IconThemeData(color: NeoTokens.irisBlue),
    ),
    useMaterial3: true,
  );
}
