import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassCard;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../core/vital_theme.dart';
import '../widgets/vital_card.dart';
import '../services/ui_feedback.dart';
import '../services/notification_service.dart';

// ==========================================================================
// ROLE SELECTOR CANVAS PARTICLES
// ==========================================================================

class RoleSelectorParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double alpha;

  RoleSelectorParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.alpha,
  });

  void update(double width, double height, Offset orbCenter, Offset? attractionTarget, double attractionStrength, math.Random random) {
    if (x < 0 || x > width) x = random.nextDouble() * width;
    if (y < 0 || y > height) y = random.nextDouble() * height;

    if (attractionTarget != null) {
      final dx = attractionTarget.dx - x;
      final dy = attractionTarget.dy - y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > 5) {
        final forceX = (dx / dist) * attractionStrength;
        final forceY = (dy / dist) * attractionStrength;
        vx = vx * 0.92 + forceX * 0.08;
        vy = vy * 0.92 + forceY * 0.08;
      }
    } else {
      // Gentle gravity towards the neural orb center
      final dx = orbCenter.dx - x;
      final dy = orbCenter.dy - y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > 10) {
        vx = vx * 0.97 + (dx / dist) * 0.02 + (random.nextDouble() - 0.5) * 0.1;
        vy = vy * 0.97 + (dy / dist) * 0.02 + (random.nextDouble() - 0.5) * 0.1;
      } else {
        vx = vx * 0.95 + (random.nextDouble() - 0.5) * 0.15;
        vy = vy * 0.95 + (random.nextDouble() - 0.5) * 0.15;
      }
    }

    x += vx;
    y += vy;
  }
}

// ==========================================================================
// CUSTOM PAINTER: NEURAL ORBITAL SPHERE
// ==========================================================================

class RoleSelectorPainter extends CustomPainter {
  final List<RoleSelectorParticle> particles;
  final Offset? attractionTarget;
  final double attractionStrength;
  final double animationValue;
  final Offset orbCenter;
  final bool isDark;

  RoleSelectorPainter({
    required this.particles,
    required this.attractionTarget,
    required this.attractionStrength,
    required this.animationValue,
    required this.orbCenter,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw glowing neural orb background core
    final double pulse = 1.0 + 0.10 * math.sin(animationValue * 2 * math.pi);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          IrisTokens.brand.withValues(alpha: 0.20),
          IrisTokens.purple.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: orbCenter, radius: 95 * pulse))
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(orbCenter, 95 * pulse, corePaint);

    // 2. Draw rotating concentric orbital rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer ring spinning clockwise
    canvas.save();
    canvas.translate(orbCenter.dx, orbCenter.dy);
    canvas.rotate(animationValue * 2 * math.pi);
    ringPaint.color = IrisTokens.brand.withValues(alpha: 0.14);
    _drawDashedCircle(canvas, 70 * pulse, ringPaint);
    canvas.restore();

    // Inner ring spinning counter-clockwise
    canvas.save();
    canvas.translate(orbCenter.dx, orbCenter.dy);
    canvas.rotate(-animationValue * 2 * math.pi * 0.7);
    ringPaint.color = IrisTokens.blue.withValues(alpha: 0.12);
    _drawDashedCircle(canvas, 50 * pulse, ringPaint);
    canvas.restore();

    // 3. Draw particles and connecting lines
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      paint.color = p.color.withValues(alpha: p.alpha);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);

      // Connect near particles
      for (final other in particles) {
        if (other == p) continue;
        final dx = other.x - p.x;
        final dy = other.y - p.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < 75) {
          final lineAlpha = (1.0 - dist / 75) * 0.08 * p.alpha;
          final linePaint = Paint()
            ..color = p.color.withValues(alpha: lineAlpha)
            ..strokeWidth = 0.5;
          canvas.drawLine(Offset(p.x, p.y), Offset(other.x, other.y), linePaint);
        }
      }

      // Connect to orb center if nearby
      final dxOrb = orbCenter.dx - p.x;
      final dyOrb = orbCenter.dy - p.y;
      final distOrb = math.sqrt(dxOrb * dxOrb + dyOrb * dyOrb);
      if (distOrb < 140) {
        final lineAlpha = (1.0 - distOrb / 140) * 0.10;
        final linePaint = Paint()
          ..color = IrisTokens.purpleLight.withValues(alpha: lineAlpha)
          ..strokeWidth = 0.4;
        canvas.drawLine(Offset(p.x, p.y), orbCenter, linePaint);
      }
    }

    // 4. Draw touch attraction highlight
    if (attractionTarget != null && attractionStrength > 0) {
      final glowPaint = Paint()
        ..color = IrisTokens.brand.withValues(alpha: 0.12 * attractionStrength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(attractionTarget!, 50, glowPaint);
    }
  }

  void _drawDashedCircle(Canvas canvas, double radius, Paint paint) {
    const int dashCount = 28;
    const double sweepAngle = 2 * math.pi / dashCount;
    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: radius),
          i * sweepAngle,
          sweepAngle,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant RoleSelectorPainter oldDelegate) => true;
}

// ==========================================================================
// ROLE SELECTOR SCREEN
// ==========================================================================

class RoleSelectorScreen extends StatefulWidget {
  final ValueChanged<String> onComplete;

  const RoleSelectorScreen({required this.onComplete, super.key});

  @override
  State<RoleSelectorScreen> createState() => _RoleSelectorScreenState();
}

class _RoleSelectorScreenState extends State<RoleSelectorScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<RoleSelectorParticle> _particles = [];
  Offset? _attractionTarget;
  double _attractionStrength = 0.0;
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
  void dispose() {
    _controller.removeListener(_updateParticles);
    _controller.dispose();
    super.dispose();
  }

  void _updateParticles() {
    if (!mounted) return;
    final double width = MediaQuery.sizeOf(context).width;
    final double height = MediaQuery.sizeOf(context).height;
    if (width == 0 || height == 0) return;

    final orbCenter = Offset(width / 2, height * 0.35);

    if (_particles.isEmpty) {
      for (int i = 0; i < 40; i++) {
        _particles.add(RoleSelectorParticle(
          x: _random.nextDouble() * width,
          y: _random.nextDouble() * height,
          vx: (_random.nextDouble() - 0.5) * 1.5,
          vy: (_random.nextDouble() - 0.5) * 1.5,
          size: 1.8 + _random.nextDouble() * 3.2,
          color: _random.nextBool() ? IrisTokens.brand : IrisTokens.blue,
          alpha: 0.15 + _random.nextDouble() * 0.35,
        ));
      }
    }

    setState(() {
      for (final p in _particles) {
        p.update(width, height, orbCenter, _attractionTarget, _attractionStrength, _random);
      }
    });
  }

  void _triggerAttraction(Offset globalPosition) {
    setState(() {
      _attractionTarget = globalPosition;
      _attractionStrength = 4.5;

      final double width = MediaQuery.sizeOf(context).width;
      final double height = MediaQuery.sizeOf(context).height;
      final orbCenter = Offset(width / 2, height * 0.35);

      final dx = globalPosition.dx - orbCenter.dx;
      final dy = globalPosition.dy - orbCenter.dy;
      final angle = math.atan2(dy, dx);

      // Spawn burst of particles shooting towards the card
      for (int i = 0; i < 30; i++) {
        final speed = 3.5 + _random.nextDouble() * 5.0;
        final spreadAngle = angle + (_random.nextDouble() - 0.5) * 0.7;
        _particles.add(RoleSelectorParticle(
          x: orbCenter.dx,
          y: orbCenter.dy,
          vx: math.cos(spreadAngle) * speed,
          vy: math.sin(spreadAngle) * speed,
          size: 1.5 + _random.nextDouble() * 2.0,
          color: _random.nextBool() ? IrisTokens.brand : IrisTokens.purpleLight,
          alpha: 1.0,
        ));
      }
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _attractionTarget = null;
          _attractionStrength = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final orbCenter = Offset(width / 2, height * 0.35);

    return Scaffold(
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          Positioned.fill(
            child: CustomPaint(
              painter: RoleSelectorPainter(
                particles: _particles,
                attractionTarget: _attractionTarget,
                attractionStrength: _attractionStrength,
                animationValue: _controller.value,
                orbCenter: orbCenter,
                isDark: isDark,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Choose Your Role',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This configures your dashboard, tools, and portal access.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                    ),
                  ),
                  
                  // Space for the center orbital core to breathe
                  const Spacer(flex: 4),
                  
                  VitalCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildBentoRoleCard(
                          context: context,
                          title: 'Student Profile',
                          subtitle: 'Timetable, batch sync, live class tracking',
                          icon: Icons.school_rounded,
                          accent: IrisTokens.brand,
                          onTap: (globalPos) {
                            _triggerAttraction(globalPos);
                            Future.delayed(const Duration(milliseconds: 400), () {
                              widget.onComplete('student');
                            });
                          },
                        ),
                        Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                        _buildBentoRoleCard(
                          context: context,
                          title: 'Faculty Profile',
                          subtitle: 'Faculty schedules, room directory tools',
                          icon: Icons.badge_rounded,
                          accent: IrisTokens.blue,
                          onTap: (globalPos) {
                            _triggerAttraction(globalPos);
                            Future.delayed(const Duration(milliseconds: 400), () {
                              widget.onComplete('faculty');
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required ValueChanged<Offset> onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (details) {
        IrisHaptics.actionHeavy();
        onTap(details.globalPosition);
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.2),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white30 : Colors.black26),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// TACTILE GLASS CHOICE CHIPS
// ==========================================================================

class TactileGlassChip extends StatefulWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const TactileGlassChip({
    required this.text,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  State<TactileGlassChip> createState() => _TactileGlassChipState();
}

class _TactileGlassChipState extends State<TactileGlassChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _scaleController;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: (_) {
        _scaleController.reverse();
      },
      onTapUp: (_) {
        _scaleController.forward();
        widget.onTap();
      },
      onTapCancel: () {
        _scaleController.forward();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    colors: [IrisTokens.brand, IrisTokens.brandLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isSelected
                ? null
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? IrisTokens.brandLight.withValues(alpha: 0.4)
                  : (isDark ? Colors.white10 : Colors.black12),
              width: 1.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: IrisTokens.brand.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: widget.isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}




// ==========================================================================
// SETUP BOT SCREEN (WIZARD & NEURAL SYNC OVERLAY)
// ==========================================================================

class SetupBot extends StatefulWidget {
  final UniversityMemory memory;
  final ValueChanged<String> onComplete;

  const SetupBot({required this.memory, required this.onComplete, super.key});

  @override
  State<SetupBot> createState() => _SetupBotState();
}

class _SetupBotState extends State<SetupBot> {
  String? _program;
  int? _semester;
  String? _section;
  bool _persistentNotificationEnabled = false;
  
  // Wizard state control
  int _currentStep = 0; // 0: Program, 1: Semester, 2: Section, 3: Services/Finish
  
  // Simulated Brain Sync state
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncLog = '';

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
    _loadInitialBatchSelection();
  }

  Future<void> _loadInitialBatchSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBatch = prefs.getString('user_batch')?.trim();

    final fallbackBatch = savedBatch != null && savedBatch.isNotEmpty
        ? savedBatch
        : (widget.memory.allBatches.isNotEmpty ? widget.memory.allBatches.first : null);

    if (fallbackBatch == null || !mounted) {
      return;
    }

    final key = BatchKey.parse(fallbackBatch);
    setState(() {
      _program = key.program;
      _semester = key.semester == 0 ? null : key.semester;
      _section = key.section;
    });
  }

  String? _resolveBatch() {
    if (_program == null || _semester == null || _section == null) {
      return null;
    }

    for (final batch in widget.memory.allBatches) {
      final key = BatchKey.parse(batch);
      if (key.program == _program &&
          key.semester == _semester &&
          key.section == _section) {
        return batch;
      }
    }

    return null;
  }

  void _nextStep() {
    if (_currentStep < 3) {
      IrisHaptics.actionMedium();
      setState(() {
        _currentStep++;
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      IrisHaptics.actionMedium();
      setState(() {
        _currentStep--;
      });
    }
  }

  void _startBrainSync() {
    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
      _syncLog = 'Establishing connection to neural academic core...';
    });

    IrisHaptics.actionHeavy();

    const totalDuration = Duration(milliseconds: 2000);
    const intervals = 20;
    int currentInterval = 0;
    
    final timerStream = Stream.periodic(
      Duration(milliseconds: totalDuration.inMilliseconds ~/ intervals),
      (count) => count,
    ).take(intervals);

    timerStream.listen((count) {
      if (!mounted) return;
      
      currentInterval++;
      final double progress = currentInterval / intervals;
      
      String log = '';
      if (progress < 0.25) {
        log = 'Pinging core database nodes...';
      } else if (progress < 0.5) {
        log = 'Decompressing academic timetables (1,420 entries)...';
      } else if (progress < 0.75) {
        log = 'Compiling Room Finder indices & building nodes...';
      } else if (progress < 0.95) {
        log = 'Writing widget cache and starting Live Class services...';
      } else {
        log = 'Verification successful. Brain fully synchronized!';
      }

      setState(() {
        _syncProgress = progress;
        _syncLog = log;
      });

      if (currentInterval % 4 == 0) {
        IrisHaptics.actionSoft();
      }

      if (currentInterval == intervals) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          final batch = _resolveBatch();
          if (batch != null) {
            IrisHaptics.actionHeavy();
            widget.onComplete(batch.trim());
          }
        });
      }
    });
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _persistentNotificationEnabled =
          prefs.getBool('persistent_notification_enabled') ?? false;
    });
  }

  Future<void> _togglePersistentNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'student';
    final teacher = prefs.getString('faculty_teacher');
    if (role == 'faculty' && value && (teacher == null || teacher.isEmpty)) {
      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          dedupeKey: 'faculty_tracking_requires_teacher',
          content: Row(
            children: const [
              Icon(Icons.info_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Select your name first to enable faculty tracking'),
              ),
            ],
          ),
          tint: IrisTokens.brand,
        );
      }
      return;
    }
    await prefs.setBool('persistent_notification_enabled', value);
    setState(() {
      _persistentNotificationEnabled = value;
    });

    if (!value) {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } else {
      if (!(await FlutterForegroundTask.isRunningService)) {
        await prefs.setString('notification_title', 'IRIS Class Tracker');
        await prefs.setString('notification_body', 'Keeping your class schedule handy');

        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'IRIS Class Tracker',
          notificationText: 'Keeping your class schedule handy',
          notificationIcon: null,
          notificationButtons: [
            NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
          callback: startClassNotificationTask,
        );
      }
    }

    IrisHaptics.chipSelect();
  }

  static Future<void> _showWidgetSetupGuideFromSetup(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                offset: const Offset(0, 12),
                blurRadius: 32,
                spreadRadius: -8,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [IrisTokens.purpleLight, IrisTokens.purple],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Home Screen Widget',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Track your classes at a glance with the IRIS home screen widget.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    _buildStepStatic(isDark, '1', 'Long press on your home screen'),
                    const SizedBox(height: 12),
                    _buildStepStatic(isDark, '2', 'Tap Widgets'),
                    const SizedBox(height: 12),
                    _buildStepStatic(isDark, '3', 'Search for "IRIS"'),
                    const SizedBox(height: 12),
                    _buildStepStatic(isDark, '4', 'Drag to home screen'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        await prefs.setBool('widget_prompt_shown', true);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Got It!',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStepStatic(bool isDark, String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [IrisTokens.purple, IrisTokens.purpleLight],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Core data preparation
    final programs = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toList();
    final semesters = _program == null
        ? <int>[]
        : widget.memory.semesters(_program!);
    final sections = (_program != null && _semester != null)
        ? widget.memory.sections(_program!, _semester!)
        : <String>[];

    return Scaffold(
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // App Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: IrisTokens.brandGradient),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Synaptic Config',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                            Text(
                              'Establish academic telemetry link',
                              style: TextStyle(fontSize: 12, color: (isDark ? Colors.white60 : Colors.black54)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Progressive indicator
                  _buildStepIndicators(),
                  const SizedBox(height: 10),
                  _buildProgressBar(),
                  const SizedBox(height: 20),

                  // Main Interactive Wizard Body
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          final offsetAnimation = Tween<Offset>(
                            begin: const Offset(0.15, 0.0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(position: offsetAnimation, child: child),
                          );
                        },
                        child: _buildStepContent(isDark, programs, semesters, sections),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildNavigationButtons(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (_isSyncing) Positioned.fill(child: _buildSyncOverlay(context)),
        ],
      ),
    );
  }

  Widget _buildStepIndicators() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;
        
        Color indicatorColor;
        if (isActive) {
          indicatorColor = IrisTokens.brand;
        } else if (isCompleted) {
          indicatorColor = IrisTokens.purple;
        } else {
          indicatorColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12);
        }

        return GestureDetector(
          onTap: () {
            // Jump back to valid selection states
            if (index < _currentStep || 
                (index == 1 && _program != null) || 
                (index == 2 && _semester != null) || 
                (index == 3 && _section != null)) {
              IrisHaptics.actionSoft();
              setState(() {
                _currentStep = index;
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: isActive ? 48 : 12,
            height: 10,
            decoration: BoxDecoration(
              color: indicatorColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive ? IrisTokens.brandLight.withValues(alpha: 0.4) : Colors.transparent,
                width: 1,
              ),
              boxShadow: isActive ? [
                BoxShadow(
                  color: IrisTokens.brand.withValues(alpha: 0.25),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ] : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildProgressBar() {
    final double progress = (_currentStep + 1) / 4;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 5,
        width: double.infinity,
        color: (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black).withValues(alpha: 0.08),
        child: Stack(
          children: [
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: IrisTokens.brandGradient),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(bool isDark, List<String> programs, List<int> semesters, List<String> sections) {
    final resolvedBatch = _resolveBatch();
    final smartBatchLabel = resolvedBatch ?? (widget.memory.allBatches.isNotEmpty ? widget.memory.allBatches.first : null);

    switch (_currentStep) {
      case 0:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader('Select Program', 'Establish academic track'),
            const SizedBox(height: 16),
            _buildSelectorGrid(
              options: programs,
              selected: _program,
              columns: 3,
              onSelected: (val) {
                setState(() {
                  _program = val;
                  _semester = null;
                  _section = null;
                  if (val != null) {
                    final sems = widget.memory.semesters(val);
                    if (sems.length == 1) {
                      _semester = sems.first;
                      final secs = widget.memory.sections(val, _semester!);
                      if (secs.length == 1) {
                        _section = secs.first;
                      }
                    }
                  }
                });
                Future.delayed(const Duration(milliseconds: 250), () {
                  if (mounted && _currentStep == 0) _nextStep();
                });
              },
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader('Select Semester', 'Choose active course phase'),
            const SizedBox(height: 16),
            _buildSelectorGrid(
              options: semesters.map((e) => e.toString()).toList(),
              selected: _semester?.toString(),
              columns: 4,
              onSelected: (val) {
                setState(() {
                  _semester = int.tryParse(val ?? '');
                  _section = null;
                  if (_semester != null && _program != null) {
                    final secs = widget.memory.sections(_program!, _semester!);
                    if (secs.length == 1) {
                      _section = secs.first;
                    }
                  }
                });
                Future.delayed(const Duration(milliseconds: 250), () {
                  if (mounted && _currentStep == 1) _nextStep();
                });
              },
            ),
          ],
        );
      case 2:
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader('Select Section', 'Specify batch subset allocation'),
            const SizedBox(height: 16),
            _buildSelectorGrid(
              options: sections,
              selected: _section,
              columns: 4,
              onSelected: (val) {
                setState(() {
                  _section = val;
                });
                Future.delayed(const Duration(milliseconds: 250), () {
                  if (mounted && _currentStep == 2) _nextStep();
                });
              },
            ),
          ],
        );
      case 3:
      default:
        return Column(
          key: const ValueKey(3),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader('Telemetry Setup', 'Finalize initialization parameters'),
            const SizedBox(height: 16),
            
            // Smart batch preview card
            if (smartBatchLabel != null)
              VitalCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: IrisTokens.brandGradient),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resolved Batch Telemetry',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white70 : Colors.black87),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              smartBatchLabel,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: IrisTokens.brandLight),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 14),

            // Live Class Tracker Switch Bento
            VitalCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _persistentNotificationEnabled
                            ? IrisTokens.brandGradient
                            : [
                                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _persistentNotificationEnabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_rounded,
                      color: _persistentNotificationEnabled
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live Class Tracker',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _persistentNotificationEnabled
                              ? 'Active tracking schedule in status bar'
                              : 'Pin active class metrics in notification tray',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassSwitch(
                    value: _persistentNotificationEnabled,
                    onChanged: _togglePersistentNotification,
                    activeColor: IrisTokens.brand,
                    useOwnLayer: true,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),

            // Home Screen Widget bento card
            VitalCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () async {
                  await _showWidgetSetupGuideFromSetup(context);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              IrisTokens.brandGradient[0].withValues(alpha: 0.85),
                              IrisTokens.brandGradient[1].withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.widgets_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Home Screen Widget',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Add dynamic widgets to your device screen',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: (isDark ? Colors.white60 : Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_program != null && _semester != null && _section != null && resolvedBatch == null) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Warning: No matching core program database found.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.redAccent.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ],
        );
    }
  }

  Widget _buildStepHeader(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: (isDark ? Colors.white54 : Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorGrid({
    required List<String> options,
    required String? selected,
    required int columns,
    required ValueChanged<String?> onSelected,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: columns == 4 ? 1.35 : 2.0,
      ),
      itemBuilder: (context, idx) {
        final opt = options[idx];
        return TactileGlassChip(
          text: opt,
          isSelected: selected == opt,
          onTap: () => onSelected(opt),
        );
      },
    );
  }

  Widget _buildNavigationButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReady = _program != null && _semester != null && _section != null;
    
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: TextButton(
                onPressed: _prevStep,
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'BACK',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: (_currentStep < 3 || isReady)
                  ? LinearGradient(colors: IrisTokens.brandGradient)
                  : null,
              color: (_currentStep == 3 && !isReady)
                  ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08))
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: (_currentStep < 3 || isReady) ? [
                BoxShadow(
                  color: IrisTokens.brand.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ] : null,
            ),
            child: ElevatedButton(
              onPressed: () {
                if (_currentStep < 3) {
                  if (_currentStep == 0 && _program != null) _nextStep();
                  if (_currentStep == 1 && _semester != null) _nextStep();
                  if (_currentStep == 2 && _section != null) _nextStep();
                } else {
                  if (isReady) {
                    _startBrainSync();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _currentStep < 3 ? 'CONTINUE' : 'INITIALIZE BRAIN',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncOverlay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.75),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: _syncProgress,
                      strokeWidth: 5,
                      backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(IrisTokens.brand),
                    ),
                  ),
                  Text(
                    '${(_syncProgress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                'INITIALIZING SYNAPSE ENGINE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: IrisTokens.brand,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 50,
                alignment: Alignment.center,
                child: Text(
                  _syncLog,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: (isDark ? Colors.white70 : Colors.black87),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
