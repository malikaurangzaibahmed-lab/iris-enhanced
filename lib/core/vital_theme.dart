import 'package:flutter/material.dart';
import 'dart:math' as math;

class VitalTokens {
  // Surface Colors
  static const Color onyx = Color(0xFF000000);
  static const Color darkGrey = Color(0xFF0E0E10);
  static const Color obsidian = Color(0xFF0A0A0C); // Deep Obsidian
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF6F7FB);

  // Vital Palette
  static const Color blue = Color(0xFF007AFF);
  static const Color orange = Color(0xFFFF9500);
  static const Color green = Color(0xFF34C759);
  static const Color purple = Color(0xFF5856D6);
  static const Color pink = Color(0xFFFF2D55);
  static const Color cyan = Color(0xFF32ADE6);
  static const Color gold = Color(0xFFFFD700); // For God Mode / Premium

  // Semantic
  static const Color success = green;
  static const Color warning = orange;
  static const Color error = pink;
  static const Color info = blue;

  // Spacing & Radius
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radius28 = 28.0;
  static const double radius32 = 32.0;
  static const double radiusFull = 999.0;

  // Typography
  static const String fontFamily = 'SF Pro Display';

  static List<BoxShadow> softShadow(bool isDark) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.04),
        blurRadius: 32,
        spreadRadius: -8,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

ThemeData buildVitalTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? VitalTokens.obsidian : VitalTokens.offWhite;
  final surface = isDark ? const Color(0xFF161618) : VitalTokens.white;
  final text = isDark ? Colors.white : Colors.black;
  final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    primaryColor: VitalTokens.blue,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: VitalTokens.blue,
      onPrimary: Colors.white,
      secondary: VitalTokens.orange,
      onSecondary: Colors.white,
      error: VitalTokens.error,
      onError: Colors.white,
      background: background,
      onBackground: text,
      surface: surface,
      onSurface: text,
      surfaceVariant: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
      outline: border,
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VitalTokens.radius24),
        side: BorderSide(color: border, width: 1.2),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: text),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: text, letterSpacing: -1.0),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text, letterSpacing: -0.5),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: text),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: text),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: text.withValues(alpha: 0.7)),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: VitalTokens.blue),
    ),
  );
}

/// A premium, hardware-accelerated animated background for the Vital UI.
class ObsidianPulse extends StatefulWidget {
  final bool isDark;
  final List<Color>? pulseColors;

  const ObsidianPulse({
    required this.isDark,
    this.pulseColors,
    super.key,
  });

  @override
  State<ObsidianPulse> createState() => _ObsidianPulseState();
}

class _ObsidianPulseState extends State<ObsidianPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    
    return RepaintBoundary(
      child: Stack(
        children: [
          // Base Ambient Layer
          Container(color: isDark ? VitalTokens.obsidian : VitalTokens.offWhite),
          
          // Unified Animated Layer
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              return Stack(
                children: [
                  // Moving Glow Core
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          0.6 * math.sin(t * 2 * math.pi),
                          0.4 * math.cos(t * 2 * math.pi),
                        ),
                        colors: [
                          VitalTokens.blue.withValues(
                            alpha: isDark ? 0.12 : 0.08,
                          ),
                          Colors.transparent,
                        ],
                        radius: 1.5,
                      ),
                    ),
                  ),
                  
                  // Concentric Vital Rings
                  ...List.generate(3, (index) {
                    final ringT = (t + (index * 0.3)) % 1.0;
                    final scale = 0.5 + (ringT * 1.5);
                    final opacity = (1.0 - ringT).clamp(0.0, 1.0) * (isDark ? 0.15 : 0.10);
                    
                    return Center(
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: index == 0 
                                    ? VitalTokens.blue 
                                    : (index == 1 ? VitalTokens.purple : VitalTokens.cyan),
                                width: 2.0 / scale,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),

          // Noise/Overlay for Texture (Optimized: No separate Opacity widget)
          IgnorePointer(
            child: Container(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.02 : 0.015),
            ),
          ),
        ],
      ),
    );
  }
}
