import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/vital_motion.dart';

class VitalRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color color;
  final IconData? icon;
  final String? label;
  final String? value;

  const VitalRing({
    required this.progress,
    this.size = 120.0,
    this.strokeWidth = 12.0,
    required this.color,
    this.icon,
    this.label,
    this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Background Track
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: 1.0,
                  color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                  strokeWidth: strokeWidth,
                ),
              ),
            ),
            // Progress Ring
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: VitalMotion.slow,
              curve: VitalMotion.smoothEntrance,
              builder: (context, val, _) => SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: val,
                    color: color,
                    strokeWidth: strokeWidth,
                    useGradient: true,
                  ),
                ),
              ),
            ),
            // Center Icon/Content
            if (icon != null)
              Icon(
                icon,
                size: size * 0.35,
                color: color,
              )
            else if (value != null)
              Text(
                value!,
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
          ],
        ),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(
            label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool useGradient;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    this.useGradient = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (useGradient && progress > 0.01) {
      paint.shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.5),
          color,
        ],
        stops: const [0.0, 1.0],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
