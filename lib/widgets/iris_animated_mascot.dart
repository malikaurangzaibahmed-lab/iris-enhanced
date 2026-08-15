import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart';

/// 60 FPS Ultra-Smooth Full-Body 3D Rigged Animated Mascot Character ("Iris Mascot").
/// Features a fully animated cartoon body: waving moving hands/arms, volumetric 3D torso,
/// floating feet, expressive eyes, Matrix4 3D perspective physics, and 360-degree tap reactions.
class IrisAnimatedMascot extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  final String? speechBubbleText;

  const IrisAnimatedMascot({
    super.key,
    this.size = 110.0,
    this.onTap,
    this.speechBubbleText,
  });

  @override
  State<IrisAnimatedMascot> createState() => _IrisAnimatedMascotState();
}

class _IrisAnimatedMascotState extends State<IrisAnimatedMascot>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _waveController;
  late final AnimationController _orbitController;
  late final AnimationController _tapBounceController;
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();

    // 1. Floating Animation Loop (2.6s smooth sinusoidal float)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // 2. Hand Waving & Arm Animation Loop (1.8s continuous wave motion)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // 3. Orbiting Energy Particles (3.2s continuous 360-degree rotation)
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // 4. Interactive 3D 360-degree Spin & High-Five Jump
    _tapBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // 5. Periodic Eye Blinking
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _startPeriodicBlinkTimer();
  }

  void _startPeriodicBlinkTimer() {
    Future.delayed(Duration(milliseconds: 2800 + math.Random().nextInt(2500)), () {
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
    _waveController.dispose();
    _orbitController.dispose();
    _tapBounceController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _handleTap() {
    IrisHaptics.actionHeavy();
    _tapBounceController.forward(from: 0.0);
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
          _waveController,
          _orbitController,
          _tapBounceController,
          _blinkController,
        ]),
        builder: (context, child) {
          final floatVal = _floatController.value;
          final waveVal = _waveController.value;
          final orbitVal = _orbitController.value;
          final tapVal = _tapBounceController.value;
          final blinkVal = _blinkController.value;

          // 3D Physics & Rigging Parameters
          final floatY = math.sin(floatVal * 2 * math.pi) * 8.0;
          final breathScale = 1.0 + math.sin(floatVal * 2 * math.pi) * 0.03;

          // Hand Waving Angle (-0.3 to +0.45 radians)
          final waveAngle = -0.3 + (math.sin(waveVal * math.pi * 2) * 0.40);

          // 3D Matrix4 Transformations
          final rotateY = tapVal * 2 * math.pi * 2; // 360 3D Spin on tap!
          final tapJumpY = math.sin(tapVal * math.pi) * -22.0;

          final tapScale = tapVal < 0.2
              ? 1.0 - (tapVal / 0.2) * 0.12
              : 1.0 + math.sin((tapVal - 0.2) / 0.8 * math.pi) * 0.22;

          final transformMatrix = Matrix4.identity()
            ..setEntry(3, 2, 0.0018) // 3D Lens Depth Perspective
            ..translate(0.0, floatY + tapJumpY, 0.0)
            ..rotateY(rotateY)
            ..scale(breathScale * tapScale);

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Full-Body 3D Rigged Canvas Painter (Head, Torso, Waving Hands, Feet, Aura & Shadow)
              Transform(
                transform: transformMatrix,
                alignment: Alignment.center,
                child: CustomPaint(
                  size: Size(mascotSize, mascotSize * 1.25),
                  painter: _MascotFullBodyPainter(
                    waveAngle: waveAngle,
                    orbitAngle: orbitVal * 2 * math.pi,
                    blinkVal: blinkVal,
                    tapVal: tapVal,
                    primaryColor: IrisTokens.brand,
                    secondaryColor: const Color(0xFF06B6D4),
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

/// 3D Vector Graphics Character Painter: Renders fully rigged Head, Torso, Moving Arms/Hands, Feet & Aura
class _MascotFullBodyPainter extends CustomPainter {
  final double waveAngle;
  final double orbitAngle;
  final double blinkVal;
  final double tapVal;
  final Color primaryColor;
  final Color secondaryColor;

  _MascotFullBodyPainter({
    required this.waveAngle,
    required this.orbitAngle,
    required this.blinkVal,
    required this.tapVal,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. GROUND 3D SHADOW
    final shadowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * 0.96), width: w * 0.60, height: 12),
      shadowPaint,
    );

    // 2. ORBITING ENERGY HALO RING
    final haloPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * 0.52), width: w * 1.15, height: h * 0.28),
      haloPaint,
    );

    // Halo Sparkles
    for (int i = 0; i < 4; i++) {
      final angle = orbitAngle + (i * math.pi / 2);
      final px = w / 2 + math.cos(angle) * (w * 0.58);
      final py = h * 0.52 + math.sin(angle) * (h * 0.14);
      final sparklePaint = Paint()..color = i % 2 == 0 ? primaryColor : secondaryColor;
      canvas.drawCircle(Offset(px, py), 3.0, sparklePaint);
    }

    // 3. FLOATING FEET (Right & Left)
    final footPaint = Paint()
      ..shader = RadialGradient(
        colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.32, h * 0.82, w * 0.15, 14),
        const Radius.circular(8),
      ),
      footPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.53, h * 0.82, w * 0.15, 14),
        const Radius.circular(8),
      ),
      footPaint,
    );

    // 4. VOLUMETRIC 3D TORSO / BODY SPHERE
    final torsoCenter = Offset(w / 2, h * 0.62);
    final torsoRadius = w * 0.28;

    final torsoPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
        colors: [
          primaryColor,
          primaryColor.withValues(alpha: 0.8),
          const Color(0xFF0F172A),
        ],
      ).createShader(Rect.fromCircle(center: torsoCenter, radius: torsoRadius));

    canvas.drawCircle(torsoCenter, torsoRadius, torsoPaint);

    // Chest Glowing Emblem ('✨')
    final emblemPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(torsoCenter, 6.0, emblemPaint);

    // 5. MOVING & WAVING HANDS / ARMS

    // Left Arm & Waving Hand (Active Wave Rig)
    final leftShoulder = Offset(w * 0.26, h * 0.58);
    canvas.save();
    canvas.translate(leftShoulder.dx, leftShoulder.dy);
    canvas.rotate(waveAngle);

    final armPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7.0;

    canvas.drawLine(Offset.zero, const Offset(-18, -18), armPaint);

    // Waving Hand Glove Sphere
    final handPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, primaryColor],
      ).createShader(const Rect.fromLTWH(-28, -28, 20, 20));

    canvas.drawCircle(const Offset(-20, -20), 8.5, handPaint);
    canvas.restore();

    // Right Arm & Rest Hand (Gentle Float)
    final rightShoulder = Offset(w * 0.74, h * 0.58);
    final rightArmAngle = 0.25 + (tapVal > 0 ? -math.sin(tapVal * math.pi) * 0.8 : 0.0);
    canvas.save();
    canvas.translate(rightShoulder.dx, rightShoulder.dy);
    canvas.rotate(rightArmAngle);

    canvas.drawLine(Offset.zero, const Offset(18, 14), armPaint);
    canvas.drawCircle(const Offset(20, 16), 8.0, handPaint);
    canvas.restore();

    // 6. 3D HEAD & EXPRESSIVE CARTOON FACE
    final headCenter = Offset(w / 2, h * 0.32);
    final headRadius = w * 0.32;

    final headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.9,
        colors: [
          primaryColor,
          primaryColor.withValues(alpha: 0.85),
          const Color(0xFF1E293B),
        ],
      ).createShader(Rect.fromCircle(center: headCenter, radius: headRadius));

    canvas.drawCircle(headCenter, headRadius, headPaint);

    // Specular Top-Left Highlight
    final headSpecular = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.45),
        radius: 0.45,
        colors: [
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: headCenter, radius: headRadius));
    canvas.drawCircle(headCenter, headRadius, headSpecular);

    // Cute Antenna / Head Crown Gem
    canvas.drawLine(Offset(w / 2, h * 0.08), Offset(w / 2, h * 0.16), armPaint);
    canvas.drawCircle(Offset(w / 2, h * 0.07), 6.5, Paint()..color = secondaryColor);

    // Expressive Eyes (Left & Right Glossy Cartoon Eyes)
    final leftEyeCenter = Offset(w * 0.40, h * 0.31);
    final rightEyeCenter = Offset(w * 0.60, h * 0.31);

    if (blinkVal < 0.7) {
      // Open Glowing Eyes
      final eyeWhitePaint = Paint()..color = Colors.white;
      canvas.drawOval(Rect.fromCenter(center: leftEyeCenter, width: 14, height: 18), eyeWhitePaint);
      canvas.drawOval(Rect.fromCenter(center: rightEyeCenter, width: 14, height: 18), eyeWhitePaint);

      // Pupils & Sparkles
      final pupilPaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawCircle(Offset(leftEyeCenter.dx + 1, leftEyeCenter.dy + 1), 5.0, pupilPaint);
      canvas.drawCircle(Offset(rightEyeCenter.dx - 1, rightEyeCenter.dy + 1), 5.0, pupilPaint);

      // Eye Catchlight Sparkle
      canvas.drawCircle(Offset(leftEyeCenter.dx - 2, leftEyeCenter.dy - 3), 2.0, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(rightEyeCenter.dx - 4, rightEyeCenter.dy - 3), 2.0, Paint()..color = Colors.white);
    } else {
      // Blinking Eyes (Cute Happy Curved Lines)
      final blinkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCenter(center: leftEyeCenter, width: 12, height: 10),
        0,
        math.pi,
        false,
        blinkPaint,
      );
      canvas.drawArc(
        Rect.fromCenter(center: rightEyeCenter, width: 12, height: 10),
        0,
        math.pi,
        false,
        blinkPaint,
      );
    }

    // Happy Cartoon Smile Curve
    final smilePath = Path()
      ..moveTo(w * 0.44, h * 0.41)
      ..quadraticBezierTo(w / 2, h * 0.46, w * 0.56, h * 0.41);

    final smilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    canvas.drawPath(smilePath, smilePaint);
  }

  @override
  bool shouldRepaint(covariant _MascotFullBodyPainter oldDelegate) => true;
}
