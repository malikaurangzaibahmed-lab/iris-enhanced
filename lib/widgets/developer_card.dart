import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ui_feedback.dart';

/// Atmospheric animated Developer Card featuring dynamic moving cosmic gradients,
/// a starry halftone dot matrix pattern, and radiant spark icon.
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
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final angle = t * 2 * math.pi;

        // Oscillating gradient focal points
        final focalX = math.sin(angle) * 0.35;
        final focalY = 0.5 + math.cos(angle) * 0.25;

        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (isDark ? const Color(0xFF6366F1) : const Color(0xFF3B82F6))
                    .withValues(alpha: isDark ? 0.22 : 0.12),
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
                // 1. Moving Atmospheric Cosmic Gradient Background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF030712) : const Color(0xFFF8FAFC),
                      gradient: RadialGradient(
                        center: Alignment(focalX, focalY),
                        radius: 1.35,
                        colors: isDark
                            ? [
                                const Color(0xFF4338CA).withValues(alpha: 0.85), // Deep Royal Indigo
                                const Color(0xFF6B21A8).withValues(alpha: 0.65), // Nebula Violet
                                const Color(0xFF0E7490).withValues(alpha: 0.40), // Radiant Cyan
                                const Color(0xFF030712),                         // Deep Void
                              ]
                            : [
                                const Color(0xFF818CF8).withValues(alpha: 0.35),
                                const Color(0xFFC084FC).withValues(alpha: 0.25),
                                const Color(0xFF38BDF8).withValues(alpha: 0.20),
                                const Color(0xFFF1F5F9),
                              ],
                        stops: const [0.0, 0.40, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),

                // 2. Starry Halftone Dot Matrix Grid
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HalftoneDotsPainter(
                      isDark: isDark,
                      animationProgress: t,
                    ),
                  ),
                ),

                // 3. Ambient Glow Halo Behind Spark
                Positioned(
                  top: 30,
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
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                          BoxShadow(
                            color: const Color(0xFFE879F9).withValues(alpha: 0.35),
                            blurRadius: 32,
                            spreadRadius: 4,
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
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 10,
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
                                  ? Colors.black.withValues(alpha: 0.55)
                                  : Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: isDark ? 0.20 : 0.10),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
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
  }
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
      if (verticalFactor < 0.32) continue; // Upper area remains clean for text

      final rowOpacity = math.pow((verticalFactor - 0.32) / 0.68, 2.0).toDouble();

      for (int c = 0; c < cols; c++) {
        final x = c * spacing;

        // Subtle undulating wave
        final wave = math.sin((x / 28.0) + (animationProgress * 2 * math.pi) + (y / 24.0));
        final dotRadius = (0.75 + (verticalFactor * 1.35) + (wave * 0.25)).clamp(0.4, 2.4);

        final dotOpacity = (rowOpacity * (isDark ? 0.38 : 0.22) + (wave * 0.05))
            .clamp(0.0, isDark ? 0.45 : 0.28);

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
