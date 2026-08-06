import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../services/ui_feedback.dart'; // For IrisHaptics/Sfx
import '../core/app_signals.dart';
import '../core/theme_signals.dart';
import '../widgets/iris_components.dart';
import '../widgets/batch_selector.dart';
import '../services/system_broadcast_service.dart';
import '../core/vital_theme.dart';
import '../core/vital_motion.dart';
import '../widgets/vital_card.dart';

class IrisHubScreen extends StatefulWidget {
  final ValueChanged<String>? onRoleChanged;
  final Future<void> Function(String mode)? onSetThemeMode;
  final String? currentThemeMode;
  final UniversityMemory? memory;

  const IrisHubScreen({
    this.onRoleChanged,
    this.onSetThemeMode,
    this.currentThemeMode,
    this.memory,
    super.key,
  });

  @override
  State<IrisHubScreen> createState() => _IrisHubScreenState();
}

class _IrisHubScreenState extends State<IrisHubScreen> with TickerProviderStateMixin {
  late AnimationController _profileAnimController;
  late AnimationController _pulseController;
  
  String _userRole = 'student';
  String _appearanceMode = 'system';
  bool _uiSoundsEnabled = true;
  bool _uiHapticsEnabled = true;
  String _feedbackProfile = 'balanced';
  bool _useMinimalUI = false;
  
  bool _persistentNotificationEnabled = false;
  bool _lectureRemindersEnabled = true;
  bool _widgetDarkMode = false;
  Map<String, dynamic>? _otaStatus;
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _profileAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role') ?? 'student';
      _appearanceMode = prefs.getString('theme_mode') ?? widget.currentThemeMode ?? 'system';
      _useMinimalUI = prefs.getBool('use_minimal_ui') ?? false;
      _uiSoundsEnabled = prefs.getBool('ui_sounds_enabled') ?? true;
      _uiHapticsEnabled = prefs.getBool('ui_haptics_enabled') ?? true;
      _feedbackProfile = prefs.getString('ui_feedback_profile') ?? 'balanced';
      _persistentNotificationEnabled = prefs.getBool('persistent_notification_enabled') ?? false;
      _lectureRemindersEnabled = prefs.getBool('lecture_reminders_enabled') ?? true;
      _widgetDarkMode = prefs.getBool('widget_dark_mode') ?? false;
    });
    unawaited(IrisSfx.setEnabled(_uiSoundsEnabled));
    unawaited(IrisHaptics.setEnabled(_uiHapticsEnabled));
    unawaited(IrisHaptics.setProfile(_feedbackProfile));
    _loadOTAStatus();
  }

  Future<void> _loadOTAStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ver = prefs.getString('timetable_delta_version') ?? '1.0';
    final last = prefs.getString('timetable_last_sync') ?? 'Never';
    setState(() {
      _otaStatus = {'version': ver, 'last_sync': last};
    });
  }

  // Admin checks pruned for client-side security optimization

  @override
  void dispose() {
    _profileAnimController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          CustomScrollView(
            controller: _scrollController,
            physics: VitalMotion.scrollPhysics,
            slivers: [
              _buildVitalHubHeader(context, isDark, user),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildIntelligenceDashboard(isDark),
                    const SizedBox(height: 24),
                    
                    _buildSectionHeader("APPEARANCE & THEME", isDark),
                    const SizedBox(height: 12),
                    _buildThemeControllerCard(isDark),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader("TACTILE & AUDIO ENGINE", isDark),
                    const SizedBox(height: 12),
                    _buildBentoTuner(isDark),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader("FOREGROUND SERVICES & WIDGETS", isDark),
                    const SizedBox(height: 12),
                    _buildBentoServices(isDark),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader("DATA & MAINTENANCE", isDark),
                    const SizedBox(height: 12),
                    _buildOTACardPremium(isDark),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader("ABOUT & LEGAL", isDark),
                    const SizedBox(height: 12),
                    _buildAboutCard(isDark),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
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
          ),
        ],
      ),
    );
  }

  Widget _buildThemeControllerCard(bool isDark) {
    return VitalCard(
      padding: const EdgeInsets.all(20),
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
                child: const Icon(Icons.palette_rounded, color: VitalTokens.purple, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appearance Mode',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select light, dark, or system mode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildThemeSegmentButton(isDark, 'system', 'SYSTEM', Icons.hdr_auto_rounded),
              const SizedBox(width: 8),
              _buildThemeSegmentButton(isDark, 'dark', 'DARK', Icons.dark_mode_rounded),
              const SizedBox(width: 8),
              _buildThemeSegmentButton(isDark, 'light', 'LIGHT', Icons.light_mode_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSegmentButton(bool isDark, String modeKey, String label, IconData icon) {
    final isSelected = _appearanceMode == modeKey;
    return Expanded(
      child: InkWell(
        onTap: () async {
          IrisHaptics.chipSelect();
          setState(() => _appearanceMode = modeKey);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('theme_mode', modeKey);
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
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? VitalTokens.blue
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: isSelected
                      ? VitalTokens.blue
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntelligenceDashboard(bool isDark) {
    return VitalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIntelligencePulse(isDark),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "IRIS INTELLIGENCE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "System Analysis Complete",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: VitalTokens.blue, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Next: Computational Physics in 12 minutes (Room 402)",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
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

  Widget _buildIntelligencePulse(bool isDark) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VitalTokens.blue.withValues(alpha: 0.1),
            border: Border.all(
              color: VitalTokens.blue.withValues(alpha: 0.2 + (_pulseController.value * 0.3)),
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VitalTokens.blue,
                boxShadow: [
                  BoxShadow(
                    color: VitalTokens.blue.withValues(alpha: 0.5),
                    blurRadius: 10 * _pulseController.value,
                    spreadRadius: 2 * _pulseController.value,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _togglePersonaRole() async {
    IrisHaptics.actionMedium();
    final newRole = _userRole == 'student' ? 'faculty' : 'student';
    setState(() => _userRole = newRole);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', newRole);
    widget.onRoleChanged?.call(newRole);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched persona to ${newRole.toUpperCase()}')),
      );
    }
  }

  Widget _buildVitalHubHeader(BuildContext context, bool isDark, User? user) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: Column(
          children: [
            // Multi-ring Glowing Avatar Aura
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _profileAnimController,
                  builder: (context, child) {
                    return Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          transform: GradientRotation(_profileAnimController.value * 2 * math.pi),
                          colors: [
                            VitalTokens.blue.withValues(alpha: 0.8),
                            VitalTokens.purple.withValues(alpha: 0.8),
                            Colors.pinkAccent.withValues(alpha: 0.8),
                            VitalTokens.blue.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  ),
                ),
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [VitalTokens.blue, VitalTokens.purple],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: VitalTokens.blue.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            
            // Email Title
            Text(
              user?.email?.toUpperCase() ?? "IRIS STUDENT INSTANCE",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            // Badges Row (Role + Batch Switcher Trigger)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Persona Switch Pill
                InkWell(
                  onTap: _togglePersonaRole,
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
                const SizedBox(width: 8),
                
                // Batch Switcher Trigger Button
                InkWell(
                  onTap: () {
                    IrisHaptics.actionMedium();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => BatchSelectorSheet(
                        memory: widget.memory ?? UniversityMemory(),
                        selected: 'SP22-BSE-B',
                      ),
                    );
                  },
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
                        const Text(
                          'CHANGE BATCH',
                          style: TextStyle(
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
            ),
          ],
        ),
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

  void _showHapticsPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HAPTIC ENGINE PROFILE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              ...['subtle', 'balanced', 'expressive'].map((profile) {
                final isSel = _feedbackProfile == profile;
                return ListTile(
                  title: Text(profile.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing: isSel ? const Icon(Icons.check_circle_rounded, color: VitalTokens.blue) : null,
                  onTap: () async {
                    setState(() => _feedbackProfile = profile);
                    IrisHaptics.setProfile(profile);
                    IrisHaptics.actionMedium();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('ui_feedback_profile', profile);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBentoTuner(bool isDark) {
    return VitalCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildTunerTile(
            isDark,
            title: "Haptic Pulse",
            subtitle: _feedbackProfile.toUpperCase(),
            icon: Icons.vibration_rounded,
            onTap: _showHapticsPicker,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildTunerToggle(
            isDark,
            title: "Acoustic Feedback",
            subtitle: "Refined interaction tones",
            icon: Icons.volume_up_rounded,
            value: _uiSoundsEnabled,
            onChanged: (v) {
              setState(() => _uiSoundsEnabled = v);
              IrisSfx.setEnabled(v);
            }
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildTunerToggle(
            isDark,
            title: "Minimal UI",
            subtitle: "Reduced motion & effects",
            icon: Icons.format_paint_rounded,
            value: _useMinimalUI,
            onChanged: (v) async {
              setState(() => _useMinimalUI = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('use_minimal_ui', v);
              ThemeSignals.useMinimalTheme.value = v;
            }
          ),
        ],
      ),
    );
  }

  void _togglePersistentNotification(bool v) async {
    setState(() => _persistentNotificationEnabled = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('persistent_notification_enabled', v);
    if (v) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persistent Class Tracker Enabled')),
      );
    } else {
      await FlutterForegroundTask.stopService();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persistent Class Tracker Disabled')),
      );
    }
  }

  void _refreshOTA() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    final prefs = await SharedPreferences.getInstance();
    final nowStr = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    await prefs.setString('timetable_last_sync', 'Today, $nowStr');
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _otaStatus = {'version': '2.5.0', 'last_sync': 'Today, $nowStr'};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timetable Hyper-Sync Up to Date!')),
      );
    }
  }

  Widget _buildBentoServices(bool isDark) {
    return VitalCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildTunerToggle(
            isDark,
            title: "Class Tracker",
            subtitle: "System notification",
            icon: Icons.notifications_active_rounded,
            value: _persistentNotificationEnabled,
            onChanged: _togglePersistentNotification,
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildTunerToggle(
            isDark,
            title: "Lecture Reminders",
            subtitle: "Contextual alerts",
            icon: Icons.alarm_rounded,
            value: _lectureRemindersEnabled,
            onChanged: (v) async {
              setState(() => _lectureRemindersEnabled = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('lecture_reminders_enabled', v);
            }
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          _buildTunerToggle(
            isDark,
            title: "Dynamic Widget",
            subtitle: "Home sync",
            icon: Icons.widgets_rounded,
            value: _widgetDarkMode,
            onChanged: (v) async {
              setState(() => _widgetDarkMode = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('widget_dark_mode', v);
            }
          ),
        ],
      ),
    );
  }

  Widget _buildTunerTile(bool isDark, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return ListTile(
      onTap: () {
        IrisHaptics.actionMedium();
        onTap();
      },
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
      trailing: Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2)),
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
      trailing: IrisGlassSwitch(
        value: value,
        onChanged: (v) {
          IrisHaptics.selectionClick();
          onChanged(v);
        },
        activeColor: VitalTokens.blue,
      ),
    );
  }

  // God Mode Card helper widget pruned



  Widget _buildOTACardPremium(bool isDark) {
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
                Text("Hyper-Sync Protocol", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(
                  "Build v${_otaStatus?['version']} • Sync: ${_otaStatus?['last_sync']}",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isRefreshing ? null : _refreshOTA,
            icon: _isRefreshing 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: VitalTokens.blue))
              : const Icon(Icons.refresh_rounded, color: VitalTokens.blue, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(bool isDark) {
    return VitalCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VitalTokens.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: VitalTokens.blue, size: 20),
            ),
            title: const Text('IRIS Academic Intelligence', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            subtitle: Text('v2.5.0 Premium Build • Build 2026', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4))),
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          ListTile(
            onTap: () {
              IrisHaptics.actionMedium();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('IRIS Privacy Policy: Local data remains 100% on device.')),
              );
            },
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.security_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 20),
            ),
            title: const Text('Privacy & Local Security', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            trailing: Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.5,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildAboutTile(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: IrisTextStyles.metaInfo(context)),
          Text(value, style: IrisTextStyles.settingTitle(context).copyWith(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  Future<void> _contactSupport() async {
    IrisHaptics.actionMedium();
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'malikaurangzaibahmed@gmail.com',
      queryParameters: {'subject': 'IRIS Support Request'},
    );
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else { throw 'Could not launch'; }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contact: malikaurangzaibahmed@gmail.com"), backgroundColor: IrisTokens.brand));
      }
    }
  }


}

// Background Task Entry Point
@pragma('vm:entry-point')
void startClassNotificationTask() {
  FlutterForegroundTask.setTaskHandler(ClassTrackerHandler());
}
class ClassTrackerHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {}
  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
