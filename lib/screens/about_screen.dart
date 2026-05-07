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
import '../services/timetable_ota_service.dart';
import '../widget_service.dart';
import '../widgets/neural_aura.dart';
import '../widgets/smooth_scroll.dart';
import '../widgets/glass_card.dart';
import '../widgets/batch_selector.dart';
import '../widgets/dashboard_dock.dart';
import '../portal_screen.dart';

class AboutScreen extends StatefulWidget {
  final UniversityMemory memory;
  const AboutScreen({required this.memory, super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  Map<String, dynamic>? _otaStatus;
  String _batch = '...';
  String _userRole = 'student';
  bool _notificationsEnabled = true;
  bool _hapticsEnabled = true;
  bool _soundsEnabled = true;
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
      _batch = prefs.getString('user_batch') ?? 'UNKNOWN';
      _userRole = prefs.getString('user_role') ?? 'student';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _hapticsEnabled = prefs.getBool('ui_haptics_enabled') ?? true;
      _soundsEnabled = prefs.getBool('ui_sounds_enabled') ?? true;
      _feedbackProfile = prefs.getString('ui_feedback_profile') ?? 'gentle';
    });
  }

  Future<void> _refreshOTA() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final status = await TimetableOTAService.checkUpdates(widget.memory);
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

  Future<void> _toggleRole() async {
    final newRole = _userRole == 'student' ? 'teacher' : 'student';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', newRole);
    setState(() => _userRole = newRole);
    IrisHaptics.actionMedium();
  }

  Future<void> _togglePersistentNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);

    if (value) {
      // Logic to start foreground task - usually in main.dart
      // For now we assume the native side handles the toggle via prefs
    } else {
      await FlutterForegroundTask.stopService();
    }
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
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          NeuralAura(background: isDark),
          ScrollConfiguration(
            behavior: const SmoothScrollBehavior(),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 110, 20, 120),
              children: [
                _buildIdentityCard(isDark),
                const SizedBox(height: 24),
                _buildSectionHeader('Preferences', Icons.tune_rounded),
                const SizedBox(height: 12),
                _buildPreferencesGrid(isDark),
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
                      _userRole == 'teacher' ? 'Faculty Member' : 'Student',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      _batch,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _updateBatch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: IrisTokens.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: IrisTokens.brand,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          const SizedBox(height: 12),
          _buildIdentityToggle(
            'Role',
            _userRole.toUpperCase(),
            Icons.school_rounded,
            onTap: _toggleRole,
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityToggle(String label, String value, IconData icon, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: IrisTokens.brand,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.sync_rounded, size: 14, color: IrisTokens.brand),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _buildPreferenceTile(
          'Notifications',
          'Persistent',
          Icons.notifications_active_rounded,
          _notificationsEnabled,
          (v) => _togglePersistentNotification(v),
        ),
        _buildPreferenceTile(
          'Haptics',
          'System-wide',
          Icons.vibration_rounded,
          _hapticsEnabled,
          (v) async {
            await IrisHaptics.setEnabled(v);
            setState(() => _hapticsEnabled = v);
          },
        ),
        _buildPreferenceTile(
          'Audio',
          'UI Sounds',
          Icons.volume_up_rounded,
          _soundsEnabled,
          (v) async {
            await IrisSfx.setEnabled(v);
            setState(() => _soundsEnabled = v);
          },
        ),
        _buildPreferenceTile(
          'Portal',
          'Sync State',
          Icons.cloud_sync_rounded,
          true,
          (v) => Navigator.push(context, MaterialPageRoute(builder: (c) => const PortalScreen())),
          isLink: true,
        ),
      ],
    );
  }

  Widget _buildPreferenceTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    bool isLink = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: IrisTokens.brand),
              const Spacer(),
              if (isLink)
                const Icon(Icons.arrow_forward_rounded, size: 16, color: IrisTokens.brand)
              else
                SizedBox(
                  height: 20,
                  width: 32,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    activeTrackColor: IrisTokens.brand,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
            ),
          ),
        ],
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
                  onTap: _refreshOTA,
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
              style: const TextStyle(fontSize: 12, opacity: 0.4),
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
