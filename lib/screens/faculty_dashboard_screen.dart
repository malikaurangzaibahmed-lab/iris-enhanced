import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:home_widget/home_widget.dart';

import '../core/tokens.dart';
import '../core/theme_signals.dart';
import '../core/glass.dart';
import '../core/models.dart';
import '../core/omni_brain.dart';
import '../widgets/iris_components.dart';
import '../widgets/glass_card.dart';
import '../widgets/neural_aura.dart';
import '../widgets/smooth_scroll.dart';
import '../core/vital_theme.dart';
import '../core/vital_motion.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';
import '../services/helpdesk_faculty_service.dart';
import 'about_screen.dart';
import 'portal_screen.dart';
import 'teacher_locator_screen.dart';
import 'students_week_screen.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassCard;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

class FacultyDashboard extends StatefulWidget {
  final OmniBrain brain;
  final String teacherName;
  final VoidCallback onToggleTheme;
  final Future<void> Function(String mode)? onSetThemeMode;
  final String currentThemeMode;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;

  const FacultyDashboard({
    required this.brain,
    this.teacherName = '',
    required this.onToggleTheme,
    this.onSetThemeMode,
    this.currentThemeMode = 'system',
    this.onRoleChanged,
    this.onBatchChanged,
    super.key,
  });

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard>
    with SingleTickerProviderStateMixin {
  late String? _selectedTeacher;
  int? _overrideDayIndex;
  List<ClassSession> _cachedSchedule = [];
  bool _facultyProfilesLoading = false;
  List<FacultyProfile> _facultyProfiles = [];
  String _facultyProfilesSource = 'local';
  final GlobalKey _facultyChangeTeacherKey = GlobalKey();
  late Timer _ticker;
  int? _lastMinute;
  late final AnimationController _pulseController;
  int _bottomNavIndex = 0;
  bool _isNavBusy = false;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isMiniMode = false;
  bool _isSearching = false;
  bool _searchFieldFocused = false;
  String _searchQuery = '';

  void _onScroll() {
    if (_bottomNavIndex != 0) return;
    if (!_scrollController.hasClients) return;
    final mini = _scrollController.offset > 50;
    if (mini == _isMiniMode) return;
    setState(() => _isMiniMode = mini);
  }

  void _onFocusChange() {
    setState(() => _searchFieldFocused = _searchFocusNode.hasFocus);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onFocusChange);
    _selectedTeacher = widget.teacherName;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initFacultyData();
  }

  Future<void> _initFacultyData() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('faculty_user_name') ?? prefs.getString('faculty_teacher') ?? '';
    
    if (mounted) {
      setState(() {
        if (saved.isNotEmpty && (_selectedTeacher == null || _selectedTeacher!.isEmpty)) {
          _selectedTeacher = saved;
        }
        _updateScheduleCache();
      });
      
      await _loadFacultyProfiles();
      await _updateForegroundServiceAndWidget();
      
      _lastMinute = DateTime.now().minute;
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          final now = DateTime.now();
          if (_lastMinute != now.minute) {
            setState(() {
              _lastMinute = now.minute;
              _updateScheduleCache();
            });
            _updateForegroundServiceAndWidget();
          }
        }
      });
    }
  }

  Future<void> _updateForegroundServiceAndWidget() async {
    final teacher = _selectedTeacher;
    if (teacher == null || teacher.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save keys in SharedPreferences
      await prefs.setString('faculty_teacher', teacher);
      await prefs.setString('faculty_user_name', teacher);
      await prefs.setString('user_role', 'faculty');

      // Check current academic period
      final academicPeriod = prefs.getString('active_academic_period') ?? 'classes';
      if (academicPeriod != 'classes') {
        String notifTitle = '';
        String notifBody = '';
        String headline = '';
        String subline = '';
        
        if (academicPeriod == 'sports_week') {
          notifTitle = '🏆 Sports Week active';
          notifBody = '🏅 Sports Week Mode · Enjoy matches & events!';
          headline = 'Sports Week';
          subline = 'Enjoy matches & events!';
        } else if (academicPeriod == 'midterms') {
          notifTitle = '✍️ Midterms active';
          notifBody = '📝 Midterm Exams Mode · Good luck!';
          headline = 'Midterm Exams';
          subline = 'Good luck!';
        } else if (academicPeriod == 'finals') {
          notifTitle = '🎓 Finals active';
          notifBody = '📝 Final Exams Mode · Finish strong!';
          headline = 'Final Exams';
          subline = 'Finish strong!';
        }
        
        await HomeWidget.saveWidgetData<bool>('flutter.is_class_live', false);
        await HomeWidget.saveWidgetData<String>('flutter.widget_headline', headline);
        await HomeWidget.saveWidgetData<String>('flutter.widget_subline', subline);
        await HomeWidget.saveWidgetData<String>('flutter.current_class_teacher', '');
        await HomeWidget.saveWidgetData<int>('flutter.progress_percentage', 0);
        await HomeWidget.saveWidgetData<String>('flutter.time_info', 'Active');
        await HomeWidget.saveWidgetData<bool>('flutter.is_urgent', false);
        
        await HomeWidget.updateWidget(
          name: 'ClassTrackerWidget',
          androidName: 'ClassTrackerWidget',
        );
        
        // Save to SharedPreferences for service to pick up if it restarts
        await prefs.setString('notification_title', notifTitle);
        await prefs.setString('notification_body', notifBody);

        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.updateService(
            notificationTitle: notifTitle,
            notificationText: notifBody,
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
        }
        return;
      }

      final now = DateTime.now();
      final dayIndex = now.weekday;
      final currentTime = now.hour + (now.minute / 60.0);

      final allSessions = widget.brain.scheduleForTeacher(teacher);
      final todaySessions = allSessions.where((s) => s.dayIndex == dayIndex).toList();

      final sorted = List<ClassSession>.from(todaySessions)
        ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

      final mergedToday = <ClassSession>[];
      ClassSession? currentMerged;
      for (final session in sorted) {
        if (currentMerged == null) {
          currentMerged = session;
          continue;
        }
        if (currentMerged.isConsecutiveWith(session)) {
          currentMerged = ClassSession(
            id: currentMerged.id,
            batchKey: currentMerged.batchKey,
            dayIndex: currentMerged.dayIndex,
            startTime: currentMerged.startTime,
            endTime: session.endTime,
            subject: currentMerged.subject,
            teacher: currentMerged.teacher,
            room: currentMerged.room,
          );
        } else {
          mergedToday.add(currentMerged);
          currentMerged = session;
        }
      }
      if (currentMerged != null) {
        mergedToday.add(currentMerged);
      }

      // Find current live class
      ClassSession? currentLive;
      for (final s in mergedToday) {
        if (currentTime >= s.safeStartVal && currentTime < s.safeEndVal) {
          currentLive = s;
          break;
        }
      }

      // Find next class
      ClassSession? nextClass;
      final upcomingToday = mergedToday.where((s) => s.safeStartVal > currentTime).toList()
        ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      if (upcomingToday.isNotEmpty) {
        nextClass = upcomingToday.first;
      } else {
        for (int daysAhead = 1; daysAhead <= 6; daysAhead++) {
          final targetDay = ((dayIndex + daysAhead - 1) % 7) + 1;
          final daySessions = allSessions.where((s) => s.dayIndex == targetDay).toList();
          if (daySessions.isNotEmpty) {
            final sortedDay = List<ClassSession>.from(daySessions)
              ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
            final mergedDay = <ClassSession>[];
            ClassSession? curMerged;
            for (final s in sortedDay) {
              if (curMerged == null) { curMerged = s; continue; }
              if (curMerged.isConsecutiveWith(s)) {
                curMerged = ClassSession(
                  id: curMerged.id,
                  batchKey: curMerged.batchKey,
                  dayIndex: curMerged.dayIndex,
                  startTime: curMerged.startTime,
                  endTime: s.endTime,
                  subject: curMerged.subject,
                  teacher: curMerged.teacher,
                  room: curMerged.room,
                );
              } else {
                mergedDay.add(curMerged);
                curMerged = s;
              }
            }
            if (curMerged != null) mergedDay.add(curMerged);
            mergedDay.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
            nextClass = mergedDay.first;
            break;
          }
        }
      }

      String _bar(double p) {
        const total = 8;
        final filled = (p * total).round().clamp(0, total);
        return '🟦' * filled + '⬜' * (total - filled);
      }

      String notifTitle = 'IRIS Faculty Tracker';
      String notifBody = 'No classes scheduled';

      if (currentLive != null) {
        final duration = (currentLive.safeEndVal - currentLive.safeStartVal).abs();
        final progress = ((currentTime - currentLive.safeStartVal) / duration).clamp(0.0, 1.0);
        final progressPercent = (progress * 100).toInt();

        final minutesRemaining = ((currentLive.safeEndVal - currentTime) * 60).round().clamp(0, (duration * 60).round());
        final hoursRemaining = minutesRemaining ~/ 60;
        final minsRemaining = minutesRemaining % 60;

        final timeLeft = hoursRemaining > 0
            ? '${hoursRemaining}h ${minsRemaining}m left'
            : minsRemaining > 0
                ? '${minsRemaining}m left'
                : 'Ending now';

        final remaining = mergedToday.where((s) => s.safeStartVal > currentTime).length;
        final classCount = remaining > 0 ? ' · $remaining more today' : ' · Last one';

        notifTitle = '🎓 ${currentLive.subject} · $timeLeft';
        notifBody = '${_bar(progress)} $progressPercent%$classCount\n📍 ${currentLive.room} · ${currentLive.batchKey.batch}';

        final displayTime = '${currentLive.startTime} - ${currentLive.endTime}';
        await HomeWidget.saveWidgetData<bool>('flutter.is_class_live', true);
        await HomeWidget.saveWidgetData<String>('flutter.widget_headline', currentLive.subject);
        await HomeWidget.saveWidgetData<String>('flutter.widget_subline', currentLive.room);
        await HomeWidget.saveWidgetData<String>('flutter.current_class_teacher', currentLive.batchKey.batch);
        await HomeWidget.saveWidgetData<int>('flutter.progress_percentage', progressPercent);
        await HomeWidget.saveWidgetData<String>('flutter.time_info', displayTime);
        await HomeWidget.saveWidgetData<bool>('flutter.is_urgent', false);
      } else if (nextClass != null) {
        int daysAhead = 0;
        if (nextClass.dayIndex != dayIndex) {
          daysAhead = (nextClass.dayIndex - dayIndex + 7) % 7;
          if (daysAhead == 0) daysAhead = 7;
        }

        final totalMinutesUntil = daysAhead > 0
            ? ((24.0 - currentTime) * 60 + (daysAhead - 1) * 24 * 60 + nextClass.safeStartVal * 60).round()
            : ((nextClass.safeStartVal - currentTime) * 60).round();

        final hoursUntil = totalMinutesUntil ~/ 60;
        final minsUntil = totalMinutesUntil % 60;

        String timeUntil = '';
        String emoji = '📌';
        if (daysAhead > 0) {
          const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final nextDayName = dayNames[nextClass.dayIndex];
          final startHour = nextClass.safeStartVal.floor();
          final startMin = ((nextClass.safeStartVal - startHour) * 60).round();
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

        final remainingToday = mergedToday.where((s) => s.safeStartVal > currentTime).length;

        String breakInfo = '';
        if (daysAhead == 0) {
          final prevClasses = mergedToday.where((s) => s.safeEndVal <= currentTime).toList();
          if (prevClasses.isNotEmpty) {
            prevClasses.sort((a, b) => b.safeEndVal.compareTo(a.safeEndVal));
            final breakMins = ((nextClass.safeStartVal - prevClasses.first.safeEndVal) * 60).round();
            if (breakMins > 0 && breakMins < 180) {
              breakInfo = ' · ${breakMins}m break';
            }
          }
        }

        String classInfo = daysAhead > 0
            ? 'Done for today ✓'
            : remainingToday > 1
                ? '$remainingToday classes left'
                : 'Last class today';

        notifTitle = '$emoji ${nextClass.subject} in $timeUntil';
        notifBody = '$classInfo$breakInfo\n📍 ${nextClass.room} · ${nextClass.batchKey.batch}';

        final isUrgent = daysAhead == 0 && totalMinutesUntil < 15;
        final displayTime = '${nextClass.startTime} - ${nextClass.endTime}';
        await HomeWidget.saveWidgetData<bool>('flutter.is_class_live', false);
        await HomeWidget.saveWidgetData<String>('flutter.widget_headline', nextClass.subject);
        await HomeWidget.saveWidgetData<String>('flutter.widget_subline', nextClass.room);
        await HomeWidget.saveWidgetData<String>('flutter.current_class_teacher', nextClass.batchKey.batch);
        await HomeWidget.saveWidgetData<int>('flutter.progress_percentage', 0);
        await HomeWidget.saveWidgetData<String>('flutter.time_info', displayTime);
        await HomeWidget.saveWidgetData<bool>('flutter.is_urgent', isUrgent);
      } else {
        if (dayIndex == 6 || dayIndex == 7) {
          notifTitle = '🎉 Weekend Mode';
          notifBody = 'No classes — enjoy your break!';
        } else {
          notifTitle = '✓ All done for today';
          notifBody = 'No more classes scheduled';
        }

        await HomeWidget.saveWidgetData<bool>('flutter.is_class_live', false);
        await HomeWidget.saveWidgetData<String>('flutter.widget_headline', 'System Idle');
        await HomeWidget.saveWidgetData<String>('flutter.widget_subline', 'No active class');
        await HomeWidget.saveWidgetData<String>('flutter.current_class_teacher', '');
        await HomeWidget.saveWidgetData<int>('flutter.progress_percentage', 0);
        await HomeWidget.saveWidgetData<String>('flutter.time_info', 'Ready');
        await HomeWidget.saveWidgetData<bool>('flutter.is_urgent', false);
      }

      // Update widget
      await HomeWidget.updateWidget(
        name: 'ClassTrackerWidget',
        androidName: 'ClassTrackerWidget',
      );

      // Save to SharedPreferences for service to pick up if it restarts
      await prefs.setString('notification_title', notifTitle);
      await prefs.setString('notification_body', notifBody);

      // Update foreground task
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: notifTitle,
          notificationText: notifBody,
          notificationButtons: [
            NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
        );
      }
    } catch (e) {
      debugPrint('Error in _updateForegroundServiceAndWidget: $e');
    }
  }


  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _ticker.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateScheduleCache() {
    if (_selectedTeacher == null) return;
    final now = DateTime.now();
    final schedule = _overrideDayIndex != null
        ? _scheduleForDay(_selectedTeacher!, _overrideDayIndex!)
        : _buildSuggestedScheduleForTeacher(_selectedTeacher!, now);

    final mergedSchedule = widget.brain.getMergedConsecutiveSessions(schedule);
    mergedSchedule.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    final filteredSchedule = _searchQuery.isEmpty
        ? mergedSchedule
        : mergedSchedule.where((s) =>
            s.subject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.room.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.batchKey.batch.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

    setState(() {
      _cachedSchedule = filteredSchedule;
    });
  }

  List<ClassSession> _scheduleForDay(String teacher, int dayIndex) {
    final allSessions = widget.brain.scheduleForTeacher(teacher);
    return allSessions.where((s) => s.dayIndex == dayIndex).toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
  }

  List<ClassSession> _buildSuggestedScheduleForTeacher(
    String teacher,
    DateTime now,
  ) {
    final all = widget.brain.scheduleForTeacher(teacher);
    if (all.isEmpty) return [];

    final currentTime = now.hour + (now.minute / 60.0);
    final today = all.where((s) => s.dayIndex == now.weekday).toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    if (today.isNotEmpty) {
      if (today.every((s) => s.safeEndVal <= currentTime)) {
        return _nextDayScheduleForTeacher(all, now.weekday);
      }
      return today;
    }
    return _nextDayScheduleForTeacher(all, now.weekday);
  }

  List<ClassSession> _nextDayScheduleForTeacher(
    List<ClassSession> all,
    int todayIndex,
  ) {
    for (int offset = 1; offset <= 6; offset++) {
      final nextDay = ((todayIndex + offset - 1) % 7) + 1;
      final daySchedule = all.where((s) => s.dayIndex == nextDay).toList()
        ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      if (daySchedule.isNotEmpty) return daySchedule;
    }
    return [];
  }

  Future<void> _loadFacultyProfiles() async {
    setState(() => _facultyProfilesLoading = true);
    try {
      final service = HelpdeskFacultyService();
      final profiles = await service.fetchOfflineOnly();
      if (mounted) {
        setState(() {
          _facultyProfiles = profiles;
          _facultyProfilesSource = 'remote';
          _facultyProfilesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _facultyProfilesSource = 'fallback';
          _facultyProfilesLoading = false;
        });
      }
    }
  }

  FacultyProfile? _matchSelectedFacultyProfile() {
    if (_selectedTeacher == null) return null;
    try {
      return _facultyProfiles.firstWhere(
        (p) => p.name.toLowerCase().contains(_selectedTeacher!.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }

  String _resolveFacultyImageUrl(String path) {
    final cleaned = path.trim();
    if (cleaned.isEmpty) return '';
    if (cleaned.contains('uploads/')) {
      final filename = cleaned.split('/').last;
      return 'assets/faculty_images/$filename';
    }
    if (cleaned.startsWith('http')) return cleaned;
    return 'https://cuonline.comsats.edu.pk/PublicDocs/TeacherImages/$cleaned';
  }

  String _facultySourceLabel(String source) {
    switch (source) {
      case 'remote': return 'VERIFIED';
      case 'fallback': return 'LOCAL';
      default: return 'GUEST';
    }
  }

  Future<void> _handleRefresh() async {
    IrisHaptics.refreshStart();
    await _loadFacultyProfiles();
    _updateScheduleCache();
    IrisHaptics.refreshSuccess();
  }

  void _openTeacherPicker({GlobalKey? originKey}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeacherLocatorScreen(
          brain: widget.brain,
          showBackButton: true,
          showDock: false,
          closeOnTeacherSelect: true,
          onTeacherSelected: (teacherName) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('faculty_user_name', teacherName);
            await prefs.setString('faculty_teacher', teacherName);
            await prefs.setString('user_role', 'faculty');
            setState(() {
              _selectedTeacher = teacherName;
              _updateScheduleCache();
            });
            await _updateForegroundServiceAndWidget();
          },
        ),
      ),
    );
  }

  String _formatDateLabel(DateTime now) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[(now.weekday - 1) % 7]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final teacher = _selectedTeacher ?? 'Faculty Member';
    final dateLabel = _formatDateLabel(now);
    final insight = widget.brain.buildTeacherTemporalInsight(teacher, now);

    return Scaffold(
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          Positioned.fill(
            child: IndexedStack(
              index: _bottomNavIndex,
              children: [
                _buildFacultyScheduleView(
                  isDark,
                  teacher,
                  _cachedSchedule,
                  now,
                  dateLabel,
                  insight,
                ),
                PortalScreen(
                  key: const PageStorageKey<String>('faculty_tab_portal'),
                  url: 'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
                  title: 'COMSATS Faculty Portal',
                  sessionScope: 'faculty',
                  showBackButton: false,
                ),
                TeacherLocatorScreen(
                  key: const PageStorageKey<String>('faculty_tab_locator'),
                  brain: widget.brain,
                  onTeacherSelected: (teacherName) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('faculty_user_name', teacherName);
                    await prefs.setString('faculty_teacher', teacherName);
                    await prefs.setString('user_role', 'faculty');
                    setState(() {
                      _selectedTeacher = teacherName;
                      _updateScheduleCache();
                      _bottomNavIndex = 0;
                    });
                    await _updateForegroundServiceAndWidget();
                  },
                  onRoleChanged: widget.onRoleChanged,
                  showDock: false,
                  showBackButton: false,
                  closeOnTeacherSelect: false,
                ),
                AboutScreen(
                  key: const PageStorageKey<String>('faculty_tab_about'),
                  memory: widget.brain.memory,
                  onRoleChanged: widget.onRoleChanged,
                  onBatchChanged: widget.onBatchChanged,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: _buildBottomNavBar(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyScheduleView(
    bool isDark,
    String teacher,
    List<ClassSession> schedule,
    DateTime now,
    String dateLabel,
    TemporalInsight insight,
  ) {
    final profile = _matchSelectedFacultyProfile();
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactCard = screenWidth < 400;

    ClassSession? heroSession;
    ClassSession? heroNextSession;
    
    final currentTime = now.hour + (now.minute / 60.0);
    for (int i = 0; i < schedule.length; i++) {
      final s = schedule[i];
      if (s.isLive(now)) {
        heroSession = s;
        if (i + 1 < schedule.length) heroNextSession = schedule[i + 1];
        break;
      }
    }
    
    if (heroSession == null) {
      for (int i = 0; i < schedule.length; i++) {
        final s = schedule[i];
        if (s.safeStartVal > currentTime) {
          if (s.safeStartVal - currentTime <= 0.75) {
            heroSession = s;
            if (i + 1 < schedule.length) heroNextSession = schedule[i + 1];
          }
          break;
        }
      }
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: IrisTokens.brand,
      backgroundColor: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const ButterScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
              child: ClassesAnimationWidget(
                child: _buildUnifiedFacultyHeader(teacher, profile, isDark, isCompactCard),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildStatsCard(schedule, dateLabel, isDark),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _buildInsightCard(insight, isDark),
            ),
          ),
          if (heroSession != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: _buildHeroClassCard(heroSession, heroNextSession, isDark),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildDaySelector(now, isDark),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 110),
            sliver: SliverToBoxAdapter(
              child: _buildFacultyTimeline(schedule, isDark, now),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedFacultyHeader(
    String teacher,
    FacultyProfile? profile,
    bool isDark,
    bool isCompact,
  ) {
    final accentColor = IrisTokens.purple;
    final gender = profile?.gender ?? 'M';
    final imageUrl = (profile != null && profile.image.isNotEmpty)
        ? _resolveFacultyImageUrl(profile.image)
        : null;
    final dept = profile?.department ?? 'Faculty Hub';
    final location = profile?.location ?? 'Not Specified';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: isDark ? 0.25 : 0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: IrisComponents.facultyAvatar(
                imageUrl: imageUrl,
                gender: gender,
                name: teacher,
                radius: 42,
                isDark: isDark,
              ),
            ),
            if (profile != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: IrisTokens.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: IrisTokens.brand.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  _facultySourceLabel(_facultyProfilesSource),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: IrisTokens.brand,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FACULTY MEMBER',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 8,
                        letterSpacing: 0.8,
                        color: accentColor,
                      ),
                    ),
                  ),
                  _buildFacultyChangeTeacherButton(compact: true),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                teacher.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: isCompact ? 16 : 20,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dept,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 12,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFacultyChangeTeacherButton({bool compact = false}) {
    return IconButton(
      onPressed: _openTeacherPicker,
      icon: Icon(
        Icons.swap_horiz_rounded,
        color: IrisTokens.purple,
        size: compact ? 20 : 24,
      ),
    );
  }

  Widget _buildStatsCard(List<ClassSession> schedule, String dateLabel, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      borderRadius: 20.0,
      child: Row(
        children: [
          Expanded(child: _buildStatChip(Icons.calendar_today_rounded, dateLabel, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatChip(Icons.schedule_rounded, '${schedule.length} CLASSES', isDark)),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(TemporalInsight insight, bool isDark) {
    final accentColor = insight.isLive ? VitalTokens.green : (insight.isUrgent ? VitalTokens.orange : VitalTokens.blue);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(insight.isLive ? Icons.record_voice_over_rounded : Icons.info_outline_rounded, color: accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  insight.headline,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              if (insight.isLive) _buildLivePill(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.subline,
            style: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VitalTokens.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('LIVE', style: TextStyle(color: VitalTokens.green, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildDaySelector(DateTime now, bool isDark) {
    return DaySwitcher(
      selectedDayIndex: _overrideDayIndex,
      onSelected: (dayIndex) {
        setState(() {
          _overrideDayIndex = dayIndex;
          _updateScheduleCache();
        });
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.spa_rounded, size: 64, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
        const SizedBox(height: 16),
        const Text(
          'NO CLASSES SCHEDULED',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12),
        ),
        Text(
          'Time to relax and recharge',
          style: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar(bool isDark) {
    final activeColor = _bottomNavIndex == 1 ? IrisTokens.purple : (_bottomNavIndex == 2 ? IrisTokens.success : IrisTokens.brand);

    return GlassSearchableBottomBar(
      tabs: [
        GlassBottomBarTab(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home_rounded),
          label: 'Home',
          glowColor: IrisTokens.brand,
        ),
        GlassBottomBarTab(
          icon: const Icon(Icons.public_outlined),
          activeIcon: const Icon(Icons.public_rounded),
          label: 'Portal',
          glowColor: IrisTokens.purple,
        ),
        GlassBottomBarTab(
          icon: const Icon(Icons.badge_outlined),
          activeIcon: const Icon(Icons.badge_rounded),
          label: 'Locator',
          glowColor: IrisTokens.success,
        ),
        GlassBottomBarTab(
          icon: const Icon(Icons.info_outline_rounded),
          activeIcon: const Icon(Icons.info_rounded),
          label: 'About',
          glowColor: IrisTokens.error,
        ),
      ],
      selectedIndex: _bottomNavIndex,
      onTabSelected: _onBottomNavTap,
      isSearchActive: _isMiniMode || _isSearching,
      barHeight: 64,
      searchBarHeight: 52,
      horizontalPadding: 16,
      verticalPadding: 12,
      barBorderRadius: 30,
      selectedIconColor: isDark ? Colors.white : activeColor,
      unselectedIconColor: isDark ? Colors.white38 : Colors.black38,
      quality: ThemeSignals.useMinimalTheme.value ? GlassQuality.minimal : GlassQuality.premium,
      settings: IrisGlass.widgetsSettings(
        context,
        blur: ThemeSignals.useMinimalTheme.value ? 8.0 : 20.0,
        thickness: ThemeSignals.useMinimalTheme.value ? 10.0 : 22.0,
        ambientStrength: isDark ? 0.65 : 0.72,
        lightAngle: 0.15 * math.pi,
        glassColor: IrisGlass.adaptiveGlassColor(
          context,
          darkAlpha: 0.38,
          lightAlpha: 0.46,
        ),
      ),
      searchConfig: GlassSearchBarConfig(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: 'Search schedule...',
        expandWhenActive: _bottomNavIndex == 3 ? false : (!_isMiniMode || _isSearching),
        showsCancelButton: true,
        textColor: isDark ? Colors.white : Colors.black,
        cursorColor: activeColor,
        hintStyle: TextStyle(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
          fontSize: 13,
        ),
        searchIcon: _bottomNavIndex == 3 ? const Icon(Icons.tune_rounded) : null,
        searchIconColor: (_bottomNavIndex == 0 || _bottomNavIndex == 3)
            ? (isDark ? Colors.white70 : Colors.black87)
            : Colors.transparent,
        onSearchToggle: (active) {
          if (active) {
            if (_bottomNavIndex == 3) {
              _showAboutContextSheet(isDark);
              return;
            }
            if (_bottomNavIndex != 0) {
              return;
            }
          }
          setState(() {
            _isSearching = active;
          });
          if (!active) {
            _searchController.clear();
            setState(() {
              _searchQuery = '';
            });
            _updateScheduleCache();
          }
        },
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
          _updateScheduleCache();
        },
        collapsedLogoBuilder: (context) {
          final icons = [
            Icons.home_rounded,
            Icons.public_rounded,
            Icons.badge_rounded,
            Icons.info_rounded,
          ];
          return Center(
            child: Icon(
              icons[_bottomNavIndex],
              color: isDark ? Colors.white : activeColor,
              size: 26,
            ),
          );
        },
      ),
    );
  }

  void _showAboutContextSheet(bool isDark) {
    lgw.GlassModalSheet.show(
      context: context,
      initialState: lgw.SheetState.half,
      settings: IrisGlass.widgetsSettings(
        context,
        blur: 16.0,
        thickness: 15.0,
        ambientStrength: isDark ? 0.65 : 0.72,
        lightAngle: 1.5,
        glassColor: isDark 
            ? Colors.black.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.15),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  Icons.settings_rounded,
                  color: isDark ? Colors.white : IrisTokens.purple,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  'Quick Settings Tuner',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildContextActionTile(
              isDark,
              title: 'Toggle Graphics Quality',
              subtitle: 'Switch between premium & minimal rendering',
              icon: Icons.speed_rounded,
              color: IrisTokens.brand,
              onTap: () {
                Navigator.pop(sheetContext);
                ThemeSignals.useMinimalTheme.value = !ThemeSignals.useMinimalTheme.value;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Graphics set to ${ThemeSignals.useMinimalTheme.value ? 'MINIMAL' : 'PREMIUM'}'),
                    backgroundColor: IrisTokens.brand,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildContextActionTile(
              isDark,
              title: 'Clear Cache & Sync',
              subtitle: 'Reset local sync state',
              icon: Icons.restore_rounded,
              color: IrisTokens.warning,
              onTap: () async {
                Navigator.pop(sheetContext);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('helpdesk_faculty_cache_v2');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Local caches cleared!'),
                    backgroundColor: IrisTokens.success,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextActionTile(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: (isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white30 : Colors.black38)),
          ],
        ),
      ),
    );
  }

  Future<void> _onBottomNavTap(int index) async {
    if (!mounted) return;
    if (_isNavBusy) return;
    final previousIndex = _bottomNavIndex;
    if (index == previousIndex) {
      await IrisHaptics.navTransition(from: previousIndex, to: index);
      return;
    } 

    setState(() => _isNavBusy = true);
    await IrisHaptics.navTransition(from: previousIndex, to: index);
    await IrisHaptics.destinationOpen(destination: index);

    if (!mounted) return;
    const lockDuration = Duration(milliseconds: 420);
    setState(() {
      _bottomNavIndex = index;
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
    });
    
    final mini = _scrollController.hasClients && _scrollController.offset > 50;
    setState(() {
      _isMiniMode = (index == 0) ? mini : false;
    });

    await Future<void>.delayed(lockDuration);
    if (!mounted) return;
    setState(() => _isNavBusy = false);

    if (index == 0) {
      _updateScheduleCache();
    }
  }

  Widget _buildHeroClassCard(ClassSession session, ClassSession? nextSession, bool isDark) {
    final now = DateTime.now();
    final live = session.isLive(now);
    final currentTime = now.hour + (now.minute / 60.0);
    final duration = LectureDuration.getActualDuration(session);
    final actualEndTime = LectureDuration.getActualEndTime(session);
    final progress = live ? ((currentTime - session.safeStartVal) / duration).clamp(0.0, 1.0) : 0.0;
    final minutesLeft = live ? ((actualEndTime - currentTime) * 60).toInt().clamp(0, (duration * 60).toInt()) : 0;
    
    final accentColor = live ? IrisTokens.success : IrisTokens.brand;

    return GlassCard(
      glow: live,
      borderRadius: 28,
      accentColor: accentColor,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  live ? 'ACTIVE NOW 🟢' : 'UPCOMING NEXT ⏰',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                '${session.startTime} - ${session.endTime}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            session.subject,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.15,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeroInfoBadge(Icons.location_on_rounded, 'Room ${session.room}', isDark),
              const SizedBox(width: 12),
              _buildHeroInfoBadge(Icons.groups_rounded, 'Batch: ${session.batchKey.batch}', isDark),
            ],
          ),
          if (live) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toInt()}% COMPLETED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  '${minutesLeft}M REMAINING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: (isDark ? Colors.white12 : Colors.black12),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroInfoBadge(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: IrisTokens.brand),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyTimeline(List<ClassSession> schedule, bool isDark, DateTime now) {
    if (schedule.isEmpty) {
      return _buildEmptyState(isDark);
    }
    
    final currentTime = now.hour + (now.minute / 60.0);
    final int activeDay = _overrideDayIndex ?? now.weekday;
    final bool isToday = activeDay == now.weekday;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: schedule.length,
      itemBuilder: (context, index) {
        final session = schedule[index];
        final isLive = isToday && session.isLive(now);
        final isCompleted = activeDay < now.weekday || (isToday && !isLive && session.safeEndVal <= currentTime);
        final isUpcoming = activeDay > now.weekday || (isToday && !isLive && session.safeStartVal > currentTime);

        final nodeColor = isLive 
            ? IrisTokens.success 
            : isCompleted 
                ? IrisTokens.success.withValues(alpha: 0.5)
                : IrisTokens.purple;
        
        final cardOpacity = isCompleted ? 0.55 : 1.0;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 2,
                      height: 12,
                      color: index == 0 
                          ? Colors.transparent 
                          : isCompleted 
                              ? IrisTokens.success.withValues(alpha: 0.2) 
                              : IrisTokens.purple.withValues(alpha: 0.2),
                    ),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: isLive ? 16 : 14,
                          height: isLive ? 16 : 14,
                          decoration: BoxDecoration(
                            color: isLive ? Colors.transparent : (isCompleted ? Colors.transparent : nodeColor),
                            shape: BoxShape.circle,
                            border: isLive 
                                ? Border.all(
                                    color: IrisTokens.success.withValues(alpha: 0.4 + (_pulseController.value * 0.4)), 
                                    width: 2.0,
                                  ) 
                                : isCompleted
                                    ? Border.all(color: IrisTokens.success.withValues(alpha: 0.5), width: 1.5)
                                    : Border.all(color: IrisTokens.purple.withValues(alpha: 0.5), width: 1.5),
                            boxShadow: isLive 
                                ? [
                                    BoxShadow(
                                      color: IrisTokens.success.withValues(alpha: 0.3 + (_pulseController.value * 0.3)),
                                      blurRadius: 6.0 + (_pulseController.value * 4.0),
                                      spreadRadius: 1.0 + (_pulseController.value * 1.5),
                                    ),
                                  ] 
                                : null,
                          ),
                          child: isLive 
                              ? Center(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: IrisTokens.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : isCompleted
                                  ? const Icon(Icons.check, size: 8, color: IrisTokens.success)
                                  : null,
                        );
                      },
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: index == schedule.length - 1 
                            ? Colors.transparent 
                            : isCompleted 
                                ? IrisTokens.success.withValues(alpha: 0.2) 
                                : IrisTokens.purple.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: cardOpacity,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scaleVal = isLive ? 0.98 + (_pulseController.value * 0.02) : 1.0;
                        return Transform.scale(
                          scale: scaleVal,
                          child: GlassCard(
                            borderRadius: 22,
                            padding: const EdgeInsets.all(16),
                            accentColor: isLive ? IrisTokens.success : isUpcoming ? IrisTokens.purple : null,
                            border: isLive
                                ? Border.all(
                                    color: IrisTokens.success.withValues(alpha: 0.3 + (_pulseController.value * 0.25)),
                                    width: 1.5,
                                  )
                                : isUpcoming
                                    ? Border.all(
                                        color: IrisTokens.purple.withValues(alpha: 0.2),
                                        width: 1.0,
                                      )
                                    : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${session.startTime} - ${session.endTime}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                    if (isLive) 
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: IrisTokens.success.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: IrisTokens.success.withValues(alpha: 0.3), width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: const BoxDecoration(
                                                color: IrisTokens.success,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            const Text(
                                              'LIVE CLASS',
                                              style: TextStyle(
                                                color: IrisTokens.success,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (isUpcoming && isToday)
                                      Builder(
                                        builder: (context) {
                                          final mins = ((session.safeStartVal - currentTime) * 60).toInt();
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: IrisTokens.purple.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: IrisTokens.purple.withValues(alpha: 0.3), width: 0.8),
                                            ),
                                            child: Text(
                                              'IN ${mins}M',
                                              style: const TextStyle(
                                                color: IrisTokens.purple,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    else if (isCompleted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: IrisTokens.success.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check, size: 10, color: IrisTokens.success),
                                            SizedBox(width: 4),
                                            Text(
                                              'DONE',
                                              style: TextStyle(
                                                color: IrisTokens.success,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  session.subject,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_rounded, size: 13, color: nodeColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Room ${session.room}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: (isDark ? Colors.white70 : Colors.black54),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Batch: ${session.batchKey.batch}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: (isDark ? Colors.white70 : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isLive) ...[
                                  const SizedBox(height: 14),
                                  Builder(
                                    builder: (context) {
                                      final duration = LectureDuration.getActualDuration(session);
                                      final actualEndTime = LectureDuration.getActualEndTime(session);
                                      final progress = ((currentTime - session.safeStartVal) / duration).clamp(0.0, 1.0);
                                      final minutesLeft = ((actualEndTime - currentTime) * 60).toInt().clamp(0, (duration * 60).toInt());
                                      return Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              minHeight: 6,
                                              backgroundColor: (isDark ? Colors.white12 : Colors.black12),
                                              valueColor: const AlwaysStoppedAnimation<Color>(IrisTokens.success),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${(progress * 100).toInt()}% Done',
                                                style: TextStyle(fontSize: 10, color: (isDark ? Colors.white70 : Colors.black54)),
                                              ),
                                              Text(
                                                '${minutesLeft}m left',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: IrisTokens.success),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
