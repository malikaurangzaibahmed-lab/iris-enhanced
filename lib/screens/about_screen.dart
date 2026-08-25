import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/tokens.dart';
import '../core/models.dart';
import '../services/ui_feedback.dart';
import '../services/notification_service.dart';
import '../services/timetable_ota_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/batch_selector.dart';
import '../widgets/glowing_input_wrapper.dart';
import '../core/vital_theme.dart';
import '../core/vital_motion.dart';
import '../core/theme_signals.dart';
import '../core/device_performance.dart';
import '../widgets/iris_components.dart';
import '../widgets/vital_card.dart';
import '../widgets/glass_container_transform.dart';
import '../widgets/developer_card.dart';
import '../services/remote_config_service.dart';
import 'legal_screens.dart';
import 'feedback_screen.dart';

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
  bool _isLowEndDevice = false;

  final GlobalKey _privacyKey = GlobalKey();
  final GlobalKey _termsKey = GlobalKey();
  final GlobalKey _feedbackKey = GlobalKey();
  final GlobalKey _supportKey = GlobalKey();

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
    final isLowEnd = await DevicePerformance.isLowEndDevice();
    if (!mounted) return;
    setState(() {
      _isLowEndDevice = isLowEnd;
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
        content: IrisTextField(
          controller: controller,
          isDark: Theme.of(context).brightness == Brightness.dark,
          label: 'Name',
          hint: 'Enter name',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    pushGlassContainerMorphRoute(
      context,
      originKey: _privacyKey,
      page: PrivacyPolicyScreen(isDark: isDark),
      accentColor: const Color(0xFF8B5CF6),
    );
  }

  void _openTerms() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    pushGlassContainerMorphRoute(
      context,
      originKey: _termsKey,
      page: TermsOfServiceScreen(isDark: isDark),
      accentColor: IrisTokens.brand,
    );
  }

  void _openFeedback() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    pushGlassContainerMorphRoute(
      context,
      originKey: _feedbackKey,
      page: FeedbackScreen(isDark: isDark),
      accentColor: const Color(0xFF10B981),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          CustomScrollView(
            controller: _scrollController,
            physics: VitalMotion.scrollPhysics,
            slivers: [
              // Hero Profile Header with Multi-Ring Aura
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 72, 24, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                                  width: 1.0,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 18,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          Text(
                            'SETTINGS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Profile Avatar Container
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [VitalTokens.blue, VitalTokens.purple],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: VitalTokens.blue.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      // Name & Persona Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _userName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, size: 20),
                            color: VitalTokens.blue,
                            onPressed: _editUserName,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // Badges Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Role Badge
                          InkWell(
                            onTap: _toggleRole,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: VitalTokens.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: VitalTokens.blue.withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: VitalTokens.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _userRole.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: VitalTokens.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.sync_alt_rounded, size: 12, color: VitalTokens.blue),
                                ],
                              ),
                            ),
                          ),
                          if (_userRole == 'student') ...[
                            const SizedBox(width: 8),
                            // Batch Switcher Button
                            InkWell(
                              onTap: _updateBatch,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: VitalTokens.purple.withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: VitalTokens.purple.withValues(alpha: 0.3),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.school_rounded, size: 13, color: VitalTokens.purple),
                                    const SizedBox(width: 6),
                                    Text(
                                      'BATCH: ${_batch.toUpperCase()}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                        color: VitalTokens.purple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader('APPEARANCE & THEME'),
                    const SizedBox(height: 8),
                    _buildThemeCard(isDark),

                    const SizedBox(height: 24),
                    _buildSectionHeader('HYPER-SYNC & OTA ENGINE'),
                    const SizedBox(height: 8),
                    _buildOTACard(isDark),

                    const SizedBox(height: 24),
                    _buildSectionHeader('TACTILE & AUDIO ENGINE'),
                    const SizedBox(height: 8),
                    _buildPreferencesCard(isDark),

                    const SizedBox(height: 24),
                    _buildSectionHeader('APPLICATION VERSION & RELEASE'),
                    const SizedBox(height: 8),
                    _buildVersionCard(isDark),

                    const SizedBox(height: 24),
                    _buildSectionHeader('DEVELOPER'),
                    const SizedBox(height: 8),
                    _buildDeveloperCard(isDark),

                    const SizedBox(height: 24),
                    _buildSectionHeader('INFORMATION & LEGAL'),
                    const SizedBox(height: 8),
                    _buildInfoLinksCard(isDark),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(bool isDark) {
    final currentMode = widget.currentThemeMode ?? 'system';
    return VitalCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VitalTokens.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.palette_rounded, color: VitalTokens.purple, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance Mode', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Select dark, light, or system sync', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildThemeOption(isDark, 'system', 'SYSTEM', Icons.hdr_auto_rounded, currentMode),
              const SizedBox(width: 8),
              _buildThemeOption(isDark, 'dark', 'DARK', Icons.dark_mode_rounded, currentMode),
              const SizedBox(width: 8),
              _buildThemeOption(isDark, 'light', 'LIGHT', Icons.light_mode_rounded, currentMode),
            ],
          ),
          if (!_isLowEndDevice) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Eco Mode (High Performance)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Solid theme surfaces & zero shader overhead',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                IrisGlassSwitch(
                  value: ThemeSignals.useMinimalTheme.value,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) async {
                    IrisHaptics.selectionClick();
                    ThemeSignals.useMinimalTheme.value = val;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('use_minimal_ui', val);
                    setState(() {});
                    if (context.mounted) {
                      showIrisFrostedSnackBar(
                        context,
                        content: Text('Eco Mode: ${val ? "ENABLED" : "DISABLED"}'),
                        tint: val ? IrisTokens.success : IrisTokens.brand,
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _clearLocalStorageCaches,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.05 : 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restore_rounded, size: 16, color: isDark ? Colors.amber[300] : Colors.amber[800]),
                          const SizedBox(width: 6),
                          Text(
                            'Clear Caches',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      IrisHaptics.intelligencePulse();
                      showIrisFrostedSnackBar(context, content: const Text('Sensory engine pulse test sent.'));
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.05 : 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_rounded, size: 16, color: isDark ? Colors.cyan[300] : Colors.cyan[800]),
                          const SizedBox(width: 6),
                          Text(
                            'Diagnostics',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
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
        ],
      ),
    );
  }

  void _clearLocalStorageCaches() async {
    IrisHaptics.actionMedium();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('helpdesk_faculty_cache_v2');
    await prefs.remove('helpdesk_has_doc_draft');
    if (mounted) {
      showIrisFrostedSnackBar(
        context,
        content: const Text('Local caches & sync state cleared successfully!'),
        tint: VitalTokens.success,
      );
    }
  }

  Widget _buildThemeOption(bool isDark, String modeKey, String label, IconData icon, String currentMode) {
    final isSelected = currentMode == modeKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          IrisHaptics.chipSelect();
          widget.onSetThemeMode?.call(modeKey);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? VitalTokens.blue.withValues(alpha: isDark ? 0.25 : 0.15)
                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? VitalTokens.blue
                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? VitalTokens.blue : (isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? VitalTokens.blue : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
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
            key: _supportKey,
            title: "Contact Support",
            subtitle: "Get help from the developer team",
            icon: Icons.help_outline_rounded,
            onTap: _contactSupport,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildLinkRow(
            isDark,
            key: _privacyKey,
            title: "Privacy Policy",
            subtitle: "Read privacy guidelines",
            icon: Icons.security_rounded,
            onTap: _openPrivacy,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildLinkRow(
            isDark,
            key: _feedbackKey,
            title: "Send Feedback",
            subtitle: "Share thoughts or report issues",
            icon: Icons.rate_review_rounded,
            onTap: _openFeedback,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildLinkRow(
            isDark,
            key: _termsKey,
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
    Key? key,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
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

  void _downloadLatestApk() async {
    IrisHaptics.actionHeavy();
    final updateData = RemoteConfigService.latestApkUpdate.value;
    String downloadUrl = updateData?['download_url']?.toString() ?? '';

    if (downloadUrl.isEmpty) {
      downloadUrl = 'https://github.com/malikaurangzaibahmed-lab/iris-enhanced/releases';
    }

    final uri = Uri.parse(downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          content: const Text('Could not open download URL'),
          tint: Colors.redAccent,
        );
      }
    }
  }

  Widget _buildVersionCard(bool isDark) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: RemoteConfigService.latestApkUpdate,
      builder: (context, updateData, _) {
        final hasUpdate = updateData != null && updateData['download_url'] != null;
        final newVersionName = updateData?['version_name']?.toString() ?? '1.0.3';

        return GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: IrisTokens.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: IrisTokens.brand.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: IrisTokens.brand,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "IRIS v${RemoteConfigService.CURRENT_VERSION_NAME}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<String>(
                              valueListenable: RemoteConfigService.activeTrack,
                              builder: (context, track, _) {
                                final isBeta = track == 'beta';
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isBeta ? const Color(0xFF8B5CF6) : const Color(0xFF10B981))
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isBeta ? 'BETA' : 'STABLE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: isBeta ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Package: com.iris.app • Build ${RemoteConfigService.CURRENT_VERSION_CODE}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _downloadLatestApk,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        hasUpdate ? "Download v$newVersionName APK" : "Download Latest APK",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _downloadLatestApk,
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    tooltip: "Open Release Page",
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ],
              ),
            ],
          ),
        );
      },
     );
  }

  void _openUrl(String url) async {
    IrisHaptics.actionMedium();
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          content: Text('Could not open link: $url'),
          tint: VitalTokens.error,
        );
      }
    }
  }

  Widget _buildDeveloperCard(bool isDark) {
    return DeveloperCard(isDark: isDark);
  }
}
