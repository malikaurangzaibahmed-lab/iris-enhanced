import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import '../widgets/nature_particles.dart';
import '../services/ui_feedback.dart';
import '../core/tokens.dart';
import '../widgets/smart_widgets.dart';
import '../services/analytics_manager.dart';

// ==========================================================================
// STUDENTS WEEK HEADER CARD WITH LOOPING MULTI-MODE VECTOR ANIMATIONS
// ==========================================================================

class StudentsWeekHeaderCard extends StatelessWidget {
  final String userName;
  final String batch;
  final VoidCallback onToggleTheme;

  const StudentsWeekHeaderCard({
    required this.userName,
    required this.batch,
    required this.onToggleTheme,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StudentsWeekAnimationWidget(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "STUDENTS' WEEK ${DateTime.now().year}",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unleash the\nAthletic Brain',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "No normal classes this week! Tap the card to cycle activities. Don't forget your timetable at the bottom.",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}

// ==========================================================================
// LOOPING MULTI-MODE ANIMATION WIDGET (CRICKET, FOOTBALL, MASCOT, CONCERT)
// ==========================================================================

enum StudentsWeekAnimationMode { cricket, football, animals, singers }

class StudentsWeekAnimationWidget extends StatefulWidget {
  final Widget child;
  const StudentsWeekAnimationWidget({required this.child, super.key});

  @override
  State<StudentsWeekAnimationWidget> createState() => _StudentsWeekAnimationWidgetState();
}

class _StudentsWeekAnimationWidgetState extends State<StudentsWeekAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<StudentsWeekParticle> _particles = [];
  
  StudentsWeekAnimationMode _mode = StudentsWeekAnimationMode.cricket;
  int _cycleCount = 0;
  bool _showText = false;
  double _textOpacity = 0.0;
  double _textScale = 0.0;
  bool _hasHit = false;
  bool _isTapTriggered = false;
  
  double _lastWidth = 350.0;
  double _lastHeight = 150.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..repeat();

    _controller.addListener(_updateAnimation);
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_isTapTriggered) {
          _isTapTriggered = false;
        }
        _controller.repeat();
      }
    });
  }

  Color _getModeParticleColor(StudentsWeekAnimationMode mode, math.Random random) {
    switch (mode) {
      case StudentsWeekAnimationMode.cricket:
        return random.nextBool() ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
      case StudentsWeekAnimationMode.football:
        return random.nextBool() ? Colors.white : const Color(0xFFF59E0B);
      case StudentsWeekAnimationMode.animals:
        return random.nextBool() ? const Color(0xFFE28743) : const Color(0xFFF59E0B);
      case StudentsWeekAnimationMode.singers:
        return random.nextBool() ? const Color(0xFFEC4899) : const Color(0xFF8B5CF6);
    }
  }

  void _updateAnimation() {
    final t = _controller.value;

    // Reset hit flag at cycle start
    if (t < 0.02) {
      _hasHit = false;
      _showText = false;
      _textOpacity = 0.0;
      _textScale = 0.0;
      _particles.clear();

      // Cycle mode naturally every 2 loops if not tapped
      if (!_isTapTriggered) {
        _cycleCount++;
        if (_cycleCount >= 2) {
          _cycleCount = 0;
          setState(() {
            _mode = StudentsWeekAnimationMode.values[
                (_mode.index + 1) % StudentsWeekAnimationMode.values.length];
          });
        }
      }
    }

    // Determine impact moment
    double impactT = 0.4;
    if (_mode == StudentsWeekAnimationMode.football) {
      impactT = 0.6; // hits goal net
    }

    final double cx = _lastWidth * 0.82;
    final double cy = _lastHeight * 0.48;

    if (t >= impactT && t < 0.8 && !_hasHit) {
      _hasHit = true;
      _showText = true;
      IrisHaptics.actionHeavy(); // Heavy vibration on hit

      final random = math.Random();
      final particleCount = _isTapTriggered ? 45 : 24;

      switch (_mode) {
        case StudentsWeekAnimationMode.cricket:
          // Emerald green & gold particle burst
          for (int i = 0; i < particleCount; i++) {
            final angle = -random.nextDouble() * math.pi * 0.7; // upwards arcs
            final speed = 3.0 + random.nextDouble() * 6.5;
            _particles.add(StudentsWeekParticle(
              x: cx - 25.0,
              y: cy + 15.0,
              vx: math.cos(angle) * speed,
              vy: math.sin(angle) * speed,
              size: 2.0 + random.nextDouble() * 3.0,
              alpha: 1.0,
              color: random.nextBool() ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ));
          }
          break;

        case StudentsWeekAnimationMode.football:
          // White & gold star burst
          for (int i = 0; i < particleCount; i++) {
            final angle = (random.nextDouble() * 0.6 - 0.3) + math.pi; // left bounce
            final speed = 3.0 + random.nextDouble() * 5.0;
            _particles.add(StudentsWeekParticle(
              x: cx + 15.0,
              y: cy,
              vx: math.cos(angle) * speed,
              vy: math.sin(angle) * speed,
              size: 2.0 + random.nextDouble() * 2.5,
              alpha: 1.0,
              color: random.nextBool() ? Colors.white : const Color(0xFFF59E0B),
              isStar: true,
            ));
          }
          break;

        case StudentsWeekAnimationMode.animals:
          // Mascot golden shockwaves
          for (int i = 0; i < particleCount; i++) {
            final angle = random.nextDouble() * math.pi * 2;
            final speed = 1.5 + random.nextDouble() * 4.5;
            _particles.add(StudentsWeekParticle(
              x: cx,
              y: cy + 10.0,
              vx: math.cos(angle) * speed,
              vy: math.sin(angle) * speed,
              size: 3.0 + random.nextDouble() * 3.5,
              alpha: 1.0,
              color: random.nextBool() ? const Color(0xFFE28743) : const Color(0xFFF59E0B),
            ));
          }
          break;

        case StudentsWeekAnimationMode.singers:
          // Neon pink / magenta sound stars
          for (int i = 0; i < particleCount; i++) {
            final angle = -random.nextDouble() * math.pi;
            final speed = 2.0 + random.nextDouble() * 5.5;
            _particles.add(StudentsWeekParticle(
              x: cx,
              y: cy,
              vx: math.cos(angle) * speed,
              vy: math.sin(angle) * speed,
              size: 2.0 + random.nextDouble() * 3.0,
              alpha: 1.0,
              color: random.nextBool() ? const Color(0xFFEC4899) : const Color(0xFF8B5CF6),
              isStar: true,
            ));
          }
          break;
      }
    }

    // Animate Text Scale and Opacity
    if (_showText) {
      final hitProgress = (t - impactT) / (1.0 - impactT);
      if (hitProgress >= 0.0 && hitProgress <= 1.0) {
        _textScale = math.sin(hitProgress * math.pi) * 1.35;
        _textOpacity = (1.0 - hitProgress).clamp(0.0, 1.0);
      } else {
        _showText = false;
      }
    }

    // Update active physics particles
    for (final p in _particles) {
      p.update();
    }

    setState(() {});
  }

  void _handleTapDown(TapDownDetails details) {
    IrisHaptics.actionMedium();
    final tapPos = details.localPosition;
    setState(() {
      _isTapTriggered = true;
      _cycleCount = 0;
      // Cycle to the next mode immediately
      _mode = StudentsWeekAnimationMode.values[
          (_mode.index + 1) % StudentsWeekAnimationMode.values.length];
    });
    // Restart animation from beginning
    _controller.forward(from: 0.0);
    
    // Spawn extra tap particles directly at the tap position
    final random = math.Random();
    for (int i = 0; i < 24; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 2.0 + random.nextDouble() * 4.5;
      _particles.add(StudentsWeekParticle(
        x: tapPos.dx,
        y: tapPos.dy,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        size: 2.0 + random.nextDouble() * 3.0,
        alpha: 1.0,
        color: _getModeParticleColor(_mode, random),
        isStar: random.nextBool(),
      ));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateAnimation);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HeaderAtmosphereWrapper(
      radius: 36.0,
      themeColor: const Color(0xFF10B981),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          borderRadius: 36.0,
          accentColor: const Color(0xFF10B981), // Emerald Green theme
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _lastWidth = constraints.maxWidth;
                    _lastHeight = constraints.maxHeight;
                    return CustomPaint(
                      painter: StudentsWeekPainter(
                        progress: _controller.value,
                        mode: _mode,
                        particles: _particles,
                        showText: _showText,
                        textScale: _textScale,
                        textOpacity: _textOpacity,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 130),
                alignment: Alignment.centerLeft,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// PHYSICS PARTICLE MODEL
// ==========================================================================

class StudentsWeekParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  Color color;
  bool isStar;

  StudentsWeekParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.color,
    this.isStar = false,
  });

  void update() {
    x += vx;
    y += vy;
    vy += 0.22; // gravity downwards
    alpha -= 0.024;
    if (alpha < 0) alpha = 0.0;
  }
}

// ==========================================================================
// CANVAS CUSTOM PAINTER FOR ALL 4 MODES
// ==========================================================================

class StudentsWeekPainter extends CustomPainter {
  final double progress;
  final StudentsWeekAnimationMode mode;
  final List<StudentsWeekParticle> particles;
  final bool showText;
  final double textScale;
  final double textOpacity;
  final bool isDark;

  StudentsWeekPainter({
    required this.progress,
    required this.mode,
    required this.particles,
    required this.showText,
    required this.textScale,
    required this.textOpacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.82;
    final double cy = size.height * 0.48;
    final baseColor = isDark ? Colors.white : Colors.black;

    // 1. Draw mode-specific illustrations
    switch (mode) {
      case StudentsWeekAnimationMode.cricket:
        // Draw pitch line
        final pitchPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.05)
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(cx - 50, cy + 24), Offset(cx + 50, cy + 24), pitchPaint);

        // Draw 3 wooden stumps (wickets) behind bat
        final wicketPaint = Paint()..color = const Color(0xFFD1A153)..strokeWidth = 1.5;
        for (double wx in [-5.0, 0.0, 5.0]) {
          canvas.drawLine(Offset(cx + 22 + wx, cy + 24), Offset(cx + 22 + wx, cy + 4), wicketPaint);
        }
        
        // Draw red bail on top
        final bailPaint = Paint()..color = const Color(0xFFEF4444)..strokeWidth = 1.2;
        if (progress < 0.45) {
          canvas.drawLine(Offset(cx + 15, cy + 3), Offset(cx + 29, cy + 3), bailPaint);
        } else if (progress < 0.85) {
          // Bail flies off and rotates
          final double t = (progress - 0.45) / 0.40;
          final double bailY = cy + 3.0 - (t * 40.0);
          final double bailRotation = t * 6.5;
          canvas.save();
          canvas.translate(cx + 22, bailY);
          canvas.rotate(bailRotation);
          canvas.drawLine(const Offset(-7, 0), const Offset(7, 0), bailPaint);
          canvas.restore();
        } else {
          // Fade bail back to normal
          final double t = (progress - 0.85) / 0.15;
          canvas.save();
          canvas.translate(cx + 22, cy + 3.0);
          canvas.drawLine(const Offset(-7, 0), const Offset(7, 0), bailPaint..color = const Color(0xFFEF4444).withValues(alpha: t));
          canvas.restore();
        }

        // Draw bat swinging with motion trails
        final batPaint = Paint()
          ..color = const Color(0xFFD1A153)
          ..style = PaintingStyle.fill;
        final handlePaint = Paint()
          ..color = const Color(0xFF374151)
          ..style = PaintingStyle.fill;

        double batRotation = -0.6;
        if (progress < 0.2) {
          // Prepare swing (backswing)
          final double t = progress / 0.2;
          batRotation = -0.6 - (t * 0.15);
        } else if (progress < 0.45) {
          // Forward swing
          final double t = (progress - 0.2) / 0.25;
          batRotation = -0.75 + (t * 1.95);
        } else if (progress < 0.75) {
          // Follow through
          final double t = (progress - 0.45) / 0.3;
          batRotation = 1.2 + math.sin(t * math.pi / 2) * 0.25;
        } else {
          // Return smoothly to start position
          final double t = (progress - 0.75) / 0.25;
          batRotation = 1.45 - (t * 2.05);
        }

        // Draw faint motion trails during forward swing
        if (progress >= 0.2 && progress <= 0.45) {
          final double trailT = (progress - 0.2) / 0.25;
          for (int t = 1; t <= 3; t++) {
            final trailProgress = (trailT - (t * 0.08)).clamp(0.0, 1.0);
            final double trailRotation = -0.75 + (trailProgress * 1.95);
            canvas.save();
            canvas.translate(cx - 15, cy + 15);
            canvas.rotate(trailRotation);
            canvas.drawRect(
              const Rect.fromLTWH(-1.5, -20, 3, 8),
              Paint()
                ..color = const Color(0xFF374151).withValues(alpha: 0.08 * (4 - t))
                ..style = PaintingStyle.fill,
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(const Rect.fromLTWH(-3, -12, 6, 22), const Radius.circular(2)),
              Paint()
                ..color = const Color(0xFFD1A153).withValues(alpha: 0.08 * (4 - t))
                ..style = PaintingStyle.fill,
            );
            canvas.restore();
          }
        }

        // Draw primary bat
        canvas.save();
        canvas.translate(cx - 15, cy + 15);
        canvas.rotate(batRotation);
        canvas.drawRect(const Rect.fromLTWH(-2, -22, 4, 10), handlePaint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -12, 8, 25), const Radius.circular(2)),
          batPaint,
        );
        canvas.restore();

        // Draw ball moving and looping
        double ballX, ballY;
        double ballOpacity = 1.0;
        if (progress < 0.45) {
          // Ball approaches bat
          final double t = progress / 0.45;
          ballX = cx + 60.0 - (t * 80.0);
          ballY = cy + 5.0 + (t * 5.0);
          
          final ballPaint = Paint()
            ..color = const Color(0xFFEF4444)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(ballX, ballY), 5, ballPaint);
          
          // Motion trails
          canvas.drawCircle(Offset(ballX + 8, ballY + 0.5), 3.5, Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.3)..style = PaintingStyle.fill);
          canvas.drawCircle(Offset(ballX + 15, ballY + 1.0), 2.0, Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.1)..style = PaintingStyle.fill);
        } else if (progress < 0.85) {
          // Ball hit and flying off
          final double t = (progress - 0.45) / 0.40;
          ballX = (cx - 20.0) - (t * 90.0);
          ballY = (cy + 10.0) - (t * 70.0);
          ballOpacity = (1.0 - t).clamp(0.0, 1.0);
          
          final ballPaint = Paint()
            ..color = const Color(0xFFEF4444).withValues(alpha: ballOpacity)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(ballX, ballY), 5, ballPaint);

          // Draw impact sparkles at contact point
          final double sparkT = (progress - 0.45) / 0.20;
          if (sparkT < 1.0) {
            final collisionX = cx - 20.0;
            final collisionY = cy + 10.0;
            for (int s = 0; s < 8; s++) {
              final double angle = s * math.pi / 4;
              final double sparkLen = 4.0 + sparkT * 16.0;
              canvas.drawLine(
                Offset(collisionX, collisionY),
                Offset(collisionX + math.cos(angle) * sparkLen, collisionY + math.sin(angle) * sparkLen),
                Paint()
                  ..color = const Color(0xFFFFB703).withValues(alpha: (1.0 - sparkT).clamp(0.0, 1.0))
                  ..strokeWidth = 1.0,
              );
            }
          }
        } else {
          // Ball returns to starting point (fading in)
          final double t = (progress - 0.85) / 0.15;
          ballX = cx + 60.0;
          ballY = cy + 5.0;
          ballOpacity = t;
          canvas.drawCircle(Offset(ballX, ballY), 5, Paint()..color = const Color(0xFFEF4444).withValues(alpha: ballOpacity));
        }
        break;

      case StudentsWeekAnimationMode.football:
        // Draw soccer goalpost frame
        final netPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.08)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        final borderPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.35)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
          
        // Goal frame boundary
        canvas.drawRect(Rect.fromLTWH(cx - 20, cy - 25, 40, 50), borderPaint);
        // Draw net grid diagonals
        for (double i = -20; i <= 20; i += 10) {
          canvas.drawLine(Offset(cx + i, cy - 25), Offset(cx + i + 10, cy + 25), netPaint);
          canvas.drawLine(Offset(cx + i, cy + 25), Offset(cx + i - 10, cy - 25), netPaint);
        }

        // Draw Goalkeeper Glove trying to save the ball
        final glovePaint = Paint()..color = baseColor.withValues(alpha: 0.25)..style = PaintingStyle.fill;
        final gloveOutline = Paint()..color = baseColor.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 0.8;
        
        double gloveY = cy + 10.0;
        if (progress < 0.55) {
          gloveY = cy + 10.0 - (progress / 0.55) * 22.0;
        } else {
          gloveY = cy - 12.0 + ((progress - 0.55) / 0.45) * 22.0;
        }

        canvas.save();
        canvas.translate(cx + 22, gloveY);
        final glovePath = Path()
          ..moveTo(0, 0)
          ..lineTo(-2, -6)
          ..lineTo(0, -8)
          ..lineTo(3, -5)
          ..lineTo(5, -7)
          ..lineTo(7, -5)
          ..lineTo(4, -1)
          ..lineTo(5, 3)
          ..close();
        canvas.drawPath(glovePath, glovePaint);
        canvas.drawPath(glovePath, gloveOutline);
        canvas.restore();

        // Draw soccer ball
        double ballX, ballY;
        if (progress < 0.55) {
          // Ball in flight to the goal
          final double t = progress / 0.55;
          ballX = cx - 60.0 + (t * 80.0);
          ballY = cy + 15.0 - (t * 27.0);

          // Draw wind trails in flight
          final windPaint = Paint()..color = baseColor.withValues(alpha: 0.15)..strokeWidth = 0.8;
          canvas.drawLine(Offset(ballX - 10, ballY + 2), Offset(ballX - 3, ballY + 1), windPaint);
          canvas.drawLine(Offset(ballX - 8, ballY - 2), Offset(ballX - 2, ballY - 1), windPaint);
        } else if (progress < 0.80) {
          // Ball hits net, flexes, and drops down
          final double t = (progress - 0.55) / 0.25;
          ballX = cx + 20.0 - (t * 5.0);
          ballY = cy - 12.0 + (t * 32.0);

          // Goalpost net flex animation
          final flexOffset = (math.sin(t * math.pi) * 3.5);
          canvas.drawArc(
            Rect.fromLTWH(cx - 20, cy - 25, 40 + flexOffset, 50),
            -math.pi / 2,
            math.pi,
            false,
            netPaint..color = const Color(0xFF10B981)..strokeWidth = 1.2,
          );
        } else {
          // Ball rolls back smoothly to start position
          final double t = (progress - 0.80) / 0.20;
          ballX = cx + 15.0 - (t * 75.0);
          ballY = cy + 20.0 - (t * 5.0);
        }

        // Draw ball body
        final ballPaint = Paint()
          ..color = baseColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(ballX, ballY), 6.5, ballPaint);
        
        // Draw soccer panels
        final panelPaint = Paint()..color = isDark ? Colors.black : Colors.white;
        canvas.drawCircle(Offset(ballX, ballY), 1.5, panelPaint);
        canvas.drawCircle(Offset(ballX - 3.5, ballY - 2.5), 1.0, panelPaint);
        canvas.drawCircle(Offset(ballX + 3.5, ballY - 2.5), 1.0, panelPaint);
        canvas.drawCircle(Offset(ballX - 3.5, ballY + 2.5), 1.0, panelPaint);
        canvas.drawCircle(Offset(ballX + 3.5, ballY + 2.5), 1.0, panelPaint);
        break;

      case StudentsWeekAnimationMode.animals:
        // Draw mascot head/ears
        final mascotPaint = Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.fill;
        final earPaint = Paint()
          ..color = const Color(0xFFD97706)
          ..style = PaintingStyle.fill;

        // Smooth continuous bouncing
        final bob = math.sin(progress * math.pi * 4) * 3.5;
        final double earRot = math.cos(progress * math.pi * 4) * 0.12;

        // Paw prints floating behind
        final pawPaint = Paint()..color = const Color(0xFFD97706).withValues(alpha: 0.12);
        canvas.drawCircle(Offset(cx - 32, cy + 18 + (bob * 0.5)), 4, pawPaint);
        canvas.drawCircle(Offset(cx - 36, cy + 13 + (bob * 0.5)), 2, pawPaint);
        canvas.drawCircle(Offset(cx - 31, cy + 10 + (bob * 0.5)), 2, pawPaint);
        canvas.drawCircle(Offset(cx - 27, cy + 12 + (bob * 0.5)), 2, pawPaint);

        // Draw left/right ears with organic sway
        canvas.save();
        canvas.translate(cx - 12, cy - 8 + bob);
        canvas.rotate(earRot);
        canvas.drawCircle(Offset.zero, 7.5, earPaint);
        canvas.drawCircle(Offset.zero, 4.5, Paint()..color = const Color(0xFFFCA5A5)); // inner pink ear
        canvas.restore();

        canvas.save();
        canvas.translate(cx + 12, cy - 8 + bob);
        canvas.rotate(-earRot);
        canvas.drawCircle(Offset.zero, 7.5, earPaint);
        canvas.drawCircle(Offset.zero, 4.5, Paint()..color = const Color(0xFFFCA5A5));
        canvas.restore();

        // Draw face
        canvas.drawCircle(Offset(cx, cy + bob), 13.5, mascotPaint);
        
        // Glasses for cool mascot
        final glassesPaint = Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.fill;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 10, cy - 3 + bob, 8, 5), const Radius.circular(2)), glassesPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + 2, cy - 3 + bob, 8, 5), const Radius.circular(2)), glassesPaint);
        canvas.drawLine(Offset(cx - 2, cy - 1 + bob), Offset(cx + 2, cy - 1 + bob), Paint()..color = Colors.black87..strokeWidth = 1.0);

        // Periodic blink animation (blinks quickly near 0.2 and 0.8 progress)
        final bool isBlinking = (progress >= 0.18 && progress <= 0.22) || (progress >= 0.78 && progress <= 0.82);
        if (isBlinking) {
          // Closed eye line
          final blinkPaint = Paint()..color = Colors.white..strokeWidth = 1.2;
          canvas.drawLine(Offset(cx - 8, cy - 0.5 + bob), Offset(cx - 4, cy - 0.5 + bob), blinkPaint);
          canvas.drawLine(Offset(cx + 4, cy - 0.5 + bob), Offset(cx + 8, cy - 0.5 + bob), blinkPaint);
        } else {
          // Open eye white circles
          canvas.drawCircle(Offset(cx - 6, cy - 0.5 + bob), 2, Paint()..color = Colors.white);
          canvas.drawCircle(Offset(cx + 6, cy - 0.5 + bob), 2, Paint()..color = Colors.white);
        }
        break;

      case StudentsWeekAnimationMode.singers:
        // Draw microphone and lights
        final micPaint = Paint()
          ..color = Colors.grey
          ..style = PaintingStyle.fill;
        final bulbPaint = Paint()
          ..color = const Color(0xFFEC4899)
          ..style = PaintingStyle.fill;

        // Draw 3 intersecting Spotlight beams (looping perfectly)
        final colorsSpot = [
          const Color(0xFFEC4899),
          const Color(0xFF3B82F6),
          const Color(0xFFF59E0B)
        ];
        for (int i = 0; i < 3; i++) {
          final double shiftAngle = (progress * 2 * math.pi) + (i * 2 * math.pi / 3);
          final double targetX = cx + math.cos(shiftAngle) * 25.0;
          final double sourceX = cx - 30.0 + (i * 30.0);
          final double sourceY = cy - 40.0;
          
          final lightPath = Path()
            ..moveTo(sourceX - 3, sourceY)
            ..lineTo(sourceX + 3, sourceY)
            ..lineTo(targetX + 18, cy + 25)
            ..lineTo(targetX - 18, cy + 25)
            ..close();

          final lightPaint = Paint()
            ..shader = LinearGradient(
              colors: [
                colorsSpot[i].withValues(alpha: 0.155),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(Rect.fromLTRB(sourceX - 10, sourceY, targetX + 18, cy + 25));
          canvas.drawPath(lightPath, lightPaint);
        }

        // Draw microphone stand and grille
        canvas.drawRect(Rect.fromLTWH(cx - 1.5, cy - 5, 3, 22), micPaint);
        canvas.drawCircle(Offset(cx, cy - 8), 6.5, bulbPaint);
        
        // Grille mesh lines
        final meshPaint = Paint()
          ..color = Colors.white54
          ..strokeWidth = 0.6;
        canvas.drawLine(Offset(cx - 5, cy - 8), Offset(cx + 5, cy - 8), meshPaint);
        canvas.drawLine(Offset(cx, cy - 13), Offset(cx, cy - 3), meshPaint);

        // Swaying music notes swaying upward
        void _drawMusicNote(Canvas canvas, Offset pos, Color color) {
          final stemPaint = Paint()..color = color..strokeWidth = 0.8;
          final notePaint = Paint()..color = color..style = PaintingStyle.fill;
          canvas.drawOval(Rect.fromLTWH(pos.dx, pos.dy, 3.5, 2.5), notePaint);
          canvas.drawLine(Offset(pos.dx + 3.1, pos.dy + 1.2), Offset(pos.dx + 3.1, pos.dy - 5.5), stemPaint);
          canvas.drawLine(Offset(pos.dx + 3.1, pos.dy - 5.5), Offset(pos.dx + 5.2, pos.dy - 4.2), stemPaint);
        }

        final double n1T = (progress + 0.15) % 1.0;
        final double n2T = (progress + 0.65) % 1.0;
        final noteCol = const Color(0xFFEC4899);
        _drawMusicNote(canvas, Offset(cx - 18 + math.sin(n1T * 2 * math.pi) * 4.0, cy - 12 - n1T * 28.0), noteCol.withValues(alpha: 1.0 - n1T));
        _drawMusicNote(canvas, Offset(cx + 16 + math.cos(n2T * 2 * math.pi) * 3.5, cy - 18 - n2T * 24.0), noteCol.withValues(alpha: 1.0 - n2T));

        // Dancing audio spectrum wave rings (looping perfectly)
        final wavePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
          
        final double r1 = 5.0 + (progress * 25.0);
        final double op1 = math.sin(progress * math.pi) * 0.22;
        canvas.drawCircle(Offset(cx, cy - 8), r1, wavePaint..color = const Color(0xFFEC4899).withValues(alpha: op1));

        final double p2 = (progress + 0.5) % 1.0;
        final double r2 = 5.0 + (p2 * 25.0);
        final double op2 = math.sin(p2 * math.pi) * 0.22;
        canvas.drawCircle(Offset(cx, cy - 8), r2, wavePaint..color = const Color(0xFFEC4899).withValues(alpha: op2));
        break;
    }

    // 2. Paint Particles
    for (final p in particles) {
      if (p.alpha > 0.01) {
        final pPaint = Paint()
          ..color = p.color.withValues(alpha: p.alpha)
          ..style = PaintingStyle.fill;
        if (p.isStar) {
          final path = Path();
          final r = p.size;
          for (int i = 0; i < 5; i++) {
            final double angle = -math.pi / 2 + (i * 4 * math.pi / 5);
            if (i == 0) {
              path.moveTo(p.x + math.cos(angle) * r, p.y + math.sin(angle) * r);
            } else {
              path.lineTo(p.x + math.cos(angle) * r, p.y + math.sin(angle) * r);
            }
          }
          path.close();
          canvas.drawPath(path, pPaint);
        } else {
          canvas.drawCircle(Offset(p.x, p.y), p.size, pPaint);
        }
      }
    }

    // 3. Paint Hit Text Overlay
    if (showText && textOpacity > 0.01) {
      canvas.save();
      canvas.translate(cx, cy - 25);
      canvas.scale(textScale);

      String hitStr = 'HIT!';
      Color textColor = const Color(0xFF10B981);
      switch (mode) {
        case StudentsWeekAnimationMode.cricket:
          hitStr = 'SIXER!';
          textColor = const Color(0xFF10B981);
          break;
        case StudentsWeekAnimationMode.football:
          hitStr = 'GOAL!';
          textColor = const Color(0xFFF59E0B);
          break;
        case StudentsWeekAnimationMode.animals:
          hitStr = 'YEAH!';
          textColor = const Color(0xFFE28743);
          break;
        case StudentsWeekAnimationMode.singers:
          hitStr = 'ROCK!';
          textColor = const Color(0xFFEC4899);
          break;
      }

      final textSpan = TextSpan(
        text: hitStr,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: textColor,
          shadows: [
            BoxShadow(color: textColor.withValues(alpha: 0.6), blurRadius: 4),
            const BoxShadow(color: Colors.black, blurRadius: 0.5, offset: Offset(0, 1)),
          ],
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================================================
// SPORTS WEEK LIVE SCOREBOARD CARD
// ==========================================================================

class LiveScoreboardWidget extends SmartStatefulWidget {
  const LiveScoreboardWidget({super.key});

  @override
  State<LiveScoreboardWidget> createState() => _LiveScoreboardWidgetState();
}

class _LiveScoreboardWidgetState extends SmartState<LiveScoreboardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 30.0,
      accentColor: const Color(0xFF10B981),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3 + (_pulseController.value * 0.7)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.4 * _pulseController.value),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE MATCH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFEF4444),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'CRICKET SEMIFINAL 1',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Team A
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CS Warriors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      '148 / 4  (15.2 Ov)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF10B981),
                        shadows: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // VS circle
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  ),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                  ),
                ),
              ),
              // Team B
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('SE Titans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      'Yet to bat',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sports_cricket_rounded,
                  size: 16,
                  color: const Color(0xFF10B981).withValues(alpha: 0.85),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Target: 165 runs. CS Warriors needs 17 runs in 28 balls to win.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65),
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// DAILY EVENTS SCHEDULE TIMELINE WIDGET
// ==========================================================================

class StudentsWeekMatchesWidget extends StatelessWidget {
  const StudentsWeekMatchesWidget({super.key});

  static final List<Map<String, dynamic>> _mockEvents = [
    {
      'time': '10:00 AM',
      'sport': 'Cricket Semifinal 1',
      'teams': 'CS Batch 22 vs SE Batch 23',
      'venue': 'Main Ground Pitch A',
      'status': 'LIVE',
    },
    {
      'time': '11:30 AM',
      'sport': 'Badminton Doubles',
      'teams': 'EE Dept vs ME Dept',
      'venue': 'Gymnasium Court 2',
      'status': 'UPCOMING',
    },
    {
      'time': '01:00 PM',
      'sport': 'Futsal Final',
      'teams': 'CS Warriors vs EE Titans',
      'venue': 'Futsal Arena',
      'status': 'UPCOMING',
    },
    {
      'time': '02:30 PM',
      'sport': 'Table Tennis Singles',
      'teams': 'BBA Smashers vs CS Spinners',
      'venue': 'Student Center Hall',
      'status': 'UPCOMING',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("TODAY'S ACTIVITIES", isDark),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _mockEvents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ev = _mockEvents[index];
            final isLive = ev['status'] == 'LIVE';
            return GlassCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 24.0,
              accentColor: isLive ? const Color(0xFF10B981) : null,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      ev['time'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              ev['sport'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (isLive) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ev['teams'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.place_rounded,
                              size: 12,
                              color: const Color(0xFF10B981).withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ev['venue'],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

// ==========================================================================
// DEPARTMENT STANDINGS POINTS TABLE LEADERBOARD WIDGET
// ==========================================================================

class StudentsWeekStandingsWidget extends StatelessWidget {
  const StudentsWeekStandingsWidget({super.key});

  static final List<Map<String, dynamic>> _mockStandings = [
    {'dept': 'CS / Computing', 'gold': 4, 'silver': 2, 'bronze': 1, 'points': 45},
    {'dept': 'Electrical Eng', 'gold': 2, 'silver': 3, 'bronze': 2, 'points': 31},
    {'dept': 'Mechanical Eng', 'gold': 1, 'silver': 1, 'bronze': 4, 'points': 21},
    {'dept': 'Management (BBA)', 'gold': 1, 'silver': 0, 'bronze': 2, 'points': 14},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("DEPARTMENT LEADERBOARD", isDark),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 28.0,
          child: Column(
            children: [
              Row(
                children: const [
                  Expanded(flex: 3, child: Text('DEPARTMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                  Expanded(child: Center(child: Text('🥇', style: TextStyle(fontSize: 12)))),
                  Expanded(child: Center(child: Text('🥈', style: TextStyle(fontSize: 12)))),
                  Expanded(child: Center(child: Text('🥉', style: TextStyle(fontSize: 12)))),
                  Expanded(child: Center(child: Text('PTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))),
                ],
              ),
              const Divider(height: 20),
              ..._mockStandings.map((team) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          team['dept'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Center(child: Text('${team['gold']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))),
                      Expanded(child: Center(child: Text('${team['silver']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))),
                      Expanded(child: Center(child: Text('${team['bronze']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))),
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${team['points']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

// ==========================================================================
// CLASSES (NORMAL PERIOD) ANIMATION: GLOWING LIGHTBULB & WRITING PENCIL
// ==========================================================================

enum DayPeriod { morning, day, night }

class ClassesAnimationWidget extends StatefulWidget {
  final Widget child;
  const ClassesAnimationWidget({required this.child, super.key});

  @override
  State<ClassesAnimationWidget> createState() => _ClassesAnimationWidgetState();
}

class _ClassesAnimationWidgetState extends State<ClassesAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<ClassesParticle> _particles = [];
  bool _isLightOn = false;
  double _bulbGlowScale = 1.0;
  bool _showIdeas = false;
  double _ideasScale = 0.0;
  double _ideasOpacity = 0.0;
  double _lastWidth = 350.0;
  double _lastHeight = 150.0;

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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _controller.addListener(_updateAnimation);
  }

  void _updateAnimation() {
    final t = _controller.value;
    final period = _getPeriod();

    // Reset loop attributes
    if (t < 0.02) {
      _isLightOn = false;
      _showIdeas = false;
      _ideasScale = 0.0;
      _ideasOpacity = 0.0;
      _particles.clear();
    }

    final cx = _lastWidth * 0.82;
    final cy = _lastHeight * 0.48;

    if (t >= 0.4 && t < 0.8) {
      if (!_isLightOn) {
        _isLightOn = true;
        _showIdeas = true;
        
        if (period == DayPeriod.day) {
          IrisHaptics.actionMedium();
        } else if (period == DayPeriod.night) {
          IrisHaptics.actionSoft();
        }

        final random = math.Random();
        int particleCount = period == DayPeriod.morning ? 8 : 12;
        for (int i = 0; i < particleCount; i++) {
          final angle = random.nextDouble() * 2 * math.pi;
          final speed = period == DayPeriod.morning 
              ? 0.5 + random.nextDouble() * 1.5 
              : 1.5 + random.nextDouble() * 3.5;
              
          _particles.add(ClassesParticle(
            x: cx,
            y: cy,
            vx: period == DayPeriod.morning ? (random.nextDouble() - 0.5) * 0.8 : math.cos(angle) * speed,
            vy: period == DayPeriod.morning ? -speed : math.sin(angle) * speed,
            size: period == DayPeriod.morning ? 3.0 + random.nextDouble() * 4.0 : 2.0 + random.nextDouble() * 2.0,
            alpha: 1.0,
            color: period == DayPeriod.morning 
                ? Colors.white.withValues(alpha: 0.4)
                : period == DayPeriod.night 
                    ? const Color(0xFFFACC15) // Neon Yellow
                    : const Color(0xFFF59E0B), // Amber
          ));
        }
      }
      _bulbGlowScale = 1.0 + 0.15 * math.sin((t - 0.4) / 0.4 * math.pi);
    } else if (t >= 0.8) {
      _isLightOn = false;
      _bulbGlowScale = 1.0;
    }

    if (_showIdeas) {
      final textProgress = (t - 0.4) / 0.4;
      if (textProgress >= 0.0 && textProgress <= 1.0) {
        _ideasScale = math.sin(textProgress * math.pi) * 1.35;
        _ideasOpacity = (1.0 - textProgress).clamp(0.0, 1.0);
      } else {
        _showIdeas = false;
      }
    }

    // Update active particles
    for (final p in _particles) {
      p.update(period);
    }

    setState(() {});
  }

  void _handleTapDown(TapDownDetails details) {
    IrisHaptics.actionHeavy();
    final tapPos = details.localPosition;
    final period = _getPeriod();
    
    setState(() {
      _isLightOn = true;
      _showIdeas = true;
      _controller.forward(from: 0.0);
      
      final random = math.Random();
      for (int i = 0; i < 22; i++) {
        final angle = random.nextDouble() * 2 * math.pi;
        final speed = 2.0 + random.nextDouble() * 4.5;
        _particles.add(ClassesParticle(
          x: tapPos.dx,
          y: tapPos.dy,
          vx: period == DayPeriod.morning ? (random.nextDouble() - 0.5) * 1.5 : math.cos(angle) * speed,
          vy: period == DayPeriod.morning ? -speed : math.sin(angle) * speed,
          size: 2.0 + random.nextDouble() * 3.0,
          alpha: 1.0,
          color: period == DayPeriod.morning 
              ? Colors.white.withValues(alpha: 0.5)
              : period == DayPeriod.night 
                  ? const Color(0xFFFACC15)
                  : const Color(0xFFF59E0B),
        ));
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateAnimation);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HeaderAtmosphereWrapper(
      radius: 36.0,
      themeColor: IrisTokens.brand,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          borderRadius: 36.0,
          accentColor: IrisTokens.brand,
          border: Border.all(
            color: IrisTokens.brand.withValues(alpha: 0.16),
            width: 1.2,
          ),
          glow: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _lastWidth = constraints.maxWidth;
                    _lastHeight = constraints.maxHeight;
                    return CustomPaint(
                      painter: ClassesPainter(
                        progress: _controller.value,
                        period: _getPeriod(),
                        particles: _particles,
                        isLightOn: _isLightOn,
                        glowScale: _bulbGlowScale,
                        showIdeas: _showIdeas,
                        ideasScale: _ideasScale,
                        ideasOpacity: _ideasOpacity,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 130),
                alignment: Alignment.centerLeft,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClassesParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  Color color;

  ClassesParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.color,
  });

  void update(DayPeriod period) {
    x += vx;
    y += vy;
    
    if (period == DayPeriod.morning) {
      // Vapor bubbles rise and fade slowly
      vy = vy * 0.96 - 0.05;
      vx += math.sin(y * 0.1) * 0.04;
      alpha -= 0.012;
    } else if (period == DayPeriod.night) {
      // Fireflies drift in random sine waves
      vx += math.sin(y * 0.05) * 0.06;
      vy += math.cos(x * 0.05) * 0.06;
      alpha -= 0.016;
    } else {
      // Original sparks
      vy += 0.05;
      alpha -= 0.025;
    }
    
    if (alpha < 0) alpha = 0.0;
  }
}

class ClassesPainter extends CustomPainter {
  final double progress;
  final DayPeriod period;
  final List<ClassesParticle> particles;
  final bool isLightOn;
  final double glowScale;
  final bool showIdeas;
  final double ideasScale;
  final double ideasOpacity;
  final bool isDark;

  ClassesPainter({
    required this.progress,
    required this.period,
    required this.particles,
    required this.isLightOn,
    required this.glowScale,
    required this.showIdeas,
    required this.ideasScale,
    required this.ideasOpacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.82;
    final double cy = size.height * 0.48;

    // 1. Draw dynamic sketch wave at the bottom
    _paintPencilAndLine(canvas, size);

    // 2. Period-specific header illustrations
    switch (period) {
      case DayPeriod.morning:
        _paintMorningScene(canvas, cx, cy);
        break;
      case DayPeriod.day:
        _paintDayScene(canvas, cx, cy);
        break;
      case DayPeriod.night:
        _paintNightScene(canvas, cx, cy, size);
        break;
    }

    // 3. Render dynamic particles
    for (final p in particles) {
      if (p.alpha > 0.01) {
        final pPaint = Paint()
          ..color = p.color.withValues(alpha: p.alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(p.x, p.y), p.size, pPaint);
      }
    }

    // 4. Overlaid dynamic text bubbles
    if (showIdeas && ideasOpacity > 0.01) {
      canvas.save();
      canvas.translate(cx, cy - 28);
      canvas.scale(ideasScale);
      
      final String label = period == DayPeriod.morning 
          ? 'RISE!' 
          : period == DayPeriod.night 
              ? 'STUDY!' 
              : 'IDEAS!';
              
      final Color tintColor = period == DayPeriod.morning 
          ? const Color(0xFF10B981) 
          : period == DayPeriod.night 
              ? const Color(0xFFF59E0B) 
              : const Color(0xFFF59E0B);

      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: tintColor,
          shadows: [
            BoxShadow(
              color: tintColor.withValues(alpha: 0.6),
              blurRadius: 8,
            ),
            const BoxShadow(color: Colors.black, blurRadius: 1, offset: Offset(0, 1.5)),
          ],
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  void _paintMorningScene(Canvas canvas, double cx, double cy) {
    // Golden Rising Sun (Shifted left and up to cx - 22, cy - 12)
    final double sunRadius = 14.0 + (glowScale - 1.0) * 12.0;
    
    // Ambient sunglow
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF59E0B),
          const Color(0xFFFFB703).withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx - 22, cy - 12), radius: sunRadius + 16))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 22, cy - 12), sunRadius + 16, sunPaint);

    final sunCorePaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 22, cy - 12), 10.0, sunCorePaint);

    // Rotating Sun rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFFB703).withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (int r = 0; r < 8; r++) {
      final double angle = (progress * 0.4) + (r * math.pi / 4);
      canvas.drawLine(
        Offset(cx - 22 + math.cos(angle) * 14.0, cy - 12 + math.sin(angle) * 14.0),
        Offset(cx - 22 + math.cos(angle) * 20.0, cy - 12 + math.sin(angle) * 20.0),
        rayPaint,
      );
    }

    // Sparkles around sun
    final sparklePaint = Paint()..color = const Color(0xFFFBBF24).withValues(alpha: 0.5)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 38, cy - 22), 1.5, sparklePaint);
    canvas.drawCircle(Offset(cx - 6, cy - 2), 1.0, sparklePaint);

    // Little floating cloud
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: isDark ? 0.22 : 0.5);
    canvas.drawCircle(Offset(cx - 8, cy - 18), 5, cloudPaint);
    canvas.drawCircle(Offset(cx - 4, cy - 18), 6, cloudPaint);
    canvas.drawCircle(Offset(cx, cy - 18), 5, cloudPaint);
    canvas.drawRect(Rect.fromLTWH(cx - 8, cy - 15, 8, 3), cloudPaint);

    // Steaming coffee mug (Shifted right and down to cx + 8, cy + 6)
    final cupPaint = Paint()
      ..color = isDark ? Colors.white70 : Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    final cupFill = Paint()
      ..color = isDark ? Colors.white24 : Colors.black12
      ..style = PaintingStyle.fill;

    // Cup Body
    final cupRect = Rect.fromLTWH(cx + 8, cy + 6, 16, 14);
    canvas.drawRRect(RRect.fromRectAndRadius(cupRect, const Radius.circular(2.5)), cupFill);
    canvas.drawRRect(RRect.fromRectAndRadius(cupRect, const Radius.circular(2.5)), cupPaint);

    // Coffee Shading inside cup
    canvas.drawRect(Rect.fromLTWH(cx + 9.5, cy + 7.5, 13, 2), Paint()..color = const Color(0xFF6F4E37));

    // Handle (Shifted relative to cup body)
    final handlePath = Path()
      ..moveTo(cx + 24, cy + 9)
      ..arcToPoint(Offset(cx + 24, cy + 17), radius: const Radius.circular(5.0))
      ..arcToPoint(Offset(cx + 24, cy + 9), radius: const Radius.circular(3.0));
    canvas.drawPath(handlePath, cupPaint);

    // Mini Donut next to the coffee cup
    final donutPaint = Paint()..color = const Color(0xFFD4A373)..style = PaintingStyle.fill;
    final frostingPaint = Paint()..color = const Color(0xFFF472B6)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 2, cy + 14), 3.5, donutPaint);
    canvas.drawCircle(Offset(cx - 2, cy + 14), 2.2, frostingPaint);
    canvas.drawCircle(Offset(cx - 2, cy + 14), 1.0, Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white);

    // Wavy Steam
    final steamPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35 + (progress * 0.3))
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    for (int i = -1; i <= 1; i++) {
      final double sx = cx + 16 + (i * 4.0);
      final double sy = cy + 4;
      final steamPath = Path()..moveTo(sx, sy);
      steamPath.cubicTo(
        sx - 2 + math.sin(progress * 6.0) * 1.5, sy - 4,
        sx + 2 - math.sin(progress * 6.0) * 1.5, sy - 8,
        sx, sy - 13
      );
      canvas.drawPath(steamPath, steamPaint);
    }
  }

  void _paintDayScene(Canvas canvas, double cx, double cy) {
    if (isLightOn) {
      final glowPaint = Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.16)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), 22.0 * glowScale, glowPaint);

      final rayPaint = Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.6)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < 8; i++) {
        final angle = (progress * 0.3) + (i * math.pi / 4);
        final double rStart = 16.0 * glowScale;
        final double rEnd = 24.0 * glowScale;
        canvas.drawLine(
          Offset(cx + math.cos(angle) * rStart, cy + math.sin(angle) * rStart),
          Offset(cx + math.cos(angle) * rEnd, cy + math.sin(angle) * rEnd),
          rayPaint,
        );
      }
    }

    final basePaint = Paint()
      ..color = (isDark ? Colors.white54 : Colors.black45)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillBase = Paint()
      ..color = (isDark ? Colors.white24 : Colors.black12)
      ..style = PaintingStyle.fill;

    // Lightbulb socket details (screw threads)
    canvas.drawRect(Rect.fromLTWH(cx - 5, cy + 9, 10, 6), fillBase);
    canvas.drawRect(Rect.fromLTWH(cx - 5, cy + 9, 10, 6), basePaint);
    canvas.drawLine(Offset(cx - 4, cy + 11), Offset(cx + 4, cy + 11), basePaint);
    canvas.drawLine(Offset(cx - 4, cy + 13), Offset(cx + 4, cy + 13), basePaint);
    canvas.drawCircle(Offset(cx, cy + 16), 3, fillBase);

    final glassPaint = Paint()
      ..color = isLightOn
          ? const Color(0xFFFBBF24).withValues(alpha: 0.8)
          : (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy - 2), 11.5, glassPaint);

    final outlinePaint = Paint()
      ..color = (isDark ? Colors.white70 : Colors.black87)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy - 2), 11.5, outlinePaint);

    // Loop Filament inside bulb
    final filPaint = Paint()
      ..color = isLightOn ? Colors.white : (isDark ? Colors.white54 : Colors.black54)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
      
    final filPath = Path()
      ..moveTo(cx - 3.5, cy + 8)
      ..lineTo(cx - 2.5, cy - 0.5)
      ..cubicTo(cx - 4.5, cy - 4.5, cx + 4.5, cy - 4.5, cx + 2.5, cy - 0.5)
      ..lineTo(cx + 3.5, cy + 8);
    canvas.drawPath(filPath, filPaint);

    // Rotating gear wheel in background
    final gearPaint = Paint()
      ..color = basePaint.color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.save();
    canvas.translate(cx - 22, cy - 10);
    canvas.rotate(progress * 2 * math.pi);
    canvas.drawCircle(Offset.zero, 5, gearPaint);
    for (int g = 0; g < 6; g++) {
      final double gRad = g * math.pi / 3;
      canvas.drawLine(Offset.zero, Offset(math.cos(gRad) * 7.5, math.sin(gRad) * 7.5), gearPaint);
    }
    canvas.restore();

    // Floating idea sparkles
    final ideaPaint = Paint()..color = const Color(0xFF60A5FA).withValues(alpha: 0.4)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx + 18, cy - 14), 1.3, ideaPaint);
    canvas.drawCircle(Offset(cx - 18, cy + 12), 1.0, ideaPaint);
  }

  void _paintNightScene(Canvas canvas, double cx, double cy, Size size) {
    // Dotted moon
    final moonPaint = Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.35)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 34, cy - 22), 4.0, moonPaint);
    canvas.drawCircle(Offset(cx - 32, cy - 22), 3.2, Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white);
    
    // Stars in background window
    canvas.drawCircle(Offset(cx - 18, cy - 25), 0.7, Paint()..color = Colors.white70);
    canvas.drawCircle(Offset(cx - 42, cy - 10), 0.7, Paint()..color = Colors.white70);

    // Glowing Study desk lamp
    final basePaint = Paint()
      ..color = isDark ? Colors.white60 : Colors.black87
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black12
      ..style = PaintingStyle.fill;

    // Base plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 12, cy + 15, 24, 3), const Radius.circular(1)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 12, cy + 15, 24, 3), const Radius.circular(1)),
      basePaint,
    );

    // Stack of tiny study books next to the lamp base
    final tinyBookCover = Paint()..color = IrisTokens.blue;
    final tinyBookPage = Paint()..color = Colors.white70;
    canvas.drawRect(Rect.fromLTWH(cx + 16, cy + 13, 14, 5), tinyBookCover);
    canvas.drawRect(Rect.fromLTWH(cx + 17, cy + 14, 12, 3), tinyBookPage);

    // Spines lines on the book stack
    final spineLinePaint = Paint()..color = isDark ? Colors.black45 : Colors.white60..strokeWidth = 0.5;
    canvas.drawLine(Offset(cx + 20, cy + 13), Offset(cx + 20, cy + 18), spineLinePaint);
    canvas.drawLine(Offset(cx + 25, cy + 13), Offset(cx + 25, cy + 18), spineLinePaint);

    // Angled Arm Joints
    canvas.drawLine(Offset(cx - 4, cy + 15), Offset(cx - 8, cy + 5), basePaint);
    canvas.drawLine(Offset(cx - 8, cy + 5), Offset(cx + 2, cy - 8), basePaint);

    // Lamp Dome Hood tilted left/down
    canvas.save();
    canvas.translate(cx + 2, cy - 8);
    canvas.rotate(-0.5); // Tilt angle

    final hoodRect = Rect.fromLTWH(-9, -8, 18, 10);
    canvas.drawRRect(RRect.fromRectAndRadius(hoodRect, const Radius.circular(5.0)), fillPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(hoodRect, const Radius.circular(5.0)), basePaint);
    canvas.restore();

    // Projected light beam cone
    final double baseY = size.height - 22.0;
    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFDE047).withValues(alpha: 0.22),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(cx - 35, cy - 4, cx + 35, baseY));

    final beamPath = Path()
      ..moveTo(cx - 3, cy - 5)
      ..lineTo(cx + 8, cy - 5)
      ..lineTo(cx + 25, baseY)
      ..lineTo(cx - 45, baseY)
      ..close();
      
    canvas.drawPath(beamPath, beamPaint);
  }

  void _paintPencilAndLine(Canvas canvas, Size size) {
    // Secondary glow offset line (added depth)
    final glowPaint = Paint()
      ..color = IrisTokens.brand.withValues(alpha: 0.15)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..color = const Color(0xFF3A86FF).withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double startX = 20.0;
    final double endX = size.width * 0.6;
    final double width = endX - startX;
    final double baseY = size.height - 22.0;

    final path = Path();
    final glowPath = Path();
    
    path.moveTo(startX, baseY);
    glowPath.moveTo(startX, baseY + 1.0);
    
    final waveT = progress;
    final int limit = (waveT * width).toInt().clamp(0, width.toInt());

    for (int i = 0; i <= limit; i += 2) {
      final double x = startX + i;
      final double y = baseY + math.sin(x * 0.12 - waveT * 8.0) * 3.0;
      path.lineTo(x, y);
      glowPath.lineTo(x, y + 1.0);
    }
    
    canvas.drawPath(glowPath, glowPaint);
    canvas.drawPath(path, linePaint);

    if (limit < width) {
      final double px = startX + limit;
      final double py = baseY + math.sin(px * 0.12 - waveT * 8.0) * 3.0;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(-0.5);

      final pencilPaint = Paint()..color = const Color(0xFFD4A373);
      final graphitePaint = Paint()..color = const Color(0xFF1E293B);
      final bodyPaint = Paint()..color = const Color(0xFFEC4899);

      final conePath = Path()
        ..moveTo(0, 0)
        ..lineTo(-4, -8)
        ..lineTo(4, -8)
        ..close();
      canvas.drawPath(conePath, pencilPaint);

      final leadPath = Path()
        ..moveTo(0, 0)
        ..lineTo(-1.5, -3)
        ..lineTo(1.5, -3)
        ..close();
      canvas.drawPath(leadPath, graphitePaint);

      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -22, 8, 14), const Radius.circular(1.5)),
        bodyPaint,
      );
      
      // Pencil metallic band and eraser
      final metalPaint = Paint()..color = const Color(0xFF94A3B8);
      final eraserPaint = Paint()..color = const Color(0xFFFDA4AF);
      canvas.drawRect(const Rect.fromLTWH(-4, -25, 8, 3), metalPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -29, 8, 4), const Radius.circular(1)),
        eraserPaint,
      );
      canvas.restore();
      
      // Floating drawing sparks flying off pencil tip!
      final sparkPaint = Paint()..color = const Color(0xFF3A86FF).withValues(alpha: 0.65);
      canvas.drawCircle(Offset(px - 3, py - 4), 1.0, sparkPaint);
      canvas.drawCircle(Offset(px + 4, py - 2), 0.7, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================================================
// MIDTERMS ANIMATION: STEAMING COFFEE MUG & STUDY GRID
// ==========================================================================

class MidtermsAnimationWidget extends StatefulWidget {
  final Widget child;
  const MidtermsAnimationWidget({required this.child, super.key});

  @override
  State<MidtermsAnimationWidget> createState() => _MidtermsAnimationWidgetState();
}

class _MidtermsAnimationWidgetState extends State<MidtermsAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<MidtermsParticle> _particles = [];
  bool _showFocusText = false;
  double _focusScale = 0.0;
  double _focusOpacity = 0.0;
  double _steamOffset = 0.0;
  double _lastWidth = 350.0;
  double _lastHeight = 150.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _controller.addListener(_updateAnimation);
  }

  void _updateAnimation() {
    final t = _controller.value;
    _steamOffset = t * 2 * math.pi;

    if (t < 0.02) {
      _showFocusText = false;
      _focusScale = 0.0;
      _focusOpacity = 0.0;
      _particles.clear();
    }

    final cx = _lastWidth * 0.82;
    final cy = _lastHeight * 0.55;

    // Every loop, spawn little steam bubbles rising
    if (t >= 0.4 && t < 0.44 && _particles.isEmpty) {
      final random = math.Random();
      for (int i = 0; i < 4; i++) {
        _particles.add(MidtermsParticle(
          x: cx - 4.0 + random.nextDouble() * 8.0,
          y: cy - 15.0,
          vx: -0.2 + random.nextDouble() * 0.4,
          vy: -0.5 - random.nextDouble() * 0.7,
          size: 1.0 + random.nextDouble() * 1.5,
          alpha: 0.8,
          swayPhase: random.nextDouble() * 2 * math.pi,
        ));
      }
    }

    // Animate FOCUS text
    if (_showFocusText) {
      final progressText = (t - 0.1) / 0.5;
      if (progressText >= 0.0 && progressText <= 1.0) {
        _focusScale = math.sin(progressText * math.pi) * 1.35;
        _focusOpacity = (1.0 - progressText).clamp(0.0, 1.0);
      } else {
        _showFocusText = false;
      }
    }

    // Update active steam bubbles
    for (final p in _particles) {
      p.update();
    }

    setState(() {});
  }

  void _handleTapDown(TapDownDetails details) {
    IrisHaptics.actionMedium();
    final tapPos = details.localPosition;
    setState(() {
      _showFocusText = true;
      _controller.forward(from: 0.0);

      // Burst of heat sparks on tap
      final random = math.Random();
      for (int i = 0; i < 18; i++) {
        _particles.add(MidtermsParticle(
          x: tapPos.dx,
          y: tapPos.dy,
          vx: -1.2 + random.nextDouble() * 2.4,
          vy: -1.5 - random.nextDouble() * 2.5,
          size: 1.5 + random.nextDouble() * 2.0,
          alpha: 1.0,
          color: const Color(0xFFF59E0B),
          swayPhase: random.nextDouble() * 2 * math.pi,
        ));
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateAnimation);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HeaderAtmosphereWrapper(
      radius: 32.0,
      themeColor: const Color(0xFFF59E0B),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          borderRadius: 32.0,
          accentColor: const Color(0xFFF59E0B),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
            width: 1.2,
          ),
          glow: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _lastWidth = constraints.maxWidth;
                    _lastHeight = constraints.maxHeight;
                    return CustomPaint(
                      painter: MidtermsPainter(
                        progress: _controller.value,
                        steamOffset: _steamOffset,
                        particles: _particles,
                        showFocusText: _showFocusText,
                        focusScale: _focusScale,
                        focusOpacity: _focusOpacity,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 130),
                alignment: Alignment.centerLeft,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MidtermsParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  Color color;
  double swayFrequency;
  double swayPhase;

  MidtermsParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    this.color = Colors.white70,
    this.swayFrequency = 0.15,
    required this.swayPhase,
  });

  void update() {
    y += vy;
    // add horizontal sway using sine wave
    x += vx + math.sin(y * swayFrequency + swayPhase) * 0.25;
    alpha -= 0.02;
    if (alpha < 0) alpha = 0.0;
  }
}

class MidtermsPainter extends CustomPainter {
  final double progress;
  final double steamOffset;
  final List<MidtermsParticle> particles;
  final bool showFocusText;
  final double focusScale;
  final double focusOpacity;
  final bool isDark;

  MidtermsPainter({
    required this.progress,
    required this.steamOffset,
    required this.particles,
    required this.showFocusText,
    required this.focusScale,
    required this.focusOpacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.82;
    final double cy = size.height * 0.55;
    final baseColor = isDark ? Colors.white : Colors.black;

    // 1. Draw open flat textbook pages on the side
    final bookCoverPaint = Paint()..color = const Color(0xFF1E293B);
    final bookPagePaint = Paint()..color = Colors.white;
    final bookLinePaint = Paint()..color = Colors.black26..strokeWidth = 0.5;
    
    // Left page
    canvas.drawRect(Rect.fromLTWH(cx - 42, cy + 6, 11, 8), bookCoverPaint);
    canvas.drawRect(Rect.fromLTWH(cx - 41, cy + 7, 10, 6), bookPagePaint);
    canvas.drawLine(Offset(cx - 39, cy + 9), Offset(cx - 33, cy + 9), bookLinePaint);
    canvas.drawLine(Offset(cx - 39, cy + 11), Offset(cx - 34, cy + 11), bookLinePaint);
    
    // Right page
    canvas.drawRect(Rect.fromLTWH(cx - 30, cy + 6, 11, 8), bookCoverPaint);
    canvas.drawRect(Rect.fromLTWH(cx - 30, cy + 7, 10, 6), bookPagePaint);
    canvas.drawLine(Offset(cx - 28, cy + 9), Offset(cx - 22, cy + 9), bookLinePaint);
    canvas.drawLine(Offset(cx - 28, cy + 11), Offset(cx - 23, cy + 11), bookLinePaint);

    // Pencil resting on flat open book
    final penPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawLine(Offset(cx - 28, cy + 12), Offset(cx - 23, cy + 7), penPaint..strokeWidth = 0.8);

    // 2. Draw Study Books with details
    final bookPaint1 = Paint()..color = const Color(0xFF475569); // Slate cover
    final pagePaint = Paint()..color = Colors.white70;
    
    // Bottom book
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 19, cy + 7, 38, 8), const Radius.circular(1.5)), bookPaint1);
    canvas.drawRect(Rect.fromLTWH(cx - 17, cy + 9, 34, 4), pagePaint);
    
    // Draw page lines on the bottom book side
    final pageLinePaint = Paint()..color = Colors.black12..strokeWidth = 0.8;
    canvas.drawLine(Offset(cx - 16, cy + 10), Offset(cx + 16, cy + 10), pageLinePaint);
    canvas.drawLine(Offset(cx - 16, cy + 12), Offset(cx + 16, cy + 12), pageLinePaint);

    // Top Book
    final bookPaint2 = Paint()..color = const Color(0xFFF59E0B); // Amber cover
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 15, cy + 1, 30, 7), const Radius.circular(1.5)), bookPaint2);
    canvas.drawRect(Rect.fromLTWH(cx - 13, cy + 3, 26, 3), pagePaint);
    
    // Ribbon bookmark hanging out of the top book
    final ribbonPaint = Paint()..color = const Color(0xFFEF4444);
    final ribbonPath = Path()
      ..moveTo(cx + 8, cy + 5)
      ..lineTo(cx + 10, cy + 13)
      ..lineTo(cx + 12, cy + 11)
      ..lineTo(cx + 11, cy + 5)
      ..close();
    canvas.drawPath(ribbonPath, ribbonPaint);

    // Coaster under coffee cup
    final coasterPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 12, cy - 1, 24, 2), const Radius.circular(0.5)), coasterPaint);

    // 3. Draw Coffee Mug sitting on top
    final mugPaint = Paint()..color = const Color(0xFFD97706); // rich warm amber
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 10, cy - 15, 20, 16), const Radius.circular(3)), mugPaint);

    // Mug handle
    final handlePaint = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawArc(
      Rect.fromLTWH(cx + 5, cy - 12, 8, 10),
      -math.pi / 2,
      math.pi,
      false,
      handlePaint,
    );

    // Coffee surface color inside mug
    canvas.drawRect(Rect.fromLTWH(cx - 8.5, cy - 15, 17, 2), Paint()..color = const Color(0xFF5C3D2E));

    // 4. Draw Steam Lines rising (curly style)
    final steamPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.25 * (1.0 - progress))
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final double startX = cx - 6.0 + (i * 6.0);
      final double startY = cy - 17.0;
      final double waveProgress = (progress + i * 0.33) % 1.0;
      final double currentY = startY - (waveProgress * 16.0);
      final double swayX = math.sin(steamOffset * 1.5 + i * math.pi) * 2.5;

      final Path steamPath = Path();
      steamPath.moveTo(startX, startY);
      steamPath.cubicTo(
        startX + swayX, startY - 5.0,
        startX - swayX, startY - 10.0,
        startX + swayX * 0.5, currentY,
      );
      canvas.drawPath(steamPath, steamPaint);
    }

    // Floating math and science symbols
    final symbols = ['∑', 'π', 'x²', '√', '∫', '∞'];
    for (int i = 0; i < symbols.length; i++) {
      final double symbolProgress = (progress + i * 0.16) % 1.0;
      final double sy = cy - 18.0 - (symbolProgress * 30.0);
      final double sx = cx + (i - 2.5) * 8.0 + math.sin(steamOffset + i) * 3.5;
      
      final symSpan = TextSpan(
        text: symbols[i],
        style: TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.bold,
          color: (isDark ? Colors.white70 : Colors.black87).withValues(alpha: (1.0 - symbolProgress) * 0.45),
        ),
      );
      final symPainter = TextPainter(text: symSpan, textDirection: TextDirection.ltr)..layout();
      symPainter.paint(canvas, Offset(sx - symPainter.width / 2, sy));
    }

    // 5. Steam bubbles particles
    for (final p in particles) {
      if (p.alpha > 0.01) {
        final pPaint = Paint()
          ..color = p.color.withValues(alpha: p.alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(p.x, p.y), p.size, pPaint);
      }
    }

    // 6. FOCUS Overlay Text
    if (showFocusText && focusOpacity > 0.01) {
      canvas.save();
      canvas.translate(cx, cy - 25);
      canvas.scale(focusScale);
      
      final textSpan = TextSpan(
        text: 'FOCUS!',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFF59E0B),
          shadows: [
            BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.6), blurRadius: 4),
            const BoxShadow(color: Colors.black, blurRadius: 0.5, offset: Offset(0, 1)),
          ],
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================================================
// FINALS ANIMATION: CELEBRATION PAPERS THROWING & CONFETTI BLOWS
// ==========================================================================

class FinalsAnimationWidget extends StatefulWidget {
  final Widget child;
  const FinalsAnimationWidget({required this.child, super.key});

  @override
  State<FinalsAnimationWidget> createState() => _FinalsAnimationWidgetState();
}

class _FinalsAnimationWidgetState extends State<FinalsAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<FinalsPaperSheet> _papers = [];
  final List<FinalsConfetti> _confetti = [];
  bool _showDoneText = false;
  double _doneScale = 0.0;
  double _doneOpacity = 0.0;
  double _lastWidth = 350.0;
  double _lastHeight = 150.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _controller.addListener(_updateAnimation);
  }

  void _updateAnimation() {
    final t = _controller.value;

    if (t < 0.02) {
      _showDoneText = false;
      _doneScale = 0.0;
      _doneOpacity = 0.0;
      _papers.clear();
      _confetti.clear();
    }

    // Launch a paper and confetti at beginning of loop
    if (t >= 0.1 && t < 0.14 && _papers.isEmpty) {
      _launchPaperBatch(false);
    }

    // Animate DONE text
    if (_showDoneText) {
      final progressText = (t - 0.1) / 0.5;
      if (progressText >= 0.0 && progressText <= 1.0) {
        _doneScale = math.sin(progressText * math.pi) * 1.35;
        _doneOpacity = (1.0 - progressText).clamp(0.0, 1.0);
      } else {
        _showDoneText = false;
      }
    }

    // Update active papers and confetti
    for (final p in _papers) {
      p.update();
    }
    for (final c in _confetti) {
      c.update();
    }

    setState(() {});
  }

  void _launchPaperBatch(bool extra, [double? tapX, double? tapY]) {
    final random = math.Random();
    final int paperCount = extra ? 6 : 2;
    for (int i = 0; i < paperCount; i++) {
      final startX = tapX ?? (10.0 + random.nextDouble() * (_lastWidth - 20.0));
      final startY = tapY ?? (-20.0 + random.nextDouble() * 20.0);
      _papers.add(FinalsPaperSheet(
        x: startX,
        y: startY,
        vx: -1.2 + random.nextDouble() * 2.4,
        vy: tapY != null ? (-2.0 - random.nextDouble() * 2.5) : (0.5 + random.nextDouble() * 1.5),
        rotSpeed: -0.1 + random.nextDouble() * 0.2,
        scale: 0.6 + random.nextDouble() * 0.5,
      ));
    }

    final int confettiCount = extra ? 25 : 8;
    final List<Color> colors = [const Color(0xFFF43F5E), const Color(0xFF10B981), const Color(0xFF3A86FF), const Color(0xFFF59E0B)];
    for (int i = 0; i < confettiCount; i++) {
      final startX = tapX ?? (10.0 + random.nextDouble() * (_lastWidth - 20.0));
      final startY = tapY ?? (-20.0 + random.nextDouble() * 20.0);
      _confetti.add(FinalsConfetti(
        x: startX,
        y: startY,
        vx: -2.0 + random.nextDouble() * 4.0,
        vy: tapY != null ? (-2.5 - random.nextDouble() * 3.0) : (0.8 + random.nextDouble() * 2.0),
        color: colors[random.nextInt(colors.length)],
        size: 2.0 + random.nextDouble() * 2.0,
      ));
    }
  }

  void _handleTapDown(TapDownDetails details) {
    IrisHaptics.actionHeavy();
    final tapPos = details.localPosition;
    setState(() {
      _showDoneText = true;
      _controller.forward(from: 0.0);
      _launchPaperBatch(true, tapPos.dx, tapPos.dy);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateAnimation);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HeaderAtmosphereWrapper(
      radius: 32.0,
      themeColor: const Color(0xFFF43F5E),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          borderRadius: 32.0,
          backgroundColor: const Color(0xFF07080C).withValues(alpha: 0.94),
          border: Border.all(
            color: const Color(0xFFF43F5E).withValues(alpha: 0.32),
            width: 1.5,
          ),
          accentColor: const Color(0xFFF43F5E),
          glow: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _lastWidth = constraints.maxWidth;
                    _lastHeight = constraints.maxHeight;
                    return CustomPaint(
                      painter: FinalsPainter(
                        progress: _controller.value,
                        papers: _papers,
                        confetti: _confetti,
                        showDoneText: _showDoneText,
                        doneScale: _doneScale,
                        doneOpacity: _doneOpacity,
                        isDark: true, // Always dark obsidian mode
                      ),
                    );
                  },
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 130),
                alignment: Alignment.centerLeft,
                child: Theme(
                  data: ThemeData(
                    brightness: Brightness.dark,
                    primaryColor: const Color(0xFFF43F5E),
                  ),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FinalsPaperSheet {
  double x;
  double y;
  double vx;
  double vy;
  double rotation = 0.0;
  double rotSpeed;
  double scale;
  double alpha = 1.0;

  FinalsPaperSheet({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotSpeed,
    required this.scale,
  });

  void update() {
    x += vx;
    y += vy;
    vy += 0.08; // gravity
    vx += math.sin(y * 0.1) * 0.05; // flutter drift
    rotation += rotSpeed;
    alpha -= 0.015;
    if (alpha < 0) alpha = 0.0;
  }
}

class FinalsConfetti {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double alpha = 1.0;

  FinalsConfetti({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  });

  void update() {
    x += vx;
    y += vy;
    vy += 0.12; // heavier gravity
    alpha -= 0.025;
    if (alpha < 0) alpha = 0.0;
  }
}

class FinalsPainter extends CustomPainter {
  final double progress;
  final List<FinalsPaperSheet> papers;
  final List<FinalsConfetti> confetti;
  final bool showDoneText;
  final double doneScale;
  final double doneOpacity;
  final bool isDark;

  FinalsPainter({
    required this.progress,
    required this.papers,
    required this.confetti,
    required this.showDoneText,
    required this.doneScale,
    required this.doneOpacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.82;
    final double cy = size.height * 0.55;

    // 1. Draw graduation cap (mortarboard) at the bottom
    final capPaint = Paint()
      ..color = isDark ? Colors.white70 : Colors.black87
      ..style = PaintingStyle.fill;
      
    // Draw skull cap base
    canvas.drawArc(Rect.fromLTWH(cx - 7, cy + 9, 14, 10), math.pi, math.pi, true, capPaint);
    
    // Draw diamond top board
    final boardPath = Path()
      ..moveTo(cx, cy + 4)       // top
      ..lineTo(cx + 17, cy + 9)  // right
      ..lineTo(cx, cy + 14)      // bottom
      ..lineTo(cx - 17, cy + 9)  // left
      ..close();
    canvas.drawPath(boardPath, capPaint);
    
    // Tassel hanging down, swaying dynamically using a sine wave
    final double swayTassel = math.sin(progress * 2 * math.pi) * 3.5;
    final tasselPaint = Paint()
      ..color = const Color(0xFFF43F5E) // Crimson Rose theme
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final tasselPath = Path()
      ..moveTo(cx, cy + 9)
      ..lineTo(cx - 12 + swayTassel * 0.5, cy + 12)
      ..lineTo(cx - 14 + swayTassel, cy + 17);
    canvas.drawPath(tasselPath, tasselPaint);
    canvas.drawCircle(Offset(cx - 14 + swayTassel, cy + 17), 1.5, Paint()..color = const Color(0xFFF43F5E));

    // Rolled diploma scroll next to cap
    final scrollPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final scrollBorder = Paint()..color = (isDark ? Colors.white70 : Colors.black87)..style = PaintingStyle.stroke..strokeWidth = 0.8;
    final ribbonScroll = Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + 12, cy + 12, 12, 6), const Radius.circular(1.0)), scrollPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + 12, cy + 12, 12, 6), const Radius.circular(1.0)), scrollBorder);
    canvas.drawRect(Rect.fromLTWH(cx + 17, cy + 12, 2.5, 6), ribbonScroll);

    // 2. Draw Flying Papers
    for (final p in papers) {
      if (p.alpha > 0.01) {
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.rotation);
        canvas.scale(p.scale);
        
        final paperFill = Paint()..color = Colors.white.withValues(alpha: p.alpha);
        final borderFill = Paint()..color = (isDark ? Colors.white60 : Colors.black45).withValues(alpha: p.alpha)..strokeWidth = 0.8..style = PaintingStyle.stroke;
        final linesFill = Paint()..color = Colors.black26.withValues(alpha: p.alpha)..strokeWidth = 0.5;

        // Draw small sheet shape (rect)
        canvas.drawRect(const Rect.fromLTWH(-5, -7, 10, 14), paperFill);
        canvas.drawRect(const Rect.fromLTWH(-5, -7, 10, 14), borderFill);
        
        // Draw tiny text lines on paper
        canvas.drawLine(const Offset(-3, -3), const Offset(3, -3), linesFill);
        canvas.drawLine(const Offset(-3, 0), const Offset(2, 0), linesFill);
        canvas.drawLine(const Offset(-3, 3), const Offset(1, 3), linesFill);

        // Wind vector trail lines behind the sheet
        if (p.scale > 0.35) {
          final windPaint = Paint()..color = (isDark ? Colors.white24 : Colors.black12)..strokeWidth = 0.6;
          canvas.drawLine(const Offset(-8, 8), const Offset(-15, 15), windPaint);
        }
        
        canvas.restore();
      }
    }

    // 3. Draw Confetti Sparkles (Squares, Triangles & Circles)
    for (final c in confetti) {
      if (c.alpha > 0.01) {
        final cPaint = Paint()
          ..color = c.color.withValues(alpha: c.alpha)
          ..style = PaintingStyle.fill;
          
        final sizeIndex = c.size.toInt() % 3;
        if (sizeIndex == 0) {
          // Draw Square
          canvas.drawRect(Rect.fromLTWH(c.x - c.size / 2, c.y - c.size / 2, c.size, c.size), cPaint);
        } else if (sizeIndex == 1) {
          // Draw Triangle
          final triPath = Path()
            ..moveTo(c.x, c.y - c.size / 2)
            ..lineTo(c.x + c.size / 2, c.y + c.size / 2)
            ..lineTo(c.x - c.size / 2, c.y + c.size / 2)
            ..close();
          canvas.drawPath(triPath, cPaint);
        } else {
          // Draw Circle
          canvas.drawCircle(Offset(c.x, c.y), c.size / 2, cPaint);
        }
      }
    }

    // 4. DONE Overlay Text
    if (showDoneText && doneOpacity > 0.01) {
      canvas.save();
      canvas.translate(cx, cy - 25);
      canvas.scale(doneScale);
      
      final textSpan = TextSpan(
        text: 'DONE!',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFF43F5E),
          shadows: [
            BoxShadow(color: const Color(0xFFF43F5E).withValues(alpha: 0.6), blurRadius: 4),
            const BoxShadow(color: Colors.black, blurRadius: 0.5, offset: Offset(0, 1)),
          ],
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================================================
// TEACHER LOCATOR RADAR SWEEP ANIMATION
// ==========================================================================

class TeacherLocatorAnimationWidget extends StatefulWidget {
  final Widget child;
  const TeacherLocatorAnimationWidget({required this.child, super.key});

  @override
  State<TeacherLocatorAnimationWidget> createState() => _TeacherLocatorAnimationWidgetState();
}

class _TeacherLocatorAnimationWidgetState extends State<TeacherLocatorAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Offset> _tapPings = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    IrisHaptics.actionSoft();
    setState(() {
      _tapPings.add(details.localPosition);
      if (_tapPings.length > 5) _tapPings.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HeaderAtmosphereWrapper(
      radius: 36.0,
      themeColor: IrisTokens.purple,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          borderRadius: 36.0,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: TeacherLocatorPainter(
                        progress: _controller.value,
                        tapPings: _tapPings,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 130),
                alignment: Alignment.centerLeft,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeacherLocatorPainter extends CustomPainter {
  final double progress;
  final List<Offset> tapPings;
  final bool isDark;

  TeacherLocatorPainter({
    required this.progress,
    required this.tapPings,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.82;
    final double cy = size.height * 0.48;
    final baseColor = isDark ? Colors.white : Colors.black;
    final accentColor = IrisTokens.purple;

    // 1. Draw compass outer boundary with ticks
    final compassPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), 70, compassPaint);

    // Compass degree ticks & labels
    final tickPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    for (int deg = 0; deg < 360; deg += 30) {
      final double rad = deg * math.pi / 180;
      final double rStart = deg % 90 == 0 ? 66.0 : 68.0;
      final double rEnd = 70.0;
      canvas.drawLine(
        Offset(cx + math.cos(rad) * rStart, cy + math.sin(rad) * rStart),
        Offset(cx + math.cos(rad) * rEnd, cy + math.sin(rad) * rEnd),
        tickPaint,
      );
    }

    void _drawCompassLabel(String label, Offset pos) {
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 5.5,
          fontWeight: FontWeight.bold,
          color: baseColor.withValues(alpha: 0.4),
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2));
    }
    _drawCompassLabel("N", Offset(cx, cy - 75));
    _drawCompassLabel("S", Offset(cx, cy + 75));
    _drawCompassLabel("E", Offset(cx + 75, cy));
    _drawCompassLabel("W", Offset(cx - 75, cy));

    // 2. Draw radar concentric lines (some dashed)
    final radarPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;
    
    canvas.drawCircle(Offset(cx, cy), 15, radarPaint);
    canvas.drawCircle(Offset(cx, cy), 45, radarPaint);

    // Dashed concentric circles (30 and 60)
    final dashedRadarPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
      const int segments = 16;
      final double sweep = (2 * math.pi) / (segments * 2);
      for (int i = 0; i < segments; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          i * 2 * sweep,
          sweep,
          false,
          paint,
        );
      }
    }
    _drawDashedCircle(canvas, Offset(cx, cy), 30, dashedRadarPaint);
    _drawDashedCircle(canvas, Offset(cx, cy), 60, dashedRadarPaint);

    // Crosshairs
    canvas.drawLine(Offset(cx - 70, cy), Offset(cx + 70, cy), radarPaint);
    canvas.drawLine(Offset(cx, cy - 70), Offset(cx, cy + 70), radarPaint);

    // Axis ticks every 10 pixels
    for (double i = 10; i <= 60; i += 10) {
      canvas.drawLine(Offset(cx + i, cy - 2.0), Offset(cx + i, cy + 2.0), tickPaint);
      canvas.drawLine(Offset(cx - i, cy - 2.0), Offset(cx - i, cy + 2.0), tickPaint);
      canvas.drawLine(Offset(cx - 2.0, cy + i), Offset(cx + 2.0, cy + i), tickPaint);
      canvas.drawLine(Offset(cx - 2.0, cy - i), Offset(cx + 2.0, cy - i), tickPaint);
    }

    // 3. Draw radar sweeping cone (radius extended to 65)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          accentColor.withValues(alpha: 0.22),
          Colors.transparent,
        ],
        stops: const [0.05, 0.4],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 65));

    canvas.save();
    canvas.translate(cx, cy);
    canvas.drawCircle(Offset.zero, 65, sweepPaint);
    
    // Sweep line
    final double sweepAngle = progress * 2 * math.pi;
    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset.zero,
      Offset(math.cos(sweepAngle) * 65, math.sin(sweepAngle) * 65),
      linePaint,
    );
    canvas.restore();

    // 4. Blinking located nodes & Signal Vector Lines
    final Offset node1 = Offset(cx - 22, cy - 18);
    final Offset node2 = Offset(cx + 26, cy + 12);
    final Offset node3 = Offset(cx - 10, cy + 32);

    final vectorPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.08 + (math.sin(progress * 4 * math.pi) * 0.04).abs())
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Triangulation connection lines between located nodes
    final triangulationPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15 + (math.sin(progress * 2 * math.pi) * 0.08).abs())
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(node1, node2, triangulationPaint);
    canvas.drawLine(node2, node3, triangulationPaint);
    canvas.drawLine(node3, node1, triangulationPaint);

    // Central scan ring pulse expanding outward
    final double pulseRadius = progress * 65.0;
    final pulseRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accentColor.withValues(alpha: (1.0 - progress) * 0.25);
    canvas.drawCircle(Offset(cx, cy), pulseRadius, pulseRingPaint);

    // Draw vector lines from center to nodes
    canvas.drawLine(Offset(cx, cy), node1, vectorPaint);
    canvas.drawLine(Offset(cx, cy), node2, vectorPaint);
    canvas.drawLine(Offset(cx, cy), node3, vectorPaint);

    final nodePaint = Paint()
      ..color = IrisTokens.purpleLight.withValues(alpha: 0.4 + (math.sin(progress * 8 * math.pi) * 0.4).abs())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(node1, 3.5, nodePaint);
    canvas.drawCircle(node2, 4.0, nodePaint);
    canvas.drawCircle(node3, 3.0, nodePaint);

    // HUD target brackets [ ] around nodes
    final hudBracketPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.7 + (math.sin(progress * math.pi * 4) * 0.2))
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    void _drawHUDBrackets(Canvas canvas, Offset center, double size) {
      canvas.drawLine(center + Offset(-size, -size), center + Offset(-size + 3.0, -size), hudBracketPaint);
      canvas.drawLine(center + Offset(-size, -size), center + Offset(-size, -size + 3.0), hudBracketPaint);
      canvas.drawLine(center + Offset(size, -size), center + Offset(size - 3.0, -size), hudBracketPaint);
      canvas.drawLine(center + Offset(size, -size), center + Offset(size, -size + 3.0), hudBracketPaint);
      canvas.drawLine(center + Offset(-size, size), center + Offset(-size + 3.0, size), hudBracketPaint);
      canvas.drawLine(center + Offset(-size, size), center + Offset(-size, size - 3.0), hudBracketPaint);
      canvas.drawLine(center + Offset(size, size), center + Offset(size - 3.0, size), hudBracketPaint);
      canvas.drawLine(center + Offset(size, size), center + Offset(size, size - 3.0), hudBracketPaint);
    }

    _drawHUDBrackets(canvas, node1, 7.0);
    _drawHUDBrackets(canvas, node2, 8.0);
    _drawHUDBrackets(canvas, node3, 6.0);

    // Telemetry text printouts
    void _drawTelemetryText(String text, Offset pos) {
      final textSpan = TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 5.0,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          color: baseColor.withValues(alpha: 0.35),
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, pos);
    }
    _drawTelemetryText("AZ: 184°", Offset(cx - 68, cy + 50));
    _drawTelemetryText("DIST: 42m", Offset(cx - 68, cy + 56));
    _drawTelemetryText("SIGNAL: STABLE", Offset(cx + 26, cy - 60));

    // Blinking green status dot next to SIGNAL: STABLE
    final signalDotPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.4 + (math.sin(progress * 8 * math.pi) * 0.4).abs())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx + 21, cy - 58), 2.0, signalDotPaint);

    // 5. Tap pings
    for (final ping in tapPings) {
      final pingProgress = (progress * 2.0) % 1.0;
      final pingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = accentColor.withValues(alpha: (1.0 - pingProgress) * 0.45)
        ..strokeWidth = 1.5;
      canvas.drawCircle(ping, 30.0 * pingProgress, pingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TeacherLocatorPainter oldDelegate) => true;
}


// ==========================================================================
// ROOM FINDER ISOMETRIC BUILDING BLOCKS ANIMATION
// ==========================================================================

class RoomFinderAnimationWidget extends StatefulWidget {
  final Widget child;
  const RoomFinderAnimationWidget({required this.child, super.key});

  @override
  State<RoomFinderAnimationWidget> createState() => _RoomFinderAnimationWidgetState();
}

class _RoomFinderAnimationWidgetState extends State<RoomFinderAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Offset> _tapNodes = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    IrisHaptics.actionSoft();
    setState(() {
      _tapNodes.add(details.localPosition);
      if (_tapNodes.length > 5) _tapNodes.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HeaderAtmosphereWrapper(
      radius: 36.0,
      themeColor: IrisTokens.brand,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          borderRadius: 36.0,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: RoomFinderPainter(
                        progress: _controller.value,
                        tapNodes: _tapNodes,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 130),
                alignment: Alignment.centerLeft,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoomFinderPainter extends CustomPainter {
  final double progress;
  final List<Offset> tapNodes;
  final bool isDark;

  RoomFinderPainter({
    required this.progress,
    required this.tapNodes,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.82;
    final double cy = size.height * 0.48;
    final baseColor = isDark ? Colors.white : Colors.black;
    final accentColor = IrisTokens.brand;

    // 1. Draw floor grid compass rose indicator at corner
    final compassRoseColor = baseColor.withValues(alpha: 0.15);
    final compassLinePaint = Paint()..color = compassRoseColor..strokeWidth = 0.6;
    final cxCompass = cx - 36;
    final cyCompass = cy - 22;
    canvas.drawLine(Offset(cxCompass - 6, cyCompass), Offset(cxCompass + 6, cyCompass), compassLinePaint);
    canvas.drawLine(Offset(cxCompass, cyCompass - 6), Offset(cxCompass, cyCompass + 6), compassLinePaint);
    
    void _drawCompassLabel(String label, Offset pos) {
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 4.5,
          fontWeight: FontWeight.bold,
          color: baseColor.withValues(alpha: 0.25),
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2));
    }
    _drawCompassLabel("N", Offset(cxCompass, cyCompass - 9));
    _drawCompassLabel("S", Offset(cxCompass, cyCompass + 9));
    _drawCompassLabel("W", Offset(cxCompass - 9, cyCompass));
    _drawCompassLabel("E", Offset(cxCompass + 9, cyCompass));

    // Draw connecting floor plan lines (isometric grid)
    final pathPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.05)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Isometric Grid lines
    for (double offset = -30; offset <= 30; offset += 15) {
      canvas.drawLine(Offset(cx - 40 + offset, cy + 20), Offset(cx - 10 + offset, cy - 10), pathPaint);
      canvas.drawLine(Offset(cx - 40, cy + 20 + offset * 0.5), Offset(cx + 20, cy - 10 + offset * 0.5), pathPaint);
    }

    // Main floor plan boundary
    final floorPath = Path()
      ..moveTo(cx - 35, cy + 18)
      ..lineTo(cx - 5, cy - 12)
      ..lineTo(cx + 35, cy + 8)
      ..lineTo(cx + 5, cy + 38)
      ..close();
    canvas.drawPath(floorPath, pathPaint..color = baseColor.withValues(alpha: 0.1));

    // 2. Draw 3 isometric building blocks (buildings) - Draw back-left, then back-right, then front
    _drawBuildingBlock(canvas, cx - 18, cy + 5, 6.0, 26.0, const Color(0xFF10B981), progress);
    _drawBuildingBlock(canvas, cx + 18, cy + 17, 7.0, 16.0, IrisTokens.purple, progress + 0.3);
    _drawBuildingBlock(canvas, cx, cy + 26, 8.0, 12.0, IrisTokens.brand, progress + 0.6);

    // 3. Draw pulsing connecting line between block roofs
    final linkPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.25 + (math.sin(progress * math.pi * 2) * 0.15).abs())
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    final Offset roof1 = Offset(cx - 18, cy + 5 - 26.0);
    final Offset roof2 = Offset(cx + 18, cy + 17 - 16.0);
    final Offset roof3 = Offset(cx, cy + 26 - 12.0);

    canvas.drawLine(roof1, roof3, linkPaint);
    canvas.drawLine(roof2, roof3, linkPaint);

    // Pulsing room locator pin above front building roof
    final double hoverOffset = math.sin(progress * 4 * math.pi) * 3.0;
    final pinPaint = Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill;
    final pinOutline = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 0.6;
    final Offset pinPos = Offset(roof3.dx, roof3.dy - 12 + hoverOffset);
    final pinPath = Path()
      ..moveTo(pinPos.dx, pinPos.dy)
      ..lineTo(pinPos.dx - 3, pinPos.dy - 6)
      ..arcToPoint(Offset(pinPos.dx + 3, pinPos.dy - 6), radius: const Radius.circular(3.0))
      ..close();
    canvas.drawPath(pinPath, pinPaint);
    canvas.drawPath(pinPath, pinOutline);
    canvas.drawCircle(Offset(pinPos.dx, pinPos.dy - 6), 1.0, Paint()..color = Colors.white);

    // 4. Height measurement telemetry overlay on Block 1
    final measurePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.22)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 27, cy + 5), Offset(cx - 27, cy + 5 - 26.0), measurePaint);
    // Ticks
    for (double h = 0; h <= 26.0; h += 6.5) {
      canvas.drawLine(Offset(cx - 29, cy + 5 - h), Offset(cx - 25, cy + 5 - h), measurePaint);
    }

    // 5. Tap visual nodes
    for (final node in tapNodes) {
      final pulse = (progress * 2.0) % 1.0;
      final tapPaint = Paint()
        ..color = accentColor.withValues(alpha: (1.0 - pulse) * 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node, 20.0 * pulse, tapPaint);
    }
  }

  void _drawBuildingBlock(Canvas canvas, double x, double y, double size, double height, Color color, double localProgress) {
    final double dx = size;
    final double dy = size * 0.5;
    final double h = height;

    final t0 = Offset(x, y - h);
    final t1 = Offset(x - dx, y - dy - h);
    final t2 = Offset(x + dx, y - dy - h);
    final t3 = Offset(x, y - 2 * dy - h);

    final p0 = Offset(x, y);
    final p1 = Offset(x - dx, y - dy);
    final p2 = Offset(x + dx, y - dy);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Left face
    final leftPath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(t1.dx, t1.dy)
      ..lineTo(t0.dx, t0.dy)
      ..close();

    // Right face
    final rightPath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(t2.dx, t2.dy)
      ..lineTo(t0.dx, t0.dy)
      ..close();

    // Top face
    final topPath = Path()
      ..moveTo(t0.dx, t0.dy)
      ..lineTo(t1.dx, t1.dy)
      ..lineTo(t3.dx, t3.dy)
      ..lineTo(t2.dx, t2.dy)
      ..close();

    // Paint faces with shaded fill opacities
    canvas.drawPath(leftPath, Paint()..color = color.withValues(alpha: 0.32)..style = PaintingStyle.fill);
    canvas.drawPath(rightPath, Paint()..color = color.withValues(alpha: 0.16)..style = PaintingStyle.fill);
    canvas.drawPath(topPath, Paint()..color = color.withValues(alpha: 0.5)..style = PaintingStyle.fill);

    // Draw outline borders
    canvas.drawPath(leftPath, borderPaint);
    canvas.drawPath(rightPath, borderPaint);
    canvas.drawPath(topPath, borderPaint);

    // Draw tiny glowing window grids on left & right faces
    final windowPaint = Paint()
      ..color = const Color(0xFFFDE047).withValues(alpha: 0.4 + (math.sin(localProgress * 5 * math.pi) * 0.35).abs())
      ..style = PaintingStyle.fill;

    // Left windows (along vector [-dx, -dy])
    for (double i = 0.25; i <= 0.75; i += 0.25) {
      for (double j = 0.2; j <= 0.8; j += 0.3) {
        final wx = x - dx * i;
        final wy = y - dy * i - h * j;
        canvas.drawCircle(Offset(wx, wy), 0.7, windowPaint);
      }
    }

    // Right windows (along vector [dx, -dy])
    for (double i = 0.25; i <= 0.75; i += 0.25) {
      for (double j = 0.2; j <= 0.8; j += 0.3) {
        final wx = x + dx * i;
        final wy = y - dy * i - h * j;
        canvas.drawCircle(Offset(wx, wy), 0.7, windowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RoomFinderPainter oldDelegate) => true;
}


// ==========================================================================
// CGPA CALCULATOR DYNAMIC CHART & GAUGE ANIMATION
// ==========================================================================

class CgpaCalculatorAnimationWidget extends StatefulWidget {
  final Widget child;
  const CgpaCalculatorAnimationWidget({required this.child, super.key});

  @override
  State<CgpaCalculatorAnimationWidget> createState() => _CgpaCalculatorAnimationWidgetState();
}

class _CgpaCalculatorAnimationWidgetState extends State<CgpaCalculatorAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<({Offset pos, String sign, double alpha, double yOffset})> _mathFloat = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _controller.addListener(_updateFloaters);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateFloaters() {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _mathFloat.length; i++) {
        final item = _mathFloat[i];
        final nextAlpha = (item.alpha - 0.015).clamp(0.0, 1.0);
        final nextY = item.yOffset - 0.5;
        _mathFloat[i] = (pos: item.pos, sign: item.sign, alpha: nextAlpha, yOffset: nextY);
      }
      _mathFloat.removeWhere((element) => element.alpha <= 0.01);
    });
  }

  void _handleTapDown(TapDownDetails details) {
    IrisHaptics.actionSoft();
    final random = math.Random();
    final signs = ['+', '-', '÷', '×', 'GPA', 'A+', '4.0'];
    setState(() {
      _mathFloat.add((
        pos: details.localPosition,
        sign: signs[random.nextInt(signs.length)],
        alpha: 1.0,
        yOffset: 0.0
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HeaderAtmosphereWrapper(
      radius: 36.0,
      themeColor: IrisTokens.brand,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          borderRadius: 36.0,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: CgpaCalculatorPainter(
                        progress: _controller.value,
                        floaters: _mathFloat,
                        isDark: isDark,
                      ),
                    );
                  }
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 130),
                alignment: Alignment.centerLeft,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CgpaCalculatorPainter extends CustomPainter {
  final double progress;
  final List<({Offset pos, String sign, double alpha, double yOffset})> floaters;
  final bool isDark;

  CgpaCalculatorPainter({
    required this.progress,
    required this.floaters,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.82;
    final double cy = size.height * 0.48;
    final baseColor = isDark ? Colors.white : Colors.black;
    final accentColor = IrisTokens.brand;

    // 1. Draw outer bezel ring
    final bezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = baseColor.withValues(alpha: 0.12);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy + 12), radius: 30),
      math.pi,
      math.pi,
      false,
      bezelPaint,
    );

    // 2. Draw half-circle speed gauge for GPA tiers
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = baseColor.withValues(alpha: 0.06);

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy + 12), radius: 24),
      math.pi,
      math.pi,
      false,
      arcPaint,
    );

    // Draw active tier filling
    final activeArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = accentColor;
    
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy + 12), radius: 24),
      math.pi,
      math.pi * 0.82, // 82% representing 3.28+ GPA level
      false,
      activeArcPaint,
    );

    // Draw division ticks along the speed gauge dial (extended for detail)
    final tickPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.25)
      ..strokeWidth = 1.2;
    for (int i = 0; i <= 12; i++) {
      final double angle = math.pi + (i / 12.0) * math.pi;
      final double rStart = i % 3 == 0 ? 21.0 : 23.0;
      final double rEnd = 27.5;
      canvas.drawLine(
        Offset(cx + math.cos(angle) * rStart, cy + 12 + math.sin(angle) * rStart),
        Offset(cx + math.cos(angle) * rEnd, cy + 12 + math.sin(angle) * rEnd),
        tickPaint,
      );
    }

    // Draw GPA labels under the dial
    void _drawGpaText(String text, Offset pos) {
      final textSpan = TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 7.0,
          fontWeight: FontWeight.bold,
          color: baseColor.withValues(alpha: 0.5),
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2));
    }
    _drawGpaText("2.0", Offset(cx - 35, cy + 12));
    _drawGpaText("3.0", Offset(cx, cy - 18));
    _drawGpaText("4.0", Offset(cx + 35, cy + 12));

    // Digital readout inside the bezel
    final digitalSpan = TextSpan(
      text: "3.28",
      style: TextStyle(
        fontSize: 8.5,
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        color: baseColor.withValues(alpha: 0.8),
      ),
    );
    final digitalPainter = TextPainter(text: digitalSpan, textDirection: TextDirection.ltr)..layout();
    digitalPainter.paint(canvas, Offset(cx - digitalPainter.width / 2 - 4, cy - 2));

    // Glowing golden A+ medal badge next to digital readout
    final badgePaint = Paint()..color = const Color(0xFFFBBF24)..style = PaintingStyle.fill;
    final badgeOutline = Paint()..color = const Color(0xFFD97706)..style = PaintingStyle.stroke..strokeWidth = 0.8;
    final bxBadge = cx + 18;
    final byBadge = cy - 2;
    canvas.drawCircle(Offset(bxBadge, byBadge), 6.0, badgePaint);
    canvas.drawCircle(Offset(bxBadge, byBadge), 6.0, badgeOutline);
    
    final aPlusSpan = TextSpan(
      text: "A+",
      style: TextStyle(
        fontSize: 6.5,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF78350F),
      ),
    );
    final aPlusPainter = TextPainter(text: aPlusSpan, textDirection: TextDirection.ltr)..layout();
    aPlusPainter.paint(canvas, Offset(bxBadge - aPlusPainter.width / 2, byBadge - aPlusPainter.height / 2));

    // 3. Draw gauge dial pointer needle
    final pointerPaint = Paint()
      ..color = baseColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final double pointerAngle = -math.pi + (0.82 * math.pi) + (math.sin(progress * math.pi * 4) * 0.04);
    canvas.drawLine(
      Offset(cx, cy + 12),
      Offset(cx + math.cos(pointerAngle) * 20, cy + 12 + math.sin(pointerAngle) * 20),
      pointerPaint,
    );
    canvas.drawCircle(Offset(cx, cy + 12), 3.0, Paint()..color = baseColor);

    // 4. Draw horizontal telemetry grid lines behind bar charts
    final gridPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    for (double gy = 0; gy <= 12; gy += 4) {
      canvas.drawLine(Offset(cx - 50, cy + 12 - gy), Offset(cx - 20, cy + 12 - gy), gridPaint);
    }

    // Draw mini vertical bar charts (5 bars with alternating colors)
    for (int i = 0; i < 5; i++) {
      final barHeight = 6.0 + math.sin((progress * math.pi * 2) + (i * 1.0)) * 6.0;
      final bx = cx - 48.0 + (i * 6.0);
      final isEven = i % 2 == 0;
      final barPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = (isEven ? IrisTokens.blue : IrisTokens.purple).withValues(alpha: 0.3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, cy + 12 - barHeight, 3.5, barHeight),
          const Radius.circular(1),
        ),
        barPaint,
      );
    }

    // 5. Render floating math signs in a spiral trajectory
    for (final f in floaters) {
      if (f.alpha > 0.01) {
        final textSpan = TextSpan(
          text: f.sign,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: accentColor.withValues(alpha: f.alpha),
          ),
        );
        final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
        final double spiralX = math.sin(f.yOffset * 0.15) * 12.0;
        textPainter.paint(canvas, Offset(f.pos.dx - textPainter.width / 2 + spiralX, f.pos.dy + f.yOffset));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CgpaCalculatorPainter oldDelegate) => true;
}


// ==========================================================================
// DIRECTORY SERVERS SYNAPTIC TREE NODE ANIMATION
// ==========================================================================

class DirectoryAnimationWidget extends StatefulWidget {
  final Widget child;
  const DirectoryAnimationWidget({required this.child, super.key});

  @override
  State<DirectoryAnimationWidget> createState() => _DirectoryAnimationWidgetState();
}

class _DirectoryAnimationWidgetState extends State<DirectoryAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Offset> _tapPulses = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    IrisHaptics.actionSoft();
    setState(() {
      _tapPulses.add(details.localPosition);
      if (_tapPulses.length > 5) _tapPulses.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HeaderAtmosphereWrapper(
      radius: 36.0,
      themeColor: IrisTokens.blue,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          borderRadius: 36.0,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: DirectoryPainter(
                        progress: _controller.value,
                        tapPulses: _tapPulses,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 130),
                alignment: Alignment.centerLeft,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DirectoryPainter extends CustomPainter {
  final double progress;
  final List<Offset> tapPulses;
  final bool isDark;

  DirectoryPainter({
    required this.progress,
    required this.tapPulses,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.82;
    final double cy = size.height * 0.48;
    final baseColor = isDark ? Colors.white : Colors.black;
    final accentColor = IrisTokens.blue;

    final root = Offset(cx, cy);
    final subLeft = Offset(cx - 15, cy - 6);
    final subRight = Offset(cx + 15, cy + 6);
    final subTop = Offset(cx, cy - 20);

    final leafL1 = Offset(cx - 28, cy - 18);
    final leafL2 = Offset(cx - 10, cy - 24);
    final leafR1 = Offset(cx + 10, cy + 24);
    final leafR2 = Offset(cx + 28, cy + 18);
    final leafC1 = Offset(cx - 22, cy + 18);
    final leafC2 = Offset(cx + 22, cy - 18);
    
    final leafT1 = Offset(cx - 12, cy - 36);
    final leafT2 = Offset(cx + 12, cy - 36);

    final List<(Offset, Offset)> connections = [
      (root, subLeft),
      (root, subRight),
      (root, subTop),
      (root, leafC2),
      (subLeft, leafL1),
      (subLeft, leafL2),
      (subLeft, leafC1),
      (subRight, leafR1),
      (subRight, leafR2),
      (subTop, leafT1),
      (subTop, leafT2),
      // Triangulation synapses between leaves (mesh synapse)
      (leafL1, leafL2),
      (leafL2, leafT1),
      (leafT2, leafC2),
      (leafC2, leafR2),
      (leafR2, leafR1),
      (leafC1, leafL1),
    ];

    // Glow connection lines
    final linePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    for (final conn in connections) {
      canvas.drawLine(conn.$1, conn.$2, linePaint);
    }

    // Outer orbit ring around root node
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor.withValues(alpha: 0.04)
      ..strokeWidth = 0.8;
    void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
      const int segments = 12;
      final double sweep = (2 * math.pi) / (segments * 2);
      for (int i = 0; i < segments; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          (i * 2 * sweep) + (progress * 0.8),
          sweep,
          false,
          paint,
        );
      }
    }
    _drawDashedCircle(canvas, root, 10.0, orbitPaint);

    final corePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    final subNodePaint = Paint()
      ..color = IrisTokens.purple.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final leafPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    // Draw nodes
    canvas.drawCircle(root, 4.5, corePaint);
    canvas.drawCircle(subLeft, 3.5, subNodePaint);
    canvas.drawCircle(subRight, 3.5, subNodePaint);
    canvas.drawCircle(subTop, 3.5, subNodePaint);

    final List<Offset> leaves = [leafL1, leafL2, leafR1, leafR2, leafC1, leafC2, leafT1, leafT2];
    for (final leaf in leaves) {
      canvas.drawCircle(leaf, 2.2, leafPaint);
      
      // Pulsing auric ring around leaf node
      final double auricPulse = (progress + leaves.indexOf(leaf) * 0.12) % 1.0;
      final auricPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = accentColor.withValues(alpha: (1.0 - auricPulse) * 0.35);
      canvas.drawCircle(leaf, 2.2 + auricPulse * 5.0, auricPaint);
    }

    // Floating binary telemetry text
    void _drawBinaryText(String text, Offset pos, double opacity) {
      final binSpan = TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 4.5,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          color: accentColor.withValues(alpha: opacity),
        ),
      );
      final binPainter = TextPainter(text: binSpan, textDirection: TextDirection.ltr)..layout();
      binPainter.paint(canvas, pos);
    }
    final double bProgress = progress % 1.0;
    _drawBinaryText("01", Offset(cx - 38, cy - 8 - bProgress * 10), (1.0 - bProgress) * 0.35);
    _drawBinaryText("DB", Offset(cx + 28, cy - 20 - bProgress * 12), (1.0 - bProgress) * 0.3);
    _drawBinaryText("OK", Offset(cx - 5, cy + 22 - bProgress * 8), (1.0 - bProgress) * 0.4);

    // Pulse data packets with tail trailing particles
    for (int i = 0; i < connections.length; i++) {
      final conn = connections[i];
      final double t = (progress + (i * 0.12)) % 1.0;
      final pos = Offset.lerp(conn.$1, conn.$2, t)!;
      
      // Main packet
      canvas.drawCircle(pos, 1.8, Paint()..color = accentColor.withValues(alpha: 0.8)..style = PaintingStyle.fill);
      
      // Trail particles (shrunk and faded behind it)
      if (t > 0.06) {
        final posTrail1 = Offset.lerp(conn.$1, conn.$2, t - 0.04)!;
        canvas.drawCircle(posTrail1, 1.2, Paint()..color = accentColor.withValues(alpha: 0.45)..style = PaintingStyle.fill);
      }
      if (t > 0.12) {
        final posTrail2 = Offset.lerp(conn.$1, conn.$2, t - 0.08)!;
        canvas.drawCircle(posTrail2, 0.7, Paint()..color = accentColor.withValues(alpha: 0.2)..style = PaintingStyle.fill);
      }
    }

    // Tap ripples
    for (final tap in tapPulses) {
      final pulse = (progress * 2.0) % 1.0;
      final tapPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = accentColor.withValues(alpha: (1.0 - pulse) * 0.45)
        ..strokeWidth = 1.2;
      canvas.drawCircle(tap, 25.0 * pulse, tapPaint);
    }
  }

  @override
  bool shouldRepaint(covariant DirectoryPainter oldDelegate) => true;
}

class DirectoryBackgroundWidget extends StatefulWidget {
  const DirectoryBackgroundWidget({super.key});

  @override
  State<DirectoryBackgroundWidget> createState() => _DirectoryBackgroundWidgetState();
}

class _DirectoryBackgroundWidgetState extends State<DirectoryBackgroundWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: DirectoryPainter(
            progress: _controller.value,
            tapPulses: const [],
            isDark: isDark,
          ),
        );
      },
    );
  }
}

