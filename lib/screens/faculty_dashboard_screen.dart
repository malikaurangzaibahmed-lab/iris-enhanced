import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';

import '../core/tokens.dart';
import '../core/models.dart';
import '../core/omni_brain.dart';
import '../widgets/iris_components.dart';
import '../widgets/glass_card.dart';
import '../widgets/neural_aura.dart';
import '../widgets/smooth_scroll.dart';
import '../core/vital_theme.dart';
import '../core/vital_motion.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';
import '../services/helpdesk_faculty_service.dart';
import 'about_screen.dart';

class FacultyDashboard extends StatefulWidget {
  final OmniBrain brain;
  final String teacherName;
  final VoidCallback onToggleTheme;
  final ValueChanged<ThemeMode>? onSetThemeMode;
  final ThemeMode currentThemeMode;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;

  const FacultyDashboard({
    required this.brain,
    this.teacherName = '',
    required this.onToggleTheme,
    this.onSetThemeMode,
    this.currentThemeMode = ThemeMode.system,
    this.onRoleChanged,
    this.onBatchChanged,
    super.key,
  });

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard>
    with SingleTickerProviderStateMixin {
  late String? _selectedTeacher;
  int? _overrideDayIndex;
  List<ClassSession> _cachedSchedule = [];
  bool _facultyProfilesLoading = false;
  List<FacultyProfile> _facultyProfiles = [];
  String _facultyProfilesSource = 'local';
  final GlobalKey _facultyChangeTeacherKey = GlobalKey();
  late Timer _ticker;
  int? _lastMinute;

  @override
  void initState() {
    super.initState();
    _selectedTeacher = widget.teacherName;
    _updateScheduleCache();
    _loadFacultyProfiles();
    _lastMinute = DateTime.now().minute;
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        final now = DateTime.now();
        if (_lastMinute != now.minute) {
          setState(() {
            _lastMinute = now.minute;
            _updateScheduleCache();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _updateScheduleCache() {
    if (_selectedTeacher == null) return;
    final now = DateTime.now();
    final schedule = _overrideDayIndex != null
        ? _scheduleForDay(_selectedTeacher!, _overrideDayIndex!)
        : _buildSuggestedScheduleForTeacher(_selectedTeacher!, now);

    final mergedSchedule = widget.brain.getMergedConsecutiveSessions(schedule);
    mergedSchedule.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    setState(() {
      _cachedSchedule = mergedSchedule;
    });
  }

  List<ClassSession> _scheduleForDay(String teacher, int dayIndex) {
    final allSessions = widget.brain.scheduleForTeacher(teacher);
    return allSessions.where((s) => s.dayIndex == dayIndex).toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
  }

  List<ClassSession> _buildSuggestedScheduleForTeacher(
    String teacher,
    DateTime now,
  ) {
    final all = widget.brain.scheduleForTeacher(teacher);
    if (all.isEmpty) return [];

    final currentTime = now.hour + (now.minute / 60.0);
    final today = all.where((s) => s.dayIndex == now.weekday).toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    if (today.isNotEmpty) {
      if (today.every((s) => s.safeEndVal <= currentTime)) {
        return _nextDayScheduleForTeacher(all, now.weekday);
      }
      return today;
    }
    return _nextDayScheduleForTeacher(all, now.weekday);
  }

  List<ClassSession> _nextDayScheduleForTeacher(
    List<ClassSession> all,
    int todayIndex,
  ) {
    for (int offset = 1; offset <= 6; offset++) {
      final nextDay = ((todayIndex + offset - 1) % 7) + 1;
      final daySchedule = all.where((s) => s.dayIndex == nextDay).toList()
        ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      if (daySchedule.isNotEmpty) return daySchedule;
    }
    return [];
  }

  Future<void> _loadFacultyProfiles() async {
    setState(() => _facultyProfilesLoading = true);
    try {
      final service = HelpdeskFacultyService();
      final profiles = await service.fetchOfflineOnly();
      if (mounted) {
        setState(() {
          _facultyProfiles = profiles;
          _facultyProfilesSource = 'remote';
          _facultyProfilesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _facultyProfilesSource = 'fallback';
          _facultyProfilesLoading = false;
        });
      }
    }
  }

  FacultyProfile? _matchSelectedFacultyProfile() {
    if (_selectedTeacher == null) return null;
    try {
      return _facultyProfiles.firstWhere(
        (p) => p.name.toLowerCase().contains(_selectedTeacher!.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }

  String _resolveFacultyImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://cuonline.comsats.edu.pk/PublicDocs/TeacherImages/$path';
  }

  void _launchFacultyEmail(String email) async {
    if (email.isEmpty) return;
    final url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  String _facultySourceLabel(String source) {
    switch (source) {
      case 'remote': return 'VERIFIED';
      case 'fallback': return 'LOCAL';
      default: return 'GUEST';
    }
  }

  Future<void> _handleRefresh() async {
    IrisHaptics.refreshStart();
    await _loadFacultyProfiles();
    _updateScheduleCache();
    IrisHaptics.refreshSuccess();
  }

  void _openTeacherPicker({GlobalKey? originKey}) {
    final teachers = widget.brain.allTeachers();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? VitalTokens.obsidian 
            : VitalTokens.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Select Teacher', style: TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final t = teachers[index];
              return ListTile(
                title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('faculty_user_name', t);
                  setState(() {
                    _selectedTeacher = t;
                    _updateScheduleCache();
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDateLabel(DateTime now) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[(now.weekday - 1) % 7]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final teacher = _selectedTeacher ?? 'Faculty Member';
    final dateLabel = _formatDateLabel(now);
    final insight = widget.brain.buildTeacherTemporalInsight(teacher, now);

    return Scaffold(
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          _buildFacultyScheduleView(
            isDark,
            teacher,
            _cachedSchedule,
            now,
            dateLabel,
            insight,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: _buildBottomNavBar(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyScheduleView(
    bool isDark,
    String teacher,
    List<ClassSession> schedule,
    DateTime now,
    String dateLabel,
    TemporalInsight insight,
  ) {
    final profile = _matchSelectedFacultyProfile();
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactCard = screenWidth < 400;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: IrisTokens.brand,
      backgroundColor: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
      child: CustomScrollView(
        physics: const ButterScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildFacultyHeaderBadge(compact: isCompactCard),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildFacultyHeaderTitle(teacher, isDark, isCompactCard),
                        ),
                        _buildFacultyChangeTeacherButton(compact: isCompactCard),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (profile != null) _buildProfileCard(profile, isDark),
                    const SizedBox(height: 16),
                    _buildStatsRow(schedule, dateLabel, isDark),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _buildInsightCard(insight, isDark),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildDaySelector(now, isDark),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
            sliver: schedule.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyState(isDark))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final session = schedule[index];
                        final nextSession = index + 1 < schedule.length ? schedule[index + 1] : null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClassCard(
                            session: session,
                            nextSession: nextSession,
                            isFacultyView: true,
                          ),
                        );
                      },
                      childCount: schedule.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyHeaderBadge({bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [IrisTokens.purple, IrisTokens.purpleLight]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: IrisTokens.purple.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(Icons.badge_rounded, color: Colors.white, size: compact ? 20 : 24),
    );
  }

  Widget _buildFacultyHeaderTitle(String teacher, bool isDark, bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEACHING TODAY',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1.2,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          teacher.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: compact ? 18 : 22,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildFacultyChangeTeacherButton({bool compact = false}) {
    return IconButton(
      onPressed: _openTeacherPicker,
      icon: Icon(
        Icons.swap_horiz_rounded,
        color: IrisTokens.purple,
        size: compact ? 20 : 24,
      ),
    );
  }

  Widget _buildProfileCard(FacultyProfile profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IrisComponents.facultyAvatar(
                imageUrl: profile.image.isNotEmpty ? _resolveFacultyImageUrl(profile.image) : null,
                gender: profile.gender,
                name: profile.name,
                radius: 24,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.department,
                      style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                    ),
                    Text(
                      profile.location,
                      style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: IrisTokens.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _facultySourceLabel(_facultyProfilesSource),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: IrisTokens.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _launchFacultyEmail(profile.email),
              icon: const Icon(Icons.email_outlined, size: 16),
              label: const Text('CONTACT FACULTY'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                foregroundColor: IrisTokens.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<ClassSession> schedule, String dateLabel, bool isDark) {
    return Row(
      children: [
        _buildStatChip(Icons.calendar_today_rounded, dateLabel, isDark),
        const SizedBox(width: 8),
        _buildStatChip(Icons.schedule_rounded, '${schedule.length} CLASSES', isDark),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(TemporalInsight insight, bool isDark) {
    final accentColor = insight.isLive ? VitalTokens.green : (insight.isUrgent ? VitalTokens.orange : VitalTokens.blue);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(insight.isLive ? Icons.record_voice_over_rounded : Icons.info_outline_rounded, color: accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  insight.headline,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              if (insight.isLive) _buildLivePill(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.subline,
            style: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VitalTokens.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('LIVE', style: TextStyle(color: VitalTokens.green, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildDaySelector(DateTime now, bool isDark) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final currentDay = _overrideDayIndex ?? now.weekday;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final dayIndex = index + 1;
        final isSelected = currentDay == dayIndex;
        return GestureDetector(
          onTap: () {
            setState(() {
              _overrideDayIndex = dayIndex;
              _updateScheduleCache();
            });
            IrisHaptics.chipSelect();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? IrisTokens.brand : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                days[index],
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.spa_rounded, size: 64, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
        const SizedBox(height: 16),
        const Text(
          'NO CLASSES SCHEDULED',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12),
        ),
        Text(
          'Time to relax and recharge',
          style: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar(bool isDark) {
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: (isDark ? VitalTokens.obsidian : Colors.white).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.dashboard_rounded, 'DASH', true, isDark, () {}),
              _buildNavItem(1, Icons.groups_rounded, 'STUDENTS', false, isDark, () {}),
              _buildNavItem(2, Icons.cloud_rounded, 'PORTAL', false, isDark, () {}),
              _buildNavItem(3, Icons.settings_rounded, 'ABOUT', false, isDark, () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AboutScreen(
                      memory: widget.brain.memory,
                      onRoleChanged: widget.onRoleChanged,
                      onBatchChanged: widget.onBatchChanged,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isSelected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        IrisSfx.navTick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? IrisTokens.brand : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: isSelected ? IrisTokens.brand : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
