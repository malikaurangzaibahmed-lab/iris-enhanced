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
      duration: const Duration(seconds: 24),
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
    final dotColor = isDark 
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.black.withValues(alpha: 0.04);
        
    return RepaintBoundary(
      child: Stack(
        children: [
          // Base Background
          Container(
            color: isDark ? VitalTokens.obsidian : VitalTokens.offWhite,
          ),
          
          // Soft Animated Ambient Blobs (Drifting slowly)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              final angle = t * 2 * math.pi;
              
              // Blob 1: Top-Right / Center-Right area
              final blob1X = 0.25 * math.sin(angle);
              final blob1Y = 0.18 * math.cos(angle);
              
              // Blob 2: Bottom-Left / Center-Left area
              final blob2X = 0.25 * math.cos(angle + math.pi);
              final blob2Y = 0.18 * math.sin(angle + math.pi);
              
              return Stack(
                children: [
                  // Blue Blob (Top Right)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0.4 + blob1X, -0.3 + blob1Y),
                          radius: 1.5,
                          colors: [
                            VitalTokens.blue.withValues(alpha: isDark ? 0.06 : 0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Purple/Indigo Blob (Bottom Left)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(-0.4 + blob2X, 0.3 + blob2Y),
                          radius: 1.5,
                          colors: [
                            VitalTokens.purple.withValues(alpha: isDark ? 0.05 : 0.03),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Clean Professional Dot Grid Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _DotGridPainter(color: dotColor),
                ),
              ),
            ),
          ),
          
          // Very subtle gradient overlay to fade grid at the edges
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.4,
                    colors: [
                      Colors.transparent,
                      (isDark ? VitalTokens.obsidian : VitalTokens.offWhite).withValues(alpha: 0.18),
                      isDark ? VitalTokens.obsidian : VitalTokens.offWhite,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  const _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    const spacing = 32.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => color != oldDelegate.color;
}
