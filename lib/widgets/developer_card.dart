import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme_signals.dart';
import '../services/ui_feedback.dart';

/// Atmospheric animated Developer Card featuring dynamic moving cosmic gradients,
/// a starry halftone dot matrix pattern, and radiant prism sparkle icon inspired by the Gemini interface.
class DeveloperCard extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onTap;

  const DeveloperCard({
    required this.isDark,
    this.onTap,
    super.key,
  });

  @override
  State<DeveloperCard> createState() => _DeveloperCardState();
}

class _DeveloperCardState extends State<DeveloperCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (!ThemeSignals.useMinimalTheme.value) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openEmail() async {
    IrisHaptics.actionMedium();
    final uri = Uri.parse('mailto:malikaurangzaibahmed@gmail.com?subject=IRIS%20Inquiry');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useMinimalTheme,
      builder: (context, useMinimal, _) {
        if (useMinimal && _controller.isAnimating) {
          _controller.stop();
        } else if (!useMinimal && !_controller.isAnimating) {
          _controller.repeat();
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = useMinimal ? 0.0 : _controller.value;

        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (isDark ? const Color(0xFF6366F1) : const Color(0xFF3B82F6))
                    .withValues(alpha: isDark ? 0.25 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: isDark ? 0.14 : 0.08),
              width: 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                // 1. Fluid Moving Cosmic Gradient Mesh
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MovingCosmicMeshPainter(
                      isDark: isDark,
                      progress: t,
                    ),
                  ),
                ),

                // 2. Starry Halftone White Dot Matrix Grid (Gemini Texture)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HalftoneDotsPainter(
                      isDark: isDark,
                      animationProgress: t,
                    ),
                  ),
                ),

                // 3. Subtle Ambient Glow Halo Behind Prism Spark
                Positioned(
                  top: 26,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _getDynamicSparkGlow(t).withValues(alpha: isDark ? 0.45 : 0.25),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Foreground Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Radiant 4-Point Prism Spark Star
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CustomPaint(
                          painter: _PrismSparkPainter(pulse: t),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Developer Name
                      Text(
                        'Malik Aurangzaib Ahmed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          shadows: isDark
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Interactive Email Contact Pill
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openEmail,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.60)
                                  : Colors.white.withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: isDark ? 0.22 : 0.12),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.mail_outline_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Text(
                                  'malikaurangzaibahmed@gmail.com',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.1,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);
}

  Color _getDynamicSparkGlow(double t) {
    // Cycles between Cyan, Blue, Purple, and Magenta
    final phase = (t * 4) % 4;
    if (phase < 1.0) {
      return Color.lerp(const Color(0xFF06B6D4), const Color(0xFF3B82F6), phase)!;
    } else if (phase < 2.0) {
      return Color.lerp(const Color(0xFF3B82F6), const Color(0xFF8B5CF6), phase - 1.0)!;
    } else if (phase < 3.0) {
      return Color.lerp(const Color(0xFF8B5CF6), const Color(0xFFD946EF), phase - 2.0)!;
    } else {
      return Color.lerp(const Color(0xFFD946EF), const Color(0xFF06B6D4), phase - 3.0)!;
    }
  }
}

/// Paints the animated moving cosmic gradient mesh inspired by Google Gemini
class _MovingCosmicMeshPainter extends CustomPainter {
  final bool isDark;
  final double progress;

  _MovingCosmicMeshPainter({
    required this.isDark,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Solid Base Background
    final baseColor = isDark ? const Color(0xFF030712) : const Color(0xFFF8FAFC);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = baseColor);

    final angle = progress * 2 * math.pi;

    // Color Palette Transition (Blue -> Purple -> Magenta -> Indigo -> Blue)
    final color1 = _cycleColor(progress, const [
      Color(0xFF2563EB), // Royal Blue
      Color(0xFF7C3AED), // Violet
      Color(0xFFC026D3), // Fuchsia / Magenta
      Color(0xFF0284C7), // Sky Blue
    ]);

    final color2 = _cycleColor(progress + 0.33, const [
      Color(0xFF9333EA), // Purple
      Color(0xFFE11D48), // Rose
      Color(0xFF06B6D4), // Cyan
      Color(0xFF4F46E5), // Indigo
    ]);

    final color3 = _cycleColor(progress + 0.66, const [
      Color(0xFF0E7490), // Cyan-blue
      Color(0xFF4338CA), // Deep Indigo
      Color(0xFFA21CAF), // Magenta
      Color(0xFF1D4ED8), // Blue
    ]);

    // 2. Primary Moving Orb (Bottom Center / Left)
    final orb1X = w * (0.35 + math.sin(angle) * 0.25);
    final orb1Y = h * (0.85 + math.cos(angle) * 0.15);
    final orb1Radius = w * 0.95;

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          color1.withValues(alpha: isDark ? 0.75 : 0.35),
          color1.withValues(alpha: isDark ? 0.40 : 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(orb1X, orb1Y), radius: orb1Radius));

    canvas.drawCircle(Offset(orb1X, orb1Y), orb1Radius, paint1);

    // 3. Secondary Moving Orb (Bottom Center / Right)
    final orb2X = w * (0.65 + math.cos(angle + math.pi / 3) * 0.25);
    final orb2Y = h * (0.90 + math.sin(angle + math.pi / 3) * 0.15);
    final orb2Radius = w * 0.85;

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          color2.withValues(alpha: isDark ? 0.70 : 0.30),
          color2.withValues(alpha: isDark ? 0.35 : 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(orb2X, orb2Y), radius: orb2Radius));

    canvas.drawCircle(Offset(orb2X, orb2Y), orb2Radius, paint2);

    // 4. Center Ambient Atmosphere
    final orb3X = w * (0.50 + math.sin(angle * 1.5) * 0.15);
    final orb3Y = h * 0.60;
    final orb3Radius = w * 0.75;

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          color3.withValues(alpha: isDark ? 0.45 : 0.20),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(orb3X, orb3Y), radius: orb3Radius));

    canvas.drawCircle(Offset(orb3X, orb3Y), orb3Radius, paint3);
  }

  Color _cycleColor(double p, List<Color> colors) {
    final normalized = p % 1.0;
    final count = colors.length;
    final index = (normalized * count).floor();
    final nextIndex = (index + 1) % count;
    final t = (normalized * count) - index;
    return Color.lerp(colors[index], colors[nextIndex], t)!;
  }

  @override
  bool shouldRepaint(covariant _MovingCosmicMeshPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

/// Paints the multicolored 4-point prism sparkle star
class _PrismSparkPainter extends CustomPainter {
  final double pulse;

  _PrismSparkPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final scale = 1.0 + (math.sin(pulse * 2 * math.pi) * 0.04);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);
    canvas.translate(-cx, -cy);

    final path = Path();
    // Top point
    path.moveTo(cx, 0);
    // Curve to Right point
    path.quadraticBezierTo(cx + (w * 0.12), cy - (h * 0.12), w, cy);
    // Curve to Bottom point
    path.quadraticBezierTo(cx + (w * 0.12), cy + (h * 0.12), cx, h);
    // Curve to Left point
    path.quadraticBezierTo(cx - (w * 0.12), cy + (h * 0.12), 0, cy);
    // Curve back to Top point
    path.quadraticBezierTo(cx - (w * 0.12), cy - (h * 0.12), cx, 0);
    path.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFEA4335), // Red / Coral
          Color(0xFFFBBC04), // Amber / Gold
          Color(0xFF34A853), // Emerald
          Color(0xFF4285F4), // Sky Blue
          Color(0xFFA855F7), // Violet
        ],
        stops: [0.0, 0.28, 0.52, 0.78, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PrismSparkPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

/// Paints the starry halftone white dot matrix grid with soft vertical fading
class _HalftoneDotsPainter extends CustomPainter {
  final bool isDark;
  final double animationProgress;

  _HalftoneDotsPainter({
    required this.isDark,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 11.5;
    final int cols = (size.width / spacing).ceil() + 1;
    final int rows = (size.height / spacing).ceil() + 1;

    final basePaint = Paint()..style = PaintingStyle.fill;

    for (int r = 0; r < rows; r++) {
      final y = r * spacing;
      // Fade dots upwards (most dense at bottom, fading to transparent towards top)
      final verticalFactor = (y / size.height).clamp(0.0, 1.0);
      if (verticalFactor < 0.28) continue; // Upper area remains clean for text

      final rowOpacity = math.pow((verticalFactor - 0.28) / 0.72, 2.0).toDouble();

      for (int c = 0; c < cols; c++) {
        final x = c * spacing;

        // Subtle undulating shimmer wave
        final wave = math.sin((x / 28.0) + (animationProgress * 2 * math.pi) + (y / 24.0));
        final dotRadius = (0.80 + (verticalFactor * 1.40) + (wave * 0.25)).clamp(0.4, 2.5);

        final dotOpacity = (rowOpacity * (isDark ? 0.42 : 0.25) + (wave * 0.06))
            .clamp(0.0, isDark ? 0.55 : 0.32);

        basePaint.color = (isDark ? Colors.white : const Color(0xFF0F172A))
            .withValues(alpha: dotOpacity);

        canvas.drawCircle(Offset(x, y), dotRadius, basePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HalftoneDotsPainter oldDelegate) =>
      oldDelegate.animationProgress != animationProgress ||
      oldDelegate.isDark != isDark;
}
