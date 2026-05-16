import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../core/animations.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../core/vital_theme.dart';
import '../widgets/glass_card.dart';
import '../services/ui_feedback.dart';
import '../services/notification_service.dart';

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
    _loadInitialBatchSelection();
  }

  Future<void> _loadInitialBatchSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBatch = prefs.getString('user_batch')?.trim();

    final fallbackBatch = savedBatch != null && savedBatch.isNotEmpty
        ? savedBatch
        : (widget.memory.allBatches.isNotEmpty ? widget.memory.allBatches.first : null);

    if (fallbackBatch == null || !mounted) {
      return;
    }

    final key = BatchKey.parse(fallbackBatch);
    setState(() {
      _program = key.program;
      _semester = key.semester == 0 ? null : key.semester;
      _section = key.section;
    });
  }

  // Static method to show widget setup guide from SetupBot
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

  String? _resolveBatch() {
    if (_program == null || _semester == null || _section == null) {
      return null;
    }

    for (final batch in widget.memory.allBatches) {
      final key = BatchKey.parse(batch);
      if (key.program == _program &&
          key.semester == _semester &&
          key.section == _section) {
        return batch;
      }
    }

    return null;
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
    final resolvedBatch = _resolveBatch();
    final smartBatchLabel = resolvedBatch ?? (widget.memory.allBatches.isNotEmpty ? widget.memory.allBatches.first : null);

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
                    if (smartBatchLabel != null) ...[
                      const SizedBox(height: 14),
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: IrisTokens.brandGradient),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Smart default',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.92)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      smartBatchLabel,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.72)),
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
                    ],
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
                    if (_program != null && _semester != null && _section != null && resolvedBatch == null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'No exact batch matches this combination yet.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
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
                                    final batch = _resolveBatch();
                                    if (batch == null) return;
                                    IrisHaptics.chipSelect();
                                    widget.onComplete(batch.trim());
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: isReady
                                  ? Colors.white
                                  : (isDarkBtn
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.black.withValues(alpha: 0.25)),
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  IrisTokens.radius20,
                                ),
                              ),
                            ),
                            child: const Text(
                              'INITIALIZE BRAIN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
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
