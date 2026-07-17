import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';

enum DayPeriod { morning, day, night }

class HeaderAtmosphereWrapper extends StatefulWidget {
  final Widget child;
  final double radius;
  final Color themeColor;

  const HeaderAtmosphereWrapper({
    super.key,
    required this.child,
    this.radius = 36.0,
    required this.themeColor,
  });

  @override
  State<HeaderAtmosphereWrapper> createState() => _HeaderAtmosphereWrapperState();
}

class _HeaderAtmosphereWrapperState extends State<HeaderAtmosphereWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final List<NatureBeing> _beings = [];
  final List<NatureSpark> _sparks = [];
  
  Offset? _touchPos;
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  double _width = 350.0;
  double _height = 150.0;

  DayPeriod _getPeriod() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
      return DayPeriod.morning;
    } else if (hour >= 12 && hour < 18) {
      return DayPeriod.day;
    } else {
      return DayPeriod.night;
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _ticker.addListener(_onTick);

    // Initialize beings (set to 0 to disable fireflies as requested)
    final random = math.Random();
    for (int i = 0; i < 0; i++) {
      _beings.add(NatureBeing(
        x: 50.0 + random.nextDouble() * 250.0,
        y: 30.0 + random.nextDouble() * 90.0,
        size: 3.0 + random.nextDouble() * 3.0,
        alpha: 0.4 + random.nextDouble() * 0.5,
      ));
    }
  }

  @override
  void dispose() {
    _ticker.removeListener(_onTick);
    _ticker.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {
      for (final being in _beings) {
        being.update(_touchPos, _width, _height);
      }
      
      // Update tap sparks
      for (int i = _sparks.length - 1; i >= 0; i--) {
        _sparks[i].update();
        if (_sparks[i].alpha <= 0.01) {
          _sparks.removeAt(i);
        }
      }
    });
  }

  void _updateTouch(Offset localPos, Size size) {
    _width = size.width;
    _height = size.height;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    setState(() {
      _touchPos = localPos;
      // Smooth 3D tilt perspective limit
      _tiltX = ((localPos.dy - centerY) / centerY) * -0.06;
      _tiltY = ((localPos.dx - centerX) / centerX) * 0.06;
    });
  }

  void _resetTouch() {
    setState(() {
      _touchPos = null;
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  void _triggerScatter(Offset tapPos) {
    IrisHaptics.actionMedium();
    final random = math.Random();

    setState(() {
      // Scatter beings away from tap position
      for (final being in _beings) {
        final dx = being.x - tapPos.dx;
        final dy = being.y - tapPos.dy;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < 100.0) {
          final angle = dist > 0.1 ? math.atan2(dy, dx) : random.nextDouble() * 2 * math.pi;
          // Apply strong outward force
          final force = (120.0 - dist) / 15.0;
          being.vx = math.cos(angle) * (being.vx.abs() + force + 2.0);
          being.vy = math.sin(angle) * (being.vy.abs() + force + 2.0);
        }
      }

      // Add colorful glow sparks at tap position
      final period = _getPeriod();
      Color sparkColor;
      if (period == DayPeriod.morning) {
        sparkColor = const Color(0xFFF59E0B); // Golden
      } else if (period == DayPeriod.day) {
        sparkColor = const Color(0xFF10B981); // Emerald
      } else {
        sparkColor = const Color(0xFF00F2FE); // Cyan
      }

      for (int i = 0; i < 15; i++) {
        final angle = random.nextDouble() * 2 * math.pi;
        final speed = 1.5 + random.nextDouble() * 4.0;
        _sparks.add(NatureSpark(
          x: tapPos.dx,
          y: tapPos.dy,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          size: 1.5 + random.nextDouble() * 2.5,
          color: sparkColor,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final period = _getPeriod();

    return Listener(
      onPointerDown: (event) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          _updateTouch(event.localPosition, renderBox.size);
        }
      },
      onPointerMove: (event) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          _updateTouch(event.localPosition, renderBox.size);
        }
      },
      onPointerUp: (_) => _resetTouch(),
      onPointerCancel: (_) => _resetTouch(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          _triggerScatter(details.localPosition);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: IrisMotion.spring,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(_tiltX)
            ..rotateY(_tiltY),
          transformAlignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              // 1. Atmosphere Background Painter
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.radius),
                  child: CustomPaint(
                    painter: NatureAtmosphereBgPainter(
                      isDark: isDark,
                      period: period,
                      themeColor: widget.themeColor,
                    ),
                  ),
                ),
              ),

              // 2. Original Card Contents
              widget.child,

              // 3. Beings & Touch Sparks Painter Overlay
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.radius),
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: NatureBeingsPainter(
                        beings: _beings,
                        sparks: _sparks,
                        touchPos: _touchPos,
                        period: period,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NatureBeing {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  double angle;
  double angleSpeed;

  NatureBeing({
    required this.x,
    required this.y,
    required this.size,
    required this.alpha,
  })  : vx = 0,
        vy = 0,
        angle = math.Random().nextDouble() * 2 * math.pi,
        angleSpeed = 0.02 + math.Random().nextDouble() * 0.03;

  void update(Offset? touchPos, double width, double height) {
    if (touchPos != null) {
      // Swarm / Attract to touch pos
      final dx = touchPos.dx - x;
      final dy = touchPos.dy - y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > 8.0) {
        vx += (dx / dist) * 0.28;
        vy += (dy / dist) * 0.28;
      } else {
        // slow down near coordinates
        vx *= 0.85;
        vy *= 0.85;
      }
      
      // Speed clamp for swarming
      final speed = math.sqrt(vx * vx + vy * vy);
      if (speed > 5.0) {
        vx = (vx / speed) * 5.0;
        vy = (vy / speed) * 5.0;
      }
    } else {
      // Float organically (wandering behavior)
      angle += angleSpeed;
      vx += math.cos(angle) * 0.08;
      vy += math.sin(angle) * 0.08;
      
      // Friction and speed clamp for floating
      vx *= 0.96;
      vy *= 0.96;
      final speed = math.sqrt(vx * vx + vy * vy);
      if (speed > 1.4) {
        vx = (vx / speed) * 1.4;
        vy = (vy / speed) * 1.4;
      }
    }

    x += vx;
    y += vy;

    // Boundary wrap/bounce
    if (x < 10) { x = 10; vx = -vx * 0.8; }
    if (x > width - 10) { x = width - 10; vx = -vx * 0.8; }
    if (y < 10) { y = 10; vy = -vy * 0.8; }
    if (y > height - 10) { y = height - 10; vy = -vy * 0.8; }

    // Glow pulsing
    alpha = 0.35 + 0.5 * math.sin(angle * 1.8).abs();
  }
}

class NatureSpark {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  Color color;

  NatureSpark({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
  }) : alpha = 1.0;

  void update() {
    x += vx;
    y += vy;
    vy += 0.12; // slow fall gravity
    alpha -= 0.035;
    if (alpha < 0) alpha = 0.0;
  }
}

class NatureAtmosphereBgPainter extends CustomPainter {
  final bool isDark;
  final DayPeriod period;
  final Color themeColor;

  NatureAtmosphereBgPainter({
    required this.isDark,
    required this.period,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    // Draw background atmosphere gradient
    Gradient bgGradient;
    if (period == DayPeriod.morning) {
      bgGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                const Color(0xFF1E1E28),
                const Color(0xFF2E242C),
                const Color(0xFF1A1A24),
              ]
            : [
                const Color(0xFFFFF7ED),
                const Color(0xFFFFEDD5),
                const Color(0xFFFDBA74).withValues(alpha: 0.15),
              ],
      );
    } else if (period == DayPeriod.day) {
      bgGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                const Color(0xFF0F172A),
                const Color(0xFF1E293B),
                const Color(0xFF0F172A),
              ]
            : [
                const Color(0xFFF0FDF4),
                const Color(0xFFDCFCE7),
                themeColor.withValues(alpha: 0.08),
              ],
      );
    } else {
      bgGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                const Color(0xFF020617),
                const Color(0xFF0B132B),
                const Color(0xFF020617),
              ]
            : [
                const Color(0xFFFAF5FF),
                const Color(0xFFF3E8FF),
                const Color(0xFFD8B4FE).withValues(alpha: 0.1),
              ],
      );
    }

    final bgPaint = Paint()..shader = bgGradient.createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Draw Morning Sunbeams
    if (period == DayPeriod.morning) {
      final sunbeamPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFDBA74).withValues(alpha: isDark ? 0.08 : 0.22),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(size.width * 0.85, 20), radius: 120));
      canvas.drawCircle(Offset(size.width * 0.85, 20), 120, sunbeamPaint);
    }

    // Draw Day wind ripples / light streaks
    if (period == DayPeriod.day) {
      final ripplePaint = Paint()
        ..color = (isDark ? Colors.white : themeColor).withValues(alpha: isDark ? 0.025 : 0.045)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      
      final ripplePath = Path();
      ripplePath.moveTo(0, size.height * 0.3);
      ripplePath.cubicTo(size.width * 0.3, size.height * 0.2, size.width * 0.6, size.height * 0.5, size.width, size.height * 0.4);
      canvas.drawPath(ripplePath, ripplePaint);

      final ripplePath2 = Path();
      ripplePath2.moveTo(0, size.height * 0.7);
      ripplePath2.cubicTo(size.width * 0.4, size.height * 0.8, size.width * 0.7, size.height * 0.5, size.width, size.height * 0.65);
      canvas.drawPath(ripplePath2, ripplePaint);
    }

    // Draw Twilight / Night Stars
    if (period == DayPeriod.night) {
      final starPaint = Paint()
        ..color = Colors.white.withValues(alpha: isDark ? 0.25 : 0.12)
        ..style = PaintingStyle.fill;
      
      // Paint standard star pattern coordinates
      final starsList = [
        Offset(size.width * 0.1, size.height * 0.25),
        Offset(size.width * 0.25, size.height * 0.15),
        Offset(size.width * 0.45, size.height * 0.35),
        Offset(size.width * 0.72, size.height * 0.18),
        Offset(size.width * 0.88, size.height * 0.28),
        Offset(size.width * 0.3, size.height * 0.7),
      ];

      for (final star in starsList) {
        canvas.drawCircle(star, 1.0, starPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant NatureAtmosphereBgPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.period != period || oldDelegate.themeColor != themeColor;
}

class NatureBeingsPainter extends CustomPainter {
  final List<NatureBeing> beings;
  final List<NatureSpark> sparks;
  final Offset? touchPos;
  final DayPeriod period;

  NatureBeingsPainter({
    required this.beings,
    required this.sparks,
    required this.touchPos,
    required this.period,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw organic pulsing beings (fireflies / light blobs)
    for (final being in beings) {
      if (being.alpha <= 0.01) continue;

      // Outer glow bloom
      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFACC15).withValues(alpha: being.alpha * 0.25),
            const Color(0xFFEAB308).withValues(alpha: being.alpha * 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(being.x, being.y), radius: being.size * 3.5));
      
      canvas.drawCircle(Offset(being.x, being.y), being.size * 3.5, glowPaint);

      // Core firefly light
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: being.alpha * 0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(being.x, being.y), being.size * 0.9, corePaint);
    }

    // 2. Draw interactive sparks
    for (final spark in sparks) {
      if (spark.alpha <= 0.01) continue;

      final sparkPaint = Paint()
        ..color = spark.color.withValues(alpha: spark.alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(spark.x, spark.y), spark.size, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant NatureBeingsPainter oldDelegate) => true;
}
