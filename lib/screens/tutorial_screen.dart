import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/animations.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart';
import '../core/vital_theme.dart';

class TutorialBackgroundPainter extends CustomPainter {
  final double page;
  final double animationValue;
  final bool isDark;

  TutorialBackgroundPainter({
    required this.page,
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = isDark ? Colors.white : Colors.black;
    final brandColor = IrisTokens.brand;
    final blueColor = IrisTokens.blue;

    final cx = size.width * 0.5;
    final cy = size.height * 0.35; // Position aligned with tutorial icon slide center

    double w1 = 0.0;
    double w2 = 0.0;
    double w3 = 0.0;

    if (page < 1.0) {
      w1 = 1.0 - page;
      w2 = page;
    } else {
      w2 = 2.0 - page;
      w3 = page - 1.0;
    }

    // Page 1: Concentric expanding energy rings
    if (w1 > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (int i = 1; i <= 3; i++) {
        final r = (50.0 * i) + (animationValue * 50.0);
        final alpha = ((1.0 - (r / 220.0)).clamp(0.0, 1.0)) * 0.14 * w1;
        paint.color = brandColor.withValues(alpha: alpha);
        canvas.drawCircle(Offset(cx, cy), r, paint);
      }
    }

    // Page 2: Timeline connector pulse wave nodes
    if (w2 > 0) {
      final linePaint = Paint()
        ..color = baseColor.withValues(alpha: 0.06 * w2)
        ..strokeWidth = 1.5;
      final lineY = cy + 60;
      canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), linePaint);

      for (int i = 0; i < 4; i++) {
        final progress = (animationValue + (i / 4.0)) % 1.0;
        final px = progress * size.width;
        final pulseRadius = 5.0 + math.sin(animationValue * math.pi * 2 + i) * 2.0;
        final bubblePaint = Paint()
          ..color = blueColor.withValues(alpha: 0.15 * w2 * (1.0 - progress))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, lineY), pulseRadius, bubblePaint);

        final corePaint = Paint()
          ..color = blueColor.withValues(alpha: 0.40 * w2 * (1.0 - progress))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, lineY), 2.5, corePaint);
      }
    }

    // Page 3: Synaptic database sync orbiting particles
    if (w3 > 0) {
      final orbitPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = brandColor.withValues(alpha: 0.06 * w3)
        ..strokeWidth = 1.0;

      canvas.drawCircle(Offset(cx, cy), 85, orbitPaint);
      canvas.drawCircle(Offset(cx, cy), 135, orbitPaint);

      final angle1 = animationValue * math.pi * 2;
      final angle2 = -animationValue * math.pi * 1.5 + 1.2;

      final nodePaint1 = Paint()
        ..color = brandColor.withValues(alpha: 0.40 * w3)
        ..style = PaintingStyle.fill;
      final nodePaint2 = Paint()
        ..color = IrisTokens.purple.withValues(alpha: 0.40 * w3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(cx + math.cos(angle1) * 85, cy + math.sin(angle1) * 85),
        5.0,
        nodePaint1,
      );
      canvas.drawCircle(
        Offset(cx + math.cos(angle2) * 135, cy + math.sin(angle2) * 135),
        6.0,
        nodePaint2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TutorialBackgroundPainter oldDelegate) => true;
}

class TutorialScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const TutorialScreen({required this.onComplete, super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _animController;
  int _currentPage = 0;
  double _pageOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _pageOffset = _pageController.page ?? 0.0;
        });
      }
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      IrisHaptics.actionSoft();
      _pageController.nextPage(
        duration: IrisMotion.medium,
        curve: IrisMotion.standard,
      );
    } else {
      IrisHaptics.actionHeavy();
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return CustomPaint(
                  painter: TutorialBackgroundPainter(
                    page: _pageOffset,
                    animationValue: _animController.value,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              IrisHaptics.chipSelect();
            },
            physics: const BouncingScrollPhysics(),
            children: [
              _TutorialSlide(
                title: 'Welcome to Nexsync',
                subtitle: 'Your intelligent academic companion. Experience a complete system designed to keep you focused and organized.',
                icon: Icons.auto_awesome_rounded,
                isDark: isDark,
              ),
              _TutorialSlide(
                title: 'Live Class Tracking',
                subtitle: 'Never miss a beat. Nexsync tracks your timetable seamlessly in the background and surfaces live progress to your lockscreen.',
                icon: Icons.timeline_rounded,
                isDark: isDark,
              ),
              _TutorialSlide(
                title: 'Deep Portal Sync',
                subtitle: 'Attendance, marks, and faculty details, all securely synced from the portal right into a beautiful, fluid interface.',
                icon: Icons.sync_rounded,
                isDark: isDark,
              ),
            ],
          ),

          Positioned(
            bottom: 40,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(3, (index) {
                    final isActive = _currentPage == index;
                    return AnimatedContainer(
                      duration: IrisMotion.fast,
                      curve: IrisMotion.standard,
                      margin: const EdgeInsets.only(right: 8),
                      height: 6,
                      width: isActive ? 24 : 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? IrisTokens.brand
                            : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                GestureDetector(
                  onTap: _nextPage,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(IrisTokens.radius20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: IrisTokens.brandGradient),
                        borderRadius: BorderRadius.circular(IrisTokens.radius20),
                        boxShadow: [
                          BoxShadow(
                            color: IrisTokens.brand.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Row(
                        children: [
                          Text(
                            _currentPage == 2 ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _TutorialSlide extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDark;

  const _TutorialSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: IrisTokens.brand.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: IrisTokens.brand.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: IrisTokens.brandGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: Colors.white),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              title,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 80), // Space for bottom navigation
          ],
        ),
      ),
    );
  }
}
