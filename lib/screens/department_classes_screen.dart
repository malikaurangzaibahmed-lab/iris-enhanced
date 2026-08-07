import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import '../core/glass.dart';
import '../core/theme_signals.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../core/omni_brain.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';
import '../widgets/dashboard_dock.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';
import '../core/vital_theme.dart'; // For ObsidianPulse
import '../main.dart'; // For ToolsScreen
import 'portal_screen.dart';
import 'teacher_locator_screen.dart';
import 'about_screen.dart';
import '../services/remote_config_service.dart';

class DepartmentClassesScreen extends StatefulWidget {
  final UniversityMemory memory;
  final String currentBatch;
  final OmniBrain? brain;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;
  final bool showDock;
  final bool showBackButton;
  final Future<void> Function(ClassSession session)? onAddMakeupClass;
  final Future<void> Function(ClassSession session)? onRemoveMakeupClass;

  const DepartmentClassesScreen({
    required this.memory,
    required this.currentBatch,
    this.brain,
    this.onRoleChanged,
    this.onBatchChanged,
    this.showDock = true,
    this.showBackButton = true,
    this.onAddMakeupClass,
    this.onRemoveMakeupClass,
    super.key,
  });

  @override
  State<DepartmentClassesScreen> createState() =>
      _DepartmentClassesScreenState();
}

class _DepartmentClassesScreenState extends State<DepartmentClassesScreen> {
  String? selectedProgram;
  int? selectedSemester;
  String? selectedSection;
  int? selectedDay;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Filter out batch-like programs and select the first valid one
    final validPrograms = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toList();
    if (validPrograms.isNotEmpty) {
      selectedProgram = validPrograms.first;
      final semesters = widget.memory.semesters(selectedProgram!);
      if (semesters.isNotEmpty) {
        selectedSemester = semesters.first;
        final sections = widget.memory
            .sections(selectedProgram!, selectedSemester!);
        if (sections.isNotEmpty) {
          selectedSection = sections.first;
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _jumpToMyBatch() {
    final rawBatch = widget.currentBatch.trim();
    if (rawBatch.isEmpty) return;

    final key = BatchKey.parse(rawBatch);
    final prog = key.program.toUpperCase();
    final sem = key.dynamicSemester;
    final sec = key.section.toUpperCase();

    final validPrograms = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toList();

    final matchedProgram = validPrograms.firstWhere(
      (p) => p.toUpperCase() == prog || p.toUpperCase().contains(prog) || prog.contains(p.toUpperCase()),
      orElse: () => validPrograms.isNotEmpty ? validPrograms.first : '',
    );

    if (matchedProgram.isNotEmpty) {
      setState(() {
        selectedProgram = matchedProgram;
        final sems = widget.memory.semesters(matchedProgram);
        if (sems.contains(sem)) {
          selectedSemester = sem;
        } else if (sems.isNotEmpty) {
          selectedSemester = sems.first;
        }
        if (selectedSemester != null) {
          final secs = widget.memory.sections(matchedProgram, selectedSemester!);
          if (sec.isNotEmpty && secs.contains(sec)) {
            selectedSection = sec;
          } else if (secs.isNotEmpty) {
            selectedSection = secs.first;
          }
        }
      });
      IrisHaptics.actionMedium();
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'jump_to_my_batch',
        content: Text('Switched to My Batch ($rawBatch)'),
      );
    }
  }

  Future<void> _shareCurrentTimetableText(BuildContext context, List<ClassSession> sessions) async {
    IrisHaptics.actionMedium();
    final batchStr = (selectedProgram != null && selectedSemester != null && selectedSection != null)
        ? '$selectedProgram-$selectedSemester$selectedSection'
        : 'Department Schedule';

    final buffer = StringBuffer();
    buffer.writeln('📅 COMSATS University - Class Schedule');
    buffer.writeln('👥 Batch / Program: $batchStr');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');

    if (sessions.isEmpty) {
      buffer.writeln('🎉 No scheduled classes listed.');
    } else {
      for (final s in sessions) {
        final timeStr = s.endTime.isNotEmpty ? '${s.startTime} - ${s.endTime}' : s.startTime;
        buffer.writeln('• $timeStr | ${s.subject}');
        final loc = s.room.isNotEmpty ? '📍 ${s.room}' : '';
        final prof = s.teacher.isNotEmpty ? '👤 ${s.teacher}' : '';
        if (loc.isNotEmpty || prof.isNotEmpty) {
          buffer.writeln('  $loc ${loc.isNotEmpty && prof.isNotEmpty ? '| ' : ''}$prof');
        }
      }
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📱 Shared via IRIS Campus Operating System');

    final text = buffer.toString();
    await Clipboard.setData(ClipboardData(text: text));

    try {
      final encoded = Uri.encodeComponent(text);
      final whatsappUri = Uri.parse('whatsapp://send?text=$encoded');
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        if (context.mounted) {
          showIrisFrostedSnackBar(
            context,
            content: const Text('Schedule copied to clipboard! Ready to paste & share.'),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        showIrisFrostedSnackBar(
          context,
          content: const Text('Schedule copied to clipboard! Ready to paste & share.'),
        );
      }
    }
  }

  void _showGlassPicker({
    required String title,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (context) {
        String filterQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final glassSettings = IrisGlass.settings(
              context,
              blur: 24,
              ambientStrength: 0.8,
              lightAngle: 0.15 * math.pi,
              thickness: 18,
              glassColor: IrisGlass.adaptiveGlassColor(context, darkAlpha: 0.85, lightAlpha: 0.9),
            );

            final filteredOptions = filterQuery.isEmpty
                ? options
                : options.where((o) => o.toLowerCase().contains(filterQuery.toLowerCase())).toList();

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: GlassSurface(
                settings: glassSettings,
                radius: 30,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white30 : Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: IrisTextStyles.headline(context).copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: IrisTokens.brand.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${filteredOptions.length} items',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: IrisTokens.brand,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (options.length > 5) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
                            ),
                          ),
                          child: TextField(
                            onChanged: (val) => setSheetState(() => filterQuery = val.trim()),
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Filter $title...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                              ),
                              border: InputBorder.none,
                              icon: Icon(Icons.search_rounded, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                          ),
                          child: filteredOptions.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'No matching options',
                                    style: TextStyle(
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: filteredOptions.length,
                                  itemBuilder: (context, index) {
                                    final option = filteredOptions[index];
                                    final isSelected = option == selectedValue;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            IrisHaptics.selectionClick();
                                            onSelected(option);
                                            Navigator.of(context).pop();
                                          },
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? IrisTokens.brand.withValues(alpha: 0.14)
                                                  : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSelected
                                                    ? IrisTokens.brand.withValues(alpha: 0.35)
                                                    : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  option,
                                                  style: TextStyle(
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                    fontSize: 13,
                                                    color: isSelected
                                                        ? (isDark ? Colors.white : IrisTokens.brand)
                                                        : (isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87),
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    color: isDark ? Colors.white : IrisTokens.brand,
                                                    size: 18,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGlassInputPill({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: (isDark ? Colors.white54 : Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validPrograms = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toList();

    // Compute the options based on current selections
    final semesters = selectedProgram != null
        ? widget.memory.semesters(selectedProgram!)
        : const <int>[];
    final sections = (selectedProgram != null && selectedSemester != null)
        ? widget.memory.sections(
            selectedProgram!, selectedSemester!)
        : const <String>[];

    final allSessions = (selectedProgram != null &&
            selectedSemester != null &&
            selectedSection != null)
        ? widget.memory.activeSessions()
            .where((s) =>
                s.batchKey.program == selectedProgram &&
                s.batchKey.semester == selectedSemester &&
                s.batchKey.section == selectedSection)
            .toList()
        : const <ClassSession>[];

    // Filter by day if selected
    var displayedSessions = allSessions;
    if (selectedDay != null) {
      displayedSessions =
          allSessions.where((s) => s.dayIndex == selectedDay).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      displayedSessions = displayedSessions.where((s) {
        final subject = s.subject.toLowerCase();
        final teacher = s.teacher.toLowerCase();
        final room = s.room.toLowerCase();
        final batch = s.batchKey.batch.toLowerCase();
        return subject.contains(q) ||
            teacher.contains(q) ||
            room.contains(q) ||
            batch.contains(q);
      }).toList();
    }

    displayedSessions.sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

    final today = DateTime.now().weekday;
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final smartDays = [1, 2, 3, 4, 5];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: widget.showBackButton
          ? AppBar(
              backgroundColor: Colors.transparent,
              forceMaterialTransparency: true,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: AppBackButton(isDark: isDark),
            )
          : null,
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: IrisTokens.brandGradient,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.domain_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Department Classes',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                      if (widget.currentBatch.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _jumpToMyBatch,
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: IrisTokens.brand.withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: IrisTokens.brand.withValues(alpha: 0.32),
                                                  width: 0.9,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.bolt_rounded, size: 13, color: IrisTokens.brand),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'My Batch',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: IrisTokens.brand,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => _shareCurrentTimetableText(context, displayedSessions),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: IrisTokens.brand.withValues(alpha: isDark ? 0.18 : 0.10),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: IrisTokens.brand.withValues(alpha: 0.3),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.share_rounded, size: 13, color: IrisTokens.brand),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Share',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: IrisTokens.brand,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ValueListenableBuilder<String>(
                                    valueListenable: RemoteConfigService.activeAcademicPeriod,
                                    builder: (context, period, _) {
                                      String subText = 'Browse classes for any program or semester.';
                                      if (period == 'ramadan') {
                                        subText = '🌙 RAMADAN ACTIVE: Compressed Ramadan lecture timings in effect.';
                                      } else if (period == 'midterms') {
                                        subText = '📝 MIDTERMS ACTIVE: Showing exam paper datesheets & halls.';
                                      } else if (period == 'finals') {
                                        subText = '🎓 FINALS ACTIVE: Showing final datesheets, halls & invigilators.';
                                      } else if (period == 'sports_week') {
                                        subText = '🏆 GALA ACTIVE: Showing sports week events & match schedules.';
                                      }
                                      return Text(
                                        subText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: period == 'classes' ? FontWeight.w500 : FontWeight.w700,
                                          color: period == 'classes'
                                              ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6)
                                              : (period == 'ramadan' || period == 'sports_week'
                                                  ? const Color(0xFF10B981)
                                                  : (period == 'midterms' ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6))),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Smart Search Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                size: 16,
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Search course, teacher, room, or batch...',
                                    hintStyle: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.38),
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Dropdowns Selector Card
                        GlassCard(
                          enableOverlay: false,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: lgw.GlassMenu(
                                        menuWidth: 180,
                                        menuHeight: math.min(validPrograms.length * 48.0 + 16.0, 220.0),
                                        menuBorderRadius: 18.0,
                                        triggerBuilder: (context, toggleMenu) {
                                          return _buildGlassInputPill(
                                            title: 'PROGRAM',
                                            value: selectedProgram ?? 'None',
                                            onTap: toggleMenu,
                                          );
                                        },
                                        items: validPrograms.map((p) {
                                          final isSelected = p == selectedProgram;
                                          return lgw.GlassMenuItem(
                                            title: p,
                                            isSelected: isSelected,
                                            onTap: () {
                                              setState(() {
                                                selectedProgram = p;
                                                final newSemesters = widget.memory.semesters(p);
                                                if (newSemesters.isNotEmpty) {
                                                  selectedSemester = newSemesters.first;
                                                  final newSections = widget.memory.sections(p, selectedSemester!);
                                                  if (newSections.isNotEmpty) {
                                                    selectedSection = newSections.first;
                                                  } else {
                                                    selectedSection = null;
                                                  }
                                                } else {
                                                  selectedSemester = null;
                                                  selectedSection = null;
                                                }
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: lgw.GlassMenu(
                                        menuWidth: 150,
                                        menuHeight: math.min(semesters.length * 48.0 + 16.0, 220.0),
                                        menuBorderRadius: 18.0,
                                        triggerBuilder: (context, toggleMenu) {
                                          return _buildGlassInputPill(
                                            title: 'SEMESTER',
                                            value: selectedSemester != null ? 'Sem $selectedSemester' : 'None',
                                            onTap: toggleMenu,
                                          );
                                        },
                                        items: semesters.map((s) {
                                          final isSelected = s == selectedSemester;
                                          return lgw.GlassMenuItem(
                                            title: 'Semester $s',
                                            isSelected: isSelected,
                                            onTap: () {
                                              setState(() {
                                                selectedSemester = s;
                                                if (selectedProgram != null) {
                                                  final newSections = widget.memory.sections(selectedProgram!, s);
                                                  if (newSections.isNotEmpty) {
                                                    selectedSection = newSections.first;
                                                  } else {
                                                    selectedSection = null;
                                                  }
                                                }
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: lgw.GlassMenu(
                                        menuWidth: 140,
                                        menuHeight: math.min(sections.length * 48.0 + 16.0, 220.0),
                                        menuBorderRadius: 18.0,
                                        triggerBuilder: (context, toggleMenu) {
                                          return _buildGlassInputPill(
                                            title: 'SECTION',
                                            value: selectedSection != null ? 'Sec $selectedSection' : 'None',
                                            onTap: toggleMenu,
                                          );
                                        },
                                        items: sections.map((sec) {
                                          final isSelected = sec == selectedSection;
                                          return lgw.GlassMenuItem(
                                            title: 'Section $sec',
                                            isSelected: isSelected,
                                            onTap: () {
                                              setState(() {
                                                selectedSection = sec;
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                                if (allSessions.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: smartDays
                                          .map(
                                            (day) => Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: _buildFilterChip(
                                                label: day == today
                                                    ? 'Today'
                                                    : dayNames[day - 1],
                                                selected: selectedDay == day,
                                                color: day == today
                                                    ? IrisTokens.success
                                                    : IrisTokens.warning,
                                                isDark: isDark,
                                                onSelected: (selected) {
                                                  setState(() {
                                                    selectedDay = selected
                                                        ? day
                                                        : null;
                                                  });
                                                },
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '${displayedSessions.length} classes found',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Classes list
                if (displayedSessions.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 118),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final session = displayedSessions[index];
                          final isInMySchedule =
                              widget.currentBatch == session.batchKey.batch;
                          final isLive = session.isLive(DateTime.now());
                          final programAccent = _accentForProgram(
                            session.batchKey.program,
                          );

                          return StaggeredListItem(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                enableOverlay: false,
                                enableShadow: false,
                                glow: isLive,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Time column
                                    Container(
                                      width: 54,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLive
                                            ? IrisTokens.success.withValues(
                                                alpha: isDark ? 0.15 : 0.1,
                                              )
                                            : IrisTokens.brand.withValues(
                                                alpha: isDark ? 0.1 : 0.06,
                                              ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            session.startTime,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isLive
                                                  ? IrisTokens.success
                                                  : IrisTokens.brand,
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 6,
                                            color: (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.1),
                                          ),
                                          Text(
                                            session.endTime,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: (isDark
                                                      ? Colors.white
                                                      : Colors.black)
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (isLive) ...[
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration: const BoxDecoration(
                                                    color: IrisTokens.success,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  session.subject,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: isLive
                                                        ? IrisTokens.success
                                                        : (isDark
                                                            ? programAccent
                                                                .withValues(
                                                                    alpha: 0.95)
                                                            : programAccent
                                                                .withValues(
                                                                    alpha:
                                                                        0.90)),
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isInMySchedule)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: programAccent
                                                        .withValues(
                                                            alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      8,
                                                    ),
                                                    border: Border.all(
                                                      color: programAccent
                                                          .withValues(
                                                              alpha: 0.2),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'MY CLASS',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: programAccent,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              _buildMetaChip(
                                                icon: Icons
                                                    .person_outline_rounded,
                                                text: session.teacher,
                                                color: IrisTokens.brand,
                                                isDark: isDark,
                                              ),
                                              _buildMetaChip(
                                                icon: Icons.room_rounded,
                                                text: session.room,
                                                color: IrisTokens.success,
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: IrisTokens.purple
                                                  .withValues(
                                                alpha: isDark ? 0.14 : 0.10,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: IrisTokens.purple
                                                    .withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Text(
                                              session.batchKey.batch,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: IrisTokens.purple,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: displayedSessions.length,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),

                // Empty state
                if (displayedSessions.isEmpty && selectedProgram != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: GlassCard(
                        enableOverlay: false,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.25),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No classes found',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try adjusting the filters',
                              style: TextStyle(
                                fontSize: 12,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
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
                  selectedIndex: 3,
                  onTeacher: widget.brain != null
                      ? () => pushIconLaunchRoute(
                            context,
                            page: TeacherLocatorScreen(
                              brain: widget.brain!,
                              onRoleChanged: widget.onRoleChanged,
                              onBatchChanged: widget.onBatchChanged,
                              memory: widget.memory,
                              currentBatch: widget.currentBatch,
                            ),
                          )
                      : () {},
                  onPortal: () => pushIconLaunchRoute(
                    context,
                    page: const PortalScreen(
                      url: 'https://swl-sis.comsats.edu.pk/',
                      title: 'COMSATS Student Portal',
                      sessionScope: 'student',
                    ),
                  ),
                  onClasses: () {},
                  onTools: widget.brain != null
                      ? () => pushIconLaunchRoute(
                            context,
                            page: ToolsScreen(
                              memory: widget.memory,
                              batch: widget.currentBatch,
                              brain: widget.brain!,
                              onRoleChanged: widget.onRoleChanged,
                              onBatchChanged: widget.onBatchChanged,
                              onAddMakeupClass: widget.onAddMakeupClass,
                              onRemoveMakeupClass: widget.onRemoveMakeupClass,
                            ),
                          )
                      : () {
                          showIrisFrostedSnackBar(
                            context,
                            dedupeKey: 'tools_unavailable_session',
                            content: const Text(
                              'Tools view is unavailable for this session.',
                            ),
                          );
                        },
                  onAbout: () => pushIconLaunchRoute(
                    context,
                    page: AboutScreen(
                      memory: widget.memory,
                      onRoleChanged: widget.onRoleChanged,
                      onBatchChanged: widget.onBatchChanged,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _accentForProgram(String program) {
    final key = program.toLowerCase();
    if (key.contains('cs') || key.contains('computer')) return IrisTokens.brand;
    if (key.contains('se') || key.contains('software')) return IrisTokens.blue;
    if (key.contains('it') || key.contains('information'))
      return const Color(0xFF06B6D4);
    if (key.contains('ee') || key.contains('electrical'))
      return IrisTokens.warning;
    if (key.contains('ai') || key.contains('ml')) return IrisTokens.purple;
    if (key.contains('mech') || key.contains('mechanical'))
      return IrisTokens.error;
    return IrisTokens.success;
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Color color,
    required bool isDark,
    required ValueChanged<bool> onSelected,
  }) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: IrisMotion.fast,
        curve: IrisMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        margin: const EdgeInsets.symmetric(vertical: 2),
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          color: selected
              ? color
              : isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.8)
                : isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: -6,
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.75,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
