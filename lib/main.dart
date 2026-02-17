import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart' hide NotificationVisibility;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/models.dart';
import 'core/omni_brain.dart';
import 'core/format_guard.dart';
import 'core/university_memory.dart';
import 'portal_screen.dart';
import 'widget_service.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';

// ============ FOREGROUND TASK HANDLER ============
@pragma('vm:entry-point')
void startClassNotificationTask() {
  FlutterForegroundTask.setTaskHandler(ClassNotificationTaskHandler());
}

class ClassNotificationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Task started
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Calculate current class info from stored timetable data
    SharedPreferences.getInstance().then((prefs) {
      try {
        final batch = prefs.getString('student_batch');
        final timetableJson = prefs.getString('timetable_data');
        
        if (batch == null || timetableJson == null) {
          FlutterForegroundTask.updateService(
            notificationTitle: 'IRIS Class Tracker',
            notificationText: 'No schedule data available',
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
          return;
        }
        
        // Parse timetable data
        final data = jsonDecode(timetableJson) as Map<String, dynamic>;
        final rawSessions = (data['sessions'] as List)
            .map((s) => ClassSession.fromJson(s))
            .where((s) => s.batchKey.batch == batch)
            .toList();
        
        // Merge consecutive sessions (same subject/teacher/room back-to-back)
        final sorted = List<ClassSession>.from(rawSessions)
          ..sort((a, b) {
            final d = a.dayIndex.compareTo(b.dayIndex);
            return d != 0 ? d : a.safeStartVal.compareTo(b.safeStartVal);
          });
        final sessions = <ClassSession>[];
        ClassSession? merging;
        for (final s in sorted) {
          if (merging == null) { merging = s; continue; }
          if (merging.isConsecutiveWith(s)) {
            merging = ClassSession(
              id: merging.id, batchKey: merging.batchKey,
              dayIndex: merging.dayIndex, startTime: merging.startTime,
              endTime: s.endTime, subject: merging.subject,
              teacher: merging.teacher, room: merging.room,
            );
          } else {
            sessions.add(merging);
            merging = s;
          }
        }
        if (merging != null) sessions.add(merging);
        
        // Calculate current/next class
        final now = DateTime.now();
        final currentTime = now.hour + (now.minute / 60.0);
        final dayIndex = now.weekday;
        
        ClassSession? current;
        ClassSession? next;
        
        for (var session in sessions) {
          if (session.dayIndex == dayIndex && 
              currentTime >= session.safeStartVal && 
              currentTime < session.safeEndVal) {
            current = session;
            break;
          }
        }
        
        if (current == null) {
          // Find next class: today (later) or next days (with week wrapping)
          for (var session in sessions) {
            if (session.dayIndex == dayIndex && currentTime < session.safeStartVal) {
              // Later today
              if (next == null ||
                  session.dayIndex < next.dayIndex ||
                  (session.dayIndex == next.dayIndex && session.safeStartVal < next.safeStartVal)) {
                next = session;
              }
            }
          }
          if (next == null) {
            // Search upcoming days (wrap around week)
            for (int daysAhead = 1; daysAhead <= 6; daysAhead++) {
              final checkDay = ((dayIndex + daysAhead - 1) % 7) + 1;
              final candidates = sessions
                  .where((s) => s.dayIndex == checkDay)
                  .toList()
                ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
              if (candidates.isNotEmpty) {
                next = candidates.first;
                break;
              }
            }
          }
        }
        
        String notifTitle = 'IRIS Class Tracker';
        String notifBody = 'No classes scheduled';
        
        // Build a visual progress bar from Unicode blocks
        String _progressBar(double p) {
          final filled = (p * 10).round().clamp(0, 10);
          return '▓' * filled + '░' * (10 - filled);
        }

        String _formatStart(double val) {
          final hour = val.floor();
          final minute = ((val - hour) * 60).round();
          final displayHour = hour % 12 == 0 ? 12 : hour % 12;
          final amPm = hour >= 12 ? 'PM' : 'AM';
          return '$displayHour:${minute.toString().padLeft(2, '0')} $amPm';
        }
        
        // Count total classes today
        final todayAll = sessions.where((s) => s.dayIndex == dayIndex).toList();
        
        if (current != null) {
          final duration = current.safeEndVal - current.safeStartVal;
          final progress = ((currentTime - current.safeStartVal) / duration).clamp(0.0, 1.0);
          final progressPercent = (progress * 100).toInt();
          
          // Calculate time remaining
          final minutesRemaining = ((current.safeEndVal - currentTime) * 60).round();
          final hoursRemaining = minutesRemaining ~/ 60;
          final minsRemaining = minutesRemaining % 60;
          
          String timeLeft = '';
          if (hoursRemaining > 0) {
            timeLeft = '${hoursRemaining}h ${minsRemaining}m left';
          } else if (minsRemaining > 0) {
            timeLeft = '${minsRemaining}m left';
          } else {
            timeLeft = 'Ending now';
          }
          
          // Smart status with progress bar
          final bar = _progressBar(progress);
          final remaining = todayAll.where((s) => s.safeStartVal > currentTime).length;
          final classCount = remaining > 0 ? ' · $remaining more today' : ' · Last one';

          ClassSession? nextAfterCurrent;
          for (final session in todayAll) {
            if (session.safeStartVal > currentTime) {
              if (nextAfterCurrent == null ||
                  session.safeStartVal < nextAfterCurrent.safeStartVal) {
                nextAfterCurrent = session;
              }
            }
          }
          final nextLine = nextAfterCurrent == null
              ? ''
              : ' · Next: ${nextAfterCurrent.subject} at ${_formatStart(nextAfterCurrent.safeStartVal)}';
          
          notifTitle = '🎓 ${current.subject} · $timeLeft';
          notifBody = '$bar $progressPercent%$classCount\n📍 ${current.room} · ${current.teacher}$nextLine';
          
        } else if (next != null) {
          // Calculate time until next class, handling multi-day gaps
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
          
          // Count remaining classes today
          final remainingToday = sessions
              .where((s) => s.dayIndex == dayIndex && s.safeStartVal > currentTime)
              .length;
          
          // Smart break info
          String breakInfo = '';
          if (daysAhead == 0) {
            // Calculate break duration until next
            // Find previous class end time
            final prevClasses = todayAll
                .where((s) => s.safeEndVal <= currentTime)
                .toList();
            if (prevClasses.isNotEmpty) {
              prevClasses.sort((a, b) => b.safeEndVal.compareTo(a.safeEndVal));
              final breakMins = ((next.safeStartVal - prevClasses.first.safeEndVal) * 60).round();
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
          // Check what day it is for smarter idle message
          final weekday = DateTime.now().weekday;
          if (weekday == 6 || weekday == 7) {
            notifTitle = '🌤 Weekend Mode';
            notifBody = 'No classes — recharge and relax';
          } else {
            notifTitle = '✅ All done for today';
            notifBody = 'No more classes scheduled — see you tomorrow';
          }
        }
        
        FlutterForegroundTask.updateService(
          notificationTitle: notifTitle,
          notificationText: notifBody,
          notificationButtons: [
            NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
        );
      } catch (e) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'IRIS Class Tracker',
          notificationText: 'Error loading schedule',
          notificationButtons: [
            NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
        );
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Cleanup
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'open') {
      FlutterForegroundTask.launchApp("/");
    }
  }

  @override
  void onNotificationPressed() {
    // Open app when notification is tapped
    FlutterForegroundTask.launchApp("/");
  }
}

// ============ NOTIFICATION SERVICE ============
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._();
  
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  Future<void> init() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _localNotifications.initialize(initSettings);
      
      // Request Android 13+ notification permission
      if (Platform.isAndroid) {
        final plugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await plugin?.requestNotificationsPermission();
      }
      
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('⚠️ Notification service init failed (non-critical): $e');
      // Continue anyway
    }
  }
  
  Future<void> showClassReminder({
    required String subject,
    required String teacher,
    required String room,
    required String timeUntil,
  }) async {
    final bigText = BigTextStyleInformation(
      '$subject with $teacher in $room ($timeUntil)',
      contentTitle: '⏰ Class Starting',
      summaryText: 'IRIS',
    );
    final androidDetails = AndroidNotificationDetails(
      'class_reminder_channel',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      styleInformation: bigText,
      color: const Color(0xFF6366F1),
      colorized: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );
    
    final platformDetails = NotificationDetails(android: androidDetails);
    
    await _localNotifications.show(
      DateTime.now().millisecond,
      '⏰ Class Starting',
      '$subject with $teacher in $room ($timeUntil)',
      platformDetails,
      payload: 'class_reminder',
    );
  }
  
  // Schedule notifications for upcoming classes (run periodically)
  Future<void> scheduleClassReminders(List<ClassSession> sessions) async {
    final now = DateTime.now();
    
    for (final session in sessions) {
      // Parse time from session (e.g., "09:00")
      final parts = session.startTime.split(':');
      if (parts.length != 2) continue;
      
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      
      // Get day offset for class day
      final dayDiff = session.dayIndex - now.weekday;
      final classDateTime = now.add(Duration(days: dayDiff)).copyWith(
        hour: hour,
        minute: minute,
        second: 0,
        millisecond: 0,
      );
      
      // Schedule notification 5 minutes before class
      final notifyTime = classDateTime.subtract(const Duration(minutes: 5));
      
      if (notifyTime.isAfter(now)) {
        try {
          final bigText = BigTextStyleInformation(
            '${session.subject} with ${session.teacher} in ${session.room}',
            contentTitle: '⏰ Class in 5 minutes',
            summaryText: 'IRIS',
          );
          final androidDetails = AndroidNotificationDetails(
            'class_reminder_channel',
            'Class Reminders',
            channelDescription: 'Notifications for upcoming classes',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            styleInformation: bigText,
            color: const Color(0xFF6366F1),
            colorized: true,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
          );
          
          final platformDetails = NotificationDetails(android: androidDetails);
          
          await _localNotifications.zonedSchedule(
            session.id.hashCode,
            '⏰ Class in 5 minutes',
            '${session.subject} with ${session.teacher} in ${session.room}',
            tz.TZDateTime.from(notifyTime, tz.local),
            platformDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: 
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          // Silently handle scheduling errors
        }
      }
    }
  }

  // Update persistent notification showing current/next class
  // Update persistent notification showing current/next class
  Future<void> updatePersistentNotification({
    required String title,
    required String body,
    bool isOngoing = true,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'persistent_class_channel',
        'Current Class',
        channelDescription: 'Shows current or next class information',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        enableVibration: false,
        playSound: false,
        ongoing: true, // Always ongoing to prevent dismissal
        autoCancel: false, // Never auto-cancel
        showWhen: true, // Show timestamp
        usesChronometer: false,
        color: const Color(0xFF6366F1), // Brand color
        colorized: false,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
        ticker: title, // For accessibility
      );
      
      final platformDetails = NotificationDetails(android: androidDetails);
      
      await _localNotifications.show(
        999, // Fixed ID for persistent notification
        title,
        body,
        platformDetails,
        payload: 'persistent_class',
      );
    } catch (e) {
      debugPrint('⚠️ Persistent notification update failed: $e');
    }
  }

  // Dismiss persistent notification
  Future<void> dismissPersistentNotification() async {
    try {
      await _localNotifications.cancel(999);
    } catch (e) {
      debugPrint('⚠️ Failed to dismiss persistent notification: $e');
    }
  }
  
  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone database
  tz.initializeTimeZones();
  
  // Initialize Home Widget service (bulletproof init)
  await WidgetService.initialize();
  await WidgetService.initializeWidgetDefaults();
  
  // Initialize notifications
  await NotificationService().init();
  
  // Initialize foreground task
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'persistent_class_foreground',
      channelName: 'IRIS Class Tracker',
      channelDescription: 'Shows your current and upcoming classes',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(30000), // Update every 30 seconds
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );

  // Restore persistent notification service on launch if enabled.
  final prefs = await SharedPreferences.getInstance();
  final persistentEnabled = prefs.getBool('persistent_notification_enabled') ?? false;
  if (persistentEnabled && !(await FlutterForegroundTask.isRunningService)) {
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
  
  // Enable immersive mode for smooth high refresh rate experience
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  runApp(const IrisApp());
}

class IrisApp extends StatefulWidget {
  const IrisApp({super.key});

  @override
  State<IrisApp> createState() => _IrisAppState();
}

class _IrisAppState extends State<IrisApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemSound.play(SystemSoundType.click);
    });
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('themeMode') ?? 'system';
    setState(() {
      _themeMode = mode == 'dark'
          ? ThemeMode.dark
          : mode == 'light'
              ? ThemeMode.light
              : ThemeMode.system;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final next = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await prefs.setString('themeMode', next == ThemeMode.dark ? 'dark' : 'light');
    setState(() => _themeMode = next);
  }

  @override
  Widget build(BuildContext context) {
    // Set system overlay styles based on theme
    final isDark = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
    return MaterialApp(
      title: 'IRIS',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const SmoothScrollBehavior(),
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFFF7F8FF),
        fontFamily: 'SF Pro Display',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        splashColor: const Color(0xFF6366F1).withOpacity(0.06),
        highlightColor: const Color(0xFF6366F1).withOpacity(0.04),
        dividerColor: Colors.black.withOpacity(0.06),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF818CF8),
        scaffoldBackgroundColor: const Color(0xFF0D0B1B),
        brightness: Brightness.dark,
        fontFamily: 'SF Pro Display',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        splashColor: const Color(0xFF818CF8).withOpacity(0.10),
        highlightColor: const Color(0xFF818CF8).withOpacity(0.06),
        dividerColor: Colors.white.withOpacity(0.08),
      ),
      home: FutureBuilder<UniversityMemory>(
        future: UniversityMemoryLoader.loadFromAssets(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _BootScreen();
          }
          return _AppRoot(
            memory: snapshot.data!,
            onToggleTheme: _toggleTheme,
          );
        },
      ),
    );
  }
}

class _BootScreen extends StatefulWidget {
  const _BootScreen();

  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for glow effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotation animation for rings
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          _NeuralAura(background: isDark),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo container with pulsing aura and rotating rings
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsing ring
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.35),
                              blurRadius: 32,
                              spreadRadius: 12,
                            ),
                            BoxShadow(
                              color: const Color(0xFF818CF8).withOpacity(0.20),
                              blurRadius: 48,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Rotating rings
                    RotationTransition(
                      turns: _rotateAnimation,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    
                    RotationTransition(
                      turns: Tween<double>(begin: 0, end: -1).animate(
                        CurvedAnimation(parent: _rotateController, curve: Curves.linear),
                      ),
                      child: Container(
                        width: 105,
                        height: 105,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF818CF8).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    
                    // Main logo container
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF818CF8),
                              Color(0xFF8B5CF6),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.55),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/iris_logo.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFF818CF8),
                      Color(0xFFFFFFFF),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'IRIS',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6.0,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'INTELLIGENT ROUTINE & INSIGHT SYSTEM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3.0,
                    color: (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white : Colors.black).withOpacity(0.40),
                  ),
                ),
                const SizedBox(height: 44),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF818CF8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  final UniversityMemory memory;
  final VoidCallback onToggleTheme;

  const _AppRoot({
    required this.memory,
    required this.onToggleTheme,
  });

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final OmniBrain _brain;
  String? _selectedBatch;

  @override
  void initState() {
    super.initState();
    _brain = OmniBrain(widget.memory);
    _loadBatch();
    
    // Show Darood e Pak reminder on app boot with haptic pulse
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.lightImpact();
      _showDaroodePakDialog();
    });
  }
  
  void _showDaroodePakDialog() {
    // Pick a contextual Islamic greeting based on time of day
    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? 'Start your morning with blessings'
        : hour >= 12 && hour < 17
            ? 'Afternoon reminder for Darood'
            : hour >= 17 && hour < 21
                ? 'Evening blessings upon the Prophet'
                : 'Night reminder — send Darood e Pak';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF34D399)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.mosque_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'صلى الله عليه وسلم',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.80),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.favorite_rounded,
                size: 16,
                color: Colors.white.withOpacity(0.5),
              ),
            ],
          ),
        ),
        backgroundColor: isDark
            ? const Color(0xFF0F2E23)
            : const Color(0xFF10B981),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFF10B981).withOpacity(isDark ? 0.4 : 0.0),
            width: 1.2,
          ),
        ),
        elevation: 8,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Future<void> _loadBatch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedBatch = prefs.getString('selectedBatch');
    });
  }

  Future<void> _saveBatch(String batch) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBatch', batch);
    setState(() => _selectedBatch = batch);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedBatch == null) {
      return SetupBot(
        memory: widget.memory,
        onComplete: _saveBatch,
      );
    }

    return Dashboard(
      memory: widget.memory,
      brain: _brain,
      batch: _selectedBatch!,
      onToggleTheme: widget.onToggleTheme,
      onChangeBatch: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => BatchSelectorSheet(memory: widget.memory, selected: _selectedBatch!),
        );
        if (result != null && result != _selectedBatch) {
          await _saveBatch(result);
          HapticFeedback.selectionClick();
        }
      },
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _persistentNotificationEnabled = prefs.getBool('persistent_notification_enabled') ?? false;
    });
  }

  Future<void> _togglePersistentNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('persistent_notification_enabled', value);
    setState(() {
      _persistentNotificationEnabled = value;
    });
    
    if (!value) {
      // Stop foreground service when disabled
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } else {
      // Start foreground service when enabled
      if (!(await FlutterForegroundTask.isRunningService)) {
        // Store default values for first time
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
    
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final programs = widget.memory.programs();
    final semesters = _program == null ? <int>[] : widget.memory.semesters(_program!);
    final sections = (_program != null && _semester != null)
        ? widget.memory.sections(_program!, _semester!)
        : <String>[];

    return Scaffold(
      body: Stack(
        children: [
          _NeuralAura(background: Theme.of(context).brightness == Brightness.dark),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6366F1).withOpacity(0.30),
                              const Color(0xFF818CF8).withOpacity(0.24),
                              const Color(0xFFA5B4FC).withOpacity(0.18),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.5),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.20),
                              blurRadius: 12,
                              spreadRadius: 0,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF818CF8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withOpacity(0.4),
                                    blurRadius: 6,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Neural Setup Bot',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Configure your academic profile',
                                      style: TextStyle(
                                        fontSize: 13,
                                        letterSpacing: 0.3,
                                        color: Colors.white.withOpacity(0.7),
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
                    Text(
                      'Choose your program, semester, and section to sync the brain.',
                      style: TextStyle(
                        fontSize: 15,
                        letterSpacing: 0.2,
                        height: 1.4,
                        color: (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.7)
                            : Colors.black.withOpacity(0.6)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SelectorCard(
                      label: 'Program',
                      options: programs,
                      selected: _program,
                      onSelected: (value) => setState(() {
                        _program = value;
                        _semester = null;
                        _section = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _SelectorCard(
                      label: 'Semester',
                      options: semesters.map((e) => e.toString()).toList(),
                      selected: _semester?.toString(),
                      onSelected: (value) => setState(() {
                        _semester = int.tryParse(value ?? '');
                        _section = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _SelectorCard(
                      label: 'Section',
                      options: sections,
                      selected: _section,
                      onSelected: (value) => setState(() => _section = value),
                    ),
                    const SizedBox(height: 24),
                    
                    // Persistent Notification Toggle
                    GlassCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _persistentNotificationEnabled
                                    ? [const Color(0xFF6366F1), const Color(0xFF818CF8)]
                                    : [
                                        (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.10),
                                        (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _persistentNotificationEnabled
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_off_rounded,
                              color: _persistentNotificationEnabled
                                  ? Colors.white
                                  : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.5),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Class Tracker',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _persistentNotificationEnabled
                                      ? 'Progress bar & schedule in status bar'
                                      : 'Show class info in notification bar',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white.withOpacity(0.5)
                                        : Colors.black.withOpacity(0.5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _persistentNotificationEnabled,
                            onChanged: _togglePersistentNotification,
                            activeColor: const Color(0xFF6366F1),
                            activeTrackColor: const Color(0xFF6366F1).withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    Builder(
                      builder: (context) {
                        final isReady = _program != null && _semester != null && _section != null;
                        final isDarkBtn = Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: isReady
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFF818CF8),
                                    ],
                                  )
                                : null,
                            color: !isReady
                                ? (isDarkBtn
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.black.withOpacity(0.06))
                                : null,
                            borderRadius: BorderRadius.circular(16),
                            border: !isReady
                                ? Border.all(
                                    color: isDarkBtn
                                        ? Colors.white.withOpacity(0.10)
                                        : Colors.black.withOpacity(0.10),
                                  )
                                : null,
                            boxShadow: isReady
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withOpacity(0.4),
                                      blurRadius: 6,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed: isReady
                                ? () {
                                    final batch = widget.memory
                                        .allBatches
                                        .firstWhere((b) {
                                          final key = BatchKey.parse(b);
                                          return key.program == _program &&
                                              key.semester == _semester &&
                                              key.section == _section;
                                        }, orElse: () => widget.memory.allBatches.first);
                                    widget.onComplete(batch);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: isReady
                                  ? Colors.white
                                  : (isDarkBtn ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.35)),
                              disabledForegroundColor: isDarkBtn
                                  ? Colors.white.withOpacity(0.30)
                                  : Colors.black.withOpacity(0.30),
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              minimumSize: const Size.fromHeight(56),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.rocket_launch_rounded, size: 22),
                                SizedBox(width: 10),
                                Text('Sync My Batch'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _SelectorCard extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _SelectorCard({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.45),
                ),
              ),
              if (selected != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    selected!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options
                .map((opt) => ChoiceChip(
                      label: Text(
                        opt,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      selected: selected == opt,
                      onSelected: (_) => onSelected(opt),
                      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                      selectedColor: const Color(0xFF6366F1).withOpacity(0.18),
                      side: BorderSide(
                        color: selected == opt
                            ? const Color(0xFF6366F1).withOpacity(0.5)
                            : isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.10),
                        width: 1.2,
                      ),
                      labelStyle: TextStyle(
                        color: selected == opt
                            ? const Color(0xFF6366F1)
                            : isDark ? Colors.white.withOpacity(0.85) : Colors.black.withOpacity(0.7),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  final UniversityMemory memory;
  final OmniBrain brain;
  final String batch;
  final VoidCallback onToggleTheme;
  final VoidCallback onChangeBatch;

  const Dashboard({
    required this.memory,
    required this.brain,
    required this.batch,
    required this.onToggleTheme,
    required this.onChangeBatch,
    super.key,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late Timer _ticker;
  ClassSession? _previousClass;
  int? _overrideDayIndex;
  List<ClassSession> _cachedSchedule = [];
  DateTime? _lastScheduleUpdate;
  int? _lastMinute;
  int _scheduleFilter = 0; // 0=all, 1=live, 2=upcoming


  @override
  void initState() {
    super.initState();
    _updateScheduleCache();
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
          });
        }
        _updatePersistentNotificationIfNeeded();
        _updateWidgetIfNeeded();
      }
    });
    _updatePersistentNotificationIfNeeded();
    _updateWidgetIfNeeded();
    
    // Check for app updates after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      _checkForUpdates();
    });
  }

  /// Check for available app updates from GitHub
  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    
    try {
      final update = await UpdateService.checkForUpdates();
      if (update != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: !update.isRequired,
          builder: (context) => UpdateDialog(
            update: update,
            onDismiss: () => Navigator.pop(context),
          ),
        );
      }
    } catch (e) {
      print('Update check error: $e');
    }
  }

  Future<void> _startForegroundServiceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationEnabled = prefs.getBool('persistent_notification_enabled') ?? false;
    
    if (notificationEnabled) {
      // Check if service is already running
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) {
        await _startForegroundService();
      }
    }
  }

  Future<void> _startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    // Store timetable data for TaskHandler to use
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_batch', widget.batch);
    
    // Serialize timetable data
    final timetableData = {
      'sessions': widget.memory.sessions.map((s) => s.toJson()).toList(),
    };
    await prefs.setString('timetable_data', jsonEncode(timetableData));
    
    // Schedule 5-minute reminders for today's classes
    final todayClasses = widget.memory.sessions
        .where((s) => 
            s.batchKey.batch == widget.batch && 
            s.dayIndex == DateTime.now().weekday)
        .toList();
    
    if (todayClasses.isNotEmpty) {
      await NotificationService().scheduleClassReminders(todayClasses);
    }
    
    // Calculate initial notification
    final now = DateTime.now();
    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);
    final currentTime = now.hour + (now.minute / 60.0);
    final dayIndex = now.weekday;
    
    // Visual progress bar
    String _bar(double p) {
      final f = (p * 10).round().clamp(0, 10);
      return '\u2593' * f + '\u2591' * (10 - f);
    }
    
    final todayAll = widget.memory.sessions
        .where((s) => s.batchKey.batch == widget.batch && s.dayIndex == dayIndex)
        .toList();
    
    String notifTitle = 'IRIS Class Tracker';
    String notifBody = 'Keeping your class schedule handy';
    
    if (current != null && current.isLive(now)) {
      final duration = current.safeEndVal - current.safeStartVal;
      final progress = ((currentTime - current.safeStartVal) / duration).clamp(0.0, 1.0);
      final progressPercent = (progress * 100).toInt();
      
      final minutesRemaining = ((current.safeEndVal - currentTime) * 60).round();
      final hoursRemaining = minutesRemaining ~/ 60;
      final minsRemaining = minutesRemaining % 60;
      
      String timeLeft = hoursRemaining > 0
          ? '${hoursRemaining}h ${minsRemaining}m left'
          : minsRemaining > 0 ? '${minsRemaining}m left' : 'Ending now';
      
      final remaining = todayAll.where((s) => s.safeStartVal > currentTime).length;
      final classCount = remaining > 0 ? ' · $remaining more today' : ' · Last one';
      
      notifTitle = '🎓 ${current.subject} · $timeLeft';
      notifBody = '${_bar(progress)} $progressPercent%$classCount\n📍 ${current.room} · ${current.teacher}';
      
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
      
      final remainingToday = todayAll.where((s) => s.safeStartVal > currentTime).length;
      
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
      notificationButtons: [],
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
      // Get today's classes for the student's batch
      final todayClasses = widget.memory.sessions
          .where((s) => 
              s.batchKey.batch == widget.batch && 
              s.dayIndex == DateTime.now().weekday)
          .toList();
      
      if (todayClasses.isNotEmpty) {
        NotificationService().scheduleClassReminders(todayClasses);
      }
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

  Future<void> _updatePersistentNotificationIfNeeded() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final notificationEnabled = prefs.getBool('persistent_notification_enabled') ?? false;
    
    if (!notificationEnabled) return;
    
    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);
    final currentTime = now.hour + (now.minute / 60.0);
    final dayIndex = now.weekday;
    
    // Visual progress bar
    String _bar(double p) {
      final f = (p * 10).round().clamp(0, 10);
      return '\u2593' * f + '\u2591' * (10 - f);
    }
    
    final todayAll = widget.memory.sessions
        .where((s) => s.batchKey.batch == widget.batch && s.dayIndex == dayIndex)
        .toList();
    
    try {
      String notifTitle = '';
      String notifBody = '';
      
      if (current != null && current.isLive(now)) {
        final duration = current.safeEndVal - current.safeStartVal;
        final progress = ((currentTime - current.safeStartVal) / duration).clamp(0.0, 1.0);
        final progressPercent = (progress * 100).toInt();
        
        final minutesRemaining = ((current.safeEndVal - currentTime) * 60).round();
        final hoursRemaining = minutesRemaining ~/ 60;
        final minsRemaining = minutesRemaining % 60;
        
        String timeLeft = hoursRemaining > 0
            ? '${hoursRemaining}h ${minsRemaining}m left'
            : minsRemaining > 0 ? '${minsRemaining}m left' : 'Ending now';
        
        final remaining = todayAll.where((s) => s.safeStartVal > currentTime).length;
        final classCount = remaining > 0 ? ' · $remaining more today' : ' · Last one';
        
        notifTitle = '🎓 ${current.subject} · $timeLeft';
        notifBody = '${_bar(progress)} $progressPercent%$classCount\n📍 ${current.room} · ${current.teacher}';
        
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
        
        final remainingToday = todayAll.where((s) => s.safeStartVal > currentTime).length;
        
        // Break info
        String breakInfo = '';
        if (daysAhead == 0) {
          final prevClasses = todayAll.where((s) => s.safeEndVal <= currentTime).toList();
          if (prevClasses.isNotEmpty) {
            prevClasses.sort((a, b) => b.safeEndVal.compareTo(a.safeEndVal));
            final breakMins = ((next.safeStartVal - prevClasses.first.safeEndVal) * 60).round();
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
            NotificationButton(id: 'open', text: 'Open IRIS'),
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
          final duration = current.safeEndVal - current.safeStartVal;
          final progress = ((currentTime - current.safeStartVal) / duration).clamp(0.0, 1.0);
          progressPercent = (progress * 100).toInt();
        }
      }
      
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

  Future<void> _openPortal() async {
    if (!mounted) return;
    
    HapticFeedback.mediumImpact();
    
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const PortalScreen(
          url: 'https://swl-sis.comsats.edu.pk/Login/Index',
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Smooth entrance slide from bottom
          var slideTween = Tween<Offset>(
            begin: const Offset(0.0, 0.08),
            end: Offset.zero,
          );
          var slideAnimation = slideTween.animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );
          
          // Fade in smoothly from 0.8 to 1.0 for subtlety
          var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
          var fadeAnimation = fadeTween.animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
            ),
          );
          
          // Subtle scale down start then smooth expansion
          var scaleTween = Tween<double>(begin: 0.97, end: 1.0);
          var scaleAnimation = scaleTween.animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
            ),
          );
          
          // Rotation twist for personality
          var rotationTween = Tween<double>(begin: 0.003, end: 0.0);
          var rotationAnimation = rotationTween.animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );
          
          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: Transform.rotate(
                  angle: rotationAnimation.value,
                  child: child,
                ),
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  Future<void> _openAbout() async {
    if (!mounted) return;
    
    HapticFeedback.mediumImpact();
    
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AboutScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
          var fadeAnimation = fadeTween.animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
          );
          
          var scaleTween = Tween<double>(begin: 0.95, end: 1.0);
          var scaleAnimation = scaleTween.animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );
    
    // Widget updates automatically via ticker - no manual refresh needed
  }



  void _openDepartmentClassesBrowser() {
    if (!mounted) return;
    
    HapticFeedback.mediumImpact();
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            _DepartmentClassesScreen(
              memory: widget.memory,
              currentBatch: widget.batch,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
          var fadeAnimation = fadeTween.animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
          );
          
          var scaleTween = Tween<double>(begin: 0.92, end: 1.0);
          var scaleAnimation = scaleTween.animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _openTeacherSearch() {
    if (!mounted) return;
    
    HapticFeedback.mediumImpact();
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            _TeacherLocatorScreen(brain: widget.brain),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
          var fadeAnimation = fadeTween.animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
          );
          
          var scaleTween = Tween<double>(begin: 0.92, end: 1.0);
          var scaleAnimation = scaleTween.animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );
          
          var slideTween = Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero);
          var slideAnimation = slideTween.animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final dateLabel = _formatDateLabel(now);
    final insight = widget.brain.buildTemporalInsight(widget.batch, now);
    
    // Update cache if day changed or schedule is empty
    if (_lastScheduleUpdate == null || 
        _lastScheduleUpdate!.day != now.day ||
        _cachedSchedule.isEmpty) {
      _updateScheduleCache();
    }
    final schedule = _cachedSchedule;
    final filteredSchedule = _applyScheduleFilter(schedule, now);

    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            child: _NeuralAura(background: isDark),
          ),
          SafeArea(
            child: CustomScrollView(
              cacheExtent: 500, // Preload items 500px ahead
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: GlassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onChangeBatch,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF6366F1),
                                              Color(0xFF818CF8),
                                              Color(0xFFA78BFA),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF6366F1).withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.asset(
                                              'assets/iris_logo.png',
                                              width: 11,
                                              height: 11,
                                              fit: BoxFit.cover,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'IRIS',
                                              style: const TextStyle(
                                                letterSpacing: 2.5,
                                                fontSize: 9,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _getSmartGreeting(now.hour),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.8,
                                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.12)
                                            : Colors.black.withOpacity(0.08),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 12,
                                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          dateLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.batch,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Icon(
                                          Icons.swap_horiz_rounded,
                                          size: 16,
                                          color: const Color(0xFF6366F1).withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: (isDark
                                      ? Colors.white
                                      : const Color(0xFF6366F1))
                                  .withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (isDark ? Colors.white : const Color(0xFF6366F1))
                                    .withOpacity(0.12),
                              ),
                            ),
                            child: IconButton(
                              onPressed: widget.onToggleTheme,
                              icon: Icon(
                                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                size: 22,
                                color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF6366F1),
                              ),
                              padding: const EdgeInsets.all(10),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 14),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GlassCard(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final offset = Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(position: offset, child: child),
                          );
                        },
                        child: Column(
                          key: ValueKey('${insight.headline}-${insight.subline}'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Icon with optional live pulse ring
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (insight.isLive)
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF10B981).withOpacity(0.30),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: insight.isUrgent
                                              ? [const Color(0xFFEF4444), const Color(0xFFFCA5A5)]
                                              : insight.isLive
                                                  ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                                                  : [const Color(0xFF6366F1), const Color(0xFF818CF8)],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (insight.isUrgent
                                                    ? const Color(0xFFEF4444)
                                                    : insight.isLive
                                                        ? const Color(0xFF10B981)
                                                        : const Color(0xFF6366F1))
                                                .withOpacity(0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        insight.isUrgent
                                            ? Icons.notifications_active
                                            : insight.isLive
                                                ? Icons.play_circle_outline_rounded
                                                : Icons.insights_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        insight.headline,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17,
                                          letterSpacing: 0.3,
                                          height: 1.2,
                                          color: insight.isLive ? const Color(0xFF10B981) : null,
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
                                                ? const Color(0xFFEF4444)
                                                : insight.isLive
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFF6366F1),
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
                                  margin: const EdgeInsets.only(top: 2, right: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: insight.isLive
                                        ? const Color(0xFF10B981).withOpacity(0.4)
                                        : const Color(0xFF6366F1).withOpacity(0.3),
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
                                          ? Colors.white.withOpacity(0.72)
                                          : Colors.black.withOpacity(0.55)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (insight.teacherInfo != null && insight.teacherInfo!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.10)
                                        : Colors.black.withOpacity(0.06),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 12,
                                        color: const Color(0xFF6366F1).withOpacity(0.8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        insight.teacherInfo!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _ActionsMenuCard(
                      onPortalTap: _openPortal,
                      onTeacherSearchTap: _openTeacherSearch,
                      onBrowseClassesTap: _openDepartmentClassesBrowser,
                      onAboutTap: _openAbout,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: _DaySwitcher(
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: SectionHeader(
                      title: _timelineTitle(schedule, now, _overrideDayIndex),
                      subtitle: _timelineSubtitle(schedule, now, _overrideDayIndex),
                      statusIndicator: _getTimelineStatusColor(widget.brain, widget.batch, now),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  sliver: filteredSchedule.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                            child: GlassCard(
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF6366F1).withOpacity(0.12),
                                          const Color(0xFF818CF8).withOpacity(0.06),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.beach_access_rounded,
                                      size: 32,
                                      color: const Color(0xFF6366F1).withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _scheduleFilter == 0
                                        ? 'No classes scheduled'
                                        : 'No matches for this filter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _scheduleFilter == 0
                                        ? 'Enjoy your free time! 🎉'
                                        : 'Try another filter for today',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.45),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
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
                              final nextSession = (fullIndex >= 0 && fullIndex + 1 < schedule.length)
                                  ? schedule[fullIndex + 1]
                                  : null;
                              return RepaintBoundary(
                                child: _ClassCard(
                                  key: ValueKey('class_${session.subject}_${session.startTime}'),
                                  session: session,
                                  nextSession: nextSession,
                                ),
                              );
                            },
                            childCount: filteredSchedule.length,
                            addAutomaticKeepAlives: true,
                            addRepaintBoundaries: true,
                          ),
                        ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            ),
          )
        ],
      ),
    );
  }

  List<ClassSession> _buildTimelineSchedule(DateTime now) {
    final schedule = _overrideDayIndex != null
        ? _scheduleForDay(widget.brain.scheduleFor(widget.batch), _overrideDayIndex!)
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

  List<ClassSession> _applyScheduleFilter(List<ClassSession> schedule, DateTime now) {
    if (_scheduleFilter == 0) return schedule;
    if (schedule.isEmpty) return schedule;
    if (_scheduleFilter == 1) {
      return schedule.where((s) => s.isLive(now)).toList();
    }
    final currentTime = now.hour + (now.minute / 60.0);
    return schedule
        .where((s) =>
            s.dayIndex == now.weekday && s.safeStartVal > currentTime)
        .toList();
  }

  String _timelineTitle(List<ClassSession> schedule, DateTime now, int? overrideDay) {
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

  String _timelineSubtitle(List<ClassSession> schedule, DateTime now, int? overrideDay) {
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
        final remaining = schedule.where((s) => s.safeStartVal > currentTime).length;
        final classesLeft = remaining > 0 ? '$remaining ${remaining == 1 ? 'class' : 'classes'} left' : 'Last class today';
        return '${current.subject} • $classesLeft';
      } else {
        // Between classes or before first class
        final nextClass = schedule.firstWhere(
          (s) => s.safeStartVal > currentTime,
          orElse: () => schedule.first,
        );
        
        if (nextClass.safeStartVal > currentTime) {
          final minutesUntil = ((nextClass.safeStartVal - currentTime) * 60).round();
          
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
      return '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} • ${_getDayName(dayIndex)}';
    }
    
    return 'Upcoming schedule';
  }
  
  String _getDayName(int day) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
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
      return const Color(0xFF10B981);
    }
    
    // Check if there's a class starting soon (within next 15 minutes)
    final schedule = brain.scheduleFor(batch);
    final currentTime = now.hour + (now.minute / 60.0);
    final upcomingSoon = schedule.where((s) =>
        s.dayIndex == now.weekday &&
        s.safeStartVal > currentTime &&
        s.safeStartVal - currentTime <= 0.25 // 15 minutes
    ).isNotEmpty;
    
    if (upcomingSoon) {
      // Blue - lectures about to start
      return const Color(0xFF3B82F6);
    }
    
    // Red - no active lectures
    return const Color(0xFFEF4444);
  }
}

class _DaySwitcher extends StatelessWidget {
  final int? selectedDayIndex;
  final ValueChanged<int?> onSelected;

  const _DaySwitcher({required this.selectedDayIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday; // 1=Mon
    return GlassCard(
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 13,
                      color: selectedDayIndex == null
                          ? const Color(0xFF6366F1)
                          : isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Auto',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                selected: selectedDayIndex == null,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onSelected(null);
                },
                selectedColor: const Color(0xFF6366F1).withOpacity(0.22),
                backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                side: BorderSide(
                  color: selectedDayIndex == null
                      ? const Color(0xFF6366F1).withOpacity(0.6)
                      : isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.12),
                  width: 1.5,
                ),
                labelStyle: TextStyle(
                  color: selectedDayIndex == null
                      ? const Color(0xFF6366F1)
                      : isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.65),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ...List.generate(days.length, (index) {
              final dayIndex = index + 1;
              final isSelected = selectedDayIndex == dayIndex;
              final isToday = dayIndex == today;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: ChoiceChip(
                    avatar: isToday && !isSelected
                        ? Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          )
                        : null,
                    label: Text(
                      days[index],
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      onSelected(dayIndex);
                    },
                    selectedColor: const Color(0xFF6366F1).withOpacity(0.22),
                    backgroundColor: isToday && !isSelected
                        ? (isDark ? Colors.white.withOpacity(0.11) : Colors.black.withOpacity(0.07))
                        : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF6366F1).withOpacity(0.6)
                          : isToday
                              ? const Color(0xFF10B981).withOpacity(0.35)
                              : isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.12),
                      width: 1.5,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.65),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _ClassCard extends StatefulWidget {
  final ClassSession session;
  final ClassSession? nextSession;

  const _ClassCard({super.key, required this.session, this.nextSession});

  @override
  State<_ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<_ClassCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final isLive = widget.session.isLive(now);
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    if (isLive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final live = widget.session.isLive(now);
    final currentTime = now.hour + (now.minute / 60.0);
    final isUpcoming = !live &&
        widget.session.dayIndex == now.weekday &&
        widget.session.safeStartVal > currentTime &&
        widget.session.safeStartVal - currentTime <= 0.75;

    // Calculate lecture duration (already accounts for merged consecutive slots)
    final duration = widget.session.safeEndVal - widget.session.safeStartVal;
    
    // Calculate progress and label based on actual lecture duration
    double progress = 0.0;
    String progressLabel = '';
    
    if (live) {
      // Always calculate progress across the entire merged lecture duration
      progress = ((currentTime - widget.session.safeStartVal) / duration).clamp(0.0, 1.0);
      final minutesLeft = ((widget.session.safeEndVal - currentTime) * 60).toInt();
      
      if (minutesLeft >= 60) {
        final hours = minutesLeft ~/ 60;
        final mins = minutesLeft % 60;
        progressLabel = mins > 0 ? '${hours}h ${mins}m left' : '${hours}h left';
      } else {
        progressLabel = '${minutesLeft}m left';
      }
    }
    
    final timeLabel = '${widget.session.startTime} - ${widget.session.endTime}';

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: live ? _pulseAnimation.value : 1.0,
            child: child,
          ),
          child: GlassCard(
        glow: live,
        shimmer: false,
        enableBlur: false,
        enableShadow: true,
        enableOverlay: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live indicator dot
                if (live)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 10),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    widget.session.subject,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 0.3,
                      height: 1.3,
                      color: live ? const Color(0xFF10B981) : null,
                    ),
                  ),
                ),
                if (live || isUpcoming) ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (live)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) => Container(
                            width: 46 * _pulseAnimation.value,
                            height: 22 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: const Color(0xFF10B981).withOpacity(0.10),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: live
                              ? const Color(0xFF10B981).withOpacity(0.16)
                              : const Color(0xFF3B82F6).withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: live
                                ? const Color(0xFF10B981).withOpacity(0.35)
                                : const Color(0xFF3B82F6).withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          live ? 'LIVE' : 'NEXT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: live ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: live
                          ? const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                            )
                          : LinearGradient(
                              colors: [
                                const Color(0xFF6366F1).withOpacity(
                                    Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.10),
                                const Color(0xFF818CF8).withOpacity(
                                    Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: live
                            ? const Color(0xFF6366F1).withOpacity(0.6)
                            : const Color(0xFF6366F1).withOpacity(
                                  Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.20),
                        width: 1.2,
                      ),
                      boxShadow: live
                          ? [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.30),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                        color: live ? Colors.white : const Color(0xFF6366F1).withOpacity(0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              ],
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.04)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 13,
                    color: const Color(0xFF6366F1).withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.session.room,
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w600,
                      color: (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.75)
                          : Colors.black.withOpacity(0.55)),
                    ),
                  ),
                ),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.35)
                        : Colors.black.withOpacity(0.2)),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.session.teacher,
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w500,
                      color: (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.60)
                          : Colors.black.withOpacity(0.45)),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (live && widget.nextSession != null &&
                widget.nextSession!.dayIndex == widget.session.dayIndex) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.fast_forward_rounded,
                      size: 12,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Next room: ${widget.nextSession!.room}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (live) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  tween: Tween<double>(begin: 0.0, end: progress),
                  builder: (context, value, child) => Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF818CF8),
                              Color(0xFFA78BFA),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 0,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    progressLabel,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6366F1).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final bool glow;
  final bool shimmer;
  final bool enableBlur;
  final bool enableShadow;
  final bool enableOverlay;

  const GlassCard({
    required this.child,
    this.glow = false,
    this.shimmer = false,
    this.enableBlur = true,
    this.enableShadow = true,
    this.enableOverlay = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardStack = Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Colors.white.withOpacity(0.14), Colors.white.withOpacity(0.08)]
                  : [Colors.white.withOpacity(0.70), Colors.white.withOpacity(0.55)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: glow
                  ? const Color(0xFF6366F1).withOpacity(0.7)
                  : isDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.white.withOpacity(0.40),
              width: 1.5,
            ),
            boxShadow: enableShadow
                ? (glow
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: const Color(0xFF818CF8).withOpacity(0.3),
                          blurRadius: 14,
                          spreadRadius: -4,
                        )
                      ]
                    : [
                        if (isDark)
                          BoxShadow(
                            color: Colors.white.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, -2),
                            spreadRadius: -4,
                          ),
                        BoxShadow(
                          color: isDark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.10),
                          blurRadius: isDark ? 16 : 12,
                          offset: const Offset(0, 10),
                          spreadRadius: -4,
                        ),
                        BoxShadow(
                          color: isDark
                              ? const Color(0xFF6366F1).withOpacity(0.10)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: isDark ? 22 : 18,
                          offset: const Offset(0, 16),
                          spreadRadius: -10,
                        )
                      ])
                : const [],
          ),
          child: child,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.35),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        if (shimmer)
          const Positioned.fill(
            child: _GlassShimmer(),
          ),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: cardStack,
    );
  }
}

class _GlassShimmer extends StatefulWidget {
  const _GlassShimmer();

  @override
  State<_GlassShimmer> createState() => _GlassShimmerState();
}

class _GlassShimmerState extends State<_GlassShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final shift = (_curve.value * 2) - 1;
            return FractionalTranslation(
              translation: Offset(shift, 0),
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color statusIndicator;

  const SectionHeader({required this.title, required this.subtitle, required this.statusIndicator, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 4,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  statusIndicator,
                  const Color(0xFF6366F1),
                  const Color(0xFF8B5CF6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: statusIndicator.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                        fontSize: 11,
                        height: 1.2,
                        color: isDark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.45),
                      ),
                    ),
                    const Spacer(),
                    // Status dot with ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: statusIndicator.withOpacity(0.25),
                              width: 1.5,
                            ),
                          ),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusIndicator,
                            boxShadow: [
                              BoxShadow(
                                color: statusIndicator.withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: isDark ? Colors.white.withOpacity(0.75) : Colors.black.withOpacity(0.6),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [
                        statusIndicator.withOpacity(0.4),
                        const Color(0xFF6366F1).withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsMenuCard extends StatelessWidget {
  final VoidCallback onPortalTap;
  final VoidCallback onTeacherSearchTap;
  final VoidCallback onBrowseClassesTap;
  final VoidCallback onAboutTap;

  const _ActionsMenuCard({
    required this.onPortalTap,
    required this.onTeacherSearchTap,
    required this.onBrowseClassesTap,
    required this.onAboutTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.35),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(Icons.apps_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: isDark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.language_rounded,
                  label: 'Portal',
                  accent: const Color(0xFF3B82F6),
                  onTap: onPortalTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.person_search_rounded,
                  label: 'Teacher',
                  accent: const Color(0xFF8B5CF6),
                  onTap: onTeacherSearchTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.school_rounded,
                  label: 'Classes',
                  accent: const Color(0xFF10B981),
                  onTap: onBrowseClassesTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.tune_rounded,
                  label: 'About',
                  accent: const Color(0xFFF59E0B),
                  onTap: onAboutTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_CompactActionButton> createState() => _CompactActionButtonState();
}

class _CompactActionButtonState extends State<_CompactActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _controller.forward().then((_) => _controller.reverse());
          widget.onTap();
        },
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      widget.accent.withOpacity(0.12),
                      widget.accent.withOpacity(0.05),
                    ]
                  : [
                      widget.accent.withOpacity(0.10),
                      widget.accent.withOpacity(0.04),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? widget.accent.withOpacity(0.22)
                  : widget.accent.withOpacity(0.20),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.accent.withOpacity(isDark ? 0.28 : 0.16),
                      widget.accent.withOpacity(isDark ? 0.14 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: widget.accent.withOpacity(0.15),
                            blurRadius: 8,
                            spreadRadius: -2,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  widget.icon,
                  color: widget.accent,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: isDark
                      ? Colors.white.withOpacity(0.85)
                      : Colors.black.withOpacity(0.70),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Timer? _revealTimer;
  bool _revealQuote = false;
  int _tapCount = 0;
  bool _persistentNotificationEnabled = false;
  bool _widgetDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
    _loadWidgetDarkModeSetting();
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _persistentNotificationEnabled = prefs.getBool('persistent_notification_enabled') ?? false;
    });
  }

  Future<void> _loadWidgetDarkModeSetting() async {
    final isDark = await WidgetService.getWidgetDarkMode();
    setState(() {
      _widgetDarkMode = isDark;
    });
  }

  Future<void> _togglePersistentNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('persistent_notification_enabled', value);
    setState(() {
      _persistentNotificationEnabled = value;
    });
    
    if (!value) {
      // Stop foreground service when disabled
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } else {
      // Start foreground service when enabled
      if (!(await FlutterForegroundTask.isRunningService)) {
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
    
    HapticFeedback.selectionClick();
  }

  Future<void> _toggleWidgetDarkMode(bool value) async {
    await WidgetService.setWidgetDarkMode(value);
    setState(() {
      _widgetDarkMode = value;
    });
    HapticFeedback.selectionClick();
  }

  void _registerRevealTap() {
    if (_revealQuote) return;
    _tapCount += 1;
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(seconds: 2), () {
      _tapCount = 0;
    });
    if (_tapCount >= 5) {
      _revealTimer?.cancel();
      _tapCount = 0;
      if (!mounted) return;
      setState(() {
        _revealQuote = true;
      });
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          _NeuralAura(background: isDark),
          SafeArea(
            child: ScrollConfiguration(
              behavior: const SmoothScrollBehavior(),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'About & Settings',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [Colors.white.withOpacity(0.14), Colors.white.withOpacity(0.07)]
                                : [Colors.white.withOpacity(0.90), Colors.white.withOpacity(0.75)],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.18)
                                : Colors.white.withOpacity(0.60),
                            width: isDark ? 1.5 : 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.5)
                                  : Colors.black.withOpacity(0.10),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                              spreadRadius: -4,
                            ),
                            if (isDark)
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.08),
                                blurRadius: 30,
                                spreadRadius: -6,
                              ),
                          ],
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF6366F1),
                                          Color(0xFF818CF8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF6366F1).withOpacity(0.45),
                                          blurRadius: 8,
                                          spreadRadius: 0,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.info_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                      GestureDetector(
                                        onTap: _registerRevealTap,
                                        child: Text(
                                          'Developed by Malik Aurangzaib Channer',
                                          style: TextStyle(
                                            fontSize: 13,
                                            letterSpacing: 0.2,
                                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_revealQuote) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.black.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        'assets/Alex_Jones.gif',
                                        height: 150,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '"Obstacles do not exist to be surrendered to, but only to be broken."\n― Adolf Hitler',
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          fontStyle: FontStyle.italic,
                                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      (isDark ? Colors.white : Colors.black).withOpacity(0.12),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF6366F1).withOpacity(0.15),
                                          const Color(0xFF818CF8).withOpacity(0.08),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.widgets_rounded,
                                      size: 16,
                                      color: const Color(0xFF6366F1).withOpacity(0.9),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'SETTINGS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 1.8,
                                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.45),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const SizedBox(height: 20),
                              // Persistent Notification Toggle
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _persistentNotificationEnabled
                                        ? [
                                            const Color(0xFF6366F1).withOpacity(isDark ? 0.12 : 0.08),
                                            const Color(0xFF818CF8).withOpacity(isDark ? 0.06 : 0.04),
                                          ]
                                        : isDark
                                            ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.04)]
                                            : [Colors.black.withOpacity(0.04), Colors.black.withOpacity(0.02)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _persistentNotificationEnabled
                                        ? const Color(0xFF6366F1).withOpacity(0.25)
                                        : isDark
                                            ? Colors.white.withOpacity(0.12)
                                            : Colors.black.withOpacity(0.08),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: _persistentNotificationEnabled
                                              ? [const Color(0xFF6366F1), const Color(0xFF818CF8)]
                                              : [
                                                  (isDark ? Colors.white : Colors.black).withOpacity(0.10),
                                                  (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                                                ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _persistentNotificationEnabled
                                            ? Icons.notifications_active_rounded
                                            : Icons.notifications_off_rounded,
                                        color: _persistentNotificationEnabled
                                            ? Colors.white
                                            : (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Live Class Tracker',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.9),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _persistentNotificationEnabled
                                                ? 'Showing progress bar & schedule in status bar'
                                                : 'Tap to show class info in notification bar',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _persistentNotificationEnabled,
                                      onChanged: _togglePersistentNotification,
                                      activeColor: const Color(0xFF6366F1),
                                      activeTrackColor: const Color(0xFF6366F1).withOpacity(0.3),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),
                              // Widget Dark Mode Toggle
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _widgetDarkMode
                                        ? [
                                            const Color(0xFF6366F1).withOpacity(isDark ? 0.12 : 0.08),
                                            const Color(0xFF818CF8).withOpacity(isDark ? 0.06 : 0.04),
                                          ]
                                        : isDark
                                            ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.04)]
                                            : [Colors.black.withOpacity(0.04), Colors.black.withOpacity(0.02)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _widgetDarkMode
                                        ? const Color(0xFF6366F1).withOpacity(0.25)
                                        : isDark
                                            ? Colors.white.withOpacity(0.12)
                                            : Colors.black.withOpacity(0.08),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: _widgetDarkMode
                                              ? [const Color(0xFF6366F1), const Color(0xFF818CF8)]
                                              : [
                                                  (isDark ? Colors.white : Colors.black).withOpacity(0.10),
                                                  (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                                                ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _widgetDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                        color: _widgetDarkMode
                                            ? Colors.white
                                            : (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Widget Dark Mode',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.9),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _widgetDarkMode
                                                ? 'Widget uses dark colors'
                                                : 'Widget uses light colors',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _widgetDarkMode,
                                      onChanged: _toggleWidgetDarkMode,
                                      activeColor: const Color(0xFF6366F1),
                                      activeTrackColor: const Color(0xFF6366F1).withOpacity(0.3),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.12)
                                            : Colors.black.withOpacity(0.08),
                                      ),
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.white.withOpacity(0.07)
                                        : Colors.black.withOpacity(0.03),
                                  ),
                                  child: Text(
                                    'Close',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      letterSpacing: 0.3,
                                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BatchSelectorSheet extends StatefulWidget {
  final UniversityMemory memory;
  final String selected;

  const BatchSelectorSheet({required this.memory, required this.selected, super.key});

  @override
  State<BatchSelectorSheet> createState() => _BatchSelectorSheetState();
}

class _BatchSelectorSheetState extends State<BatchSelectorSheet> {
  String? program;
  int? semester;
  String? section;

  @override
  void initState() {
    super.initState();
    final key = BatchKey.parse(widget.selected);
    program = key.program;
    semester = key.semester;
    section = key.section;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final programs = widget.memory.programs();
    final semesters = program == null ? <int>[] : widget.memory.semesters(program!);
    final sections = (program != null && semester != null)
        ? widget.memory.sections(program!, semester!)
        : <String>[];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Colors.white.withOpacity(0.14), Colors.white.withOpacity(0.07)]
                  : [Colors.white.withOpacity(0.80), Colors.white.withOpacity(0.60)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.70),
              width: isDark ? 1.5 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(isDark ? 0.20 : 0.15),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: (isDark ? Colors.black : Colors.black.withOpacity(0.5)).withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: -10,
                offset: const Offset(0, 20),
              ),
              if (isDark)
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  blurRadius: 30,
                  spreadRadius: -6,
                ),
            ],
          ),
          child: Stack(
              children: [
                Positioned(
                  top: -12,
                  left: -12,
                  child: IgnorePointer(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(isDark ? 0.16 : 0.24),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -16,
                  right: -16,
                  child: IgnorePointer(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(isDark ? 0.14 : 0.20),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFF818CF8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Batch Resolver',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Configure your academic profile',
                            style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 0.3,
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _EnhancedDropDownRow(
                  label: 'Program',
                  value: program,
                  items: programs,
                  icon: Icons.school_rounded,
                  onChanged: (value) => setState(() {
                    program = value;
                    semester = null;
                    section = null;
                  }),
                ),
                const SizedBox(height: 12),
                _EnhancedDropDownRow(
                  label: 'Semester',
                  value: semester?.toString(),
                  items: semesters.map((e) => e.toString()).toList(),
                  icon: Icons.calendar_month_rounded,
                  onChanged: (value) => setState(() {
                    semester = int.tryParse(value ?? '');
                    section = null;
                  }),
                ),
                const SizedBox(height: 12),
                _EnhancedDropDownRow(
                  label: 'Section',
                  value: section,
                  items: sections,
                  icon: Icons.group_rounded,
                  onChanged: (value) => setState(() => section = value),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: (program != null && semester != null && section != null)
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF818CF8),
                                  ],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: (program != null && semester != null && section != null)
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withOpacity(0.4),
                                    blurRadius: 5,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: ElevatedButton(
                          onPressed: (program != null && semester != null && section != null)
                              ? () {
                                  final batch = widget.memory.allBatches.firstWhere((b) {
                                    final key = BatchKey.parse(b);
                                    return key.program == program &&
                                        key.semester == semester &&
                                        key.section == section;
                                  }, orElse: () => widget.selected);
                                  Navigator.pop(context, batch);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.08),
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Apply Changes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _EnhancedDropDownRow extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _EnhancedDropDownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.black.withOpacity(0.10),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black.withOpacity(0.5)).withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF6366F1),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                hint: Text(
                  'Select',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                items: items
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeuralAura extends StatelessWidget {
  final bool background;

  const _NeuralAura({required this.background});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        // Base gradient — deeper, richer
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: background
                  ? [
                      const Color(0xFF0B0A14),
                      const Color(0xFF111021),
                      const Color(0xFF15132A),
                      const Color(0xFF101021),
                    ]
                  : [
                      const Color(0xFFF7F8FF),
                      const Color(0xFFF1F3FF),
                      const Color(0xFFF6F4FF),
                      const Color(0xFFFFF7F4),
                      const Color(0xFFFBF7F2),
                      const Color(0xFFF4F6FF),
                    ],
              stops: background ? const [0.0, 0.45, 0.7, 1.0] : const [0.0, 0.15, 0.35, 0.55, 0.78, 1.0],
            ),
          ),
        ),

        if (background)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(0.08),
              ),
            ),
          ),
        
        if (!background)
          Positioned(
            top: -160,
            left: -120,
            child: _AuraBlob(
              colors: [
                const Color(0xFF6366F1).withOpacity(0.14),
                const Color(0xFF818CF8).withOpacity(0.08),
                const Color(0xFFA5B4FC).withOpacity(0.03),
              ],
              size: 460,
            ),
          ),
        
        if (!background)
          Positioned(
            top: -60,
            right: -100,
            child: _AuraBlob(
              colors: [
                const Color(0xFFF472B6).withOpacity(0.10),
                const Color(0xFFEC4899).withOpacity(0.05),
                const Color(0xFFFDA4AF).withOpacity(0.02),
              ],
              size: 320,
            ),
          ),
        
        // Bottom-right — deep purple
        if (!background)
          Positioned(
            bottom: -140,
            right: -120,
            child: _AuraBlob(
              colors: [
                const Color(0xFF8B5CF6).withOpacity(0.12),
                const Color(0xFFA78BFA).withOpacity(0.06),
                const Color(0xFFC4B5FD).withOpacity(0.03),
              ],
              size: 500,
            ),
          ),
        
        if (!background)
          Positioned(
            top: h * 0.32,
            right: -90,
            child: _AuraBlob(
              colors: [
                const Color(0xFFFBBF24).withOpacity(0.07),
                const Color(0xFFF59E0B).withOpacity(0.04),
                const Color(0xFFFCD34D).withOpacity(0.02),
              ],
              size: 300,
            ),
          ),
        
        if (!background)
          Positioned(
            bottom: h * 0.12,
            left: -80,
            child: _AuraBlob(
              colors: [
                const Color(0xFF14B8A6).withOpacity(0.08),
                const Color(0xFF34D399).withOpacity(0.04),
                const Color(0xFF6EE7B7).withOpacity(0.02),
              ],
              size: 320,
            ),
          ),
        
        if (!background)
          Positioned(
            top: h * 0.18,
            left: w * 0.25,
            child: _AuraBlob(
              colors: [
                const Color(0xFF3B82F6).withOpacity(0.05),
                const Color(0xFF60A5FA).withOpacity(0.03),
                const Color(0xFF93C5FD).withOpacity(0.01),
              ],
              size: 240,
            ),
          ),
        
        if (!background)
          Positioned(
            top: h * 0.6,
            left: w * 0.4,
            child: _AuraBlob(
              colors: [
                const Color(0xFF7C3AED).withOpacity(0.06),
                const Color(0xFF8B5CF6).withOpacity(0.03),
                const Color(0xFFA78BFA).withOpacity(0.01),
              ],
              size: 260,
            ),
          ),

        // Subtle grain/noise overlay for depth
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    (background ? Colors.black : Colors.white).withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SmoothScrollBehavior extends MaterialScrollBehavior {
  const SmoothScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use platform-native physics for better performance
    // Android: ClampingScrollPhysics (native feel, better performance)
    // iOS/macOS: BouncingScrollPhysics (native feel)
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        );
      case TargetPlatform.android:
      default:
        return const ClampingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        );
    }
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class _AuraBlob extends StatelessWidget {
  final List<Color> colors;
  final double size;

  const _AuraBlob({required this.colors, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
          stops: colors.length == 3 ? const [0.0, 0.6, 1.0] : const [0.0, 1.0],
        ),
      ),
    );
  }
}

class _TeacherLocatorScreen extends StatefulWidget {
  final OmniBrain brain;

  const _TeacherLocatorScreen({required this.brain});

  @override
  State<_TeacherLocatorScreen> createState() => _TeacherLocatorScreenState();
}

class _TeacherLocatorScreenState extends State<_TeacherLocatorScreen> {
  late TextEditingController _controller;
  TeacherLocatorResult? _result;
  bool _searching = false;
  List<String> _suggestions = [];
  List<String> _quickPicks = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _quickPicks = widget.brain.allTeachers().take(4).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateSuggestions(String query) {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final q = query.toLowerCase().trim();
    final all = widget.brain.allTeachers();
    final matches = all.where((t) => t.toLowerCase().contains(q)).take(5).toList();
    setState(() => _suggestions = matches);
  }

  void _performSearch([String? override]) {
    final query = override ?? _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _suggestions = [];
    });

    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        final result = widget.brain.locateTeacher(query, DateTime.now());
        setState(() {
          _result = result;
          _searching = false;
          if (result.status != 'not_found' && result.status != 'empty') {
            _controller.text = result.teacherName;
          }
        });
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const purple = Color(0xFF8B5CF6);
    const purpleLight = Color(0xFFA78BFA);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Neural aura background
          _NeuralAura(background: isDark),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [purple, purpleLight, Color(0xFFC4B5FD)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: purple.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_search_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [purple, purpleLight],
                              ).createShader(bounds),
                              child: const Text(
                                'Teacher Locator',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Find any teacher\'s real-time location & schedule',
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 0.1,
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Search card
                  GlassCard(
                    enableOverlay: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search field
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.10)
                                  : Colors.black.withOpacity(0.06),
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _performSearch(),
                            enabled: !_searching,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search by name...',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: purple,
                                size: 22,
                              ),
                              suffixIcon: _controller.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        _controller.clear();
                                        setState(() {
                                          _result = null;
                                          _suggestions = [];
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            onChanged: (v) {
                              _updateSuggestions(v);
                              setState(() {});
                            },
                          ),
                        ),

                        if (_controller.text.trim().isEmpty && _quickPicks.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 14, color: purple.withOpacity(0.6)),
                                const SizedBox(width: 6),
                                Text(
                                  'Quick picks',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 0.6,
                                    fontWeight: FontWeight.w700,
                                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickPicks.map((name) {
                              return InkWell(
                                onTap: () {
                                  _controller.text = name;
                                  _performSearch(name);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: purple.withOpacity(0.18),
                                    ),
                                  ),
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        // Suggestions dropdown
                        if (_suggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: purple.withOpacity(0.15),
                              ),
                            ),
                            child: Column(
                              children: _suggestions.map((name) {
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    _controller.text = name;
                                    _performSearch(name);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_outline_rounded, size: 18, color: purple.withOpacity(0.7)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Icon(Icons.north_west_rounded, size: 14, color: purple.withOpacity(0.4)),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),
                        // Search button
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [purple, purpleLight],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: purple.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _searching || _controller.text.trim().isEmpty
                                  ? null
                                  : _performSearch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                disabledForegroundColor: Colors.white.withOpacity(0.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _searching
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.near_me_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Locate Now',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Results
                  if (_result != null && _result!.status != 'empty') ...[
                    const SizedBox(height: 20),
                    _buildResultSection(context, _result!, isDark),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection(BuildContext context, TeacherLocatorResult result, bool isDark) {
    const purple = Color(0xFF8B5CF6);

    if (result.status == 'not_found') {
      return GlassCard(
        enableOverlay: false,
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.red.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              'No teacher found matching "${_controller.text}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different spelling or partial name',
              style: TextStyle(
                fontSize: 12,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Teacher name & status badge
        GlassCard(
          glow: result.status == 'live',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: result.status == 'live'
                            ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                            : [purple, const Color(0xFFA78BFA)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        result.teacherName.isNotEmpty
                            ? result.teacherName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.teacherName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${result.allSubjects.length} subject${result.allSubjects.length == 1 ? '' : 's'} · ${result.weeklySchedule.length} day${result.weeklySchedule.length == 1 ? '' : 's'}/week',
                          style: TextStyle(
                            fontSize: 12,
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  _buildStatusBadge(result, isDark),
                ],
              ),
              const SizedBox(height: 14),
              // Status text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: result.status == 'live'
                      ? const Color(0xFF10B981).withOpacity(isDark ? 0.15 : 0.1)
                      : purple.withOpacity(isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: result.status == 'live'
                        ? const Color(0xFF10B981).withOpacity(0.2)
                        : purple.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      result.status == 'live'
                          ? Icons.location_on_rounded
                          : result.status == 'today'
                              ? Icons.schedule_rounded
                              : Icons.event_rounded,
                      size: 16,
                      color: result.status == 'live'
                          ? const Color(0xFF10B981)
                          : purple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.statusText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: result.status == 'live'
                              ? const Color(0xFF10B981)
                              : (isDark ? Colors.white.withOpacity(0.85) : Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMetricChip(
              icon: Icons.menu_book_rounded,
              label: '${result.allSubjects.length} subjects',
              color: const Color(0xFF6366F1),
              isDark: isDark,
            ),
            _buildMetricChip(
              icon: Icons.today_rounded,
              label: '${result.todaySessions.length} today',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            _buildMetricChip(
              icon: Icons.calendar_month_rounded,
              label: '${result.weeklySchedule.length} days/week',
              color: const Color(0xFFF59E0B),
              isDark: isDark,
            ),
          ],
        ),

        // Today's schedule (if any)
        if (result.todaySessions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'TODAY\'S SCHEDULE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
              ),
            ),
          ),
          ...result.todaySessions.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RepaintBoundary(
              child: _buildSessionTile(entry, isDark, showDay: false),
            ),
          )),
        ],

        // Weekly schedule
        if (result.weeklySchedule.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'FULL WEEKLY SCHEDULE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
              ),
            ),
          ),
          ..._buildWeeklySchedule(result, isDark),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(TeacherLocatorResult result, bool isDark) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (result.status) {
      case 'live':
        bg = const Color(0xFF10B981);
        fg = Colors.white;
        label = 'LIVE';
        icon = Icons.circle;
        break;
      case 'today':
        bg = const Color(0xFF6366F1);
        fg = Colors.white;
        label = 'TODAY';
        icon = Icons.today_rounded;
        break;
      default:
        bg = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06);
        fg = isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6);
        label = 'WEEKLY';
        icon = Icons.calendar_month_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: result.status == 'live'
            ? [BoxShadow(color: bg.withOpacity(0.4), blurRadius: 8)]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result.status == 'live') ...[
            Icon(icon, size: 8, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.35 : 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(TeacherScheduleEntry entry, bool isDark, {bool showDay = true}) {
    const purple = Color(0xFF8B5CF6);

    return GlassCard(
      enableOverlay: false,
      enableShadow: false,
      child: Row(
        children: [
          // Time column
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: entry.isLive
                  ? const Color(0xFF10B981).withOpacity(isDark ? 0.15 : 0.1)
                  : purple.withOpacity(isDark ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  entry.startTime,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: entry.isLive ? const Color(0xFF10B981) : purple,
                  ),
                ),
                Container(
                  width: 1,
                  height: 8,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                ),
                Text(
                  entry.endTime,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (entry.isLive) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        entry.subject,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.room_rounded, size: 13, color: purple.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text(
                      entry.room,
                      style: TextStyle(
                        fontSize: 12,
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                      ),
                    ),
                    if (showDay) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.groups_rounded, size: 13, color: purple.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          entry.batch,
                          style: TextStyle(
                            fontSize: 11,
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 10),
                      Icon(Icons.groups_rounded, size: 13, color: purple.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          entry.batch,
                          style: TextStyle(
                            fontSize: 11,
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (entry.isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'NOW',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10B981),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          if (entry.isUpcoming && !entry.isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'NEXT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6366F1),
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildWeeklySchedule(TeacherLocatorResult result, bool isDark) {
    const purple = Color(0xFF8B5CF6);
    final sortedDays = result.weeklySchedule.keys.toList()..sort();
    final today = DateTime.now().weekday;

    return sortedDays.map((day) {
      final entries = result.weeklySchedule[day]!;
      final isToday = day == today;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isToday
                          ? purple.withOpacity(isDark ? 0.2 : 0.12)
                          : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: purple.withOpacity(0.3))
                          : null,
                    ),
                    child: Text(
                      TeacherScheduleEntry.dayNames[day - 1],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isToday
                            ? purple
                            : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6)),
                      ),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: purple.withOpacity(0.7),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${entries.length} class${entries.length == 1 ? '' : 'es'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
            ...entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RepaintBoundary(
                child: _buildSessionTile(entry, isDark, showDay: true),
              ),
            )),
          ],
        ),
      );
    }).toList();
  }
}

class _DepartmentClassesScreen extends StatefulWidget {
  final UniversityMemory memory;
  final String currentBatch;

  const _DepartmentClassesScreen({
    required this.memory,
    required this.currentBatch,
  });

  @override
  State<_DepartmentClassesScreen> createState() => _DepartmentClassesScreenState();
}

class _DepartmentClassesScreenState extends State<_DepartmentClassesScreen> {
  String? selectedProgram;
  int? selectedSemester;
  String? selectedSection;
  int? selectedDay;

  @override
  void initState() {
    super.initState();
    if (widget.memory.programs().isNotEmpty) {
      selectedProgram = widget.memory.programs().first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final programs = widget.memory.programs();
    final selectedProgram = this.selectedProgram;

    List<ClassSession> displayedSessions = [];
    if (selectedProgram != null) {
      displayedSessions = widget.memory.sessions
          .where((s) => s.batchKey.program == selectedProgram)
          .toList();

      if (selectedSemester != null && selectedSemester! > 0) {
        displayedSessions = displayedSessions
            .where((s) => s.batchKey.semester == selectedSemester)
            .toList();
      }

      if (selectedSection != null) {
        displayedSessions = displayedSessions
            .where((s) => s.batchKey.section == selectedSection)
            .toList();
      }

      if (selectedDay != null) {
        displayedSessions = displayedSessions
            .where((s) => s.dayIndex == selectedDay)
            .toList();
      }
    }

    // Get unique semesters and sections for filters
    final semesters = selectedProgram == null
        ? []
        : widget.memory.semesters(selectedProgram);
    final sections = selectedProgram == null || selectedSemester == null
        ? []
        : widget.memory.sections(selectedProgram, selectedSemester ?? 1);
    
    // Get available days from filtered sessions
    final List<String> dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final availableDays = <int>{};
    
    var dayFilteredSessions = widget.memory.sessions;
    if (selectedProgram != null) {
      dayFilteredSessions = dayFilteredSessions.where((s) => s.batchKey.program == selectedProgram).toList();
    }
    if (selectedSemester != null && selectedSemester! > 0) {
      dayFilteredSessions = dayFilteredSessions.where((s) => s.batchKey.semester == selectedSemester).toList();
    }
    if (selectedSection != null) {
      dayFilteredSessions = dayFilteredSessions.where((s) => s.batchKey.section == selectedSection).toList();
    }
    for (final session in dayFilteredSessions) {
      availableDays.add(session.dayIndex);
    }
    final sortedDays = availableDays.toList()..sort();
    final today = DateTime.now().weekday;
    final smartDays = List<int>.from(sortedDays);
    if (smartDays.contains(today)) {
      smartDays.remove(today);
      smartDays.insert(0, today);
    }
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF6366F1), Color(0xFF818CF8), Color(0xFFA78BFA)],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                                    ).createShader(bounds),
                                    child: const Text(
                                      'Browse Classes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 24,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'View classes from all departments',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: (isDark ? Colors.white : Colors.black)
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Filters card
                        GlassCard(
                          enableOverlay: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Department Filter
                              Text(
                                'DEPARTMENT',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: programs
                                      .map((program) => Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: _buildFilterChip(
                                              label: program,
                                              selected: selectedProgram == program,
                                              color: const Color(0xFF8B5CF6),
                                              isDark: isDark,
                                              onSelected: (selected) {
                                                if (selected) {
                                                  setState(() {
                                                    this.selectedProgram = program;
                                                    selectedSemester = null;
                                                    selectedSection = null;
                                                  });
                                                }
                                              },
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),

                              // Semester Filter
                              if (semesters.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'SEMESTER',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: semesters
                                        .map((sem) => Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: _buildFilterChip(
                                                label: 'Sem $sem',
                                                selected: selectedSemester == sem,
                                                color: const Color(0xFF06B6D4),
                                                isDark: isDark,
                                                onSelected: (selected) {
                                                  setState(() {
                                                    selectedSemester = selected ? sem : null;
                                                    selectedSection = null;
                                                  });
                                                },
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ],

                              // Section Filter
                              if (sections.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'SECTION',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: sections
                                        .map((section) => Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: _buildFilterChip(
                                                label: section,
                                                selected: selectedSection == section,
                                                color: const Color(0xFF10B981),
                                                isDark: isDark,
                                                onSelected: (selected) {
                                                  setState(() {
                                                    selectedSection = selected ? section : null;
                                                  });
                                                },
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ],

                              // Day Filter
                              if (smartDays.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'DAY',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: smartDays
                                        .map((day) => Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: _buildFilterChip(
                                                label: day == today ? 'Today' : dayNames[day - 1],
                                                selected: selectedDay == day,
                                                color: day == today
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFF59E0B),
                                                isDark: isDark,
                                                onSelected: (selected) {
                                                  setState(() {
                                                    selectedDay = selected ? day : null;
                                                  });
                                                },
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '${displayedSessions.length} classes found',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Classes list
                if (displayedSessions.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final session = displayedSessions[index];
                          final isInMySchedule = widget.currentBatch == session.batchKey.batch;
                          final isLive = session.isLive(DateTime.now());
                          final programAccent = _accentForProgram(session.batchKey.program);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              enableOverlay: false,
                              enableShadow: false,
                              glow: isLive,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Time column
                                  Container(
                                    width: 54,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isLive
                                          ? const Color(0xFF10B981).withOpacity(isDark ? 0.15 : 0.1)
                                          : const Color(0xFF6366F1).withOpacity(isDark ? 0.1 : 0.06),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          session.startTime,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isLive ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 6,
                                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                                        ),
                                        Text(
                                          session.endTime,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (isLive) ...[
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF10B981),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Expanded(
                                              child: Text(
                                                session.subject,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: isLive
                                                      ? const Color(0xFF10B981)
                                                      : (isDark
                                                          ? programAccent.withOpacity(0.95)
                                                          : programAccent.withOpacity(0.90)),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isInMySchedule)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: programAccent.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: programAccent.withOpacity(0.2),
                                                  ),
                                                ),
                                                child: Text(
                                                  'MY CLASS',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: programAccent,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _buildMetaChip(
                                              icon: Icons.person_outline_rounded,
                                              text: session.teacher,
                                              color: const Color(0xFF6366F1),
                                              isDark: isDark,
                                            ),
                                            _buildMetaChip(
                                              icon: Icons.room_rounded,
                                              text: session.room,
                                              color: const Color(0xFF10B981),
                                              isDark: isDark,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B5CF6).withOpacity(isDark ? 0.14 : 0.10),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(
                                              color: const Color(0xFF8B5CF6).withOpacity(0.25),
                                            ),
                                          ),
                                          child: Text(
                                            session.batchKey.batch,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF8B5CF6),
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: displayedSessions.length,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),

                // Empty state
                if (displayedSessions.isEmpty && selectedProgram != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: GlassCard(
                        enableOverlay: false,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.25),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No classes found',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try adjusting the filters',
                              style: TextStyle(
                                fontSize: 12,
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _accentForProgram(String program) {
    final key = program.toLowerCase();
    if (key.contains('cs') || key.contains('computer')) return const Color(0xFF6366F1);
    if (key.contains('se') || key.contains('software')) return const Color(0xFF3B82F6);
    if (key.contains('it') || key.contains('information')) return const Color(0xFF06B6D4);
    if (key.contains('ee') || key.contains('electrical')) return const Color(0xFFF59E0B);
    if (key.contains('ai') || key.contains('ml')) return const Color(0xFF8B5CF6);
    if (key.contains('mech') || key.contains('mechanical')) return const Color(0xFFEF4444);
    return const Color(0xFF10B981);
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Color color,
    required bool isDark,
    required ValueChanged<bool> onSelected,
  }) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color
              : isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? color.withOpacity(0.8)
                : isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6)),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.35 : 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.75),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

