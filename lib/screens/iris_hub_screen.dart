import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart'; // For IrisHaptics/Sfx
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../widgets/native_liquid_glass.dart';
import 'admin_god_mode_dashboard.dart';
import 'login_screen.dart';
import '../widgets/glass_card.dart';
import '../services/system_broadcast_service.dart';
import '../core/animations.dart';

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
  
  bool _isGodMode = false;
  String _userRole = 'student';
  String _appearanceMode = 'system';
  bool _uiSoundsEnabled = true;
  bool _uiHapticsEnabled = true;
  String _feedbackProfile = 'balanced';
  
  bool _persistentNotificationEnabled = false;
  bool _lectureRemindersEnabled = true;
  bool _widgetDarkMode = false;
  Map<String, dynamic>? _otaStatus;
  bool _isRefreshing = false;

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
    _checkAdminStatus();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role') ?? 'student';
      _appearanceMode = prefs.getString('themeMode') ?? 'system';
      _uiSoundsEnabled = prefs.getBool('ui_sounds_enabled') ?? true;
      _uiHapticsEnabled = prefs.getBool('ui_haptics_enabled') ?? true;
      _feedbackProfile = prefs.getString('ui_feedback_profile') ?? 'balanced';
      _persistentNotificationEnabled = prefs.getBool('persistent_notification_enabled') ?? false;
      _lectureRemindersEnabled = prefs.getBool('lecture_reminders_enabled') ?? true;
      _widgetDarkMode = prefs.getBool('widget_dark_mode') ?? false;
    });
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

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() => _isGodMode = true);
        IrisHaptics.actionMedium();
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  @override
  void dispose() {
    _profileAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? IrisTokens.surfaceDark : IrisTokens.surfaceLight,
      body: CustomScrollView(
        physics: const ButterScrollPhysics(),
        slivers: [
          // THE CRYSTAL HEADER
          SliverAppBar(
            expandedHeight: 420,
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                clipBehavior: Clip.none,
                children: [
                  // LAVA LAMP ORBS (Background)
                  _buildLavaBlob(size.width * 0.8, -100, IrisTokens.brand.withOpacity(0.15), 300),
                  _buildLavaBlob(-100, size.height * 0.1, IrisTokens.purple.withOpacity(0.15), 250),
                  
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80.0),
                      child: Column(
                        children: [
                          // THE CORE PROFILE SPHERE
                          Container(
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: AnimatedBuilder(
                              animation: _profileAnimController,
                              builder: (context, child) {
                                return Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.1),
                                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                                    gradient: SweepGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.0),
                                        Colors.white.withOpacity(0.2),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                      transform: GradientRotation(_profileAnimController.value * 2 * 3.14),
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 140,
                                      height: 140,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: _isGodMode 
                                            ? [IrisTokens.warning, IrisTokens.error]
                                            : [IrisTokens.brand, IrisTokens.purple],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (_isGodMode ? IrisTokens.warning : IrisTokens.brand).withOpacity(0.4),
                                            blurRadius: 30,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      ),
                                      child: ClipOval(
                                        child: CircleAvatar(
                                          backgroundColor: Colors.transparent,
                                          child: Icon(_isGodMode ? Icons.security_rounded : Icons.person_rounded, size: 70, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Identity Cluster
                          Text(
                            user?.email ?? "GUEST INSTANCE",
                            style: TextStyle(
                              fontSize: 22, 
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : Colors.black87
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (_isGodMode ? IrisTokens.warning : IrisTokens.brand).withOpacity(0.15 + (_pulseController.value * 0.1)),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: (_isGodMode ? IrisTokens.warning : IrisTokens.brand).withOpacity(0.3)),
                                ),
                                child: Text(
                                  _isGodMode ? "GOD-MODE TERMINAL" : _userRole.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    color: _isGodMode ? IrisTokens.warning : IrisTokens.brand,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // SETTINGS & ABOUT SECTION
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // QUICK ACTIONS GRID
                  Row(
                    children: [
                      Expanded(child: _buildGlassAction(isDark, "PERSONA", _userRole.toUpperCase(), Icons.supervised_user_circle_rounded, _showRolePicker)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildGlassAction(isDark, "THEME", _appearanceMode.toUpperCase(), Icons.palette_rounded, _showThemePicker)),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  _buildIntelligenceDashboard(isDark),
                  
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader("SYSTEM TUNER", isDark),
                  const SizedBox(height: 10),
                  
                  _buildPremiumSettingsGroup(isDark, [
                    _buildSettingsTile(
                      isDark,
                      title: "Haptic Pulse",
                      subtitle: "Current Profile: ${_feedbackProfile.toUpperCase()}",
                      icon: Icons.vibration_rounded,
                      onTap: _showHapticsPicker,
                    ),
                    _buildSettingsToggle(
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
                  ]),
                  
                  const SizedBox(height: 28),
                  _buildSectionHeader("SERVICE ENGINE", isDark),
                  const SizedBox(height: 16),
                  
                  _buildPremiumSettingsGroup(isDark, [
                    _buildSettingsToggle(
                      isDark,
                      title: "Class Tracker",
                      subtitle: "Deep-system persistent notification",
                      icon: Icons.notifications_active_rounded,
                      value: _persistentNotificationEnabled,
                      onChanged: _togglePersistentNotification,
                    ),
                    _buildSettingsToggle(
                      isDark,
                      title: "Lecture Reminders",
                      subtitle: "Context-aware schedule alerts",
                      icon: Icons.alarm_rounded,
                      value: _lectureRemindersEnabled,
                      onChanged: (v) async {
                        setState(() => _lectureRemindersEnabled = v);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('lecture_reminders_enabled', v);
                      }
                    ),
                    _buildSettingsToggle(
                      isDark,
                      title: "Dynamic Hub Widget",
                      subtitle: "Adaptive home screen synchronization",
                      icon: Icons.widgets_rounded,
                      value: _widgetDarkMode,
                      onChanged: (v) async {
                        setState(() => _widgetDarkMode = v);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('widget_dark_mode', v);
                      }
                    ),
                  ]),
                  
                  const SizedBox(height: 20),
                  _buildSectionHeader("MAINTENANCE", isDark),
                  const SizedBox(height: 10),
                  
                  _buildOTACardPremium(isDark),
                  
                  const SizedBox(height: 20),
                  _buildSectionHeader("REPORTS & SUPPORT", isDark),
                  const SizedBox(height: 10),
                  
                  _buildPremiumSettingsGroup(isDark, [
                    _buildSettingsTile(
                      isDark, 
                      title: "Developer Protocol", 
                      subtitle: "Malik Aurangzaib • Lead Architect", 
                      icon: Icons.code_rounded,
                      onTap: null,
                    ),
                    _buildSettingsTile(
                      isDark, 
                      title: "Emergency Support", 
                      subtitle: "Direct terminal for critical bug reports", 
                      icon: Icons.bug_report_rounded,
                      onTap: _contactSupport,
                    ),
                  ]),

                  // GOD MODE PANEL
                  if (_isGodMode) ...[
                    const SizedBox(height: 48),
                    _buildSectionHeader("GOD-MODE REGISTRY", isDark),
                    const SizedBox(height: 16),
                    LiquidGlass(
                      settings: LiquidGlassSettings(
                        blur: 10,
                        ambientStrength: 0.5,
                        lightAngle: 0.2 * 3.14,
                        glassColor: IrisTokens.warning.withOpacity(0.08),
                        thickness: 15,
                      ),
                      shape: const LiquidRoundedSuperellipse(
                        borderRadius: Radius.circular(24),
                      ),
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminGodModeDashboard())),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(color: IrisTokens.warning.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: [IrisTokens.warning.withOpacity(0.05), Colors.transparent],
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: IrisTokens.warning.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.admin_panel_settings_rounded, color: IrisTokens.warning, size: 30),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Terminal Root Access", style: TextStyle(fontWeight: FontWeight.w900, color: IrisTokens.warning, letterSpacing: 1)),
                                    Text("Authorized Personnel Only", style: TextStyle(fontSize: 11, color: IrisTokens.warning.withOpacity(0.7))),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: IrisTokens.warning, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                  
                  // LOGOUT / TERMINATE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: LiquidGlass(
                      settings: LiquidGlassSettings(
                        blur: 15,
                        ambientStrength: 0.6,
                        lightAngle: 0.25 * 3.14,
                        glassColor: (user == null ? IrisTokens.brand : IrisTokens.error).withOpacity(0.1),
                        thickness: 18,
                      ),
                      shape: LiquidRoundedSuperellipse(
                        borderRadius: Radius.circular(20),
                      ),
                      child: ElevatedButton(
                        onPressed: user == null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())) : _handleLogout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (user == null ? IrisTokens.brand : IrisTokens.error).withOpacity(0.15),
                          foregroundColor: user == null ? IrisTokens.brand : IrisTokens.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: (user == null ? IrisTokens.brand : IrisTokens.error).withOpacity(0.3)),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          user == null ? "VERIFY IDENTITY" : "TERMINATE SESSION",
                          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  Center(
                    child: Opacity(
                      opacity: 0.3,
                      child: Column(
                        children: [
                          const Icon(Icons.blur_on_rounded, size: 40, color: IrisTokens.brand),
                          const SizedBox(height: 12),
                          Text(
                            "IRIS HUB • v2.1.0-STABLE",
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 3,
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildIntelligenceDashboard(bool isDark) {
    return GlassCard(
      borderRadius: 28,
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
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "System Analysis Complete",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  IrisHaptics.intelligencePulse();
                  IrisSfx.intelligentConfirmation();
                },
                icon: Icon(Icons.refresh_rounded, size: 20, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: IrisTokens.brand, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Next: Computational Physics in 12 minutes (Room 402)",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
            color: IrisTokens.brand.withOpacity(0.1),
            border: Border.all(
              color: IrisTokens.brand.withOpacity(0.2 + (_pulseController.value * 0.3)),
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: IrisTokens.brand,
                boxShadow: [
                  BoxShadow(
                    color: IrisTokens.brand.withOpacity(0.5),
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

  Widget _buildLavaBlob(double x, double y, Color color, double size) {
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }

  Widget _buildGlassAction(bool isDark, String label, String value, IconData icon, VoidCallback onTap) {
    return GlassCard(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.06)),
          ),
          child: Column(
            children: [
              Icon(icon, color: IrisTokens.brand, size: 28),
              const SizedBox(height: 12),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: isDark ? Colors.white38 : Colors.black38)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumSettingsGroup(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile(bool isDark, {required String title, required String subtitle, required IconData icon, required VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: IrisTokens.brand.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: IrisTokens.brand, size: 24),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5))),
      trailing: onTap != null ? Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withOpacity(0.2)) : null,
    );
  }

  Widget _buildSettingsToggle(bool isDark, {required String title, required String subtitle, required IconData icon, required bool value, required ValueChanged<bool> onChanged}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: IrisTokens.brand.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: IrisTokens.brand, size: 24),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5))),
      trailing: Switch.adaptive(
        value: value, 
        onChanged: (v) {
          IrisHaptics.chipSelect();
          onChanged(v);
        },
        activeColor: IrisTokens.brand, activeTrackColor: IrisTokens.brand.withOpacity(0.3),
      ),
    );
  }

  Widget _buildOTACardPremium(bool isDark) {
    return LiquidGlass(
      settings: LiquidGlassSettings(
        blur: 10,
        ambientStrength: 0.5,
        lightAngle: 0.15 * 3.14,
        glassColor: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        thickness: 18,
      ),
      shape: LiquidRoundedSuperellipse(
        borderRadius: Radius.circular(28),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: IrisTokens.brand.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.cloud_sync_rounded, color: IrisTokens.brand, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Hyper-Sync Protocol", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  Text(
                    "Build v${_otaStatus?['version']} • Last Sync: ${_otaStatus?['last_sync']}", 
                    style: TextStyle(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5))
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _isRefreshing ? null : _refreshOTA,
              icon: _isRefreshing 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: IrisTokens.brand))
                : const Icon(Icons.refresh_rounded, color: IrisTokens.brand, size: 28),
            ),
          ],
        ),
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
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
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
          Text(label, style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.5))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
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
        settings: LiquidGlassSettings(
          blur: 25,
          ambientStrength: 0.7,
          lightAngle: 0.2 * 3.14,
          glassColor: (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(0.6),
          thickness: 30,
        ),
        shape: const LiquidRoundedSuperellipse(
          borderRadius: Radius.circular(32),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("HAPTIC PROTOCOL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: isDark?Colors.white38:Colors.black38)),
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
        settings: LiquidGlassSettings(
          blur: 25,
          ambientStrength: 0.7,
          lightAngle: 0.2 * 3.14,
          glassColor: (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(0.6),
          thickness: 30,
        ),
        shape: const LiquidRoundedSuperellipse(
          borderRadius: Radius.circular(32),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("APPEARANCE MODE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: isDark?Colors.white38:Colors.black38)),
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
      builder: (context) => LiquidGlass(
        settings: LiquidGlassSettings(
          blur: 25,
          ambientStrength: 0.7,
          lightAngle: 0.2 * 3.14,
          glassColor: (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(0.6),
          thickness: 30,
        ),
        shape: const LiquidRoundedSuperellipse(
          borderRadius: Radius.circular(32),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF111421) : Colors.white).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("APPLICATION PERSONA", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: isDark?Colors.white38:Colors.black38)),
              const SizedBox(height: 24),
              _buildPickerOption(isDark, "Student Module", "Standard timeline access", _userRole == "student", () => _setUserRole("student")),
              _buildPickerOption(isDark, "Faculty Module", "Academic management terminal", _userRole == "faculty", () => _setUserRole("faculty")),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption(bool isDark, String title, String subtitle, bool selected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? IrisTokens.brand.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? IrisTokens.brand.withOpacity(0.3) : Colors.transparent),
      ),
      child: ListTile(
        onTap: () {
          onTap();
          Navigator.pop(context);
        },
        leading: Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? IrisTokens.brand : Colors.grey.withOpacity(0.5)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark?Colors.white:Colors.black, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: (isDark?Colors.white:Colors.black).withOpacity(0.5), fontSize: 12)),
      ),
    );
  }

  Future<void> _setUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    setState(() => _userRole = role);
    if (widget.onRoleChanged != null) {
      widget.onRoleChanged!(role);
    }
    IrisHaptics.refreshSuccess();
  }

  Future<void> _setFeedbackProfile(String profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ui_feedback_profile', profile);
    setState(() => _feedbackProfile = profile);
    IrisHaptics.setProfile(profile);
    IrisHaptics.actionHeavy();
  }

  Future<void> _setAppearanceMode(String mode) async {
    if (widget.onSetThemeMode != null) {
      await widget.onSetThemeMode!(mode);
      setState(() => _appearanceMode = mode);
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
    setState(() => _isGodMode = false);
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
