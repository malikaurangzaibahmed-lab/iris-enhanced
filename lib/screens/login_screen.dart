import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../widgets/iris_components.dart';
import '../core/vital_theme.dart';
import '../widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: LoginParticleBackground(
        child: Stack(
          children: [
            ObsidianPulse(isDark: isDark),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: GlassCard(
                  borderRadius: 32,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GlowingOrbitalLogo(),
                      const SizedBox(height: 24),
                      const Text(
                        'IRIS SYSTEM',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'IDENTITY VERIFICATION REQUIRED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Terminal ID',
                          filled: true,
                          fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Access Code',
                          filled: true,
                          fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: AnimatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Container(
                            decoration: BoxDecoration(
                              color: IrisTokens.brand,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: IrisTokens.brand.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                )
                              ]
                            ),
                            child: const Center(
                              child: Text(
                                'INITIALIZE SESSION',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
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
    );
  }
}

// ==========================================================================
// GLOWING ORBITAL CANVAS LOGO WIDGET & PAINTER
// ==========================================================================

class GlowingOrbitalLogo extends StatefulWidget {
  const GlowingOrbitalLogo({super.key});

  @override
  State<GlowingOrbitalLogo> createState() => _GlowingOrbitalLogoState();
}

class _GlowingOrbitalLogoState extends State<GlowingOrbitalLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(110, 110),
          painter: GlowingOrbitalLogoPainter(
            progress: _controller.value,
            isDark: isDark,
          ),
        );
      },
    );
  }
}

class GlowingOrbitalLogoPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  GlowingOrbitalLogoPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = size.width / 3.2;

    final baseColor = IrisTokens.brand;
    final accentColor = IrisTokens.purple;

    // 1. Draw pulsing central core
    final pulse = 0.85 + (math.sin(progress * 2 * math.pi) * 0.15);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          baseColor,
          baseColor.withValues(alpha: 0.25),
          Colors.transparent,
        ],
        stops: const [0.2, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius * pulse));

    canvas.drawCircle(Offset(cx, cy), radius * pulse, corePaint);

    // 2. Draw rotating orbital rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    canvas.drawCircle(Offset(cx, cy), radius * 0.75, ringPaint);
    canvas.drawCircle(Offset(cx, cy), radius * 1.1, ringPaint);

    // 3. Draw orbiting nodes (electrons)
    final nodePaint = Paint()..style = PaintingStyle.fill;

    // Inner orbital node
    final double innerAngle = progress * 2 * math.pi;
    final innerNodePos = Offset(
      cx + math.cos(innerAngle) * radius * 0.75,
      cy + math.sin(innerAngle) * radius * 0.75,
    );
    nodePaint.color = baseColor;
    canvas.drawCircle(innerNodePos, 4, nodePaint);
    canvas.drawCircle(
      innerNodePos, 
      8, 
      Paint()
        ..color = baseColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill
    );

    // Outer orbital node (slower, opposite direction)
    final double outerAngle = -progress * 1.2 * math.pi;
    final outerNodePos = Offset(
      cx + math.cos(outerAngle) * radius * 1.1,
      cy + math.sin(outerAngle) * radius * 1.1,
    );
    nodePaint.color = accentColor;
    canvas.drawCircle(outerNodePos, 4.5, nodePaint);
    canvas.drawCircle(
      outerNodePos, 
      9, 
      Paint()
        ..color = accentColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill
    );
  }

  @override
  bool shouldRepaint(covariant GlowingOrbitalLogoPainter oldDelegate) => true;
}

// ==========================================================================
// TAP-INTERACTIVE PARTICLE BACKGROUND
// ==========================================================================

class LoginParticle {
  Offset position;
  Offset velocity;
  double radius;
  double opacity;
  Color color;

  LoginParticle({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.opacity,
    required this.color,
  });
}

class LoginParticleBackground extends StatefulWidget {
  final Widget child;
  const LoginParticleBackground({required this.child, super.key});

  @override
  State<LoginParticleBackground> createState() => _LoginParticleBackgroundState();
}

class _LoginParticleBackgroundState extends State<LoginParticleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<LoginParticle> _particles = [];
  Offset? _tapPosition;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _controller.addListener(_updateParticles);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_particles.isEmpty) {
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < 40; i++) {
        _particles.add(
          LoginParticle(
            position: Offset(_random.nextDouble() * size.width, _random.nextDouble() * size.height),
            velocity: Offset((_random.nextDouble() - 0.5) * 0.4, (_random.nextDouble() - 0.5) * 0.4),
            radius: _random.nextDouble() * 3.0 + 1.2,
            opacity: _random.nextDouble() * 0.3 + 0.1,
            color: _random.nextBool() ? IrisTokens.brand : IrisTokens.purple,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateParticles() {
    final size = MediaQuery.of(context).size;
    if (size.width == 0 || size.height == 0) return;
    
    setState(() {
      for (final p in _particles) {
        p.position += p.velocity;
        if (p.position.dx < 0) p.position = Offset(size.width, p.position.dy);
        if (p.position.dx > size.width) p.position = Offset(0, p.position.dy);
        if (p.position.dy < 0) p.position = Offset(p.position.dx, size.height);
        if (p.position.dy > size.height) p.position = Offset(p.position.dx, 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) => setState(() => _tapPosition = d.localPosition),
      onTapUp: (_) => setState(() => _tapPosition = null),
      onTapCancel: () => setState(() => _tapPosition = null),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: LoginParticleFieldPainter(
                particles: _particles,
                tapPosition: _tapPosition,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class LoginParticleFieldPainter extends CustomPainter {
  final List<LoginParticle> particles;
  final Offset? tapPosition;
  final double tapRadius;

  LoginParticleFieldPainter({
    required this.particles,
    required this.tapPosition,
    this.tapRadius = 100.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      double activeOpacity = particle.opacity;
      Offset drawPosition = particle.position;

      if (tapPosition != null) {
        final double dx = tapPosition!.dx - particle.position.dx;
        final double dy = tapPosition!.dy - particle.position.dy;
        final double dist = math.sqrt(dx * dx + dy * dy);
        if (dist < tapRadius) {
          final double force = (1.0 - (dist / tapRadius)) * 0.15;
          drawPosition = Offset(
            particle.position.dx + dx * force,
            particle.position.dy + dy * force,
          );
          activeOpacity = (particle.opacity * 1.5).clamp(0.0, 1.0);
        }
      }

      paint.color = particle.color.withValues(alpha: activeOpacity);
      canvas.drawCircle(drawPosition, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LoginParticleFieldPainter oldDelegate) => true;
}
