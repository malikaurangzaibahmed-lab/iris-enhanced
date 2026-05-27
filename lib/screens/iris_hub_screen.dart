import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart'; // For IrisHaptics/Sfx
import '../core/app_signals.dart';
import '../core/theme_signals.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../widgets/native_liquid_glass.dart';
import 'login_screen.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';
import '../services/system_broadcast_service.dart';
import '../core/animations.dart';
import '../core/glass.dart';
import '../core/vital_theme.dart';
import '../core/vital_motion.dart';
import '../widgets/vital_card.dart';

class IrisHubScreen extends StatefulWidget {
  final ValueChanged<String>? onRoleChanged;
  final Future<void> Function(String mode)? onSetThemeMode;
  final String? currentThemeMode;

  const IrisHubScreen({
    this.onRoleChanged,
    this.onSetThemeMode,
    this.currentThemeMode,
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
                    const SizedBox(height: 32),
                    _buildSectionHeader("SYSTEM CONTROLS", isDark),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildBentoAction(isDark, "PERSONA", _userRole.toUpperCase(), Icons.supervised_user_circle_rounded, _showRolePicker, VitalTokens.blue)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildBentoAction(isDark, "THEME", _appearanceMode.toUpperCase(), Icons.palette_rounded, _showThemePicker, VitalTokens.purple)),
                      ],
                    ),
                  
                    const SizedBox(height: 16),
                    _buildBentoTuner(isDark),
                    const SizedBox(height: 32),
                    _buildSectionHeader("SERVICE ENGINE", isDark),
                    const SizedBox(height: 16),
                    _buildBentoServices(isDark),
                  
                    const SizedBox(height: 32),
                    _buildSectionHeader("MAINTENANCE", isDark),
                    const SizedBox(height: 16),
                    _buildOTACardPremium(isDark),
                    const SizedBox(height: 48),
                    _buildLogoutButton(user),
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
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

  Widget _buildVitalHubHeader(BuildContext context, bool isDark, User? user) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _profileAnimController,
                  builder: (context, child) {
                    return Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          width: 2,
                        ),
                      ),
                      child: CircularProgressIndicator(
                        value: _profileAnimController.value,
                        strokeWidth: 2,
                        color: VitalTokens.blue.withValues(alpha: 0.2),
                      ),
                    );
                  },
                ),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [VitalTokens.blue, VitalTokens.purple],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: VitalTokens.blue.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              user?.email?.toUpperCase() ?? "GUEST INSTANCE",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: VitalTokens.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: VitalTokens.blue.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _userRole.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: VitalTokens.blue,
                ),
              ),
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
      trailing: Switch.adaptive(
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

  Widget _buildLogoutButton(User? user) {
    final color = user == null ? VitalTokens.blue : VitalTokens.error;
    return VitalCard(
      onTap: user == null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())) : _handleLogout,
      backgroundColor: color.withValues(alpha: 0.1),
      border: Border.all(color: color.withValues(alpha: 0.2)),
      child: Center(
        child: Text(
          user == null ? "VERIFY IDENTITY" : "TERMINATE SESSION",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: color,
          ),
        ),
      ),
    );
  }

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

  void _showHapticsPicker() {
    IrisHaptics.actionMedium();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LiquidGlass(
        settings: IrisGlass.settings(
          context,
          blur: 25,
          ambientStrength: 0.7,
          lightAngle: 0.2 * 3.14,
          thickness: 30,
          glassColor:
              (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(0.6),
          minBlur: 12,
          minThickness: 20,
        ),
        shape: IrisGlass.shape(32),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("HAPTIC PROTOCOL", style: IrisTextStyles.overline(context).copyWith(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: isDark?Colors.white38:Colors.black38)),
              const SizedBox(height: 24),
              _buildPickerOption(isDark, "Gentle Pulse", "Precision micro-vibrations", _feedbackProfile == "gentle", () => _setFeedbackProfile("gentle")),
              _buildPickerOption(isDark, "Balanced", "Standard haptic fidelity", _feedbackProfile == "balanced", () => _setFeedbackProfile("balanced")),
              _buildPickerOption(isDark, "Crisp Impact", "Tactile assurance feedback", _feedbackProfile == "crisp", () => _setFeedbackProfile("crisp")),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemePicker() {
    IrisHaptics.actionMedium();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LiquidGlass(
        settings: IrisGlass.settings(
          context,
          blur: 25,
          ambientStrength: 0.7,
          lightAngle: 0.2 * 3.14,
          thickness: 30,
          glassColor:
              (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(0.6),
          minBlur: 12,
          minThickness: 20,
        ),
        shape: IrisGlass.shape(32),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("APPEARANCE MODE", style: IrisTextStyles.overline(context).copyWith(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: isDark?Colors.white38:Colors.black38)),
              const SizedBox(height: 24),
              _buildPickerOption(isDark, "Dynamic OS", "Universal system sync", _appearanceMode == "system", () => _setAppearanceMode("system")),
              _buildPickerOption(isDark, "Liquid Light", "High-contrast day mode", _appearanceMode == "light", () => _setAppearanceMode("light")),
              _buildPickerOption(isDark, "Midnight Glass", "Pure obsidian dark mode", _appearanceMode == "dark", () => _setAppearanceMode("dark")),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showRolePicker() {
    IrisHaptics.actionMedium();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: ThemeSignals.useMinimalTheme,
        builder: (context, useMinimal, _) {
          final content = Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(useMinimal ? 0.04 : 0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "APPLICATION PERSONA",
                  style: IrisTextStyles.overline(context).copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useColumn = constraints.maxWidth < 420;
                    final student = _buildRoleToggle(
                      isDark,
                      title: 'Student',
                      subtitle: 'Timetable, batch sync, class tracking',
                      icon: Icons.school_rounded,
                      accent: IrisTokens.brand,
                      selected: _userRole == 'student',
                      onTap: () => _applyRoleAndDismiss('student'),
                    );
                    final faculty = _buildRoleToggle(
                      isDark,
                      title: 'Faculty',
                      subtitle: 'Faculty portal and teaching tools',
                      icon: Icons.badge_rounded,
                      accent: IrisTokens.blue,
                      selected: _userRole == 'faculty',
                      onTap: () => _applyRoleAndDismiss('faculty'),
                    );

                    if (useColumn) {
                      return Column(
                        children: [
                          student,
                          const SizedBox(height: 12),
                          faculty,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: student),
                        const SizedBox(width: 12),
                        Expanded(child: faculty),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );

          if (useMinimal) return content;

          // Legacy: wrap in LiquidGlass for the glass effect
          return LiquidGlass(
            settings: IrisGlass.settings(
              context,
              blur: 25,
              ambientStrength: 0.7,
              lightAngle: 0.2 * 3.14,
              thickness: 30,
              glassColor:
                  (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(0.6),
              minBlur: 12,
              minThickness: 20,
            ),
            shape: IrisGlass.shape(32),
            child: content,
          );
        },
      ),
    );
  }

  Widget _buildRoleToggle(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? accent.withOpacity(0.35)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(selected ? 1.0 : 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: IrisTextStyles.settingTitle(context).copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.toggle_on_rounded
                              : Icons.toggle_off_rounded,
                          color: selected
                              ? accent
                              : (isDark ? Colors.white38 : Colors.black38),
                          size: 30,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: IrisTextStyles.settingSubtitle(context),
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

  Widget _buildPickerOption(
    bool isDark,
    String title,
    String subtitle,
    bool selected,
    VoidCallback onTap,
  ) {
    final activeColor = IrisTokens.brand;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          IrisHaptics.actionMedium();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withOpacity(0.08)
                : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? activeColor.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: IrisTextStyles.settingTitle(context).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: IrisTextStyles.settingSubtitle(context).copyWith(
                        fontSize: 13,
                        color: selected
                            ? (isDark ? Colors.white54 : Colors.black54)
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? activeColor : (isDark ? Colors.white30 : Colors.black.withOpacity(0.3)),
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeColor,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _setUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    setState(() => _userRole = role);
    AppSignals.roleNotifier.value = role;
    if (widget.onRoleChanged != null) {
      widget.onRoleChanged!(role);
    }
    IrisHaptics.refreshSuccess();
  }

  Future<void> _applyRoleAndDismiss(String role) async {
    await _setUserRole(role);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _setFeedbackProfile(String profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ui_feedback_profile', profile);
    setState(() => _feedbackProfile = profile);
    IrisHaptics.setProfile(profile);
    IrisHaptics.actionHeavy();
  }

  Future<void> _setAppearanceMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _appearanceMode = mode);
    await prefs.setString('theme_mode', mode);
    if (widget.onSetThemeMode != null) {
      await widget.onSetThemeMode!(mode);
    }
  }

  Future<void> _togglePersistentNotification(bool v) async {
    setState(() => _persistentNotificationEnabled = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('persistent_notification_enabled', v);
    if (v) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'IRIS Class Tracker',
        notificationText: 'Initializing...',
        callback: startClassNotificationTask,
      );
    } else {
      await FlutterForegroundTask.stopService();
    }
  }

  Future<void> _refreshOTA() async {
    setState(() => _isRefreshing = true);
    IrisHaptics.actionMedium();
    
    // Trigger Persistent Sync Telemetry
    SystemBroadcastService().triggerLocalOverride(
      "Intelligence Sync", 
      "Optimizing timetable neural cache...", 
      isPersistent: true
    );

    await Future.delayed(const Duration(seconds: 3));
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month} ${now.hour}:${now.minute}";
    await prefs.setString('timetable_last_sync', dateStr);
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _otaStatus?['last_sync'] = dateStr;
      });
      
      // Update Pill to Success State, then auto-hide after 3s
      SystemBroadcastService().triggerLocalOverride(
        "Sync Complete", 
        "Intelligence engine updated to v${_otaStatus?['version']}", 
        isPersistent: false
      );
      
      IrisHaptics.refreshSuccess();
    }
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

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    IrisHaptics.actionHeavy();
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
