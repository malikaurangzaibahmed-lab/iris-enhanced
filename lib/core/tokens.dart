import 'package:flutter/material.dart';

class IrisTokens {
  static const Color brand = Color(0xFF007AFF); 
  static const Color brandLight = Color(0xFF58A1FF);
  static const Color brandDark = Color(0xFF0056B3);
  static const Color surfaceDark = Color(0xFF000000); 
  static const Color surfaceLightElevated = Color(0xFFFFFFFF);
  static const List<Color> brandGradient = [brand, brandLight];

  static const List<Color> sunsetGradient = [
    Color(0xFFFF6B9D),
    Color(0xFFC239B3),
  ];
  static const List<Color> oceanGradient = [
    Color(0xFF00C9FF),
    Color(0xFF92FE9D),
  ];
  static const List<Color> successGradient = [
    Color(0xFF00E5A0),
    Color(0xFF00D9F5),
  ];

  static const Color surfaceLight = Color(0xFFF2F2F7); 
  static const Color surfaceDarkElevated = Color(0xFF1C1C1E); 

  static const Color success = Color(0xFF00E5A0);
  static const Color successDark = Color(0xFF00D9F5);
  static const Color warning = Color(0xFFFFB800);
  static const Color warningDark = Color(0xFFFF8A00);
  static const Color error = Color(0xFFFF6B6B);
  static const Color errorDark = Color(0xFFFF4757);
  static const Color info = Color(0xFF5B7FFF);

  static const Color purple = Color(0xFF8B6EFF);
  static const Color purpleLight = Color(0xFFB794F6);
  static const Color blue = Color(0xFF5B9EFF);
  static const Color blueLight = Color(0xFF8BB5FF);
  static const Color pink = Color(0xFFFF6B9D);
  static const Color pinkLight = Color(0xFFFFB3C6);
  static const Color teal = Color(0xFF00D9F5);
  static const Color tealLight = Color(0xFF7FEFFF);

  static const String fontFamily = 'SF Pro Display';

  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;

  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radius28 = 28.0;
  static const double radius32 = 32.0;
  static const double radius36 = 36.0;
  static const double radiusFull = 9999.0;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(14));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(10));

  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );
}

class IrisVibrancy {
  static double thin(bool isDark) => isDark ? 0.45 : 0.70;
  static double ultraThin(bool isDark) => isDark ? 0.30 : 0.55;
  static double thick(bool isDark) => isDark ? 0.75 : 0.90;
  
  static Color color(BuildContext context, {double opacity = 0.5}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return (isDark ? Colors.black : Colors.white).withValues(alpha: opacity);
  }
}

class IrisTextStyles {
  static TextStyle display(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w200,
      letterSpacing: -0.5,
      height: 1.1,
      color: isDark ? Colors.white : Colors.black,
    );
  }

  static TextStyle title(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w300,
      letterSpacing: 0.5,
      height: 1.2,
      color: isDark ? Colors.white : Colors.black,
    );
  }

  static TextStyle headline(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      height: 1.3,
      color: isDark ? Colors.white : Colors.black,
    );
  }

  static TextStyle body(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.1,
      height: 1.5,
      color: isDark
          ? Colors.white.withValues(alpha: 0.88)
          : Colors.black.withValues(alpha: 0.87),
    );
  }

  static TextStyle label(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      height: 1.4,
      color: isDark
          ? Colors.white.withValues(alpha: 0.82)
          : Colors.black.withValues(alpha: 0.78),
    );
  }

  static TextStyle caption(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      height: 1.3,
      color: isDark
          ? Colors.white.withValues(alpha: 0.64)
          : Colors.black.withValues(alpha: 0.6),
    );
  }

  static TextStyle overline(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      height: 1.2,
      color: isDark
          ? Colors.white.withValues(alpha: 0.58)
          : Colors.black.withValues(alpha: 0.54),
    );
  }
}

class IrisElevation {
  static List<BoxShadow> level1(Color color, {bool isDark = false}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        offset: const Offset(0, 2),
        blurRadius: 8,
        spreadRadius: -2,
      ),
    ];
  }

  static List<BoxShadow> level2(Color color, {bool isDark = false}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
        offset: const Offset(0, 6),
        blurRadius: 18,
        spreadRadius: -6,
      ),
    ];
  }

  static List<BoxShadow> level3(Color color, {bool isDark = false}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.24),
        offset: const Offset(0, 10),
        blurRadius: 30,
        spreadRadius: -12,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.17 : 0.06),
        offset: const Offset(0, 4),
        blurRadius: 14,
      ),
    ];
  }

  static List<BoxShadow> level4(Color color, {bool isDark = false}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.30),
        offset: const Offset(0, 16),
        blurRadius: 44,
        spreadRadius: -16,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
        offset: const Offset(0, 6),
        blurRadius: 18,
      ),
    ];
  }
}
