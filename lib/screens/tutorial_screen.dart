import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/animations.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart';
import '../core/vital_theme.dart';
import '../widgets/glass_card.dart';

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
    final cy = size.height * 0.32; // Aligned with the center of phone mockups

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
      for (int i = 1; i <= 4; i++) {
        final r = (45.0 * i) + (animationValue * 45.0);
        final alpha = ((1.0 - (r / 240.0)).clamp(0.0, 1.0)) * 0.16 * w1;
        paint.color = brandColor.withValues(alpha: alpha);
        canvas.drawCircle(Offset(cx, cy), r, paint);
      }
    }

    // Page 2: Timeline connector pulse wave nodes
    if (w2 > 0) {
      final linePaint = Paint()
        ..color = baseColor.withValues(alpha: 0.06 * w2)
        ..strokeWidth = 1.5;
      final lineY = cy + 40;
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
        ..color = brandColor.withValues(alpha: 0.07 * w3)
        ..strokeWidth = 1.0;

      canvas.drawCircle(Offset(cx, cy), 95, orbitPaint);
      canvas.drawCircle(Offset(cx, cy), 145, orbitPaint);

      final angle1 = animationValue * math.pi * 2;
      final angle2 = -animationValue * math.pi * 1.5 + 1.2;

      final nodePaint1 = Paint()
        ..color = brandColor.withValues(alpha: 0.45 * w3)
        ..style = PaintingStyle.fill;
      final nodePaint2 = Paint()
        ..color = IrisTokens.purple.withValues(alpha: 0.45 * w3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(cx + math.cos(angle1) * 95, cy + math.sin(angle1) * 95),
        5.0,
        nodePaint1,
      );
      canvas.drawCircle(
        Offset(cx + math.cos(angle2) * 145, cy + math.sin(angle2) * 145),
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
      duration: const Duration(seconds: 5),
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

    // Breath rotation for interactive 3D feel
    final breathAngleX = math.sin(_animController.value * math.pi * 2) * 0.035;
    final breathAngleY = math.cos(_animController.value * math.pi * 2) * 0.035;

    return Scaffold(
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          
          // Custom Background Painter
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

          // Central 3D Smartphone Viewport
          Positioned(
            top: MediaQuery.of(context).padding.top + 30,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.44,
            child: IgnorePointer(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Slide 0: Live Class Tracker
                  _build3DViewport(
                    index: 0,
                    breathX: breathAngleX,
                    breathY: breathAngleY,
                    isDark: isDark,
                    child: _buildClassesMockup(isDark),
                  ),

                  // Slide 1: Portal Sync Insights
                  _build3DViewport(
                    index: 1,
                    breathX: breathAngleX,
                    breathY: breathAngleY,
                    isDark: isDark,
                    child: _buildPortalMockup(isDark),
                  ),

                  // Slide 2: Liquid Widgets Dashboard
                  _build3DViewport(
                    index: 2,
                    breathX: breathAngleX,
                    breathY: breathAngleY,
                    isDark: isDark,
                    child: _buildWidgetsMockup(isDark),
                  ),
                ],
              ),
            ),
          ),

          // Swipable text layer
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              IrisHaptics.chipSelect();
            },
            physics: const BouncingScrollPhysics(),
            children: [
              _buildTextSlide(
                title: 'Welcome to Nexsync',
                subtitle: 'Your intelligent academic companion. Experience a complete system designed to keep you focused and organized.',
                isDark: isDark,
              ),
              _buildTextSlide(
                title: 'Live Class Tracking',
                subtitle: 'Never miss a beat. Nexsync tracks your timetable seamlessly in the background and surfaces live progress to your lockscreen.',
                isDark: isDark,
              ),
              _buildTextSlide(
                title: 'Deep Portal Sync',
                subtitle: 'Attendance, marks, and faculty details, all securely synced from the portal right into a beautiful, fluid interface.',
                isDark: isDark,
              ),
            ],
          ),

          // Bottom Bar (Indicators & Action Button)
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

  // 3D Viewport Builder with Parallax Translation & Perspective Tilt
  Widget _build3DViewport({
    required int index,
    required double breathX,
    required double breathY,
    required bool isDark,
    required Widget child,
  }) {
    final double swipeOffset = index - _pageOffset;
    if (swipeOffset.abs() >= 1.0) {
      return const SizedBox.shrink(); // Hide inactive items
    }

    final double opacity = (1.0 - swipeOffset.abs()).clamp(0.0, 1.0);
    final double scale = 0.88 + (1.0 - swipeOffset.abs()).clamp(0.0, 1.0) * 0.12;
    
    // Horizontal parallax shift
    final double translateX = swipeOffset * 280.0;
    
    // 3D rotations matching swipe position
    final double rotateY = swipeOffset * 0.55 + breathY;
    final double rotateX = swipeOffset.abs() * -0.08 + breathX;

    return Opacity(
      opacity: opacity,
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0016) // Perspective depth variable
          ..translate(translateX, 0.0)
          ..scale(scale)
          ..rotateY(rotateY)
          ..rotateX(rotateX),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  // Text slide container for PageView pages
  Widget _buildTextSlide({
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 32,
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
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 110), // Safe area margin above indicators
          ],
        ),
      ),
    );
  }

  // Smartphone Mockup Shell Container
  Widget _buildPhoneMockup(bool isDark, Widget innerContent, double internalParallax) {
    final strokeColor = isDark ? Colors.white24 : Colors.black12;
    final baseColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      width: 196,
      height: 336,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: strokeColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : IrisTokens.brand).withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29.5),
        child: Stack(
          children: [
            // Internal Screen Grid Wallpaper
            Positioned.fill(
              child: CustomPaint(
                painter: MockupGridPainter(isDark: isDark),
              ),
            ),

            // Shifting parallax inner content
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(internalParallax * -30.0, 0.0),
                child: innerContent,
              ),
            ),

            // Top Status Bar (Wifi, Battery, Notch)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '11:34',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.wifi, size: 9, color: isDark ? Colors.white60 : Colors.black54),
                        const SizedBox(width: 4),
                        Icon(Icons.battery_4_bar_rounded, size: 10, color: isDark ? Colors.white60 : Colors.black54),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Dynamic Island / Top Speaker Notch
            Positioned(
              top: 4,
              left: 64,
              right: 64,
              height: 11,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),

            // Bottom Navigation Indicator Line
            Positioned(
              bottom: 4,
              left: 70,
              right: 70,
              height: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mockup 1: Live Class Timeline Slide
  Widget _buildClassesMockup(bool isDark) {
    final double offset = 0.0 - _pageOffset;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textAccent = isDark ? Colors.white70 : Colors.black87;

    return _buildPhoneMockup(
      isDark,
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 30, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: IrisTokens.brand.withValues(alpha: 0.15),
                  child: const Text('A', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: IrisTokens.brand)),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good morning,', style: TextStyle(fontSize: 8, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
                    Text('Aurangzaib', style: TextStyle(fontSize: 9, color: textAccent, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            // "Now Active" timetable card with parallax depth
            Transform.translate(
              offset: Offset(offset * -24.0, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.24), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: IrisTokens.brand.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ACTIVE CLASS', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: IrisTokens.brand, letterSpacing: 0.5)),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Automata Theory', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textAccent)),
                    const SizedBox(height: 8),
                    // Progress bar
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.65,
                        child: Container(decoration: BoxDecoration(color: IrisTokens.brand, borderRadius: BorderRadius.circular(2))),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('11:00 AM - 12:30 PM', style: TextStyle(fontSize: 7, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w700)),
                        const Text('35m left', style: TextStyle(fontSize: 7, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Next up simple card
            Transform.translate(
              offset: Offset(offset * -12.0, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward_rounded, size: 10, color: isDark ? Colors.white54 : Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NEXT UP', style: TextStyle(fontSize: 6, fontWeight: FontWeight.w800, color: isDark ? Colors.white38 : Colors.black38)),
                          Text('Linear Algebra (12:30 PM)', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: textAccent)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      offset,
    );
  }

  // Mockup 2: Academic Portal Sync & Grades Slide
  Widget _buildPortalMockup(bool isDark) {
    final double offset = 1.0 - _pageOffset;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textAccent = isDark ? Colors.white70 : Colors.black87;

    return _buildPhoneMockup(
      isDark,
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 30, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Academic Portal',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Secure Portal Sync Client',
              style: TextStyle(fontSize: 7, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            // GPA Dial Circle
            Transform.translate(
              offset: Offset(offset * -24.0, 0),
              child: Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.15), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: IrisTokens.brand.withValues(alpha: 0.04),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('CGPA', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: IrisTokens.brand, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text('3.84', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textAccent)),
                        const SizedBox(height: 2),
                        Text('89% Attendance', style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Subject Grade progress list
            Transform.translate(
              offset: Offset(offset * -12.0, 0),
              child: Column(
                children: [
                  _buildMiniGradeBar(isDark, 'Data Structures', 'A', 0.90),
                  const SizedBox(height: 8),
                  _buildMiniGradeBar(isDark, 'Calculus II', 'B+', 0.76),
                ],
              ),
            ),
          ],
        ),
      ),
      offset,
    );
  }

  Widget _buildMiniGradeBar(bool isDark, String name, String grade, double factor) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                  Text(grade, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: IrisTokens.brand)),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(1)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: factor,
                  child: Container(decoration: BoxDecoration(color: IrisTokens.brand.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(1))),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  // Mockup 3: Home Launcher Liquid Widgets Slide
  Widget _buildWidgetsMockup(bool isDark) {
    final double offset = 2.0 - _pageOffset;
    final textAccent = isDark ? Colors.white70 : Colors.black87;

    return _buildPhoneMockup(
      isDark,
      Stack(
        children: [
          // Home wallpaper gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF312E81), const Color(0xFF0F172A)]
                      : [const Color(0xFFF1F5F9), const Color(0xFFE0E7FF), const Color(0xFFF1F5F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Floating dynamic smart widget
          Positioned(
            top: 60,
            left: 14,
            right: 14,
            child: Transform.translate(
              offset: Offset(offset * -24.0, 0),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 20,
                glow: true,
                enableShadow: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(color: IrisTokens.brand, shape: BoxShape.circle),
                              child: const Icon(Icons.school, size: 8, color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Nexsync Widget',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: IrisTokens.brand),
                            ),
                          ],
                        ),
                        Text(
                          'CS-201',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Linear Algebra',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textAccent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lab 13  •  Starts in 15m',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    // Quick task items indicators
                    Row(
                      children: [
                        _buildWidgetBadge(isDark, 'Quiz', Colors.orange),
                        const SizedBox(width: 6),
                        _buildWidgetBadge(isDark, 'Assign', Colors.red),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
          // Launcher apps row (decorative)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (index) {
                return Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
      offset,
    );
  }

  Widget _buildWidgetBadge(bool isDark, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 6, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}

// Background Grid Painter for Smartphone screens
class MockupGridPainter extends CustomPainter {
  final bool isDark;
  MockupGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.02)
      ..strokeWidth = 0.5;

    // Vertical grid lines
    const spacing = 12.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    // Horizontal grid lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant MockupGridPainter oldDelegate) => false;
}
