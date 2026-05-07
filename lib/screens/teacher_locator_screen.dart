import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import '../core/omni_brain.dart';
import '../core/university_memory.dart';
import '../services/helpdesk_faculty_service.dart';
import '../services/ui_feedback.dart';
import '../widgets/iris_components.dart';
import '../widgets/glass_card.dart';
import '../widgets/neural_aura.dart';

class TeacherLocatorScreen extends StatefulWidget {
  final OmniBrain brain;
  final ValueChanged<String>? onTeacherSelected;
  final ValueChanged<String>? onRoleChanged;
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
  List<String> _quickPicks = [];
  List<FacultyProfile> _facultyProfiles = const [];

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
      setState(() => _suggestions = []);
      return;
    }
    final q = query.toLowerCase().trim();
    final all = widget.brain.allTeachers();
    final directMatches = all
        .where((t) => t.toLowerCase().contains(q))
        .toList();
    if (directMatches.isNotEmpty) {
      setState(() => _suggestions = directMatches.take(5).toList());
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
    setState(() => _suggestions = matches);
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
          if (result.status != 'not_found' && result.status != 'empty') {
            _controller.text = result.teacherName;
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
          NeuralAura(background: isDark),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [purple, purpleLight, purpleLight],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
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
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [purple, purpleLight],
                              ).createShader(bounds),
                              child: Text(
                                isFacultySelection
                                    ? 'Select Teacher'
                                    : 'Teacher Locator',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isFacultySelection
                                  ? 'Choose a teacher to load your faculty schedule'
                                  : 'Find any teacher\'s real-time location & schedule',
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 0.1,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        TextField(
                          controller: _controller,
                          onChanged: _updateSuggestions,
                          onSubmitted: _performSearch,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: irisFrostedInputDecoration(
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.7),
                                        ),
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
                      ],
                    ),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 20),
                    _buildResultCard(isDark, purple, purpleLight),
                  ] else if (!_searching) ...[
                    const SizedBox(height: 32),
                    Text(
                      'QUICK PICKS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.4),
                      ),
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
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
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
    final hasSchedule = res.schedule.isNotEmpty;

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
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: purple.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: profile != null && profile.image.isNotEmpty
                          ? Image.network(
                              _resolveFacultyImageUrl(profile.image),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person_rounded,
                                size: 32,
                                color: purple.withValues(alpha: 0.5),
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              size: 32,
                              color: purple.withValues(alpha: 0.5),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            res.teacherName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (profile != null)
                            Text(
                              profile.designation,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: purple.withValues(alpha: 0.8),
                              ),
                            )
                          else
                            Text(
                              'Faculty Member',
                              style: TextStyle(
                                fontSize: 13,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (profile != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildContactAction(
                        Icons.phone_rounded,
                        'Call',
                        () => _launchFacultyPhone(profile.phone),
                      ),
                      const SizedBox(width: 12),
                      _buildContactAction(
                        Icons.email_rounded,
                        'Email',
                        () => _launchFacultyEmail(profile.email),
                      ),
                      const SizedBox(width: 12),
                      if (widget.onTeacherSelected != null)
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
                  ),
                ],
                const SizedBox(height: 24),
                _buildStatusSection(isDark, res),
              ],
            ),
          ),
          if (hasSchedule) ...[
            const SizedBox(height: 20),
            _buildMiniTimeline(isDark, res.schedule),
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isPrimary
                ? IrisTokens.purple
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary
                  ? Colors.white.withValues(alpha: 0.2)
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05)),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isPrimary
                      ? Colors.white
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.black.withValues(alpha: 0.9)),
                ),
              ),
            ],
          ),
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
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                res.status == 'live' ? 'CURRENTLY TEACHING' : 'CURRENT STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: statusColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            res.headline,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            res.subline,
            style: TextStyle(
              fontSize: 13,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTimeline(bool isDark, List<ClassSession> sessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'TODAY\'S SCHEDULE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final s = sessions[idx];
            final now = DateTime.now();
            final isLive = s.isLive(now);
            return GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.startTime,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        s.endTime,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.4),
                        ),
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${s.room} • ${s.batchKey.batch}',
                          style: TextStyle(
                            fontSize: 12,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.6),
                          ),
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
