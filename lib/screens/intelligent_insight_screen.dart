import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../core/omni_brain.dart';
import '../services/ui_feedback.dart';
import '../services/helpdesk_schedule_data_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';
import '../widgets/iris_animated_mascot.dart';
import 'portal_screen.dart';

/// Ultra-Premium Intelligent Insight Screen for IRIS Mobile Client.
/// Inspired by modern Bento-grid UI with animated 3D mascot character,
/// portal sync status detection, academic metrics, transport route pinning,
/// least attendance warning alert, and upcoming semester schedule timeline.
class IntelligentInsightScreen extends StatefulWidget {
  final OmniBrain? brain;
  final UniversityMemory? memory;
  final VoidCallback? onBackPressed;
  final bool? isDark;

  const IntelligentInsightScreen({
    super.key,
    this.brain,
    this.memory,
    this.onBackPressed,
    this.isDark,
  });

  @override
  State<IntelligentInsightScreen> createState() => _IntelligentInsightScreenState();
}

class _IntelligentInsightScreenState extends State<IntelligentInsightScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mascotFloatController;
  late final AnimationController _mascotPulseController;
  late final AnimationController _mascotTapController;

  String _userName = 'Student';
  String _userBatch = 'SP26-BCS-1-A';
  bool _isPortalSynced = false;
  DateTime? _lastSyncTime;

  int _totalAssignments = 0;
  int _totalQuizzes = 0;
  double _overallAttendancePct = 86.5;
  int _totalLecturesThisWeek = 0;

  String _leastAttendanceCourse = 'CSC322 Operating Systems';
  double _leastAttendancePct = 68.0;
  int _classesNeededFor75Pct = 2;

  // Transport Route Pinning
  String _pinnedRouteId = 'Route 4A';
  String _pinnedRouteTitle = 'Route 4A: Saddar ➔ Campus';
  String _pinnedRouteTiming = 'Departs 4:30 PM • Stop 12';
  List<TransportRouteData> _availableRoutes = [];

  // Active Category Filter for Semester Events
  String _selectedEventFilter = 'All';

  // Mascot Interactive Quotes
  int _mascotQuoteIndex = 0;
  final List<String> _mascotQuotes = [
    'Hey! Need help checking your least attendance lecture?',
    'You need 2 more classes in Operating Systems to reach 75%!',
    'Route 4A bus leaves campus at 4:30 PM today!',
    'Midterm examinations begin in 24 days. Stay prepared!',
    'Did you review your open quizzes for this week?',
  ];

  // Semester Schedule Events
  final List<Map<String, dynamic>> _semesterEvents = [
    {
      'title': 'Classes Commencement',
      'date': 'Feb 09, 2026',
      'category': 'Classes',
      'icon': Icons.school_rounded,
      'color': IrisTokens.brand,
      'status': 'Active Phase',
    },
    {
      'title': 'Midterm Examinations',
      'date': 'Apr 13, 2026',
      'category': 'Exams',
      'icon': Icons.edit_calendar_rounded,
      'color': Colors.amber,
      'status': 'Upcoming in 24d',
    },
    {
      'title': 'Sports & Cultural Week',
      'date': 'May 04, 2026',
      'category': 'Events',
      'icon': Icons.emoji_events_rounded,
      'color': const Color(0xFF10B981),
      'status': 'Scheduled',
    },
    {
      'title': 'Final Examinations',
      'date': 'Jun 15, 2026',
      'category': 'Exams',
      'icon': Icons.history_edu_rounded,
      'color': Colors.purpleAccent,
      'status': 'Scheduled',
    },
  ];

  @override
  void initState() {
    super.initState();
    _mascotFloatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _mascotPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _mascotTapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _loadInsightData();
  }

  @override
  void dispose() {
    _mascotFloatController.dispose();
    _mascotPulseController.dispose();
    _mascotTapController.dispose();
    super.dispose();
  }

  void _loadInsightData() async {
    final prefs = await SharedPreferences.getInstance();

    final name = prefs.getString('student_user_name')?.trim().isNotEmpty == true
        ? prefs.getString('student_user_name')!.trim()
        : (prefs.getString('student_name') ?? prefs.getString('user_name') ?? 'Student');

    final batch = prefs.getString('student_batch') ?? prefs.getString('selected_batch') ?? 'SP26-BCS-1-A';
    final synced = prefs.getBool('portal_synced') ?? prefs.getString('iris_session_student_cookies') != null;

    final savedRoute = prefs.getString('pinned_transport_route') ?? 'Route 4A: Saddar ➔ Campus';

    // Calculate weekly lectures count
    int weeklyLectures = 16;
    if (widget.memory != null) {
      try {
        final batchSessions = widget.memory!.byBatch()[batch] ?? widget.memory!.sessions;
        weeklyLectures = batchSessions.isNotEmpty ? batchSessions.length : 16;
      } catch (_) {}
    }

    // Load Helpdesk transport routes & official semester schedule
    try {
      final helpdesk = HelpdeskScheduleDataService();
      final payload = await helpdesk.fetchSchedulePayload();
      if (payload.transportRoutes.isNotEmpty) {
        _availableRoutes = payload.transportRoutes;
      }
      if (payload.semesterSchedule.isNotEmpty) {
        _semesterEvents = payload.semesterSchedule.map((m) {
          final isExam = m.title.toLowerCase().contains('exam') ||
              m.title.toLowerCase().contains('midterm');
          final isClass = m.title.toLowerCase().contains('class') ||
              m.title.toLowerCase().contains('commence') ||
              m.title.toLowerCase().contains('registration');
          return {
            'title': m.title,
            'date': m.date.isNotEmpty ? m.date : 'Semester Milestone',
            'category': isExam ? 'Exams' : (isClass ? 'Classes' : 'Events'),
            'icon': isExam
                ? Icons.event_note_rounded
                : (isClass ? Icons.school_rounded : Icons.celebration_rounded),
            'color': isExam
                ? const Color(0xFFF59E0B)
                : (isClass ? IrisTokens.brand : const Color(0xFF8B5CF6)),
            'status': m.status.isNotEmpty ? m.status : 'Official',
          };
        }).toList();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _userName = name;
        _userBatch = batch;
        _isPortalSynced = synced;
        _totalLecturesThisWeek = weeklyLectures;
        _pinnedRouteTitle = savedRoute;
        if (synced) {
          _totalAssignments = prefs.getInt('portal_assignments_count') ?? 3;
          _totalQuizzes = prefs.getInt('portal_quizzes_count') ?? 2;
          _overallAttendancePct = prefs.getDouble('portal_attendance_pct') ?? 86.5;
        }
      });
    }
  }

  void _onTapMascot() {
    IrisHaptics.actionHeavy();
    _mascotTapController.forward(from: 0.0);
    setState(() {
      _mascotQuoteIndex = (_mascotQuoteIndex + 1) % _mascotQuotes.length;
    });
  }

  void _openTransportPicker() async {
    IrisHaptics.selectionClick();
    final prefs = await SharedPreferences.getInstance();

    final routesList = _availableRoutes.isNotEmpty
        ? _availableRoutes.map((r) => '${r.route} • ${r.stops.isNotEmpty ? r.stops.first.time : "4:30 PM"}').toList()
        : [
            'Route 4A: Saddar ➔ Campus • Departs 4:30 PM',
            'Route 2B: Faizabad ➔ Campus • Departs 4:30 PM',
            'Route 1A: Rawalpindi ➔ Campus • Departs 4:30 PM',
            'Route 5C: Commercial Market ➔ Campus • Departs 4:30 PM',
          ];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_bus_rounded, color: IrisTokens.brand),
                  const SizedBox(width: 10),
                  Text(
                    'PIN YOUR TRANSPORT ROUTE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...routesList.map((routeStr) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () async {
                      IrisHaptics.actionMedium();
                      await prefs.setString('pinned_transport_route', routeStr);
                      setState(() => _pinnedRouteTitle = routeStr);
                      if (context.mounted) Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: IrisTokens.brand.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              routeStr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          const Icon(Icons.push_pin_rounded, size: 16, color: IrisTokens.brand),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final isWeekend = DateTime.now().weekday == DateTime.daysPerWeek - 1 || DateTime.now().weekday == DateTime.daysPerWeek;
    if (isWeekend) return 'Happy weekend,';
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final textColor = effectiveIsDark ? Colors.white : Colors.black;
    final mutedTextColor = (effectiveIsDark ? Colors.white : Colors.black).withValues(alpha: 0.6);

    final filteredEvents = _selectedEventFilter == 'All'
        ? _semesterEvents
        : _semesterEvents.where((e) => e['category'] == _selectedEventFilter).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        elevation: 0,
        leading: AppBackButton(
          isDark: effectiveIsDark,
          onPressed: widget.onBackPressed,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              IrisHaptics.actionSoft();
              _loadInsightData();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: effectiveIsDark ? const Color(0xFF070A11) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Greeting & Calendar Memory Badge
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()} $_userName!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: IrisTokens.brand.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 12, color: IrisTokens.brand),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Semester Active • Day 266',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: IrisTokens.brand,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Animated Mascot Bento Card (Fluffy 3D Breeno-style companion)
              GestureDetector(
                onTap: _onTapMascot,
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 60 FPS Animated Mascot with Floating Physics & Energy Aura
                      IrisAnimatedMascot(
                        size: 85,
                        onTap: _onTapMascot,
                      ),
                      const SizedBox(width: 14),

                      // Interactive Speech Bubble
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: IrisTokens.brand.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 11, color: IrisTokens.brand),
                                  SizedBox(width: 4),
                                  Text(
                                    'ASK IRIS MASCOT',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: IrisTokens.brand,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _mascotQuotes[_mascotQuoteIndex],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap mascot to get next insight ✦',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: mutedTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Portal Sync Status Alert Banner
              if (!_isPortalSynced)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.sync_problem_rounded, color: Colors.amber, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PORTAL SYNC PENDING',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.amber,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Log in to CUOnline portal to sync live attendance, quizzes, & course tasks.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: mutedTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            IrisHaptics.actionMedium();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PortalScreen(
                                  url: 'https://cuonline.comsats.edu.pk/',
                                  title: 'CUOnline Portal Sync',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text(
                            'SYNC NOW',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Academic Bento Grid Metrics
              Row(
                children: [
                  // Total Assignments & Quizzes Card
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.assignment_turned_in_rounded, size: 18, color: IrisTokens.brand),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: IrisTokens.brand.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'TASKS',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: IrisTokens.brand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_totalAssignments + _totalQuizzes}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          Text(
                            '$_totalAssignments Assignments • $_totalQuizzes Quizzes',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Attendance Overview Card
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF10B981)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ATTENDANCE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_overallAttendancePct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Overall Attendance Health',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Total Lectures This Week & Least Attendance Alert Row
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_view_week_rounded, size: 18, color: IrisTokens.purple),
                              const SizedBox(width: 8),
                              Text(
                                'WEEKLY LECTURES',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: IrisTokens.purple,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$_totalLecturesThisWeek Lectures',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Scheduled for active week',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Least Attendance Warning Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'LOWEST ATTENDANCE WARNING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.redAccent,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_leastAttendancePct.toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _leastAttendanceCourse,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Attend next $_classesNeededFor75Pct classes to restore 75% requirement',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pinned Transport Route Bento Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_bus_rounded, color: IrisTokens.brand, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'PINNED TRANSPORT ROUTE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: IrisTokens.brand,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _openTransportPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: IrisTokens.brand.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.push_pin_rounded, size: 12, color: IrisTokens.brand),
                                SizedBox(width: 4),
                                Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: IrisTokens.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _pinnedRouteTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _pinnedRouteTiming,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Semester Schedule Events Timeline
              Row(
                children: [
                  Text(
                    'SEMESTER TIMELINE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: IrisTokens.brand,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 10),

              // Category Filter Chips
              Wrap(
                spacing: 8,
                children: ['All', 'Classes', 'Exams', 'Events'].map((cat) {
                  final isSelected = _selectedEventFilter == cat;
                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : textColor,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: IrisTokens.brand,
                    backgroundColor: (effectiveIsDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    onSelected: (val) {
                      if (val) {
                        IrisHaptics.selectionClick();
                        setState(() => _selectedEventFilter = cat);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Event List Items
              Column(
                children: filteredEvents.map((event) {
                  final color = event['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(event['icon'] as IconData, color: color, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event['title'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  event['date'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: mutedTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              event['status'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
