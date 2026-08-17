import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassCard;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'core/animations.dart';
import 'core/format_guard.dart';
import 'core/glass.dart';
import 'core/models.dart';
import 'core/omni_brain.dart';
import 'core/theme.dart';
import 'core/minimal_theme.dart';
import 'core/tokens.dart';
import 'core/university_memory.dart';
import 'core/app_signals.dart';
import 'core/theme_signals.dart';
import 'core/vital_theme.dart';
import 'core/vital_motion.dart';
import 'widgets/glass_container_transform.dart';
import 'screens/portal_screen.dart';
import 'screens/about_screen.dart';
import 'screens/academics_hub_screen.dart';
import 'screens/intelligent_insight_screen.dart';
import 'screens/faculty_dashboard_screen.dart';
import 'screens/room_finder_screen.dart';
import 'screens/document_workspace_screen.dart';
import 'screens/setup_screens.dart';
import 'screens/tutorial_screen.dart';
import 'screens/teacher_locator_screen.dart';
import 'services/helpdesk_faculty_service.dart';
import 'screens/students_week_screen.dart';
import 'services/remote_config_service.dart';
import 'services/app_update_service.dart';
import 'services/helpdesk_schedule_data_service.dart';
import 'services/headless_portal_sync.dart';
import 'services/notification_service.dart';
import 'services/system_broadcast_service.dart';
import 'services/ui_feedback.dart';
import 'services/session_refresher_service.dart';
import 'services/widget_service.dart';
import 'services/app_config.dart';
import 'services/analytics_manager.dart';
import 'services/memory_manager.dart';
import 'widgets/batch_selector.dart';
import 'widgets/dashboard_dock.dart' hide NavActiveHalo, BouncyNavButton;
import 'widgets/glass_card.dart';
import 'widgets/iris_components.dart';
import 'widgets/portal_sync_card.dart';
import 'widgets/smart_pill_overlay.dart';
import 'widgets/smooth_scroll.dart';

import 'widgets/live_class_hub_sheet.dart';
import 'screens/cgpa_calculator_screen.dart';
import 'screens/faculty_directory_screen.dart';
import 'screens/department_classes_screen.dart';
import 'screens/makeup_lecture_scheduler_screen.dart';
import 'screens/exam_grid_dashboard_screen.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

part 'screens/tools_screen_part.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init fallback: $e');
  }

  try {
    await AppConfig().initialize();
    ErrorHandler.setupErrorHandling();
    ImageCacheManager.optimizeImageCache();
  } catch (e) {
    debugPrint('AppConfig init error: $e');
  }

  try {
    tz.initializeTimeZones();
  } catch (e) {
    debugPrint('Timezone init error: $e');
  }

  try {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'persistent_class_foreground',
        channelName: 'IRIS Class Tracker',
        channelDescription: 'Shows your current and upcoming classes',
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.MAX,
        enableVibration: false,
        playSound: false,
        showWhen: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  } catch (e) {
    debugPrint('Foreground task init error: $e');
  }

  try {
    await LiquidGlassWidgets.initialize();
  } catch (e) {
    debugPrint('LiquidGlassWidgets init error: $e');
  }

  try {
    await IrisSfx.init();
    await IrisHaptics.init();
  } catch (e) {
    debugPrint('UI feedback init error: $e');
  }
  
  runApp(ErrorBoundary(
    child: LiquidGlassWidgets.wrap(
      child: const IrisApp(),
      adaptiveQuality: true,
    ),
  ));
}

class IrisApp extends StatefulWidget {
  const IrisApp();

  @override
  State<IrisApp> createState() => _IrisAppBootState();
}

final globalScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class _IrisAppBootState extends State<IrisApp> {
  late final Future<UniversityMemory> _memoryFuture;
  final _shorebirdUpdater = ShorebirdUpdater();

  @override
  void initState() {
    super.initState();
    _memoryFuture = UniversityMemoryLoader.loadFromAssets();
    _checkShorebirdPatch();
  }

  Future<void> _checkShorebirdPatch() async {
    try {
      if (!_shorebirdUpdater.isAvailable) return;
      final status = await _shorebirdUpdater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        await _shorebirdUpdater.update();
        _promptForRestartWhenReady();
      }
    } catch (e) {
      debugPrint('Shorebird patch check: $e');
    }
  }

  void _promptForRestartWhenReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      int retries = 0;
      while (retries < 15) {
        final context = globalScaffoldMessengerKey.currentContext;
        if (context != null && context.mounted) {
          _showUpdateDialog(context);
          break;
        }
        await Future.delayed(const Duration(milliseconds: 400));
        retries++;
      }
    });
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: IrisTokens.brand.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 40,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: GlassSurface(
                  settings: IrisGlass.settings(
                    context,
                    blur: 16.0,
                    ambientStrength: 0.85,
                    lightAngle: 0.15 * math.pi,
                    thickness: 22.0,
                    glassColor: IrisGlass.adaptiveGlassColor(
                      context,
                      darkAlpha: 0.90,
                      lightAlpha: 0.95,
                    ),
                  ),
                  radius: 32,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: IrisTokens.brand.withValues(alpha: isDark ? 0.45 : 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Hero Icon Badge with Gradient Glow
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [IrisTokens.brand, IrisTokens.purple],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: IrisTokens.brand.withValues(alpha: 0.45),
                                blurRadius: 24,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.system_update_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Pill Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: IrisTokens.brand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: IrisTokens.brand.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'OVER-THE-AIR PATCH READY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: IrisTokens.brand,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Update Installed!',
                          style: IrisTextStyles.headline(context).copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'A fresh update with visual enhancements and performance speedups is ready to apply.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 26),
                        // Action Buttons
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  IrisHaptics.actionHeavy();
                                  SystemNavigator.pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: IrisTokens.brand,
                                  foregroundColor: Colors.white,
                                  elevation: 6,
                                  shadowColor: IrisTokens.brand.withValues(alpha: 0.4),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.restart_alt_rounded, size: 20, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'RESTART APP NOW',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  'Dismiss & Restart Later',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UniversityMemory>(
      future: _memoryFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _IrisApp(memory: snapshot.data!);
        }
        return MaterialApp(
          scaffoldMessengerKey: globalScaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          theme: IrisTheme.light(),
          darkTheme: IrisTheme.dark(),
          scrollBehavior: const SmoothScrollBehavior(),
          home: const _StartupSplash(),
        );
      },
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [IrisTokens.surfaceDark, const Color(0xFF0D0F17)]
                : [const Color(0xFFF8F7FC), const Color(0xFFF0F3FF)],
          ),
        ),
        child: Center(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: IrisTokens.brandGradient),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'IRIS',
                  style: IrisTextStyles.display(context).copyWith(
                    fontSize: 26,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Loading schedule and preferences...',
                  style: IrisTextStyles.metaInfo(context),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IrisApp extends StatefulWidget {
  const _IrisApp({required this.memory});

  final UniversityMemory memory;

  @override
  State<_IrisApp> createState() => _IrisAppState();
}

class _IrisAppState extends State<_IrisApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('theme_mode') ?? 'system';
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = _themeModeFromString(savedMode);
    });
    // Load minimal UI preference and apply globally
    final useMinimal = prefs.getBool('use_minimal_ui') ?? false;
    ThemeSignals.useMinimalTheme.value = useMinimal;
  }

  ThemeMode _themeModeFromString(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> _setThemeMode(String mode) async {
    final nextMode = _themeModeFromString(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _themeModeToString(nextMode));
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = nextMode;
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useVitalTheme,
      builder: (context, useVital, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: ThemeSignals.useMinimalTheme,
          builder: (context, useMinimal, _) {
            final theme = useVital 
                ? buildVitalTheme(brightness: Brightness.light)
                : (useMinimal ? buildMinimalTheme(brightness: Brightness.light) : IrisTheme.light());
            
            final darkTheme = useVital 
                ? buildVitalTheme(brightness: Brightness.dark)
                : (useMinimal ? buildMinimalTheme(brightness: Brightness.dark) : IrisTheme.dark());

            return MaterialApp(
              scaffoldMessengerKey: globalScaffoldMessengerKey,
              debugShowCheckedModeBanner: false,
              themeMode: _themeMode,
              theme: theme,
              darkTheme: darkTheme,
              scrollBehavior: const SmoothScrollBehavior(),
              builder: (context, child) => SmartPillOverlay(child: child!),
              home: _AppRoot(
                memory: widget.memory,
                onToggleTheme: _toggleTheme,
                onSetThemeMode: _setThemeMode,
                currentThemeMode: _themeModeToString(_themeMode),
              ),
            );
          },
        );
      },
    );
  }
}



class _AppRoot extends StatefulWidget {
  final UniversityMemory memory;
  final VoidCallback onToggleTheme;
  final Future<void> Function(String mode) onSetThemeMode;
  final String currentThemeMode;

  const _AppRoot({
    required this.memory,
    required this.onToggleTheme,
    required this.onSetThemeMode,
    required this.currentThemeMode,
  });

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final OmniBrain _brain;
  String? _selectedBatch;
  String? _userRole;
  String? _userName;
  bool? _tutorialCompleted;
  late VoidCallback _roleListener;
  String _headlessUrl = 'https://swl-sis.comsats.edu.pk/';

  @override
  void initState() {
    super.initState();
    _brain = OmniBrain(widget.memory);
    // Listen for global role-change signals (used when hub is opened without a callback)
    _roleListener = () {
      final role = AppSignals.roleNotifier.value;
      if (role != null) {
        // Persist and apply role change
        _saveUserRole(role);
        // clear the notifier value so subsequent changes can be detected
        AppSignals.roleNotifier.value = null;
      }
    };
    AppSignals.roleNotifier.addListener(_roleListener);
    _loadTutorialCompleted();
    _loadUserRole();
    _loadBatch();
    _loadUserName();
    _loadHeadlessUrl();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestForegroundNotificationPermission();
    });

    // Show Darood e Pak reminder on app boot with haptic pulse after UI layout settles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          IrisHaptics.actionSoft();
          _showDaroodePakDialog();
        }
      });
    });
  }

  @override
  void dispose() {
    AppSignals.roleNotifier.removeListener(_roleListener);
    super.dispose();
  }

  Future<void> _loadHeadlessUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const activeSessionKey = 'iris_portal_student_last_active_session';
      final raw = prefs.getString(activeSessionKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        final url = decoded['url'] as String?;
        if (url != null && url.isNotEmpty && !url.contains('cui-helpdesk')) {
          setState(() {
            _headlessUrl = url;
          });
          debugPrint('🌐 [IRIS] Loaded Headless Scraper Target URL: $_headlessUrl');
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [IRIS] Error loading headless URL: $e');
    }
    setState(() {
      _headlessUrl = 'https://swl-sis.comsats.edu.pk/';
    });
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role');
    });
  }

  Future<void> _loadTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tutorialCompleted = prefs.getBool('tutorial_completed') ?? false;
    });
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', true);
    setState(() {
      _tutorialCompleted = true;
    });
  }

  void _showDaroodePakDialog() {
    final now = DateTime.now();
    final hour = now.hour;
    final isFriday = now.weekday == DateTime.friday;
    final greeting = isFriday
        ? 'Jummah Mubarak — Send Darood upon the Prophet ﷺ'
        : (hour >= 5 && hour < 12
            ? 'Start your morning with blessings · Darood e Pak'
            : hour >= 12 && hour < 17
                ? 'Afternoon reminder for Darood e Pak'
                : hour >= 17 && hour < 21
                    ? 'Evening blessings upon the Prophet ﷺ'
                    : 'Night reminder — Send Darood e Pak');

    SystemBroadcastService().triggerLocalOverride(
      'Darood e Pak 🕌',
      greeting,
      isUrgent: false,
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _loadBatch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedBatch = prefs.getString('user_batch');
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final role = prefs.getString('user_role');
      if (role == 'faculty') {
        _userName = prefs.getString('faculty_user_name') ?? prefs.getString('faculty_teacher');
      } else {
        _userName = prefs.getString('student_user_name');
      }
    });
  }

  Future<void> _requestForegroundNotificationPermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    try {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (e) {
      debugPrint('Battery optimization ignore error: $e');
    }
  }

  Future<void> _saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_user_name', name);
    setState(() {
      _userName = name;
    });
  }

  Future<void> _saveBatch(String batch) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = batch.trim();
    await prefs.setString('user_batch', trimmed);

    final isFirstSetup = prefs.getBool('widget_prompt_shown') != true;
    setState(() => _selectedBatch = trimmed);

    // Show widget setup prompt after first batch selection
    if (isFirstSetup && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _showWidgetSetupPrompt();
      }
    }
  }

  Future<void> _showWidgetSetupPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                offset: const Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Widget icon with smooth gradient
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [IrisTokens.blue, IrisTokens.brand],
                  ),
                  borderRadius: BorderRadius.circular(IrisTokens.radius20),
                  boxShadow: [
                    BoxShadow(
                      color: IrisTokens.brand.withValues(alpha: 0.20),
                      offset: const Offset(0, 8),
                      blurRadius: 18,
                      spreadRadius: -6,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Add Home Screen Widget',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: 2.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                'Track your classes at a glance with the IRIS home screen widget.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.65,
                  ),
                  height: 1.5,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Instructions
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.04,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                      0.06,
                    ),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStep(isDark, '1', 'Long press on your home screen'),
                    const SizedBox(height: 12),
                    _buildStep(isDark, '2', 'Tap Widgets'),
                    const SizedBox(height: 12),
                    _buildStep(isDark, '3', 'Search for "IRIS"'),
                    const SizedBox(height: 12),
                    _buildStep(isDark, '4', 'Drag to home screen'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Maybe Later',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.5),
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
                        backgroundColor: IrisTokens.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            IrisTokens.radius16,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Got It!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
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

    // Mark as shown
    await prefs.setBool('widget_prompt_shown', true);
  }

  Widget _buildStep(bool isDark, String number, String text) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [IrisTokens.error.withValues(alpha: 0.8), IrisTokens.error],
            ),
            border: Border.all(
              color: IrisTokens.error.withValues(alpha: 0.4),
              width: 0.5,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: IrisTokens.error.withValues(alpha: 0.3),
                offset: const Offset(0, 2),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
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
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);

    // Don't clear data - just switch role and let onRepeatEvent use the right data for this role
    // This way notifications continue properly during role switching

    // Always stop service when changing roles to ensure clean state
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() => _userRole = role);
  }

  Future<void> _completeOnboarding(String role, String name, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    if (role == 'faculty') {
      await prefs.setString('faculty_user_name', name);
      await prefs.setString('faculty_teacher', value);
      
      // Always stop service when changing roles to ensure clean state
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      setState(() {
        _userRole = role;
        _userName = name;
      });
    } else {
      await prefs.setString('student_user_name', name);
      await prefs.setString('user_batch', value.trim());
      
      final isFirstSetup = prefs.getBool('widget_prompt_shown') != true;
      
      setState(() {
        _userRole = role;
        _userName = name;
        _selectedBatch = value.trim();
      });
      
      if (isFirstSetup && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await _showWidgetSetupPrompt();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tutorialCompleted == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_tutorialCompleted == false) {
      return TutorialScreen(onComplete: _completeTutorial);
    }

    // Unified Onboarding check
    final isStudentOnboarded = _userRole == 'student' && _selectedBatch != null && _userName != null;
    final isFacultyOnboarded = _userRole == 'faculty' && _userName != null;
    final isOnboarded = isStudentOnboarded || isFacultyOnboarded;

    if (!isOnboarded) {
      return OnboardingWizard(
        memory: widget.memory,
        onComplete: _completeOnboarding,
      );
    }

    if (_userRole == 'faculty') {
      final prefs = SharedPreferences.getInstance();
      return FacultyDashboard(
        brain: _brain,
        teacherName: _userName ?? '',
        onToggleTheme: widget.onToggleTheme,
        onSetThemeMode: widget.onSetThemeMode,
        currentThemeMode: widget.currentThemeMode,
        onRoleChanged: _saveUserRole,
        onBatchChanged: _saveBatch,
      );
    }

    return Stack(
      children: [
        Dashboard(
          memory: widget.memory,
          brain: _brain,
          batch: _selectedBatch!,
          onToggleTheme: widget.onToggleTheme,
          onSetThemeMode: widget.onSetThemeMode,
          currentThemeMode: widget.currentThemeMode,
          userName: _userName,
          onUserNameChanged: (name) => setState(() => _userName = name),
          onRoleChanged: _saveUserRole,
          onChangeBatch: () => setState(() => _selectedBatch = null),
          onBatchChanged: _saveBatch,
        ),
        HeadlessPortalSync(url: _headlessUrl),
      ],
    );
  }
}

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
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;

  const Dashboard({
    required this.memory,
    required this.brain,
    required this.batch,
    required this.onToggleTheme,
    required this.onSetThemeMode,
    required this.currentThemeMode,
    required this.onChangeBatch,
    this.userName,
    this.onUserNameChanged,
    this.onRoleChanged,
    this.onBatchChanged,
    super.key,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

// Faculty Full Schedule Screen
class _FacultyFullScheduleScreen extends StatefulWidget {
  final OmniBrain brain;
  final String teacherName;
  final VoidCallback onToggleTheme;
  final ValueChanged<String>? onRoleChanged;

  const _FacultyFullScheduleScreen({
    required this.brain,
    required this.teacherName,
    required this.onToggleTheme,
    this.onRoleChanged,
  });

  @override
  State<_FacultyFullScheduleScreen> createState() =>
      _FacultyFullScheduleScreenState();
}

class _FacultyFullScheduleScreenState
    extends State<_FacultyFullScheduleScreen> {
  int? _overrideDayIndex;
  List<ClassSession> _cachedSchedule = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _updateScheduleCache();
  }

  void _updateScheduleCache() {
    final now = DateTime.now();
    final schedule = _overrideDayIndex != null
        ? _scheduleForDay(widget.teacherName, _overrideDayIndex!)
        : _buildSuggestedScheduleForTeacher(widget.teacherName, now);

    // Merge consecutive slots of the same lecture for cleaner display
    final mergedSchedule = widget.brain.getMergedConsecutiveSessions(schedule);

    // Ensure final schedule is always sorted in ascending order by start time
    mergedSchedule.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    setState(() {
      _cachedSchedule = mergedSchedule;
    });
  }

  List<ClassSession> _scheduleForDay(String teacher, int dayIndex) {
    final allSessions = widget.brain.scheduleForTeacher(teacher);
    final daySchedule =
        allSessions.where((s) => s.dayIndex == dayIndex).toList()
          ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    return daySchedule;
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
      final allClassesEnded = today.every((s) => s.safeEndVal <= currentTime);

      if (allClassesEnded) {
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
      if (daySchedule.isNotEmpty) {
        return daySchedule;
      }
    }
    return [];
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final dateLabel = _formatDateLabel(now);
    final schedule = _cachedSchedule;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactCard = screenWidth < 400;
    final isVeryCompactCard = screenWidth < 360;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        leading: AppBackButton(isDark: isDark),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? IrisTokens.brand.withValues(alpha: 0.2)
                    : IrisTokens.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  IrisHaptics.actionMedium();
                  pushGlassContainerMorphRoute(
                    context,
                    page: IntelligentInsightScreen(
                      brain: widget.brain,
                    ),
                    accentColor: IrisTokens.brand,
                  );
                },
                tooltip: 'Intelligent Insight & Mascot',
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: IrisTokens.brand,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  IrisHaptics.actionSoft();
                  widget.onToggleTheme();
                },
                tooltip: isDark
                    ? 'Switch to light mode'
                    : 'Switch to dark mode',
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const ButterScrollPhysics(),
              cacheExtent: 500,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: GlassCard(
                      padding: EdgeInsets.fromLTRB(
                        isVeryCompactCard ? 14 : (isCompactCard ? 16 : 20),
                        isVeryCompactCard ? 14 : 16,
                        isVeryCompactCard ? 14 : (isCompactCard ? 16 : 20),
                        isVeryCompactCard ? 14 : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isVeryCompactCard ? 8 : 10,
                                  vertical: isVeryCompactCard ? 4 : 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [IrisTokens.blue, IrisTokens.blue],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: IrisTokens.blue.withValues(alpha: 0.22),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/iris_logo.png',
                                      width: isVeryCompactCard ? 10 : 11,
                                      height: isVeryCompactCard ? 10 : 11,
                                      fit: BoxFit.cover,
                                    ),
                                    SizedBox(width: isVeryCompactCard ? 4 : 5),
                                    Text(
                                      'IRIS',
                                      style: TextStyle(
                                        letterSpacing: 2.5,
                                        fontSize: isVeryCompactCard ? 8 : 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ValueListenableBuilder<String>(
                                  valueListenable: RemoteConfigService.activeAcademicPeriod,
                                  builder: (context, period, _) {
                                    String title = 'FACULTY SCHEDULE';
                                    if (period == 'ramadan') {
                                      title = '🌙 RAMADAN SCHEDULE';
                                    } else if (period == 'midterms') {
                                      title = '✍️ MIDTERM INVIGILATION';
                                    } else if (period == 'finals') {
                                      title = '🎓 FINAL EXAM SUPERVISION';
                                    } else if (period == 'sports_week') {
                                      title = '🏆 GALA EVENT DUTY';
                                    }
                                    return Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: isVeryCompactCard ? 11 : 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                        color: period == 'classes'
                                            ? (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.46 : 0.40)
                                            : (period == 'ramadan' || period == 'sports_week'
                                                ? const Color(0xFF10B981)
                                                : (period == 'midterms' ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6))),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isVeryCompactCard ? 10 : 12,
                              vertical: isVeryCompactCard ? 6 : 7,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: isVeryCompactCard ? 12 : 13,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.62),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: isVeryCompactCard ? 11 : 12,
                                    letterSpacing: 0.35,
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: 0.78),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.teacherName,
                            maxLines: isCompactCard ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: isVeryCompactCard
                                  ? 19
                                  : (isCompactCard ? 20 : 22),
                              height: 1.1,
                              letterSpacing: 0.2,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _buildDaySelector(now, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: _buildScheduleHeader(schedule, now, isDark),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  sliver: schedule.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 50,
                              horizontal: 20,
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 40,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      IrisTokens.brand.withValues(alpha: 
                                        isDark ? 0.12 : 0.08,
                                      ),
                                      IrisTokens.brandLight.withValues(alpha: 
                                        isDark ? 0.06 : 0.03,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: IrisTokens.brand.withValues(alpha: 
                                      isDark ? 0.20 : 0.12,
                                    ),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: IrisTokens.brand.withValues(alpha: 0.12),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            IrisTokens.brand.withValues(alpha: 0.15),
                                            IrisTokens.brandLight.withValues(alpha: 
                                              0.08,
                                            ),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.beach_access_rounded,
                                        size: 36,
                                        color: IrisTokens.brand.withValues(alpha: 
                                          0.80,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'No Classes Today',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        letterSpacing: 0.3,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'You\'re all set for the day! 🎉',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, index) {
                              final session = schedule[index];
                              final nextSession = index + 1 < schedule.length
                                  ? schedule[index + 1]
                                  : null;
                              return StaggeredListItem(
                                index: index,
                                child: RepaintBoundary(
                                  child: ClassCard(
                                    key: ValueKey(
                                      'faculty_class_${session.subject}_${session.startTime}_${session.batchKey.batch}',
                                    ),
                                    session: session,
                                    nextSession: nextSession,
                                    isFacultyView: true,
                                  ),
                                ),
                              );
                            },
                            childCount: schedule.length,
                            addAutomaticKeepAlives: true,
                            addRepaintBoundaries: true,
                          ),
                        ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 118)),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: DashboardDock(
                scrollController: _scrollController,
                showFacultySet: true,
                selectedIndex: 1,
                onTeacher: () => pushIconLaunchRoute(
                  context,
                  page: TeacherLocatorScreen(brain: widget.brain),
                ),
                onPortal: () => pushIconLaunchRoute(
                  context,
                  page: const PortalScreen(
                    url:
                        'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
                    title: 'COMSATS Faculty Portal',
                    sessionScope: 'faculty',
                  ),
                ),
                onAbout: () => pushIconLaunchRoute(
                  context,
                  page: AboutScreen(
                    memory: widget.brain.memory,
                    onRoleChanged: widget.onRoleChanged,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(DateTime now, bool isDark) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final currentDay = _overrideDayIndex;
    final today = now.weekday; // 1=Mon
    final autoSelected = currentDay == null;

    return GlassCard(
      child: SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const ButterScrollPhysics(),
          children: [
            const SizedBox(width: 6),
            AnimatedSlide(
              duration: IrisMotion.fast,
              curve: IrisMotion.standard,
              offset: autoSelected ? const Offset(0, -0.02) : Offset.zero,
              child: AnimatedScale(
                duration: IrisMotion.fast,
                curve: IrisMotion.standard,
                scale: autoSelected ? 1.025 : 1.0,
                child: AnimatedContainer(
                  duration: IrisMotion.fast,
                  curve: IrisMotion.standard,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [],
                  ),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: autoSelected
                              ? IrisTokens.brand
                              : isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Auto',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    selected: autoSelected,
                    onSelected: (_) {
                      IrisHaptics.chipSelect();
                      setState(() {
                        _overrideDayIndex = null;
                        _updateScheduleCache();
                      });
                    },
                    selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    side: BorderSide(
                      color: autoSelected
                          ? IrisTokens.brand.withValues(alpha: 0.56)
                          : isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.10),
                      width: autoSelected ? 1.4 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      color: autoSelected
                          ? IrisTokens.brand
                          : isDark
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.black.withValues(alpha: 0.65),
                    ),
                    elevation: autoSelected ? 0.6 : 0,
                    pressElevation: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ...List.generate(days.length, (index) {
              final dayIndex = index + 1;
              final isSelected = currentDay == dayIndex;
              final isToday = dayIndex == today;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedSlide(
                  duration: IrisMotion.fast,
                  curve: IrisMotion.standard,
                  offset: isSelected ? const Offset(0, -0.02) : Offset.zero,
                  child: AnimatedScale(
                    duration: IrisMotion.fast,
                    curve: IrisMotion.standard,
                    scale: isSelected ? 1.03 : 1.0,
                    child: AnimatedContainer(
                      duration: IrisMotion.fast,
                      curve: IrisMotion.standard,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [],
                      ),
                      child: ChoiceChip(
                        avatar: isToday && !isSelected
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: IrisTokens.success,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        label: Text(
                          days[index],
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          IrisHaptics.chipSelect();
                          setState(() {
                            _overrideDayIndex = dayIndex == today
                                ? null
                                : dayIndex;
                            _updateScheduleCache();
                          });
                        },
                        selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        side: BorderSide(
                          color: isSelected
                              ? IrisTokens.brand.withValues(alpha: 0.56)
                              : isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.10),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? IrisTokens.brand
                              : isDark
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.black.withValues(alpha: 0.65),
                        ),
                        elevation: isSelected ? 0.6 : 0,
                        pressElevation: 1,
                      ),
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

  Widget _buildScheduleHeader(
    List<ClassSession> schedule,
    DateTime now,
    bool isDark,
  ) {
    final dayIndex =
        _overrideDayIndex ?? schedule.firstOrNull?.dayIndex ?? now.weekday;
    String title;
    String subtitle;
    Color statusColor = IrisTokens.brand;

    if (schedule.isEmpty && _overrideDayIndex != null) {
      title = '${FormatGuard.normalizeDay(_overrideDayIndex!)} SCHEDULE';
      subtitle = 'No classes scheduled • Free day! 🎉';
      statusColor = IrisTokens.purple;
    } else if (schedule.isEmpty) {
      title = 'NO CLASSES';
      subtitle = 'No sessions in the registry';
      statusColor = IrisTokens.brand;
    } else {
      if (dayIndex == now.weekday) {
        title = 'TODAY\'S SCHEDULE';
        final currentTime = now.hour + (now.minute / 60.0);
        final current = widget.brain.getCurrentClassForTeacher(
          widget.teacherName,
          now,
        );

        if (current != null && current.isLive(now)) {
          statusColor = IrisTokens.success;
          final remaining = schedule
              .where((s) => s.safeStartVal > currentTime)
              .length;
          final classesLeft = remaining > 0
              ? '$remaining ${remaining == 1 ? 'class' : 'classes'} left'
              : 'Last class today';
          subtitle = '${current.subject} • $classesLeft';
        } else {
          statusColor = IrisTokens.warning;
          final nextClass = schedule.firstWhere(
            (s) => s.safeStartVal > currentTime,
            orElse: () => schedule.first,
          );

          if (nextClass.safeStartVal > currentTime) {
            final minutesUntil = ((nextClass.safeStartVal - currentTime) * 60)
                .round();

            if (minutesUntil > 60) {
              subtitle =
                  '${(minutesUntil / 60).floor()}h ${minutesUntil % 60}m free • Next: ${nextClass.subject}';
            } else if (minutesUntil > 15) {
              subtitle =
                  '${minutesUntil} min break • ${nextClass.subject} in ${nextClass.room}';
            } else {
              subtitle =
                  'Starting soon: ${nextClass.subject} in ${nextClass.room} ⚡';
            }
          } else {
            subtitle =
                '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} scheduled';
          }
        }
      } else {
        statusColor = IrisTokens.brand;
        final tomorrowIndex = (now.weekday % 7) + 1;
        if (dayIndex == tomorrowIndex && _overrideDayIndex == null) {
          title = 'TOMORROW MORNING';
        } else {
          final dayName = FormatGuard.normalizeDay(dayIndex).toUpperCase();
          title = '$dayName SCHEDULE';
        }
        subtitle =
            '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} scheduled';
      }
    }

    return SectionHeader(
      title: title,
      subtitle: subtitle,
      statusIndicator: statusColor,
    );
  }
}

// Student Dashboard

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  static const String _customMakeupSessionsPrefsKey = 'custom_makeup_sessions';
  late Timer _ticker;
  String? _dismissedAnnouncementText;
  ClassSession? _previousClass;
  int? _previousProgressPercent;
  String? _previousNotificationHash;
  String? _previousWidgetHash;
  int? _overrideDayIndex;
  int _bottomNavIndex = 0;
  int _studentTabSlideDirection = 1;
  bool _isStudentNavBusy = false;
  bool _navBarReady = false;
  double? _studentNavDragPosition;
  bool _isStudentNavTracking = false;
  bool _studentNavHasMoved = false;
  List<ClassSession> _cachedSchedule = [];
  DateTime? _lastScheduleUpdate;
  int? _lastMinute;
  bool _isRefreshing = false;
  List<String> _pendingTimetableChanges = [];
  final Map<String, List<ClassSession>> _makeupReplacementHistory = {};
  
  final ScrollController _scrollController = ScrollController();
  final ScrollController _toolsScrollController = ScrollController();
  final ScrollController _aboutScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isMiniMode = false;
  bool _isSearching = false;
  bool _searchFieldFocused = false;
  String _homeSearchQuery = '';
  String _toolsSearchQuery = '';

  final GlobalKey _studentPortalNavKey = GlobalKey(
    debugLabel: 'student_portal_nav',
  );
  final GlobalKey _studentToolsNavKey = GlobalKey(
    debugLabel: 'student_tools_nav',
  );
  final GlobalKey _studentAboutNavKey = GlobalKey(
    debugLabel: 'student_about_nav',
  );
  final GlobalKey _academicsIconKey = GlobalKey(
    debugLabel: 'student_academics_nav',
  );

  ScrollController? get _activeScrollController {
    switch (_bottomNavIndex) {
      case 0:
        return _scrollController;
      case 1:
        return _toolsScrollController;
      case 2:
        return _aboutScrollController;
      default:
        return null;
    }
  }

  void _onScroll() {
    final ctrl = _activeScrollController;
    if (ctrl == null) return;
    final canCollapse = _bottomNavIndex == 0 || _bottomNavIndex == 1;
    final mini = canCollapse && ctrl.hasClients && ctrl.offset > 50;
    if (mini == _isMiniMode) return;
    setState(() => _isMiniMode = mini);
  }

  void _onFocusChange() {
    setState(() => _searchFieldFocused = _searchFocusNode.hasFocus);
  }

  void _updateMiniModeForActiveTab() {
    final ctrl = _activeScrollController;
    final canCollapse = _bottomNavIndex == 0 || _bottomNavIndex == 1;
    final mini = canCollapse && ctrl != null && ctrl.hasClients && ctrl.offset > 50;
    if (mini != _isMiniMode) {
      setState(() => _isMiniMode = mini);
    }
  }

  void _dismissMiniMode() {
    final ctrl = _activeScrollController;
    if (ctrl != null && ctrl.hasClients) {
      ctrl.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuart,
      );
    }
    setState(() {
      _isMiniMode = false;
      _isSearching = false;
      _searchFieldFocused = false;
    });
  }

  Future<void> _triggerBatchSelector() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BatchSelectorSheet(
        memory: widget.memory,
        selected: widget.batch,
      ),
    );

    if (result != null && result != widget.batch) {
      widget.onBatchChanged?.call(result);
      IrisHaptics.actionHeavy();
      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          content: Text('Batch updated to $result'),
        );
      }
    }
  }

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

  Future<void> _checkPendingTimetableChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('ota_timetable_changes');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        if (mounted && decoded.isNotEmpty) {
          setState(() {
            _pendingTimetableChanges = List<String>.from(decoded);
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _clearPendingTimetableChanges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ota_timetable_changes');
    if (mounted) {
      setState(() {
        _pendingTimetableChanges = [];
      });
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
        content: Text('This makeup class belongs to a different batch.'),
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
        content: Text('That makeup class is already in your timeline.'),
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
      builder: (ctx) {
        return GlassSurface(
          settings: IrisGlass.settings(
            ctx,
            blur: 16,
            ambientStrength: 0.70,
            lightAngle: 0.15 * math.pi,
            thickness: 15,
            glassColor: Colors.black.withValues(alpha: 0.05),
            minBlur: 10,
            minThickness: 12,
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
        );
      },
    );

    if (confirm == true) {
      await _removeMakeupSession(session);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _toolsScrollController.addListener(_onScroll);
    _aboutScrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onFocusChange);
    _loadDismissedAnnouncement();
    _checkPendingTimetableChanges();

    // Start remote Firestore listener for real-time announcements, modes & OTA timetable upgrades
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        RemoteConfigService.startRemoteListener(context);
        setState(() => _navBarReady = true);

        // Background session warming on startup
        unawaited(SessionRefresherService.warmSession('swl-sis.comsats.edu.pk', 'student'));
        unawaited(HelpdeskFacultyService().fetchOfflineOnly());
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
          // Update notifications and widget only when the visible schedule state changes.
          unawaited(_updatePersistentNotificationIfNeeded());
          unawaited(_updateWidgetIfNeeded());
        }
      }
    });
    unawaited(_updatePersistentNotificationIfNeeded());
    unawaited(_updateWidgetIfNeeded());
  }

  Future<void> _startForegroundServiceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // Keep the foreground service aligned with the active batch without
    // overwriting the app persona.
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
      'sessions': widget.memory.activeSessions().map((s) => s.toJson()).toList(),
    };
    await prefs.setString('timetable_data', jsonEncode(timetableData));

    final remindersEnabled =
        prefs.getBool('lecture_reminders_enabled') ?? false;
    if (remindersEnabled) {
      // Schedule 5-minute reminders for today's classes
      final todayClasses = widget.memory.activeSessions()
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

    final todayAll = widget.memory.activeSessions()
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
          ? ' • $remaining more today'
          : ' • Last session today';

      final cleanSub = current.subject.replaceAll('[EXAM]', '').trim();
      notifTitle = '🎓 $cleanSub • $progressPercent%';
      notifBody =
          '⏱️ $timeLeft (${current.startTime} - ${current.endTime})$classCount\n📍 ${current.room} • ${current.teacher}';
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
      notificationButtons: [NotificationButton(id: 'open', text: 'Open IRIS')],
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
        final todayClasses = widget.memory.activeSessions()
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _toolsScrollController.removeListener(_onScroll);
    _toolsScrollController.dispose();
    _aboutScrollController.removeListener(_onScroll);
    _aboutScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _ticker.cancel();
    // Don't stop foreground service here - it should persist
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    IrisHaptics.refreshStart();

    setState(() => _isRefreshing = true);

    // Background session warming on pull-to-refresh
    unawaited(SessionRefresherService.warmSession('swl-sis.comsats.edu.pk', 'student'));

    // Simulate data refresh delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Refresh schedule cache
    _updateScheduleCache();

    // Check for pending timetable changes
    await _checkPendingTimetableChanges();

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

    // Check current academic period
    final academicPeriod = RemoteConfigService.activeAcademicPeriod.value;
    if (academicPeriod != 'classes') {
      String notifTitle = '';
      String notifBody = '';
      if (academicPeriod == 'ramadan') {
        notifTitle = '🌙 Ramadan Timings Active';
        notifBody = '🕌 Ramadan Schedule · Compressed lecture hours in effect';
      } else if (academicPeriod == 'sports_week') {
        notifTitle = '🏆 Sports Week active';
        notifBody = '🏅 Sports Week Mode · Enjoy matches & events!';
      } else if (academicPeriod == 'midterms') {
        notifTitle = '✍️ Midterms active';
        notifBody = '📝 Midterm Exams Mode · Good luck!';
      } else if (academicPeriod == 'finals') {
        notifTitle = '🎓 Finals active';
        notifBody = '📝 Final Exams Mode · Finish strong!';
      }

      try {
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
      } catch (e) {
        debugPrint('❌ Persistent notification update failed: $e');
      }
      return;
    }

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
    String _generateStateHash() {
      if (current != null && current.isLive(now)) {
        final duration = LectureDuration.getActualDuration(current);
        final progress = ((currentTime - current.safeStartVal) / duration)
            .clamp(0.0, 1.0);
        final progressPercent = (progress * 100).toInt();
        return 'live_${current.subject}_${progressPercent}';
      } else if (next != null) {
        return 'next_${next.subject}_${next.safeStartVal}';
      }
      return 'idle';
    }

    final currentHash = _generateStateHash();

    // Only update if state changed significantly (class changed or progress milestone reached)
    if (_previousNotificationHash == currentHash && current == _previousClass) {
      return; // No meaningful change, skip update
    }

    _previousNotificationHash = currentHash;

    final todayAll = widget.memory.activeSessions()
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
            ? ' • $remaining more today'
            : ' • Last session today';

        final cleanSub = current.subject.replaceAll('[EXAM]', '').trim();
        notifTitle = '🎓 $cleanSub • $progressPercent%';
        notifBody =
            '⏱️ $timeLeft (${current.startTime} - ${current.endTime})$classCount\n📍 ${current.room} • ${current.teacher}';
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
      
      // Check current academic period
      final academicPeriod = RemoteConfigService.activeAcademicPeriod.value;
      if (academicPeriod != 'classes') {
        String headline = '';
        String subline = '';
        if (academicPeriod == 'ramadan') {
          headline = 'Ramadan Mode';
          subline = 'Compressed schedule active';
        } else if (academicPeriod == 'sports_week') {
          headline = 'Sports Week';
          subline = 'Enjoy matches & events!';
        } else if (academicPeriod == 'midterms') {
          headline = 'Midterm Exams';
          subline = 'Good luck!';
        } else if (academicPeriod == 'finals') {
          headline = 'Final Exams';
          subline = 'Finish strong!';
        }

        // Generate state hash to determine if widget update is needed
        final currentHash = 'mode_${academicPeriod}';
        if (_previousWidgetHash == currentHash) {
          return; // No change
        }
        _previousWidgetHash = currentHash;
        _previousProgressPercent = 0;

        await WidgetService.updateWidgetWithInsight(
          headline: headline,
          subline: subline,
          timeInfo: 'Active',
          teacherInfo: '',
          isLive: false,
          isUrgent: false,
          progressPercentage: 0,
        );
        return;
      }

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
      String _generateWidgetHash() {
        return '${insight.headline}_${insight.isLive}_${progressPercent}_${insight.isUrgent}';
      }

      final currentHash = _generateWidgetHash();

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
        subject: insight.subject,
        room: insight.room,
      );
    } catch (e) {
      debugPrint('⚠️ Widget update failed: $e');
    }
  }

  void _showPortalGlassMenu(BuildContext context) {
    IrisHaptics.actionMedium();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black26,
      builder: (ctx) {
        return Stack(
          children: [
            Positioned(
              bottom: 90,
              left: 24,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: GlassSurface(
                    settings: IrisGlass.settings(
                      context,
                      blur: 24,
                      ambientStrength: 0.85,
                      lightAngle: 0.15 * math.pi,
                      thickness: 18,
                      glassColor: IrisGlass.adaptiveGlassColor(context, darkAlpha: 0.88, lightAlpha: 0.92),
                    ),
                    radius: 28,
                    child: Container(
                      width: 230,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.14),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              pushGlassContainerMorphRoute(
                                context,
                                originKey: _studentPortalNavKey,
                                page: const PortalScreen(
                                  url: 'https://swl-sis.comsats.edu.pk/',
                                  title: 'COMSATS Student Portal',
                                  sessionScope: 'student',
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.school_rounded, color: Color(0xFF3B82F6), size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Student Portal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Divider(height: 1, color: (isDark ? Colors.white12 : Colors.black12)),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              pushGlassContainerMorphRoute(
                                context,
                                originKey: _studentPortalNavKey,
                                page: AcademicsHubScreen(brain: widget.brain),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_stories_rounded, color: Color(0xFF8B5CF6), size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Academics Hub',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : Colors.black87,
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
              ),
            ),
          ],
        );
      },
    );
  }



  Widget _buildGlassPortalMenuItem({
    required BuildContext ctx,
    required bool isDark,
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withOpacity(0.6)
                : const Color(0xFFF1F5F9).withOpacity(0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFFCBD5E1).withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: iconGradient),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.first.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.black38,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTeacherPortal({GlobalKey? originKey}) async {
    if (!mounted) return;
    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      page: const PortalScreen(
        url:
            'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
        title: 'COMSATS Faculty Portal',
        sessionScope: 'faculty',
      ),
    );
  }

  Future<void> _openAbout({GlobalKey? originKey}) async {
    if (!mounted) return;
    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      page: AboutScreen(
        memory: widget.memory,
        onRoleChanged: widget.onRoleChanged,
      ),
    );

    // Widget updates automatically via ticker - no manual refresh needed
  }

  Future<void> _openDepartmentClassesBrowser({GlobalKey? originKey}) async {
    if (!mounted) return;
    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      page: DepartmentClassesScreen(
        memory: widget.memory,
        currentBatch: widget.batch,
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
        showDock: false,
      ),
    );
  }

  Future<void> _openTeacherSearch({GlobalKey? originKey}) async {
    if (!mounted) return;
    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      page: TeacherLocatorScreen(
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
        memory: widget.memory,
        currentBatch: widget.batch,
        showDock: false,
      ),
    );
  }

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
      _isSearching = false;
      _searchController.clear();
      _homeSearchQuery = '';
      _toolsSearchQuery = '';
    });
    _updateMiniModeForActiveTab();

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
    index = index.clamp(0, 2);
    setState(() {
      _studentTabSlideDirection = index > _bottomNavIndex ? 1 : -1;
      _bottomNavIndex = index;
      _isSearching = false;
      _searchController.clear();
      _homeSearchQuery = '';
      _toolsSearchQuery = '';
    });
    _updateMiniModeForActiveTab();
    IrisHaptics.chipSelect();
    if (index == 0) {
      _updateScheduleCache();
    }
  }

  void _handleStudentNavDrag(DragUpdateDetails details, double width) {
    if (width <= 0) return;
    final safeDx = details.localPosition.dx.clamp(0.0, width - 1);
    final itemWidth = width / 3;
    final targetIndex = (safeDx / itemWidth).floor().clamp(0, 2);
    _setStudentTabFromDrag(targetIndex);
  }

  double _studentNavInteractionPosition(int itemCount) {
    if (_isStudentNavTracking && _studentNavDragPosition != null) {
      return _studentNavDragPosition!.clamp(0.0, itemCount - 1.0);
    }
    return _bottomNavIndex.toDouble();
  }

  int _studentNavDisplayIndex(int itemCount) {
    return _studentNavInteractionPosition(itemCount)
        .round()
        .clamp(0, itemCount - 1);
  }

  void _beginStudentNavTracking(
    Offset localPosition,
    double width,
    int itemCount,
  ) {
    if (width <= 0) return;
    setState(() {
      _isStudentNavTracking = true;
      _studentNavHasMoved = false;
      final slotWidth = width / itemCount;
      _studentNavDragPosition = (localPosition.dx / slotWidth).clamp(
        0.0,
        itemCount - 1.0,
      );
    });
  }

  void _updateStudentNavTracking(
    Offset localPosition,
    double width,
    int itemCount,
  ) {
    if (!_isStudentNavTracking || width <= 0) return;
    setState(() {
      _studentNavHasMoved = true;
      final slotWidth = width / itemCount;
      _studentNavDragPosition = (localPosition.dx / slotWidth).clamp(
        0.0,
        itemCount - 1.0,
      );
    });
  }

  void _endStudentNavTracking(int itemCount) {
    if (!_isStudentNavTracking) return;
    if (!_studentNavHasMoved) {
      _cancelStudentNavTracking();
      return;
    }
    final targetIndex = _studentNavInteractionPosition(itemCount)
        .round()
        .clamp(0, itemCount - 1);
    setState(() {
      _isStudentNavTracking = false;
      _studentNavDragPosition = null;
      _studentNavHasMoved = false;
    });
    _setStudentTabFromDrag(targetIndex);
  }

  void _cancelStudentNavTracking() {
    if (!_isStudentNavTracking) return;
    setState(() {
      _isStudentNavTracking = false;
      _studentNavDragPosition = null;
      _studentNavHasMoved = false;
    });
  }

  Widget _buildStudentTabContent() {
    switch (_bottomNavIndex) {
      case 1:
        return const PortalScreen(
          key: PageStorageKey<String>('student_tab_portal'),
          url: 'https://swl-sis.comsats.edu.pk/',
          title: 'COMSATS Student Portal',
          sessionScope: 'student',
          showBackButton: false,
        );
      case 2:
        return const AcademicsHubScreen(
          key: PageStorageKey<String>('student_tab_academics'),
        );
      case 3:
        return ToolsScreen(
          key: const PageStorageKey<String>('student_tab_tools'),
          memory: widget.memory,
          batch: widget.batch,
          brain: widget.brain,
          onRoleChanged: widget.onRoleChanged,
          onBatchChanged: widget.onBatchChanged,
          onAddMakeupClass: _addMakeupSession,
          onRemoveMakeupClass: _removeMakeupSession,
        );
      case 4:
        return AboutScreen(
          key: const PageStorageKey<String>('student_tab_about'),
          memory: widget.memory,
          onRoleChanged: widget.onRoleChanged,
          onBatchChanged: widget.onBatchChanged,
          onToggleTheme: widget.onToggleTheme,
          currentThemeMode: widget.currentThemeMode,
          onSetThemeMode: widget.onSetThemeMode,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _loadDismissedAnnouncement() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _dismissedAnnouncementText = prefs.getString('iris_dismissed_announcement');
      });
    }
  }

  Future<void> _dismissAnnouncement(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('iris_dismissed_announcement', text);
    if (mounted) {
      setState(() {
        _dismissedAnnouncementText = text;
      });
    }
    IrisHaptics.actionSoft();
  }

  Widget _buildAnnouncementBanner(BuildContext context, Map<String, dynamic> announcement) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final message = announcement['message']?.toString() ?? '';
    
    if (message.isEmpty || _dismissedAnnouncementText == message) {
      return const SizedBox.shrink();
    }

    final rawTime = announcement['updated_at'];
    DateTime? dateTime;
    if (rawTime is Timestamp) {
      dateTime = rawTime.toDate();
    } else if (rawTime is DateTime) {
      dateTime = rawTime;
    } else if (rawTime is String) {
      dateTime = DateTime.tryParse(rawTime);
    }
    final formattedTime = RemoteConfigService.formatTimestamp(dateTime);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(message),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.15),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GlassSurface(
                settings: IrisGlass.settings(
                  context,
                  blur: 20,
                  ambientStrength: 0.85,
                  lightAngle: 0.15 * math.pi,
                  thickness: 18,
                  glassColor: isDark 
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.09)
                      : Colors.white.withValues(alpha: 0.92),
                ),
                radius: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          Icons.campaign_rounded,
                          size: 20,
                          color: isDark ? Colors.white : const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'CAMPUS BROADCAST',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: isDark ? Colors.amber[200] : const Color(0xFFB45309),
                                  ),
                                ),
                                Text(
                                  formattedTime.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.amber[200]!.withValues(alpha: 0.6) : const Color(0xFFB45309).withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _dismissAnnouncement(message),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black54,
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
      ),
    );
  }

  Widget _buildPersistentAnnouncementCard(BuildContext context, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      sliver: SliverToBoxAdapter(
        child: ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: RemoteConfigService.liveAnnouncement,
          builder: (context, announcement, _) {
            if (announcement == null) {
              return _buildEmptyNoticeboard(context, isDark);
            }
            
            final message = announcement['message']?.toString() ?? '';
            if (message.isEmpty) {
              return _buildEmptyNoticeboard(context, isDark);
            }

            return _buildActiveNoticeCard(context, isDark, message, announcement);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyNoticeboard(BuildContext context, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: GlassSurface(
        settings: IrisGlass.settings(
          context,
          blur: 15,
          ambientStrength: 0.7,
          lightAngle: 0.15 * math.pi,
          thickness: 10,
          glassColor: isDark 
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.01),
        ),
        radius: 20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                ),
                child: Icon(
                  Icons.notifications_off_rounded,
                  size: 18,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CAMPUS NOTICEBOARD',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'All Quiet on Campus • No active broadcasts right now',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveNoticeCard(
    BuildContext context,
    bool isDark,
    String message,
    Map<String, dynamic> announcement,
  ) {
    final hasDismissedBanner = _dismissedAnnouncementText == message;
    final accentColor = const Color(0xFFF59E0B);

    final rawTime = announcement['updated_at'];
    DateTime? dateTime;
    if (rawTime is Timestamp) {
      dateTime = rawTime.toDate();
    } else if (rawTime is DateTime) {
      dateTime = rawTime;
    } else if (rawTime is String) {
      dateTime = DateTime.tryParse(rawTime);
    }
    final formattedTime = RemoteConfigService.formatTimestamp(dateTime);

    final noticeKey = GlobalKey();
    return GestureDetector(
      key: noticeKey,
      onTap: () {
        IrisHaptics.selectionClick();
        pushGlassContainerMorphRoute(
          context,
          originKey: noticeKey,
          page: Scaffold(
            backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Campus Notice Details', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign_rounded, size: 16, color: accentColor),
                          const SizedBox(width: 6),
                          Text(
                            'REAL-TIME BROADCAST',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accentColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: IrisTextStyles.headline(context).copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Broadcasted: ${formattedTime.toUpperCase()}',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: GlassSurface(
            settings: IrisGlass.settings(
              context,
              blur: 24,
              ambientStrength: 0.85,
              lightAngle: 0.15 * math.pi,
              thickness: 18,
              glassColor: isDark 
                  ? accentColor.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.90),
            ),
            radius: 20,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PulsingRadarBadge(
                    icon: Icons.campaign_rounded,
                    color: accentColor,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'CAMPUS NOTICEBOARD',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: isDark ? Colors.amber[200] : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                            if (hasDismissedBanner)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.visibility_off_rounded,
                                      size: 10,
                                      color: (isDark ? Colors.white54 : Colors.black54),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'BANNER DISMISSED',
                                      style: TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: (isDark ? Colors.white54 : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_tethering_rounded,
                                  size: 12,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'REAL-TIME BROADCAST',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'BROADCASTED: ${formattedTime.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: isDark ? Colors.amber[200]!.withValues(alpha: 0.8) : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSmartClassTrackerPill(BuildContext context, bool isDark, DateTime now) {
    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);

    String title = '';
    String subtitle = '';
    IconData icon = Icons.event_note_rounded;
    Color accentColor = IrisTokens.brand;
    bool isActive = false;
    
    if (current != null) {
      title = current.subject;
      accentColor = IrisTokens.brand;
      icon = Icons.school_rounded;
      final endVal = current.safeEndVal;
      final currentVal = now.hour + (now.minute / 60.0);
      final remainingMinutes = ((endVal - currentVal) * 60).round();
      subtitle = 'Ongoing in ${current.room} • ${remainingMinutes}m remaining';
      isActive = true;
    } else if (next != null) {
      title = 'Next Class: ${next.subject}';
      accentColor = IrisTokens.purple;
      icon = Icons.hourglass_top_rounded;
      final startVal = next.safeStartVal;
      final currentVal = now.hour + (now.minute / 60.0);
      final minutesToStart = ((startVal - currentVal) * 60).round();
      if (minutesToStart > 0 && minutesToStart <= 60) {
        subtitle = 'Starts in ${minutesToStart}m • ${next.room}';
        isActive = true;
      } else {
        subtitle = 'Scheduled at ${next.startTime} • ${next.room}';
      }
    } else {
      title = 'All classes ended';
      subtitle = 'Enjoy the rest of your day! 🎉';
      accentColor = IrisTokens.success;
      icon = Icons.done_all_rounded;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        borderRadius: 24,
        accentColor: accentColor,
        glow: false,
        enableShadow: false,
        backgroundColor: Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              _TrackerPulseIndicator(color: accentColor),
            ],
          ],
        ),
      ),
    );
  }

  void _showPortalContextSheet(bool isDark) {
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
                  Icons.public_rounded,
                  color: isDark ? Colors.white : IrisTokens.brand,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  'Portal Navigator',
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
              title: 'Open in System Browser',
              subtitle: 'Launch SWL-SIS in default browser',
              icon: Icons.open_in_browser_rounded,
              color: IrisTokens.brand,
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  final uri = Uri.parse('https://swl-sis.comsats.edu.pk/');
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
            ),
            const SizedBox(height: 12),
            _buildContextActionTile(
              isDark,
              title: 'Refresh Portal Frame',
              subtitle: 'Reload current COMSATS webpage',
              icon: Icons.refresh_rounded,
              color: IrisTokens.success,
              onTap: () {
                Navigator.pop(sheetContext);
                showIrisFrostedSnackBar(context, content: const Text('Portal frame reloading...'));
              },
            ),
            const SizedBox(height: 12),
            _buildContextActionTile(
              isDark,
              title: 'Clear Cache & Cookies',
              subtitle: 'Reset portal local web session storage',
              icon: Icons.delete_sweep_rounded,
              color: IrisTokens.error,
              onTap: () {
                Navigator.pop(sheetContext);
                showIrisFrostedSnackBar(context, content: const Text('Session cache cleared successfully!'));
              },
            ),
          ],
        ),
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
                showIrisFrostedSnackBar(
                  context,
                  content: Text('Graphics set to ${ThemeSignals.useMinimalTheme.value ? 'MINIMAL' : 'PREMIUM'}'),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildContextActionTile(
              isDark,
              title: 'Reset Offline Local Storage',
              subtitle: 'Clear local timetable caches & load seed',
              icon: Icons.restore_rounded,
              color: IrisTokens.warning,
              onTap: () async {
                Navigator.pop(sheetContext);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('helpdesk_has_doc_draft');
                showIrisFrostedSnackBar(context, content: const Text('Caches cleared successfully!'));
              },
            ),
            const SizedBox(height: 12),
            _buildContextActionTile(
              isDark,
              title: 'Sensory Haptics Diagnostics',
              subtitle: 'Pulse interaction engine triggers',
              icon: Icons.analytics_rounded,
              color: IrisTokens.success,
              onTap: () {
                Navigator.pop(sheetContext);
                IrisHaptics.intelligencePulse();
                showIrisFrostedSnackBar(context, content: const Text('Sensory engine diagnostics pulse sent.'));
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

  Widget _buildStudentBottomNavBar(bool isDark) {
    final activeColor = isDark ? Colors.white : Colors.black87;
    final glowColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    
    return GlassSearchableBottomBar(
      tabs: [
        GlassBottomBarTab(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home_rounded),
          label: 'Home',
          glowColor: glowColor,
        ),
        GlassBottomBarTab(
          icon: const Icon(Icons.construction_outlined),
          activeIcon: const Icon(Icons.construction_rounded),
          label: 'Tools',
          glowColor: glowColor,
        ),
        GlassBottomBarTab(
          icon: const Icon(Icons.info_outline_rounded),
          activeIcon: const Icon(Icons.info_rounded),
          label: 'About',
          glowColor: glowColor,
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
        glassColor: Colors.transparent,
      ),
      searchConfig: GlassSearchBarConfig(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: _bottomNavIndex == 0 ? 'Search classes...' : 'Search tools...',
        expandWhenActive: _bottomNavIndex == 0 ? false : (!_isMiniMode || _isSearching),
        showsCancelButton: true,
        textColor: isDark ? Colors.white : Colors.black,
        cursorColor: activeColor,
        hintStyle: TextStyle(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
          fontSize: 13,
        ),
        searchIcon: _bottomNavIndex == 0
            ? lgw.GlassMenu(
                menuWidth: 230,
                settings: IrisGlass.widgetsSettings(
                  context,
                  blur: 20,
                  thickness: 18,
                  ambientStrength: 0.7,
                  lightAngle: 0.15 * math.pi,
                ),
                triggerBuilder: (context, toggleMenu) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: toggleMenu,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.public_rounded, key: _studentPortalNavKey),
                    ),
                  );
                },
                items: [
                  lgw.GlassMenuItem(
                    title: 'Student Portal',
                    icon: const Icon(Icons.school_rounded, color: Color(0xFF3B82F6), size: 18),
                    onTap: () {
                      pushGlassContainerMorphRoute(
                        context,
                        originKey: _studentPortalNavKey,
                        page: const PortalScreen(
                          url: 'https://swl-sis.comsats.edu.pk/',
                          title: 'COMSATS Student Portal',
                          sessionScope: 'student',
                        ),
                      );
                    },
                  ),
                  const lgw.GlassMenuDivider(),
                  lgw.GlassMenuItem(
                    title: 'Academics Hub',
                    icon: const Icon(Icons.auto_stories_rounded, color: Color(0xFF8B5CF6), size: 18),
                    onTap: () {
                      pushGlassContainerMorphRoute(
                        context,
                        originKey: _studentPortalNavKey,
                        page: AcademicsHubScreen(brain: widget.brain),
                      );
                    },
                  ),
                ],
              )
            : null,
        searchIconColor: isDark ? Colors.white70 : Colors.black87,
        onSearchToggle: (active) {
          if (active) {
            if (_bottomNavIndex == 2) {
              _showAboutContextSheet(isDark);
              return;
            }
          }
          setState(() {
            _isSearching = active;
          });
          if (!active) {
            _searchController.clear();
            setState(() {
              _homeSearchQuery = '';
              _toolsSearchQuery = '';
            });
            _updateScheduleCache();
          }
        },
        onChanged: (val) {
          setState(() {
            if (_bottomNavIndex == 0) {
              _homeSearchQuery = val;
              _updateScheduleCache();
            } else if (_bottomNavIndex == 1) {
              _toolsSearchQuery = val;
            }
          });
        },
        collapsedLogoBuilder: (context) {
          final icons = [
            Icons.home_rounded,
            Icons.construction_rounded,
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


  Future<void> _openMakeupScheduler({GlobalKey? originKey}) async {
    if (!mounted) return;

    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: MakeupLectureScheduler(
        memory: widget.memory,
        brain: widget.brain,
        batch: widget.batch,
        onAddMakeupClass: _addMakeupSession,
        onRemoveMakeupClass: _removeMakeupSession,
        onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
        showDock: false,
      ),
    );

    if (!mounted) return;
    _updateScheduleCache();
    setState(() {});
  }

  Widget _buildSystemUpdateBanner(BuildContext context, Map<String, dynamic> update) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vName = update['version_name']?.toString() ?? '1.1.0';
    final notes = update['release_notes']?.toString() ?? '';
    final apkUrl = update['apk_url']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: IrisTokens.brand.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          ClipRRect(
            borderRadius: IrisTokens.cardRadius,
            child: GlassSurface(
              settings: IrisGlass.settings(
                context,
                blur: 20,
                ambientStrength: 0.8,
                lightAngle: 0.15 * math.pi,
                thickness: 18,
                glassColor: isDark 
                    ? IrisTokens.brand.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.85),
              ),
              radius: 20,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: IrisTokens.brand.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: IrisTokens.brand.withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            Icons.system_update_rounded,
                            size: 18,
                            color: isDark ? Colors.white : IrisTokens.brand,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SYSTEM UPDATE AVAILABLE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: isDark ? Colors.white70 : IrisTokens.brand,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'IRIS Enhanced v$vName',
                                style: IrisTextStyles.headline(context).copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            IrisHaptics.selectionClick();
                            RemoteConfigService.dismissAdminUpdateBanner(vName);
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                          ),
                          tooltip: 'Dismiss update',
                        ),
                      ],
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        notes,
                        style: IrisTextStyles.caption(context).copyWith(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: IrisTokens.buttonRadius,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        elevation: 0,
                      ),
                      onPressed: () {
                        IrisHaptics.actionHeavy();
                        RemoteConfigService.dismissAdminUpdateBanner(vName);
                        AppUpdateService.showUpdateDialog(context, updateInfo: update);
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text(
                        'Install Update Now',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
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

  Widget _buildTimetableDiffCard(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24.0,
      border: Border.all(
        color: IrisTokens.warning.withValues(alpha: isDark ? 0.3 : 0.2),
        width: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IrisTokens.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: IrisTokens.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIMETABLE MODIFIED',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                        color: IrisTokens.warning,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Recent schedule updates for your batch',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._pendingTimetableChanges.map((change) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: IrisTokens.warning.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      change,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  IrisHaptics.actionSoft();
                  _clearPendingTimetableChanges();
                },
                icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Acknowledge & Dismiss',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: IrisTokens.warning,
                  shadowColor: IrisTokens.warning.withValues(alpha: 0.3),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'AM';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      if (parts[0].length >= 2) {
        return parts[0].substring(0, 2).toUpperCase();
      }
      return parts[0].toUpperCase();
    }
    final first = parts.first.isNotEmpty ? parts.first.substring(0, 1).toUpperCase() : '';
    final last = parts.last.isNotEmpty ? parts.last.substring(0, 1).toUpperCase() : '';
    return '$first$last';
  }

  String _getSemesterOrdinal(int sem) {
    switch (sem) {
      case 1: return '1st';
      case 2: return '2nd';
      case 3: return '3rd';
      default: return '${sem}th';
    }
  }

  Widget _buildExamModeDashboardBanner(BuildContext context, bool isDark) {
    return ValueListenableBuilder<String>(
      valueListenable: RemoteConfigService.activeAcademicPeriod,
      builder: (context, period, _) {
        if (period == 'classes') return const SliverToBoxAdapter(child: SizedBox.shrink());

        final isMidterm = period == 'midterms';
        final isFinal = period == 'finals';
        final isSports = period == 'sports_week';

        final accentColor = isMidterm
            ? const Color(0xFFF59E0B)
            : (isFinal
                ? const Color(0xFF8B5CF6)
                : const Color(0xFF10B981));

        final secondaryAccent = isMidterm
            ? const Color(0xFFD97706)
            : (isFinal
                ? const Color(0xFFEC4899)
                : const Color(0xFF06B6D4));

        final titleText = isMidterm
            ? '✍️ MIDTERM DATESHEET MATRIX'
            : (isFinal
                ? '🎓 FINAL EXAM DATESHEET MATRIX'
                : (isSports
                    ? '🏆 SPORTS GALA FESTIVAL SCHEDULE'
                    : '🌙 RAMADAN TIMINGS IN EFFECT'));

        final subText = isMidterm || isFinal
            ? 'Tap to search full exam paper schedule, halls & invigilators across all batches ➔'
            : (isSports
                ? 'Sports Week Gala active · Enjoy match fixtures & events!'
                : 'All lectures are running on compressed 45-min / 1-hr Ramadan schedule.');

        return SliverToBoxAdapter(
          child: RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: GestureDetector(
                onTap: () {
                  IrisHaptics.chipSelect();
                  if (isMidterm || isFinal) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExamGridDashboard(
                          period: period,
                          batch: widget.batch,
                          onToggleTheme: widget.onToggleTheme,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: isDark ? 0.22 : 0.14),
                        secondaryAccent.withValues(alpha: isDark ? 0.10 : 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isMidterm || isFinal
                              ? Icons.grid_view_rounded
                              : (isSports ? Icons.emoji_events_rounded : Icons.nights_stay_rounded),
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subText,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isMidterm || isFinal)
                        Icon(
                          Icons.chevron_right_rounded,
                          color: accentColor.withValues(alpha: 0.8),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeDashboard(
    BuildContext context,
    bool isDark,
    DateTime now,
    String dateLabel,
    TemporalInsight insight,
    List<ClassSession> filteredSchedule,
    List<ClassSession> schedule,
  ) {
    final isStudentsWeek = RemoteConfigService.activeAcademicPeriod.value == 'sports_week';
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: isStudentsWeek ? const Color(0xFF10B981) : IrisTokens.brand,
        backgroundColor: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const ButterScrollPhysics(),
          cacheExtent: 500,
          slivers: [
            if (_pendingTimetableChanges.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _buildTimetableDiffCard(isDark),
                ),
              ),
            ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: RemoteConfigService.latestApkUpdate,
              builder: (context, updateInfo, _) {
                if (updateInfo == null) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildSystemUpdateBanner(context, updateInfo),
                  ),
                );
              },
            ),
            if (isStudentsWeek) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: StudentsWeekHeaderCard(
                    userName: widget.userName ?? 'Student',
                    batch: widget.batch,
                    onToggleTheme: widget.onToggleTheme,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: ClassesAnimationWidget(
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 44),
                          child: Row(
                            children: [
                              lgw.GlassMenu(
                                menuWidth: 220,
                                triggerBuilder: (context, toggleMenu) {
                                  return GestureDetector(
                                    onTap: toggleMenu,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
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
                                      child: Center(
                                        child: Text(
                                          _getInitials(widget.userName),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                items: [
                                  lgw.GlassMenuItem(
                                    title: 'Student Mode',
                                    isSelected: true,
                                    icon: const Icon(Icons.school_rounded, size: 18),
                                    onTap: () {},
                                  ),
                                  lgw.GlassMenuItem(
                                    title: 'Faculty Mode',
                                    isSelected: false,
                                    icon: const Icon(Icons.badge_rounded, size: 18),
                                    onTap: () {
                                      widget.onRoleChanged?.call('faculty');
                                    },
                                  ),
                                  const lgw.GlassMenuDivider(),
                                  lgw.GlassMenuItem(
                                    title: 'Change Active Batch',
                                    icon: const Icon(Icons.layers_rounded, size: 18),
                                    onTap: () {
                                      _triggerBatchSelector();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getSmartGreeting(now.hour),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.userName ?? 'Student',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(99),
                                              border: Border.all(
                                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                              ),
                                            ),
                                            child: Text(
                                              '${widget.batch}  •  ${_getSemesterOrdinal(BatchKey.parse(widget.batch).dynamicSemester)} Sem',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        ValueListenableBuilder<String>(
                                          valueListenable: RemoteConfigService.activeAcademicPeriod,
                                          builder: (context, period, _) {
                                            final modeColor = period == 'ramadan' || period == 'sports_week'
                                                ? const Color(0xFF10B981)
                                                : (period == 'midterms' ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6));
                                            final modeLabel = period == 'ramadan'
                                                ? '🌙 RAMADAN'
                                                : (period == 'sports_week'
                                                    ? '🏆 GALA'
                                                    : (period == 'midterms' ? '✍️ MIDTERMS' : '🎓 FINALS'));
                                            if (period == 'classes') return const SizedBox.shrink();
                                            return Padding(
                                              padding: const EdgeInsets.only(left: 6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: modeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                                  borderRadius: BorderRadius.circular(99),
                                                  border: Border.all(
                                                    color: modeColor.withValues(alpha: 0.4),
                                                    width: 1.0,
                                                  ),
                                                ),
                                                child: Text(
                                                  modeLabel,
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: modeColor,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Academics Hub Screen Access
                              Container(
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    IrisHaptics.actionMedium();
                                    pushIconLaunchRoute(
                                      context,
                                      page: AcademicsHubScreen(brain: widget.brain),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.auto_stories_rounded,
                                    size: 20,
                                    color: isDark ? Colors.white : IrisTokens.brand,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Theme Toggle Button
                              Container(
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: widget.onToggleTheme,
                                  icon: Icon(
                                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                    size: 20,
                                    color: isDark ? Colors.white : IrisTokens.brand,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
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
                                            IrisTokens.success.withValues(alpha: 0.8),
                                          ]
                                        : [
                                            IrisTokens.brand,
                                            IrisTokens.brandLight,
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (insight.isUrgent
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      insight.headline,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                        letterSpacing: 0.3,
                                        height: 1.2,
                                        color: insight.isLive ? IrisTokens.success : null,
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
                                      ? IrisTokens.success.withValues(alpha: 0.4)
                                      : IrisTokens.brand.withValues(alpha: 0.3),
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
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.72)
                                        : Colors.black.withValues(alpha: 0.55),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (insight.isLive) ...[
                            const SizedBox(height: 14),
                            Builder(
                              builder: (context) {
                                final currentClass = widget.brain.getCurrentClass(widget.batch, now);
                                if (currentClass != null) {
                                  final currentTime = now.hour + (now.minute / 60.0);
                                  final duration = LectureDuration.getActualDuration(currentClass);
                                  final actualEndTime = LectureDuration.getActualEndTime(currentClass);
                                  final progress = ((currentTime - currentClass.safeStartVal) / duration).clamp(0.0, 1.0);
                                  final minutesLeft = ((actualEndTime - currentTime) * 60).toInt().clamp(0, (duration * 60).toInt());

                                  String progressLabel = '';
                                  if (minutesLeft >= 60) {
                                    final hours = minutesLeft ~/ 60;
                                    final mins = minutesLeft % 60;
                                    progressLabel = mins > 0 ? '${hours}h ${mins}m left' : '${hours}h left';
                                  } else {
                                    progressLabel = '${minutesLeft}m left';
                                  }

                                  return Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: TweenAnimationBuilder<double>(
                                          duration: const Duration(milliseconds: 768),
                                          curve: IrisMotion.entrance,
                                          tween: Tween<double>(begin: 0.0, end: progress),
                                          builder: (context, value, child) => Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: IrisTokens.success.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: value.clamp(0.0, 1.0),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [IrisTokens.success, IrisTokens.success, IrisTokens.successDark],
                                                  ),
                                                  borderRadius: BorderRadius.circular(6),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: IrisTokens.success.withValues(alpha: 0.28),
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
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                              color: IrisTokens.success.withValues(alpha: 0.7),
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
                          if (insight.teacherInfo != null && insight.teacherInfo!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: IrisTokens.brand.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 12,
                                      color: IrisTokens.brand.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      insight.teacherInfo!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
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
            _buildPersistentAnnouncementCard(context, isDark),
            _buildExamModeDashboardBanner(context, isDark),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: _timelineTitle(schedule, now, _overrideDayIndex),
                      subtitle: _timelineSubtitle(schedule, now, _overrideDayIndex),
                      statusIndicator: _getTimelineStatusColor(widget.brain, widget.batch, now),
                    ),
                    ValueListenableBuilder<DateTime?>(
                      valueListenable: RemoteConfigService.lastTimetableUpdateTime,
                      builder: (context, lastSync, _) {
                        if (lastSync == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Timetable synced: ${RemoteConfigService.formatTimestamp(lastSync)}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: (isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
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
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      IrisTokens.brand.withValues(alpha: 0.15),
                                      IrisTokens.brandLight.withValues(alpha: 0.08),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: IrisTokens.brand.withValues(alpha: 0.14),
                                      blurRadius: 8,
                                      spreadRadius: -4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.beach_access_rounded,
                                  size: 40,
                                  color: IrisTokens.brand.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No classes scheduled',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  letterSpacing: 0.3,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Enjoy your free time! 🎉',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
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
                          final nextSession = (fullIndex >= 0 && fullIndex + 1 < schedule.length) ? schedule[fullIndex + 1] : null;
                          return StaggeredListItem(
                            index: index,
                            child: RepaintBoundary(
                              child: ClassCard(
                                key: ValueKey('class_${session.subject}_${session.startTime}'),
                                session: session,
                                nextSession: nextSession,
                                isFacultyView: false,
                                onRemoveMakeup: _isMakeupSession(session) ? () => _confirmAndRemoveMakeupSession(session) : null,
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
            const SliverToBoxAdapter(child: SizedBox(height: 126)),
          ],
        ),
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
    final filteredSchedule = schedule;

    final double sysBottom = MediaQuery.of(context).padding.bottom;
    final double pillBottom;
    final double pillLeft;
    final double pillRight;
    final double pillOpacity;
    final bool isHome = _bottomNavIndex == 0;

    if (isHome) {
      if (_isMiniMode && !_isSearching) {
        pillBottom = 12.0 + sysBottom;
        pillLeft = 16.0 + 50.0 + 6.0; // 72.0 (Leaves space for collapsed Home button)
        pillRight = 16.0 + 50.0 + 6.0; // 72.0 (Leaves space for collapsed Search button)
        pillOpacity = 1.0;
      } else if (_isSearching) {
        pillBottom = -64.0;
        pillLeft = 16.0;
        pillRight = 16.0;
        pillOpacity = 0.0;
      } else {
        pillBottom = 80.0 + sysBottom;
        pillLeft = 16.0;
        pillRight = 16.0;
        pillOpacity = 1.0;
      }
    } else {
      pillBottom = -64.0;
      pillLeft = 16.0;
      pillRight = 16.0;
      pillOpacity = 0.0;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          Positioned(
            width: 0,
            height: 0,
            child: SizedBox.shrink(
              child: HeadlessPortalSync(
                url: 'https://swl-sis.comsats.edu.pk/',
                onSyncComplete: (tasks) {
                  debugPrint('IRIS Dashboard: Headless sync complete with ${tasks.length} tasks.');
                },
              ),
            ),
          ),
          Positioned.fill(
            child: IndexedStack(
              index: _bottomNavIndex,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: RemoteConfigService.activeAcademicPeriod,
                  builder: (context, period, _) {
                    final activeWidget = KeyedSubtree(
                      key: ValueKey('home-$period'),
                      child: _buildHomeDashboard(
                        context,
                        isDark,
                        now,
                        dateLabel,
                        insight,
                        filteredSchedule,
                        schedule,
                      ),
                    );

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 550),
                      switchInCurve: Curves.easeInOutCubic,
                      switchOutCurve: Curves.easeInOutCubic,
                      transitionBuilder: (child, animation) {
                        final scale = Tween<double>(begin: 0.94, end: 1.0).animate(
                          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                        );
                        final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(animation);
                        final slide = Tween<Offset>(
                          begin: const Offset(0.0, 0.06),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

                        return FadeTransition(
                          opacity: opacity,
                          child: ScaleTransition(
                            scale: scale,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: activeWidget,
                    );
                  },
                ),
                ToolsScreen(
                  key: const PageStorageKey<String>('student_tab_tools'),
                  memory: widget.memory,
                  batch: widget.batch,
                  brain: widget.brain,
                  onRoleChanged: widget.onRoleChanged,
                  onBatchChanged: widget.onBatchChanged,
                  onAddMakeupClass: _addMakeupSession,
                  onRemoveMakeupClass: _removeMakeupSession,
                  scrollController: _toolsScrollController,
                  searchQuery: _toolsSearchQuery,
                ),
                AboutScreen(
                  key: const PageStorageKey<String>('student_tab_about'),
                  memory: widget.memory,
                  onRoleChanged: widget.onRoleChanged,
                  onBatchChanged: widget.onBatchChanged,
                  scrollController: _aboutScrollController,
                  onToggleTheme: widget.onToggleTheme,
                  currentThemeMode: widget.currentThemeMode,
                  onSetThemeMode: widget.onSetThemeMode,
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: RemoteConfigService.liveAnnouncement,
                builder: (context, announcement, _) {
                  if (announcement != null) {
                    return _buildAnnouncementBanner(context, announcement);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
            bottom: pillBottom,
            left: pillLeft,
            right: pillRight,
            height: 60.0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: pillOpacity,
              child: lgw.GlassMenu(
                menuWidth: 200,
                triggerBuilder: (context, toggleMenu) {
                  return GestureDetector(
                    onTap: toggleMenu,
                    child: _buildSmartClassTrackerPill(context, isDark, now),
                  );
                },
                items: [
                  lgw.GlassMenuItem(
                    title: 'Open Class Hub',
                    icon: const Icon(Icons.hub_rounded, size: 18),
                    onTap: () {
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
                        builder: (sheetContext) => LiveClassHubSheet(
                          brain: widget.brain,
                          memory: widget.memory,
                          batch: widget.batch,
                          sessions: _cachedSchedule,
                        ),
                      );
                    },
                  ),
                  lgw.GlassMenuItem(
                    title: 'Locate Classroom',
                    icon: const Icon(Icons.meeting_room_rounded, size: 18),
                    onTap: () {
                      pushGlassContainerMorphRoute(
                        context,
                        page: RoomFinderScreen(memory: widget.memory, brain: widget.brain),
                        accentColor: const Color(0xFF14B8A6),
                      );
                    },
                  ),
                  lgw.GlassMenuItem(
                    title: 'Locate Instructor',
                    icon: const Icon(Icons.person_search_rounded, size: 18),
                    onTap: () {
                      final currentClass = widget.brain.getCurrentClass(widget.batch, now);
                      pushGlassContainerMorphRoute(
                        context,
                        page: TeacherLocatorScreen(
                          brain: widget.brain,
                          memory: widget.memory,
                          currentBatch: widget.batch,
                          initialTeacherQuery: currentClass?.teacher,
                          autoSearchInitial: currentClass != null,
                          showBackButton: true,
                        ),
                        accentColor: const Color(0xFF8B5CF6),
                      );
                    },
                  ),
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

    if (_homeSearchQuery.isNotEmpty) {
      final query = _homeSearchQuery.toLowerCase();
      return mergedSchedule.where((s) =>
        s.subject.toLowerCase().contains(query) ||
        s.teacher.toLowerCase().contains(query) ||
        s.room.toLowerCase().contains(query)
      ).toList();
    }

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
    final period = RemoteConfigService.activeAcademicPeriod.value;
    if (schedule.isEmpty && overrideDay != null) {
      final dayName = FormatGuard.normalizeDay(overrideDay);
      if (period == 'midterms') return '$dayName Midterm Papers';
      if (period == 'finals') return '$dayName Final Exams';
      if (period == 'sports_week') return '$dayName Gala Timetable';
      if (period == 'ramadan') return '$dayName Ramadan Timeline';
      return '$dayName Timeline';
    }
    if (schedule.isEmpty) {
      if (period == 'midterms') return 'No Midterm Papers';
      if (period == 'finals') return 'No Final Exams';
      if (period == 'sports_week') return 'No Gala Events';
      return 'No Classes';
    }
    final dayIndex = overrideDay ?? schedule.first.dayIndex;

    if (dayIndex == now.weekday) {
      if (period == 'midterms') return 'Today\'s Midterm Papers';
      if (period == 'finals') return 'Today\'s Final Exams';
      if (period == 'sports_week') return 'Today\'s Gala Schedule';
      if (period == 'ramadan') return 'Today\'s Ramadan Timeline';
      return 'Today\'s Timeline';
    }

    final tomorrowIndex = (now.weekday % 7) + 1;
    if (dayIndex == tomorrowIndex && overrideDay == null) {
      if (period == 'midterms') return 'Tomorrow\'s Midterms';
      if (period == 'finals') return 'Tomorrow\'s Finals';
      if (period == 'sports_week') return 'Tomorrow\'s Gala Events';
      return 'Tomorrow Morning';
    }

    final dayName = FormatGuard.normalizeDay(dayIndex);
    if (period == 'midterms') return '$dayName Midterms';
    if (period == 'finals') return '$dayName Finals';
    if (period == 'sports_week') return '$dayName Gala Schedule';
    if (period == 'ramadan') return '$dayName Ramadan Timeline';
    return '$dayName Timeline';
  }

  String _timelineSubtitle(
    List<ClassSession> schedule,
    DateTime now,
    int? overrideDay,
  ) {
    final period = RemoteConfigService.activeAcademicPeriod.value;
    if (schedule.isEmpty && overrideDay != null) {
      if (period == 'midterms' || period == 'finals') return 'No exam papers scheduled • All clear! 🎉';
      if (period == 'sports_week') return 'No gala matches scheduled • Enjoy! 🎉';
      return 'No classes scheduled • Free day! 🎉';
    }
    if (schedule.isEmpty) return 'No sessions in the registry';

    final dayIndex = overrideDay ?? schedule.first.dayIndex;
    final currentTime = now.hour + (now.minute / 60.0);

    final noun = period == 'midterms' || period == 'finals' ? 'paper' : (period == 'sports_week' ? 'event' : 'class');
    final nouns = period == 'midterms' || period == 'finals' ? 'papers' : (period == 'sports_week' ? 'events' : 'classes');

    if (dayIndex == now.weekday) {
      final current = widget.brain.getCurrentClass(widget.batch, now);

      if (current != null && current.isLive(now)) {
        final remaining = schedule
            .where((s) => s.safeStartVal > currentTime)
            .length;
        final classesLeft = remaining > 0
            ? '$remaining ${remaining == 1 ? noun : nouns} left'
            : 'Last $noun today';
        return '${current.subject} • $classesLeft';
      } else {
        final nextClass = schedule.firstWhere(
          (s) => s.safeStartVal > currentTime,
          orElse: () => schedule.first,
        );

        if (nextClass.safeStartVal > currentTime) {
          final minutesUntil = ((nextClass.safeStartVal - currentTime) * 60)
              .round();

          final prefix = period == 'midterms' || period == 'finals' ? 'Paper' : (period == 'sports_week' ? 'Event' : 'Next');
          if (minutesUntil > 60) {
            return '${(minutesUntil / 60).floor()}h ${minutesUntil % 60}m free • $prefix: ${nextClass.subject}';
          } else if (minutesUntil > 15) {
            return '${minutesUntil} min break • ${nextClass.subject} in ${nextClass.room}';
          } else {
            return 'Starting soon: ${nextClass.subject} in ${nextClass.room} ⚡';
          }
        }
      }

      return '${schedule.length} ${schedule.length == 1 ? noun : nouns} today';
    }

    return '${schedule.length} ${schedule.length == 1 ? noun : nouns} scheduled';
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

class _PulsingRadarBadge extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool isDark;

  const _PulsingRadarBadge({
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  State<_PulsingRadarBadge> createState() => _PulsingRadarBadgeState();
}

class _PulsingRadarBadgeState extends State<_PulsingRadarBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final breathOpacity = 0.05 + (0.15 * _pulseController.value);
        final glowScale = 1.0 + (0.12 * _pulseController.value);

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 38 * glowScale,
              height: 38 * glowScale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: breathOpacity),
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.15 * _pulseController.value),
                  width: 1.0,
                ),
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.12),
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.isDark ? Colors.white : widget.color,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StudentCapsuleNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final bool isDark;
  final VoidCallback onTap;

  const _StudentCapsuleNavButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        IrisHaptics.actionSoft();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        tween: Tween<double>(begin: isSelected ? 0.0 : 1.0, end: isSelected ? 1.0 : 0.0),
        builder: (context, animValue, child) {
          final scale = 1.0 + (0.08 * animValue);
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: activeColor.withValues(
                      alpha: 0.12 * animValue,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected 
                        ? activeColor 
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  letterSpacing: 0.2,
                  color: isSelected 
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3)),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isSelected ? 6 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ] : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================================================
// EXAM GRID DASHBOARD & CARD CORE
// ==========================================================================

class _TrackerPulseIndicator extends StatefulWidget {
  final Color color;
  const _TrackerPulseIndicator({required this.color});

  @override
  State<_TrackerPulseIndicator> createState() => _TrackerPulseIndicatorState();
}

class _TrackerPulseIndicatorState extends State<_TrackerPulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5 * _controller.value),
                blurRadius: 4 + 8 * _controller.value,
                spreadRadius: 1 + 3 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
