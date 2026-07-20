import 'package:flutter/material.dart';
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
    super.dispose();
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassSettings = IrisGlass.settings(
          context,
          blur: 24,
          ambientStrength: 0.8,
          lightAngle: 0.15 * math.pi,
          thickness: 18,
          glassColor: IrisGlass.adaptiveGlassColor(context, darkAlpha: 0.85, lightAlpha: 0.9),
        );

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: GlassSurface(
            settings: glassSettings,
            radius: 30,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: IrisTextStyles.headline(context).copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options[index];
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? IrisTokens.brand.withOpacity(0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? IrisTokens.brand.withOpacity(0.3)
                                          : (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        option,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected
                                              ? (isDark ? Colors.white : IrisTokens.brand)
                                              : (isDark ? Colors.white87 : Colors.black87),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: isDark ? Colors.white : IrisTokens.brand,
                                          size: 20,
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
        ? widget.memory.sessions
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
                                  Text(
                                    'Department Classes',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Browse classes for any program or semester.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: (isDark
                                              ? Colors.white
                                              : Colors.black)
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

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
                                      child: _buildGlassInputPill(
                                        title: 'PROGRAM',
                                        value: selectedProgram ?? 'None',
                                        onTap: () {
                                          _showGlassPicker(
                                            title: 'Select Program',
                                            options: validPrograms,
                                            selectedValue: selectedProgram ?? '',
                                            onSelected: (val) {
                                              setState(() {
                                                selectedProgram = val;
                                                final newSemesters = widget.memory.semesters(val);
                                                if (newSemesters.isNotEmpty) {
                                                  selectedSemester = newSemesters.first;
                                                  final newSections = widget.memory.sections(val, selectedSemester!);
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
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildGlassInputPill(
                                        title: 'SEMESTER',
                                        value: selectedSemester != null ? 'Semester $selectedSemester' : 'None',
                                        onTap: () {
                                          if (selectedProgram == null) return;
                                          _showGlassPicker(
                                            title: 'Select Semester',
                                            options: semesters.map((s) => s.toString()).toList(),
                                            selectedValue: selectedSemester?.toString() ?? '',
                                            onSelected: (val) {
                                              final sInt = int.tryParse(val);
                                              if (sInt != null) {
                                                setState(() {
                                                  selectedSemester = sInt;
                                                  final newSections = widget.memory.sections(selectedProgram!, sInt);
                                                  if (newSections.isNotEmpty) {
                                                    selectedSection = newSections.first;
                                                  } else {
                                                    selectedSection = null;
                                                  }
                                                });
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildGlassInputPill(
                                        title: 'SECTION',
                                        value: selectedSection != null ? 'Section $selectedSection' : 'None',
                                        onTap: () {
                                          if (selectedProgram == null || selectedSemester == null) return;
                                          _showGlassPicker(
                                            title: 'Select Section',
                                            options: sections,
                                            selectedValue: selectedSection ?? '',
                                            onSelected: (val) {
                                              setState(() {
                                                selectedSection = val;
                                              });
                                            },
                                          );
                                        },
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
                      url: 'https://swl-sis.comsats.edu.pk/Login/Index',
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
