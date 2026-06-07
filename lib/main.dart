import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
  hide NotificationVisibility;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

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
import 'screens/portal_screen.dart';
import 'screens/about_screen.dart';
import 'screens/academics_hub_screen.dart';
import 'screens/faculty_dashboard_screen.dart' hide FacultyDashboard, LectureDuration, startClassNotificationTask;
import 'screens/room_finder_screen.dart';
import 'screens/setup_screens.dart';
import 'screens/teacher_locator_screen.dart';
import 'services/remote_config_service.dart';
import 'services/helpdesk_campus_feed_service.dart';
import 'services/helpdesk_faculty_service.dart';
import 'services/helpdesk_schedule_data_service.dart';
import 'services/headless_portal_sync.dart';
import 'services/notification_service.dart';
import 'services/timetable_ota_service.dart';
import 'services/ui_feedback.dart';
import 'services/session_refresher_service.dart';
import 'services/widget_service.dart';
import 'widgets/batch_selector.dart';
import 'widgets/dashboard_dock.dart' hide NavActiveHalo, BouncyNavButton;
import 'widgets/glass_card.dart';
import 'widgets/iris_components.dart';
import 'widgets/neural_aura.dart';
import 'widgets/portal_sync_card.dart';
import 'widgets/smooth_scroll.dart';
import 'widgets/spring_button.dart';
import 'widgets/vital_card.dart';

part 'screens/tools_screen_part.dart';

const MethodChannel _notificationChannel = MethodChannel('iris/notification_channel');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  tz.initializeTimeZones();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'persistent_class_foreground',
      channelName: 'IRIS Class Tracker',
      channelDescription: 'Shows your current and upcoming classes',
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(30000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
    ),
  );
  await IrisSfx.init();
  await IrisHaptics.init();
  runApp(const _BootIrisApp());
}

class _BootIrisApp extends StatefulWidget {
  const _BootIrisApp();

  @override
  State<_BootIrisApp> createState() => _BootIrisAppState();
}

class _BootIrisAppState extends State<_BootIrisApp> {
  late final Future<UniversityMemory> _memoryFuture;

  @override
  void initState() {
    super.initState();
    _memoryFuture = UniversityMemoryLoader.loadFromAssets();
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
              debugShowCheckedModeBanner: false,
              themeMode: _themeMode,
              theme: theme,
              darkTheme: darkTheme,
              scrollBehavior: const SmoothScrollBehavior(),
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
  late VoidCallback _roleListener;

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
    _loadUserRole();
    _loadBatch();
    _loadUserName();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestForegroundNotificationPermission();
    });

    // Show Darood e Pak reminder on app boot with haptic pulse
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IrisHaptics.actionSoft();
      _showDaroodePakDialog();
    });
  }

  @override
  void dispose() {
    AppSignals.roleNotifier.removeListener(_roleListener);
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role');
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

    final bottomSafeSpace = MediaQuery.of(context).padding.bottom + 108;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'startup_darood_reminder',
      dedupeWindow: const Duration(seconds: 10),
      content: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: IrisTokens.successGradient),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: IrisTokens.success.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mosque_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Darood e Pak',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.80),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.favorite_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
      tint: IrisTokens.success,
      duration: const Duration(seconds: 5),
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomSafeSpace),
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
      _userName = prefs.getString('student_user_name');
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

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return RoleSelectorScreen(onComplete: _saveUserRole);
    }

    if (_userRole == 'faculty') {
      return FacultyDashboard(
        brain: _brain,
        onToggleTheme: widget.onToggleTheme,
        onSetThemeMode: widget.onSetThemeMode,
        currentThemeMode: widget.currentThemeMode,
        onRoleChanged: _saveUserRole,
        onBatchChanged: _saveBatch,
      );
    }

    if (_selectedBatch == null) {
      return SetupBot(memory: widget.memory, onComplete: _saveBatch);
    }

    if (_userName == null) {
      return _NameCaptureScreen(onComplete: _saveUserName);
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
        const HeadlessPortalSync(url: 'https://swl-sis.comsats.edu.pk/Login/Index'),
      ],
    );
  }
}

class _NameCaptureScreen extends StatefulWidget {
  final ValueChanged<String> onComplete;

  const _NameCaptureScreen({required this.onComplete});

  @override
  State<_NameCaptureScreen> createState() => _NameCaptureScreenState();
}

class _NameCaptureScreenState extends State<_NameCaptureScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isValid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: IrisTokens.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: IrisTokens.brand.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Center(
                      child: Text('👋', style: TextStyle(fontSize: 32)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome to IRIS',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To personalize your experience, please let us know what to call you.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.55),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    borderRadius: 24,
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Your Name',
                        hintStyle: TextStyle(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.25),
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _isValid = val.trim().length >= 2;
                        });
                      },
                      onSubmitted: (val) {
                        if (_isValid) {
                          IrisHaptics.actionHeavy();
                          widget.onComplete(val.trim());
                        }
                      },
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedButton(
                      onPressed: _isValid
                          ? () {
                              IrisHaptics.actionHeavy();
                              widget.onComplete(_controller.text.trim());
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          gradient: _isValid
                              ? const LinearGradient(
                                  colors: [IrisTokens.brand, IrisTokens.purple],
                                )
                              : null,
                          color: _isValid ? null : (isDark ? Colors.white10 : Colors.black12),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: _isValid
                              ? [
                                  BoxShadow(
                                    color: IrisTokens.brand.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _isValid
                                  ? Colors.white
                                  : (isDark ? Colors.white24 : Colors.black26),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
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

class RoleSelectorScreen extends StatelessWidget {
  final ValueChanged<String> onComplete;

  const RoleSelectorScreen({required this.onComplete, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Choose your role',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will personalize your dashboard, tools, and portal access.',
                    style: TextStyle(
                      fontSize: 14,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                        0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    child: Column(
                      children: [
                        _RoleCard(
                          title: 'Student',
                          subtitle: 'Timetable, batch sync, class tracking',
                          icon: Icons.school_rounded,
                          accent: IrisTokens.brand,
                          onTap: () => onComplete('student'),
                        ),
                        const SizedBox(height: 14),
                        _RoleCard(
                          title: 'Faculty',
                          subtitle: 'Faculty portal and teaching tools',
                          icon: Icons.badge_rounded,
                          accent: IrisTokens.blue,
                          onTap: () => onComplete('faculty'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _wobbleController;
  late Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      duration: IrisMotion.fast,
      vsync: this,
    );
    _wobbleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _wobbleController, curve: IrisMotion.standard),
    );
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MotionSlideFade(
      beginOffset: const Offset(100, 0),
      duration: IrisMotion.medium,
      curve: IrisMotion.entrance,
      child: AnimatedBuilder(
        animation: _wobbleAnimation,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - (_wobbleAnimation.value * 0.08),
          child: InkWell(
            onTap: () {
              IrisHaptics.actionHeavy();
              _wobbleController.forward().then(
                (_) => _wobbleController.reverse(),
              );
              widget.onTap();
            },
            onTapDown: (_) => _wobbleController.forward(),
            onTapCancel: () => _wobbleController.reverse(),
            borderRadius: BorderRadius.circular(IrisTokens.radius28),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.accent,
                    widget.accent.withValues(alpha: 0.82),
                  ],
                  stops: const [0.0, 1.0],
                ),
                borderRadius: BorderRadius.circular(IrisTokens.radius28),
                border: Border.all(
                  color: widget.accent.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.20),
                    offset: const Offset(0, 10),
                    blurRadius: 22,
                    spreadRadius: -12,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    offset: const Offset(0, 4),
                    blurRadius: 14,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w200,
                            fontSize: 22,
                            letterSpacing: -0.5,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.5,
                            color: Colors.black.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: widget.accent,
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
}

class MotionSlideFade extends StatelessWidget {
  final Widget child;
  final Offset beginOffset;
  final Duration duration;
  final Curve curve;

  const MotionSlideFade({
    required this.child,
    required this.beginOffset,
    this.duration = IrisMotion.medium,
    this.curve = IrisMotion.entrance,
  });

  @override
  Widget build(BuildContext context) {
    if (IrisMotion.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, _) => Transform.translate(
        offset: Offset(
          beginOffset.dx * (1 - value),
          beginOffset.dy * (1 - value),
        ),
        child: Opacity(opacity: value, child: child),
      ),
    );
  }
}

class MotionScaleFade extends StatelessWidget {
  final Widget child;
  final double beginScale;
  final Duration duration;
  final Curve curve;

  const MotionScaleFade({
    required this.child,
    this.beginScale = 0.9,
    this.duration = IrisMotion.medium,
    this.curve = IrisMotion.bouncy,
  });

  @override
  Widget build(BuildContext context) {
    if (IrisMotion.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, _) => Transform.scale(
        scale: beginScale + ((1 - beginScale) * value),
        child: Opacity(opacity: value, child: child),
      ),
    );
  }
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

  // SetupBot and related screens moved to screens/setup_screens.dart
  static Future<void> _showWidgetSetupGuideFromSetup(
    BuildContext context,
  ) async {
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
              // Widget icon with gradient
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [IrisTokens.purpleLight, IrisTokens.purple],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: IrisTokens.purpleLight.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: IrisTokens.purple.withValues(alpha: 0.20),
                      offset: const Offset(0, 5),
                      blurRadius: 12,
                      spreadRadius: -5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  size: 38,
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
                    _buildStepStatic(
                      isDark,
                      '1',
                      'Long press on your home screen',
                    ),
                    const SizedBox(height: 12),
                    _buildStepStatic(isDark, '2', 'Tap Widgets'),
                    const SizedBox(height: 12),
                    _buildStepStatic(isDark, '3', 'Search for "IRIS"'),
                    const SizedBox(height: 12),
                    _buildStepStatic(isDark, '4', 'Drag to home screen'),
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
                        'Close',
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
                        backgroundColor: IrisTokens.purple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Got It!',
                        style: TextStyle(
                          fontSize: 14,
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
  }

  static Widget _buildStepStatic(bool isDark, String number, String text) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [IrisTokens.purple, IrisTokens.purpleLight],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
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

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _persistentNotificationEnabled =
          prefs.getBool('persistent_notification_enabled') ?? false;
    });
  }

  Future<void> _togglePersistentNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'student';
    final teacher = prefs.getString('faculty_teacher');
    if (role == 'faculty' && value && (teacher == null || teacher.isEmpty)) {
      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          dedupeKey: 'faculty_tracking_requires_teacher',
          content: Row(
            children: const [
              Icon(Icons.info_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select your name first to enable faculty tracking',
                ),
              ),
            ],
          ),
          tint: IrisTokens.brand,
        );
      }
      return;
    }
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
        await prefs.setString(
          'notification_body',
          'Keeping your class schedule handy',
        );

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

    IrisHaptics.chipSelect();
  }

  @override
  Widget build(BuildContext context) {
    // Filter out batch-like programs (FA##, SP##, etc.) - show only actual programs
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

    return Scaffold(
      body: Stack(
        children: [
          ObsidianPulse(
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(IrisTokens.radius32),
                      child: Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              IrisTokens.brand.withValues(alpha: 0.50),
                              IrisTokens.purple.withValues(alpha: 0.42),
                              IrisTokens.purpleLight.withValues(alpha: 0.34),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            IrisTokens.radius32,
                          ),
                          border: Border.all(
                            color: IrisTokens.brand.withValues(alpha: 0.55),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: IrisTokens.brand.withValues(alpha: 0.24),
                              blurRadius: 16,
                              spreadRadius: -2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: IrisTokens.brandGradient,
                                ),
                                borderRadius: BorderRadius.circular(
                                  IrisTokens.radius20,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: IrisTokens.brand.withValues(alpha: 0.45),
                                    blurRadius: 8,
                                    spreadRadius: -1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.psychology_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
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
                                      color: Colors.white.withValues(alpha: 0.92),
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
                            ? Colors.white.withValues(alpha: 0.84)
                            : Colors.black.withValues(alpha: 0.78)),
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
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _persistentNotificationEnabled
                                    ? IrisTokens.brandGradient
                                    : [
                                        (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black)
                                            .withValues(alpha: 0.12),
                                        (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black)
                                            .withValues(alpha: 0.08),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(
                                IrisTokens.radius12,
                              ),
                            ),
                            child: Icon(
                              _persistentNotificationEnabled
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_off_rounded,
                              color: _persistentNotificationEnabled
                                  ? Colors.white
                                  : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black)
                                        .withValues(alpha: 0.5),
                              size: 20,
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
                                    color:
                                        (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.72)
                                        : Colors.black.withValues(alpha: 0.70)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _persistentNotificationEnabled,
                            onChanged: _togglePersistentNotification,
                            activeColor: IrisTokens.brand,
                            activeTrackColor: IrisTokens.brand.withValues(alpha: 
                              0.35,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Widget Setup Guide
                    GlassCard(
                      child: InkWell(
                        onTap: () async {
                          await _showWidgetSetupGuideFromSetup(context);
                        },
                        borderRadius: BorderRadius.circular(
                          IrisTokens.radius16,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      IrisTokens.brandGradient[0].withValues(alpha: 
                                        0.9,
                                      ),
                                      IrisTokens.brandGradient[1].withValues(alpha: 
                                        0.9,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    IrisTokens.radius12,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.widgets_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Home Screen Widget',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Add widget to see classes at a glance',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withValues(alpha: 0.72)
                                            : Colors.black.withValues(alpha: 0.70)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color:
                                    (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.48)
                                    : Colors.black.withValues(alpha: 0.45)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Builder(
                      builder: (context) {
                        final isReady =
                            _program != null &&
                            _semester != null &&
                            _section != null;
                        final isDarkBtn =
                            Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: isReady
                                ? LinearGradient(
                                    colors: IrisTokens.brandGradient,
                                  )
                                : null,
                            color: !isReady
                                ? (isDarkBtn
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.08))
                                : null,
                            borderRadius: BorderRadius.circular(
                              IrisTokens.radius20,
                            ),
                            border: !isReady
                                ? Border.all(
                                    color: isDarkBtn
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.black.withValues(alpha: 0.12),
                                    width: 1.5,
                                  )
                                : null,
                            boxShadow: isReady
                                ? [
                                    BoxShadow(
                                      color: IrisTokens.brand.withValues(alpha: 0.45),
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
                                    final batch = widget.memory.allBatches
                                        .firstWhere(
                                          (b) {
                                            final key = BatchKey.parse(b);
                                            return key.program == _program &&
                                                key.semester == _semester &&
                                                key.section == _section;
                                          },
                                          orElse: () =>
                                              widget.memory.allBatches.first,
                                        );
                                    widget.onComplete(batch.trim());
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: isReady
                                  ? Colors.white
                                  : (isDarkBtn
                                        ? Colors.white.withValues(alpha: 0.56)
                                        : Colors.black.withValues(alpha: 0.52)),
                              disabledForegroundColor: isDarkBtn
                                  ? Colors.white.withValues(alpha: 0.50)
                                  : Colors.black.withValues(alpha: 0.48),
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
          ),
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
      enableOverlay: true,
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
                    colors: [IrisTokens.brand, IrisTokens.brandLight],
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
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.45),
                ),
              ),
              if (selected != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: IrisTokens.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    selected!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: IrisTokens.brand,
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
                .map(
                  (opt) => ChoiceChip(
                    label: Text(
                      opt,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    selected: selected == opt,
                    onSelected: (_) => onSelected(opt),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                    side: BorderSide(
                      color: selected == opt
                          ? IrisTokens.brand.withValues(alpha: 0.55)
                          : isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.10),
                      width: 1.2,
                    ),
                    labelStyle: TextStyle(
                      color: selected == opt
                          ? IrisTokens.brand
                          : isDark
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                )
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

class FacultyDashboard extends StatefulWidget {
  final OmniBrain brain;
  final VoidCallback onToggleTheme;
  final Future<void> Function(String mode) onSetThemeMode;
  final String currentThemeMode;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;

  const FacultyDashboard({
    required this.brain,
    required this.onToggleTheme,
    required this.onSetThemeMode,
    required this.currentThemeMode,
    required this.onRoleChanged,
    this.onBatchChanged,
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
  double? _facultyNavDragPosition;
  bool _isFacultyNavTracking = false;
  bool _facultyNavHasMoved = false;
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
      if (_selectedTeacher != null) {
        final current = widget.brain.getCurrentClassForTeacher(
          _selectedTeacher!,
          now,
        );

        if (current != null && current.isLive(now)) {
          // Currently in a class
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
    // ALWAYS set role to faculty to prevent cross-contamination
    await prefs.setString('user_role', 'faculty');

    // Get teacher and update state
    final teacher = prefs.getString('faculty_teacher');
    setState(() {
      _selectedTeacher = teacher;
    });

    // Now start notification service with the teacher loaded above (pass as parameter)
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

  FacultyProfile? _matchSelectedTeacherProfile() {
    final teacher = _selectedTeacher;
    if (teacher == null || teacher.isEmpty) return null;
    return HelpdeskFacultyService.matchFacultyProfile(teacher, _facultyProfiles);
  }

  String _facultySourceLabel(HelpdeskFacultySource source) {
    switch (source) {
      case HelpdeskFacultySource.live:
        return 'LIVE';
      case HelpdeskFacultySource.cache:
        return 'CACHE';
      case HelpdeskFacultySource.backup:
        return 'BACKUP';
      case HelpdeskFacultySource.none:
        return 'OFFLINE';
    }
  }

  String _resolveFacultyImageUrl(String image) {
    final raw = image.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '$_helpdeskBackendBase$raw';
    return '$_helpdeskBackendBase/$raw';
  }

  Future<void> _launchFacultyEmail(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'faculty_dashboard_email_unavailable',
        content: const Text('Email unavailable for this faculty profile.'),
      );
      return;
    }
    final uri = Uri.parse('mailto:$normalized');
    if (await canLaunchUrl(uri)) {
      IrisSfx.pillTap();
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'faculty_dashboard_email_launch_failed',
      content: const Text('Unable to open email client on this device.'),
    );
  }

  Future<void> _saveSelectedTeacher(String teacherName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('faculty_teacher', teacherName);
    await prefs.setString('faculty_user_name', teacherName);
    await prefs.setString('user_role', 'faculty');
    await _persistTimetableData();
    setState(() {
      _selectedTeacher = teacherName;
      _overrideDayIndex = null; // Reset day filter when teacher changes
    });
    // Refresh cache and UI immediately
    _updateScheduleCache();
    _updateWidgetForTeacher();
    await _ensureFacultyNotificationService(teacherName);
    await _scheduleFacultyClassReminders(teacherName);
  }

  Future<void> _scheduleFacultyClassReminders(String teacherName) async {
    final prefs = await SharedPreferences.getInstance();
    final remindersEnabled =
        prefs.getBool('lecture_reminders_enabled') ?? false;
    if (!remindersEnabled) {
      await NotificationService().cancelScheduledClassReminders();
      return;
    }

    final todayClasses = widget.brain.memory.sessions
        .where(
          (s) =>
              s.dayIndex == DateTime.now().weekday &&
              s.teacher.trim().toLowerCase() ==
                  teacherName.trim().toLowerCase(),
        )
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
    // Use parameter if provided, otherwise fall back to state
    final teacher = teacherParam ?? _selectedTeacher;
    if (!enabled || teacher == null || teacher.isEmpty) {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      return;
    }

    // Persist all data needed for background service
    await prefs.setString('user_role', 'faculty');
    await prefs.setString('faculty_teacher', teacher);
    await _persistTimetableData();

    // Stop service if running to ensure clean restart
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      // Minimal delay to ensure service fully stops before restart
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Calculate initial notification to show immediately (like student mode)
    final now = DateTime.now();
    final current = widget.brain.getCurrentClassForTeacher(teacher, now);
    final next = widget.brain.getNextClassForTeacher(teacher, now);
    final currentTime = now.hour + (now.minute / 60.0);
    final dayIndex = now.weekday;

    String _bar(double p) {
      const total = 8;
      final filled = (p * total).round().clamp(0, total);
      return '🟦' * filled + '⬜' * (total - filled);
    }

    final teacherSessions = widget.brain.memory.sessions
        .where(
          (s) => s.teacher.trim().toLowerCase() == teacher.trim().toLowerCase(),
        )
        .toList();
    final todayAll = teacherSessions
        .where((s) => s.dayIndex == dayIndex)
        .toList();

    String notifTitle = 'IRIS Faculty Tracker';
    String notifBody = 'Your schedule is ready';

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
          '${_bar(progress)} $progressPercent%$classCount\n📍 ${current.room} · 📚 ${current.batchKey.batch}';
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
      final progress = ((currentTime - current.safeStartVal) / duration).clamp(
        0.0,
        1.0,
      );
      progressPercent = (progress * 100).toInt();
    }

    // For faculty, show batch instead of teacher name
    String displayInfo = teacher;
    if (current != null) {
      displayInfo = current.batchKey.batch;
    } else {
      // If no current class, try to get batch from next class
      final allSessions = widget.brain.memory.sessions
          .where(
            (s) =>
                s.teacher.trim().toLowerCase() == teacher.trim().toLowerCase(),
          )
          .toList();
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

  void _onFacultyNavTap(int index) {
    _onBottomNavTap(index);
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

  double _facultyNavInteractionPosition(int itemCount) {
    if (_isFacultyNavTracking && _facultyNavDragPosition != null) {
      return _facultyNavDragPosition!.clamp(0.0, itemCount - 1.0);
    }
    return _bottomNavIndex.toDouble();
  }

  int _facultyNavDisplayIndex(int itemCount) {
    return _facultyNavInteractionPosition(itemCount)
        .round()
        .clamp(0, itemCount - 1);
  }

  void _beginFacultyNavTracking(
    Offset localPosition,
    double width,
    int itemCount,
  ) {
    if (width <= 0) return;
    setState(() {
      _isFacultyNavTracking = true;
      _facultyNavHasMoved = false;
      final slotWidth = width / itemCount;
      _facultyNavDragPosition = (localPosition.dx / slotWidth).clamp(
        0.0,
        itemCount - 1.0,
      );
    });
  }

  void _updateFacultyNavTracking(
    Offset localPosition,
    double width,
    int itemCount,
  ) {
    if (!_isFacultyNavTracking || width <= 0) return;
    setState(() {
      _facultyNavHasMoved = true;
      final slotWidth = width / itemCount;
      _facultyNavDragPosition = (localPosition.dx / slotWidth).clamp(
        0.0,
        itemCount - 1.0,
      );
    });
  }

  void _endFacultyNavTracking(int itemCount) {
    if (!_isFacultyNavTracking) return;
    if (!_facultyNavHasMoved) {
      _cancelFacultyNavTracking();
      return;
    }
    final targetIndex = _facultyNavInteractionPosition(itemCount)
        .round()
        .clamp(0, itemCount - 1);
    setState(() {
      _isFacultyNavTracking = false;
      _facultyNavDragPosition = null;
      _facultyNavHasMoved = false;
    });
    _setFacultyTabFromDrag(targetIndex);
  }

  void _cancelFacultyNavTracking() {
    if (!_isFacultyNavTracking) return;
    setState(() {
      _isFacultyNavTracking = false;
      _facultyNavDragPosition = null;
      _facultyNavHasMoved = false;
    });
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
          url:
              'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
          title: 'COMSATS Faculty Portal',
          sessionScope: 'faculty',
          showBackButton: false,
        );
      case 3:
        return AboutScreen(
          key: const PageStorageKey<String>('faculty_tab_about'),
          memory: widget.brain.memory,
          onRoleChanged: widget.onRoleChanged,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomNavBar(bool isDark) {
    // Compact, well-balanced bottom nav bar to avoid complex nested parsing issues.
    final displayIndex = _facultyNavDisplayIndex(4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.04),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.85),
                          Colors.white.withValues(alpha: 0.70),
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: VitalTokens.blue.withValues(alpha: isDark ? 0.15 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: BouncyNavButton(
                      icon: displayIndex == 0 ? Icons.home_filled : Icons.home_rounded,
                      label: 'Home',
                      isDark: isDark,
                      isSelected: displayIndex == 0,
                      activeColor: VitalTokens.blue,
                      onTap: () => _onFacultyNavTap(0),
                    ),
                  ),
                  Expanded(
                    child: BouncyNavButton(
                      icon: displayIndex == 1 ? Icons.badge_rounded : Icons.badge_outlined,
                      label: 'Teachers',
                      isDark: isDark,
                      isSelected: displayIndex == 1,
                      activeColor: VitalTokens.purple,
                      onTap: () => _onFacultyNavTap(1),
                    ),
                  ),
                  Expanded(
                    child: BouncyNavButton(
                      icon: Icons.public_rounded,
                      label: 'Portal',
                      isDark: isDark,
                      isSelected: displayIndex == 2,
                      activeColor: VitalTokens.cyan,
                      onTap: () => _onFacultyNavTap(2),
                    ),
                  ),
                  Expanded(
                    child: BouncyNavButton(
                      icon: displayIndex == 3 ? Icons.info_rounded : Icons.info_outline_rounded,
                      label: 'About',
                      isDark: isDark,
                      isSelected: displayIndex == 3,
                      activeColor: VitalTokens.blue,
                      onTap: () => _onFacultyNavTap(3),
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

  void _updateScheduleCache() {
    final teacher = _selectedTeacher;
    if (teacher == null || teacher.isEmpty) {
      _cachedSchedule = [];
      return;
    }

    final now = DateTime.now();
    final schedule = _overrideDayIndex != null
        ? _scheduleForDay(teacher, _overrideDayIndex!)
        : _buildSuggestedScheduleForTeacher(teacher, now);

    // Merge consecutive slots of the same lecture for cleaner display
    final mergedSchedule = widget.brain.getMergedConsecutiveSessions(schedule);

    // Ensure final schedule is always sorted in ascending order by start time
    mergedSchedule.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    _cachedSchedule = mergedSchedule;
    _lastScheduleUpdate = now;
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
      // Check if all today's classes have ended
      final allClassesEnded = today.every((s) => s.safeEndVal <= currentTime);

      if (allClassesEnded) {
        // All classes done for today, show next day automatically
        return _nextDayScheduleForTeacher(all, now.weekday);
      }

      return today; // Show today's full schedule
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
    const days = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
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
    final dayName = days[(now.weekday - 1) % 7];
    final monthName = months[(now.month - 1).clamp(0, 11)];
    return '$dayName, $monthName ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_bottomNavIndex != 0) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            ObsidianPulse(isDark: isDark),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: IrisMotion.entrance,
                switchOutCurve: IrisMotion.standard,
                transitionBuilder: (child, animation) {
                  final isIncoming =
                      child.key == ValueKey<int>(_bottomNavIndex);
                  final direction = _facultyTabSlideDirection.toDouble();
                  
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
                  child: _buildFacultyTabContent(),
                ),
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

    final teacher = _selectedTeacher;
    final now = DateTime.now();
    final dateLabel = _formatDateLabel(now);

    // Build schedule cache for selected teacher
    if (teacher != null && teacher.isNotEmpty) {
      if (_lastScheduleUpdate == null ||
          _lastScheduleUpdate!.day != now.day ||
          _cachedSchedule.isEmpty) {
        _updateScheduleCache();
      }
    }

    final schedule = (teacher != null && teacher.isNotEmpty)
        ? _cachedSchedule
        : <ClassSession>[];
    var insight = teacher != null && teacher.isNotEmpty
        ? widget.brain.buildTeacherTemporalInsight(teacher, now)
        : null;

    // For faculty, update insight to show batch instead of teacher name
    if (insight != null && teacher != null) {
      final current = widget.brain.getCurrentClassForTeacher(teacher, now);
      String batchName = teacher;
      if (current != null) {
        batchName = current.batchKey.batch;
      } else {
        // Try to get batch from any session for this teacher
        final allSessions = widget.brain.memory.sessions
            .where(
              (s) =>
                  s.teacher.trim().toLowerCase() ==
                  teacher.trim().toLowerCase(),
            )
            .toList();
        if (allSessions.isNotEmpty) {
          batchName = allSessions.first.batchKey.batch;
        }
      }
      insight = TemporalInsight(
        headline: insight.headline,
        subline: insight.subline,
        isLive: insight.isLive,
        timeInfo: insight.timeInfo,
        teacherInfo: batchName,
        isUrgent: insight.isUrgent,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: teacher == null || teacher.isEmpty
                ? _buildTeacherSelectionView(isDark)
                : _buildFacultyScheduleView(
                    isDark,
                    teacher,
                    schedule,
                    now,
                    dateLabel,
                    insight!,
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

  Widget _buildTeacherSelectionView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced premium header card with staggered animation
          MotionSlideFade(
            beginOffset: const Offset(0, 20),
            duration: IrisMotion.medium,
            curve: IrisMotion.entrance,
            child: Container(
              padding: const EdgeInsets.all(IrisTokens.space24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isDark ? Colors.white : IrisTokens.purple).withValues(alpha: 
                      isDark ? 0.14 : 0.20,
                    ),
                    (isDark ? Colors.white : IrisTokens.purpleLight)
                        .withValues(alpha: isDark ? 0.10 : 0.16),
                    (isDark
                            ? Colors.white
                            : IrisTokens.purpleLight.withValues(alpha: 0.7))
                        .withValues(alpha: isDark ? 0.07 : 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(IrisTokens.radius24),
                border: Border.all(
                  color: (isDark ? Colors.white : IrisTokens.purple)
                      .withValues(alpha: isDark ? 0.20 : 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: IrisTokens.purple.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: IrisTokens.purpleLight.withValues(alpha: 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                    spreadRadius: -12,
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
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              IrisTokens.purple.withValues(alpha: 0.85),
                              IrisTokens.purpleLight.withValues(alpha: 0.75),
                              IrisTokens.purpleLight
                                  .withValues(alpha: 0.7)
                                  .withValues(alpha: 0.65),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: IrisTokens.purple.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  IrisTokens.purple,
                                  IrisTokens.purpleLight,
                                  IrisTokens.purpleLight,
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'Faculty Dashboard',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                  letterSpacing: 0.4,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Manage your teaching schedule',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.86),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : IrisTokens.purple)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isDark ? Colors.white : IrisTokens.purple)
                                .withValues(alpha: 0.20),
                          ),
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
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.94)
                                : IrisTokens.purple,
                          ),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Enhanced instructions card with staggered animation
          MotionSlideFade(
            beginOffset: const Offset(0, 30),
            duration: IrisMotion.medium,
            curve: IrisMotion.entrance,
            child: GlassCard(
              enableOverlay: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              IrisTokens.purple.withValues(alpha: 0.18),
                              IrisTokens.purpleLight.withValues(alpha: 0.12),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: IrisTokens.purple.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.lightbulb_rounded,
                          size: 20,
                          color: IrisTokens.purple,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Get Started',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 0.3,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                        0.03,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      'Select your name to view your complete teaching schedule, monitor live classes, and access faculty management tools.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            IrisTokens.purple,
                            IrisTokens.purpleLight,
                            IrisTokens.purpleLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: IrisTokens.purple.withValues(alpha: 0.40),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: IrisTokens.purpleLight.withValues(alpha: 0.20),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: AnimatedButton(
                        key: _facultySelectTeacherCtaKey,
                        onPressed: () => _openTeacherPicker(
                          originKey: _facultySelectTeacherCtaKey,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.badge_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Select My Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildFacultyHeaderBadge({bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IrisTokens.purple.withValues(alpha: 0.9),
            IrisTokens.purpleLight.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: IrisTokens.purple.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(
        Icons.badge_rounded,
        color: Colors.white,
        size: compact ? 20 : 24,
      ),
    );
  }

  Widget _buildFacultyHeaderTitle(String teacher, bool isDark, bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teaching Today',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: compact ? 10 : 11,
            letterSpacing: compact ? 0.6 : 0.8,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.50),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          teacher,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: compact ? 18 : 20,
            letterSpacing: 0.2,
            color: isDark ? Colors.white : Colors.black,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildFacultyChangeTeacherButton({
    bool compact = false,
    GlobalKey? originKey,
  }) {
    return AnimatedButton(
      key: originKey,
      onPressed: () => _openTeacherPicker(originKey: originKey),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: IrisTokens.purple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: IrisTokens.purple.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              size: compact ? 13 : 14,
              color: IrisTokens.purple,
            ),
            const SizedBox(width: 4),
            Text(
              'Change',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 10 : 11,
                color: IrisTokens.purple,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyThemeToggleButton(bool isDark, {bool compact = false}) {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : IrisTokens.purple).withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isDark ? Colors.white : IrisTokens.purple).withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: IconButton(
        onPressed: () {
          IrisHaptics.actionSoft();
          widget.onToggleTheme();
        },
        tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        icon: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: compact ? 17 : 18,
          color: isDark
              ? Colors.white.withValues(alpha: 0.82)
              : IrisTokens.purple,
        ),
        padding: EdgeInsets.all(compact ? 7 : 8),
        constraints: const BoxConstraints(),
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
    final filteredSchedule = schedule;
    final profile = _matchSelectedTeacherProfile();
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactCard = screenWidth < 400;
    final isVeryCompactCard = screenWidth < 360;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: IrisTokens.brand,
      backgroundColor: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
      strokeWidth: 2.5,
      displacement: 60,
      child: CustomScrollView(
        physics: const ButterScrollPhysics(),
        cacheExtent: 500,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: EdgeInsets.all(
                  isVeryCompactCard
                      ? IrisTokens.space16
                      : (isCompactCard
                            ? IrisTokens.space20
                            : IrisTokens.space24),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (isDark ? Colors.white : IrisTokens.purple).withValues(alpha: 
                        isDark ? 0.10 : 0.12,
                      ),
                      (isDark ? Colors.white : IrisTokens.purpleLight)
                          .withValues(alpha: isDark ? 0.06 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(IrisTokens.radius24),
                  border: Border.all(
                    color: (isDark ? Colors.white : IrisTokens.purple)
                        .withValues(alpha: isDark ? 0.20 : 0.30),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: IrisTokens.purple.withValues(alpha: 
                        isDark ? 0.12 : 0.09,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isCompactCard)
                      Row(
                        children: [
                          _buildFacultyHeaderBadge(),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildFacultyHeaderTitle(
                              teacher,
                              isDark,
                              false,
                            ),
                          ),
                          _buildFacultyChangeTeacherButton(
                            originKey: _facultyChangeTeacherKey,
                          ),
                          const SizedBox(width: 8),
                          _buildFacultyThemeToggleButton(isDark),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFacultyHeaderBadge(compact: true),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFacultyHeaderTitle(
                                  teacher,
                                  isDark,
                                  true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildFacultyChangeTeacherButton(
                                compact: true,
                                originKey: _facultyChangeTeacherKey,
                              ),
                              const SizedBox(width: 8),
                              _buildFacultyThemeToggleButton(
                                isDark,
                                compact: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    if (profile != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 46,
                                    height: 46,
                                    child:
                                        _resolveFacultyImageUrl(profile.image)
                                                .isEmpty
                                            ? Container(
                                                color: IrisTokens.brand.withValues(
                                                  alpha: 0.15,
                                                ),
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  color: IrisTokens.brand,
                                                  size: 22,
                                                ),
                                              )
                                            : Image.network(
                                                _resolveFacultyImageUrl(
                                                  profile.image,
                                                ),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  color: IrisTokens.brand
                                                      .withValues(alpha: 0.15),
                                                  child: const Icon(
                                                    Icons.person_rounded,
                                                    color: IrisTokens.brand,
                                                    size: 22,
                                                  ),
                                                ),
                                              ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.department.isEmpty
                                            ? 'Department unavailable'
                                            : profile.department,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.76),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        profile.location.isEmpty
                                            ? 'Location unavailable'
                                            : profile.location,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.58),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: IrisTokens.brand.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: IrisTokens.brand.withValues(
                                        alpha: 0.24,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _facultySourceLabel(_facultyProfilesSource),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                      color: IrisTokens.brand.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _launchFacultyEmail(profile.email),
                                    icon: const Icon(
                                      Icons.mail_outline_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Open Email'),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: IrisTokens.brand.withValues(
                                          alpha: 0.26,
                                        ),
                                      ),
                                      foregroundColor: IrisTokens.brand,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 9,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Privacy-first: personal phone is hidden in faculty mode. Student locator keeps contact actions where needed.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.52),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else if (_facultyProfilesLoading) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.07),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Loading faculty profile...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                dateLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isVeryCompactCard ? 9 : 10,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.65),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isVeryCompactCard ? 9 : 10,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.65),
                                  letterSpacing: 0.2,
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
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: MotionScaleFade(
                beginScale: 0.85,
                duration: IrisMotion.medium,
                curve: IrisMotion.emphasized,
                child: _buildInsightCard(insight, isDark),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SectionHeader(
                title: _timelineTitle(schedule, now, _overrideDayIndex),
                subtitle: _timelineSubtitle(schedule, now, _overrideDayIndex),
                statusIndicator: _getTimelineStatusColor(
                  widget.brain,
                  teacher,
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
                      child: MotionScaleFade(
                        beginScale: 0.9,
                        duration: IrisMotion.medium,
                        curve: IrisMotion.emphasized,
                        child: GlassCard(
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              TweenAnimationBuilder<double>(
                                duration: const Duration(seconds: 3),
                                tween: Tween(begin: 0.0, end: 1.0),
                                curve: IrisMotion.standard,
                                builder: (context, value, child) =>
                                    Transform.rotate(
                                      angle: value * 0.1 * 3.14159,
                                      child: child,
                                    ),
                                onEnd: () => setState(() {}),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        IrisTokens.purple.withValues(alpha: 0.25),
                                        IrisTokens.purpleLight.withValues(alpha: 
                                          0.18,
                                        ),
                                        IrisTokens.purpleLight
                                            .withValues(alpha: 0.7)
                                            .withValues(alpha: 0.12),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: IrisTokens.purple.withValues(alpha: 
                                          0.16,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                        spreadRadius: -4,
                                      ),
                                      BoxShadow(
                                        color: IrisTokens.purple.withValues(alpha: 
                                          0.08,
                                        ),
                                        blurRadius: 24,
                                        offset: const Offset(0, 12),
                                        spreadRadius: -8,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.self_improvement_rounded,
                                    size: 40,
                                    color: IrisTokens.purple.withValues(alpha: 0.90),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'No Classes Scheduled',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      IrisTokens.success.withValues(alpha: 0.20),
                                      IrisTokens.success
                                          .withValues(alpha: 0.8)
                                          .withValues(alpha: 0.12),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: IrisTokens.success.withValues(alpha: 0.35),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  'Time to relax and recharge 🎉',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                    color: IrisTokens.success.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
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
                            (fullIndex >= 0 && fullIndex + 1 < schedule.length)
                            ? schedule[fullIndex + 1]
                            : null;
                        return RepaintBoundary(
                          child: ClassCard(
                            key: ValueKey(
                              'faculty_class_${session.subject}_${session.startTime}_${session.batchKey.batch}',
                            ),
                            session: session,
                            nextSession: nextSession,
                            isFacultyView: true,
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
    );
  }

  Widget _buildInsightCard(TemporalInsight insight, bool isDark) {
    final now = DateTime.now();
    final accentColor = insight.isLive
        ? IrisTokens.success
        : insight.isUrgent
        ? IrisTokens.warning
        : IrisTokens.brand;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: insight.isLive
              ? [
                  (isDark ? Colors.white : IrisTokens.success).withValues(alpha: 
                    isDark ? 0.08 : 0.12,
                  ),
                  (isDark ? Colors.white : IrisTokens.success.withValues(alpha: 0.8))
                      .withValues(alpha: isDark ? 0.05 : 0.08),
                  (isDark ? Colors.white : IrisTokens.successDark).withValues(alpha: 
                    isDark ? 0.03 : 0.05,
                  ),
                ]
              : insight.isUrgent
              ? [
                  (isDark ? Colors.white : IrisTokens.warning).withValues(alpha: 
                    isDark ? 0.07 : 0.10,
                  ),
                  (isDark ? Colors.white : IrisTokens.warningDark).withValues(alpha: 
                    isDark ? 0.05 : 0.07,
                  ),
                  (isDark ? Colors.white : IrisTokens.warning.withValues(alpha: 0.7))
                      .withValues(alpha: isDark ? 0.03 : 0.04),
                ]
              : [
                  (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 
                    isDark ? 0.07 : 0.10,
                  ),
                  (isDark ? Colors.white : IrisTokens.brandLight).withValues(alpha: 
                    isDark ? 0.05 : 0.07,
                  ),
                  (isDark
                          ? Colors.white
                          : IrisTokens.brandLight.withValues(alpha: 0.8))
                      .withValues(alpha: isDark ? 0.03 : 0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? Colors.white : accentColor).withValues(alpha: 
            isDark ? 0.18 : 0.32,
          ),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 18),
            spreadRadius: -14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withValues(alpha: isDark ? 0.15 : 0.20),
                        accentColor.withValues(alpha: isDark ? 0.10 : 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (isDark ? Colors.white : accentColor).withValues(alpha: 
                        isDark ? 0.20 : 0.35,
                      ),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    insight.isLive
                        ? Icons.record_voice_over_rounded
                        : insight.isUrgent
                        ? Icons.notifications_active_rounded
                        : Icons.schedule_rounded,
                    color: accentColor,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            insight.headline,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              color: accentColor,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (insight.isLive)
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 1440),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: IrisMotion.standard,
                            builder: (context, value, child) {
                              final pulse = 0.5 - (value - 0.5).abs();
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      IrisTokens.success.withValues(alpha: 
                                        0.25 + (pulse * 0.15),
                                      ),
                                      IrisTokens.success
                                          .withValues(alpha: 0.8)
                                          .withValues(alpha: 0.18 + (pulse * 0.12)),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: IrisTokens.success.withValues(alpha: 
                                      0.50 + (pulse * 0.3),
                                    ),
                                    width: 1.3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: IrisTokens.success.withValues(alpha: 
                                        0.14 + (pulse * 0.12),
                                      ),
                                      blurRadius: 8 + (pulse * 4),
                                      offset: const Offset(0, 2),
                                      spreadRadius: -1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6 + (pulse * 2),
                                      height: 6 + (pulse * 2),
                                      decoration: BoxDecoration(
                                        color: IrisTokens.success,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: IrisTokens.success
                                                .withValues(alpha: 0.48),
                                            blurRadius: 5 + (pulse * 3),
                                            spreadRadius: -1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'LIVE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: IrisTokens.success,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onEnd: () => setState(() {}),
                          ),
                      ],
                    ),
                    if (insight.timeInfo != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        insight.timeInfo!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: insight.isLive
                              ? IrisTokens.success
                              : insight.isUrgent
                              ? IrisTokens.error
                              : IrisTokens.brand,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
              ),
            ),
            child: Text(
              insight.subline,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.72),
              ),
            ),
          ),
          // Live progress bar for faculty
          if (insight.isLive && _selectedTeacher != null) ...[
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final currentClass = widget.brain.getCurrentClassForTeacher(
                  _selectedTeacher!,
                  now,
                );
                if (currentClass != null) {
                  final currentTime = now.hour + (now.minute / 60.0);
                  final duration = LectureDuration.getActualDuration(
                    currentClass,
                  );
                  final actualEndTime = LectureDuration.getActualEndTime(
                    currentClass,
                  );
                  final progress =
                      ((currentTime - currentClass.safeStartVal) / duration)
                          .clamp(0.0, 1.0);
                  final minutesLeft = ((actualEndTime - currentTime) * 60)
                      .toInt()
                      .clamp(0, (duration * 60).toInt());

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
                        borderRadius: BorderRadius.circular(6),
                        child: TweenAnimationBuilder<double>(
                          duration: IrisMotion.medium,
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
                                    colors: [
                                      IrisTokens.success,
                                      IrisTokens.success,
                                      IrisTokens.successDark,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: IrisTokens.success.withValues(alpha: 
                                        0.28,
                                      ),
                                      blurRadius: 3,
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
          if (insight.teacherInfo != null || insight.timeInfo != null) ...[
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
                children: [
                  if (insight.timeInfo != null) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: IrisTokens.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: IrisTokens.purple.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      insight.timeInfo!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  if (insight.teacherInfo != null && insight.timeInfo != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (insight.teacherInfo != null) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: IrisTokens.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.groups_rounded,
                        size: 12,
                        color: IrisTokens.purple.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight.teacherInfo!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
                                child: Text(
                                  'FACULTY SCHEDULE',
                                  style: TextStyle(
                                    fontSize: isVeryCompactCard ? 11 : 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: isDark ? 0.46 : 0.40),
                                  ),
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
    _loadDismissedAnnouncement();
    _checkPendingTimetableChanges();

    // Start remote Firestore listener for real-time announcements, modes & OTA timetable upgrades
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        RemoteConfigService.startRemoteListener(context);
        setState(() => _navBarReady = true);

        // Background session warming on startup
        unawaited(SessionRefresherService.warmSession('swl-sis.comsats.edu.pk', 'student'));
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
    String _bar(double p) {
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
          '${_bar(progress)} $progressPercent%$classCount\n📍 ${current.room} · ${current.teacher}';
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

    // Health check: restart service if it should be running but isn't
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      print('⚠️ Service not running but should be - restarting...');
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

    // Animated colored progress bar with glowy emojis
    String _bar(double p) {
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
            '${_bar(progress)} $progressPercent%$classCount\n📍 ${current.room} · ${current.teacher}';
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
      );
    } catch (e) {
      debugPrint('⚠️ Widget update failed: $e');
    }
  }

  Future<void> _openPortal({GlobalKey? originKey}) async {
    if (!mounted) return;
    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      page: const PortalScreen(
        url: 'https://swl-sis.comsats.edu.pk/Login/Index',
        title: 'COMSATS Student Portal',
        sessionScope: 'student',
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
      page: _DepartmentClassesScreen(
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
    index = index.clamp(0, 4);
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
    final itemWidth = width / 5;
    final targetIndex = (safeDx / itemWidth).floor().clamp(0, 4);
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
          url: 'https://swl-sis.comsats.edu.pk/Login/Index',
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
        );
      case 4:
        return AboutScreen(
          key: const PageStorageKey<String>('student_tab_about'),
          memory: widget.memory,
          onRoleChanged: widget.onRoleChanged,
          onBatchChanged: widget.onBatchChanged,
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
                                    color: isDark ? Colors.amber[200]!.withOpacity(0.6) : const Color(0xFFB45309).withOpacity(0.7),
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

    return Container(
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
                              color: isDark ? Colors.amber[200]!.withOpacity(0.8) : const Color(0xFFD97706),
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
    );
  }


  Widget _buildStudentBottomNavBar(bool isDark) {
    final displayIndex = _studentNavDisplayIndex(5);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.8),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.08 : 0.05),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StudentCapsuleNavButton(
                  icon: displayIndex == 0 ? Icons.grid_view_rounded : Icons.grid_view_outlined,
                  label: 'Portal',
                  isSelected: displayIndex == 0,
                  activeColor: IrisTokens.brand,
                  isDark: isDark,
                  onTap: () => _onBottomNavTap(0),
                ),
                _StudentCapsuleNavButton(
                  icon: Icons.wifi_tethering_rounded,
                  label: 'Feed',
                  isSelected: displayIndex == 1,
                  activeColor: IrisTokens.purple,
                  isDark: isDark,
                  onTap: () => _onBottomNavTap(1),
                ),
                _StudentCapsuleNavButton(
                  icon: Icons.school_rounded,
                  label: 'Academics',
                  isSelected: displayIndex == 2,
                  activeColor: const Color(0xFFF59E0B),
                  isDark: isDark,
                  onTap: () => _onBottomNavTap(2),
                ),
                _StudentCapsuleNavButton(
                  icon: Icons.construction_rounded,
                  label: 'Tools',
                  isSelected: displayIndex == 3,
                  activeColor: IrisTokens.success,
                  isDark: isDark,
                  onTap: () => _onBottomNavTap(3),
                ),
                _StudentCapsuleNavButton(
                  icon: Icons.offline_bolt_rounded,
                  label: 'About',
                  isSelected: displayIndex == 4,
                  activeColor: IrisTokens.error,
                  isDark: isDark,
                  onTap: () => _onBottomNavTap(4),
                ),
              ],
            ),
          ),
        ),
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
                      onPressed: () async {
                        IrisHaptics.actionHeavy();
                        if (apkUrl.isNotEmpty) {
                          final uri = Uri.tryParse(apkUrl);
                          if (uri != null) {
                            try {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (e) {
                              print('Failed to launch URL with externalApplication: $e');
                              try {
                                await launchUrl(uri, mode: LaunchMode.platformDefault);
                              } catch (e2) {
                                print('Failed to launch URL with platformDefault: $e2');
                                if (context.mounted) {
                                  showIrisFrostedSnackBar(
                                    context,
                                    content: const Text('Could not open APK download link. Try copying it manually.'),
                                    tint: IrisTokens.error,
                                  );
                                }
                              }
                            }
                          }
                        }
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

  Widget _buildHomeDashboard(
    BuildContext context,
    bool isDark,
    DateTime now,
    String dateLabel,
    TemporalInsight insight,
    List<ClassSession> filteredSchedule,
    List<ClassSession> schedule,
  ) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: IrisTokens.brand,
        backgroundColor: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
        child: CustomScrollView(
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
            const SliverPadding(padding: EdgeInsets.only(bottom: 126)),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          Positioned.fill(
            child: IndexedStack(
              index: _bottomNavIndex,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: RemoteConfigService.activeAcademicPeriod,
                  builder: (context, period, _) {
                    if (period == 'midterms' || period == 'finals') {
                      return ExamGridDashboard(
                        period: period,
                        batch: widget.batch,
                        onToggleTheme: widget.onToggleTheme,
                      );
                    }
                    return _buildHomeDashboard(context, isDark, now, dateLabel, insight, filteredSchedule, schedule);
                  },
                ),
                const PortalScreen(
                  key: PageStorageKey<String>('student_tab_portal'),
                  url: 'https://swl-sis.comsats.edu.pk/Login/Index',
                  title: 'COMSATS Student Portal',
                  sessionScope: 'student',
                  showBackButton: false,
                ),
                const AcademicsHubScreen(
                  key: PageStorageKey<String>('student_tab_academics'),
                ),
                ToolsScreen(
                  key: const PageStorageKey<String>('student_tab_tools'),
                  memory: widget.memory,
                  batch: widget.batch,
                  brain: widget.brain,
                  onRoleChanged: widget.onRoleChanged,
                  onBatchChanged: widget.onBatchChanged,
                ),
                AboutScreen(
                  key: const PageStorageKey<String>('student_tab_about'),
                  memory: widget.memory,
                  onRoleChanged: widget.onRoleChanged,
                  onBatchChanged: widget.onBatchChanged,
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
      return '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} • ${_getDayName(dayIndex)}';
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

// DaySwitcher, ClassCard, and GlassShimmer moved to widgets/iris_components.dart
class _HealthToolsScreen extends StatefulWidget {
  final int initialTab;

  const _HealthToolsScreen({this.initialTab = 0});

  @override
  State<_HealthToolsScreen> createState() => _HealthToolsScreenState();
}

class _HealthToolsScreenState extends State<_HealthToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _weightController = TextEditingController(text: '70');
  final TextEditingController _heightController = TextEditingController(text: '170');
  final TextEditingController _waterController = TextEditingController(text: '70');
  final TextEditingController _sysController = TextEditingController(text: '120');
  final TextEditingController _diaController = TextEditingController(text: '80');
  final TextEditingController _elementSearchController = TextEditingController();

  static const List<Map<String, String>> _elements = [
    {'symbol': 'H', 'name': 'Hydrogen', 'number': '1'},
    {'symbol': 'He', 'name': 'Helium', 'number': '2'},
    {'symbol': 'C', 'name': 'Carbon', 'number': '6'},
    {'symbol': 'N', 'name': 'Nitrogen', 'number': '7'},
    {'symbol': 'O', 'name': 'Oxygen', 'number': '8'},
    {'symbol': 'Na', 'name': 'Sodium', 'number': '11'},
    {'symbol': 'Mg', 'name': 'Magnesium', 'number': '12'},
    {'symbol': 'P', 'name': 'Phosphorus', 'number': '15'},
    {'symbol': 'S', 'name': 'Sulfur', 'number': '16'},
    {'symbol': 'Cl', 'name': 'Chlorine', 'number': '17'},
    {'symbol': 'K', 'name': 'Potassium', 'number': '19'},
    {'symbol': 'Ca', 'name': 'Calcium', 'number': '20'},
    {'symbol': 'Fe', 'name': 'Iron', 'number': '26'},
    {'symbol': 'Zn', 'name': 'Zinc', 'number': '30'},
    {'symbol': 'Cu', 'name': 'Copper', 'number': '29'},
    {'symbol': 'I', 'name': 'Iodine', 'number': '53'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _waterController.dispose();
    _sysController.dispose();
    _diaController.dispose();
    _elementSearchController.dispose();
    super.dispose();
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  String _bpCategory(int s, int d) {
    if (s < 120 && d < 80) return 'Normal';
    if (s < 130 && d < 80) return 'Elevated';
    if (s < 140 || d < 90) return 'Stage 1';
    return 'Stage 2';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset =
        MediaQuery.paddingOf(context).top +
        kToolbarHeight +
        kTextTabBarHeight +
        12;
    final w = double.tryParse(_weightController.text) ?? 0;
    final hCm = double.tryParse(_heightController.text) ?? 0;
    final hM = hCm > 0 ? hCm / 100 : 0;
    final bmi = hM > 0 ? w / (hM * hM) : 0;
    final hydration = (double.tryParse(_waterController.text) ?? 0) * 0.033;
    final s = int.tryParse(_sysController.text) ?? 0;
    final d = int.tryParse(_diaController.text) ?? 0;
    final query = _elementSearchController.text.trim().toLowerCase();
    final filtered = _elements.where((e) {
      if (query.isEmpty) return true;
      return e['symbol']!.toLowerCase().contains(query) ||
          e['name']!.toLowerCase().contains(query) ||
          e['number']!.contains(query);
    }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Health Smart Suite'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Calculators'),
            Tab(text: 'Periodic Table'),
          ],
        ),
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          TabBarView(
            controller: _tabController,
            children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: IrisTokens.brandGradient),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Health Smart Suite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                            const SizedBox(height: 4),
                            Text('Quick calculators and references in one place.', style: TextStyle(fontSize: 13, height: 1.35, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.64))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BMI Assistant', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _heightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('BMI: ${bmi.toStringAsFixed(2)} • ${_bmiCategory(bmi.toDouble())}', style: const TextStyle(fontWeight: FontWeight.w700, color: IrisTokens.brand)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hydration Estimator', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _waterController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Body Weight (kg)', border: OutlineInputBorder()),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text('Daily water target: ${hydration.toStringAsFixed(2)} L', style: const TextStyle(fontWeight: FontWeight.w700, color: IrisTokens.success)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vitals Check (BP)', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _sysController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Systolic', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _diaController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Diastolic', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('BP category: ${_bpCategory(s, d)}', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: IrisTokens.brandGradient),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.code_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CS Compiler Suite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                            const SizedBox(height: 4),
                            Text('Smart checks, templates, and quick dry-run helpers.', style: TextStyle(fontSize: 13, height: 1.35, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.64))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _elementSearchController,
                        decoration: const InputDecoration(
                          labelText: 'Search element by name/symbol/number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      Text('${filtered.length} elements found', style: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...filtered.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: IrisTokens.brand.withValues(alpha: 0.2),
                        child: Text(e['symbol']!, style: const TextStyle(fontWeight: FontWeight.w800, color: IrisTokens.brand)),
                      ),
                      title: Text(e['name']!),
                      subtitle: Text('Atomic Number: ${e['number']}'),
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
    );
  }
}

class _ResistorColorDecoderScreen extends StatefulWidget {
  const _ResistorColorDecoderScreen();

  @override
  State<_ResistorColorDecoderScreen> createState() =>
      _ResistorColorDecoderScreenState();
}

class _ResistorColorDecoderScreenState extends State<_ResistorColorDecoderScreen> {
  String _band1 = 'Brown';
  String _band2 = 'Black';
  String _multiplier = 'Red';
  String _tolerance = 'Gold';

  static const Map<String, int> _digitMap = {
    'Black': 0,
    'Brown': 1,
    'Red': 2,
    'Orange': 3,
    'Yellow': 4,
    'Green': 5,
    'Blue': 6,
    'Violet': 7,
    'Gray': 8,
    'White': 9,
  };

  static const Map<String, int> _multiplierExp = {
    'Black': 0,
    'Brown': 1,
    'Red': 2,
    'Orange': 3,
    'Yellow': 4,
    'Green': 5,
    'Blue': 6,
    'Violet': 7,
    'Gray': 8,
    'White': 9,
    'Gold': -1,
    'Silver': -2,
  };

  static const Map<String, double> _toleranceMap = {
    'Brown': 1.0,
    'Red': 2.0,
    'Green': 0.5,
    'Blue': 0.25,
    'Violet': 0.1,
    'Gray': 0.05,
    'Gold': 5.0,
    'Silver': 10.0,
  };

  static const Map<String, Color> _colorMap = {
    'Black': Colors.black,
    'Brown': Color(0xFF8D6E63),
    'Red': Color(0xFFE53935),
    'Orange': Color(0xFFFB8C00),
    'Yellow': Color(0xFFFDD835),
    'Green': Color(0xFF43A047),
    'Blue': Color(0xFF1E88E5),
    'Violet': Color(0xFF8E24AA),
    'Gray': Color(0xFF9E9E9E),
    'White': Color(0xFFF5F5F5),
    'Gold': Color(0xFFFFC107),
    'Silver': Color(0xFFB0BEC5),
  };

  double _resistance() {
    final first = _digitMap[_band1] ?? 0;
    final second = _digitMap[_band2] ?? 0;
    final base = (first * 10) + second;
    final exp = _multiplierExp[_multiplier] ?? 0;
    return (base * math.pow(10, exp)).toDouble();
  }

  String _formatOhms(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)} MΩ';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)} kΩ';
    }
    return '${value.toStringAsFixed(2)} Ω';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final value = _resistance();
    final tol = _toleranceMap[_tolerance] ?? 5.0;
    final min = value * (1 - tol / 100);
    final max = value * (1 + tol / 100);

    Widget bandDropdown(
      String title,
      String current,
      List<String> options,
      ValueChanged<String> onChanged,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: current,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: options
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _colorMap[c],
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(c),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Resistor Color Decoder'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: bandDropdown(
                          'Band 1',
                          _band1,
                          _digitMap.keys.toList(),
                          (v) => setState(() => _band1 = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: bandDropdown(
                          'Band 2',
                          _band2,
                          _digitMap.keys.toList(),
                          (v) => setState(() => _band2 = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: bandDropdown(
                          'Multiplier',
                          _multiplier,
                          _multiplierExp.keys.toList(),
                          (v) => setState(() => _multiplier = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: bandDropdown(
                          'Tolerance',
                          _tolerance,
                          _toleranceMap.keys.toList(),
                          (v) => setState(() => _tolerance = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatOhms(value),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tolerance: ±${tol.toStringAsFixed(2)}%'
                    '  •  Range: ${_formatOhms(min)} to ${_formatOhms(max)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Smart tip: Read from the side with the tolerance band (usually gold/silver).',
                    style: TextStyle(fontSize: 12, color: IrisTokens.brand),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  ),
);
  }
}

class _DepartmentSmartKitScreen extends StatefulWidget {
  final String department;
  final OmniBrain brain;
  final String batch;

  const _DepartmentSmartKitScreen({
    required this.department,
    required this.brain,
    required this.batch,
  });

  @override
  State<_DepartmentSmartKitScreen> createState() =>
      _DepartmentSmartKitScreenState();
}

class _DepartmentSmartKitScreenState extends State<_DepartmentSmartKitScreen> {
  final TextEditingController _assignmentsController =
      TextEditingController(text: '2');
  final TextEditingController _quizzesController =
      TextEditingController(text: '1');
  final TextEditingController _labsController = TextEditingController(text: '1');
  final TextEditingController _prepHoursController =
      TextEditingController(text: '8');

  final TextEditingController _currentScoreController =
      TextEditingController(text: '72');
  final TextEditingController _targetScoreController =
      TextEditingController(text: '85');
  final TextEditingController _remainingWeightController =
      TextEditingController(text: '40');

  @override
  void dispose() {
    _assignmentsController.dispose();
    _quizzesController.dispose();
    _labsController.dispose();
    _prepHoursController.dispose();
    _currentScoreController.dispose();
    _targetScoreController.dispose();
    _remainingWeightController.dispose();
    super.dispose();
  }

  double _parseNum(String value) => double.tryParse(value.trim()) ?? 0;

  ({double score, String band}) _workloadScore() {
    final assignments = _parseNum(_assignmentsController.text);
    final quizzes = _parseNum(_quizzesController.text);
    final labs = _parseNum(_labsController.text);
    final prepHours = _parseNum(_prepHoursController.text);
    final score = (assignments * 2.0) +
        (quizzes * 3.0) +
        (labs * 4.0) +
        (prepHours * 0.5);
    if (score >= 26) {
      return (score: score, band: 'High intensity week');
    }
    if (score >= 16) {
      return (score: score, band: 'Balanced workload');
    }
    return (score: score, band: 'Light workload window');
  }

  ({double required, bool impossible}) _targetPlanner() {
    final current = _parseNum(_currentScoreController.text).clamp(0, 100);
    final target = _parseNum(_targetScoreController.text).clamp(0, 100);
    final remainingWeight =
        (_parseNum(_remainingWeightController.text).clamp(1, 100)) / 100.0;
    final completedWeight = 1.0 - remainingWeight;
    final required = (target - (current * completedWeight)) / remainingWeight;
    return (required: required, impossible: required > 100);
  }

  List<String> _departmentTips(String department) {
    final d = department.toLowerCase();
    if (d.contains('civil')) {
      return const [
        'Prioritize surveying and design studio deliverables early.',
        'Batch numericals by topic to reduce context switching.',
        'Reserve one long block for CAD/BIM practice each week.',
      ];
    }
    if (d.contains('chem')) {
      return const [
        'Group reaction-mechanism practice with formula review.',
        'Use short spaced sessions for nomenclature retention.',
        'Keep one weekly block for lab prep and report templates.',
      ];
    }
    if (d.contains('eco') || d.contains('account') || d.contains('finance')) {
      return const [
        'Split theory revision and numerical practice into separate blocks.',
        'Use one-day lag review after every major lecture.',
        'Track trend questions for faster exam pattern recognition.',
      ];
    }
    return const [
      'Use 45-10 focused cycles for heavy concept days.',
      'Front-load assignments before quiz windows to reduce overlap stress.',
      'Keep one recap block to compress week-long notes into 1-page summaries.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final now = DateTime.now();
    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);
    final workload = _workloadScore();
    final targetPlan = _targetPlanner();
    final tips = _departmentTips(widget.department);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Department Smart Kit'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: IrisTokens.brandGradient),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Department Smart Kit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                            const SizedBox(height: 4),
                            Text('Weekly workload and grade planning for this department.', style: TextStyle(fontSize: 13, height: 1.35, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.64))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.department.toUpperCase()} adaptive assistant',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    current != null
                        ? 'Live now: ${current.subject}'
                        : next != null
                        ? 'Next class: ${next.subject}'
                        : 'No class right now. Good time to plan your week.',
                    style: TextStyle(
                      fontSize: 13,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Workload Estimator',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _numField('Assignments', _assignmentsController),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _numField('Quizzes', _quizzesController)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _numField('Labs', _labsController)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numField('Prep Hours', _prepHoursController),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Load score: ${workload.score.toStringAsFixed(1)} • ${workload.band}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: IrisTokens.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target Grade Planner',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _numField('Current %', _currentScoreController),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numField('Target %', _targetScoreController),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _numField('Remaining Weight %', _remainingWeightController),
                  const SizedBox(height: 12),
                  Text(
                    targetPlan.impossible
                        ? 'Required in remaining assessments: ${targetPlan.required.toStringAsFixed(1)}% (above 100%, adjust target or strategy).'
                        : 'Required in remaining assessments: ${targetPlan.required.clamp(0, 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: IrisTokens.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Department Smart Tips',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (final tip in tips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '• $tip',
                        style: TextStyle(
                          fontSize: 13,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _PrintTimetableScreen extends StatefulWidget {
  final OmniBrain brain;
  final String batch;

  const _PrintTimetableScreen({
    required this.brain,
    required this.batch,
  });

  @override
  State<_PrintTimetableScreen> createState() => _PrintTimetableScreenState();
}

class _PrintTimetableScreenState extends State<_PrintTimetableScreen> {
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    // Automatically generate and print the PDF
    _generateAndPrintPdf();
  }

  Future<void> _generateAndPrintPdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final schedule = widget.brain.scheduleFor(widget.batch);
      final dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];

      // Group sessions by day
      final grouped = <int, List<ClassSession>>{};
      for (final session in schedule) {
        grouped.putIfAbsent(session.dayIndex, () => []).add(session);
      }
      for (final day in grouped.values) {
        day.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      }

      // Create PDF document
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;

      // Add title
      graphics.drawString(
        'IRIS Timetable',
        PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold),
        bounds: const Rect.fromLTWH(20, 20, 500, 40),
        brush: PdfSolidBrush(PdfColor(0, 122, 255)),
      );

      // Add batch info
      graphics.drawString(
        'Batch: ${widget.batch}',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(20, 70, 500, 20),
      );

      // Create table
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 4);

      // Add headers
      final PdfGridRow headerRow = grid.rows.add();
      headerRow.cells[0].value = 'Time';
      headerRow.cells[1].value = 'Subject';
      headerRow.cells[2].value = 'Teacher';
      headerRow.cells[3].value = 'Room';

      // Style header
      for (int i = 0; i < 4; i++) {
        headerRow.cells[i].style = PdfGridCellStyle(
          backgroundBrush: PdfSolidBrush(PdfColor(0, 122, 255)),
          textBrush: PdfSolidBrush(PdfColor(255, 255, 255)),
          font: PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
        );
      }

      // Add data rows
      for (int dayIndex = 1; dayIndex <= 7; dayIndex++) {
        if (grouped.containsKey(dayIndex)) {
          // Add day header row
          final dayRow = grid.rows.add();
          dayRow.cells[0].value = '${dayNames[dayIndex - 1]} Schedule';
          dayRow.cells[0].columnSpan = 4;
          dayRow.cells[0].style = PdfGridCellStyle(
            backgroundBrush: PdfSolidBrush(PdfColor(230, 230, 230)),
            font: PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
          );

          // Add sessions
          for (final session in grouped[dayIndex]!) {
            final row = grid.rows.add();
            row.cells[0].value = '${session.startTime} – ${session.endTime}';
            row.cells[1].value = session.subject;
            row.cells[2].value = session.teacher;
            row.cells[3].value = session.room;
          }
        }
      }

      // Draw table on page
      grid.draw(page: page, bounds: Rect.fromLTWH(20, 110, 550, 500));

      // Save to temporary file
      final bytes = await document.save();
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/iris_timetable_${widget.batch}.pdf');
      await file.writeAsBytes(bytes);
      document.dispose();

      // Open print dialog
      if (!mounted) return;

      // Use native Android printing via method channel
      const platform = MethodChannel('iris/print');
      try {
        await platform.invokeMethod('printPdf', {
          'filePath': file.path,
          'jobName': 'IRIS Timetable - ${widget.batch}',
        });
      } catch (e) {
        debugPrint('Print failed: $e');
        // Fallback: share the PDF
        if (mounted) {
          _showPrintFallback(file);
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('PDF generation error: $e');
      setState(() => _isGeneratingPdf = false);
      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          dedupeKey: 'pdf_generation_error',
          content: Text('Error generating PDF: $e'),
          tint: IrisTokens.error,
        );
      }
    }
  }

  void _showPrintFallback(File file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1AFFFFFF) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: IrisTokens.brandGradient),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.print_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'PDF Ready',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your timetable PDF is ready. Open it to print using your device printer.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.7,
                  ),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await OpenFilex.open(file.path);
                        if (mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.brand,
                      ),
                      child: const Text('Open PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Print Timetable'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Center(
              child: _isGeneratingPdf
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0x1AFFFFFF)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    IrisTokens.brand,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Generating PDF...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your timetable is being prepared for printing',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: IrisTokens.brandGradient,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 60,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'PDF Ready',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Your timetable PDF has been generated and opened in your printer.',
                              style: TextStyle(
                                fontSize: 15,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.7),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: IrisTokens.brand,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineFormulaLibraryScreen extends StatefulWidget {
  const _OfflineFormulaLibraryScreen();

  @override
  State<_OfflineFormulaLibraryScreen> createState() =>
      _OfflineFormulaLibraryScreenState();
}

class _OfflineFormulaLibraryScreenState
    extends State<_OfflineFormulaLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _category = 'All';

  static const List<String> _categories = [
    'All',
    'Thermodynamics',
    'Circuits',
    'Mechanics',
    'Constants',
  ];

  static final List<_FormulaEntry> _entries = [
    _FormulaEntry(
      category: 'Thermodynamics',
      title: 'First Law',
      formula: 'ΔU = Q - W',
      description: 'Change in internal energy equals heat added minus work done.',
    ),
    _FormulaEntry(
      category: 'Thermodynamics',
      title: 'Ideal Gas Law',
      formula: 'PV = nRT',
      description: 'Pressure-volume relationship for ideal gases.',
    ),
    _FormulaEntry(
      category: 'Circuits',
      title: 'Ohm\'s Law',
      formula: 'V = I R',
      description: 'Voltage equals current multiplied by resistance.',
    ),
    _FormulaEntry(
      category: 'Circuits',
      title: 'Electric Power',
      formula: 'P = V I = I²R = V²/R',
      description: 'Equivalent forms of electrical power.',
    ),
    _FormulaEntry(
      category: 'Mechanics',
      title: 'Newton Second Law',
      formula: 'F = m a',
      description: 'Force equals mass times acceleration.',
    ),
    _FormulaEntry(
      category: 'Mechanics',
      title: 'Kinetic Energy',
      formula: 'KE = 1/2 m v²',
      description: 'Energy due to motion.',
    ),
    _FormulaEntry(
      category: 'Constants',
      title: 'Gas Constant',
      formula: 'R = 8.314 J/(mol·K)',
      description: 'Universal gas constant.',
    ),
    _FormulaEntry(
      category: 'Constants',
      title: 'Gravitational Acceleration',
      formula: 'g = 9.81 m/s²',
      description: 'Standard gravity near Earth surface.',
    ),
    _FormulaEntry(
      category: 'Constants',
      title: 'Speed of Light',
      formula: 'c = 2.998 × 10^8 m/s',
      description: 'Light speed in vacuum.',
    ),
  ];

  List<_FormulaEntry> _filtered() {
    final q = _searchController.text.trim().toLowerCase();
    return _entries.where((e) {
      final catMatch = _category == 'All' || e.category == _category;
      if (!catMatch) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          e.formula.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final entries = _filtered();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Formula Library & Constants'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search formula, symbol, topic',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories
                        .map(
                          (c) => ChoiceChip(
                            label: Text(c),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${entries.length} references available offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        e.formula,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: IrisTokens.brand,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.description,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgrammingToolsScreen extends StatefulWidget {
  const _ProgrammingToolsScreen();

  @override
  State<_ProgrammingToolsScreen> createState() => _ProgrammingToolsScreenState();
}

class _ProgrammingToolsScreenState extends State<_ProgrammingToolsScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _dryRunInputController = TextEditingController(
    text: '5, 1, 4, 2, 8',
  );

  String _language = 'Dart';
  String _status = 'Ready';
  String _summary = 'Pick a language and run Smart Check.';
  List<String> _warnings = const [];
  int _complexityScore = 0;
  String _accessoryMode = 'Snippet Vault';
  String _accessoryOutput = 'Pick an accessory mode and generate output.';

  static const Map<String, String> _templates = {
    'Dart': 'void main() {\n  print("Hello IRIS");\n}\n',
    'Python': 'def main():\n    print("Hello IRIS")\n\nif __name__ == "__main__":\n    main()\n',
    'C++': '#include <iostream>\nusing namespace std;\n\nint main() {\n  cout << "Hello IRIS" << endl;\n  return 0;\n}\n',
    'Java': 'public class Main {\n  public static void main(String[] args) {\n    System.out.println("Hello IRIS");\n  }\n}\n',
  };

  static const Map<String, String> _algorithmTemplates = {
    'Binary Search':
        'while (low <= high) {\n  int mid = low + (high - low) / 2;\n  if (arr[mid] == target) return mid;\n  if (arr[mid] < target) low = mid + 1;\n  else high = mid - 1;\n}\nreturn -1;',
    'DFS (Recursive)':
        'void dfs(int node) {\n  visited[node] = true;\n  for (final nxt in graph[node]) {\n    if (!visited[nxt]) dfs(nxt);\n  }\n}',
    'BFS':
        'final q = Queue<int>();\nq.add(start);\nvisited[start] = true;\nwhile (q.isNotEmpty) {\n  final u = q.removeFirst();\n  for (final v in graph[u]) {\n    if (!visited[v]) {\n      visited[v] = true;\n      q.add(v);\n    }\n  }\n}',
  };

  @override
  void initState() {
    super.initState();
    _codeController.text = _templates[_language]!;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _dryRunInputController.dispose();
    super.dispose();
  }

  bool _bracketsBalanced(String input) {
    final stack = <String>[];
    final opens = {'(': ')', '{': '}', '[': ']'};
    final closes = {')', '}', ']'};
    for (final ch in input.split('')) {
      if (opens.containsKey(ch)) {
        stack.add(ch);
      } else if (closes.contains(ch)) {
        if (stack.isEmpty) return false;
        final last = stack.removeLast();
        if (opens[last] != ch) return false;
      }
    }
    return stack.isEmpty;
  }

  int _complexityHeuristic(String input) {
    final lower = input.toLowerCase();
    final patterns = [
      RegExp(r'\bif\b'),
      RegExp(r'\bfor\b'),
      RegExp(r'\bwhile\b'),
      RegExp(r'\bswitch\b'),
      RegExp(r'\bcase\b'),
      RegExp(r'\bcatch\b'),
      RegExp(r'&&|\|\|'),
      RegExp(r'\?'),
    ];
    var score = 1;
    for (final p in patterns) {
      score += p.allMatches(lower).length;
    }
    return score;
  }

  void _loadTemplate() {
    setState(() {
      _codeController.text = _templates[_language]!;
      _status = 'Template loaded';
      _summary = 'Press Smart Check to analyze this $_language snippet.';
      _warnings = const [];
      _complexityScore = 0;
    });
  }

  void _smartCheck() {
    final code = _codeController.text;
    final warnings = <String>[];
    final lineCount = '\n'.allMatches(code).length + 1;
    final hasBalanced = _bracketsBalanced(code);

    if (!hasBalanced) {
      warnings.add('Unbalanced brackets detected.');
    }

    if (_language == 'Python' && code.contains('{') && code.contains('}')) {
      warnings.add('Python style warning: avoid braces for blocks.');
    }

    if ((_language == 'Java' || _language == 'C++' || _language == 'Dart') &&
        code.contains('print(') &&
        !code.contains(';')) {
      warnings.add('Possible missing semicolon in print statement.');
    }

    if (code.trim().isEmpty) {
      warnings.add('Code is empty.');
    }

    final complexity = _complexityHeuristic(code);
    final status = warnings.isEmpty ? 'Smart Check Passed' : 'Needs Attention';
    final summary =
        'Language: $_language • Lines: $lineCount • Complexity: $complexity';

    setState(() {
      _status = status;
      _summary = summary;
      _warnings = warnings;
      _complexityScore = complexity;
    });
  }

  void _runAccessory() {
    if (_accessoryMode == 'Snippet Vault') {
      final items = _algorithmTemplates.entries
          .map((e) => '${e.key}:\n${e.value}')
          .join('\n\n');
      setState(() {
        _accessoryOutput = 'Top Snippets:\n\n$items';
      });
      return;
    }

    if (_accessoryMode == 'Algorithm Templates') {
      final bestFit = _complexityScore > 6
          ? 'BFS / DFS with visited set'
          : 'Binary Search / Two Pointers';
      setState(() {
        _accessoryOutput =
            'Suggested template family: $bestFit\n\nTip: choose based on data shape and constraints.';
      });
      return;
    }

    final raw = _dryRunInputController.text
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
    if (raw.isEmpty) {
      setState(() {
        _accessoryOutput = 'Dry-run helper needs comma-separated integers.';
      });
      return;
    }

    final sorted = List<int>.from(raw)..sort();
    final minV = sorted.first;
    final maxV = sorted.last;
    final avg = sorted.reduce((a, b) => a + b) / sorted.length;

    setState(() {
      _accessoryOutput =
          'Dry-run Snapshot\nInput: $raw\nSorted: $sorted\nMin: $minV, Max: $maxV, Avg: ${avg.toStringAsFixed(2)}\n\nUse this as a quick sanity-check before coding.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('CS Compiler Suite'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _language,
                          decoration: const InputDecoration(
                            labelText: 'Language',
                            border: OutlineInputBorder(),
                          ),
                          items: _templates.keys
                              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _language = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _loadTemplate,
                        child: const Text('Load'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeController,
                    minLines: 10,
                    maxLines: 16,
                    decoration: const InputDecoration(
                      labelText: 'Code Editor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _smartCheck,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Smart Check'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _warnings.isEmpty
                          ? IrisTokens.success
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _summary,
                    style: TextStyle(
                      fontSize: 13,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complexity Score: $_complexityScore',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: IrisTokens.brand,
                    ),
                  ),
                  if (_warnings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._warnings.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $w',
                          style: const TextStyle(
                            fontSize: 12,
                            color: IrisTokens.warning,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compiler Suite Accessories',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Snippet Vault', 'Algorithm Templates', 'Dry-run Helper']
                        .map(
                          (m) => ChoiceChip(
                            label: Text(m),
                            selected: _accessoryMode == m,
                            onSelected: (_) => setState(() => _accessoryMode = m),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  if (_accessoryMode == 'Dry-run Helper')
                    TextField(
                      controller: _dryRunInputController,
                      decoration: const InputDecoration(
                        labelText: 'Sample numbers (comma-separated)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _runAccessory,
                      icon: const Icon(Icons.build_rounded),
                      label: const Text('Generate Smart Output'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _accessoryOutput,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormulaEntry {
  final String category;
  final String title;
  final String formula;
  final String description;

  const _FormulaEntry({
    required this.category,
    required this.title,
    required this.formula,
    required this.description,
  });
}


class _WordCounterScreen extends StatefulWidget {
  const _WordCounterScreen({
    required this.title,
    required this.formula,
    required this.description,
  });

  final String title;
  final String formula;
  final String description;

  @override
  State<_WordCounterScreen> createState() => _WordCounterScreenState();
}


class _WordCounterScreenState extends State<_WordCounterScreen> {
  final TextEditingController _controller = TextEditingController();

  int get _characters => _controller.text.length;
  int get _charactersNoSpaces => _controller.text.replaceAll(' ', '').length;

  int get _words {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  int get _sentences {
    final matches = RegExp(r'[.!?]+').allMatches(_controller.text);
    return matches.length;
  }

  int get _paragraphs {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .length;
  }

  int get _readMinutes {
    if (_words == 0) return 0;
    return (_words / 220).ceil();
  }

  int get _speakMinutes {
    if (_words == 0) return 0;
    return (_words / 140).ceil();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Word Counter'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: IrisTokens.brandGradient),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.text_fields_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Word Counter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 4),
                        Text('Measure writing, reading time, and speaking time instantly.', style: TextStyle(fontSize: 13, height: 1.35, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.64))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _controller,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: 'Paste or write your text here...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(label: 'Words', value: '$_words'),
              _MetricChip(label: 'Characters', value: '$_characters'),
              _MetricChip(label: 'No Spaces', value: '$_charactersNoSpaces'),
              _MetricChip(label: 'Sentences', value: '$_sentences'),
              _MetricChip(label: 'Paragraphs', value: '$_paragraphs'),
              _MetricChip(label: 'Read Time', value: '${_readMinutes}m'),
              _MetricChip(label: 'Speak Time', value: '${_speakMinutes}m'),
            ],
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.68,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class ClassAnalyticsScreen extends StatelessWidget {
  final OmniBrain brain;
  final String batch;

  const ClassAnalyticsScreen({required this.brain, required this.batch});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final sessions = brain.scheduleFor(batch);
    final dayMap = <int, int>{};
    final roomMap = <String, int>{};

    for (final s in sessions) {
      dayMap[s.dayIndex] = (dayMap[s.dayIndex] ?? 0) + 1;
      roomMap[s.room] = (roomMap[s.room] ?? 0) + 1;
    }

    final busiestDay = dayMap.entries.isEmpty
        ? null
        : dayMap.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final topRoom = roomMap.entries.isEmpty
        ? null
        : roomMap.entries.reduce((a, b) => a.value >= b.value ? a : b);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Class Analytics'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: IrisTokens.brandGradient),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Class Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 4),
                        Text('See the shape of your week at a glance.', style: TextStyle(fontSize: 13, height: 1.35, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.64))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricChip(label: 'Total Sessions', value: '${sessions.length}'),
                  _MetricChip(label: 'Unique Rooms', value: '${roomMap.keys.length}'),
                  _MetricChip(label: 'Busiest Day', value: busiestDay == null ? '-' : FormatGuard.normalizeDay(busiestDay.key)),
                  _MetricChip(label: 'Top Room', value: topRoom?.key ?? '-'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (dayMap.isNotEmpty)
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sessions by Day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...(() {
                      final sorted = dayMap.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key));
                      return sorted
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      FormatGuard.normalizeDay(entry.key),
                                    ),
                                  ),
                                  Text('${entry.value}'),
                                ],
                              ),
                            ),
                          )
                          .toList();
                    })(),
                  ],
                ),
              ),
            ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CgpaCalculatorScreen extends StatefulWidget {
  const _CgpaCalculatorScreen();

  @override
  State<_CgpaCalculatorScreen> createState() => _CgpaCalculatorScreenState();
}

class _CgpaCalculatorScreenState extends State<_CgpaCalculatorScreen> {
  final List<_CgpaCourseRow> _rows = [
    _CgpaCourseRow(),
    _CgpaCourseRow(),
    _CgpaCourseRow(),
  ];

  double _semesterGpa = 0.0;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _recalculate() {
    double qualityPoints = 0;
    double totalCredits = 0;

    for (final row in _rows) {
      final credits = double.tryParse(row.creditsController.text) ?? 0;
      if (credits <= 0) {
        continue;
      }
      qualityPoints += credits * row.gradePoint;
      totalCredits += credits;
    }

    setState(() {
      _semesterGpa = totalCredits > 0 ? qualityPoints / totalCredits : 0.0;
    });
  }

  void _addRow() {
    setState(() {
      _rows.add(_CgpaCourseRow());
    });
    _recalculate();
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
    _recalculate();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('CGPA Calculator'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // Neural aura background
          ObsidianPulse(isDark: isDark),
          ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
          20,
          36,
        ),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: IrisTokens.brandGradient),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CGPA Calculator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 4),
                        Text('Estimate GPA and keep your semester plan visible.', style: TextStyle(fontSize: 13, height: 1.35, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.64))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: IrisTokens.brand.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: IrisTokens.brand,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Semester GPA',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.68),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _semesterGpa.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : Colors.black,
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
            'Add your courses below',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.72,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(_rows.length, (index) {
            final row = _rows[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CgpaRowCard(
                index: index,
                row: row,
                onChanged: _recalculate,
                onDelete: () => _removeRow(index),
              ),
            );
          }),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Course'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _recalculate,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Recalculate'),
                ),
              ),
            ],
          ),
        ],
      ),
        ],
      ),
    );
  }
}

class _CgpaCourseRow {
  _CgpaCourseRow();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController creditsController = TextEditingController();
  String grade = 'A';

  static const Map<String, double> _gradePoints = {
    'A': 4.0,
    'A-': 3.67,
    'B+': 3.33,
    'B': 3.00,
    'B-': 2.67,
    'C+': 2.33,
    'C': 2.00,
    'C-': 1.67,
    'D+': 1.33,
    'D': 1.00,
    'F': 0.0,
  };

  double get gradePoint => _gradePoints[grade] ?? 0.0;

  List<String> get gradeOptions => _gradePoints.keys.toList();

  void dispose() {
    nameController.dispose();
    creditsController.dispose();
  }
}

class _CgpaRowCard extends StatelessWidget {
  final int index;
  final _CgpaCourseRow row;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _CgpaRowCard({
    required this.index,
    required this.row,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Course ${index + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: row.nameController,
              decoration: const InputDecoration(
                labelText: 'Course Name (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.creditsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Credit Hours',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: row.grade,
                    decoration: const InputDecoration(
                      labelText: 'Grade',
                      border: OutlineInputBorder(),
                    ),
                    items: row.gradeOptions
                        .map(
                          (g) => DropdownMenuItem<String>(
                            value: g,
                            child: Text('$g (${_CgpaCourseRow._gradePoints[g]})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      row.grade = value;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String description;

  _ToolItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class _ToolCard extends StatelessWidget {
  final _ToolItem tool;
  final bool isDark;
  final VoidCallback onTap;
  final bool compact;

  const _ToolCard({
    required this.tool,
    required this.isDark,
    required this.onTap,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tool.color.withValues(alpha: isDark ? 0.18 : 0.12),
              tool.color.withValues(alpha: isDark ? 0.08 : 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: tool.color.withValues(alpha: isDark ? 0.2 : 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: tool.color.withValues(alpha: isDark ? 0.1 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: tool.color.withValues(alpha: 0.1),
            highlightColor: tool.color.withValues(alpha: 0.05),
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tool.color.withValues(alpha: isDark ? 0.3 : 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tool.color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(tool.icon, color: tool.color, size: 22),
                  ),
                  SizedBox(height: compact ? 10 : 12),
                  Text(
                    tool.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tool.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.62,
                      ),
                      height: 1.25,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 8),
                    Text(
                      tool.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: (isDark ? Colors.white : Colors.black).withValues(
                          alpha: 0.55,
                        ),
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NameEditDialog extends StatefulWidget {
  final String? initialName;

  const _NameEditDialog({this.initialName});

  @override
  State<_NameEditDialog> createState() => _NameEditDialogState();
}

class _NameEditDialogState extends State<_NameEditDialog> {
  late final TextEditingController _controller;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _isValid = _controller.text.trim().length >= 2;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        padding: const EdgeInsets.all(28),
        borderRadius: 28,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update Name',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This is how you will be greeted on the dashboard.',
              style: TextStyle(
                fontSize: 13,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                ),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Your Name',
                  hintStyle: TextStyle(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.25),
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _isValid = val.trim().length >= 2;
                  });
                },
                onSubmitted: (val) {
                  if (_isValid) {
                    IrisHaptics.actionHeavy();
                    Navigator.pop(context, val.trim());
                  }
                },
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AnimatedButton(
                    onPressed: _isValid
                        ? () {
                            IrisHaptics.actionHeavy();
                            Navigator.pop(context, _controller.text.trim());
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: _isValid
                            ? const LinearGradient(
                                colors: [IrisTokens.brand, IrisTokens.purple],
                              )
                            : null,
                        color: _isValid ? null : (isDark ? Colors.white10 : Colors.black12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'Update',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _isValid
                                ? Colors.white
                                : (isDark ? Colors.white24 : Colors.black26),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
class _DepartmentClassesScreen extends StatefulWidget {
  final UniversityMemory memory;
  final String currentBatch;
  final OmniBrain? brain;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;
  final bool showDock;
  final bool showBackButton;

  const _DepartmentClassesScreen({
    required this.memory,
    required this.currentBatch,
    this.brain,
    this.onRoleChanged,
    this.onBatchChanged,
    this.showDock = true,
    this.showBackButton = true,
    super.key,
  });

  @override
  State<_DepartmentClassesScreen> createState() =>
      _DepartmentClassesScreenState();
}


class _FacultyDirectoryScreen extends StatefulWidget {
  final OmniBrain? brain;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;
  final UniversityMemory? memory;
  final String? currentBatch;

  const _FacultyDirectoryScreen({
    this.brain,
    this.onRoleChanged,
    this.onBatchChanged,
    this.memory,
    this.currentBatch,
    super.key,
  });

  @override
  State<_FacultyDirectoryScreen> createState() => _FacultyDirectoryScreenState();
}

class _FacultyDirectoryScreenState extends State<_FacultyDirectoryScreen> {
  static const String _backendBase = 'https://cui-helpdesk-backend.onrender.com';

  final HelpdeskFacultyService _service = HelpdeskFacultyService();
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  List<FacultyProfile> _all = const [];
  List<FacultyProfile> _filtered = const [];
  final Map<String, TeacherLocatorResult> _teacherInsightCache = {};
  bool _loading = true;
  String _error = '';
  String _query = '';
  String _selectedDepartment = 'All';
  String _selectedBlock = 'All';
  HelpdeskFacultySource _source = HelpdeskFacultySource.none;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    unawaited(_loadFaculty());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFaculty() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    final list = await _service.fetchOfflineOnly();
    if (!mounted) return;

    if (list.isEmpty) {
      setState(() {
        _all = const [];
        _filtered = const [];
        _loading = false;
        _error = 'Unable to load faculty directory right now.';
        _source = HelpdeskFacultySource.none;
      });
      return;
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _all = list;
      _loading = false;
      _source = HelpdeskFacultySource.cache;
    });
    _applyFilter();
  }

  String _sourceLabel(HelpdeskFacultySource source) {
    switch (source) {
      case HelpdeskFacultySource.live:
        return 'LIVE';
      case HelpdeskFacultySource.cache:
        return 'CACHE';
      case HelpdeskFacultySource.backup:
        return 'BACKUP';
      case HelpdeskFacultySource.none:
        return 'OFFLINE';
    }
  }

  String _resolveImageUrl(String raw) {
    final image = raw.trim();
    if (image.isEmpty) return '';
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }
    if (image.startsWith('/')) return '$_backendBase$image';
    return '$_backendBase/$image';
  }

  String _blockFromLocation(String location) {
    final value = location.trim();
    if (value.isEmpty) return 'Unknown';
    final upper = value.toUpperCase();
    if (upper.contains('A BLOCK')) return 'A Block';
    if (upper.contains('B BLOCK')) return 'B Block';
    if (upper.contains('C BLOCK')) return 'C Block';
    if (upper.contains('D BLOCK')) return 'D Block';
    return value;
  }

  List<String> get _departments {
    final items = _all
        .map((e) => e.department.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...items];
  }

  List<String> get _blocks {
    final items = _all
        .map((e) => _blockFromLocation(e.location))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...items];
  }

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    final result = _all.where((item) {
      final departmentOk = _selectedDepartment == 'All' ||
          item.department.toLowerCase() == _selectedDepartment.toLowerCase();
      final blockOk = _selectedBlock == 'All' ||
          _blockFromLocation(item.location).toLowerCase() ==
              _selectedBlock.toLowerCase();

      if (!departmentOk || !blockOk) return false;
      if (q.isEmpty) return true;

      return item.name.toLowerCase().contains(q) ||
          item.department.toLowerCase().contains(q) ||
          item.location.toLowerCase().contains(q) ||
          item.email.toLowerCase().contains(q) ||
          item.contact.toLowerCase().contains(q);
    }).toList();

    setState(() {
      _filtered = result;
    });
  }

  TeacherLocatorResult? _teacherInsight(String teacherName) {
    final brain = widget.brain;
    if (brain == null) return null;
    return _teacherInsightCache.putIfAbsent(
      teacherName,
      () => brain.locateTeacher(teacherName, DateTime.now()),
    );
  }

  Future<void> _openTeacherLocator(FacultyProfile item) async {
    if (widget.brain == null) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'faculty_locator_brain_missing',
        content: const Text('Teacher locator is unavailable right now.'),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherLocatorScreen(
          brain: widget.brain!,
          onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
          memory: widget.memory,
          currentBatch: widget.currentBatch,
          initialTeacherQuery: item.name,
          autoSearchInitial: true,
          showDock: false,
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'faculty_phone_unavailable',
        content: const Text('Phone number unavailable for this faculty member.'),
      );
      return;
    }
    final uri = Uri.parse('tel:$normalized');
    if (await canLaunchUrl(uri)) {
      IrisSfx.pillTap();
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'faculty_phone_launch_failed',
      content: const Text('Unable to open dialer on this device.'),
    );
  }

  Future<void> _launchEmail(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'faculty_email_unavailable',
        content: const Text('Email unavailable for this faculty member.'),
      );
      return;
    }
    final uri = Uri.parse('mailto:$normalized');
    if (await canLaunchUrl(uri)) {
      IrisSfx.pillTap();
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'faculty_email_launch_failed',
      content: const Text('Unable to open email client on this device.'),
    );
  }

  Widget _buildFilterStrip({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.42),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final value = options[i];
              final active = selected == value;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  IrisHaptics.chipSelect();
                  onChanged(value);
                },
                child: AnimatedContainer(
                  duration: IrisMotion.fast,
                  curve: IrisMotion.standard,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? IrisTokens.brand.withValues(alpha: isDark ? 0.24 : 0.14)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? IrisTokens.brand.withValues(alpha: 0.40)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : Colors.black.withValues(alpha: 0.10)),
                    ),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: active
                          ? IrisTokens.brand
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.82)
                                : Colors.black.withValues(alpha: 0.75)),
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

  Widget _buildFacultyTile(FacultyProfile item, bool isDark) {
    final imageUrl = _resolveImageUrl(item.image);
    final insight = _teacherInsight(item.name);
    final status = insight?.status ?? 'unknown';
    final statusText = insight?.statusText ?? '';

    Color statusColor() {
      switch (status) {
        case 'live':
          return IrisTokens.success;
        case 'today':
          return IrisTokens.brand;
        case 'weekly':
        case 'upcoming':
          return IrisTokens.warning;
        default:
          return IrisTokens.purple;
      }
    }

    final smartColor = statusColor();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openTeacherLocator(item),
      child: GlassCard(
        enableOverlay: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IrisComponents.facultyAvatar(
                  imageUrl: imageUrl.isEmpty ? null : imageUrl,
                  gender: item.gender,
                  name: item.name,
                  radius: 28,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.department.isEmpty
                            ? 'Department unavailable'
                            : item.department,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.56),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: IrisTokens.purple.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location.isEmpty
                                  ? 'Location unavailable'
                                  : item.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.58),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: smartColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: smartColor.withValues(alpha: 0.30)),
                  ),
                  child: Text(
                    status == 'live'
                        ? 'LIVE NOW'
                        : status == 'today'
                        ? 'TODAY'
                        : status == 'weekly' || status == 'upcoming'
                        ? 'UPCOMING'
                        : 'LOCATE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: smartColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText.isEmpty ? 'Tap card to open Teacher Locator' : statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.58),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchEmail(item.email),
                    icon: const Icon(Icons.mail_outline_rounded, size: 16),
                    label: const Text('Email'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: IrisTokens.brand.withValues(alpha: 0.24),
                      ),
                      foregroundColor: IrisTokens.brand,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchPhone(item.contact),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: IrisTokens.success.withValues(alpha: 0.28),
                      ),
                      foregroundColor: IrisTokens.success,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(isDark: isDark),
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadFaculty,
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [IrisTokens.brand, IrisTokens.purple],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.badge_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Faculty Directory',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  Text(
                                    'Live source with backup fallback',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: (isDark ? Colors.white : Colors.black)
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: IrisTokens.brand.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: IrisTokens.brand.withValues(alpha: 0.24),
                                      ),
                                    ),
                                    child: Text(
                                      _sourceLabel(_source),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.7,
                                        color: IrisTokens.brand.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GlassCard(
                          enableOverlay: false,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              _query = value;
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 120),
                                () {
                                  if (!mounted) return;
                                  _applyFilter();
                                },
                              );
                            },
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search faculty by name, dept, location...',
                              hintStyle: TextStyle(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.45),
                              ),
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        IrisHaptics.actionSoft();
                                        _searchController.clear();
                                        _query = '';
                                        _applyFilter();
                                      },
                                      icon: const Icon(Icons.clear_rounded),
                                    ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFilterStrip(
                          title: 'DEPARTMENT',
                          options: _departments,
                          selected: _selectedDepartment,
                          onChanged: (value) {
                            setState(() => _selectedDepartment = value);
                            _applyFilter();
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildFilterStrip(
                          title: 'BLOCK',
                          options: _blocks,
                          selected: _selectedBlock,
                          onChanged: (value) {
                            setState(() => _selectedBlock = value);
                            _applyFilter();
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_error.isNotEmpty)
                          GlassCard(
                            enableOverlay: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Directory unavailable',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton.icon(
                                    onPressed: _loadFaculty,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Try again'),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Text(
                            '${_filtered.length} result${_filtered.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._filtered.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildFacultyTile(item, isDark),
                            ),
                          ),
                        ],
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

class _DepartmentClassesScreenState extends State<_DepartmentClassesScreen> {
  String? selectedProgram;
  int? selectedSemester;
  String? selectedSection;
  int? selectedDay;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Filter out batch-like programs and select the first valid one
    final validPrograms = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toList();
    if (validPrograms.isNotEmpty) {
      selectedProgram = validPrograms.first;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Filter out batch-like programs (FA##, SP##, etc.) to avoid Sem 0 display
    final programs = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toList();
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
    final List<String> dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final availableDays = <int>{};

    var dayFilteredSessions = widget.memory.sessions;
    if (selectedProgram != null) {
      dayFilteredSessions = dayFilteredSessions
          .where((s) => s.batchKey.program == selectedProgram)
          .toList();
    }
    if (selectedSemester != null && selectedSemester! > 0) {
      dayFilteredSessions = dayFilteredSessions
          .where((s) => s.batchKey.semester == selectedSemester)
          .toList();
    }
    if (selectedSection != null) {
      dayFilteredSessions = dayFilteredSessions
          .where((s) => s.batchKey.section == selectedSection)
          .toList();
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
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        leading: widget.showBackButton ? AppBackButton(isDark: isDark) : null,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const ButterScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        // Header
                        MotionSlideFade(
                          beginOffset: const Offset(0, 14),
                          duration: IrisMotion.medium,
                          curve: IrisMotion.entrance,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      IrisTokens.brand,
                                      IrisTokens.brandLight,
                                      IrisTokens.purpleLight,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: IrisTokens.brand.withValues(alpha: 0.35),
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
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                            colors: [
                                              IrisTokens.brand,
                                              IrisTokens.brandLight,
                                            ],
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
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Filters card
                        MotionSlideFade(
                          beginOffset: const Offset(0, 18),
                          duration: IrisMotion.medium,
                          curve: IrisMotion.entrance,
                          child: GlassCard(
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
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: 0.4),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: programs
                                        .map(
                                          (program) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: _buildFilterChip(
                                              label: program,
                                              selected:
                                                  selectedProgram == program,
                                              color: IrisTokens.purple,
                                              isDark: isDark,
                                              onSelected: (selected) {
                                                if (selected) {
                                                  setState(() {
                                                    this.selectedProgram =
                                                        program;
                                                    selectedSemester = null;
                                                    selectedSection = null;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        )
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
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: semesters
                                          .map(
                                            (sem) => Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: _buildFilterChip(
                                                label: 'Sem $sem',
                                                selected:
                                                    selectedSemester == sem,
                                                color: const Color(0xFF06B6D4),
                                                isDark: isDark,
                                                onSelected: (selected) {
                                                  setState(() {
                                                    selectedSemester = selected
                                                        ? sem
                                                        : null;
                                                    selectedSection = null;
                                                  });
                                                },
                                              ),
                                            ),
                                          )
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
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: sections
                                          .map(
                                            (section) => Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: _buildFilterChip(
                                                label: section,
                                                selected:
                                                    selectedSection == section,
                                                color: IrisTokens.success,
                                                isDark: isDark,
                                                onSelected: (selected) {
                                                  setState(() {
                                                    selectedSection = selected
                                                        ? section
                                                        : null;
                                                  });
                                                },
                                              ),
                                            ),
                                          )
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
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: smartDays
                                          .map(
                                            (day) => Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: _buildFilterChip(
                                                label: day == today
                                                    ? 'Today'
                                                    : dayNames[day - 1],
                                                selected: selectedDay == day,
                                                color: day == today
                                                    ? IrisTokens.success
                                                    : IrisTokens.warning,
                                                isDark: isDark,
                                                onSelected: (selected) {
                                                  setState(() {
                                                    selectedDay = selected
                                                        ? day
                                                        : null;
                                                  });
                                                },
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.4),
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 118),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final session = displayedSessions[index];
                          final isInMySchedule =
                              widget.currentBatch == session.batchKey.batch;
                          final isLive = session.isLive(DateTime.now());
                          final programAccent = _accentForProgram(
                            session.batchKey.program,
                          );

                          return StaggeredListItem(
                            index: index,
                            child: Padding(
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLive
                                            ? IrisTokens.success.withValues(alpha: 
                                                isDark ? 0.15 : 0.1,
                                              )
                                            : IrisTokens.brand.withValues(alpha: 
                                                isDark ? 0.1 : 0.06,
                                              ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            session.startTime,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isLive
                                                  ? IrisTokens.success
                                                  : IrisTokens.brand,
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 6,
                                            color:
                                                (isDark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withValues(alpha: 0.1),
                                          ),
                                          Text(
                                            session.endTime,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  (isDark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (isLive) ...[
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color:
                                                            IrisTokens.success,
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
                                                        ? IrisTokens.success
                                                        : (isDark
                                                              ? programAccent
                                                                    .withValues(alpha: 
                                                                      0.95,
                                                                    )
                                                              : programAccent
                                                                    .withValues(alpha: 
                                                                      0.90,
                                                                    )),
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isInMySchedule)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: programAccent
                                                        .withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: programAccent
                                                          .withValues(alpha: 0.2),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'MY CLASS',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
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
                                                icon: Icons
                                                    .person_outline_rounded,
                                                text: session.teacher,
                                                color: IrisTokens.brand,
                                                isDark: isDark,
                                              ),
                                              _buildMetaChip(
                                                icon: Icons.room_rounded,
                                                text: session.room,
                                                color: IrisTokens.success,
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: IrisTokens.purple
                                                  .withValues(alpha: 
                                                    isDark ? 0.14 : 0.10,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: IrisTokens.purple
                                                    .withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Text(
                                              session.batchKey.batch,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: IrisTokens.purple,
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
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.25),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No classes found',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try adjusting the filters',
                              style: TextStyle(
                                fontSize: 12,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.3),
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
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: DashboardDock(
                  scrollController: _scrollController,
                  selectedIndex: 3,
                  onTeacher: widget.brain != null
                      ? () => pushIconLaunchRoute(
                          context,
                          page: TeacherLocatorScreen(
                            brain: widget.brain!,
                            onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
                            memory: widget.memory,
                            currentBatch: widget.currentBatch,
                          ),
                        )
                      : () {},
                  onPortal: () => pushIconLaunchRoute(
                    context,
                    page: const PortalScreen(
                      url: 'https://swl-sis.comsats.edu.pk/Login/Index',
                      title: 'COMSATS Student Portal',
                      sessionScope: 'student',
                    ),
                  ),
                  onClasses: () {},
                  onTools: widget.brain != null
                      ? () => pushIconLaunchRoute(
                          context,
                          page: ToolsScreen(
                            memory: widget.memory,
                            batch: widget.currentBatch,
                            brain: widget.brain!,
                            onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
                          ),
                        )
                      : () {
                          showIrisFrostedSnackBar(
                            context,
                            dedupeKey: 'tools_unavailable_session',
                            content: Text(
                              'Tools view is unavailable for this session.',
                            ),
                          );
                        },
                  onAbout: () => pushIconLaunchRoute(
                    context,
                    page: AboutScreen(
                      memory: widget.memory,
                      onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _accentForProgram(String program) {
    final key = program.toLowerCase();
    if (key.contains('cs') || key.contains('computer')) return IrisTokens.brand;
    if (key.contains('se') || key.contains('software')) return IrisTokens.blue;
    if (key.contains('it') || key.contains('information'))
      return const Color(0xFF06B6D4);
    if (key.contains('ee') || key.contains('electrical'))
      return IrisTokens.warning;
    if (key.contains('ai') || key.contains('ml')) return IrisTokens.purple;
    if (key.contains('mech') || key.contains('mechanical'))
      return IrisTokens.error;
    return IrisTokens.success;
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
        duration: IrisMotion.fast,
        curve: IrisMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        margin: const EdgeInsets.symmetric(vertical: 2),
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          color: selected
              ? color
              : isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.8)
                : isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: -6,
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.6)),
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
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.25)),
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
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.75,
                  ),
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

class MakeupLectureScheduler extends StatefulWidget {
  final UniversityMemory memory;
  final OmniBrain brain;
  final String batch;
  final Future<void> Function(ClassSession session) onAddMakeupClass;
  final Future<void> Function(ClassSession session)? onRemoveMakeupClass;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;
  final bool showDock;
  final bool showBackButton;

  const MakeupLectureScheduler({
    required this.memory,
    required this.brain,
    required this.batch,
    required this.onAddMakeupClass,
    this.onRemoveMakeupClass,
    this.onRoleChanged,
    this.onBatchChanged,
    this.showDock = true,
    this.showBackButton = true,
    super.key,
  });

  @override
  State<MakeupLectureScheduler> createState() => _MakeupLectureSchedulerState();
}

class _MakeupLectureSchedulerState extends State<MakeupLectureScheduler> {
  late TextEditingController _teacherController;
  String? _selectedTeacher;
  String? _selectedSuggestionKey;
  bool _autoSelectedTeacher = false;
  List<MakeupSlotSuggestion> _suggestions = [];
  List<MakeupSlotSuggestion> _filteredSuggestions = [];
  List<String> _filteredTeachers = [];
  bool _isLoading = false;
  final List<String> _allTeachers = [];

  // Smart filters
  int? _filterDayIndex;
  double _minDuration = 0.5;
  int _minRooms = 0;
  String _sortBy = 'earliest'; // 'earliest', 'duration', 'rooms'
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _teacherController = TextEditingController();
    // Get all teachers from memory
    final teachers = <String>{};
    for (final session in widget.memory.sessions) {
      teachers.add(session.teacher);
    }
    _allTeachers.addAll(teachers.toList()..sort());
    _filteredTeachers = List.from(_allTeachers);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait for route transition to complete before heavy slot discovery.
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) _autoSelectSmartTeacher();
      });
    });
  }

  @override
  void dispose() {
    _teacherController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateTeacherSuggestions(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredTeachers = List.from(_allTeachers));
      return;
    }
    final q = query.toLowerCase().trim();
    final matches = _allTeachers
        .where((t) => t.toLowerCase().contains(q))
        .toList();
    setState(() => _filteredTeachers = matches);
  }

  void _selectTeacher(String teacher) {
    setState(() {
      _selectedTeacher = teacher;
      _selectedSuggestionKey = null;
      _autoSelectedTeacher = false;
      _teacherController.text = teacher;
      _filteredTeachers = [];
    });
    IrisHaptics.chipSelect();
    _findMakeupSlots();
  }

  String? _pickSmartTeacherForBatch() {
    final now = DateTime.now();
    final nowVal = now.hour + (now.minute / 60.0);
    final batchSessions = widget.memory.sessions
        .where(
          (s) =>
              s.batchKey.batch == widget.batch && !s.id.startsWith('makeup_'),
        )
        .toList();
    if (batchSessions.isEmpty) return null;

    final today = batchSessions
        .where((s) => s.dayIndex == now.weekday)
        .toList();
    today.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    final live = today
        .where((s) => s.safeStartVal <= nowVal && nowVal < s.safeEndVal)
        .toList();
    if (live.isNotEmpty) return live.first.teacher;

    final upcoming = today.where((s) => s.safeStartVal > nowVal).toList();
    if (upcoming.isNotEmpty) return upcoming.first.teacher;

    final frequency = <String, int>{};
    for (final session in batchSessions) {
      final key = session.teacher.trim();
      if (key.isEmpty) continue;
      frequency.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    if (frequency.isEmpty) return null;
    return frequency.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  void _autoSelectSmartTeacher() {
    if (_selectedTeacher != null || _isLoading || _allTeachers.isEmpty) return;

    final smartTeacher = _pickSmartTeacherForBatch();
    if (smartTeacher == null || !_allTeachers.contains(smartTeacher)) return;

    setState(() {
      _selectedTeacher = smartTeacher;
      _teacherController.text = smartTeacher;
      _selectedSuggestionKey = null;
      _filteredTeachers = [];
      _autoSelectedTeacher = true;
    });

    _findMakeupSlots();
  }

  String _timeFromDecimal(double value) {
    final hour = value.floor().clamp(0, 23);
    final minute = ((value - value.floor()) * 60).round().clamp(0, 59);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _slotKey(MakeupSlotSuggestion suggestion) {
    final teacherKey = (_selectedTeacher ?? '').trim().toLowerCase();
    return '${suggestion.dayIndex}_${suggestion.startTime.toStringAsFixed(3)}_${suggestion.endTime.toStringAsFixed(3)}_$teacherKey';
  }

  bool _sameTimeSlot(ClassSession session, MakeupSlotSuggestion suggestion) {
    return session.dayIndex == suggestion.dayIndex &&
        (session.safeStartVal - suggestion.startTime).abs() < 0.001 &&
        (session.safeEndVal - suggestion.endTime).abs() < 0.001;
  }

  ClassSession? _existingMakeupSessionForSuggestion(
    MakeupSlotSuggestion suggestion,
  ) {
    final teacher = _selectedTeacher?.trim().toLowerCase();
    if (teacher == null || teacher.isEmpty) return null;

    for (final session in widget.memory.sessions) {
      if (!session.id.startsWith('makeup_')) continue;
      if (session.batchKey.batch != widget.batch) continue;
      if (session.teacher.trim().toLowerCase() != teacher) continue;
      if (_sameTimeSlot(session, suggestion)) return session;
    }
    return null;
  }

  bool _sessionsOverlapWithSuggestion(
    ClassSession session,
    MakeupSlotSuggestion suggestion,
  ) {
    if (session.dayIndex != suggestion.dayIndex) return false;
    return session.safeStartVal < suggestion.endTime &&
        suggestion.startTime < session.safeEndVal;
  }

  ClassSession? _regularConflictForSuggestion(MakeupSlotSuggestion suggestion) {
    for (final session in widget.memory.sessions) {
      if (session.batchKey.batch != widget.batch) continue;
      if (session.id.startsWith('makeup_')) continue;
      if (_sessionsOverlapWithSuggestion(session, suggestion)) return session;
    }
    return null;
  }

  List<ClassSession> _overlappingMakeupsForSuggestion(
    MakeupSlotSuggestion suggestion,
  ) {
    final teacher = _selectedTeacher?.trim().toLowerCase();
    return widget.memory.sessions.where((session) {
      if (!session.id.startsWith('makeup_')) return false;
      if (session.batchKey.batch != widget.batch) return false;
      if (!_sessionsOverlapWithSuggestion(session, suggestion)) return false;
      if (teacher != null &&
          teacher.isNotEmpty &&
          session.teacher.trim().toLowerCase() == teacher &&
          _sameTimeSlot(session, suggestion)) {
        return false;
      }
      return true;
    }).toList();
  }

  String _inferMakeupSubject(String teacher) {
    final teacherKey = teacher.trim().toLowerCase();
    final frequency = <String, int>{};
    for (final session in widget.memory.sessions) {
      if (session.batchKey.batch != widget.batch) continue;
      if (session.id.startsWith('makeup_')) continue;
      if (session.teacher.trim().toLowerCase() != teacherKey) continue;
      final subject = session.subject.trim();
      if (subject.isEmpty) continue;
      frequency.update(subject, (count) => count + 1, ifAbsent: () => 1);
    }
    if (frequency.isEmpty) return 'Makeup Class';
    return frequency.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _pickBestRoom(MakeupSlotSuggestion suggestion, String teacher) {
    final available = suggestion.availableRooms;
    if (available == null || available.isEmpty) {
      return 'TBD';
    }

    final teacherKey = teacher.trim().toLowerCase();
    final roomFrequency = <String, int>{};
    for (final session in widget.memory.sessions) {
      if (session.batchKey.batch != widget.batch) continue;
      if (session.teacher.trim().toLowerCase() != teacherKey) continue;
      final room = session.room.trim();
      if (room.isEmpty) continue;
      roomFrequency.update(room, (count) => count + 1, ifAbsent: () => 1);
    }

    final rankedRooms = available.toList();
    rankedRooms.sort((a, b) {
      final aScore = roomFrequency[a] ?? 0;
      final bScore = roomFrequency[b] ?? 0;
      return bScore.compareTo(aScore);
    });

    return rankedRooms.first;
  }

  ClassSession _buildMakeupSession(MakeupSlotSuggestion suggestion) {
    final teacher = _selectedTeacher ?? 'Unknown Teacher';
    final inferredSubject = _inferMakeupSubject(teacher);
    final start = _timeFromDecimal(suggestion.startTime);
    final end = _timeFromDecimal(suggestion.endTime);
    final room = _pickBestRoom(suggestion, teacher);
    final teacherSlug = teacher
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final slotSlug =
        '${suggestion.dayIndex}_${(suggestion.startTime * 100).round()}_${(suggestion.endTime * 100).round()}';

    return ClassSession(
      id: 'makeup_${widget.batch}_${teacherSlug}_$slotSlug',
      batchKey: BatchKey.parse(widget.batch),
      dayIndex: suggestion.dayIndex,
      startTime: start,
      endTime: end,
      subject: inferredSubject,
      teacher: teacher,
      room: room,
    );
  }

  Future<void> _handleSuggestionAction(MakeupSlotSuggestion suggestion) async {
    if (_selectedTeacher == null || _selectedTeacher!.isEmpty) return;

    final existing = _existingMakeupSessionForSuggestion(suggestion);
    final regularConflict = _regularConflictForSuggestion(suggestion);

    if (existing == null && regularConflict != null) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_slot_conflict_${regularConflict.id}',
        content: Text(
          'Cannot add: conflicts with ${regularConflict.subject} (${regularConflict.startTime}-${regularConflict.endTime}).',
        ),
      );
      return;
    }

    if (existing != null) {
      if (widget.onRemoveMakeupClass != null) {
        await widget.onRemoveMakeupClass!(existing);
      }
    } else {
      final session = _buildMakeupSession(suggestion);
      await widget.onAddMakeupClass(session);
    }

    if (!mounted) return;
    setState(() {});
  }

  void _findMakeupSlots() {
    if (_selectedTeacher == null || _selectedTeacher!.isEmpty) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_select_teacher_first',
        content: const Text('Please select a teacher'),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Yield one frame so loading state can paint before heavy computation starts.
    Future.delayed(Duration.zero, () {
      if (!mounted) return;

      final computed = widget.brain.findMakeupSlots(
        widget.batch,
        _selectedTeacher!,
      );
      setState(() {
        _suggestions = computed;
        _applyFiltersAndSort();
      });

      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() => _isLoading = false);

          if (_filteredSuggestions.isEmpty) {
            showIrisFrostedSnackBar(
              context,
              dedupeKey: _suggestions.isEmpty
                  ? 'makeup_slots_none_common'
                  : 'makeup_slots_none_filtered',
              content: Text(
                _suggestions.isEmpty
                    ? 'No common free slots found'
                    : 'No slots match your filters. Try adjusting them.',
              ),
            );
          }
        }
      });
    });
  }

  Future<void> _openTeacherFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: TeacherLocatorScreen(
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
        memory: widget.memory,
        currentBatch: widget.batch,
      ),
    );
  }

  Future<void> _openPortalFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: const PortalScreen(
        url: 'https://swl-sis.comsats.edu.pk/Login/Index',
        title: 'COMSATS Student Portal',
        sessionScope: 'student',
      ),
    );
  }

  Future<void> _openClassesFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: _DepartmentClassesScreen(
        memory: widget.memory,
        currentBatch: widget.batch,
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
      ),
    );
  }

  Future<void> _openToolsFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: ToolsScreen(
        memory: widget.memory,
        batch: widget.batch,
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
      ),
    );
  }

  Future<void> _openAboutFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: AboutScreen(
        memory: widget.memory,
        onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
      ),
    );
  }

  void _applyFiltersAndSort() {
    var filtered = List<MakeupSlotSuggestion>.from(_suggestions);

    // Apply filters
    if (_filterDayIndex != null) {
      filtered = filtered.where((s) => s.dayIndex == _filterDayIndex).toList();
    }
    if (_minDuration > 0.5) {
      filtered = filtered
          .where((s) => s.durationHours >= _minDuration)
          .toList();
    }
    if (_minRooms > 0) {
      filtered = filtered
          .where(
            (s) =>
                s.availableRooms != null &&
                s.availableRooms!.length >= _minRooms,
          )
          .toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'earliest':
        filtered.sort((a, b) {
          final dayCompare = a.dayIndex.compareTo(b.dayIndex);
          if (dayCompare != 0) return dayCompare;
          return a.startTime.compareTo(b.startTime);
        });
        break;
      case 'duration':
        filtered.sort((a, b) => b.durationHours.compareTo(a.durationHours));
        break;
      case 'rooms':
        filtered.sort((a, b) {
          final aRooms = a.availableRooms?.length ?? 0;
          final bRooms = b.availableRooms?.length ?? 0;
          return bRooms.compareTo(aRooms);
        });
        break;
    }

    _filteredSuggestions = filtered;
  }

  void _resetFilters() {
    setState(() {
      _filterDayIndex = null;
      _minDuration = 0.5;
      _minRooms = 0;
      _sortBy = 'earliest';
      _applyFiltersAndSort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const purple = IrisTokens.purple;
    const purpleLight = IrisTokens.purpleLight;
    const indigo = IrisTokens.brand;
    const amber = Color(0xFFF59E0B);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        leading: widget.showBackButton ? AppBackButton(isDark: isDark) : null,
      ),
      body: Stack(
        children: [
          // Neural aura background
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          purple.withValues(alpha: 0.18),
                          indigo.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: purple.withValues(alpha: isDark ? 0.35 : 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [purple, purpleLight, purpleLight],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: purple.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
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
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [purple, purpleLight],
                                    ).createShader(bounds),
                                child: const Text(
                                  'Schedule Makeup',
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
                                'Find free slots with your teacher',
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 0.1,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Search card
                  GlassCard(
                    enableOverlay: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: purple.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Teacher',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.7),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Search field
                        AnimatedContainer(
                          duration: IrisMotion.fast,
                          curve: IrisMotion.standard,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      Colors.black.withValues(alpha: 0.50),
                                      Colors.black.withValues(alpha: 0.45),
                                    ]
                                  : [
                                      Colors.white.withValues(alpha: 0.85),
                                      Colors.white.withValues(alpha: 0.80),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              IrisTokens.radius20,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : IrisTokens.brand.withValues(alpha: 0.10),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: IrisTokens.brand.withValues(
                                  alpha: isDark ? 0.08 : 0.06,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                                spreadRadius: -2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.25 : 0.04,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _teacherController,
                            onChanged: (value) {
                              _updateTeacherSuggestions(value);
                              setState(() {});
                            },
                            textInputAction: TextInputAction.search,
                            enabled: !_isLoading,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search by name...',
                              hintStyle: TextStyle(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.40),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                              prefixIcon: const Icon(
                                Icons.person_search_rounded,
                                color: IrisTokens.brand,
                                size: 24,
                              ),
                              suffixIcon:
                                  _selectedTeacher != null ||
                                      _teacherController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.45),
                                        size: 22,
                                      ),
                                      splashRadius: 22,
                                      onPressed: () {
                                        IrisHaptics.actionSoft();
                                        _teacherController.clear();
                                        setState(() {
                                          _selectedTeacher = null;
                                          _selectedSuggestionKey = null;
                                          _autoSelectedTeacher = false;
                                          _filteredTeachers = List.from(
                                            _allTeachers,
                                          );
                                          _suggestions = [];
                                          _filteredSuggestions = [];
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: IrisTokens.space20,
                                vertical: IrisTokens.space20,
                              ),
                            ),
                          ),
                        ),
                        // Filtered suggestions dropdown
                        if (_filteredTeachers.isNotEmpty &&
                            _teacherController.text.isNotEmpty)
                          Column(
                            children: [
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : Colors.black.withValues(alpha: 0.06),
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  maxHeight: 220,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  itemCount: _filteredTeachers.length,
                                  itemBuilder: (context, index) {
                                    final teacher = _filteredTeachers[index];
                                    final isSelected =
                                        _selectedTeacher == teacher;
                                    return InkWell(
                                      onTap: () => _selectTeacher(teacher),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? purple.withValues(alpha: 
                                                  isDark ? 0.16 : 0.10,
                                                )
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? Icons.check_circle_rounded
                                                  : Icons.person_rounded,
                                              size: 16,
                                              color: isSelected
                                                  ? purple
                                                  : (isDark
                                                            ? Colors.white
                                                            : Colors.black)
                                                        .withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                teacher,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        if (_selectedTeacher != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: purple.withValues(alpha: isDark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: purple.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                  color: IrisTokens.purple,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedTeacher!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 
                                      isDark ? 0.08 : 0.7,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _autoSelectedTeacher
                                        ? 'Smart Pick'
                                        : 'Selected',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Find Slots Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _selectedTeacher == null
                          ? null
                          : _findMakeupSlots,
                      icon: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(
                        _isLoading ? 'Searching...' : 'Find Available Slots',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: purple.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                        shadowColor: purple.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Results with Filters and Sort
                  if (_suggestions.isNotEmpty) ...[
                    // Statistics Summary
                    GlassCard(
                      enableOverlay: false,
                      enableShadow: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics_rounded,
                                size: 16,
                                color: purple.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Summary',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                Icons.event_available_rounded,
                                _filteredSuggestions.length.toString(),
                                'Slots',
                                isDark,
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: purple.withValues(alpha: 0.2),
                              ),
                              _buildStatItem(
                                Icons.access_time_rounded,
                                '${_filteredSuggestions.fold<double>(0, (sum, s) => sum + s.durationHours).toStringAsFixed(1)}h',
                                'Total',
                                isDark,
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: purple.withValues(alpha: 0.2),
                              ),
                              _buildStatItem(
                                Icons.meeting_room_rounded,
                                _filteredSuggestions
                                    .where(
                                      (s) =>
                                          (s.availableRooms?.isNotEmpty ??
                                          false),
                                    )
                                    .length
                                    .toString(),
                                'With Rooms',
                                isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filter & Sort Controls
                    GlassCard(
                      enableOverlay: false,
                      enableShadow: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 16,
                                color: purple.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Filters & Sorting',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _resetFilters,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: amber.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: amber.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'Reset',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: amber,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Day Filter
                              Expanded(
                                child: _buildFilterChip(
                                  icon: Icons.calendar_today_rounded,
                                  label: _filterDayIndex == null
                                      ? 'All Days'
                                      : [
                                          'Mon',
                                          'Tue',
                                          'Wed',
                                          'Thu',
                                          'Fri',
                                          'Sat',
                                          'Sun',
                                        ][_filterDayIndex! - 1],
                                  onTap: () => _showDayFilter(isDark),
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Sort
                              Expanded(
                                child: _buildFilterChip(
                                  icon: Icons.sort_rounded,
                                  label: _sortBy == 'earliest'
                                      ? 'Earliest'
                                      : _sortBy == 'duration'
                                      ? 'Longest'
                                      : 'Most Rooms',
                                  onTap: () => _showSortOptions(isDark),
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Slots Header
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [purple, purpleLight],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Available Slots',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_filteredSuggestions.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Slots List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredSuggestions.length,
                      separatorBuilder: (_, index2) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final suggestion = _filteredSuggestions[index];
                        return _buildMakeupSlotCard(suggestion, isDark);
                      },
                    ),
                    const SizedBox(height: 20),
                  ] else if (!_isLoading && _selectedTeacher != null) ...[
                    GlassCard(
                      enableOverlay: false,
                      enableShadow: false,
                      child: Row(
                        children: [
                          Icon(Icons.info_rounded, color: amber, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'No common free slots found. Try another teacher.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: DashboardDock(
                  scrollController: _scrollController,
                  selectedIndex: 5,
                  onTeacher: _openTeacherFromMakeup,
                  onPortal: _openPortalFromMakeup,
                  onClasses: _openClassesFromMakeup,
                  onTools: _openToolsFromMakeup,
                  onMakeup: () {},
                  onAbout: _openAboutFromMakeup,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMakeupSlotCard(MakeupSlotSuggestion suggestion, bool isDark) {
    final slotKey = _slotKey(suggestion);
    final isSelected = _selectedSuggestionKey == slotKey;
    final existing = _existingMakeupSessionForSuggestion(suggestion);
    final isAdded = existing != null;
    final regularConflict = _regularConflictForSuggestion(suggestion);
    final overlappingMakeups = _overlappingMakeupsForSuggestion(suggestion);
    final isBlocked = regularConflict != null && !isAdded;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IrisTokens.brand.withValues(
              alpha: isSelected
                  ? (isDark ? 0.22 : 0.14)
                  : (isDark ? 0.14 : 0.08),
            ),
            IrisTokens.brandLight.withValues(
              alpha: isSelected
                  ? (isDark ? 0.14 : 0.10)
                  : (isDark ? 0.10 : 0.06),
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? IrisTokens.brand.withValues(alpha: 0.46)
              : IrisTokens.brand.withValues(alpha: 0.28),
          width: isSelected ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: IrisTokens.brand.withValues(alpha: isDark ? 0.2 : 0.12),
            blurRadius: isSelected ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _selectedSuggestionKey = slotKey);
          IrisHaptics.actionSoft();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day and Time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [IrisTokens.brand, IrisTokens.brandLight],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      suggestion.dayName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion.timeRangeString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: IrisTokens.brand,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: IrisTokens.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: IrisTokens.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${suggestion.durationHours.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: IrisTokens.success,
                      ),
                    ),
                  ),
                ],
              ),
              if (isAdded) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: IrisTokens.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.success.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: IrisTokens.success,
                        size: 15,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Already in your timeline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: IrisTokens.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isBlocked) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: IrisTokens.error.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.error.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: IrisTokens.error,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Conflicts with ${regularConflict.subject} (${regularConflict.startTime}-${regularConflict.endTime})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: IrisTokens.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (!isAdded && overlappingMakeups.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: IrisTokens.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.brand.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.autorenew_rounded,
                        color: IrisTokens.brand,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Will replace ${overlappingMakeups.length} overlapping makeup slot${overlappingMakeups.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: IrisTokens.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Suggested free window',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.55,
                  ),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),

              // Available Rooms
              if (suggestion.availableRooms != null &&
                  suggestion.availableRooms!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: IrisTokens.success.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.success.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_rounded,
                            size: 16,
                            color: IrisTokens.success,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Available Rooms (${suggestion.availableRooms!.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: IrisTokens.success,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: suggestion.availableRooms!
                            .take(10) // Show max 10 rooms
                            .map(
                              (room) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: IrisTokens.success.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: IrisTokens.success.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  room,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (suggestion.availableRooms!.length > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+${suggestion.availableRooms!.length - 10} more rooms',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: IrisTokens.success.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.orange.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No rooms available during this slot',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedTeacher == null || isBlocked)
                      ? null
                      : () => _handleSuggestionAction(suggestion),
                  icon: Icon(
                    isBlocked
                        ? Icons.block_rounded
                        : (isAdded
                              ? Icons.remove_circle_outline_rounded
                              : Icons.add_circle_outline_rounded),
                  ),
                  label: Text(
                    isBlocked
                        ? 'Conflicting Slot'
                        : (isAdded
                              ? 'Remove From Timeline'
                              : 'Add To Timeline'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlocked
                        ? (isDark ? Colors.white24 : Colors.black26)
                        : (isAdded ? IrisTokens.error : IrisTokens.brand),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              if (!isAdded && !isBlocked) ...[
                const SizedBox(height: 8),
                Text(
                  overlappingMakeups.isNotEmpty
                      ? 'This will replace overlapping makeup slots and keep restore history.'
                      : 'If this overlaps another makeup slot, the app replaces it intelligently.',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    bool isDark,
  ) {
    return Column(
      children: [
        Icon(icon, color: IrisTokens.brand, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: IrisTokens.brand.withValues(alpha: isDark ? 0.16 : 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.3)),
          boxShadow: const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: IrisTokens.brand),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDayFilter(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => GlassSurface(
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
          title: const Text('Filter by Day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Days'),
                leading: Radio<int?>(
                  value: null,
                  groupValue: _filterDayIndex,
                  onChanged: (val) {
                    setState(() {
                      _filterDayIndex = val;
                      _applyFiltersAndSort();
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
              ...List.generate(7, (i) {
                final days = [
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday',
                ];
                return ListTile(
                  title: Text(days[i]),
                  leading: Radio<int?>(
                    value: i + 1,
                    groupValue: _filterDayIndex,
                    onChanged: (val) {
                      setState(() {
                        _filterDayIndex = val;
                        _applyFiltersAndSort();
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
}

  void _showSortOptions(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => GlassSurface(
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
          title: const Text('Sort By'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ListTile(
              title: const Text('Earliest First'),
              leading: Radio<String>(
                value: 'earliest',
                groupValue: _sortBy,
                onChanged: (val) {
                  setState(() {
                    _sortBy = val!;
                    _applyFiltersAndSort();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            ListTile(
              title: const Text('Longest Duration'),
              leading: Radio<String>(
                value: 'duration',
                groupValue: _sortBy,
                onChanged: (val) {
                  setState(() {
                    _sortBy = val!;
                    _applyFiltersAndSort();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            ListTile(
              title: const Text('Most Rooms Available'),
              leading: Radio<String>(
                value: 'rooms',
                groupValue: _sortBy,
                onChanged: (val) {
                  setState(() {
                    _sortBy = val!;
                    _applyFiltersAndSort();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            ],
          ),
        ),
      ),
    );
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

class ExamGridDashboard extends StatefulWidget {
  final String period;
  final String batch;
  final VoidCallback onToggleTheme;

  const ExamGridDashboard({
    required this.period,
    required this.batch,
    required this.onToggleTheme,
    super.key,
  });

  @override
  State<ExamGridDashboard> createState() => _ExamGridDashboardState();
}

class _ExamGridDashboardState extends State<ExamGridDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _parseExamDate(String dateStr) {
    final parts = dateStr.split(' ');
    if (parts.length < 2) return null;
    final datePart = parts[1];
    
    final dmyRegex = RegExp(r'(\d{2})-(\d{2})-(\d{4})');
    var match = dmyRegex.firstMatch(datePart);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    }
    
    final dmyShortRegex = RegExp(r'(\d{2})-(\d{2})-(\d{2})');
    match = dmyShortRegex.firstMatch(datePart);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final shortYear = int.parse(match.group(3)!);
      final year = 2000 + shortYear;
      return DateTime(year, month, day);
    }
    return null;
  }

  String _getExamStatus(DateTime? examDate) {
    if (examDate == null) return 'UPCOMING';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);
    
    if (examDay.isBefore(today)) {
      return 'COMPLETED';
    } else if (examDay.isAtSameMomentAs(today)) {
      return 'TODAY';
    } else {
      return 'UPCOMING';
    }
  }

  String _formatExamDate(String rawDate) {
    final parts = rawDate.split(' ');
    if (parts.length < 2) return rawDate;
    final weekday = parts[0];
    final datePart = parts[1];
    final dmyRegex = RegExp(r'(\d{2})-(\d{2})-(\d{4})');
    final match = dmyRegex.firstMatch(datePart);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '$weekday, ${months[month - 1]} $day, $year';
    }
    final dmyShortRegex = RegExp(r'(\d{2})-(\d{2})-(\d{2})');
    final matchShort = dmyShortRegex.firstMatch(datePart);
    if (matchShort != null) {
      final day = int.parse(matchShort.group(1)!);
      final month = int.parse(matchShort.group(2)!);
      final shortYear = int.parse(matchShort.group(3)!);
      final year = 2000 + shortYear;
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '$weekday, ${months[month - 1]} $day, $year';
    }
    return rawDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.period == 'midterms' ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E);
    final titleText = widget.period == 'midterms' ? 'MIDTERM EXAMS' : 'FINAL EXAMS';

    return SafeArea(
      child: ValueListenableBuilder<List<dynamic>>(
        valueListenable: widget.period == 'midterms'
            ? RemoteConfigService.midtermExams
            : RemoteConfigService.finalExams,
        builder: (context, rawExams, _) {
          final matchedExams = rawExams.where((exam) {
            final examBatch = (exam['batch'] ?? '').toString();
            if (examBatch.isEmpty || widget.batch.isEmpty) return false;
            
            final studentBatch = widget.batch.trim().toLowerCase();
            final examBatchLower = examBatch.trim().toLowerCase();
            if (examBatchLower == studentBatch) return true;
            
            final studentKey = BatchKey.parse(widget.batch);
            final examKey = BatchKey.parse(examBatch);
            
            final examParts = examBatchLower.split('-');
            if (examParts.length == 2) {
              return studentKey.intake.toLowerCase() == examKey.intake.toLowerCase() &&
                     studentKey.program.toLowerCase() == examKey.program.toLowerCase();
            }
            
            return studentKey.intake.toLowerCase() == examKey.intake.toLowerCase() &&
                   studentKey.program.toLowerCase() == examKey.program.toLowerCase() &&
                   studentKey.section.toLowerCase() == examKey.section.toLowerCase();
          }).toList();

          final Map<String, Map<String, dynamic>> grouped = {};
          for (final exam in matchedExams) {
            final date = (exam['date'] ?? '').toString();
            final time = (exam['time'] ?? '').toString();
            final subject = (exam['subject'] ?? '').toString();
            final room = (exam['room'] ?? '').toString();
            
            final key = '${date}_${time}_${subject}';
            if (grouped.containsKey(key)) {
              final existingRooms = grouped[key]!['rooms'] as List<String>;
              if (!existingRooms.contains(room)) {
                existingRooms.add(room);
              }
            } else {
              grouped[key] = {
                'date': date,
                'time': time,
                'subject': subject,
                'rooms': [room],
              };
            }
          }

          var examsList = grouped.values.toList();

          examsList.sort((a, b) {
            final dateA = _parseExamDate(a['date'] ?? '') ?? DateTime(3000);
            final dateB = _parseExamDate(b['date'] ?? '') ?? DateTime(3000);
            if (dateA != dateB) {
              return dateA.compareTo(dateB);
            }
            final timeA = (a['time'] ?? '').toString();
            final timeB = (b['time'] ?? '').toString();
            return timeA.compareTo(timeB);
          });

          if (_searchQuery.isNotEmpty) {
            examsList = examsList.where((ex) {
              final sub = (ex['subject'] ?? '').toString().toLowerCase();
              return sub.contains(_searchQuery.toLowerCase());
            }).toList();
          }

          // Calculate stats and next exam
          final totalExams = examsList.length;
          int completedExams = 0;
          int upcomingExams = 0;
          Map<String, dynamic>? nextExam;
          int daysToNextExam = -1;

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          for (final exam in examsList) {
            final parsedDate = _parseExamDate(exam['date'] ?? '');
            final status = _getExamStatus(parsedDate);
            if (status == 'COMPLETED') {
              completedExams++;
            } else {
              upcomingExams++;
              if (nextExam == null && parsedDate != null) {
                nextExam = exam;
                daysToNextExam = DateTime(parsedDate.year, parsedDate.month, parsedDate.day)
                    .difference(today)
                    .inDays;
              }
            }
          }

          // Group by Date for vertical timeline grouping
          final List<Map<String, dynamic>> dateGroups = [];
          for (final exam in examsList) {
            final date = (exam['date'] ?? '').toString();
            final lastGroup = dateGroups.isNotEmpty ? dateGroups.last : null;
            if (lastGroup != null && lastGroup['date'] == date) {
              (lastGroup['exams'] as List).add(exam);
            } else {
              dateGroups.add({
                'date': date,
                'exams': [exam],
              });
            }
          }

          return CustomScrollView(
            physics: const ButterScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(22),
                    borderRadius: 32.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: widget.period == 'midterms'
                                      ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                      : [const Color(0xFFF43F5E), const Color(0xFFE11D48)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                  child: Icon(Icons.assignment_rounded, color: Colors.white, size: 24)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: accentColor,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Exam Schedule',
                                    style: IrisTextStyles.headline(context).copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: widget.onToggleTheme,
                                icon: Icon(
                                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                  size: 20,
                                  color: isDark ? Colors.white70 : IrisTokens.brand,
                                ),
                                padding: const EdgeInsets.all(10),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        Divider(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08), height: 1),
                        const SizedBox(height: 20),
                        
                        // Circular Progress & Stats Group
                        Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: CircularProgressIndicator(
                                    value: totalExams > 0 ? completedExams / totalExams : 0.0,
                                    strokeWidth: 5,
                                    backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                  ),
                                ),
                                Text(
                                  totalExams > 0 ? '${((completedExams / totalExams) * 100).round()}%' : '0%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$completedExams / $totalExams Completed',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          widget.batch,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$upcomingExams exams remaining',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Next Exam Countdown Indicator
                        if (nextExam != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_rounded, color: accentColor, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        daysToNextExam == 0
                                            ? 'NEXT EXAM: TODAY 🔥'
                                            : daysToNextExam == 1
                                                ? 'NEXT EXAM: TOMORROW 📚'
                                                : 'NEXT EXAM: IN $daysToNextExam DAYS',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: accentColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        nextExam['subject']?.toString() ?? 'Exam',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
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
              
              // Search Input Box
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    borderRadius: 20,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        icon: Icon(Icons.search_rounded, color: (isDark ? Colors.white54 : Colors.black54)),
                        hintText: 'Search exams by subject...',
                        hintStyle: TextStyle(
                          color: (isDark ? Colors.white38 : Colors.black38),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              
              examsList.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: GlassCard(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accentColor.withValues(alpha: 0.15),
                                      accentColor.withValues(alpha: 0.05),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.calendar_today_rounded,
                                  size: 38,
                                  color: accentColor.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _searchQuery.isNotEmpty ? 'No matching exams' : 'No exams scheduled',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 0.2,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty 
                                    ? 'Try looking for another subject.' 
                                    : 'There are no exams listed for batch ${widget.batch} yet.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, groupIdx) {
                          final group = dateGroups[groupIdx];
                          final dateStr = group['date'] as String;
                          final groupExams = group['exams'] as List;
                          final parsedDate = _parseExamDate(dateStr);
                          final isTodayDate = _getExamStatus(parsedDate) == 'TODAY';
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Beautiful Left-Bordered Sticky Date Header
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: isTodayDate ? const Color(0xFF4F46E5) : accentColor.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _formatExamDate(dateStr),
                                      style: IrisTextStyles.headline(context).copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: isTodayDate 
                                            ? const Color(0xFF4F46E5) 
                                            : (isDark ? Colors.white70 : Colors.black87),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    if (isTodayDate) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'TODAY',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF4F46E5),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Grouped cards with timeline vertical connector
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: groupExams.length,
                                  separatorBuilder: (context, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, examIdx) {
                                    final exam = groupExams[examIdx];
                                    final subject = exam['subject']?.toString() ?? 'Unknown Exam';
                                    final timeStr = exam['time']?.toString() ?? 'TBD';
                                    final roomsList = List<String>.from(exam['rooms'] ?? []);
                                    final status = _getExamStatus(parsedDate);
                                    
                                    return StaggeredListItem(
                                      index: groupIdx * 10 + examIdx,
                                      child: ExamCard(
                                        subject: subject,
                                        rawDate: dateStr,
                                        parsedDate: parsedDate,
                                        rawTime: timeStr,
                                        rooms: roomsList,
                                        status: status,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          );
                        },
                        childCount: dateGroups.length,
                      ),
                    ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          );
        },
      ),
    );
  }
}

class ExamCard extends StatelessWidget {
  final String subject;
  final String rawDate;
  final DateTime? parsedDate;
  final String rawTime;
  final List<String> rooms;
  final String status;

  const ExamCard({
    required this.subject,
    required this.rawDate,
    required this.parsedDate,
    required this.rawTime,
    required this.rooms,
    required this.status,
    super.key,
  });

  String _formatExamDate(String rawDate) {
    final parts = rawDate.split(' ');
    if (parts.length < 2) return rawDate;
    final weekday = parts[0];
    final datePart = parts[1];
    final dmyRegex = RegExp(r'(\d{2})-(\d{2})-(\d{4})');
    final match = dmyRegex.firstMatch(datePart);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '$weekday, ${months[month - 1]} $day, $year';
    }
    final dmyShortRegex = RegExp(r'(\d{2})-(\d{2})-(\d{2})');
    final matchShort = dmyShortRegex.firstMatch(datePart);
    if (matchShort != null) {
      final day = int.parse(matchShort.group(1)!);
      final month = int.parse(matchShort.group(2)!);
      final shortYear = int.parse(matchShort.group(3)!);
      final year = 2000 + shortYear;
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '$weekday, ${months[month - 1]} $day, $year';
    }
    return rawDate;
  }

  String _formatExamTime(String rawTime) {
    final timeRegex = RegExp(r'(\d{2})(\d{2})-(\d{2})(\d{2})');
    final match = timeRegex.firstMatch(rawTime);
    if (match != null) {
      String formatPart(String hr, String min) {
        int h = int.parse(hr);
        final ampm = h >= 12 ? 'PM' : 'AM';
        if (h > 12) h -= 12;
        if (h == 0) h = 12;
        return '$h:$min $ampm';
      }
      return '${formatPart(match.group(1)!, match.group(2)!)} - ${formatPart(match.group(3)!, match.group(4)!)}';
    }
    return rawTime;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color statusColor;
    String badgeText = status;
    if (status == 'COMPLETED') {
      statusColor = isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3);
      badgeText = 'COMPLETED';
    } else if (status == 'TODAY') {
      statusColor = const Color(0xFF4F46E5);
      badgeText = 'TODAY 🔥';
    } else {
      statusColor = const Color(0xFF10B981);
      if (parsedDate != null) {
        final diff = DateTime(parsedDate!.year, parsedDate!.month, parsedDate!.day)
            .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
            .inDays;
        badgeText = diff == 1 ? 'TOMORROW' : 'IN $diff DAYS';
      }
    }

    final displayDate = _formatExamDate(rawDate);
    final displayTime = _formatExamTime(rawTime);
    final displayRooms = rooms.isEmpty ? 'TBD' : rooms.join(' // ');

    return Opacity(
      opacity: status == 'COMPLETED' ? 0.55 : 1.0,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'VENUE ALLOCATION',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: (isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.55)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.20), width: 1),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subject,
              style: IrisTextStyles.headline(context).copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.meeting_room_rounded,
                  size: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    displayRooms,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$displayDate // $displayTime',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
