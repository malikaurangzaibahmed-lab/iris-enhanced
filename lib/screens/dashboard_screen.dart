import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/tokens.dart';
import '../core/animations.dart';
import '../core/theme_signals.dart';
import '../core/models.dart';
import '../core/omni_brain.dart';
import '../core/university_memory.dart';
import '../core/format_guard.dart';
import '../widgets/iris_components.dart';
import '../widgets/glass_card.dart';
import '../widgets/vital_card.dart';
import '../widgets/vital_progress.dart';
import '../widgets/neural_aura.dart';
import '../widgets/smooth_scroll.dart';
import '../widgets/portal_sync_card.dart';
import '../core/vital_theme.dart';
import '../core/vital_motion.dart';
import '../services/notification_service.dart';
import '../services/helpdesk_faculty_service.dart';
import '../services/helpdesk_campus_feed_service.dart';
import '../services/helpdesk_schedule_data_service.dart';
import '../services/ui_feedback.dart';
import '../widget_service.dart';
import '../portal_screen.dart';
import 'about_screen.dart';
import 'room_finder_screen.dart';

import 'teacher_locator_screen.dart';
import 'makeup_lecture_scheduler.dart';
import 'class_analytics_screen.dart';

class Dashboard extends StatefulWidget {
  final UniversityMemory memory;
  final OmniBrain brain;
  final String batch;
  final VoidCallback onToggleTheme;
  final Future<void> Function(String mode) onSetThemeMode;
  final String currentThemeMode;
  final VoidCallback onChangeBatch;
  final String? userName;
  final ValueChanged<String>? onUserNameChanged;
  final ValueChanged<String> onRoleChanged;

  const Dashboard({
    required this.memory,
    required this.brain,
    required this.batch,
    required this.onToggleTheme,
    required this.onSetThemeMode,
    required this.currentThemeMode,
    required this.onChangeBatch,
    required this.onRoleChanged,
    this.userName,
    this.onUserNameChanged,
    super.key,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  static const String _customMakeupSessionsPrefsKey = 'custom_makeup_sessions';
  late Timer _ticker;
  ClassSession? _previousClass;
  int? _previousProgressPercent;
  String? _previousNotificationHash;
  String? _previousWidgetHash;
  int? _overrideDayIndex;
  int _bottomNavIndex = 0;
  int _studentTabSlideDirection = 1;
  bool _isStudentNavBusy = false;
  bool _navBarReady = false;
  List<ClassSession> _cachedSchedule = [];
  DateTime? _lastScheduleUpdate;
  int? _lastMinute;
  bool _isRefreshing = false;
  final Map<String, List<ClassSession>> _makeupReplacementHistory = {};
  final GlobalKey _studentPortalNavKey = GlobalKey(
    debugLabel: 'student_portal_nav',
  );
  final GlobalKey _studentToolsNavKey = GlobalKey(
    debugLabel: 'student_tools_nav',
  );
  final GlobalKey _studentAboutNavKey = GlobalKey(
    debugLabel: 'student_about_nav',
  );
  final ScrollController _scrollController = ScrollController();

  bool _isMakeupSession(ClassSession session) =>
      session.id.startsWith('makeup_');

  Future<void> _loadCustomMakeupSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_customMakeupSessionsPrefsKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final existingIds = widget.memory.sessions.map((s) => s.id).toSet();
      var changed = false;

      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final session = ClassSession.fromJson(entry);
        if (existingIds.contains(session.id)) continue;
        widget.memory.sessions.add(session);
        existingIds.add(session.id);
        changed = true;
      }

      if (changed && mounted) {
        _updateScheduleCache();
        setState(() {});
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load custom makeup sessions: $e');
    }
  }

  bool _sameSessionSignature(ClassSession a, ClassSession b) =>
      a.subject == b.subject &&
      a.teacher == b.teacher &&
      a.room == b.room &&
      (a.safeStartVal - b.safeStartVal).abs() < 0.01;

  bool _sessionsOverlap(ClassSession a, ClassSession b) =>
      a.batchKey.batch == b.batchKey.batch &&
      a.dayIndex == b.dayIndex &&
      a.safeStartVal < b.safeEndVal &&
      b.safeStartVal < a.safeEndVal;

  Future<void> _persistCustomMakeupSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = widget.memory.sessions
          .where((s) => _isMakeupSession(s))
          .map((s) => s.toJson())
          .toList();
      await prefs.setString(_customMakeupSessionsPrefsKey, jsonEncode(custom));
    } catch (e) {
      debugPrint('⚠️ Failed to persist makeup sessions: $e');
    }
  }

  Future<void> _addMakeupSession(ClassSession session) async {
    if (_isMakeupSession(session)) return;
    if (!mounted) return;

    final batchSessions = widget.memory.sessions
        .where((s) => s.batchKey.batch == widget.batch)
        .toList();

    final overlaps = batchSessions
        .where((s) => _sessionsOverlap(s, session))
        .toList();
    final regularConflict = overlaps
        .where((s) => !_isMakeupSession(s))
        .toList();
    if (regularConflict.isNotEmpty) {
      final conflict = regularConflict.first;
      if (!mounted) return;
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_conflict_${conflict.id}',
        content: Text(
          'Conflicts with ${conflict.subject} (${conflict.startTime}-${conflict.endTime}). Pick another slot.',
        ),
      );
      return;
    }

    // Intelligent behavior: replace overlapping makeup slots and preserve history for safe restore.
    final makeupOverlaps = overlaps.where(_isMakeupSession).toList();
    if (makeupOverlaps.isNotEmpty) {
      final overlapIds = makeupOverlaps.map((s) => s.id).toSet();
      final removedSnapshots = <ClassSession>[];

      for (final replaced in makeupOverlaps) {
        removedSnapshots.add(replaced);
        final nestedHistory =
            _makeupReplacementHistory.remove(replaced.id) ??
            const <ClassSession>[];
        removedSnapshots.addAll(nestedHistory);
      }

      final unique = <String, ClassSession>{};
      for (final item in removedSnapshots) {
        unique[item.id] = item;
      }
      _makeupReplacementHistory[session.id] = unique.values.toList();

      widget.memory.sessions.removeWhere((s) => overlapIds.contains(s.id));
    }

    widget.memory.sessions.add(session);
    await _persistCustomMakeupSessions();

    if (!mounted) return;
    _updateScheduleCache();
    setState(() {});
    _updateWidgetIfNeeded();
    _updatePersistentNotificationIfNeeded();

    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'makeup_added_${session.id}',
      content: Text(
        makeupOverlaps.isNotEmpty
            ? 'Added ${session.subject} (${session.startTime}-${session.endTime}) and replaced ${makeupOverlaps.length} overlapping makeup slot${makeupOverlaps.length == 1 ? '' : 's'}.'
            : 'Added makeup class: ${session.subject} (${session.startTime}-${session.endTime})',
      ),
    );
  }

  Future<void> _removeMakeupSession(ClassSession session) async {
    if (!_isMakeupSession(session)) return;

    final restoreCandidates =
        _makeupReplacementHistory.remove(session.id) ?? const <ClassSession>[];

    final before = widget.memory.sessions.length;
    widget.memory.sessions.removeWhere((s) => s.id == session.id);
    final removed = before - widget.memory.sessions.length;
    if (removed <= 0) return;

    var restored = 0;
    for (final candidate in restoreCandidates) {
      final duplicate = widget.memory.sessions.any(
        (s) => s.id == candidate.id || _sameSessionSignature(s, candidate),
      );
      if (duplicate) continue;

      final overlap = widget.memory.sessions.any(
        (s) =>
            s.batchKey.batch == widget.batch && _sessionsOverlap(s, candidate),
      );
      if (overlap) continue;

      widget.memory.sessions.add(candidate);
      restored += 1;
    }

    await _persistCustomMakeupSessions();

    if (!mounted) return;
    _updateScheduleCache();
    setState(() {});
    _updateWidgetIfNeeded();
    _updatePersistentNotificationIfNeeded();

    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'makeup_removed_${session.id}',
      content: Text(
        restored > 0
            ? 'Removed makeup class. Restored $restored previously replaced slot${restored == 1 ? '' : 's'}.'
            : 'Removed makeup class from timeline.',
      ),
    );
  }

  Future<void> _confirmAndRemoveMakeupSession(ClassSession session) async {
    if (!_isMakeupSession(session) || !mounted) return;
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLive = session.isLive(now);
    final currentTime = now.hour + (now.minute / 60.0);
    final minutesToStart = ((session.safeStartVal - currentTime) * 60).round();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassSurface(
        settings: LiquidGlassSettings(
          blur: 16,
          ambientStrength: 0.70,
          lightAngle: 0.15 * math.pi,
          glassColor: Colors.black.withValues(alpha: 0.05),
          thickness: 15,
        ),
        radius: 20,
        child: AlertDialog(
          backgroundColor: (isDark ? const Color(0xFF111827) : Colors.white)
              .withValues(alpha: isDark ? 0.88 : 0.92),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.12,
              ),
            ),
          ),
          title: const Text('Remove makeup class?'),
          content: Text(
            isLive
                ? 'This class is live right now. Remove it from your timeline?'
                : minutesToStart >= 0 && minutesToStart <= 15
                    ? 'This class starts in $minutesToStart min. Remove it anyway?'
                    : 'Remove ${session.subject} (${session.startTime}-${session.endTime}) from your timeline?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: IrisTokens.error),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _removeMakeupSession(session);
    }
  }

  void _tick(DateTime now) {
    if (mounted) {
      _updatePersistentNotificationIfNeeded();
      _updateWidgetIfNeeded();
    }
  }

  Future<void> _startForegroundServiceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // Keep the service data aligned with the active student batch,
    // but do not overwrite the app persona here.
    await prefs.setString('student_batch', widget.batch);

    final notificationEnabled =
        prefs.getBool('persistent_notification_enabled') ?? false;

    if (notificationEnabled) {
      // Always restart to ensure correct role data
      await _startForegroundService();
    } else {
      // If notifications disabled, stop any running service
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    }
  }

  Future<void> _startForegroundService() async {
    // Stop service if running (from previous role switch) without delay
    // Service restart is handled gracefully by Android
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }

    // Store timetable data for TaskHandler to use
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_batch', widget.batch);

    // Serialize timetable data
    final timetableData = {
      'sessions': widget.memory.sessions.map((s) => s.toJson()).toList(),
    };
    await prefs.setString('timetable_data', jsonEncode(timetableData));

    final remindersEnabled =
        prefs.getBool('lecture_reminders_enabled') ?? false;
    if (remindersEnabled) {
      // Schedule 5-minute reminders for today's classes
      final todayClasses = widget.memory.sessions
          .where(
            (s) =>
                s.batchKey.batch == widget.batch &&
                s.dayIndex == DateTime.now().weekday,
          )
          .toList();

      if (todayClasses.isNotEmpty) {
        await NotificationService().scheduleClassReminders(todayClasses);
      }
    }

    // Calculate initial notification
    final now = DateTime.now();
    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);
    final currentTime = now.hour + (now.minute / 60.0);
    final dayIndex = now.weekday;

    final todayAll = widget.memory.sessions
        .where(
          (s) => s.batchKey.batch == widget.batch && s.dayIndex == dayIndex,
        )
        .toList();

    String notifTitle = 'IRIS Class Tracker';
    String notifBody = 'Keeping your class schedule handy';

    if (current != null && current.isLive(now)) {
      final duration = LectureDuration.getActualDuration(current);
      final actualEndTime = LectureDuration.getActualEndTime(current);
      final progress = ((currentTime - current.safeStartVal) / duration).clamp(
        0.0,
        1.0,
      );
      final progressPercent = (progress * 100).toInt();

      final minutesRemaining = ((actualEndTime - currentTime) * 60)
          .round()
          .clamp(0, (duration * 60).round());
      final hoursRemaining = minutesRemaining ~/ 60;
      final minsRemaining = minutesRemaining % 60;

      String timeLeft = hoursRemaining > 0
          ? '${hoursRemaining}h ${minsRemaining}m left'
          : minsRemaining > 0
          ? '${minsRemaining}m left'
          : 'Ending now';

      final remaining = todayAll
          .where((s) => s.safeStartVal > currentTime)
          .length;
      final classCount = remaining > 0
          ? ' · $remaining more today'
          : ' · Last one';

      notifTitle = '${current.subject} · $timeLeft';
      notifBody =
          'In Progress ($progressPercent%)$classCount\n${current.room} · ${current.teacher}';
    } else if (next != null) {
      int daysAhead = 0;
      if (next.dayIndex != dayIndex) {
        daysAhead = (next.dayIndex - dayIndex + 7) % 7;
        if (daysAhead == 0) daysAhead = 7;
      }
      final totalMinutesUntil = daysAhead > 0
          ? ((24.0 - currentTime) * 60 +
                    (daysAhead - 1) * 24 * 60 +
                    next.safeStartVal * 60)
                .round()
          : ((next.safeStartVal - currentTime) * 60).round();
      final hoursUntil = totalMinutesUntil ~/ 60;
      final minsUntil = totalMinutesUntil % 60;

      String timeUntil = '';
      String statusLabel = 'Scheduled';
      if (daysAhead > 0) {
        const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final nextDayName = dayNames[next.dayIndex];
        final startHour = next.safeStartVal.floor();
        final startMin = ((next.safeStartVal - startHour) * 60).round();
        final displayHour = startHour > 12 ? startHour - 12 : startHour;
        final amPm = startHour >= 12 ? 'PM' : 'AM';
        timeUntil =
            '$nextDayName ${displayHour}:${startMin.toString().padLeft(2, '0')} $amPm';
        statusLabel = 'Upcoming';
      } else if (hoursUntil > 0) {
        timeUntil = '${hoursUntil}h ${minsUntil}m';
        statusLabel = 'Next';
      } else if (minsUntil > 10) {
        timeUntil = '${minsUntil} min';
        statusLabel = 'Starting Soon';
      } else if (minsUntil > 0) {
        timeUntil = '${minsUntil} min';
        statusLabel = 'Starting Now';
      } else {
        timeUntil = 'Now';
        statusLabel = 'Starting';
      }

      final remainingToday = todayAll
          .where((s) => s.safeStartVal > currentTime)
          .length;

      String classInfo;
      if (daysAhead > 0) {
        classInfo = 'Done for today';
      } else if (remainingToday > 1) {
        classInfo = '$remainingToday classes left';
      } else {
        classInfo = 'Last class today';
      }

      notifTitle = '${next.subject} in $timeUntil';
      notifBody = '$classInfo\n${next.room} · ${next.teacher}';
    } else {
      final weekday = now.weekday;
      if (weekday == 6 || weekday == 7) {
        notifTitle = 'Weekend Mode';
        notifBody = 'No classes — enjoy your break!';
      } else {
        notifTitle = 'All done for today';
        notifBody = 'No more classes scheduled';
      }
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: notifTitle,
      notificationText: notifBody,
      notificationIcon: null,
      notificationButtons: [const NotificationButton(id: 'open', text: 'Open IRIS')],
      callback: startClassNotificationTask,
    );
  }

  @override
  void didUpdateWidget(Dashboard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detect batch change and refresh everything
    if (widget.batch != oldWidget.batch) {
      _updateScheduleCache();
      _previousClass = null;
      // Force rebuild of timeline cards and UI
      setState(() {});
      _scheduleClassReminders();
      _updatePersistentNotificationIfNeeded();
      _updateWidgetIfNeeded();
    }
  }

  String _formatDateLabel(DateTime now) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[(now.weekday - 1) % 7];
    final monthName = months[(now.month - 1).clamp(0, 11)];
    return '$dayName, $monthName ${now.day}';
  }

  void _updateScheduleCache() {
    final now = DateTime.now();
    _cachedSchedule = _buildTimelineSchedule(now);
    _lastScheduleUpdate = now;
  }

  void _scheduleClassReminders() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        final remindersEnabled =
            prefs.getBool('lecture_reminders_enabled') ?? false;
        if (!remindersEnabled) {
          NotificationService().cancelScheduledClassReminders();
          return;
        }

        // Get today's classes for the student's batch
        final todayClasses = widget.memory.sessions
            .where(
              (s) =>
                  s.batchKey.batch == widget.batch &&
                  s.dayIndex == DateTime.now().weekday,
            )
            .toList();

        if (todayClasses.isNotEmpty) {
          NotificationService().scheduleClassReminders(todayClasses);
        }
      });
    } catch (e) {
      // Silently handle scheduling errors - non-critical feature
      debugPrint('⚠️ Failed to schedule class reminders: $e');
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    _scrollController.dispose();
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
    _updateWidgetIfNeeded();
    _updatePersistentNotificationIfNeeded();

    setState(() => _isRefreshing = false);
    IrisHaptics.refreshSuccess();

    // Show success feedback
    if (mounted) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'schedule_refreshed_faculty',
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              'Schedule refreshed',
              style: IrisTextStyles.body(context).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        tint: IrisTokens.success,
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _updatePersistentNotificationIfNeeded() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final notificationEnabled =
        prefs.getBool('persistent_notification_enabled') ?? false;

    if (!notificationEnabled) return;

    // Health check: restart service if it should be running but isn't
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      debugPrint('⚠️ Service not running but should be - restarting...');
      await _startForegroundService();
      return; // Service will update on its own after start
    }

    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);
    final currentTime = now.hour + (now.minute / 60.0);
    final dayIndex = now.weekday;

    // Calculate state hash to determine if update is needed
    String generateStateHash() {
      if (current != null && current.isLive(now)) {
        final duration = LectureDuration.getActualDuration(current);
        final progress = ((currentTime - current.safeStartVal) / duration)
            .clamp(0.0, 1.0);
        final progressPercent = (progress * 100).toInt();
        return 'live_${current.subject}_$progressPercent';
      } else if (next != null) {
        return 'next_${next.subject}_${next.safeStartVal}';
      }
      return 'idle';
    }

    final currentHash = generateStateHash();

    // Only update if state changed significantly (class changed or progress milestone reached)
    if (_previousNotificationHash == currentHash && current == _previousClass) {
      return; // No meaningful change, skip update
    }

    _previousNotificationHash = currentHash;

    final todayAll = widget.memory.sessions
        .where(
          (s) => s.batchKey.batch == widget.batch && s.dayIndex == dayIndex,
        )
        .toList();

    try {
      String notifTitle = '';
      String notifBody = '';

      if (current != null && current.isLive(now)) {
        final duration = LectureDuration.getActualDuration(current);
        final actualEndTime = LectureDuration.getActualEndTime(current);
        final progress = ((currentTime - current.safeStartVal) / duration)
            .clamp(0.0, 1.0);
        final progressPercent = (progress * 100).toInt();

        final minutesRemaining = ((actualEndTime - currentTime) * 60)
            .round()
            .clamp(0, (duration * 60).round());
        final hoursRemaining = minutesRemaining ~/ 60;
        final minsRemaining = minutesRemaining % 60;

        String timeLeft = hoursRemaining > 0
            ? '${hoursRemaining}h ${minsRemaining}m left'
            : minsRemaining > 0
            ? '${minsRemaining}m left'
            : 'Ending now';

        final remaining = todayAll
            .where((s) => s.safeStartVal > currentTime)
            .length;
        final classCount = remaining > 0
            ? ' · $remaining more today'
            : ' · Last one';

        notifTitle = '${current.subject} · $timeLeft';
        notifBody =
            'In Progress ($progressPercent%)$classCount\n${current.room} · ${current.teacher}';
      } else if (next != null) {
        int daysAhead = 0;
        if (next.dayIndex != dayIndex) {
          daysAhead = (next.dayIndex - dayIndex + 7) % 7;
          if (daysAhead == 0) daysAhead = 7;
        }
        final totalMinutesUntil = daysAhead > 0
            ? ((24.0 - currentTime) * 60 +
                      (daysAhead - 1) * 24 * 60 +
                      next.safeStartVal * 60)
                  .round()
            : ((next.safeStartVal - currentTime) * 60).round();
        final hoursUntil = totalMinutesUntil ~/ 60;
        final minsUntil = totalMinutesUntil % 60;

        String timeUntil = '';
        String statusLabel = 'Scheduled';
        if (daysAhead > 0) {
          const dayNames = [
            '',
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
            'Sat',
            'Sun',
          ];
          final nextDayName = dayNames[next.dayIndex];
          final startHour = next.safeStartVal.floor();
          final startMin = ((next.safeStartVal - startHour) * 60).round();
          final displayHour = startHour > 12 ? startHour - 12 : startHour;
          final amPm = startHour >= 12 ? 'PM' : 'AM';
          timeUntil =
              '$nextDayName ${displayHour}:${startMin.toString().padLeft(2, '0')} $amPm';
          statusLabel = 'Upcoming';
        } else if (hoursUntil > 0) {
          timeUntil = '${hoursUntil}h ${minsUntil}m';
          statusLabel = 'Next';
        } else if (minsUntil > 10) {
          timeUntil = '${minsUntil} min';
          statusLabel = 'Starting Soon';
        } else if (minsUntil > 0) {
          timeUntil = '${minsUntil} min';
          statusLabel = 'Starting Now';
        } else {
          timeUntil = 'Now';
          statusLabel = 'Starting';
        }

        final remainingToday = todayAll
            .where((s) => s.safeStartVal > currentTime)
            .length;

        // Break info
        String breakInfo = '';
        if (daysAhead == 0) {
          final prevClasses = todayAll
              .where((s) => s.safeEndVal <= currentTime)
              .toList();
          if (prevClasses.isNotEmpty) {
            prevClasses.sort((a, b) => b.safeEndVal.compareTo(a.safeEndVal));
            final breakMins =
                ((next.safeStartVal - prevClasses.first.safeEndVal) * 60)
                    .round();
            if (breakMins > 0 && breakMins < 180) {
              breakInfo = ' · ${breakMins}m break';
            }
          }
        }

        String classInfo;
        if (daysAhead > 0) {
          classInfo = 'Done for today';
        } else if (remainingToday > 1) {
          classInfo = '$remainingToday classes left';
        } else {
          classInfo = 'Last class today';
        }

        notifTitle = '${next.subject} in $timeUntil';
        notifBody = '$classInfo$breakInfo\n${next.room} · ${next.teacher}';
      } else {
        final weekday = now.weekday;
        if (weekday == 6 || weekday == 7) {
          notifTitle = 'Weekend Mode';
          notifBody = 'No classes — enjoy your break!';
        } else {
          notifTitle = 'All done for today';
          notifBody = 'No more classes scheduled';
        }
      }

      // Store notification content for foreground service to read
      await prefs.setString('notification_title', notifTitle);
      await prefs.setString('notification_body', notifBody);

      // Update foreground service notification if running
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: notifTitle,
          notificationText: notifBody,
          notificationButtons: [
            const NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
        );
      }
    } catch (e) {
      debugPrint('❌ Persistent notification update failed: $e');
    }
  }

  /// Update home widget with temporal insight data
  Future<void> _updateWidgetIfNeeded() async {
    try {
      final now = DateTime.now();
      final insight = widget.brain.buildTemporalInsight(widget.batch, now);

      // Calculate progress percentage if live
      int progressPercent = 0;
      if (insight.isLive) {
        final current = widget.brain.getCurrentClass(widget.batch, now);
        if (current != null) {
          final currentTime = now.hour + (now.minute / 60.0);
          final duration = LectureDuration.getActualDuration(current);
          final progress = ((currentTime - current.safeStartVal) / duration)
              .clamp(0.0, 1.0);
          progressPercent = (progress * 100).toInt();
        }
      }

      // Generate state hash to determine if widget update is needed
      String generateWidgetHash() {
        return '${insight.headline}_${insight.isLive}_${progressPercent}_${insight.isUrgent}';
      }

      final currentHash = generateWidgetHash();

      // Only update widget if state changed (smarter updates to save battery)
      if (_previousWidgetHash == currentHash &&
          progressPercent == _previousProgressPercent) {
        return; // No meaningful change, skip widget update
      }

      _previousWidgetHash = currentHash;
      _previousProgressPercent = progressPercent;

      // Update widget with insight data
      await WidgetService.updateWidgetWithInsight(
        headline: insight.headline,
        subline: insight.subline,
        timeInfo: insight.timeInfo ?? '--',
        teacherInfo: insight.teacherInfo ?? '',
        isLive: insight.isLive,
        isUrgent: insight.isUrgent,
        progressPercentage: progressPercent,
      );
    } catch (e) {
      debugPrint('⚠️ Widget update failed: $e');
    }
  }

  // Future<void> _openPortal({GlobalKey? originKey}) async {
  //   if (!mounted) return;
  //   IrisHaptics.actionMedium();

  //   await pushIconLaunchRoute(
  //     context,
  //     originKey: originKey,
  //     page: const PortalScreen(
  //       url: 'https://swl-sis.comsats.edu.pk/Login/Index',
  //       title: 'COMSATS Student Portal',
  //       sessionScope: 'student',
  //     ),
  //   );
  // }

  // Future<void> _openTeacherPortal({GlobalKey? originKey}) async {
  //   if (!mounted) return;
  //   IrisHaptics.actionMedium();

  //   await pushIconLaunchRoute(
  //     context,
  //     originKey: originKey,
  //     page: const PortalScreen(
  //       url:
  //           'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
  //       title: 'COMSATS Faculty Portal',
  //       sessionScope: 'faculty',
  //     ),
  //   );
  // }

  // Future<void> _openAbout({GlobalKey? originKey}) async {
  //   if (!mounted) return;
  //   IrisHaptics.actionMedium();

  //   await pushIconLaunchRoute(
  //     context,
  //     originKey: originKey,
  //     page: AboutScreen(
  //       onRoleChanged: widget.onRoleChanged,
  //       onSetThemeMode: widget.onSetThemeMode,
  //       currentThemeMode: widget.currentThemeMode,
  //       onUserNameChanged: widget.onUserNameChanged,
  //     ),
  //   );

  //   // Widget updates automatically via ticker - no manual refresh needed
  // }

  // Future<void> _openDepartmentClassesBrowser({GlobalKey? originKey}) async {
  //   if (!mounted) return;
  //   IrisHaptics.actionMedium();

  //   await pushIconLaunchRoute(
  //     context,
  //     originKey: originKey,
  //     page: _DepartmentClassesScreen(
  //       memory: widget.memory,
  //       currentBatch: widget.batch,
  //       brain: widget.brain,
  //       onRoleChanged: widget.onRoleChanged,
  //       showDock: false,
  //     ),
  //   );
  // }

  // Future<void> _openTeacherSearch({GlobalKey? originKey}) async {
  //   if (!mounted) return;
  //   IrisHaptics.actionMedium();

  //   await pushIconLaunchRoute(
  //     context,
  //     originKey: originKey,
  //     page: TeacherLocatorScreen(
  //       brain: widget.brain,
  //       onRoleChanged: widget.onRoleChanged,
  //       memory: widget.memory,
  //       currentBatch: widget.batch,
  //       showDock: false,
  //     ),
  //   );
  // }

  Future<void> _onBottomNavTap(int index) async {
    if (!mounted) return;
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
      _studentTabSlideDirection = index > previousIndex ? 1 : -1;
      _bottomNavIndex = index;
    });

    await Future<void>.delayed(lockDuration);
    if (!mounted) return;
    setState(() => _isStudentNavBusy = false);

    if (index == 0) {
      _updateScheduleCache();
    }
  }

  void _setStudentTabFromDrag(int index) {
    if (!mounted) return;
    if (_isStudentNavBusy) return;
    if (index == _bottomNavIndex) return;
    index = index.clamp(0, 3);
    setState(() {
      _studentTabSlideDirection = index > _bottomNavIndex ? 1 : -1;
      _bottomNavIndex = index;
    });
    IrisHaptics.chipSelect();
    if (index == 0) {
      _updateScheduleCache();
    }
  }

  void _handleStudentNavDrag(DragUpdateDetails details, double width) {
    if (width <= 0) return;
    final safeDx = details.localPosition.dx.clamp(0.0, width - 1);
    final itemWidth = width / 4;
    final targetIndex = (safeDx / itemWidth).floor().clamp(0, 3);
    _setStudentTabFromDrag(targetIndex);
  }

  Widget _buildStudentTabContent() {
    switch (_bottomNavIndex) {
      case 1:
        return const PortalScreen(
          key: PageStorageKey<String>('student_tab_portal'),
          url: 'https://swl-sis.comsats.edu.pk/Login/Index',
          title: 'COMSATS Student Portal',
          sessionScope: 'student',
          showBackButton: false,
        );
      case 2:
        // Temporarily using a placeholder until ToolsScreen is moved
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.grid_view_rounded, size: 64, color: IrisTokens.brand),
              const SizedBox(height: 16),
              Text('Resources coming soon...', style: IrisTextStyles.headline(context).copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => setState(() => _bottomNavIndex = 0),
                child: const Text('Go Home'),
              ),
            ],
          ),
        );
      case 3:
        return AboutScreen(
          key: const PageStorageKey<String>('student_tab_about'),
          memory: widget.memory,
          onRoleChanged: widget.onRoleChanged,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStudentBottomNavBar(bool isDark, ScrollController scrollController) {
    return DashboardDock(
      scrollController: scrollController,
      showStudentSet: true,
      selectedIndex: _bottomNavIndex,
      onHome: () {
        if (_bottomNavIndex == 0) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
        } else {
          setState(() {
            _studentTabSlideDirection = -1;
            _bottomNavIndex = 0;
          });
        }
      },
      onPortal: () => setState(() {
        _studentTabSlideDirection = _bottomNavIndex < 1 ? 1 : -1;
        _bottomNavIndex = 1;
      }),
      onTools: () => setState(() {
        _studentTabSlideDirection = _bottomNavIndex < 2 ? 1 : -1;
        _bottomNavIndex = 2;
      }),
      onAbout: () => setState(() {
        _studentTabSlideDirection = 1;
        _bottomNavIndex = 3;
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (now.minute != _lastMinute) {
        _lastMinute = now.minute;
        _updateScheduleCache();
        if (mounted) setState(() {});
      }
      _tick(now);
    });
    _loadCustomMakeupSessions();
    _updateScheduleCache();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: IrisMotion.entrance,
              switchOutCurve: IrisMotion.standard,
              transitionBuilder: (child, animation) {
                final isIncoming = child.key == ValueKey<int>(_bottomNavIndex);
                final direction = _studentTabSlideDirection.toDouble();
                
                final slideBegin = isIncoming ? Offset(0.42 * direction, 0) : Offset.zero;
                final slideEnd = isIncoming ? Offset.zero : Offset(-0.42 * direction, 0);
                final slideAnimation = Tween<Offset>(begin: slideBegin, end: slideEnd).animate(
                  CurvedAnimation(parent: animation, curve: IrisMotion.standard),
                );
                
                final scaleBegin = isIncoming ? 0.92 : 1.0;
                final scaleEnd = isIncoming ? 1.0 : 0.96;
                final scaleAnimation = Tween<double>(begin: scaleBegin, end: scaleEnd).animate(
                  CurvedAnimation(parent: animation, curve: IrisMotion.standard),
                );
                
                final opacityAnimation = Tween<double>(
                  begin: isIncoming ? 0.0 : 1.0,
                  end: isIncoming ? 1.0 : 0.0,
                ).animate(
                  CurvedAnimation(parent: animation, curve: IrisMotion.standard),
                );
                
                return FadeTransition(
                  opacity: opacityAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: SlideTransition(position: slideAnimation, child: child),
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_bottomNavIndex),
                child: _bottomNavIndex == 0 ? _buildStudentPortal(context) : _buildStudentTabContent(),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _buildStudentBottomNavBar(isDark, _scrollController),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentPortal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final metrics = widget.brain.getVitalMetrics(widget.batch, now);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          CustomScrollView(
            controller: _scrollController,
            physics: VitalMotion.scrollPhysics,
            slivers: [
              _buildVitalHeader(context, metrics, isDark),
              _buildBentoToolGrid(context, isDark),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TIMELINE',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2, 
                          fontWeight: FontWeight.w900,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                        ),
                      ),
                      Text(
                        _formatDateLabel(now).toUpperCase(),
                        style: TextStyle(
                          letterSpacing: 1, 
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildChronosTimeline(context, isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalHeader(BuildContext context, BatchVitalMetrics metrics, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GOOD ${_getTimeGreeting()},',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.userName ?? 'Student',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: VitalTokens.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: VitalTokens.blue.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          widget.batch,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: VitalTokens.blue,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSyncIndicator(isDark),
              ],
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                VitalRing(
                  progress: metrics.dayProgress,
                  size: 92,
                  strokeWidth: 9,
                  color: VitalTokens.blue,
                  value: '${(metrics.dayProgress * 100).toInt()}%',
                  label: 'Day',
                ),
                VitalRing(
                  progress: metrics.totalClassesToday > 0 ? metrics.completedClasses / metrics.totalClassesToday : 0,
                  size: 92,
                  strokeWidth: 9,
                  color: VitalTokens.orange,
                  value: '${metrics.completedClasses}/${metrics.totalClassesToday}',
                  label: 'Classes',
                ),
                VitalRing(
                  progress: metrics.attendanceHealth,
                  size: 92,
                  strokeWidth: 9,
                  color: VitalTokens.green,
                  value: '${(metrics.attendanceHealth * 100).toInt()}%',
                  label: 'Health',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChronosTimeline(BuildContext context, bool isDark) {
    if (_cachedSchedule.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Opacity(
            opacity: 0.5,
            child: Column(
              children: [
                Icon(Icons.event_available_rounded, size: 48, color: isDark ? Colors.white30 : Colors.black26),
                const SizedBox(height: 16),
                const Text('No classes today', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final session = _cachedSchedule[index];
            final isLast = index == _cachedSchedule.length - 1;
            final now = DateTime.now();
            final isLive = session.isLive(now);

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 24),
                        decoration: BoxDecoration(
                          color: isLive ? VitalTokens.blue : (isDark ? Colors.white10 : Colors.black12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? VitalTokens.obsidian : Colors.white,
                            width: 3,
                          ),
                          boxShadow: isLive ? [
                            BoxShadow(
                              color: VitalTokens.blue.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ] : null,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: ClassCard(
                        session: session,
                        onRemoveMakeup: _isMakeupSession(session) ? () => _confirmAndRemoveMakeupSession(session) : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: _cachedSchedule.length,
        ),
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'MORNING';
    if (hour < 17) return 'AFTERNOON';
    return 'EVENING';
  }

  Widget _buildSyncIndicator(bool isDark) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.bolt_rounded,
          size: 20,
          color: VitalTokens.blue.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  List<ClassSession> _buildTimelineSchedule(DateTime now) {
    final schedule = _overrideDayIndex != null
        ? _scheduleForDay(
            widget.brain.scheduleFor(widget.batch),
            _overrideDayIndex!,
          )
        : _buildSuggestedSchedule(now);

    // Merge consecutive slots of the same lecture for cleaner display
    final mergedSchedule = widget.brain.getMergedConsecutiveSessions(schedule);

    // Ensure final schedule is always sorted in ascending order by start time
    mergedSchedule.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    return mergedSchedule;
  }

  List<ClassSession> _scheduleForDay(List<ClassSession> all, int dayIndex) {
    final daySchedule = all.where((s) => s.dayIndex == dayIndex).toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    return daySchedule;
  }

  List<ClassSession> _buildSuggestedSchedule(DateTime now) {
    final all = widget.brain.scheduleFor(widget.batch);
    if (all.isEmpty) return [];

    final currentTime = now.hour + (now.minute / 60.0);
    final today = all.where((s) => s.dayIndex == now.weekday).toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    if (today.isNotEmpty) {
      // Check if all today's classes have ended
      final allClassesEnded = today.every((s) => s.safeEndVal <= currentTime);

      if (allClassesEnded) {
        // All classes done for today, show next day automatically
        return _nextDaySchedule(all, now.weekday);
      }

      return today; // Show today's full schedule
    }

    return _nextDaySchedule(all, now.weekday);
  }

  List<ClassSession> _nextDaySchedule(List<ClassSession> all, int todayIndex) {
    for (int offset = 1; offset <= 6; offset++) {
      final nextDay = ((todayIndex + offset - 1) % 7) + 1;
      final daySchedule = all.where((s) => s.dayIndex == nextDay).toList()
        ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      if (daySchedule.isNotEmpty) {
        return daySchedule;
      }
    }
    return [];
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

    // Check if it's tomorrow
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
      // Show smart live status
      final current = widget.brain.getCurrentClass(widget.batch, now);

      if (current != null && current.isLive(now)) {
        // Currently in a class
        final remaining = schedule
            .where((s) => s.safeStartVal > currentTime)
            .length;
        final classesLeft = remaining > 0
            ? '$remaining ${remaining == 1 ? 'class' : 'classes'} left'
            : 'Last class today';
        return '${current.subject} • $classesLeft';
      } else {
        // Between classes or before first class
        final nextClass = schedule.firstWhere(
          (s) => s.safeStartVal > currentTime,
          orElse: () => schedule.first,
        );

        if (nextClass.safeStartVal > currentTime) {
          final minutesUntil = ((nextClass.safeStartVal - currentTime) * 60)
              .round();

          if (minutesUntil > 60) {
            return '${(minutesUntil / 60).floor()}h ${minutesUntil % 60}m free • Room Finder likely has open study rooms';
          } else if (minutesUntil > 15) {
            return '${minutesUntil} min break • open Room Finder for a nearby study room';
          } else {
            return 'Starting soon: ${nextClass.subject} in ${nextClass.room} • head there now';
          }
        }
      }

      return '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} today';
    }

    // Check if it's tomorrow
    final tomorrowIndex = (now.weekday % 7) + 1;
    if (dayIndex == tomorrowIndex && overrideDay == null) {
      return '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} tomorrow • First: ${schedule.first.subject}';
    }

    if (overrideDay != null) {
      return '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} • ${_getDayName(overrideDay)}';
    }

    return 'Upcoming schedule';
  }

  String _getDayName(int day) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[(day - 1) % 7];
  }

  String _getSmartGreeting(int hour) {
    if (hour >= 5 && hour < 12) return 'MORNING';
    if (hour >= 12 && hour < 17) return 'AFTERNOON';
    if (hour >= 17 && hour < 21) return 'EVENING';
    return 'NIGHT';
  }

  Color _getTimelineStatusColor(OmniBrain brain, String batch, DateTime now) {
    final current = brain.getCurrentClass(batch, now);
    if (current != null && current.isLive(now)) {
      // Green - lectures are active
      return IrisTokens.success;
    }

    // Check if there's a class starting soon (within next 15 minutes)
    final schedule = brain.scheduleFor(batch);
    final currentTime = now.hour + (now.minute / 60.0);
    final upcomingSoon = schedule
        .where(
          (s) =>
              s.dayIndex == now.weekday &&
              s.safeStartVal > currentTime &&
              s.safeStartVal - currentTime <= 0.25, // 15 minutes
        )
        .isNotEmpty;

    if (upcomingSoon) {
      // Blue - lectures about to start
      return IrisTokens.blue;
    }

    // Red - no active lectures
    return IrisTokens.error;
  }

  Widget _buildVitalThemeToggle(bool isDark) {
    return VitalCard(
      borderRadius: VitalTokens.radiusFull,
      padding: EdgeInsets.zero,
      animate: false,
      onTap: widget.onToggleTheme,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: 20,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildVitalMetricsPanel(BuildContext context, BatchVitalMetrics metrics, bool isDark) {
    return VitalCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          VitalRing(
            progress: metrics.dayProgress,
            size: 80,
            strokeWidth: 8,
            color: VitalTokens.blue,
            label: 'Day Progress',
            value: '${(metrics.dayProgress * 100).toInt()}%',
          ),
          VitalRing(
            progress: metrics.attendanceHealth,
            size: 80,
            strokeWidth: 8,
            color: VitalTokens.green,
            label: 'Attendance',
            value: '${(metrics.attendanceHealth * 100).toInt()}%',
          ),
          VitalRing(
            progress: metrics.totalClassesToday > 0 ? metrics.remainingClasses / metrics.totalClassesToday : 0.0,
            size: 80,
            strokeWidth: 8,
            color: VitalTokens.orange,
            label: 'Remaining',
            value: '${metrics.remainingClasses}',
          ),
        ],
      ),
    );
  }

  Widget _buildVitalInsightBanner(BuildContext context, TemporalInsight insight, bool isDark) {
    final accentColor = insight.isUrgent 
      ? VitalTokens.error 
      : (insight.isLive ? VitalTokens.green : VitalTokens.blue);

    return VitalCard(
      backgroundColor: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
      border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1.5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(VitalTokens.radius16),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              insight.isUrgent ? Icons.warning_rounded : (insight.isLive ? Icons.play_arrow_rounded : Icons.info_outline_rounded),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.headline,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.subline,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                  ),
                ),
                if (insight.timeInfo != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    insight.timeInfo!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoToolGrid(BuildContext context, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
        children: [
          _buildBentoTile(
            context: context,
            isDark: isDark,
            title: 'Room Finder',
            subtitle: 'Find study space',
            icon: Icons.location_on_rounded,
            color: VitalTokens.green,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoomFinderScreen(memory: widget.memory, brain: widget.brain))),
          ),
          _buildBentoTile(
            context: context,
            isDark: isDark,
            title: 'Teacher Locator',
            subtitle: 'Faculty status',
            icon: Icons.person_search_rounded,
            color: VitalTokens.purple,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherLocatorScreen(brain: widget.brain, memory: widget.memory, currentBatch: widget.batch, onRoleChanged: widget.onRoleChanged))),
          ),
          _buildBentoTile(
            context: context,
            isDark: isDark,
            title: 'Makeup Planner',
            subtitle: 'Plan missing labs',
            icon: Icons.event_repeat_rounded,
            color: VitalTokens.orange,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MakeupLectureScheduler(memory: widget.memory, brain: widget.brain, batch: widget.batch, onAddMakeupClass: _addMakeupSession, onRoleChanged: widget.onRoleChanged, showDock: false, showBackButton: true))),
          ),
          _buildBentoTile(
            context: context,
            isDark: isDark,
            title: 'Analytics',
            subtitle: 'Load patterns',
            icon: Icons.analytics_rounded,
            color: VitalTokens.blue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClassAnalyticsScreen(brain: widget.brain, batch: widget.batch))),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoTile({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return VitalCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        IrisHaptics.actionMedium();
        onTap();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
