import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassCard;
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
import '../widgets/smooth_scroll.dart';
import '../widgets/glass_card.dart';
import '../widgets/batch_selector.dart';
import '../core/vital_theme.dart';
import '../widgets/iris_components.dart';
import '../widgets/vital_card.dart';
import 'legal_screens.dart';

class AboutScreen extends StatefulWidget {
  final UniversityMemory memory;
  final ValueChanged<String>? onUserNameChanged;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;
  final ScrollController? scrollController;
  final VoidCallback? onToggleTheme;
  final String? currentThemeMode;
  final Future<void> Function(String)? onSetThemeMode;

  const AboutScreen({
    required this.memory,
    this.onUserNameChanged,
    this.onRoleChanged,
    this.onBatchChanged,
    this.scrollController,
    this.onToggleTheme,
    this.currentThemeMode,
    this.onSetThemeMode,
    super.key,
  });

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final ScrollController _scrollController;
  bool _isRefreshing = false;
  Map<String, dynamic>? _otaStatus;
  String _userName = 'Student';
  String _batch = '...';
  String _userRole = 'student';
  bool _notificationsEnabled = true;
  bool _hapticsEnabled = true;
  bool _soundsEnabled = true;
  bool _widgetDarkMode = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _loadSettings();
    _refreshOTA();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role') ?? 'student';
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
    });
  }

  Future<void> _refreshOTA() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final status = await TimetableOTAService.getUpdateStatus();
      if (mounted) {
        setState(() => _otaStatus = status);
      }
    } catch (e) {
      debugPrint('OTA Status check failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _runOtaSync() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    IrisHaptics.actionMedium();
    try {
      final result = await TimetableOTAService.forceRefresh();
      final status = await TimetableOTAService.getUpdateStatus();
      if (mounted) {
        setState(() => _otaStatus = status);
        showIrisFrostedSnackBar(
          context,
          dedupeKey: 'ota_sync_info',
          content: Text(
            result == 1
                ? 'Timetable updated'
                : result == 0
                    ? 'Timetable already up to date'
                    : 'OTA sync failed',
          ),
          tint: result == 1 ? VitalTokens.success : IrisTokens.brand,
        );
      }
    } catch (e) {
      debugPrint('OTA sync failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
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
          const NotificationButton(id: 'open', text: 'Open IRIS'),
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
          const NotificationButton(id: 'open', text: 'Open IRIS'),
        ],
        callback: startClassNotificationTask,
      );
    }
  }

  Future<void> _toggleWidgetDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widget_dark_mode', enabled);
    setState(() {
      _widgetDarkMode = enabled;
    });
    await WidgetService.setWidgetDarkMode(enabled);
  }

  void _toggleRole() {
    if (widget.onRoleChanged == null) return;
    final nextRole = _userRole == 'student' ? 'faculty' : 'student';
    IrisHaptics.actionHeavy();
    widget.onRoleChanged!(nextRole);
    _loadSettings();
  }

  void _editUserName() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Profile Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                if (_userRole == 'faculty') {
                  await prefs.setString('faculty_user_name', newName);
                } else {
                  await prefs.setString('student_user_name', newName);
                }
                if (widget.onUserNameChanged != null) {
                  widget.onUserNameChanged!(newName);
                }
                setState(() => _userName = newName);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _updateBatch() {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BatchSelectorSheet(
        memory: widget.memory,
        selected: _batch,
      ),
    ).then((newBatch) async {
      if (newBatch != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_batch', newBatch);
        if (widget.onBatchChanged != null) {
          widget.onBatchChanged!(newBatch);
        }
        setState(() {
          _batch = newBatch;
        });
      }
    });
  }

  void _showChangelog() {
    IrisHaptics.actionSoft();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Version History'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('v1.0.0+1 - Latest Release', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Overhauled Room Finder with interactive timelines.'),
            Text('• Dynamic Onboarding Wizard integration.'),
            Text('• Performance optimizations & cache layer fixes.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _contactSupport() async {
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
          tint: VitalTokens.error,
        );
      }
    }
  }

  void _openPrivacy() {
    IrisHaptics.actionSoft();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _openTerms() {
    IrisHaptics.actionSoft();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
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
                  expandedHeight: 180,
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
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    titlePadding: const EdgeInsets.only(bottom: 16),
                    title: Text(
                      'SETTINGS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    background: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 48),
                            Icon(
                              Icons.settings_suggest_rounded,
                              size: 40,
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: ScrollConfiguration(
              behavior: const SmoothScrollBehavior(),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  // 1. Account & Profile Info Card
                  _buildSectionHeader('PROFILE ACCOUNT'),
                  const SizedBox(height: 8),
                  _buildProfileCard(isDark),

                  const SizedBox(height: 24),

                  // 2. Synchronizations Card
                  _buildSectionHeader('CLOUD SYNCHRONIZATIONS'),
                  const SizedBox(height: 8),
                  _buildOTACard(isDark),

                  const SizedBox(height: 24),

                  // 3. Tuner Preferences Switches
                  _buildSectionHeader('PREFERENCES TUNING'),
                  const SizedBox(height: 8),
                  _buildPreferencesCard(isDark),

                  const SizedBox(height: 24),

                  // 4. Reference Legal Links Card
                  _buildSectionHeader('INFORMATION & SUPPORT'),
                  const SizedBox(height: 8),
                  _buildInfoLinksCard(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildProfileCard(bool isDark) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: IrisTokens.brand.withValues(alpha: 0.1),
              child: const Icon(Icons.person_rounded, color: IrisTokens.brand, size: 24),
            ),
            title: Text(
              _userName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _userRole == 'faculty' ? 'FACULTY MEMBER' : 'STUDENT PROFILE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
              ),
            ),
            trailing: Icon(
              Icons.edit_note_rounded,
              color: isDark ? Colors.white30 : Colors.black38,
            ),
            onTap: _editUserName,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Icon(
              Icons.supervised_user_circle_rounded,
              color: isDark ? Colors.white54 : Colors.black54,
              size: 20,
            ),
            title: const Text('Persona Role', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _userRole == 'faculty' ? 'Faculty' : 'Student',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: IrisTokens.brand,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.swap_horiz_rounded, size: 18),
              ],
            ),
            onTap: _toggleRole,
          ),
          if (_userRole == 'student') ...[
            Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Icon(
                Icons.badge_rounded,
                color: isDark ? Colors.white54 : Colors.black54,
                size: 20,
              ),
              title: const Text('Batch Code', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _batch,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                ],
              ),
              onTap: _updateBatch,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOTACard(bool isDark) {
    final isUpToDate = _otaStatus?['isUpToDate'] == true;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: 24,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.cloud_sync_rounded, color: IrisTokens.brand, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Hyper-Sync Protocol",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  isUpToDate ? 'Synchronized with Cloud' : 'Update Available',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isRefreshing ? null : _runOtaSync,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: IrisTokens.brand),
                  )
                : const Icon(Icons.refresh_rounded, color: IrisTokens.brand, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(bool isDark) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: Column(
        children: [
          _buildToggleRow(
            isDark,
            title: "Dark Interface",
            subtitle: "Force dark glass themes",
            icon: Icons.dark_mode_rounded,
            value: widget.currentThemeMode == 'dark' || (widget.currentThemeMode != 'light' && isDark),
            onChanged: (v) {
              if (widget.onSetThemeMode != null) {
                widget.onSetThemeMode!(v ? 'dark' : 'light');
              } else if (widget.onToggleTheme != null) {
                widget.onToggleTheme!();
              }
            },
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildToggleRow(
            isDark,
            title: "Live Class Tracker",
            subtitle: "Persistent system notification",
            icon: Icons.notifications_active_rounded,
            value: _notificationsEnabled,
            onChanged: _togglePersistentNotification,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildToggleRow(
            isDark,
            title: "Widget Sync",
            subtitle: "Dark mode aligned widget",
            icon: Icons.widgets_rounded,
            value: _widgetDarkMode,
            onChanged: _toggleWidgetDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(
        icon,
        color: isDark ? Colors.white54 : Colors.black54,
        size: 20,
      ),
      title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
        ),
      ),
      trailing: IrisGlassSwitch(
        value: value,
        onChanged: (v) {
          IrisHaptics.selectionClick();
          onChanged(v);
        },
        activeColor: IrisTokens.brand,
      ),
    );
  }

  Widget _buildInfoLinksCard(bool isDark) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: Column(
        children: [
          _buildLinkRow(
            isDark,
            title: "Version History",
            subtitle: "Check changelogs and updates",
            icon: Icons.history_rounded,
            onTap: _showChangelog,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildLinkRow(
            isDark,
            title: "Contact Support",
            subtitle: "Get help from the developer team",
            icon: Icons.help_outline_rounded,
            onTap: _contactSupport,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildLinkRow(
            isDark,
            title: "Privacy Policy",
            subtitle: "Read privacy guidelines",
            icon: Icons.security_rounded,
            onTap: _openPrivacy,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildLinkRow(
            isDark,
            title: "Terms of Service",
            subtitle: "Read application terms",
            icon: Icons.gavel_rounded,
            onTap: _openTerms,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkRow(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(
        icon,
        color: isDark ? Colors.white54 : Colors.black54,
        size: 20,
      ),
      title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 12,
        color: isDark ? Colors.white30 : Colors.black38,
      ),
      onTap: onTap,
    );
  }
}
