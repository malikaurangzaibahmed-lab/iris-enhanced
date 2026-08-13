import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../core/vital_theme.dart';
import '../services/ui_feedback.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import '../widgets/glass_card.dart';
import 'faculty_directory_screen.dart';

// ==========================================================================
// ROLE SELECTOR CANVAS PARTICLES
// ==========================================================================

class OnboardingParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double alpha;

  OnboardingParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.alpha,
  });

  void update(
    double width,
    double height,
    Offset orbCenter,
    Offset? attractionTarget,
    double attractionStrength,
    math.Random random,
    int step,
  ) {
    if (x < 0 || x > width) x = random.nextDouble() * width;
    if (y < 0 || y > height) y = random.nextDouble() * height;

    if (attractionTarget != null) {
      final dx = attractionTarget.dx - x;
      final dy = attractionTarget.dy - y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > 5) {
        final forceX = (dx / dist) * attractionStrength;
        final forceY = (dy / dist) * attractionStrength;
        vx = vx * 0.90 + forceX * 0.10;
        vy = vy * 0.90 + forceY * 0.10;
      }
    } else {
      // Step-specific behavior: in step 3 (syncing), pull strongly to center
      final targetCenter = step == 3 ? orbCenter : Offset(width / 2, height * 0.28);
      final pullStrength = step == 3 ? 0.08 : 0.025;

      final dx = targetCenter.dx - x;
      final dy = targetCenter.dy - y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > 10) {
        vx = vx * 0.96 + (dx / dist) * pullStrength + (random.nextDouble() - 0.5) * 0.12;
        vy = vy * 0.96 + (dy / dist) * pullStrength + (random.nextDouble() - 0.5) * 0.12;
      } else {
        vx = vx * 0.94 + (random.nextDouble() - 0.5) * 0.2;
        vy = vy * 0.94 + (random.nextDouble() - 0.5) * 0.2;
      }
    }

    x += vx;
    y += vy;
  }
}

// ==========================================================================
// CUSTOM PAINTER: NEURAL ORBITAL SPHERE
// ==========================================================================

class OnboardingPainter extends CustomPainter {
  final List<OnboardingParticle> particles;
  final Offset? attractionTarget;
  final double attractionStrength;
  final double animationValue;
  final Offset orbCenter;
  final bool isDark;
  final int step;

  OnboardingPainter({
    required this.particles,
    required this.attractionTarget,
    required this.attractionStrength,
    required this.animationValue,
    required this.orbCenter,
    required this.isDark,
    required this.step,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw glowing neural orb background core
    final double pulse = 1.0 + 0.12 * math.sin(animationValue * 2 * math.pi);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (step == 3 ? const Color(0xFF10B981) : IrisTokens.brand).withValues(alpha: 0.22),
          (step == 3 ? const Color(0xFF3B82F6) : IrisTokens.purple).withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: orbCenter, radius: 100 * pulse));

    canvas.drawCircle(orbCenter, 100 * pulse, corePaint);

    // 2. Draw connections (lines) between close particles for a neural network effect
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: step == 3 ? 0.08 : 0.04)
      ..strokeWidth = 0.5;

    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final pi = particles[i];
        final pj = particles[j];
        final distSq = (pi.x - pj.x) * (pi.x - pj.x) + (pi.y - pj.y) * (pi.y - pj.y);
        if (distSq < 4800) {
          canvas.drawLine(Offset(pi.x, pi.y), Offset(pj.x, pj.y), linePaint);
        }
      }
    }

    // 3. Draw particles
    for (final p in particles) {
      final pPaint = Paint()
        ..color = p.color.withValues(alpha: p.alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), p.size, pPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================================================
// UNIFIED ONBOARDING WIZARD
// ==========================================================================

class OnboardingWizard extends StatefulWidget {
  final UniversityMemory memory;
  final Function(String role, String name, String value) onComplete;

  const OnboardingWizard({
    required this.memory,
    required this.onComplete,
    super.key,
  });

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<OnboardingParticle> _particles = [];
  Offset? _attractionTarget;
  double _attractionStrength = 0.0;
  final math.Random _random = math.Random();

  // Wizard state variables
  int _currentStep = 0; // 0: Role, 1: Name, 2: Setup (Batch/Teacher), 3: Brain Sync
  String? _role; // 'student' or 'faculty'
  String? _selectedRoleMorph;
  final GlobalKey _studentCardKey = GlobalKey();
  final GlobalKey _facultyCardKey = GlobalKey();
  String _name = '';
  final TextEditingController _nameController = TextEditingController();

  // Student specific selections
  String? _program;
  int? _semester;
  String? _section;
  String _rollNo = '';

  // Faculty specific selections
  String? _selectedTeacher;
  String _teacherSearchQuery = '';
  final TextEditingController _teacherSearchController = TextEditingController();

  // Sync state
  double _syncProgress = 0.0;
  String _syncLog = '';

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
    _nameController.dispose();
    _teacherSearchController.dispose();
    super.dispose();
  }

  void _updateParticles() {
    if (!mounted) return;
    final double width = MediaQuery.sizeOf(context).width;
    final double height = MediaQuery.sizeOf(context).height;
    if (width == 0 || height == 0) return;

    final orbCenter = Offset(width / 2, height * 0.28);

    if (_particles.isEmpty) {
      for (int i = 0; i < 45; i++) {
        _particles.add(OnboardingParticle(
          x: _random.nextDouble() * width,
          y: _random.nextDouble() * height,
          vx: (_random.nextDouble() - 0.5) * 1.5,
          vy: (_random.nextDouble() - 0.5) * 1.5,
          size: 1.8 + _random.nextDouble() * 3.0,
          color: _random.nextBool() ? IrisTokens.brand : IrisTokens.blue,
          alpha: 0.15 + _random.nextDouble() * 0.35,
        ));
      }
    }

    setState(() {
      for (final p in _particles) {
        p.update(width, height, orbCenter, _attractionTarget, _attractionStrength, _random, _currentStep);
      }
    });
  }

  void _triggerAttraction(Offset globalPosition) {
    setState(() {
      _attractionTarget = globalPosition;
      _attractionStrength = 5.0;

      final double width = MediaQuery.sizeOf(context).width;
      final double height = MediaQuery.sizeOf(context).height;
      final orbCenter = Offset(width / 2, height * 0.28);

      final dx = globalPosition.dx - orbCenter.dx;
      final dy = globalPosition.dy - orbCenter.dy;
      final angle = math.atan2(dy, dx);

      // Spawn burst of particles shooting towards the action item
      for (int i = 0; i < 25; i++) {
        final speed = 4.0 + _random.nextDouble() * 5.0;
        final spreadAngle = angle + (_random.nextDouble() - 0.5) * 0.8;
        _particles.add(OnboardingParticle(
          x: orbCenter.dx,
          y: orbCenter.dy,
          vx: math.cos(spreadAngle) * speed,
          vy: math.sin(spreadAngle) * speed,
          size: 1.5 + _random.nextDouble() * 2.0,
          color: _random.nextBool()
              ? IrisTokens.brand
              : (_role == 'faculty' ? IrisTokens.blue : IrisTokens.purpleLight),
          alpha: 1.0,
        ));
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _attractionTarget = null;
          _attractionStrength = 0.0;
        });
      }
    });
  }

  void _nextStep() {
    if (_currentStep < 3) {
      IrisHaptics.actionMedium();
      setState(() {
        if (_currentStep == 0 && _role == 'faculty') {
          _currentStep = 2; // Jump directly from Role Selection (0) to Faculty List (2)
        } else {
          _currentStep++;
        }
      });

      if (_currentStep == 3) {
        _startBrainSync();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      IrisHaptics.actionMedium();
      setState(() {
        if (_currentStep == 2 && _role == 'faculty') {
          _currentStep = 0; // Go back directly from Faculty List (2) to Role Selection (0)
        } else {
          _currentStep--;
        }
      });
    }
  }

  void _startBrainSync() {
    setState(() {
      _syncProgress = 0.0;
      _syncLog = 'Establishing connection to academic core...';
    });

    IrisHaptics.actionHeavy();

    const totalDuration = Duration(milliseconds: 2400);
    const intervals = 24;
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
      if (progress < 0.20) {
        log = 'Resolving local database caches...';
      } else if (progress < 0.45) {
        log = _role == 'faculty'
            ? 'Analyzing teaching timetables for $_selectedTeacher...'
            : 'Decompressing schedules for batch $_program-$_semester$_section...';
      } else if (progress < 0.70) {
        log = 'Compiling Room Finder indexing parameters...';
      } else if (progress < 0.90) {
        log = 'Configuring Live Class trackers & sensory links...';
      } else {
        log = 'Onboarding complete! Starting your workspace...';
      }

      setState(() {
        _syncProgress = progress;
        _syncLog = log;
      });

      if (currentInterval % 4 == 0) {
        IrisHaptics.actionSoft();
      }

      if (currentInterval == intervals) {
        Future.delayed(const Duration(milliseconds: 450), () {
          if (!mounted) return;
          final value = _role == 'faculty'
              ? _selectedTeacher!
              : (_resolveBatch() ?? '$_program-$_semester$_section');
          final finalName = _role == 'faculty' ? _selectedTeacher! : _name;
          widget.onComplete(_role!, finalName, value);
        });
      }
    });
  }

  String? _resolveBatch() {
    if (_program == null || _semester == null || _section == null) {
      return null;
    }

    for (final batch in widget.memory.allBatches) {
      final key = BatchKey.parse(batch);
      if (key.program == _program && key.semester == _semester && key.section == _section) {
        return batch;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final orbCenter = Offset(width / 2, height * 0.28);

    return Scaffold(
      backgroundColor: isDark ? IrisTokens.surfaceDark : IrisTokens.surfaceLight,
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          Positioned.fill(
            child: CustomPaint(
              painter: OnboardingPainter(
                particles: _particles,
                attractionTarget: _attractionTarget,
                attractionStrength: _attractionStrength,
                animationValue: _controller.value,
                orbCenter: orbCenter,
                isDark: isDark,
                step: _currentStep,
              ),
            ),
          ),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.08, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: _buildStepContent(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStep0RoleSelection(isDark);
      case 1:
        return _buildStep1NameInput(isDark);
      case 2:
        return _buildStep2SetupProfile(isDark);
      case 3:
      default:
        return _buildStep3SyncProgress(isDark);
    }
  }

  // ==========================================================================
  // STEP 0: ROLE SELECTION
  // ==========================================================================
  Widget _buildStep0RoleSelection(bool isDark) {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Who are you?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your profile type to configure the system',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
            ),
          ),
          const Spacer(flex: 3),
          GlassCard(
            padding: EdgeInsets.zero,
            borderRadius: 24,
            child: Column(
              children: [
                _buildRoleCardRow(
                  key: _studentCardKey,
                  title: 'Student Profile',
                  subtitle: 'Timetables, batch trackers, dynamic alerts',
                  icon: Icons.school_rounded,
                  color: IrisTokens.brand,
                  isSelected: _selectedRoleMorph == 'student',
                  onTap: (globalPos) {
                    setState(() => _selectedRoleMorph = 'student');
                    _role = 'student';
                    _triggerAttraction(globalPos);
                    Future.delayed(const Duration(milliseconds: 320), () {
                      if (mounted) {
                        setState(() => _selectedRoleMorph = null);
                        _nextStep();
                      }
                    });
                  },
                ),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                _buildRoleCardRow(
                  key: _facultyCardKey,
                  title: 'Faculty Profile',
                  subtitle: 'Teaching schedules, room finder resources',
                  icon: Icons.badge_rounded,
                  color: IrisTokens.blue,
                  isSelected: _selectedRoleMorph == 'faculty',
                  onTap: (globalPos) {
                    setState(() => _selectedRoleMorph = 'faculty');
                    _role = 'faculty';
                    _triggerAttraction(globalPos);
                    Future.delayed(const Duration(milliseconds: 320), () {
                      if (mounted) {
                        setState(() => _selectedRoleMorph = null);
                        _nextStep();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildRoleCardRow({
    Key? key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required ValueChanged<Offset> onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      key: key,
      onTapDown: (details) {
        IrisHaptics.actionHeavy();
        onTap(details.globalPosition);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: const Cubic(0.05, 0.90, 0.10, 1.0),
        transform: isSelected ? (Matrix4.identity()..scale(1.03)) : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: isDark ? 0.22 : 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected 
              ? Border.all(color: color, width: 2.0)
              : Border.all(color: Colors.transparent, width: 0.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.40),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: isSelected ? 0.8 : 0.25), width: 1.2),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : color, size: 28),
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

  // ==========================================================================
  // STEP 1: NAME INPUT
  // ==========================================================================
  Widget _buildStep1NameInput(bool isDark) {
    final isNameValid = _name.length >= 2;

    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: _prevStep,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            'What is your name?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Provide your name for interface greeting panels',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
            ),
          ),
          const Spacer(flex: 3),
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISPLAY NAME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: IrisTokens.brand.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'e.g. John Doe',
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: IrisTokens.brand,
                        width: 1.5,
                      ),
                    ),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: IrisTokens.brand),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _name = val.trim();
                    });
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isNameValid
                          ? const LinearGradient(
                              colors: [IrisTokens.brand, IrisTokens.brandLight],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isNameValid
                          ? [
                              BoxShadow(
                                color: IrisTokens.brand.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: ElevatedButton(
                      onPressed: isNameValid ? _nextStep : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.05),
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP 2: PROFILE SETUP (STUDENT BATCH VS FACULTY NAME)
  // ==========================================================================
  Widget _buildStep2SetupProfile(bool isDark) {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: _prevStep,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
          const SizedBox(height: 16),
          Text(
            _role == 'faculty' ? 'Find Your Profile' : 'Select Your Batch',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _role == 'faculty'
                ? 'Search and link your registered faculty profile'
                : 'Select program, active semester and section subset',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _role == 'faculty'
                ? _buildFacultySelectorWidget(isDark)
                : _buildStudentSelectorWidget(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSelectorWidget(bool isDark) {
    // Filter programs to exclude batch-like templates
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

    final isReady = _program != null && _semester != null && _section != null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              _HorizontalSelectorRow(
                label: 'PROGRAM',
                selectedValue: _program,
                items: programs,
                icon: Icons.school_rounded,
                onSelected: (value) => setState(() {
                  _program = value;
                  _semester = null;
                  _section = null;
                }),
              ),
              const SizedBox(height: 20),
              _HorizontalSelectorRow(
                label: 'SEMESTER',
                selectedValue: _semester?.toString(),
                items: semesters.map((e) => e.toString()).toList(),
                icon: Icons.calendar_month_rounded,
                placeholder: _program == null ? 'Select program first' : 'No semesters found',
                onSelected: (value) => setState(() {
                  _semester = int.tryParse(value);
                  _section = null;
                }),
              ),
              const SizedBox(height: 20),
              _HorizontalSelectorRow(
                label: 'SECTION',
                selectedValue: _section,
                items: sections,
                icon: Icons.group_rounded,
                placeholder: _semester == null ? 'Select semester first' : 'No sections found',
                onSelected: (value) => setState(() => _section = value),
              ),
              const SizedBox(height: 20),
              _RollNumberInputField(
                rollNo: _rollNo,
                onChanged: (newRoll) {
                  setState(() => _rollNo = newRoll);
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setString('student_roll_no', newRoll);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: Container(
            decoration: BoxDecoration(
              gradient: isReady
                  ? const LinearGradient(
                      colors: [IrisTokens.brand, IrisTokens.brandLight],
                    )
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isReady
                  ? [
                      BoxShadow(
                        color: IrisTokens.brand.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: isReady ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.05),
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Begin Synchronization',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.sync_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFacultySelectorWidget(bool isDark) {
    return Column(
      children: [
        if (_selectedTeacher != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: IrisTokens.blue.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: IrisTokens.blue, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: IrisTokens.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SELECTED FACULTY PROFILE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: IrisTokens.blue,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        _selectedTeacher!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    IrisHaptics.actionSoft();
                    setState(() {
                      _selectedTeacher = null;
                      _name = '';
                    });
                  },
                  child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                ),
              ],
            ),
          ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FacultyDirectoryScreen(
              brain: widget.brain,
              memory: widget.memory,
              isSelectionMode: true,
              onTeacherSelected: (name) {
                IrisHaptics.selectionClick();
                setState(() {
                  _selectedTeacher = name;
                  _name = name;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
                            });
                          },
                          child: Container(
                            color: isSelected
                                ? IrisTokens.blue.withValues(alpha: 0.1)
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isSelected ? IrisTokens.blue : (isDark ? Colors.white : Colors.black))
                                        .withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: isSelected ? IrisTokens.blue : (isDark ? Colors.white54 : Colors.black54),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    teacherName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected
                                          ? IrisTokens.blue
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded, color: IrisTokens.blue, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: Container(
            decoration: BoxDecoration(
              gradient: isReady
                  ? const LinearGradient(
                      colors: [IrisTokens.blue, IrisTokens.purple],
                    )
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isReady
                  ? [
                      BoxShadow(
                        color: IrisTokens.blue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: isReady ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.05),
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Begin Synchronization',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.sync_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // STEP 3: SYNC PROGRESS (NEURAL SYNC LOADER)
  // ==========================================================================
  Widget _buildStep3SyncProgress(bool isDark) {
    return Padding(
      key: const ValueKey(3),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Glowing radial backdrop
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (_role == 'faculty' ? IrisTokens.blue : IrisTokens.brand).withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _syncProgress,
                    strokeWidth: 4,
                    color: _role == 'faculty' ? IrisTokens.blue : IrisTokens.brand,
                    backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(_syncProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SYNCING',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text(
              'Synchronizing Database',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Text(
                _syncLog,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper horizontal choice list selector row
class _HorizontalSelectorRow extends StatelessWidget {
  final String label;
  final String? selectedValue;
  final List<String> items;
  final IconData icon;
  final String placeholder;
  final ValueChanged<String> onSelected;

  const _HorizontalSelectorRow({
    required this.label,
    required this.selectedValue,
    required this.items,
    required this.icon,
    this.placeholder = 'No choices found',
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: IrisTokens.brand, size: 16),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
                letterSpacing: 1.5,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        items.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  placeholder,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                ),
              )
            : lgw.GlassMenu(
                menuWidth: MediaQuery.of(context).size.width - 48,
                menuHeight: math.min(items.length * 52.0 + 16.0, 240.0),
                menuBorderRadius: 20.0,
                settings: lgw.LiquidGlassSettings(
                  blur: 20,
                  ambientStrength: 0.7,
                  lightAngle: 0.15 * math.pi,
                  glassColor: (isDark ? IrisTokens.surfaceDarkElevated : Colors.white)
                      .withValues(alpha: isDark ? 0.45 : 0.5),
                  thickness: 18,
                ),
                triggerBuilder: (context, toggleMenu) {
                  return InkWell(
                    onTap: () {
                      IrisHaptics.actionSoft();
                      toggleMenu();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedValue ?? 'Select $label',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: selectedValue != null 
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white30 : Colors.black38),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDark ? Colors.white54 : Colors.black45,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                items: items.map((String val) {
                  return lgw.GlassMenuItem(
                    title: val,
                    onTap: () {
                      IrisHaptics.chipSelect();
                      onSelected(val);
                    },
                  );
                }).toList(),
              ),
      ],
    );
  }
}

class _RollNumberInputField extends StatefulWidget {
  final String rollNo;
  final ValueChanged<String> onChanged;

  const _RollNumberInputField({
    required this.rollNo,
    required this.onChanged,
  });

  @override
  State<_RollNumberInputField> createState() => _RollNumberInputFieldState();
}

class _RollNumberInputFieldState extends State<_RollNumberInputField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.rollNo);
  }

  @override
  void didUpdateWidget(covariant _RollNumberInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rollNo != oldWidget.rollNo && widget.rollNo != _controller.text) {
      _controller.text = widget.rollNo;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.badge_rounded, color: IrisTokens.brand, size: 16),
            const SizedBox(width: 8),
            Text(
              'ROLL NUMBER (3 DIGITS)',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
                letterSpacing: 1.5,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 3,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'e.g. 042',
              hintStyle: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
              border: InputBorder.none,
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel_rounded, size: 18),
                      color: isDark ? Colors.white54 : Colors.black45,
                      onPressed: () {
                        IrisHaptics.actionSoft();
                        _controller.clear();
                        widget.onChanged('');
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              final numericVal = val.replaceAll(RegExp(r'\D'), '');
              if (numericVal != val) {
                _controller.value = TextEditingValue(
                  text: numericVal,
                  selection: TextSelection.collapsed(offset: numericVal.length),
                );
              }
              widget.onChanged(numericVal);
            },
          ),
        ),
      ],
    );
  }
}
