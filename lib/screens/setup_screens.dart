import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../core/vital_theme.dart';
import '../services/ui_feedback.dart';
import '../services/helpdesk_faculty_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassCard;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

typedef OnboardingCompleteCallback = Function(String role, String name, String value);

/// Ultra-Fluid Onboarding Setup Wizard & Faculty Selector for IRIS.
class OnboardingWizard extends StatefulWidget {
  final UniversityMemory memory;
  final OnboardingCompleteCallback onComplete;

  const OnboardingWizard({
    super.key,
    required this.memory,
    required this.onComplete,
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

  // Wizard steps:
  // 0: Role Selection (Student / Faculty)
  // 1: Profile Selection (Student Batch / Faculty Directory Profile)
  // 2: Notification Preferences (First-time Setup Toggles)
  // 3: Neural Sync Loader
  int _currentStep = 0;

  String? _role; // 'student' or 'faculty'
  String? _selectedRoleMorph;
  final GlobalKey _studentCardKey = GlobalKey();
  final GlobalKey _facultyCardKey = GlobalKey();

  String _name = '';
  String? _program;
  int? _semester;
  String? _section;
  String _rollNo = '';

  // Faculty selections & live helpdesk list
  String? _selectedTeacher;
  FacultyProfile? _selectedFacultyProfile;
  String _teacherSearchQuery = '';
  final TextEditingController _teacherSearchController = TextEditingController();
  List<FacultyProfile> _facultyList = [];
  bool _loadingFaculty = false;

  // Notification Toggles (First-Time Setup)
  bool _notifClassAlerts = true;
  bool _notifExamAlerts = true;
  bool _notifCampusBroadcasts = true;

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
    _fetchLiveFacultyProfiles();
  }

  @override
  void dispose() {
    _controller.removeListener(_updateParticles);
    _controller.dispose();
    _teacherSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveFacultyProfiles() async {
    setState(() => _loadingFaculty = true);
    try {
      final service = HelpdeskFacultyService();
      final payload = await service.fetchLiveFirstWithFallbackPayload();
      if (mounted) {
        setState(() {
          _facultyList = List<FacultyProfile>.from(payload.items)
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          _loadingFaculty = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFaculty = false);
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    final double width = MediaQuery.sizeOf(context).width;
    final double height = MediaQuery.sizeOf(context).height;
    if (width == 0 || height == 0) return;

    final orbCenter = Offset(width / 2, height * 0.28);

    if (_particles.isEmpty) {
      for (int i = 0; i < 18; i++) {
        _particles.add(OnboardingParticle(
          x: _random.nextDouble() * width,
          y: _random.nextDouble() * height,
          vx: (_random.nextDouble() - 0.5) * 0.12,
          vy: (_random.nextDouble() - 0.5) * 0.12,
          size: 1.5 + _random.nextDouble() * 2.0,
          color: _random.nextBool() ? IrisTokens.brand : IrisTokens.blue,
          alpha: 0.08 + _random.nextDouble() * 0.15,
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
      setState(() => _currentStep++);

      if (_currentStep == 3) {
        _startBrainSync();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      IrisHaptics.actionMedium();
      setState(() {
        _currentStep--;
        if (_currentStep == 0) {
          _role = null;
          _selectedRoleMorph = null;
        }
      });
    }
  }

  void _showFacultyConfirmationDialog(FacultyProfile profile) {
    IrisHaptics.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: IrisTokens.blue.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 36,
                backgroundColor: IrisTokens.blue.withValues(alpha: 0.2),
                child: Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'F',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: IrisTokens.blue,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                profile.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${profile.department} • ${profile.location}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedTeacher = profile.name;
                      _selectedFacultyProfile = profile;
                    });
                    _nextStep(); // Proceed directly to Notification Preferences Step!
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IrisTokens.blue,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'CONFIRM PROFILE & CONTINUE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startBrainSync() async {
    final prefs = await SharedPreferences.getInstance();

    // Save Notification Preferences
    await prefs.setBool('notif_class_alerts', _notifClassAlerts);
    await prefs.setBool('notif_exam_alerts', _notifExamAlerts);
    await prefs.setBool('notif_campus_broadcasts', _notifCampusBroadcasts);

    setState(() {
      _syncProgress = 0.0;
      _syncLog = 'Establishing connection to academic core...';
    });

    IrisHaptics.actionHeavy();

    const totalDuration = Duration(milliseconds: 2200);
    const intervals = 22;
    int currentInterval = 0;

    final timerStream = Stream.periodic(
      Duration(milliseconds: totalDuration.inMilliseconds ~/ intervals),
      (count) => count,
    ).take(intervals);

    timerStream.listen((count) async {
      if (!mounted) return;

      currentInterval++;
      final double progress = currentInterval / intervals;

      String log = '';
      if (progress < 0.25) {
        log = 'Resolving local database caches...';
      } else if (progress < 0.55) {
        log = _role == 'faculty'
            ? 'Analyzing teaching timetables for ${_selectedTeacher ?? "Faculty"}...'
            : 'Decompressing schedules for batch $_program-$_semester$_section...';
      } else if (progress < 0.85) {
        log = 'Configuring Live Class trackers & sensory links...';
      } else {
        log = 'Synchronization complete!';
      }

      setState(() {
        _syncProgress = progress;
        _syncLog = log;
      });

  String _resolveSelectedBatchKey() {
    if (_program == null || _semester == null || _section == null) return '';
    for (final batch in widget.memory.allBatches) {
      final key = BatchKey.parse(batch);
      if (key.program.toUpperCase() == _program!.toUpperCase() &&
          key.semester == _semester &&
          key.section.toUpperCase() == _section!.toUpperCase()) {
        return batch;
      }
    }
    return '$_program-$_semester$_section';
  }

      if (currentInterval >= intervals) {
        final prefs = await SharedPreferences.getInstance();
        if (_role == 'faculty') {
          final teacherName = _selectedTeacher ?? 'Faculty Member';
          await prefs.setString('user_role', 'faculty');
          await prefs.setString('active_role', 'faculty');
          await prefs.setString('faculty_user_name', teacherName);
          await prefs.setString('faculty_teacher', teacherName);
          await prefs.setString('student_name', teacherName);
        } else {
          final batchKey = _resolveSelectedBatchKey();
          final studentName = _name.trim().isNotEmpty ? _name.trim() : 'Student';
          await prefs.setString('user_role', 'student');
          await prefs.setString('active_role', 'student');
          await prefs.setString('student_name', studentName);
          await prefs.setString('student_user_name', studentName);
          await prefs.setString('user_name', studentName);
          await prefs.setString('name', studentName);
          await prefs.setString('student_batch', batchKey);
          await prefs.setString('selected_batch', batchKey);
          await prefs.setString('user_batch', batchKey);
          await prefs.setString('student_roll_no', _rollNo);
        }

        await prefs.setBool('is_first_time', false);
        await prefs.setBool('setup_completed', true);

        if (mounted) {
          IrisHaptics.actionHeavy();
          if (_role == 'faculty') {
            final teacherName = _selectedTeacher ?? 'Faculty Member';
            widget.onComplete('faculty', teacherName, teacherName);
          } else {
            final batchKey = _resolveSelectedBatchKey();
            final studentName = _name.trim().isNotEmpty ? _name.trim() : 'Student';
            widget.onComplete('student', studentName, batchKey);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF030712) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Canvas Particles
          CustomPaint(
            size: Size.infinite,
            painter: OnboardingParticlePainter(particles: _particles),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: List.generate(4, (index) {
                      final isActive = index <= _currentStep;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: isActive
                                ? (_role == 'faculty' ? IrisTokens.blue : IrisTokens.brand)
                                : (isDark ? Colors.white12 : Colors.black12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    child: _buildStepContent(isDark),
                  ),
                ),
              ],
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
        return _buildStep1ProfileSetup(isDark);
      case 2:
        return _buildStep2NotificationPreferences(isDark);
      case 3:
      default:
        return _buildStep3SyncProgress(isDark);
    }
  }

  // STEP 0: ROLE SELECTION
  Widget _buildStep0RoleSelection(bool isDark) {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Who are you?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select your profile type to configure the system',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
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
                    Future.delayed(const Duration(milliseconds: 300), () {
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
                    Future.delayed(const Duration(milliseconds: 300), () {
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
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildRoleCardRow({
    required Key key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required ValueChanged<Offset> onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      key: key,
      onTapDown: (details) => onTap(details.globalPosition),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 1: PROFILE SETUP
  Widget _buildStep1ProfileSetup(bool isDark) {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                _role == 'faculty' ? 'Faculty Directory' : 'Select Your Batch',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(
              _role == 'faculty'
                  ? 'Tap your faculty profile card to confirm & proceed'
                  : 'Select program, active semester, section & roll number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _role == 'faculty'
                ? _buildFacultyDirectoryListWidget(isDark)
                : _buildStudentSelectorWidget(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyDirectoryListWidget(bool isDark) {
    final matched = _facultyList
        .where((f) => f.name.toLowerCase().contains(_teacherSearchQuery.toLowerCase()) ||
                      f.department.toLowerCase().contains(_teacherSearchQuery.toLowerCase()) ||
                      f.location.toLowerCase().contains(_teacherSearchQuery.toLowerCase()))
        .toList();

    return Column(
      children: [
        // Clean Search Field
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: _teacherSearchController,
            onChanged: (val) => setState(() => _teacherSearchQuery = val.trim()),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search faculty by name, department...',
              hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4)),
              prefixIcon: const Icon(Icons.search_rounded, color: IrisTokens.blue),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: _loadingFaculty
              ? const Center(child: CircularProgressIndicator(color: IrisTokens.blue))
              : matched.isEmpty
                  ? Center(
                      child: Text(
                        'No matching faculty profiles found',
                        style: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4)),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: matched.length,
                      itemBuilder: (context, index) {
                        final item = matched[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => _showFacultyConfirmationDialog(item),
                            borderRadius: BorderRadius.circular(16),
                            child: GlassCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: IrisTokens.blue.withValues(alpha: 0.2),
                                    child: Text(
                                      item.name.isNotEmpty ? item.name[0].toUpperCase() : 'F',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        Text(
                                          '${item.department} • ${item.location}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: IrisTokens.blue),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStudentSelectorWidget(bool isDark) {
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

    final isReady = _name.trim().isNotEmpty && _program != null && _semester != null && _section != null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. YOUR FULL NAME INPUT AT THE VERY TOP
              _StudentNameInputField(
                name: _name,
                onChanged: (newName) {
                  setState(() => _name = newName);
                },
              ),
              const SizedBox(height: 16),

              // 2. PROGRAM GLASS MENU SELECTOR
              _GlassMenuDropdownSelector(
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
              const SizedBox(height: 16),

              // 3. SEMESTER GLASS MENU SELECTOR
              _GlassMenuDropdownSelector(
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
              const SizedBox(height: 16),

              // 4. SECTION GLASS MENU SELECTOR
              _GlassMenuDropdownSelector(
                label: 'SECTION',
                selectedValue: _section,
                items: sections,
                icon: Icons.group_rounded,
                placeholder: _semester == null ? 'Select semester first' : 'No sections found',
                onSelected: (value) => setState(() => _section = value),
              ),
              const SizedBox(height: 16),

              // 5. ROLL NUMBER (OPTIONAL)
              _RollNumberInputField(
                rollNo: _rollNo,
                onChanged: (newRoll) {
                  setState(() => _rollNo = newRoll);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isReady ? _nextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: IrisTokens.brand,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CONTINUE TO PREFERENCES',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // STEP 2: NOTIFICATION PREFERENCES
  Widget _buildStep2NotificationPreferences(bool isDark) {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Notification Setup',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(
              'Configure your alerts for classes, exams and broadcasts',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 24),

          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _buildNotificationToggleRow(
                  title: 'Live Class Schedule Alerts',
                  subtitle: 'Get notified 10 mins before your upcoming classes',
                  icon: Icons.notifications_active_rounded,
                  value: _notifClassAlerts,
                  onChanged: (val) => setState(() => _notifClassAlerts = val),
                  isDark: isDark,
                ),
                Divider(height: 24, color: isDark ? Colors.white10 : Colors.black12),
                _buildNotificationToggleRow(
                  title: 'Exam & Date Sheet Reminders',
                  subtitle: 'Timely reminders for midterm & final exam dates',
                  icon: Icons.edit_calendar_rounded,
                  value: _notifExamAlerts,
                  onChanged: (val) => setState(() => _notifExamAlerts = val),
                  isDark: isDark,
                ),
                Divider(height: 24, color: isDark ? Colors.white10 : Colors.black12),
                _buildNotificationToggleRow(
                  title: 'Emergency Campus Broadcasts',
                  subtitle: 'Real-time announcements & sports week updates',
                  icon: Icons.campaign_rounded,
                  value: _notifCampusBroadcasts,
                  onChanged: (val) => setState(() => _notifCampusBroadcasts = val),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _role == 'faculty' ? IrisTokens.blue : IrisTokens.brand,
                foregroundColor: Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'BEGIN SYNCHRONIZATION',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.sync_rounded, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNotificationToggleRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: _role == 'faculty' ? IrisTokens.blue : IrisTokens.brand, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: _role == 'faculty' ? IrisTokens.blue : IrisTokens.brand,
          onChanged: (val) {
            IrisHaptics.selectionClick();
            onChanged(val);
          },
        ),
      ],
    );
  }

  // STEP 3: SYNC PROGRESS
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
                        color: (_role == 'faculty' ? IrisTokens.blue : IrisTokens.brand),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              _syncLog,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentNameInputField extends StatelessWidget {
  final String name;
  final ValueChanged<String> onChanged;

  const _StudentNameInputField({
    required this.name,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_rounded, size: 14, color: IrisTokens.brand),
            const SizedBox(width: 6),
            Text(
              'YOUR FULL NAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: IrisTokens.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextFormField(
            initialValue: name,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'e.g. Malik Aurangzaib',
              hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4)),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassMenuDropdownSelector extends StatelessWidget {
  final String label;
  final String? selectedValue;
  final List<String> items;
  final IconData icon;
  final String? placeholder;
  final ValueChanged<String> onSelected;

  const _GlassMenuDropdownSelector({
    required this.label,
    required this.selectedValue,
    required this.items,
    required this.icon,
    this.placeholder,
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
            Icon(icon, size: 14, color: IrisTokens.brand),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: IrisTokens.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        items.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  placeholder ?? 'No options available',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                  ),
                ),
              )
            : lgw.GlassMenu(
                menuWidth: MediaQuery.sizeOf(context).width - 48,
                menuHeight: math.min(items.length * 52.0 + 16.0, 240.0),
                menuBorderRadius: 20.0,
                settings: lgw.LiquidGlassSettings(
                  blur: 16,
                  ambientStrength: 0.7,
                  glassColor: (isDark ? const Color(0xFF0F172A) : Colors.white)
                      .withValues(alpha: isDark ? 0.6 : 0.7),
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
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selectedValue != null
                              ? IrisTokens.brand
                              : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
                          width: selectedValue != null ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedValue ?? 'Select $label',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: selectedValue != null
                                  ? (isDark ? Colors.white : Colors.black)
                                  : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: selectedValue != null
                                ? IrisTokens.brand
                                : (isDark ? Colors.white54 : Colors.black45),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                items: items.map((val) {
                  return lgw.GlassMenuItem(
                    title: val,
                    icon: Icon(icon, size: 18, color: IrisTokens.brand),
                    onTap: () {
                      IrisHaptics.selectionClick();
                      onSelected(val);
                    },
                  );
                }).toList(),
              ),
      ],
    );
  }
}

class _RollNumberInputField extends StatelessWidget {
  final String rollNo;
  final ValueChanged<String> onChanged;

  const _RollNumberInputField({
    required this.rollNo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.badge_rounded, size: 14, color: IrisTokens.brand),
            const SizedBox(width: 6),
            Text(
              'ROLL NUMBER (OPTIONAL)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: IrisTokens.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextFormField(
            initialValue: rollNo,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'e.g. SP26-BCS-001',
              hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4)),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

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
    int currentStep,
  ) {
    x += vx;
    y += vy;

    if (x < 0) x = width;
    if (x > width) x = 0;
    if (y < 0) y = height;
    if (y > height) y = 0;

    if (attractionTarget != null) {
      final dx = attractionTarget.dx - x;
      final dy = attractionTarget.dy - y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > 1.0) {
        vx += (dx / dist) * attractionStrength * 0.1;
        vy += (dy / dist) * attractionStrength * 0.1;
      }
    }
  }
}

class OnboardingParticlePainter extends CustomPainter {
  final List<OnboardingParticle> particles;

  OnboardingParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OnboardingParticlePainter oldDelegate) => true;
}
