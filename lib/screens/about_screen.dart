import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/tokens.dart';
import '../core/models.dart';
import '../services/ui_feedback.dart';
import '../services/notification_service.dart';
import '../services/timetable_ota_service.dart';
import '../services/widget_service.dart';
import '../widgets/neural_aura.dart';
import '../widgets/smooth_scroll.dart';
import '../widgets/glass_card.dart';
import '../widgets/batch_selector.dart';
import '../widgets/dashboard_dock.dart';
import 'portal_screen.dart';
import '../core/vital_theme.dart';

class AboutScreen extends StatefulWidget {
  final UniversityMemory memory;
  final ValueChanged<String>? onUserNameChanged;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;

  const AboutScreen({
    required this.memory,
    this.onUserNameChanged,
    this.onRoleChanged,
    this.onBatchChanged,
    super.key,
  });

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  Map<String, dynamic>? _otaStatus;
  String _userName = 'Student';
  String _batch = '...';
  String _userRole = 'student';
  bool _notificationsEnabled = true;
  bool _hapticsEnabled = true;
  bool _soundsEnabled = true;
  bool _widgetDarkMode = false;
  String _feedbackProfile = 'gentle';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshOTA();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role') ?? 'student';
      
      // Load name based on role
      if (_userRole == 'faculty') {
        _userName = prefs.getString('faculty_user_name') ?? 'Faculty Member';
      } else {
        _userName = prefs.getString('student_user_name')?.trim().isNotEmpty == true
            ? prefs.getString('student_user_name')!.trim()
            : 'Student';
      }

      _batch = prefs.getString('user_batch') ?? 'UNKNOWN';
      _notificationsEnabled = prefs.getBool('persistent_notification_enabled') ??
          prefs.getBool('notifications_enabled') ??
          false;
      _hapticsEnabled = prefs.getBool('ui_haptics_enabled') ?? true;
      _soundsEnabled = prefs.getBool('ui_sounds_enabled') ?? true;
      _widgetDarkMode = prefs.getBool('widget_dark_mode') ?? false;
      _feedbackProfile = prefs.getString('ui_feedback_profile') ?? 'gentle';
    });
  }

  Future<void> _refreshOTA() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final status = await TimetableOTAService.getUpdateStatus();
      setState(() => _otaStatus = status);
    } catch (e) {
      debugPrint('OTA Status check failed: $e');
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _updateBatch() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BatchSelectorSheet(
        memory: widget.memory,
        selected: _batch,
      ),
    );

    if (result != null && result != _batch) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_batch', result);
      setState(() => _batch = result);
      widget.onBatchChanged?.call(result);
      IrisHaptics.actionHeavy();
      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          content: Text('Batch updated to $result'),
          tint: IrisTokens.brand,
        );
      }
    }
  }

  Future<void> _editUserName() async {
    if (_userRole == 'faculty') {
      showIrisFrostedSnackBar(
        context,
        content: const Text('Faculty name is derived from timetable data.'),
        tint: IrisTokens.brand,
      );
      return;
    }

    final controller = TextEditingController(
      text: _userName == 'Student' ? '' : _userName,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
          title: const Text('Change Name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Your name',
              hintText: 'Enter your display name',
            ),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final trimmed = newName?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == _userName) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_user_name', trimmed);
    setState(() => _userName = trimmed);
    widget.onUserNameChanged?.call(trimmed);
    IrisHaptics.actionMedium();
  }

  Future<void> _toggleRole() async {
    final newRole = _userRole == 'student' ? 'faculty' : 'student';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', newRole);
    
    // Update local state and name immediately
    setState(() {
      _userRole = newRole;
      if (newRole == 'faculty') {
        _userName = prefs.getString('faculty_user_name') ?? 'Faculty Member';
      } else {
        _userName = prefs.getString('student_user_name')?.trim().isNotEmpty == true
            ? prefs.getString('student_user_name')!.trim()
            : 'Student';
      }
    });
    
    widget.onRoleChanged?.call(newRole);
    IrisHaptics.actionMedium();
  }

  Future<void> _togglePersistentNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('persistent_notification_enabled', value);
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);

    if (!value) {
      await FlutterForegroundTask.stopService();
    } else if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'IRIS Class Tracker',
        notificationText: 'Keeping your class schedule handy',
        notificationButtons: [
          NotificationButton(id: 'open', text: 'Open IRIS'),
        ],
      );
    } else {
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
    IrisHaptics.actionSoft();
  }

  Future<void> _runOtaSync() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final result = await TimetableOTAService.forceRefresh();
      final status = await TimetableOTAService.getUpdateStatus();
      if (!mounted) return;
      setState(() => _otaStatus = status);
      showIrisFrostedSnackBar(
        context,
        content: Text(
          result == 1
              ? 'Timetable updated'
              : result == 0
                  ? 'Timetable already up to date'
                  : 'OTA sync failed',
        ),
        tint: result == 1 ? IrisTokens.success : IrisTokens.brand,
      );
    } catch (e) {
      debugPrint('OTA sync failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _toggleWidgetDarkMode(bool value) async {
    await WidgetService.setWidgetDarkMode(value);
    setState(() => _widgetDarkMode = value);
    IrisHaptics.actionSoft();
  }

  Future<void> _showWidgetGuide() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Home Widget',
                style: IrisTextStyles.classSubject(ctx),
              ),
              const SizedBox(height: 8),
              Text(
                'Add the IRIS widget from your launcher to keep class updates visible at a glance.',
                style: IrisTextStyles.body(ctx).copyWith(height: 1.45, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 16),
              const _WidgetStep(number: '1', text: 'Long press the home screen'),
              const SizedBox(height: 10),
              const _WidgetStep(number: '2', text: 'Open Widgets and search IRIS'),
              const SizedBox(height: 10),
              const _WidgetStep(number: '3', text: 'Drag the widget to your screen'),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangelog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _ChangelogSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? IrisTokens.surfaceDark : IrisTokens.surfaceLight,
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  stretch: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final top = constraints.biggest.height;
                      final percent = ((top - kToolbarHeight) / (220 - kToolbarHeight)).clamp(0.0, 1.0);
                      
                      return FlexibleSpaceBar(
                        centerTitle: true,
                        expandedTitleScale: 1.0,
                        title: Opacity(
                          opacity: (1.0 - percent).clamp(0.0, 1.0),
                          child: Text(
                            'IRIS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        background: Stack(
                          children: [
                            Positioned.fill(
                              child: Opacity(
                                opacity: (percent * 0.5).clamp(0.0, 0.5),
                                child: NeuralAura(
                                  background: isDark,
                                  tone: 'analytics',
                                ),
                              ),
                            ),
                            Center(
                              child: Opacity(
                                opacity: percent.clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: 0.8 + (percent * 0.2),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 20),
                                      Text(
                                        'IRIS',
                                        style: TextStyle(
                                          fontSize: 72,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -2,
                                          height: 0.9,
                                          foreground: Paint()
                                            ..shader = LinearGradient(
                                              colors: isDark 
                                                ? [Colors.white, Colors.white.withValues(alpha: 0.3)]
                                                : [IrisTokens.brand, IrisTokens.brand.withValues(alpha: 0.4)],
                                            ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                                        ),
                                      ),
                                      Text(
                                        'INTELLIGENCE',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 8,
                                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
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
                    },
                  ),
                ),
              ];
            },
            body: ScrollConfiguration(
              behavior: const SmoothScrollBehavior(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              children: [
                _buildIdentityCard(isDark),
                const SizedBox(height: 24),
                _buildSectionHeader('Account', Icons.person_rounded),
                const SizedBox(height: 12),
                  _buildSettingCard(
                    isDark: isDark,
                    icon: Icons.badge_rounded,
                    title: 'Display name',
                    subtitle: _userRole == 'faculty' ? 'Faculty identity is verified' : 'Change how your account name appears',
                    accent: IrisTokens.brand,
                    trailing: Opacity(
                      opacity: _userRole == 'faculty' ? 0.5 : 1.0,
                      child: Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: IrisTokens.brand,
                        ),
                      ),
                    ),
                    onTap: _editUserName,
                  ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  isDark: isDark,
                  icon: Icons.school_rounded,
                  title: 'Role',
                  subtitle: 'Switch between student and faculty mode',
                  accent: IrisTokens.purple,
                  trailing: Text(
                    _userRole.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: IrisTokens.purple,
                    ),
                  ),
                  onTap: _toggleRole,
                ),
                const SizedBox(height: 12),
                if (_userRole == 'student') ...[
                  _buildSettingCard(
                    isDark: isDark,
                    icon: Icons.batch_prediction_rounded,
                    title: 'Batch',
                    subtitle: 'Update your current program and semester',
                    accent: IrisTokens.success,
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: IrisTokens.success,
                    ),
                    onTap: _updateBatch,
                  ),
                ],
                const SizedBox(height: 24),
                _buildSectionHeader('Interface', Icons.tune_rounded),
                const SizedBox(height: 12),
                _buildSettingCard(
                  isDark: isDark,
                  icon: Icons.notifications_active_rounded,
                  title: 'Notifications',
                  subtitle: 'Persistent class notifications and reminders',
                  accent: IrisTokens.brand,
                  trailing: Switch.adaptive(
                    value: _notificationsEnabled,
                    onChanged: _togglePersistentNotification,
                    activeColor: IrisTokens.brand,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onTap: () => _togglePersistentNotification(!_notificationsEnabled),
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  isDark: isDark,
                  icon: Icons.widgets_rounded,
                  title: 'Widget',
                  subtitle: 'Open the setup guide and widget options',
                  accent: IrisTokens.purple,
                  trailing: TextButton(
                    onPressed: _showWidgetGuide,
                    child: const Text('Setup'),
                  ),
                  onTap: _showWidgetGuide,
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  isDark: isDark,
                  icon: Icons.dark_mode_rounded,
                  title: 'Widget dark mode',
                  subtitle: 'Keep the home widget aligned with dark layouts',
                  accent: IrisTokens.blue,
                  trailing: Switch.adaptive(
                    value: _widgetDarkMode,
                    onChanged: _toggleWidgetDarkMode,
                    activeColor: IrisTokens.brand,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onTap: () => _toggleWidgetDarkMode(!_widgetDarkMode),
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  isDark: isDark,
                  icon: Icons.vibration_rounded,
                  title: 'Haptics',
                  subtitle: 'System-wide touch feedback',
                  accent: IrisTokens.success,
                  trailing: Switch.adaptive(
                    value: _hapticsEnabled,
                    onChanged: (v) async {
                      await IrisHaptics.setEnabled(v);
                      setState(() => _hapticsEnabled = v);
                    },
                    activeColor: IrisTokens.brand,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  isDark: isDark,
                  icon: Icons.volume_up_rounded,
                  title: 'Audio',
                  subtitle: 'Interface sounds and taps',
                  accent: IrisTokens.warning,
                  trailing: Switch.adaptive(
                    value: _soundsEnabled,
                    onChanged: (v) async {
                      await IrisSfx.setEnabled(v);
                      setState(() => _soundsEnabled = v);
                    },
                    activeColor: IrisTokens.brand,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('System', Icons.settings_outlined),
                const SizedBox(height: 12),
                _buildOTAStatusCard(isDark),
                const SizedBox(height: 12),
                _buildChangelogButton(isDark),
                const SizedBox(height: 12),
                _buildSupportButton(isDark),
                const SizedBox(height: 40),
                Center(
                  child: Opacity(
                    opacity: 0.4,
                    child: Column(
                      children: [
                        Text(
                          'IRIS INTELLIGENCE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'V1.0.0 Stable Build',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black,
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
      ],
    ),
  );
}

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: IrisTokens.brand.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: IrisTokens.brand.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(bool isDark) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [IrisTokens.brand, IrisTokens.brandLight],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: IrisTokens.brand.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      _userRole == 'faculty' ? 'Faculty Member' : 'Student • $_batch',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildOTAStatusCard(bool isDark) {
    return GlassCard(
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
                      'Timetable OTA',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _otaStatus?['isUpToDate'] == true
                          ? 'Synchronized with Cloud'
                          : 'Update Available',
                      style: TextStyle(
                        fontSize: 12,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isRefreshing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(IrisTokens.brand),
                  ),
                )
              else
                GestureDetector(
                  onTap: _runOtaSync,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: IrisTokens.brand.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: IrisTokens.brand,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
          if (_otaStatus != null && _otaStatus!['hasCached'] == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: IrisTokens.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: IrisTokens.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: IrisTokens.success,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Auto-updates daily',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: IrisTokens.success,
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
            child: FilledButton.tonalIcon(
              onPressed: _runOtaSync,
              icon: const Icon(Icons.cloud_download_rounded),
              label: const Text('Sync timetable now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangelogButton(bool isDark) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: _showChangelog,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IrisTokens.brand.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: IrisTokens.brand,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Version History',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'v1.0.0+1 - Latest',
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: IrisTokens.brand.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportButton(bool isDark) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () async {
          try {
            final uri = Uri.parse(
              'mailto:malikaurangzaibahmed@gmail.com?subject=IRIS%20Support',
            );
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            IrisHaptics.actionSoft();
          } catch (e) {
            if (mounted) {
              showIrisFrostedSnackBar(
                context,
                dedupeKey: 'install_email_client_contact',
                content: const Text('Install an email client'),
                tint: IrisTokens.brand,
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IrisTokens.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: IrisTokens.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support & Feedback',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Get help or send feedback',
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: IrisTokens.purple.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangelogSheet extends StatelessWidget {
  const _ChangelogSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? IrisTokens.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Changelog',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Explore what\'s new in IRIS',
            style: TextStyle(
              fontSize: 14,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildVersion('v1.0.0+1', 'May 2024', [
                  'Liquid Glass visual modernization',
                  'Enhanced room finder with live occupancy',
                  'Persistent class notifications',
                  'Intelligent OTA timetable updates',
                  'System-wide haptic feedback',
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersion(String version, String date, List<String> changes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              version,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: IrisTokens.brand.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'LATEST',
                style: TextStyle(
                  color: IrisTokens.brand,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Spacer(),
            Text(
              date,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...changes.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: IrisTokens.brand, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(c, style: const TextStyle(fontSize: 14, height: 1.4))),
                ],
              ),
            )),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _WidgetStep extends StatelessWidget {
  final String number;
  final String text;

  const _WidgetStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: IrisTokens.brand,
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
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
