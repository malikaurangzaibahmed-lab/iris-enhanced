import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import '../core/tokens.dart';
import '../core/models.dart';
import '../core/omni_brain.dart';
import '../core/glass.dart';
import '../core/theme_signals.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';
import '../widgets/dashboard_dock.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';
import '../core/vital_theme.dart'; // For ObsidianPulse
import '../main.dart'; // For ToolsScreen
import 'teacher_locator_screen.dart';
import 'portal_screen.dart';
import 'about_screen.dart';
import 'department_classes_screen.dart';
import 'students_week_screen.dart';

class MakeupLectureScheduler extends StatefulWidget {
  final UniversityMemory memory;
  final OmniBrain brain;
  final String batch;
  final Future<void> Function(ClassSession session) onAddMakeupClass;
  final Future<void> Function(ClassSession session)? onRemoveMakeupClass;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;
  final bool showDock;
  final bool showBackButton;

  const MakeupLectureScheduler({
    required this.memory,
    required this.brain,
    required this.batch,
    required this.onAddMakeupClass,
    this.onRemoveMakeupClass,
    this.onRoleChanged,
    this.onBatchChanged,
    this.showDock = true,
    this.showBackButton = true,
    super.key,
  });

  @override
  State<MakeupLectureScheduler> createState() => _MakeupLectureSchedulerState();
}

class _MakeupLectureSchedulerState extends State<MakeupLectureScheduler> {
  late TextEditingController _teacherController;
  String? _selectedTeacher;
  String? _selectedSuggestionKey;
  bool _autoSelectedTeacher = false;
  List<MakeupSlotSuggestion> _suggestions = [];
  List<MakeupSlotSuggestion> _filteredSuggestions = [];
  List<String> _filteredTeachers = [];
  bool _isLoading = false;
  final List<String> _allTeachers = [];

  // Smart filters
  int? _filterDayIndex;
  double _minDuration = 0.5;
  int _minRooms = 0;
  String _sortBy = 'earliest'; // 'earliest', 'duration', 'rooms'
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _teacherController = TextEditingController();
    // Get all teachers from memory
    final teachers = <String>{};
    for (final session in widget.memory.sessions) {
      teachers.add(session.teacher);
    }
    _allTeachers.addAll(teachers.toList()..sort());
    _filteredTeachers = List.from(_allTeachers);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait for route transition to complete before heavy slot discovery.
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) _autoSelectSmartTeacher();
      });
    });
  }

  @override
  void dispose() {
    _teacherController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateTeacherSuggestions(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredTeachers = List.from(_allTeachers));
      return;
    }
    final q = query.toLowerCase().trim();
    final matches = _allTeachers
        .where((t) => t.toLowerCase().contains(q))
        .toList();
    setState(() => _filteredTeachers = matches);
  }

  void _selectTeacher(String teacher) {
    setState(() {
      _selectedTeacher = teacher;
      _selectedSuggestionKey = null;
      _autoSelectedTeacher = false;
      _teacherController.text = teacher;
      _filteredTeachers = [];
    });
    IrisHaptics.chipSelect();
    _findMakeupSlots();
  }

  String? _pickSmartTeacherForBatch() {
    final now = DateTime.now();
    final nowVal = now.hour + (now.minute / 60.0);
    final batchSessions = widget.memory.sessions
        .where(
          (s) =>
              s.batchKey.batch == widget.batch && !s.id.startsWith('makeup_'),
        )
        .toList();
    if (batchSessions.isEmpty) return null;

    final today = batchSessions
        .where((s) => s.dayIndex == now.weekday)
        .toList();
    today.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    final live = today
        .where((s) => s.safeStartVal <= nowVal && nowVal < s.safeEndVal)
        .toList();
    if (live.isNotEmpty) return live.first.teacher;

    final upcoming = today.where((s) => s.safeStartVal > nowVal).toList();
    if (upcoming.isNotEmpty) return upcoming.first.teacher;

    final frequency = <String, int>{};
    for (final session in batchSessions) {
      final key = session.teacher.trim();
      if (key.isEmpty) continue;
      frequency.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    if (frequency.isEmpty) return null;
    return frequency.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  void _autoSelectSmartTeacher() {
    if (_selectedTeacher != null || _isLoading || _allTeachers.isEmpty) return;

    final smartTeacher = _pickSmartTeacherForBatch();
    if (smartTeacher == null || !_allTeachers.contains(smartTeacher)) return;

    setState(() {
      _selectedTeacher = smartTeacher;
      _teacherController.text = smartTeacher;
      _selectedSuggestionKey = null;
      _filteredTeachers = [];
      _autoSelectedTeacher = true;
    });

    _findMakeupSlots();
  }

  String _timeFromDecimal(double value) {
    final hour = value.floor().clamp(0, 23);
    final minute = ((value - value.floor()) * 60).round().clamp(0, 59);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _slotKey(MakeupSlotSuggestion suggestion) {
    final teacherKey = (_selectedTeacher ?? '').trim().toLowerCase();
    return '${suggestion.dayIndex}_${suggestion.startTime.toStringAsFixed(3)}_${suggestion.endTime.toStringAsFixed(3)}_$teacherKey';
  }

  bool _sameTimeSlot(ClassSession session, MakeupSlotSuggestion suggestion) {
    return session.dayIndex == suggestion.dayIndex &&
        (session.safeStartVal - suggestion.startTime).abs() < 0.001 &&
        (session.safeEndVal - suggestion.endTime).abs() < 0.001;
  }

  ClassSession? _existingMakeupSessionForSuggestion(
    MakeupSlotSuggestion suggestion,
  ) {
    final teacher = _selectedTeacher?.trim().toLowerCase();
    if (teacher == null || teacher.isEmpty) return null;

    for (final session in widget.memory.sessions) {
      if (!session.id.startsWith('makeup_')) continue;
      if (session.batchKey.batch != widget.batch) continue;
      if (session.teacher.trim().toLowerCase() != teacher) continue;
      if (_sameTimeSlot(session, suggestion)) return session;
    }
    return null;
  }

  bool _sessionsOverlapWithSuggestion(
    ClassSession session,
    MakeupSlotSuggestion suggestion,
  ) {
    if (session.dayIndex != suggestion.dayIndex) return false;
    return session.safeStartVal < suggestion.endTime &&
        suggestion.startTime < session.safeEndVal;
  }

  ClassSession? _regularConflictForSuggestion(MakeupSlotSuggestion suggestion) {
    for (final session in widget.memory.sessions) {
      if (session.batchKey.batch != widget.batch) continue;
      if (session.id.startsWith('makeup_')) continue;
      if (_sessionsOverlapWithSuggestion(session, suggestion)) return session;
    }
    return null;
  }

  List<ClassSession> _overlappingMakeupsForSuggestion(
    MakeupSlotSuggestion suggestion,
  ) {
    final teacher = _selectedTeacher?.trim().toLowerCase();
    return widget.memory.sessions.where((session) {
      if (!session.id.startsWith('makeup_')) return false;
      if (session.batchKey.batch != widget.batch) return false;
      if (!_sessionsOverlapWithSuggestion(session, suggestion)) return false;
      if (teacher != null &&
          teacher.isNotEmpty &&
          session.teacher.trim().toLowerCase() == teacher &&
          _sameTimeSlot(session, suggestion)) {
        return false;
      }
      return true;
    }).toList();
  }

  String _inferMakeupSubject(String teacher) {
    final teacherKey = teacher.trim().toLowerCase();
    final frequency = <String, int>{};
    for (final session in widget.memory.sessions) {
      if (session.batchKey.batch != widget.batch) continue;
      if (session.id.startsWith('makeup_')) continue;
      if (session.teacher.trim().toLowerCase() != teacherKey) continue;
      final subject = session.subject.trim();
      if (subject.isEmpty) continue;
      frequency.update(subject, (count) => count + 1, ifAbsent: () => 1);
    }
    if (frequency.isEmpty) return 'Makeup Class';
    return frequency.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _pickBestRoom(MakeupSlotSuggestion suggestion, String teacher) {
    final available = suggestion.availableRooms;
    if (available == null || available.isEmpty) {
      return 'TBD';
    }

    final teacherKey = teacher.trim().toLowerCase();
    final roomFrequency = <String, int>{};
    for (final session in widget.memory.sessions) {
      if (session.batchKey.batch != widget.batch) continue;
      if (session.teacher.trim().toLowerCase() != teacherKey) continue;
      final room = session.room.trim();
      if (room.isEmpty) continue;
      roomFrequency.update(room, (count) => count + 1, ifAbsent: () => 1);
    }

    final rankedRooms = available.toList();
    rankedRooms.sort((a, b) {
      final aScore = roomFrequency[a] ?? 0;
      final bScore = roomFrequency[b] ?? 0;
      return bScore.compareTo(aScore);
    });

    return rankedRooms.first;
  }

  ClassSession _buildMakeupSession(MakeupSlotSuggestion suggestion) {
    final teacher = _selectedTeacher ?? 'Unknown Teacher';
    final inferredSubject = _inferMakeupSubject(teacher);
    final start = _timeFromDecimal(suggestion.startTime);
    final end = _timeFromDecimal(suggestion.endTime);
    final room = _pickBestRoom(suggestion, teacher);
    final teacherSlug = teacher
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final slotSlug =
        '${suggestion.dayIndex}_${(suggestion.startTime * 100).round()}_${(suggestion.endTime * 100).round()}';

    return ClassSession(
      id: 'makeup_${widget.batch}_${teacherSlug}_$slotSlug',
      batchKey: BatchKey.parse(widget.batch),
      dayIndex: suggestion.dayIndex,
      startTime: start,
      endTime: end,
      subject: inferredSubject,
      teacher: teacher,
      room: room,
    );
  }

  Future<void> _handleSuggestionAction(MakeupSlotSuggestion suggestion) async {
    if (_selectedTeacher == null || _selectedTeacher!.isEmpty) return;

    final existing = _existingMakeupSessionForSuggestion(suggestion);
    final regularConflict = _regularConflictForSuggestion(suggestion);

    if (existing == null && regularConflict != null) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_slot_conflict_${regularConflict.id}',
        content: Text(
          'Cannot add: conflicts with ${regularConflict.subject} (${regularConflict.startTime}-${regularConflict.endTime}).',
        ),
      );
      return;
    }

    if (existing != null) {
      if (widget.onRemoveMakeupClass != null) {
        await widget.onRemoveMakeupClass!(existing);
      }
    } else {
      final session = _buildMakeupSession(suggestion);
      await widget.onAddMakeupClass(session);
    }

    if (!mounted) return;
    setState(() {});
  }

  void _findMakeupSlots() {
    if (_selectedTeacher == null || _selectedTeacher!.isEmpty) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_select_teacher_first',
        content: const Text('Please select a teacher'),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Yield one frame so loading state can paint before heavy computation starts.
    Future.delayed(Duration.zero, () {
      if (!mounted) return;

      final computed = widget.brain.findMakeupSlots(
        widget.batch,
        _selectedTeacher!,
      );
      setState(() {
        _suggestions = computed;
        _applyFiltersAndSort();
      });

      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() => _isLoading = false);

          if (_filteredSuggestions.isEmpty) {
            showIrisFrostedSnackBar(
              context,
              dedupeKey: _suggestions.isEmpty
                  ? 'makeup_slots_none_common'
                  : 'makeup_slots_none_filtered',
              content: Text(
                _suggestions.isEmpty
                    ? 'No common free slots found'
                    : 'No slots match your filters. Try adjusting them.',
              ),
            );
          }
        }
      });
    });
  }

  Future<void> _openTeacherFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: TeacherLocatorScreen(
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
        memory: widget.memory,
        currentBatch: widget.batch,
      ),
    );
  }

  Future<void> _openPortalFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: const PortalScreen(
        url: 'https://swl-sis.comsats.edu.pk/',
        title: 'COMSATS Student Portal',
        sessionScope: 'student',
      ),
    );
  }

  Future<void> _openClassesFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: DepartmentClassesScreen(
        memory: widget.memory,
        currentBatch: widget.batch,
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
        onAddMakeupClass: widget.onAddMakeupClass,
        onRemoveMakeupClass: widget.onRemoveMakeupClass,
      ),
    );
  }

  Future<void> _openToolsFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: ToolsScreen(
        memory: widget.memory,
        batch: widget.batch,
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
        onAddMakeupClass: widget.onAddMakeupClass,
        onRemoveMakeupClass: widget.onRemoveMakeupClass,
      ),
    );
  }

  Future<void> _openAboutFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: AboutScreen(
        memory: widget.memory,
        onRoleChanged: widget.onRoleChanged,
        onBatchChanged: widget.onBatchChanged,
      ),
    );
  }

  void _applyFiltersAndSort() {
    var filtered = List<MakeupSlotSuggestion>.from(_suggestions);

    // Apply filters
    if (_filterDayIndex != null) {
      filtered = filtered.where((s) => s.dayIndex == _filterDayIndex).toList();
    }
    if (_minDuration > 0.5) {
      filtered = filtered
          .where((s) => s.durationHours >= _minDuration)
          .toList();
    }
    if (_minRooms > 0) {
      filtered = filtered
          .where(
            (s) =>
                s.availableRooms != null &&
                s.availableRooms!.length >= _minRooms,
          )
          .toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'earliest':
        filtered.sort((a, b) {
          final dayCompare = a.dayIndex.compareTo(b.dayIndex);
          if (dayCompare != 0) return dayCompare;
          return a.startTime.compareTo(b.startTime);
        });
        break;
      case 'duration':
        filtered.sort((a, b) => b.durationHours.compareTo(a.durationHours));
        break;
      case 'rooms':
        filtered.sort((a, b) {
          final aRooms = a.availableRooms?.length ?? 0;
          final bRooms = b.availableRooms?.length ?? 0;
          return bRooms.compareTo(aRooms);
        });
        break;
    }

    _filteredSuggestions = filtered;
  }

  void _resetFilters() {
    setState(() {
      _filterDayIndex = null;
      _minDuration = 0.5;
      _minRooms = 0;
      _sortBy = 'earliest';
      _applyFiltersAndSort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const purple = IrisTokens.purple;
    const purpleLight = IrisTokens.purpleLight;
    const indigo = IrisTokens.brand;
    const amber = Color(0xFFF59E0B);

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
          // Neural aura background
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Header
                  DirectoryAnimationWidget(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
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
                                  color: purple.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.schedule_rounded,
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
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [purple, purpleLight],
                                      ).createShader(bounds),
                                  child: const Text(
                                    'Schedule Makeup',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 26,
                                      letterSpacing: 0.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Find free slots with your teacher',
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
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Search card
                  GlassCard(
                    enableOverlay: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: purple.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Teacher',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.7),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Search field
                        AnimatedContainer(
                          duration: IrisMotion.fast,
                          curve: IrisMotion.standard,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      Colors.black.withValues(alpha: 0.50),
                                      Colors.black.withValues(alpha: 0.45),
                                    ]
                                  : [
                                      Colors.white.withValues(alpha: 0.85),
                                      Colors.white.withValues(alpha: 0.80),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              IrisTokens.radius20,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : IrisTokens.brand.withValues(alpha: 0.10),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: IrisTokens.brand.withValues(
                                  alpha: isDark ? 0.08 : 0.06,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                                spreadRadius: -2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.25 : 0.04,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _teacherController,
                            onChanged: (value) {
                              _updateTeacherSuggestions(value);
                              setState(() {});
                            },
                            textInputAction: TextInputAction.search,
                            enabled: !_isLoading,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search by name...',
                              hintStyle: TextStyle(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.40),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                              prefixIcon: const Icon(
                                Icons.person_search_rounded,
                                color: IrisTokens.brand,
                                size: 24,
                              ),
                              suffixIcon:
                                  _selectedTeacher != null ||
                                      _teacherController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.45),
                                        size: 22,
                                      ),
                                      splashRadius: 22,
                                      onPressed: () {
                                        IrisHaptics.actionSoft();
                                        _teacherController.clear();
                                        setState(() {
                                          _selectedTeacher = null;
                                          _selectedSuggestionKey = null;
                                          _autoSelectedTeacher = false;
                                          _filteredTeachers = List.from(
                                            _allTeachers,
                                          );
                                          _suggestions = [];
                                          _filteredSuggestions = [];
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: IrisTokens.space20,
                                vertical: IrisTokens.space20,
                              ),
                            ),
                          ),
                        ),
                        // Filtered suggestions dropdown
                        if (_filteredTeachers.isNotEmpty &&
                            _teacherController.text.isNotEmpty)
                          Column(
                            children: [
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : Colors.black.withValues(alpha: 0.06),
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  maxHeight: 220,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  itemCount: _filteredTeachers.length,
                                  itemBuilder: (context, index) {
                                    final teacher = _filteredTeachers[index];
                                    final isSelected =
                                        _selectedTeacher == teacher;
                                    return InkWell(
                                      onTap: () => _selectTeacher(teacher),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? purple.withValues(alpha: 
                                                  isDark ? 0.16 : 0.10,
                                                )
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? Icons.check_circle_rounded
                                                  : Icons.person_rounded,
                                              size: 16,
                                              color: isSelected
                                                  ? purple
                                                  : (isDark
                                                            ? Colors.white
                                                            : Colors.black)
                                                        .withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                teacher,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        if (_selectedTeacher != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: purple.withValues(alpha: isDark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: purple.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                  color: IrisTokens.purple,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedTeacher!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 
                                      isDark ? 0.08 : 0.7,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _autoSelectedTeacher
                                        ? 'Smart Pick'
                                        : 'Selected',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Find Slots Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _selectedTeacher == null
                          ? null
                          : _findMakeupSlots,
                      icon: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(
                        _isLoading ? 'Searching...' : 'Find Available Slots',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: purple.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                        shadowColor: purple.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Results with Filters and Sort
                  if (_suggestions.isNotEmpty) ...[
                    // Statistics Summary
                    GlassCard(
                      enableOverlay: false,
                      enableShadow: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics_rounded,
                                size: 16,
                                color: purple.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Summary',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                Icons.event_available_rounded,
                                _filteredSuggestions.length.toString(),
                                'Slots',
                                isDark,
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: purple.withValues(alpha: 0.2),
                              ),
                              _buildStatItem(
                                Icons.access_time_rounded,
                                '${_filteredSuggestions.fold<double>(0, (sum, s) => sum + s.durationHours).toStringAsFixed(1)}h',
                                'Total',
                                isDark,
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: purple.withValues(alpha: 0.2),
                              ),
                              _buildStatItem(
                                Icons.meeting_room_rounded,
                                _filteredSuggestions
                                    .where(
                                      (s) =>
                                          (s.availableRooms?.isNotEmpty ??
                                          false),
                                    )
                                    .length
                                    .toString(),
                                'With Rooms',
                                isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filter & Sort Controls
                    GlassCard(
                      enableOverlay: false,
                      enableShadow: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 16,
                                color: purple.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Filters & Sorting',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _resetFilters,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: amber.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: amber.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'Reset',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: amber,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Day Filter
                              Expanded(
                                child: lgw.GlassMenu(
                                  menuWidth: 160,
                                  menuHeight: 330.0,
                                  menuAlignment: lgw.GlassMenuAlignment.bottomCenter,
                                  triggerBuilder: (context, toggleMenu) {
                                    return _buildFilterChip(
                                      icon: Icons.calendar_today_rounded,
                                      label: _filterDayIndex == null
                                          ? 'All Days'
                                          : [
                                              'Mon',
                                              'Tue',
                                              'Wed',
                                              'Thu',
                                              'Fri',
                                              'Sat',
                                              'Sun',
                                            ][_filterDayIndex! - 1],
                                      onTap: () {
                                        IrisHaptics.actionSoft();
                                        toggleMenu();
                                      },
                                      isDark: isDark,
                                    );
                                  },
                                  items: [
                                    lgw.GlassMenuItem(
                                      title: 'All Days',
                                      onTap: () {
                                        setState(() {
                                          _filterDayIndex = null;
                                          _applyFiltersAndSort();
                                        });
                                      },
                                    ),
                                    ...List.generate(7, (i) {
                                      final days = [
                                        'Monday',
                                        'Tuesday',
                                        'Wednesday',
                                        'Thursday',
                                        'Friday',
                                        'Saturday',
                                        'Sunday',
                                      ];
                                      return lgw.GlassMenuItem(
                                        title: days[i],
                                        onTap: () {
                                          setState(() {
                                            _filterDayIndex = i + 1;
                                            _applyFiltersAndSort();
                                          });
                                        },
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Sort
                              Expanded(
                                child: lgw.GlassMenu(
                                  menuWidth: 180,
                                  menuHeight: 142.0,
                                  menuAlignment: lgw.GlassMenuAlignment.bottomCenter,
                                  triggerBuilder: (context, toggleMenu) {
                                    return _buildFilterChip(
                                      icon: Icons.sort_rounded,
                                      label: _sortBy == 'earliest'
                                          ? 'Earliest'
                                          : _sortBy == 'duration'
                                          ? 'Longest'
                                          : 'Most Rooms',
                                      onTap: () {
                                        IrisHaptics.actionSoft();
                                        toggleMenu();
                                      },
                                      isDark: isDark,
                                    );
                                  },
                                  items: [
                                    lgw.GlassMenuItem(
                                      title: 'Earliest First',
                                      onTap: () {
                                        setState(() {
                                          _sortBy = 'earliest';
                                          _applyFiltersAndSort();
                                        });
                                      },
                                    ),
                                    lgw.GlassMenuItem(
                                      title: 'Longest Duration',
                                      onTap: () {
                                        setState(() {
                                          _sortBy = 'duration';
                                          _applyFiltersAndSort();
                                        });
                                      },
                                    ),
                                    lgw.GlassMenuItem(
                                      title: 'Most Rooms Available',
                                      onTap: () {
                                        setState(() {
                                          _sortBy = 'rooms';
                                          _applyFiltersAndSort();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Slots Header
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [purple, purpleLight],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Available Slots',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_filteredSuggestions.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Slots List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredSuggestions.length,
                      separatorBuilder: (_, index2) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final suggestion = _filteredSuggestions[index];
                        return _buildMakeupSlotCard(suggestion, isDark);
                      },
                    ),
                    const SizedBox(height: 20),
                  ] else if (!_isLoading && _selectedTeacher != null) ...[
                    GlassCard(
                      enableOverlay: false,
                      enableShadow: false,
                      child: Row(
                        children: [
                          Icon(Icons.info_rounded, color: amber, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'No common free slots found. Try another teacher.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: DashboardDock(
                  scrollController: _scrollController,
                  selectedIndex: 5,
                  onTeacher: _openTeacherFromMakeup,
                  onPortal: _openPortalFromMakeup,
                  onClasses: _openClassesFromMakeup,
                  onTools: _openToolsFromMakeup,
                  onMakeup: () {},
                  onAbout: _openAboutFromMakeup,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMakeupSlotCard(MakeupSlotSuggestion suggestion, bool isDark) {
    final slotKey = _slotKey(suggestion);
    final isSelected = _selectedSuggestionKey == slotKey;
    final existing = _existingMakeupSessionForSuggestion(suggestion);
    final isAdded = existing != null;
    final regularConflict = _regularConflictForSuggestion(suggestion);
    final overlappingMakeups = _overlappingMakeupsForSuggestion(suggestion);
    final isBlocked = regularConflict != null && !isAdded;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IrisTokens.brand.withValues(
              alpha: isSelected
                  ? (isDark ? 0.22 : 0.14)
                  : (isDark ? 0.14 : 0.08),
            ),
            IrisTokens.brandLight.withValues(
              alpha: isSelected
                  ? (isDark ? 0.14 : 0.10)
                  : (isDark ? 0.10 : 0.06),
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? IrisTokens.brand.withValues(alpha: 0.46)
              : IrisTokens.brand.withValues(alpha: 0.28),
          width: isSelected ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: IrisTokens.brand.withValues(alpha: isDark ? 0.2 : 0.12),
            blurRadius: isSelected ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _selectedSuggestionKey = slotKey);
          IrisHaptics.actionSoft();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day and Time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [IrisTokens.brand, IrisTokens.brandLight],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      suggestion.dayName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion.timeRangeString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: IrisTokens.brand,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: IrisTokens.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: IrisTokens.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${suggestion.durationHours.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: IrisTokens.success,
                      ),
                    ),
                  ),
                ],
              ),
              if (isAdded) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: IrisTokens.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.success.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: IrisTokens.success,
                        size: 15,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Already in your timeline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: IrisTokens.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isBlocked) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: IrisTokens.error.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.error.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: IrisTokens.error,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Conflicts with ${regularConflict.subject} (${regularConflict.startTime}-${regularConflict.endTime})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: IrisTokens.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (!isAdded && overlappingMakeups.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: IrisTokens.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.brand.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.autorenew_rounded,
                        color: IrisTokens.brand,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Will replace ${overlappingMakeups.length} overlapping makeup slot${overlappingMakeups.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: IrisTokens.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Suggested free window',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.55,
                  ),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),

              // Available Rooms
              if (suggestion.availableRooms != null &&
                  suggestion.availableRooms!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: IrisTokens.success.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.success.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_rounded,
                            size: 16,
                            color: IrisTokens.success,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Available Rooms (${suggestion.availableRooms!.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: IrisTokens.success,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: suggestion.availableRooms!
                            .take(10) // Show max 10 rooms
                            .map(
                              (room) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: IrisTokens.success.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: IrisTokens.success.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  room,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (suggestion.availableRooms!.length > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+${suggestion.availableRooms!.length - 10} more rooms',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: IrisTokens.success.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.orange.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No rooms available during this slot',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedTeacher == null || isBlocked)
                      ? null
                      : () => _handleSuggestionAction(suggestion),
                  icon: Icon(
                    isBlocked
                        ? Icons.block_rounded
                        : (isAdded
                              ? Icons.remove_circle_outline_rounded
                              : Icons.add_circle_outline_rounded),
                  ),
                  label: Text(
                    isBlocked
                        ? 'Conflicting Slot'
                        : (isAdded
                              ? 'Remove From Timeline'
                              : 'Add To Timeline'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlocked
                        ? (isDark ? Colors.white24 : Colors.black26)
                        : (isAdded ? IrisTokens.error : IrisTokens.brand),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              if (!isAdded && !isBlocked) ...[
                const SizedBox(height: 8),
                Text(
                  overlappingMakeups.isNotEmpty
                      ? 'This will replace overlapping makeup slots and keep restore history.'
                      : 'If this overlaps another makeup slot, the app replaces it intelligently.',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    bool isDark,
  ) {
    return Column(
      children: [
        Icon(icon, color: IrisTokens.brand, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: IrisTokens.brand.withValues(alpha: isDark ? 0.16 : 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.3)),
          boxShadow: const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: IrisTokens.brand),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDayFilter(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => GlassSurface(
        settings: IrisGlass.settings(
          ctx,
          blur: 16,
          ambientStrength: 0.70,
          lightAngle: 0.15 * math.pi,
          thickness: 15,
          glassColor: Colors.black.withValues(alpha: 0.05),
          minBlur: 10,
          minThickness: 12,
        ),
        radius: 20,
        child: AlertDialog(
            backgroundColor: (isDark ? const Color(0xFF111827) : Colors.white)
                .withValues(alpha: isDark ? 0.88 : 0.92),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.12,
              ),
            ),
          ),
          title: const Text('Filter by Day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Days'),
                leading: Radio<int?>(
                  value: null,
                  groupValue: _filterDayIndex,
                  activeColor: IrisTokens.brand,
                  onChanged: (val) {
                    setState(() {
                      _filterDayIndex = val;
                      _applyFiltersAndSort();
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
              ...List.generate(7, (i) {
                final days = [
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday',
                ];
                return ListTile(
                  title: Text(days[i]),
                  leading: Radio<int?>(
                    value: i + 1,
                    groupValue: _filterDayIndex,
                    activeColor: IrisTokens.brand,
                    onChanged: (val) {
                      setState(() {
                        _filterDayIndex = val;
                        _applyFiltersAndSort();
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
}

  void _showSortOptions(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => GlassSurface(
        settings: IrisGlass.settings(
          ctx,
          blur: 16,
          ambientStrength: 0.70,
          lightAngle: 0.15 * math.pi,
          thickness: 15,
          glassColor: Colors.black.withValues(alpha: 0.05),
          minBlur: 10,
          minThickness: 12,
        ),
        radius: 20,
        child: AlertDialog(
            backgroundColor: (isDark ? const Color(0xFF111827) : Colors.white)
                .withValues(alpha: isDark ? 0.88 : 0.92),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.12,
              ),
            ),
          ),
          title: const Text('Sort By'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ListTile(
              title: const Text('Earliest First'),
              leading: Radio<String>(
                value: 'earliest',
                groupValue: _sortBy,
                activeColor: IrisTokens.brand,
                onChanged: (val) {
                  setState(() {
                    _sortBy = val!;
                    _applyFiltersAndSort();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            ListTile(
              title: const Text('Longest Duration'),
              leading: Radio<String>(
                value: 'duration',
                groupValue: _sortBy,
                activeColor: IrisTokens.brand,
                onChanged: (val) {
                  setState(() {
                    _sortBy = val!;
                    _applyFiltersAndSort();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            ListTile(
              title: const Text('Most Rooms Available'),
              leading: Radio<String>(
                value: 'rooms',
                groupValue: _sortBy,
                activeColor: IrisTokens.brand,
                onChanged: (val) {
                  setState(() {
                    _sortBy = val!;
                    _applyFiltersAndSort();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            ],
          ),
        ),
      ),
    );
}
}
