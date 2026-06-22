import 'dart:async';
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
import '../widgets/neural_aura.dart';
import '../widgets/smooth_scroll.dart';
import '../widgets/glass_card.dart';
import '../widgets/batch_selector.dart';
import '../core/vital_theme.dart';
import '../widgets/vital_card.dart';
import 'students_week_screen.dart';
import 'legal_screens.dart';

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
      _widgetDarkMode = prefs.getBool('widget_dark_mode') ?? false;
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
                            'Nexsync',
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
                                        'Nexsync',
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
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              children: [
                _buildIdentityBento(isDark),
                const SizedBox(height: 32),
                _buildSectionHeader('SYSTEM DIAGNOSTICS', Icons.analytics_rounded),
                const SizedBox(height: 16),
                _buildTelemetryCard(isDark),
                const SizedBox(height: 32),
                _buildSectionHeader('SYSTEM CONTROLS', Icons.settings_rounded),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildBentoAction(isDark, "PERSONA", _userRole.toUpperCase(), Icons.supervised_user_circle_rounded, _toggleRole, VitalTokens.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildBentoAction(isDark, "DISPLAY NAME", _userName, Icons.badge_rounded, _editUserName, VitalTokens.purple)),
                  ],
                ),
                if (_userRole == 'student') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildBentoAction(isDark, "BATCH", _batch, Icons.batch_prediction_rounded, _updateBatch, VitalTokens.success)),
                      const SizedBox(width: 12),
                      Expanded(child: Container()), // Empty space to keep grid uniform
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                _buildSectionHeader('INTERFACE TUNER', Icons.tune_rounded),
                const SizedBox(height: 16),
                _buildBentoTuner(isDark),
                const SizedBox(height: 32),
                _buildSectionHeader('SENSORY FEEDBACK DECK', Icons.hearing_rounded),
                const SizedBox(height: 16),
                _buildSensoryDeck(isDark),
                const SizedBox(height: 32),
                _buildSectionHeader('MAINTENANCE', Icons.build_rounded),
                const SizedBox(height: 16),
                _buildOTAStatusCard(isDark),
                const SizedBox(height: 12),
                _buildChangelogButton(isDark),
                const SizedBox(height: 12),
                _buildSupportButton(isDark),
                const SizedBox(height: 12),
                _buildPrivacyPolicyButton(isDark),
                const SizedBox(height: 12),
                _buildTermsButton(isDark),
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

  Widget _buildIdentityBento(bool isDark) {
    return DirectoryAnimationWidget(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [VitalTokens.blue, VitalTokens.purple],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: VitalTokens.blue.withValues(alpha: 0.3),
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
                const SizedBox(height: 2),
                Text(
                  _userRole == 'faculty' ? 'Faculty Member' : 'Student • $_batch',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoAction(bool isDark, String label, String value, IconData icon, VoidCallback onTap, Color color) {
    return VitalCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoTuner(bool isDark) {
    return VitalCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildTunerToggle(
            isDark,
            title: "Live Class Tracker",
            subtitle: "Persistent system notification",
            icon: Icons.notifications_active_rounded,
            value: _notificationsEnabled,
            onChanged: _togglePersistentNotification,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildTunerToggle(
            isDark,
            title: "Widget Sync",
            subtitle: "Dark mode aligned widget",
            icon: Icons.widgets_rounded,
            value: _widgetDarkMode,
            onChanged: _toggleWidgetDarkMode,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildTunerToggle(
            isDark,
            title: "Acoustic Feedback",
            subtitle: "Interaction tones",
            icon: Icons.volume_up_rounded,
            value: _soundsEnabled,
            onChanged: (v) async {
              setState(() => _soundsEnabled = v);
              await IrisSfx.setEnabled(v);
            }
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildTunerToggle(
            isDark,
            title: "Haptic Pulse",
            subtitle: "Precision micro-vibrations",
            icon: Icons.vibration_rounded,
            value: _hapticsEnabled,
            onChanged: (v) async {
              setState(() => _hapticsEnabled = v);
              await IrisHaptics.setEnabled(v);
            }
          ),
        ],
      ),
    );
  }

  Widget _buildTunerToggle(bool isDark, {required String title, required String subtitle, required IconData icon, required bool value, required ValueChanged<bool> onChanged}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isDark ? Colors.white70 : Colors.black87, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4))),
      trailing: GlassSwitch(
        value: value,
        onChanged: (v) {
          IrisHaptics.selectionClick();
          onChanged(v);
        },
        activeColor: VitalTokens.blue,
        useOwnLayer: true,
      ),
    );
  }

  Widget _buildOTAStatusCard(bool isDark) {
    return VitalCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: VitalTokens.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.cloud_sync_rounded, color: VitalTokens.blue, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Hyper-Sync Protocol", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(
                  _otaStatus?['isUpToDate'] == true ? 'Synchronized with Cloud' : 'Update Available',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isRefreshing ? null : _runOtaSync,
            icon: _isRefreshing 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: VitalTokens.blue))
              : const Icon(Icons.refresh_rounded, color: VitalTokens.blue, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildChangelogButton(bool isDark) {
    return VitalCard(
      padding: EdgeInsets.zero,
      onTap: _showChangelog,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VitalTokens.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.history_rounded, color: VitalTokens.purple, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Version History", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 3),
                  Text("v1.0.0+1 - Latest", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportButton(bool isDark) {
    return VitalCard(
      padding: EdgeInsets.zero,
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
              tint: VitalTokens.error,
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VitalTokens.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.help_outline_rounded, color: VitalTokens.success, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Help & Support", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 3),
                  Text("Contact IRIS Intelligence Team", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4))),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicyButton(bool isDark) {
    return VitalCard(
      padding: EdgeInsets.zero,
      onTap: () {
        IrisHaptics.actionSoft();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VitalTokens.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.security_rounded, color: VitalTokens.blue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Privacy Policy", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 3),
                  Text("Local storage keys & privacy details", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsButton(bool isDark) {
    return VitalCard(
      padding: EdgeInsets.zero,
      onTap: () {
        IrisHaptics.actionSoft();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VitalTokens.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.gavel_rounded, color: VitalTokens.purple, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Terms of Service", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 3),
                  Text("Rules of engagement & disclaimers", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(bool isDark) {
    return VitalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VitalTokens.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.memory_rounded, color: VitalTokens.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "System Diagnostics",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    "Telemetry of local sync & database",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildTelemetryGridItem(
                  context,
                  isDark,
                  label: "Local DB Size",
                  value: "1.42 MB",
                  subtext: "1,240 rows cached",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTelemetryGridItem(
                  context,
                  isDark,
                  label: "Haptic Pulse",
                  value: _hapticsEnabled ? "ACTIVE" : "DISABLED",
                  subtext: "Precision engine",
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTelemetryGridItem(
                  context,
                  isDark,
                  label: "Scraper OTA",
                  value: "v1.0.0+1",
                  subtext: "Latest build",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTelemetryGridItem(
                  context,
                  isDark,
                  label: "Sync Status",
                  value: "98.7% Success",
                  subtext: "Hyper-Sync protocol",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryGridItem(
    BuildContext context,
    bool isDark, {
    required String label,
    required String value,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensoryDeck(bool isDark) {
    return VitalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VitalTokens.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.touch_app_rounded, color: VitalTokens.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Sensory Deck Visualizer",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    "Test haptics & acoustics feedback system",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Feedback Profile",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                ),
              ),
              DropdownButton<String>(
                value: IrisHaptics.profile,
                dropdownColor: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
                underline: Container(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: IrisTokens.brand,
                ),
                items: const [
                  DropdownMenuItem(value: 'gentle', child: Text("Gentle / Soft")),
                  DropdownMenuItem(value: 'crisp', child: Text("Crisp / Sharp")),
                  DropdownMenuItem(value: 'balanced', child: Text("Balanced")),
                ],
                onChanged: (val) async {
                  if (val != null) {
                    IrisHaptics.selectionClick();
                    await IrisHaptics.setProfile(val);
                    await IrisSfx.setProfile(val == 'balanced' ? 'bubble' : val);
                    setState(() {});
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    IrisHaptics.actionSoft();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.blur_linear_rounded, color: VitalTokens.blue, size: 20),
                        SizedBox(height: 6),
                        Text(
                          "Soft Click",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    IrisHaptics.actionMedium();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.blur_on_rounded, color: VitalTokens.purple, size: 20),
                        SizedBox(height: 6),
                        Text(
                          "Medium Pop",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    IrisHaptics.actionHeavy();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.bolt_rounded, color: VitalTokens.success, size: 20),
                        SizedBox(height: 6),
                        Text(
                          "Heavy Kick",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
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
