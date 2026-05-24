import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/tokens.dart';
import '../core/glass.dart';
import '../core/animations.dart';
import '../core/theme_signals.dart';
import '../services/portal_sync_service.dart';
import '../services/ui_feedback.dart';

class AcademicsHubScreen extends StatefulWidget {
  const AcademicsHubScreen({super.key});

  @override
  State<AcademicsHubScreen> createState() => _AcademicsHubScreenState();
}

class _AcademicsHubScreenState extends State<AcademicsHubScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _academicsData;
  bool _isLoading = false;
  final Set<String> _expandedCourses = {};
  double _targetCgpa = 3.5;
  String? _savedUserName;
  String? _savedUserBatch;
  
  late final AnimationController _syncAnimCtrl;

  String _extractProgram(String? reg) {
    if (reg == null || reg.isEmpty) return 'BCS';
    final upper = reg.toUpperCase();
    final match = RegExp(r'(BCS|BSE|BEE|BME|BBA|BSCS|BSSE|BEE)').firstMatch(upper);
    if (match != null) return match.group(0)!;
    final parts = reg.split('-');
    if (parts.length >= 2) return parts[1].toUpperCase();
    return 'UG';
  }

  Map<String, dynamic> _getMockAcademicsData() {
    return {
      "student": _savedUserName ?? "Malik Aurangzaib Ahmad",
      "student_id": _savedUserBatch ?? "CIIT/FA25-BCS-101/SWL",
      "extracted_at": DateTime.now().toIso8601String(),
      "semester_summary": {
        "total_courses": 6,
        "total_pending_tasks": 3,
        "overall_attendance_avg": "88%"
      },
      "courses": [
        {
          "id": "25914",
          "code": "PHY124",
          "name": "Applied Physics",
          "instructor": "Hassan Iqbal",
          "credits": "3",
          "attendance": "92%",
          "assignments": [],
          "quizzes": []
        },
        {
          "id": "25894",
          "code": "CSC102",
          "name": "Discrete Structures",
          "instructor": "Shaheen Akhter",
          "credits": "3",
          "attendance": "86%",
          "assignments": [],
          "quizzes": []
        },
        {
          "id": "25904",
          "code": "HUM120",
          "name": "Expository Writing",
          "instructor": "Dr. Ammar Ashraf",
          "credits": "3",
          "attendance": "78%",
          "assignments": [
            {
              "title": "Assignment 4 - Expository writing",
              "due": "2026-05-18",
              "status": "OPEN"
            }
          ],
          "quizzes": [
            {
              "title": "Quiz 1",
              "due": "2026-03-02",
              "status": "CLOSED"
            },
            {
              "title": "Quiz 2",
              "due": "2026-04-13",
              "status": "CLOSED"
            },
            {
              "title": "Quiz 3",
              "due": "2026-05-01",
              "status": "CLOSED"
            },
            {
              "title": "Quiz 4",
              "due": "2026-05-17",
              "status": "CLOSED"
            }
          ]
        },
        {
          "id": "25899",
          "code": "CSC241",
          "name": "Object Oriented Programming",
          "instructor": "Hamza Arif",
          "credits": "4",
          "attendance": "95%",
          "assignments": [],
          "quizzes": []
        },
        {
          "id": "25909",
          "code": "CSC291",
          "name": "Software Engineering",
          "instructor": "Kanwal Fatima",
          "credits": "3",
          "attendance": "84%",
          "assignments": [
            {
              "title": "TA4_SE",
              "due": "2026-05-17",
              "status": "OPEN"
            }
          ],
          "quizzes": []
        },
        {
          "id": "25919",
          "code": "HUM161",
          "name": "Understanding of Holy Quran – I",
          "instructor": "Muhammad Yasin",
          "credits": "1",
          "attendance": "72%",
          "assignments": [
            {
              "title": "Assignment No. 4",
              "due": "2026-05-18",
              "status": "OPEN"
            }
          ],
          "quizzes": []
        }
      ]
    };
  }

  @override
  void initState() {
    super.initState();
    _syncAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _loadLocalData();
    PortalSyncService.syncNotifier.addListener(_onPortalUpdated);
  }

  @override
  void dispose() {
    _syncAnimCtrl.dispose();
    PortalSyncService.syncNotifier.removeListener(_onPortalUpdated);
    super.dispose();
  }

  void _onPortalUpdated() {
    if (mounted) {
      _loadLocalData();
    }
  }

  Future<void> _loadLocalData() async {
    final data = await PortalSyncService.getCachedAcademics();
    final prefs = await SharedPreferences.getInstance();
    final savedTarget = prefs.getDouble('iris_portal_target_cgpa') ?? 3.5;
    final userName = prefs.getString('student_user_name');
    final userBatch = prefs.getString('user_batch');
    
    if (mounted) {
      setState(() {
        _academicsData = data;
        _targetCgpa = savedTarget;
        _savedUserName = userName;
        _savedUserBatch = userBatch;
      });
    }
  }

  Future<void> _saveTargetCgpa(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('iris_portal_target_cgpa', val);
    setState(() {
      _targetCgpa = val;
    });
  }

  Map<String, double> _parseDetailedAttendance(String att) {
    final Map<String, double> details = {};
    
    // Find all progressBarTimer initializations
    // E.g. bar_25899-Class or bar_25899-Lab
    final regExp = RegExp(
      r"bar_\d+-([A-Za-z]+)'\)\.progressBarTimer\(\{\s*_percentage:\s*(\d+)",
      caseSensitive: false,
    );
    
    final matches = regExp.allMatches(att);
    for (final m in matches) {
      final type = m.group(1)!; // "Class" or "Lab"
      final pct = double.tryParse(m.group(2)!) ?? 0.0;
      details[type] = pct;
    }
    
    return details;
  }

  double _parseAttendancePct(String att) {
    final details = _parseDetailedAttendance(att);
    if (details.isNotEmpty) {
      final sum = details.values.reduce((a, b) => a + b);
      return sum / details.length;
    }
    
    // 1. Try to find the standard percentage format "XX%"
    final match = RegExp(r'(\d+)%').firstMatch(att);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    // 2. Try to find custom progress bar JavaScript percentage: "_percentage: XX"
    final jsMatch = RegExp(r'_percentage:\s*(\d+)').firstMatch(att);
    if (jsMatch != null) {
      return double.tryParse(jsMatch.group(1)!) ?? 0.0;
    }
    // 3. Try to find any stand-alone digits in case it's a raw number
    final rawNumberMatch = RegExp(r'^\s*(\d+)\s*$').firstMatch(att);
    if (rawNumberMatch != null) {
      return double.tryParse(rawNumberMatch.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  String _cleanAttendanceString(String att) {
    final details = _parseDetailedAttendance(att);
    if (details.isNotEmpty) {
      final List<String> parts = [];
      details.forEach((type, pct) {
        final shortType = type.toLowerCase() == 'class' ? 'Lec' : 'Lab';
        parts.add('$shortType: ${pct.toInt()}%');
      });
      return parts.join(' | ');
    }
    
    final pct = _parseAttendancePct(att);
    if (pct > 0.0 || att.contains('0')) {
      return '${pct.toInt()}%';
    }
    return att; // Fallback to raw string if parsing failed
  }

  String _cleanStudentId(String id) {
    if (id.isEmpty) return 'Not Synced';
    
    // 1. Try to find a classic COMSATS registration number pattern in the text
    // E.g. CIIT/FA25-BCS-101/SWL or SP24-BCS-055
    final regExp = RegExp(
      r'([A-Z]{2,4}\d{2}-[A-Z]{2,4}-\d{3})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(id);
    if (match != null) {
      return match.group(1)!.toUpperCase();
    }
    
    // 2. Otherwise, take the first line and strip any raw JS elements
    final firstLine = id.split('\n').firstWhere(
      (line) => line.trim().isNotEmpty,
      orElse: () => '',
    ).trim();
    
    if (firstLine.contains('\$') || firstLine.contains('{') || firstLine.contains('progressBarTimer')) {
      return 'Not Synced';
    }
    return firstLine;
  }

  String _cleanProfileText(String text, String fallback) {
    if (text.isEmpty) return fallback;
    final firstLine = text.split('\n').firstWhere(
      (line) => line.trim().isNotEmpty,
      orElse: () => '',
    ).trim();
    
    if (firstLine.contains('\$') || firstLine.contains('{') || firstLine.contains('progressBarTimer')) {
      return fallback;
    }
    return firstLine;
  }

  Color _getAttendanceColor(double pct) {
    if (pct >= 85.0) return const Color(0xFF10B981); // Emerald
    if (pct >= 75.0) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFF43F5E); // Rose
  }

  Future<void> _triggerManualSync() async {
    if (_isLoading) return;
    
    IrisHaptics.refreshStart();
    setState(() => _isLoading = true);
    _syncAnimCtrl.repeat();

    try {
      if (PortalSyncService.triggerHeadlessSync != null) {
        await PortalSyncService.triggerHeadlessSync!();
      } else {
        await PortalSyncService.performBackgroundSync(force: true);
      }
      
      // Delay slightly for natural feel
      await Future.delayed(const Duration(milliseconds: 1500));
      
      await _loadLocalData();
      
      if (mounted) {
        IrisHaptics.refreshSuccess();
        showIrisFrostedSnackBar(
          context,
          content: const Text('Academics Hub sync complete!'),
          tint: IrisTokens.success,
        );
      }
    } catch (e) {
      if (mounted) {
        IrisSfx.error();
        showIrisFrostedSnackBar(
          context,
          content: Text('Sync failed: $e'),
          tint: IrisTokens.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _syncAnimCtrl.stop();
        _syncAnimCtrl.reset();
      }
    }
  }

  void _showCgpaPicker() {
    IrisHaptics.chipSelect();
    double tempCgpa = _targetCgpa;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final glassSettings = IrisGlass.settings(
              context,
              blur: 24,
              ambientStrength: 0.8,
              lightAngle: 0.15 * math.pi,
              thickness: 18,
              glassColor: IrisGlass.adaptiveGlassColor(context, darkAlpha: 0.85, lightAlpha: 0.9),
            );

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: GlassSurface(
                settings: glassSettings,
                radius: 30,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white30 : Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Set Target CGPA',
                        style: IrisTextStyles.headline(context).copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Aim high! Choose your target academic performance.',
                        style: IrisTextStyles.caption(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        tempCgpa.toStringAsFixed(2),
                        style: IrisTextStyles.display(context).copyWith(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: IrisTokens.brand,
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: IrisTokens.brand,
                          inactiveTrackColor: (isDark ? Colors.white24 : Colors.black12),
                          thumbColor: IrisTokens.brand,
                          overlayColor: IrisTokens.brand.withValues(alpha: 0.2),
                          valueIndicatorColor: IrisTokens.brand,
                        ),
                        child: Slider(
                          value: tempCgpa,
                          min: 1.0,
                          max: 4.0,
                          divisions: 60,
                          onChanged: (val) {
                            setModalState(() {
                              tempCgpa = double.parse(val.toStringAsFixed(2));
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: IrisTokens.brand.withValues(alpha: 0.4)),
                                shape: RoundedRectangleBorder(borderRadius: IrisTokens.buttonRadius),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: IrisTokens.brand,
                                shape: RoundedRectangleBorder(borderRadius: IrisTokens.buttonRadius),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                              ),
                              onPressed: () {
                                _saveTargetCgpa(tempCgpa);
                                IrisHaptics.actionHeavy();
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Save Target',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasRealData = _academicsData != null;
    final data = _academicsData ?? _getMockAcademicsData();

    // Summary values
    final studentName = _cleanProfileText(data['student']?.toString() ?? _savedUserName ?? '', 'Student');
    final studentId = _cleanStudentId(data['student_id']?.toString() ?? _savedUserBatch ?? '');
    final totalCourses = data['semester_summary']?['total_courses'] ?? 0;
    final totalPendingTasks = data['semester_summary']?['total_pending_tasks'] ?? 0;
    final rawAttendanceAvg = data['semester_summary']?['overall_attendance_avg']?.toString() ?? 'N/A';
    final attendanceAvg = _cleanAttendanceString(rawAttendanceAvg);
    final coursesList = data['courses'] as List<dynamic>? ?? [];

    final glassSettings = IrisGlass.settings(
      context,
      blur: 16,
      ambientStrength: 0.65,
      lightAngle: 0.15 * math.pi,
      thickness: 16,
    );

    return Scaffold(
      backgroundColor: isDark ? IrisTokens.surfaceDark : IrisTokens.surfaceLight,
      body: Stack(
        children: [
          // Background Gradient meshes
          if (isDark) ...[
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: IrisTokens.brand.withValues(alpha: 0.18),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -150,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: IrisTokens.purple.withValues(alpha: 0.14),
                ),
              ),
            ),
          ] else ...[
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: IrisTokens.brandLight.withValues(alpha: 0.22),
                ),
              ),
            ),
          ],
          
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _triggerManualSync,
              color: IrisTokens.brand,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 110), // Padding bottom for dock
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP BAR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Academics Hub',
                              style: IrisTextStyles.title(context).copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 30,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'COMSATS Student Workspace',
                              style: IrisTextStyles.caption(context),
                            ),
                          ],
                        ),
                        // Refresh/Sync button
                        GestureDetector(
                          onTap: _triggerManualSync,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                width: 1.0,
                              ),
                            ),
                            child: RotationTransition(
                              turns: _syncAnimCtrl,
                              child: Icon(
                                Icons.sync_rounded,
                                color: isDark ? Colors.white : Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // SUMMARY/GPA HEADER CARD
                    ClipRRect(
                      borderRadius: IrisTokens.cardRadius,
                      child: GlassSurface(
                        settings: glassSettings,
                        radius: 20,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 0.12),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Student profile header
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: IrisTokens.brand.withValues(alpha: 0.2),
                                    child: Icon(Icons.person_rounded, color: IrisTokens.brand, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentName,
                                          style: IrisTextStyles.headline(context).copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 21,
                                            letterSpacing: -0.4,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: IrisTokens.brand.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: IrisTokens.brand.withValues(alpha: 0.3),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Text(
                                                _extractProgram(studentId),
                                                style: TextStyle(
                                                  color: IrisTokens.brandLight,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: _showCgpaPicker,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: IrisTokens.purple.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: IrisTokens.purple.withValues(alpha: 0.3),
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.emoji_events_outlined, size: 10, color: IrisTokens.purpleLight),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Target: ${_targetCgpa.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        color: IrisTokens.purpleLight,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Text(
                                              studentId,
                                              style: IrisTextStyles.caption(context).copyWith(
                                                fontFamily: 'monospace',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 30, color: Colors.white10),
                              
                              // Main metrics row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Enrolled Courses metric
                                  _buildSummaryMetric(
                                    context,
                                    title: 'COURSES',
                                    value: '$totalCourses',
                                    subtitle: 'Enrolled',
                                    accentColor: IrisTokens.brand,
                                    icon: Icons.school_outlined,
                                  ),
                                  
                                  // Attendance widget
                                  _buildSummaryMetric(
                                    context,
                                    title: 'ATTENDANCE',
                                    value: attendanceAvg,
                                    subtitle: 'Overall Avg',
                                    accentColor: IrisTokens.success,
                                    icon: Icons.analytics_outlined,
                                  ),
                                  
                                  // Pending Tasks widget
                                  _buildSummaryMetric(
                                    context,
                                    title: 'PENDING TASKS',
                                    value: '$totalPendingTasks',
                                    subtitle: 'Open Tasks',
                                    accentColor: IrisTokens.warning,
                                    icon: Icons.assignment_late_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // LIST OF COURSES SECTION HEADER
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: IrisTokens.brand,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'YOUR ENROLLED COURSES',
                          style: IrisTextStyles.sectionHeader(context).copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // COURSE LIST CARDS
                      // List of course items
                      if (coursesList.isEmpty)
                        ClipRRect(
                          borderRadius: IrisTokens.cardRadius,
                          child: GlassSurface(
                            settings: glassSettings,
                            radius: 20,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 0.08),
                                  width: 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: IrisTokens.brand.withValues(alpha: 0.1),
                                    ),
                                    child: Icon(
                                      Icons.school_outlined,
                                      color: IrisTokens.brand,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Enrolled Courses Found',
                                    style: IrisTextStyles.headline(context).copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'We couldn\'t find any courses in your student database record. Make sure your account is active or trigger a refresh.',
                                    style: IrisTextStyles.caption(context),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: IrisTokens.brand,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: IrisTokens.buttonRadius,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      elevation: 0,
                                    ),
                                    onPressed: _triggerManualSync,
                                    icon: const Icon(Icons.sync_rounded, size: 18),
                                    label: const Text(
                                      'Refresh Database',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: coursesList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                          final course = coursesList[index] as Map<String, dynamic>;
                          final courseCode = course['code']?.toString() ?? 'N/A';
                          final courseName = course['name']?.toString() ?? 'Unknown Course';
                          final instructor = course['instructor']?.toString() ?? 'Unknown';
                          final credits = course['credits']?.toString() ?? '3';
                          final attendance = course['attendance']?.toString() ?? '0%';
                          final assignments = course['assignments'] as List<dynamic>? ?? [];
                          final quizzes = course['quizzes'] as List<dynamic>? ?? [];
                          
                          final isExpanded = _expandedCourses.contains(courseCode);
                          final attPct = _parseAttendancePct(attendance);
                          final attColor = _getAttendanceColor(attPct);

                          return ClipRRect(
                            borderRadius: IrisTokens.cardRadius,
                            child: GlassSurface(
                              settings: glassSettings,
                              radius: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: (isDark ? Colors.white : IrisTokens.brand).withValues(
                                      alpha: isExpanded ? 0.22 : 0.08,
                                    ),
                                    width: isExpanded ? 1.5 : 1.0,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    IrisHaptics.selectionClick();
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedCourses.remove(courseCode);
                                      } else {
                                        _expandedCourses.add(courseCode);
                                      }
                                    });
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // COLLAPSED CARD CONTENT
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Top Row: Code Tag & Credit Tag + Attendance Badge
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: IrisTokens.brand.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        courseCode,
                                                        style: TextStyle(
                                                          color: IrisTokens.brand,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: IrisTokens.purple.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        '$credits Credits',
                                                        style: TextStyle(
                                                          color: IrisTokens.purpleLight,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: attColor.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: attColor.withValues(alpha: 0.3),
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: attColor,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        _cleanAttendanceString(attendance),
                                                        style: TextStyle(
                                                          color: attColor,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 14),
                                            
                                            // Title: Course Name
                                            Text(
                                              courseName,
                                              style: IrisTextStyles.headline(context).copyWith(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18,
                                                letterSpacing: -0.4,
                                                height: 1.25,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            
                                            // Subtitle: Instructor Name
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.person_outline_rounded,
                                                  size: 14,
                                                  color: (isDark ? Colors.white38 : Colors.black38),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  instructor,
                                                  style: IrisTextStyles.caption(context).copyWith(
                                                    fontSize: 12,
                                                    color: (isDark ? Colors.white60 : Colors.black54),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Dynamic Attendance Gradient Line
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: Container(
                                            height: 4,
                                            color: (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: (attPct / 100.0).clamp(0.0, 1.0),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      attColor.withValues(alpha: 0.7),
                                                      attColor,
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      
                                      // EXPANDED DETAILS ACCORDION
                                      AnimatedSize(
                                        duration: const Duration(milliseconds: 300),
                                        curve: IrisMotion.standard,
                                        child: isExpanded
                                            ? _buildExpandedDetails(context, instructor, credits, assignments, quizzes)
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!hasRealData)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.45 : 0.25),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.center,
                    child: GlassSurface(
                      settings: glassSettings,
                      radius: 20,
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 0.12),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: IrisTokens.brandGradient,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: IrisTokens.brand.withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Connect Student Portal',
                              style: IrisTextStyles.headline(context).copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Unlock live attendance tracking, pending assignments, and course tasks directly from the COMSATS student database.',
                              style: IrisTextStyles.caption(context),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: IrisTokens.brand,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: IrisTokens.buttonRadius,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                elevation: 0,
                              ),
                              onPressed: () {
                                IrisHaptics.actionHeavy();
                                _triggerManualSync();
                              },
                              icon: const Icon(Icons.sync_rounded),
                              label: const Text(
                                'Sync Academics Hub',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 22,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: IrisTextStyles.headline(context).copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: IrisTextStyles.overline(context).copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(
    BuildContext context,
    String instructor,
    String credits,
    List<dynamic> assignments,
    List<dynamic> quizzes,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.02)),
        border: const Border(
          top: BorderSide(color: Colors.white10, width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Metadata badges (instructor, credits)
          Row(
            children: [
              // Instructor badge
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 16, color: IrisTokens.brand),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INSTRUCTOR', style: IrisTextStyles.overline(context).copyWith(fontSize: 8)),
                            Text(
                              instructor,
                              style: IrisTextStyles.label(context).copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Credits badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.credit_card_outlined, size: 16, color: IrisTokens.purple),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CREDITS', style: IrisTextStyles.overline(context).copyWith(fontSize: 8)),
                        Text(
                          '$credits Hours',
                          style: IrisTextStyles.label(context).copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Assignments accordion list
          _buildTaskHeader(context, title: 'Assignments', count: assignments.length, barColor: Colors.deepOrangeAccent),
          const SizedBox(height: 10),
          if (assignments.isEmpty) ...[
            _buildEmptyStateRow(context, 'All Caught Up! No pending assignments.', isAssignment: true)
          ] else ...[
            ...assignments.map((task) => _buildTaskRow(context, task, isAssignment: true)),
          ],
          const SizedBox(height: 20),

          // Quizzes accordion list
          _buildTaskHeader(context, title: 'Quizzes', count: quizzes.length, barColor: Colors.tealAccent),
          const SizedBox(height: 10),
          if (quizzes.isEmpty) ...[
            _buildEmptyStateRow(context, 'No quizzes scheduled at this time.', isAssignment: false)
          ] else ...[
            ...quizzes.map((task) => _buildTaskRow(context, task, isAssignment: false)),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskHeader(
    BuildContext context, {
    required String title,
    required int count,
    required Color barColor,
  }) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: IrisTextStyles.overline(context).copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: barColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: barColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateRow(
    BuildContext context,
    String message, {
    required bool isAssignment,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isAssignment ? IrisTokens.brand : IrisTokens.teal;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.05 : 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: IrisTextStyles.caption(context).copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context, Map<String, dynamic> task, {required bool isAssignment}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = task['title']?.toString() ?? 'Untitled';
    final due = task['due']?.toString() ?? 'N/A';
    final isOpen = task['status']?.toString().toUpperCase() == 'OPEN';

    final badgeColor = isOpen ? IrisTokens.brand : (isDark ? Colors.white30 : Colors.black38);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.03 : 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.6)),
      ),
      child: Row(
        children: [
          // Icon indicator
          Icon(
            isAssignment ? Icons.assignment_outlined : Icons.quiz_outlined,
            size: 18,
            color: isOpen ? IrisTokens.brand : Colors.grey,
          ),
          const SizedBox(width: 12),
          
          // Task Title and due date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: IrisTextStyles.label(context).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.3,
                    decoration: isOpen ? null : TextDecoration.lineThrough,
                    color: isOpen ? null : Colors.grey,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Due: $due',
                  style: IrisTextStyles.caption(context).copyWith(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isOpen ? 'OPEN' : 'CLOSED',
              style: TextStyle(
                color: badgeColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
