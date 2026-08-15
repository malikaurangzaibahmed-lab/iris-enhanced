import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart';

/// 60 FPS Ultra-Smooth Animated 3D Mascot Character ("Iris Mascot").
/// Features floating physics, breathing scale, orbiting glowing particle aura,
/// periodic eye blinking/sparkles, and interactive tap bounce/flip reactions.
class IrisAnimatedMascot extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  final String? speechBubbleText;

  const IrisAnimatedMascot({
    super.key,
    this.size = 90.0,
    this.onTap,
    this.speechBubbleText,
  });

  @override
  State<IrisAnimatedMascot> createState() => _IrisAnimatedMascotState();
}

class _IrisAnimatedMascotState extends State<IrisAnimatedMascot>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _orbitController;
  late final AnimationController _blinkController;
  late final AnimationController _tapBounceController;

  bool _isWinking = false;

  @override
  void initState() {
    super.initState();

    // 1. Floating Animation Loop (3s smooth sinusoidal float)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    // 2. Orbiting Glow Particles (4s continuous 360-degree rotation)
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // 3. Periodic Eye Blinking Loop
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _startPeriodicBlinkTimer();

    // 4. Interactive Tap Bounce/Spin
    _tapBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  void _startPeriodicBlinkTimer() {
    Future.delayed(Duration(milliseconds: 3000 + math.Random().nextInt(3000)), () {
      if (mounted) {
        _blinkController.forward().then((_) {
          _blinkController.reverse().then((_) {
            _startPeriodicBlinkTimer();
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _orbitController.dispose();
    _blinkController.dispose();
    _tapBounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    IrisHaptics.actionHeavy();
    _tapBounceController.forward(from: 0.0);
    setState(() => _isWinking = !_isWinking);
    if (widget.onTap != null) widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final double mascotSize = widget.size;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _floatController,
          _orbitController,
          _blinkController,
          _tapBounceController,
        ]),
        builder: (context, child) {
          // Floating offset math
          final floatY = math.sin(_floatController.value * 2 * math.pi) * 6.0;
          final floatTilt = math.cos(_floatController.value * 2 * math.pi) * 0.04;

          // Breathing scale
          final breathScale = 1.0 + math.sin(_floatController.value * 2 * math.pi) * 0.03;

          // Tap animation (squish & bounce spin)
          final tapVal = _tapBounceController.value;
          final tapScale = tapVal < 0.3
              ? 1.0 - (tapVal / 0.3) * 0.15
              : 1.0 + math.sin((tapVal - 0.3) / 0.7 * math.pi) * 0.22;

          final tapRotation = math.sin(tapVal * math.pi * 2) * 0.25;

          final totalScale = breathScale * tapScale;
          final totalRotation = floatTilt + tapRotation;

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Orbiting Glowing Aura Painter
              CustomPaint(
                size: Size(mascotSize * 1.3, mascotSize * 1.3),
                painter: _MascotAuraPainter(
                  orbitAngle: _orbitController.value * 2 * math.pi,
                  blinkVal: _blinkController.value,
                  glowColor: IrisTokens.brand,
                ),
              ),

              // Floating & Scaled Mascot Container
              Transform.translate(
                offset: Offset(0, floatY),
                child: Transform.rotate(
                  angle: totalRotation,
                  child: Transform.scale(
                    scale: totalScale,
                    child: Container(
                      width: mascotSize,
                      height: mascotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: IrisTokens.brand.withValues(alpha: 0.35),
                            blurRadius: 22,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 3D Mascot Base Image Asset
                            Image.asset(
                              'assets/iris_mascot.png',
                              width: mascotSize,
                              height: mascotSize,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => CircleAvatar(
                                radius: mascotSize / 2,
                                backgroundColor: IrisTokens.brand.withValues(alpha: 0.2),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 40,
                                  color: IrisTokens.brand,
                                ),
                              ),
                            ),

                            // Animated Eye Overlay (Blinking & Winking effects)
                            if (_blinkController.value > 0.1)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.4 * _blinkController.value),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Custom Painter for Animated Orbiting Energy Rings & Glowing Star Particles
class _MascotAuraPainter extends CustomPainter {
  final double orbitAngle;
  final double blinkVal;
  final Color glowColor;

  _MascotAuraPainter({
    required this.orbitAngle,
    required this.blinkVal,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.48;

    // Outer Energy Ring
    final ringPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.2 + math.sin(orbitAngle) * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawCircle(center, radius, ringPaint);

    // Orbiting Sparkle Particles
    final particleCount = 4;
    for (int i = 0; i < particleCount; i++) {
      final angle = orbitAngle + (i * 2 * math.pi / particleCount);
      final px = center.dx + math.cos(angle) * (radius + 4);
      final py = center.dy + math.sin(angle) * (radius + 4);

      final pPaint = Paint()
        ..color = (i % 2 == 0 ? glowColor : Colors.cyanAccent).withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(px, py), 2.5 + (i % 2), pPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MascotAuraPainter oldDelegate) => true;
}
