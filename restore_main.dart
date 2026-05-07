void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database
  tz.initializeTimeZones();

  runApp(const IrisApp());

  unawaited(_bootstrapStartupServices());
}

Future<void> _bootstrapStartupServices() async {
  try {
    await WidgetService.initialize();
  } catch (e) {
    debugPrint('Widget service init failed: $e');
  }

  try {
    await WidgetService.initializeWidgetDefaults();
  } catch (e) {
    debugPrint('Widget defaults init failed: $e');
  }

  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }

  try {
    await IrisSfx.init();
  } catch (e) {
    debugPrint('UI sound init failed: $e');
  }

  try {
    await IrisHaptics.init();
  } catch (e) {
    debugPrint('Haptics init failed: $e');
  }

  try {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'persistent_class_foreground',
        channelName: 'IRIS Class Tracker',
        channelDescription: 'Shows your current and upcoming classes',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          30000,
        ), // Update every 30 seconds
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  } catch (e) {
    debugPrint('Foreground task init failed: $e');
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final persistentEnabled =
        prefs.getBool('persistent_notification_enabled') ?? false;
    final userRole = prefs.getString('user_role') ?? 'student';

    final hasStudentData =
        prefs.containsKey('student_batch') && prefs.containsKey('timetable_data');

    if (persistentEnabled &&
        userRole == 'student' &&
        hasStudentData &&
        !(await FlutterForegroundTask.isRunningService)) {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'IRIS Class Tracker',
        notificationText: 'Loading your schedule...',
        notificationIcon: null,
        notificationButtons: [NotificationButton(id: 'open', text: 'Open IRIS')],
        callback: startClassNotificationTask,
      );
    }
  } catch (e) {
    debugPrint('Foreground service restore failed: $e');
  }

  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (e) {
    debugPrint('System UI mode update failed: $e');
  }

  try {
    unawaited(
      TimetableOTAService.checkForUpdatesOnStartup().catchError((e) {
        debugPrint('OTA check failed on startup: $e');
      }),
    );
  } catch (e) {
    debugPrint('OTA bootstrap failed: $e');
  }

  try {
    await NotificationService().syncClassRemindersFromPrefs();
  } catch (e) {
    debugPrint('Reminder sync failed: $e');
  }
}

class IrisApp extends StatefulWidget {
  const IrisApp({super.key});

  @override
  State<IrisApp> createState() => _IrisAppState();
}

class _IrisAppState extends State<IrisApp> {
  ThemeMode _themeMode = ThemeMode.system;

  String get _themeModeKey {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _themeModeFromKey(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IrisSfx.click();
    });
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('themeMode');
    final legacyMode = prefs.getString('appearance_mode');
    final mode = savedMode ?? legacyMode ?? 'system';

    if (savedMode == null && legacyMode != null) {
      await prefs.setString('themeMode', mode);
    }
    if (legacyMode != mode) {
      await prefs.setString('appearance_mode', mode);
    }

    if (!mounted) return;
    setState(() {
      _themeMode = _themeModeFromKey(mode);
    });
  }

  Future<void> _setThemeMode(String mode) async {
    IrisSfx.tick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode);
    await prefs.setString('appearance_mode', mode);

    if (!mounted) return;
    setState(() {
      _themeMode = _themeModeFromKey(mode);
    });
  }

  Future<void> _toggleTheme() async {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isEffectivelyDark =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);
    final next = isEffectivelyDark ? 'light' : 'dark';
    await _setThemeMode(next);
  }

  @override
  Widget build(BuildContext context) {
    // Set system overlay styles based on theme
    final isDark =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
    return MaterialApp(
      title: 'IRIS',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const SmoothScrollBehavior(),
      themeMode: _themeMode,
      themeAnimationDuration: const Duration(milliseconds: 384),
      themeAnimationCurve: IrisMotion.standard,
      theme: IrisTheme.light(),
      darkTheme: IrisTheme.dark(),
      home: FutureBuilder<UniversityMemory>(
        future: UniversityMemoryLoader.loadFromAssets(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _BootScreen();
          }
          return _AppRoot(
            memory: snapshot.data!,
            onToggleTheme: _toggleTheme,
            onSetThemeMode: _setThemeMode,
            currentThemeMode: _themeModeKey,
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

    _pulseController = AnimationController(
      duration: IrisMotion.slow,
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: IrisMotion.standard),
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 2880),
      vsync: this,
    )..repeat();

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));
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
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              IrisTokens.brand.withValues(alpha: 0.18),
                              IrisTokens.brand.withValues(alpha: 0.04),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: IrisTokens.brand.withValues(alpha: 0.16),
                              offset: const Offset(0, 8),
                              blurRadius: 22,
                              spreadRadius: -8,
                            ),
                          ],
                        ),
                      ),
                    ),

                    RotationTransition(
                      turns: _rotateAnimation,
                      child: Container(
                        width: 135,
                        height: 135,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: IrisTokens.brand.withValues(alpha: 0.25),
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),

                    RotationTransition(
                      turns: Tween<double>(begin: 0, end: -1).animate(
                        CurvedAnimation(
                          parent: _rotateController,
                          curve: Curves.linear,
                        ),
                      ),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: IrisTokens.purple.withValues(alpha: 0.25),
                            width: 1.5,
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
                          color: IrisTokens.warning,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: IrisTokens.warning.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: IrisTokens.warning.withValues(alpha: 0.22),
                              offset: const Offset(0, 6),
                              blurRadius: 14,
                              spreadRadius: -4,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                              spreadRadius: 0,
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
                Text(
                  'IRIS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 6.0,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'INTELLIGENT ROUTINE & INSIGHT SYSTEM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3.0,
                    color:
                        (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black)
                            .withValues(alpha: 0.40),
                  ),
                ),
                const SizedBox(height: 44),
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(IrisTokens.brand),
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

