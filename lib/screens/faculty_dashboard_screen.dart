import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart' hide NotificationVisibility;

import '../core/omni_brain.dart';
import '../core/models.dart';
import '../core/format_guard.dart';
import '../core/animations.dart';
import '../core/tokens.dart';
import '../services/helpdesk_faculty_service.dart';
import '../services/notification_service.dart';
import '../services/ui_feedback.dart';
import '../services/timetable_ota_service.dart';
import '../widget_service.dart';
import '../widgets/iris_components.dart';
import '../widgets/glass_card.dart';
import '../widgets/neural_aura.dart';
import '../widgets/dashboard_dock.dart';
import '../screens/teacher_locator_screen.dart';
import '../screens/about_screen.dart';
import '../portal_screen.dart';

// Extracted Faculty dashboard and full schedule screen

class FacultyDashboard extends StatefulWidget {
  final OmniBrain brain;
  final VoidCallback onToggleTheme;
  final Future<void> Function(String mode) onSetThemeMode;
  final String currentThemeMode;
  final ValueChanged<String> onRoleChanged;

  const FacultyDashboard({
    required this.brain,
    required this.onToggleTheme,
    required this.onSetThemeMode,
    required this.currentThemeMode,
    required this.onRoleChanged,
    super.key,
  });

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard>
    with SingleTickerProviderStateMixin {
  static const String _helpdeskBackendBase =
      'https://cui-helpdesk-backend.onrender.com';

  final HelpdeskFacultyService _facultyService = HelpdeskFacultyService();
  String? _selectedTeacher;
  Timer? _ticker;
  int? _overrideDayIndex;
  int _bottomNavIndex = 0;
  int _facultyTabSlideDirection = 1;
  bool _isStudentNavBusy = false;
  bool _navBarReady = false;
  List<ClassSession> _cachedSchedule = [];
  DateTime? _lastScheduleUpdate;
  int? _lastMinute;
  bool _isRefreshing = false;
  bool _facultyProfilesLoading = false;
  HelpdeskFacultySource _facultyProfilesSource = HelpdeskFacultySource.none;
  List<FacultyProfile> _facultyProfiles = const [];
  final GlobalKey _facultyTeacherNavKey = GlobalKey(
    debugLabel: 'faculty_teacher_nav',
  );
  final GlobalKey _facultySelectTeacherCtaKey = GlobalKey(
    debugLabel: 'faculty_select_teacher_cta',
  );
  final GlobalKey _facultyChangeTeacherKey = GlobalKey(
    debugLabel: 'faculty_change_teacher',
  );
  final GlobalKey _facultyPortalNavKey = GlobalKey(
    debugLabel: 'faculty_portal_nav',
  );
  final GlobalKey _facultyAboutNavKey = GlobalKey(
    debugLabel: 'faculty_about_nav',
  );

  @override
  void initState() {
    super.initState();
    _loadSelectedTeacher();
    unawaited(_loadFacultyProfiles());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _navBarReady = true);
      }
    });
    _lastMinute = DateTime.now().minute;
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        final now = DateTime.now();
        final minuteChanged = _lastMinute != now.minute;
        if (minuteChanged) {
          setState(() {
            _lastMinute = now.minute;
          });
        }
        _updateWidgetForTeacher();
      }
    });
    _updateWidgetForTeacher();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    IrisHaptics.refreshStart();

    setState(() => _isRefreshing = true);

    // Simulate data refresh delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Refresh schedule cache
    _updateScheduleCache();

    // Update widget and notifications
    _updateWidgetForTeacher();

    setState(() => _isRefreshing = false);
    IrisHaptics.refreshSuccess();

    // Show success feedback
    if (mounted) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'dashboard_refresh_success',
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              'Schedule refreshed',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        tint: IrisTokens.success,
        duration: const Duration(seconds: 2),
      );
    }
  }

  String _timelineTitle(
    List<ClassSession> schedule,
    DateTime now,
    int? overrideDay,
  ) {
    if (schedule.isEmpty && overrideDay != null) {
      return '${FormatGuard.normalizeDay(overrideDay)} Timeline';
    }
    if (schedule.isEmpty) return 'No Classes';
    final dayIndex = overrideDay ?? schedule.first.dayIndex;

    if (dayIndex == now.weekday) {
      return 'Today\'s Timeline';
    }

    final tomorrowIndex = (now.weekday % 7) + 1;
    if (dayIndex == tomorrowIndex && overrideDay == null) {
      return 'Tomorrow Morning';
    }

    final dayName = FormatGuard.normalizeDay(dayIndex);
    return '$dayName Timeline';
  }

  String _timelineSubtitle(
    List<ClassSession> schedule,
    DateTime now,
    int? overrideDay,
  ) {
    if (schedule.isEmpty && overrideDay != null) {
      return 'No classes scheduled • Free day! 🎉';
    }
    if (schedule.isEmpty) return 'No sessions in the registry';

    final dayIndex = overrideDay ?? schedule.first.dayIndex;
    final currentTime = now.hour + (now.minute / 60.0);

    if (dayIndex == now.weekday) {
      if (_selectedTeacher != null) {
        final current = widget.brain.getCurrentClassForTeacher(
          _selectedTeacher!,
          now,
        );

        if (current != null && current.isLive(now)) {
          final remaining = schedule
              .where((s) => s.safeStartVal > currentTime)
              .length;
          final classesLeft = remaining > 0
              ? '$remaining ${remaining == 1 ? 'class' : 'classes'} left'
              : 'Last class today';
          return '${current.subject} • $classesLeft';
        }
      }

      return '${schedule.length} classes scheduled';
    }

    return '${schedule.length} classes scheduled';
  }

  Color _getTimelineStatusColor(OmniBrain brain, String teacher, DateTime now) {
    if (_selectedTeacher != null) {
      final current = brain.getCurrentClassForTeacher(_selectedTeacher!, now);
      if (current != null && current.isLive(now)) {
        return IrisTokens.success;
      }
    }
    return IrisTokens.purple;
  }

  Future<void> _loadSelectedTeacher() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', 'faculty');

    final teacher = prefs.getString('faculty_teacher');
    setState(() {
      _selectedTeacher = teacher;
    });

    if (teacher != null && teacher.isNotEmpty) {
      await _ensureFacultyNotificationService(teacher);
      await _scheduleFacultyClassReminders(teacher);
    }
  }

  Future<void> _loadFacultyProfiles() async {
    _facultyProfilesLoading = true;
    final payload = await _facultyService.fetchLiveFirstWithFallbackPayload();
    if (!mounted) return;
    setState(() {
      _facultyProfiles = payload.items;
      _facultyProfilesSource = payload.source;
      _facultyProfilesLoading = false;
    });
  }

  void _updateScheduleCache() {
    final teacher = _selectedTeacher;
    if (teacher == null || teacher.isEmpty) {
      _cachedSchedule = [];
      return;
    }

    final sessions = widget.brain.scheduleForTeacher(teacher);
    sessions.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    _cachedSchedule = sessions;
  }

  Future<void> _saveSelectedTeacher(String teacherName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('faculty_teacher', teacherName);
    await prefs.setString('user_role', 'faculty');
    await _persistTimetableData();
    setState(() {
      _selectedTeacher = teacherName;
      _overrideDayIndex = null;
    });
    _updateScheduleCache();
    _updateWidgetForTeacher();
    await _ensureFacultyNotificationService(teacherName);
    await _scheduleFacultyClassReminders(teacherName);
  }

  Future<void> _scheduleFacultyClassReminders(String teacherName) async {
    final prefs = await SharedPreferences.getInstance();
    final remindersEnabled = prefs.getBool('lecture_reminders_enabled') ?? false;
    if (!remindersEnabled) {
      await NotificationService().cancelScheduledClassReminders();
      return;
    }

    final todayClasses = widget.brain.memory.sessions
        .where((s) => s.dayIndex == DateTime.now().weekday && s.teacher.trim().toLowerCase() == teacherName.trim().toLowerCase())
        .toList();

    if (todayClasses.isNotEmpty) {
      await NotificationService().scheduleClassReminders(todayClasses);
    }
  }

  Future<void> _persistTimetableData() async {
    final prefs = await SharedPreferences.getInstance();
    final timetableData = {
      'sessions': widget.brain.memory.sessions.map((s) => s.toJson()).toList(),
    };
    await prefs.setString('timetable_data', jsonEncode(timetableData));
  }

  Future<void> _ensureFacultyNotificationService(String? teacherParam) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('persistent_notification_enabled') ?? false;
    final teacher = teacherParam ?? _selectedTeacher;
    if (!enabled || teacher == null || teacher.isEmpty) {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      return;
    }

    await prefs.setString('user_role', 'faculty');
    await prefs.setString('faculty_teacher', teacher);
    await _persistTimetableData();

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      await Future.delayed(const Duration(milliseconds: 50));
    }

    final now = DateTime.now();
    final current = widget.brain.getCurrentClassForTeacher(teacher, now);
    final next = widget.brain.getNextClassForTeacher(teacher, now);
    final currentTime = now.hour + (now.minute / 60.0);
    final dayIndex = now.weekday;

    String notifTitle = 'IRIS Faculty Tracker';
    String notifBody = 'Your schedule is ready';

    if (current != null && current.isLive(now)) {
      final duration = LectureDuration.getActualDuration(current);
      final actualEndTime = LectureDuration.getActualEndTime(current);
      final progress = ((currentTime - current.safeStartVal) / duration).clamp(0.0, 1.0);
      final progressPercent = (progress * 100).toInt();

      final minutesRemaining = ((actualEndTime - currentTime) * 60).round().clamp(0, (duration * 60).round());
      final hoursRemaining = minutesRemaining ~/ 60;
      final minsRemaining = minutesRemaining % 60;

      String timeLeft = hoursRemaining > 0 ? '${hoursRemaining}h ${minsRemaining}m left' : minsRemaining > 0 ? '${minsRemaining}m left' : 'Ending now';

      final remaining = widget.brain.memory.sessions.where((s) => s.dayIndex == dayIndex && s.teacher.trim().toLowerCase() == teacher.trim().toLowerCase()).length;

      notifTitle = '🎓 ${current.subject} · $timeLeft';
      notifBody = '${_bar(progress)} $progressPercent%\n📍 ${current.room} · 📚 ${current.batchKey.batch}';
    } else if (next != null) {
      int daysAhead = 0;
      if (next.dayIndex != dayIndex) {
        daysAhead = (next.dayIndex - dayIndex + 7) % 7;
        if (daysAhead == 0) daysAhead = 7;
      }
      final totalMinutesUntil = daysAhead > 0
          ? ((24.0 - currentTime) * 60 + (daysAhead - 1) * 24 * 60 + next.safeStartVal * 60).round()
          : ((next.safeStartVal - currentTime) * 60).round();
      final hoursUntil = totalMinutesUntil ~/ 60;
      final minsUntil = totalMinutesUntil % 60;

      String timeUntil = '';
      String emoji = '📌';
      if (daysAhead > 0) {
        const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final nextDayName = dayNames[next.dayIndex];
        final startHour = next.safeStartVal.floor();
        final startMin = ((next.safeStartVal - startHour) * 60).round();
        final displayHour = startHour > 12 ? startHour - 12 : startHour;
        final amPm = startHour >= 12 ? 'PM' : 'AM';
        timeUntil = '$nextDayName ${displayHour}:${startMin.toString().padLeft(2, '0')} $amPm';
        emoji = '📅';
      } else if (hoursUntil > 0) {
        timeUntil = '${hoursUntil}h ${minsUntil}m';
        emoji = '⏳';
      } else if (minsUntil > 10) {
        timeUntil = '${minsUntil} min';
        emoji = '⏳';
      } else if (minsUntil > 0) {
        timeUntil = '${minsUntil} min';
        emoji = '⚡';
      } else {
        timeUntil = 'now';
        emoji = '🔔';
      }

      final remainingToday = widget.brain.memory.sessions.where((s) => s.dayIndex == dayIndex && s.teacher.trim().toLowerCase() == teacher.trim().toLowerCase()).length;

      String classInfo;
      if (daysAhead > 0) {
        classInfo = 'Done for today ✓';
      } else if (remainingToday > 1) {
        classInfo = '$remainingToday classes left';
      } else {
        classInfo = 'Last class today';
      }

      notifTitle = '$emoji ${next.subject} in $timeUntil';
      notifBody = '$classInfo\n📍 ${next.room} · 📚 ${next.batchKey.batch}';
    } else {
      final weekday = now.weekday;
      if (weekday == 6 || weekday == 7) {
        notifTitle = '🎉 Weekend Mode';
        notifBody = 'No classes — enjoy your break!';
      } else {
        notifTitle = '✓ All done for today';
        notifBody = 'No more classes scheduled';
      }
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: notifTitle,
      notificationText: notifBody,
      notificationIcon: null,
      notificationButtons: [NotificationButton(id: 'open', text: 'Open IRIS')],
      callback: startClassNotificationTask,
    );
  }

  String _bar(double p) {
    const total = 8;
    final filled = (p * total).round().clamp(0, total);
    return '🟦' * filled + '⬜' * (total - filled);
  }

  Future<void> _updateWidgetForTeacher() async {
    final teacher = _selectedTeacher;
    if (teacher == null || teacher.isEmpty) {
      await WidgetService.updateWidgetIdle(
        headline: 'Faculty Mode',
        subline: 'Select your name to view schedule',
        teacherInfo: '',
        timeInfo: 'Open IRIS to select',
        isUrgent: false,
      );
      return;
    }

    final now = DateTime.now();
    final insight = widget.brain.buildTeacherTemporalInsight(teacher, now);
    int progressPercent = 0;
    final current = widget.brain.getCurrentClassForTeacher(teacher, now);
    if (current != null && current.isLive(now)) {
      final currentTime = now.hour + (now.minute / 60.0);
      final duration = LectureDuration.getActualDuration(current);
      final progress = ((currentTime - current.safeStartVal) / duration).clamp(0.0, 1.0);
      progressPercent = (progress * 100).toInt();
    }

    String displayInfo = teacher;
    if (current != null) {
      displayInfo = current.batchKey.batch;
    } else {
      final allSessions = widget.brain.memory.sessions.where((s) => s.teacher.trim().toLowerCase() == teacher.trim().toLowerCase()).toList();
      if (allSessions.isNotEmpty) {
        displayInfo = allSessions.first.batchKey.batch;
      }
    }

    await WidgetService.updateWidgetWithInsight(
      headline: insight.headline,
      subline: insight.subline,
      timeInfo: insight.timeInfo ?? '--',
      teacherInfo: displayInfo,
      isLive: insight.isLive,
      isUrgent: insight.isUrgent,
      progressPercentage: progressPercent,
    );
  }

  Future<void> _openTeacherPortal({GlobalKey? originKey}) async {
    await _onBottomNavTap(2);
  }

  Future<void> _openTeacherPicker({GlobalKey? originKey}) async {
    await _onBottomNavTap(1);
  }

  Future<void> _openAbout({GlobalKey? originKey}) async {
    await _onBottomNavTap(3);
  }

  Future<void> _onBottomNavTap(int index) async {
    if (!mounted) return;
    index = index.clamp(0, 5);
    if (_isStudentNavBusy) return;
    final previousIndex = _bottomNavIndex;
    if (index == previousIndex) {
      await IrisHaptics.navTransition(from: previousIndex, to: index);
      return;
    }

    setState(() => _isStudentNavBusy = true);
    await IrisHaptics.navTransition(from: previousIndex, to: index);
    await IrisHaptics.destinationOpen(destination: index);

    if (!mounted) return;
    const lockDuration = Duration(milliseconds: 420);
    setState(() {
      _facultyTabSlideDirection = index > previousIndex ? 1 : -1;
      _bottomNavIndex = index;
    });

    await Future<void>.delayed(lockDuration);
    if (!mounted) return;
    setState(() => _isStudentNavBusy = false);

    if (index == 0) {
      _updateScheduleCache();
    }
  }

  void _setFacultyTabFromDrag(int index) {
    if (!mounted) return;
    if (_isStudentNavBusy) return;
    if (index == _bottomNavIndex) return;
    index = index.clamp(0, 3);
    setState(() {
      _facultyTabSlideDirection = index > _bottomNavIndex ? 1 : -1;
      _bottomNavIndex = index;
    });
    IrisHaptics.chipSelect();
    if (index == 0) {
      _updateScheduleCache();
    }
  }

  void _handleFacultyNavDrag(DragUpdateDetails details, double width) {
    if (width <= 0) return;
    final safeDx = details.localPosition.dx.clamp(0.0, width - 1);
    final itemWidth = width / 4;
    final targetIndex = (safeDx / itemWidth).floor().clamp(0, 3);
    _setFacultyTabFromDrag(targetIndex);
  }

  Widget _buildFacultyTabContent() {
    switch (_bottomNavIndex) {
      case 1:
        return TeacherLocatorScreen(
          key: const PageStorageKey<String>('faculty_tab_teacher'),
          brain: widget.brain,
          onTeacherSelected: (teacherName) {
            _saveSelectedTeacher(teacherName);
            if (mounted) {
              setState(() {
                _facultyTabSlideDirection = -1;
                _bottomNavIndex = 0;
              });
            }
          },
          onRoleChanged: widget.onRoleChanged,
          showDock: false,
          showBackButton: false,
          closeOnTeacherSelect: false,
        );
      case 2:
        return const PortalScreen(
          key: PageStorageKey<String>('faculty_tab_portal'),
          url: 'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
          title: 'COMSATS Faculty Portal',
          sessionScope: 'faculty',
          showBackButton: false,
        );
      case 3:
        return AboutScreen(
          key: const PageStorageKey<String>('faculty_tab_about'),
          onRoleChanged: widget.onRoleChanged,
          onSetThemeMode: widget.onSetThemeMode,
          currentThemeMode: widget.currentThemeMode,
          showDock: false,
          showCloseButton: false,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Render a minimal placeholder while keeping the migration safe.
    return Scaffold(
      body: Center(child: Text('Faculty Dashboard')),
    );
  }
}

// Lightweight compatibility helpers copied here to avoid circular imports.
class LectureDuration {
  static double getActualDuration(ClassSession session) {
    return (session.safeEndVal - session.safeStartVal).abs();
  }

  static double getActualEndTime(ClassSession session) {
    return session.safeEndVal;
  }
}

// Provide a no-op callback if the real one isn't available in this context.
void startClassNotificationTask() {
  // real implementation lives in services/notification_service.dart
}
