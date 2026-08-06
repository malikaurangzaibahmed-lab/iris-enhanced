import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import '../core/omni_brain.dart';
import '../core/models.dart';
import '../services/helpdesk_faculty_service.dart';
import '../services/ui_feedback.dart';
import '../widgets/iris_components.dart';
import '../widgets/glass_card.dart';
import '../widgets/glowing_input_wrapper.dart';
import '../core/theme_signals.dart';
import '../core/minimal_theme.dart';
import '../core/vital_theme.dart';
import '../services/remote_config_service.dart';
import 'students_week_screen.dart';

class TeacherLocatorScreen extends StatefulWidget {
  final OmniBrain brain;
  final ValueChanged<String>? onTeacherSelected;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;
  final UniversityMemory? memory;
  final String? currentBatch;
  final String? initialTeacherQuery;
  final bool autoSearchInitial;
  final bool showDock;
  final bool showBackButton;
  final bool closeOnTeacherSelect;

  const TeacherLocatorScreen({
    required this.brain,
    this.onTeacherSelected,
    this.onRoleChanged,
    this.onBatchChanged,
    this.memory,
    this.currentBatch,
    this.initialTeacherQuery,
    this.autoSearchInitial = false,
    this.showDock = true,
    this.showBackButton = true,
    this.closeOnTeacherSelect = true,
    super.key,
  });

  @override
  State<TeacherLocatorScreen> createState() => _TeacherLocatorScreenState();
}

class _TeacherLocatorScreenState extends State<TeacherLocatorScreen> {
  static const String _helpdeskBackendBase =
      'https://cui-helpdesk-backend.onrender.com';

  final HelpdeskFacultyService _facultyService = HelpdeskFacultyService();
  late TextEditingController _controller;
  TeacherLocatorResult? _result;
  bool _searching = false;
  bool _facultyProfilesLoading = false;
  HelpdeskFacultySource _facultyProfilesSource = HelpdeskFacultySource.none;
  List<String> _suggestions = [];
  String? _searchHint;
  List<String> _quickPicks = [];
  List<FacultyProfile> _facultyProfiles = const [];
  int? _selectedWeekDay;

  String _normalizeTeacherName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previous = List<int>.generate(b.length + 1, (i) => i);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      for (var j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }
    return previous[b.length];
  }

  String? _bestTeacherMatch(String query) {
    final normalizedQuery = _normalizeTeacherName(query);
    if (normalizedQuery.isEmpty) return null;

    String? best;
    var bestDistance = 1 << 30;
    for (final teacher in widget.brain.allTeachers()) {
      final normalizedTeacher = _normalizeTeacherName(teacher);
      if (normalizedTeacher.isEmpty) continue;

      if (normalizedTeacher.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedTeacher)) {
        return teacher;
      }

      final distance = _levenshteinDistance(normalizedQuery, normalizedTeacher);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = teacher;
      }
    }

    final threshold = math.max(2, (normalizedQuery.length * 0.35).round());
    if (best != null && bestDistance <= threshold) return best;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    final initial = widget.initialTeacherQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _controller.text = initial;
      if (widget.autoSearchInitial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _performSearch(initial);
        });
      }
    }
    _quickPicks = widget.brain.allTeachers().take(4).toList();
    unawaited(_loadFacultyProfiles());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFacultyProfiles() async {
    _facultyProfilesLoading = true;
    final payload = await _facultyService.fetchLiveFirstWithFallbackPayload();
    if (!mounted) return;
    setState(() {
      _facultyProfiles = payload.items;
      _facultyProfilesSource = payload.source;
      _facultyProfilesLoading = false;
    });
  }

  FacultyProfile? _matchFacultyProfile(String teacherName) {
    return HelpdeskFacultyService.matchFacultyProfile(
      teacherName,
      _facultyProfiles,
    );
  }

  String _resolveFacultyImageUrl(String image) {
    final raw = image.trim();
    if (raw.isEmpty) return '';
    if (raw.contains('uploads/')) {
      final filename = raw.split('/').last;
      return 'assets/faculty_images/$filename';
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '$_helpdeskBackendBase$raw';
    return '$_helpdeskBackendBase/$raw';
  }

  Future<void> _launchFacultyPhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'teacher_locator_phone_unavailable',
        content: const Text('Phone number unavailable for this teacher.'),
      );
      return;
    }
    final uri = Uri.parse('tel:$normalized');
    if (await canLaunchUrl(uri)) {
      IrisSfx.pillTap();
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'teacher_locator_phone_launch_failed',
      content: const Text('Unable to open dialer on this device.'),
    );
  }

  Future<void> _launchFacultyEmail(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'teacher_locator_email_unavailable',
        content: const Text('Email unavailable for this teacher.'),
      );
      return;
    }
    final uri = Uri.parse('mailto:$normalized');
    if (await canLaunchUrl(uri)) {
      IrisSfx.pillTap();
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'teacher_locator_email_launch_failed',
      content: const Text('Unable to open email client on this device.'),
    );
  }

  void _updateSuggestions(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _searchHint = null;
      });
      return;
    }
    final q = query.toLowerCase().trim();
    final all = widget.brain.allTeachers();
    final directMatches = all
        .where((t) => t.toLowerCase().contains(q))
        .toList();
    if (directMatches.isNotEmpty) {
      setState(() {
        _suggestions = directMatches.take(5).toList();
        _searchHint = null;
      });
      return;
    }

    final normalizedQuery = _normalizeTeacherName(query);
    final scored =
        all
            .map(
              (name) => MapEntry(
                name,
                _levenshteinDistance(
                  normalizedQuery,
                  _normalizeTeacherName(name),
                ),
              ),
            )
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    final fuzzy = scored.take(5).map((e) => e.key).toList();
    final threshold = math.max(2, (normalizedQuery.length * 0.45).round());
    final filteredFuzzy = scored
        .where((e) => e.value <= threshold)
        .take(5)
        .map((e) => e.key)
        .toList();
    final matches = filteredFuzzy.isNotEmpty ? filteredFuzzy : fuzzy;
    final bestMatch = _bestTeacherMatch(query);
    setState(() {
      _suggestions = matches;
      _searchHint = bestMatch != null
        ? 'Likely match: $bestMatch'
        : q.length < 4
          ? 'Try a full name, surname, or department.'
          : 'Try initials or a surname for a better match.';
    });
  }

  void _performSearch([String? override]) {
    final query = override ?? _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _suggestions = [];
    });

    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        var effectiveQuery = query;
        var result = widget.brain.locateTeacher(query, DateTime.now());

        if (result.status == 'not_found' || result.status == 'empty') {
          final bestMatch = _bestTeacherMatch(query);
          if (bestMatch != null) {
            effectiveQuery = bestMatch;
            result = widget.brain.locateTeacher(bestMatch, DateTime.now());
          }
        }

        setState(() {
          _result = result;
          _searching = false;
          _selectedWeekDay = result.weeklySchedule.containsKey(DateTime.now().weekday)
              ? null
              : (result.weeklySchedule.keys.isEmpty
                  ? null
                  : (result.weeklySchedule.keys.toList()..sort()).first);
          if (result.status != 'not_found' && result.status != 'empty') {
            _controller.text = result.teacherName;
            _searchHint = null;
          } else if (_bestTeacherMatch(query) != null) {
            _searchHint = 'Closest match: ${_bestTeacherMatch(query)}';
          } else if (query.trim().length < 4) {
            _searchHint = 'Try a full name, surname, or department.';
          } else {
            _searchHint = 'No exact match. Try initials or a surname.';
          }
        });

        if (effectiveQuery != query &&
            result.status != 'not_found' &&
            result.status != 'empty') {
          showIrisFrostedSnackBar(
            context,
            dedupeKey: 'teacher_closest_match_${result.teacherName}',
            content: Text('Showing closest match: ${result.teacherName}'),
          );
        }
        IrisHaptics.actionMedium();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFacultySelection = widget.onTeacherSelected != null;
    const purple = IrisTokens.purple;
    const purpleLight = IrisTokens.purpleLight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        leading: widget.showBackButton ? AppBackButton(isDark: isDark) : null,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  TeacherLocatorAnimationWidget(
                    child: Row(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: ThemeSignals.useMinimalTheme,
                          builder: (context, useMinimal, _) {
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: useMinimal ? MinimalTokens.primary : null,
                                gradient: useMinimal ? null : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [purple, purpleLight, purpleLight],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: useMinimal ? null : [
                                  BoxShadow(
                                    color: purple.withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_search_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ValueListenableBuilder<bool>(
                                valueListenable: ThemeSignals.useMinimalTheme,
                                builder: (context, useMinimal, _) {
                                  if (useMinimal) {
                                    return Text(
                                      isFacultySelection ? 'Select Teacher' : 'Teacher Locator',
                                      style: IrisTextStyles.classSubject(context).copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 26,
                                        letterSpacing: 0.3,
                                      ),
                                    );
                                  }
                                  return ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [purple, purpleLight],
                                    ).createShader(bounds),
                                    child: Text(
                                      isFacultySelection ? 'Select Teacher' : 'Teacher Locator',
                                      style: IrisTextStyles.classSubject(context).copyWith(color: Colors.white, fontSize: 26, letterSpacing: 0.3),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              ValueListenableBuilder<String>(
                                valueListenable: RemoteConfigService.activeAcademicPeriod,
                                builder: (context, period, _) {
                                  String subtitle = 'Find any teacher\'s real-time location & schedule';
                                  if (isFacultySelection) {
                                    subtitle = 'Choose a teacher to load your faculty schedule';
                                  } else if (period == 'midterms' || period == 'finals' || period == 'exams') {
                                    subtitle = '📝 EXAM MODE: Find teacher\'s invigilation duty & exam hall';
                                  } else if (period == 'sports_week' || period == 'students_week') {
                                    subtitle = '🏆 GALA MODE: Find teacher\'s event & sports duty';
                                  }
                                  return Text(
                                    subtitle,
                                    style: IrisTextStyles.insightSubtext(context),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        IrisGlowingInputWrapper(
                          borderRadius: 14,
                          child: TextField(
                            controller: _controller,
                            onChanged: _updateSuggestions,
                            onSubmitted: _performSearch,
                            style: IrisTextStyles.body(context).copyWith(fontWeight: FontWeight.w600),
                            decoration: irisGlowingInputDecoration(
                              label: 'Teacher Name',
                              isDark: isDark,
                              prefixIcon: Icons.search_rounded,
                              hint: 'e.g. Dr. Nadeem Ahmed',
                            ).copyWith(
                              suffixIcon: _searching
                                  ? Container(
                                      width: 20,
                                      height: 20,
                                      padding: const EdgeInsets.all(12),
                                      child: IrisComponents.loadingSpinner(
                                        size: 16,
                                        strokeWidth: 2,
                                        color: purple,
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.arrow_forward_rounded),
                                      color: purple,
                                      onPressed: () => _performSearch(),
                                    ),
                            ),
                          ),
                        ),
                        if (_suggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: _suggestions
                                  .map(
                                    (s) => ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.history_rounded,
                                        size: 16,
                                        color: purpleLight,
                                      ),
                                      title: Text(
                                        s,
                                        style: IrisTextStyles.label(context).copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7)),
                                      ),
                                      onTap: () {
                                        _controller.text = s;
                                        _performSearch(s);
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                        if (_searchHint != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              _searchHint!,
                              style: IrisTextStyles.metaInfo(context).copyWith(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 20),
                    _buildResultCard(isDark, purple, purpleLight),
                    if (_result!.weeklySchedule.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildWeeklyScheduleCard(isDark, _result!),
                    ],
                  ] else if (!_searching) ...[
                    const SizedBox(height: 32),
                    Text(
                      'QUICK PICKS',
                      style: IrisTextStyles.overline(context).copyWith(letterSpacing: 1.5, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickPicks
                          .map(
                            (t) => ChoiceChip(
                              label: Text(
                                t,
                                style: IrisTextStyles.badgeText(context).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              selected: false,
                              onSelected: (_) {
                                _controller.text = t;
                                _performSearch(t);
                              },
                              backgroundColor:
                                  (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.05),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(bool isDark, Color purple, Color purpleLight) {
    final res = _result!;
    final profile = _matchFacultyProfile(res.teacherName);
    final hasSchedule = res.todaySessions.isNotEmpty;

    return MotionSlideFade(
      beginOffset: const Offset(0, 30),
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IrisComponents.facultyAvatar(
                      imageUrl: profile != null && profile.image.isNotEmpty ? _resolveFacultyImageUrl(profile.image) : null,
                      gender: profile?.gender ?? 'male',
                      name: res.teacherName,
                      radius: 32,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            res.teacherName,
                            style: IrisTextStyles.classSubject(context).copyWith(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                          ),
                          const SizedBox(height: 4),
                          if (profile != null)
                            Text(
                              profile.department,
                              style: IrisTextStyles.classSessionMeta(context).copyWith(color: purple.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
                            )
                          else
                            Text(
                              'Faculty Member',
                              style: IrisTextStyles.metaInfo(context),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (profile != null) ...[
                      _buildContactAction(
                        Icons.phone_rounded,
                        'Call',
                        () => _launchFacultyPhone(profile.contact),
                      ),
                      const SizedBox(width: 12),
                      _buildContactAction(
                        Icons.email_rounded,
                        'Email',
                        () => _launchFacultyEmail(profile.email),
                      ),
                    ],
                    if (widget.onTeacherSelected != null) ...[
                      if (profile != null) const SizedBox(width: 12),
                      _buildContactAction(
                        Icons.check_circle_rounded,
                        'Select',
                        () {
                          widget.onTeacherSelected!(res.teacherName);
                          if (widget.closeOnTeacherSelect) {
                            Navigator.of(context).pop();
                          }
                        },
                        isPrimary: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                _buildStatusSection(isDark, res),
              ],
            ),
          ),
          if (hasSchedule) ...[
            const SizedBox(height: 20),
            _buildMiniTimeline(isDark, res.todaySessions),
          ],
        ],
      ),
    );
  }

  Widget _buildContactAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ValueListenableBuilder<bool>(
          valueListenable: ThemeSignals.useMinimalTheme,
          builder: (context, useMinimal, _) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: useMinimal
                    ? (isPrimary ? MinimalTokens.primary : Colors.transparent)
                    : (isPrimary
                        ? IrisTokens.purple
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05))),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: useMinimal
                      ? Colors.transparent
                      : (isPrimary
                          ? Colors.white.withValues(alpha: 0.2)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05))),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isPrimary
                        ? Colors.white
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: IrisTextStyles.classProgress(context).copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: isPrimary ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.9))),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusSection(bool isDark, TeacherLocatorResult res) {
    final statusColor = res.status == 'live' ? IrisTokens.success : IrisTokens.purple;
    final emoji = res.status == 'live' ? '🟢' : '⚪';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: isDark ? 0.10 : 0.06),
            statusColor.withValues(alpha: isDark ? 0.02 : 0.01),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withValues(alpha: isDark ? 0.22 : 0.15),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                emoji,
                style: IrisTextStyles.metaInfo(context).copyWith(fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                res.status == 'live' ? 'CURRENTLY TEACHING' : 'CURRENT STATUS',
                style: IrisTextStyles.overline(context).copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w900, color: statusColor.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            res.statusText,
            style: IrisTextStyles.body(context).copyWith(fontWeight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 4),
          Text(
            res.todaySessions.isNotEmpty
                ? '${res.todaySessions.length} session${res.todaySessions.length == 1 ? '' : 's'} today'
                : 'No sessions today',
            style: IrisTextStyles.metaInfo(context),
          ),
        ],
      ),
    );
  }

  int _focusWeekDay(TeacherLocatorResult res) {
    if (_selectedWeekDay != null) {
      return _selectedWeekDay!;
    }

    final today = DateTime.now().weekday;
    if (res.weeklySchedule.containsKey(today)) {
      return today;
    }

    final days = res.weeklySchedule.keys.toList()..sort();
    return days.isEmpty ? today : days.first;
  }

  Widget _buildWeeklyScheduleCard(bool isDark, TeacherLocatorResult res) {
    final dayIndex = _focusWeekDay(res);
    final entries = List<TeacherScheduleEntry>.from(
      res.weeklySchedule[dayIndex] ?? const [],
    )..sort((a, b) => a.startTime.compareTo(b.startTime));

    final dayLabel = TeacherScheduleEntry.dayNames[dayIndex - 1];
    final upcomingCount = entries.where((e) => e.isUpcoming).length;
    final liveCount = entries.where((e) => e.isLive).length;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: ThemeSignals.useMinimalTheme,
                  builder: (context, useMinimal, _) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: useMinimal ? MinimalTokens.primary : null,
                        gradient: useMinimal ? null : LinearGradient(colors: IrisTokens.brandGradient),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.view_week_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Schedule',
                        style: IrisTextStyles.classSubject(context).copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap a day to browse this teacher\'s week.',
                        style: IrisTextStyles.metaInfo(context).copyWith(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.58),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                return SizedBox(
                  width: double.infinity,
                  child: DaySwitcher(
                    selectedDayIndex: _selectedWeekDay,
                    onSelected: (value) => setState(() {
                      _selectedWeekDay = value;
                    }),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 380;
                final statWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 3;

                if (compact) {
                  return Column(
                    children: [
                      _buildMiniStat(
                        isDark,
                        width: statWidth,
                        label: dayLabel,
                        value: '${entries.length} classes',
                      ),
                      const SizedBox(height: 8),
                      _buildMiniStat(
                        isDark,
                        width: statWidth,
                        label: 'Live',
                        value: '$liveCount',
                      ),
                      const SizedBox(height: 8),
                      _buildMiniStat(
                        isDark,
                        width: statWidth,
                        label: 'Upcoming',
                        value: '$upcomingCount',
                      ),
                    ],
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMiniStat(
                      isDark,
                      width: statWidth,
                      label: dayLabel,
                      value: '${entries.length} classes',
                    ),
                    _buildMiniStat(
                      isDark,
                      width: statWidth,
                      label: 'Live',
                      value: '$liveCount',
                    ),
                    _buildMiniStat(
                      isDark,
                      width: statWidth,
                      label: 'Upcoming',
                      value: '$upcomingCount',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  'No classes on $dayLabel.',
                  style: IrisTextStyles.body(context).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.68),
                  ),
                ),
              )
            else
              Column(
                children: entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildWeeklyEntryCard(isDark, entry),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(
    bool isDark, {
    required double width,
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: IrisTextStyles.overline(context).copyWith(
                fontSize: 11,
                letterSpacing: 1.2,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: IrisTextStyles.body(context).copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyEntryCard(bool isDark, TeacherScheduleEntry entry) {
    final accent = entry.isLive
        ? IrisTokens.success
        : entry.isUpcoming
            ? IrisTokens.brand
            : IrisTokens.purple;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: isDark ? 0.12 : 0.08),
            accent.withValues(alpha: isDark ? 0.02 : 0.01),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.25 : 0.15),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.06 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 480;

          final metadataStyle = IrisTextStyles.metaInfo(context).copyWith(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.58),
            fontSize: compact ? 11.5 : 12,
          );

          final badge = IrisComponents.statusBadge(
            label: entry.isLive
                ? 'LIVE'
                : entry.isUpcoming
                    ? 'UP NEXT'
                    : TeacherScheduleEntry.dayNames[entry.dayIndex - 1]
                        .substring(0, 3)
                        .toUpperCase(),
            color: accent,
            isDark: isDark,
            pulse: entry.isLive,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.subject,
                            style: IrisTextStyles.classSubject(context).copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entry.startTime} - ${entry.endTime}',
                            style: metadataStyle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${entry.room} • ${entry.batch}',
                            style: metadataStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                badge,
              ],
            );
          }

          return Row(
            children: [
              Container(
                width: 12,
                height: 64,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.subject,
                      style: IrisTextStyles.classSubject(context).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.startTime} - ${entry.endTime}  •  ${entry.room}  •  ${entry.batch}',
                      style: metadataStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              badge,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniTimeline(bool isDark, List<TeacherScheduleEntry> sessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'TODAY\'S SCHEDULE',
            style: IrisTextStyles.overline(context).copyWith(letterSpacing: 1.5, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4)),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final s = sessions[idx];
            final isLive = s.isLive;
            return GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.startTime,
                        style: IrisTextStyles.classSessionMeta(context).copyWith(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        s.endTime,
                        style: IrisTextStyles.metaInfo(context).copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.subject,
                          style: IrisTextStyles.classSubject(context).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${s.room} • ${s.batch}',
                          style: IrisTextStyles.metaInfo(context).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (isLive)
                    IrisComponents.statusBadge(
                      label: 'LIVE',
                      color: IrisTokens.success,
                      isDark: isDark,
                      pulse: true,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
