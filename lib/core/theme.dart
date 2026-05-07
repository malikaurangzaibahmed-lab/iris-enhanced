import 'package:flutter/material.dart';
import 'tokens.dart';

class IrisTheme {
  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = IrisTokens.brand;
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        surface: isDark ? IrisTokens.surfaceDark : IrisTokens.surfaceLight,
      ),
      scaffoldBackgroundColor: isDark ? IrisTokens.surfaceDark : IrisTokens.surfaceLight,
      fontFamily: IrisTokens.fontFamily,
      pageTransitionsTheme: IrisTokens.pageTransitions,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      
      cardTheme: CardThemeData(
        elevation: 0,
        shape: const ContinuousRectangleBorder(
          borderRadius: IrisTokens.cardRadius,
        ),
        color: isDark ? IrisTokens.surfaceDarkElevated : IrisTokens.surfaceLightElevated,
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 48),
          shape: const ContinuousRectangleBorder(
            borderRadius: IrisTokens.buttonRadius,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);
}
