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
import '../core/models.dart';
import '../core/omni_brain.dart';
import '../core/university_memory.dart';
import '../core/format_guard.dart';
import '../widgets/iris_components.dart';
import '../widgets/glass_card.dart';
import '../widgets/neural_aura.dart';
import '../widgets/smooth_scroll.dart';
import '../widgets/portal_sync_card.dart';
import '../services/notification_service.dart';
import '../services/helpdesk_faculty_service.dart';
import '../services/helpdesk_campus_feed_service.dart';
import '../services/helpdesk_schedule_data_service.dart';
import '../services/ui_feedback.dart';
import '../widget_service.dart';
import '../portal_screen.dart';
import 'about_screen.dart';
import 'room_finder_screen.dart';

// Helper screens that are currently in main.dart but will be moved to tools_screen.dart
// For now, we will import them if they are still in main.dart, but ideally they should be in their own files.
// Since we are moving ToolsScreen next, I'll temporarily leave these as placeholders or import main if needed.
// Actually, it's better to move them all together or use relative imports.

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

  Future<void> _persistCustomMakeupSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = widget.memory.sessions
          .where(_isMakeupSession)
          .map((s) => s.toJson())
          .toList();
      await prefs.setString(_customMakeupSessionsPrefsKey, jsonEncode(custom));
    } catch (e) {
      debugPrint('⚠️ Failed to persist custom makeup sessions: $e');
    }
  }

  bool _sessionsOverlap(ClassSession a, ClassSession b) {
    if (a.dayIndex != b.dayIndex) return false;
    return a.safeStartVal < b.safeEndVal && b.safeStartVal < a.safeEndVal;
  }

  bool _sameSessionSignature(ClassSession a, ClassSession b) {
    return a.batchKey.batch == b.batchKey.batch &&
        a.dayIndex == b.dayIndex &&
        a.startTime == b.startTime &&
        a.endTime == b.endTime &&
        a.teacher.trim().toLowerCase() == b.teacher.trim().toLowerCase() &&
        a.subject.trim().toLowerCase() == b.subject.trim().toLowerCase();
  }

  Future<void> _addMakeupSession(ClassSession session) async {
    if (session.batchKey.batch != widget.batch) {
      if (!mounted) return;
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_different_batch',
        content: const Text('This makeup class belongs to a different batch.'),
      );
      return;
    }

    final duplicate = widget.memory.sessions.any(
      (s) => s.id == session.id || _sameSessionSignature(s, session),
    );
    if (duplicate) {
      if (!mounted) return;
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_duplicate',
        content: const Text('That makeup class is already in your timeline.'),
      );
      return;
    }

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
      builder: (ctx) => LiquidGlassLayer(
        settings: LiquidGlassSettings(
          blur: 16,
          ambientStrength: 0.70,
          lightAngle: 0.15 * math.pi,
          glassColor: Colors.black.withValues(alpha: 0.05),
          thickness: 15,
        ),
        child: LiquidGlass.inLayer(
          shape: const LiquidRoundedSuperellipse(
            borderRadius: Radius.circular(20),
          ),
          glassContainsChild: false,
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
    ),
  );

    if (confirm == true) {
      await _removeMakeupSession(session);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _navBarReady = true);
      }
    });
    _updateScheduleCache();
    _loadCustomMakeupSessions();
    _lastMinute = DateTime.now().minute;

    // Schedule class reminders for today
    _scheduleClassReminders();

    // Start foreground service if notifications enabled
    _startForegroundServiceIfNeeded();

    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        final now = DateTime.now();
        final current = widget.brain.getCurrentClass(widget.batch, now);
        final minuteChanged = _lastMinute != now.minute;
        if (current != _previousClass || minuteChanged) {
          setState(() {
            _lastMinute = now.minute;
            _previousClass = current;
          });
        }
        // Update notifications and widget only if state changed (smarter updates)
        _updatePersistentNotificationIfNeeded();
        _updateWidgetIfNeeded();
      }
    });
    _updatePersistentNotificationIfNeeded();
    _updateWidgetIfNeeded();
  }

  Future<void> _startForegroundServiceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // ALWAYS set role to student to prevent cross-contamination
    await prefs.setString('user_role', 'student');
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
    await prefs.setString('user_role', 'student');
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

    // Animated colored progress bar with glowy emojis
    String bar(double p) {
      const total = 8;
      final filled = (p * total).round().clamp(0, total);
      return '🟦' * filled + '⬜' * (total - filled);
    }

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

      notifTitle = '🎓 ${current.subject} · $timeLeft';
      notifBody =
          '${bar(progress)} $progressPercent%$classCount\n📍 ${current.room} · ${current.teacher}';
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
      String emoji = '📌';
      if (daysAhead > 0) {
        const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final nextDayName = dayNames[next.dayIndex];
        final startHour = next.safeStartVal.floor();
        final startMin = ((next.safeStartVal - startHour) * 60).round();
        final displayHour = startHour > 12 ? startHour - 12 : startHour;
        final amPm = startHour >= 12 ? 'PM' : 'AM';
        timeUntil =
            '$nextDayName ${displayHour}:${startMin.toString().padLeft(2, '0')} $amPm';
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

      final remainingToday = todayAll
          .where((s) => s.safeStartVal > currentTime)
          .length;

      String classInfo;
      if (daysAhead > 0) {
        classInfo = 'Done for today ✓';
      } else if (remainingToday > 1) {
        classInfo = '$remainingToday classes left';
      } else {
        classInfo = 'Last class today';
      }

      notifTitle = '$emoji ${next.subject} in $timeUntil';
      notifBody = '$classInfo\n📍 ${next.room} · ${next.teacher}';
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
    // Don't stop foreground service here - it should persist
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
              style: TextStyle(fontWeight: FontWeight.w600),
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

    // Animated colored progress bar with glowy emojis
    String bar(double p) {
      const total = 8;
      final filled = (p * total).round().clamp(0, total);
      return '🟦' * filled + '⬜' * (total - filled);
    }

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

        notifTitle = '🎓 ${current.subject} · $timeLeft';
        notifBody =
            '${bar(progress)} $progressPercent%$classCount\n📍 ${current.room} · ${current.teacher}';
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
        String emoji = '📌';
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
          classInfo = 'Done for today ✓';
        } else if (remainingToday > 1) {
          classInfo = '$remainingToday classes left';
        } else {
          classInfo = 'Last class today';
        }

        notifTitle = '$emoji ${next.subject} in $timeUntil';
        notifBody = '$classInfo$breakInfo\n📍 ${next.room} · ${next.teacher}';
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
              const Text('Resources coming soon...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStudentBottomNavBar(bool isDark) {
    final width = MediaQuery.of(context).size.width;
    final now = DateTime.now();
    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);
    final currentTime = now.hour + (now.minute / 60.0);
    final minutesToNext = next == null
        ? 9999
        : ((next.safeStartVal - currentTime) * 60).round();
    final classesNeedAttention =
        current != null ||
        (next != null &&
            next.dayIndex == now.weekday &&
            minutesToNext >= 0 &&
            minutesToNext <= 25);
    final makeupCount = widget.memory.sessions
        .where((s) => s.batchKey.batch == widget.batch && _isMakeupSession(s))
        .length;
    final hasMakeup = makeupCount > 0;
    final navPriorityColor = current != null
        ? IrisTokens.success
        : (classesNeedAttention
              ? IrisTokens.warning
              : (hasMakeup ? IrisTokens.purple : IrisTokens.brand));
    final compact = width < 420;
    final veryCompact = width < 360;
    final horizontalPadding = veryCompact ? 10.0 : (compact ? 12.0 : 20.0);
    final radius = veryCompact ? 18.0 : (compact ? 22.0 : 28.0);

    final navActive = _bottomNavIndex != 0;
    final activeGlow = _bottomNavIndex == 0
        ? Colors.transparent
        : navPriorityColor.withValues(alpha: isDark ? 0.20 : 0.15);

    return AnimatedScale(
      duration: const Duration(milliseconds: 352),
      curve: IrisMotion.standard,
      scale: _navBarReady ? 1.0 : 0.93,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 336),
        curve: IrisMotion.standard,
        offset: _navBarReady ? Offset.zero : const Offset(0, 0.45),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 352),
          opacity: _navBarReady ? 1.0 : 0.0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              10,
            ),
            child: LiquidGlassLayer(
              settings: LiquidGlassSettings(
                blur: 18.0,
                ambientStrength: 0.75,
                lightAngle: 0.15 * math.pi,
                glassColor: isDark 
                    ? const Color(0xFF020617).withValues(alpha: 0.10) 
                    : Colors.white.withValues(alpha: 0.18),
                thickness: 12,
              ),
              child: LiquidGlass.inLayer(
                shape: LiquidRoundedSuperellipse(
                  borderRadius: Radius.circular(radius),
                ),
                glassContainsChild: false,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 304),
                  curve: IrisMotion.standard,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: (isDark ? Colors.white : navPriorityColor)
                          .withValues(alpha: navActive ? 0.12 : 0.06),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: activeGlow,
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = constraints.maxWidth / 4;
                      final trailWidth = (itemWidth * 0.34).clamp(
                        12.0,
                        veryCompact ? 16.0 : (compact ? 20.0 : 24.0),
                      );
                      final haloSize = (itemWidth * 0.70).clamp(
                        24.0,
                        veryCompact ? 30.0 : (compact ? 36.0 : 44.0),
                      );
                      final left =
                          (itemWidth * _bottomNavIndex) +
                          ((itemWidth - trailWidth) / 2);
                      final haloLeft =
                          (itemWidth * _bottomNavIndex) +
                          ((itemWidth - haloSize) / 2);
                      final trailColor = isDark
                          ? Colors.white.withValues(alpha: 0.70)
                          : navPriorityColor.withValues(alpha: 0.84);

                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) =>
                            _handleStudentNavDrag(details, constraints.maxWidth),
                        child: Stack(
                          children: [
                            Positioned(
                              left: haloLeft,
                              top: veryCompact ? 9 : (compact ? 8 : 7),
                              child: IgnorePointer(
                                child: NavActiveHalo(
                                  size: haloSize,
                                  color: trailColor,
                                ),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 304),
                              curve: IrisMotion.standard,
                              left: left,
                              top: 0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 304),
                                curve: IrisMotion.standard,
                                width: trailWidth,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: trailColor,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: trailColor.withValues(alpha: 0.20),
                                      blurRadius: 8,
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                veryCompact ? 4 : (compact ? 6 : 8),
                                veryCompact ? 5 : (compact ? 6 : 8),
                                veryCompact ? 4 : (compact ? 6 : 8),
                                veryCompact ? 3 : (compact ? 4 : 6),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: BouncyNavButton(
                                      icon: _bottomNavIndex == 0
                                          ? Icons.home_filled
                                          : Icons.home_rounded,
                                      label: 'Home',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 0,
                                      enabled: !_isStudentNavBusy,
                                      activeColor: IrisTokens.brand,
                                      onTap: () => _onBottomNavTap(0),
                                    ),
                                  ),
                                  Expanded(
                                    child: BouncyNavButton(
                                      launchIconKey: _studentPortalNavKey,
                                      icon: Icons.public_rounded,
                                      label: 'Portal',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 1,
                                      enabled: !_isStudentNavBusy,
                                      activeColor: IrisTokens.brand,
                                      onTap: () => _onBottomNavTap(1),
                                    ),
                                  ),
                                  Expanded(
                                    child: BouncyNavButton(
                                      launchIconKey: _studentToolsNavKey,
                                      icon: _bottomNavIndex == 2
                                          ? Icons.grid_view_rounded
                                          : Icons.grid_view_outlined,
                                      label: 'Resources',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 2,
                                      enabled: !_isStudentNavBusy,
                                      showIndicator: hasMakeup,
                                      indicatorCount: makeupCount,
                                      indicatorColor: IrisTokens.purple,
                                      activeColor: IrisTokens.brand,
                                      onTap: () => _onBottomNavTap(2),
                                    ),
                                  ),
                                  Expanded(
                                    child: BouncyNavButton(
                                      launchIconKey: _studentAboutNavKey,
                                      icon: _bottomNavIndex == 3
                                          ? Icons.info_rounded
                                          : Icons.info_outline_rounded,
                                      label: 'About',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 3,
                                      enabled: !_isStudentNavBusy,
                                      activeColor: IrisTokens.brand,
                                      onTap: () => _onBottomNavTap(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Future<void> _openMakeupScheduler({GlobalKey? originKey}) async {
  //   if (!mounted) return;

  //   IrisHaptics.actionMedium();

  //   await pushIconLaunchRoute(
  //     context,
  //     originKey: originKey,
  //     lightweight: true,
  //     transitionDuration: const Duration(milliseconds: 304),
  //     reverseTransitionDuration: const Duration(milliseconds: 240),
  //     page: MakeupLectureScheduler(
  //       memory: widget.memory,
  //       brain: widget.brain,
  //       batch: widget.batch,
  //       onAddMakeupClass: _addMakeupSession,
  //       onRemoveMakeupClass: _removeMakeupSession,
  //       onRoleChanged: widget.onRoleChanged,
  //       showDock: false,
  //     ),
  //   );

  //   if (!mounted) return;
  //   _updateScheduleCache();
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_bottomNavIndex != 0) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: IrisMotion.entrance,
                switchOutCurve: IrisMotion.standard,
                transitionBuilder: (child, animation) {
                  final isIncoming =
                      child.key == ValueKey<int>(_bottomNavIndex);
                  final direction = _studentTabSlideDirection.toDouble();
                  
                  // Slide animation: more dramatic distance
                  final slideBegin = isIncoming
                      ? Offset(0.42 * direction, 0)
                      : Offset.zero;
                  final slideEnd = isIncoming
                      ? Offset.zero
                      : Offset(-0.42 * direction, 0);
                  final slideAnimation = Tween<Offset>(begin: slideBegin, end: slideEnd).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: IrisMotion.standard,
                    ),
                  );
                  
                  // Scale animation: adds depth
                  final scaleBegin = isIncoming ? 0.92 : 1.0;
                  final scaleEnd = isIncoming ? 1.0 : 0.96;
                  final scaleAnimation = Tween<double>(begin: scaleBegin, end: scaleEnd).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: IrisMotion.standard,
                    ),
                  );
                  
                  // Fade animation: smoother opacity change
                  final opacityAnimation = Tween<double>(
                    begin: isIncoming ? 0.0 : 1.0,
                    end: isIncoming ? 1.0 : 0.0,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: IrisMotion.standard,
                    ),
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
                  child: _buildStudentTabContent(),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _buildStudentBottomNavBar(isDark),
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    // final dateLabel = _formatDateLabel(now);
    final insight = widget.brain.buildTemporalInsight(widget.batch, now);

    // Update cache if day changed or schedule is empty
    if (_lastScheduleUpdate == null ||
        _lastScheduleUpdate!.day != now.day ||
        _cachedSchedule.isEmpty) {
      _updateScheduleCache();
    }
    final schedule = _cachedSchedule;
    final filteredSchedule = schedule;

    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(child: NeuralAura(background: isDark)),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: IrisTokens.brand,
              backgroundColor: isDark
                  ? IrisTokens.surfaceDarkElevated
                  : Colors.white,
              child: CustomScrollView(
                physics: const ButterScrollPhysics(),
                cacheExtent: 500,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: GlassCard(
                        padding: const EdgeInsets.all(24),
                        borderRadius: 36.0,
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [IrisTokens.brand, IrisTokens.purple],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: IrisTokens.brand.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'AM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getSmartGreeting(now.hour),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.userName ?? 'Student',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(99),
                                          border: Border.all(
                                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: Text(
                                          widget.batch,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: widget.onToggleTheme,
                                icon: Icon(
                                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                  size: 24,
                                  color: isDark ? Colors.white : IrisTokens.brand,
                                ),
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GlassCard(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 336),
                          switchInCurve: IrisMotion.entrance,
                          switchOutCurve: IrisMotion.standard,
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: const Offset(0, 0.08),
                              end: Offset.zero,
                            ).animate(animation);

                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: offset,
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            key: ValueKey(
                              '${insight.headline}-${insight.subline}',
                            ),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Icon with live pulse glow (no glitchy circle)
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: insight.isUrgent
                                            ? [
                                                IrisTokens.error,
                                                const Color(0xFFFCA5A5),
                                              ]
                                            : insight.isLive
                                            ? [
                                                IrisTokens.success,
                                                IrisTokens.success.withValues(alpha: 
                                                  0.8,
                                                ),
                                              ]
                                            : [
                                                IrisTokens.brand,
                                                IrisTokens.brandLight,
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (insight.isUrgent
                                                      ? IrisTokens.error
                                                      : insight.isLive
                                                      ? IrisTokens.success
                                                      : IrisTokens.brand)
                                                  .withValues(alpha: 0.22),
                                          blurRadius: insight.isLive ? 10 : 7,
                                          spreadRadius: -2,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      insight.isUrgent
                                          ? Icons.notifications_active
                                          : insight.isLive
                                          ? Icons.play_circle_filled_rounded
                                          : Icons.insights_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          insight.headline,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 17,
                                            letterSpacing: 0.3,
                                            height: 1.2,
                                            color: insight.isLive
                                                ? IrisTokens.success
                                                : null,
                                          ),
                                        ),
                                        if (insight.timeInfo != null) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            insight.timeInfo!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: insight.isUrgent
                                                  ? IrisTokens.error
                                                  : insight.isLive
                                                  ? IrisTokens.success
                                                  : IrisTokens.brand,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Subline with accent bar
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 3,
                                    height: 18,
                                    margin: const EdgeInsets.only(
                                      top: 2,
                                      right: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: insight.isLive
                                          ? IrisTokens.success.withValues(
                                              alpha: 0.4,
                                            )
                                          : IrisTokens.brand.withValues(
                                              alpha: 0.3,
                                            ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      insight.subline,
                                      style: TextStyle(
                                        fontSize: 14,
                                        letterSpacing: 0.2,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                        color: (isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.72,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.55,
                                              )),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Progress bar for live classes
                              if (insight.isLive) ...[
                                const SizedBox(height: 14),
                                Builder(
                                  builder: (context) {
                                    final currentClass = widget.brain
                                        .getCurrentClass(widget.batch, now);
                                    if (currentClass != null) {
                                      final currentTime =
                                          now.hour + (now.minute / 60.0);
                                      // Use actual lecture duration (1.0 for 1-hour lectures, full duration otherwise)
                                      final duration =
                                          LectureDuration.getActualDuration(
                                            currentClass,
                                          );
                                      final actualEndTime =
                                          LectureDuration.getActualEndTime(
                                            currentClass,
                                          );
                                      final progress =
                                          ((currentTime -
                                                      currentClass
                                                          .safeStartVal) /
                                                  duration)
                                              .clamp(0.0, 1.0);
                                      final minutesLeft =
                                          ((actualEndTime - currentTime) * 60)
                                              .toInt()
                                              .clamp(
                                                0,
                                                (duration * 60).toInt(),
                                              );

                                      String progressLabel = '';
                                      if (minutesLeft >= 60) {
                                        final hours = minutesLeft ~/ 60;
                                        final mins = minutesLeft % 60;
                                        progressLabel = mins > 0
                                            ? '${hours}h ${mins}m left'
                                            : '${hours}h left';
                                      } else {
                                        progressLabel = '${minutesLeft}m left';
                                      }

                                      return Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: TweenAnimationBuilder<double>(
                                              duration: const Duration(
                                                milliseconds: 768,
                                              ),
                                              curve: IrisMotion.entrance,
                                              tween: Tween<double>(
                                                begin: 0.0,
                                                end: progress,
                                              ),
                                              builder:
                                                  (
                                                    context,
                                                    value,
                                                    child,
                                                  ) => Container(
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: IrisTokens.success
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: FractionallySizedBox(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      widthFactor: value.clamp(
                                                        0.0,
                                                        1.0,
                                                      ),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          gradient: const LinearGradient(
                                                            colors: [
                                                              IrisTokens
                                                                  .success,
                                                              IrisTokens
                                                                  .success,
                                                              IrisTokens
                                                                  .successDark,
                                                            ],
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: IrisTokens
                                                                  .success
                                                                  .withValues(
                                                                    alpha: 0.28,
                                                                  ),
                                                              blurRadius: 3,
                                                              spreadRadius: -1,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                progressLabel,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  letterSpacing: 0.3,
                                                  fontWeight: FontWeight.w700,
                                                  color: IrisTokens.success,
                                                ),
                                              ),
                                              Text(
                                                '${(progress * 100).toInt()}%',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  letterSpacing: 0.3,
                                                  fontWeight: FontWeight.w800,
                                                  color: IrisTokens.success
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                              if (insight.teacherInfo != null &&
                                  insight.teacherInfo!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.10)
                                          : Colors.black.withValues(
                                              alpha: 0.06,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: IrisTokens.brand.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 12,
                                          color: IrisTokens.brand.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          insight.teacherInfo!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                (isDark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withValues(alpha: 0.6),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: PortalSyncCard(isDark: isDark)),
                  
                  // Quick Actions Grid (Image 1)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IrisComponents.quickActionButton(
                                label: 'Attend',
                                icon: Icons.fingerprint_rounded,
                                color: const Color(0xFF6366F1),
                                isDark: isDark,
                                onTap: () {},
                              ),
                              IrisComponents.quickActionButton(
                                label: 'Finder',
                                icon: Icons.map_rounded,
                                color: const Color(0xFF10B981),
                                isDark: isDark,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RoomFinderScreen(
                                        memory: widget.memory,
                                        brain: widget.brain,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IrisComponents.quickActionButton(
                                label: 'Portal',
                                icon: Icons.language_rounded,
                                color: const Color(0xFFF59E0B),
                                isDark: isDark,
                                onTap: () {
                                  setState(() => _bottomNavIndex = 1);
                                },
                              ),
                              IrisComponents.quickActionButton(
                                label: 'Grades',
                                icon: Icons.auto_graph_rounded,
                                color: const Color(0xFFEC4899),
                                isDark: isDark,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: DaySwitcher(
                        selectedDayIndex: _overrideDayIndex,
                        onSelected: (value) => setState(() {
                          _overrideDayIndex = value;
                          _updateScheduleCache();
                        }),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: SectionHeader(
                        title: _timelineTitle(schedule, now, _overrideDayIndex),
                        subtitle: _timelineSubtitle(
                          schedule,
                          now,
                          _overrideDayIndex,
                        ),
                        statusIndicator: _getTimelineStatusColor(
                          widget.brain,
                          widget.batch,
                          now,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    sliver: filteredSchedule.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 24,
                              ),
                              child: GlassCard(
                                child: Column(
                                  children: [
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            IrisTokens.brand.withValues(
                                              alpha: 0.15,
                                            ),
                                            IrisTokens.brandLight.withValues(
                                              alpha: 0.08,
                                            ),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: IrisTokens.brand.withValues(
                                              alpha: 0.14,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: -4,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.beach_access_rounded,
                                        size: 40,
                                        color: IrisTokens.brand.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'No classes scheduled',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                        letterSpacing: 0.3,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.85),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Enjoy your free time! 🎉',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, index) {
                                final session = filteredSchedule[index];
                                final fullIndex = schedule.indexOf(session);
                                final nextSession =
                                    (fullIndex >= 0 &&
                                        fullIndex + 1 < schedule.length)
                                    ? schedule[fullIndex + 1]
                                    : null;
                                return StaggeredListItem(
                                  index: index,
                                  child: RepaintBoundary(
                                    child: ClassCard(
                                      key: ValueKey(
                                        'class_${session.subject}_${session.startTime}',
                                      ),
                                      session: session,
                                      nextSession: nextSession,
                                      isFacultyView: false,
                                      onRemoveMakeup: _isMakeupSession(session)
                                          ? () =>
                                                _confirmAndRemoveMakeupSession(
                                                  session,
                                                )
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              childCount: filteredSchedule.length,
                              addAutomaticKeepAlives: true,
                              addRepaintBoundaries: true,
                            ),
                          ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 126)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _buildStudentBottomNavBar(isDark),
            ),
          ),
        ],
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
            return '${(minutesUntil / 60).floor()}h ${minutesUntil % 60}m free • Next: ${nextClass.subject}';
          } else if (minutesUntil > 15) {
            return '${minutesUntil} min break • ${nextClass.subject} in ${nextClass.room}';
          } else {
            return 'Starting soon: ${nextClass.subject} in ${nextClass.room} ⚡';
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
}
