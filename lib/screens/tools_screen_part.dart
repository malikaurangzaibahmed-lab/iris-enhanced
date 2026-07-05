part of '../main.dart';

class ToolsScreen extends StatefulWidget {
  final UniversityMemory memory;
  final String batch;
  final OmniBrain brain;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;
  final Future<void> Function(ClassSession session)? onAddMakeupClass;
  final Future<void> Function(ClassSession session)? onRemoveMakeupClass;
  final ScrollController? scrollController;
  final String searchQuery;

  const ToolsScreen({
    super.key,
    required this.memory,
    required this.batch,
    required this.brain,
    this.onRoleChanged,
    this.onBatchChanged,
    this.onAddMakeupClass,
    this.onRemoveMakeupClass,
    this.scrollController,
    this.searchQuery = '',
  });

  @override
  State<ToolsScreen> createState() => ToolsScreenState();
}

class ToolsScreenState extends State<ToolsScreen> {
  String _activeCategory = 'All';

  final List<String> _categories = ['All', 'Utilities', 'People', 'Planning'];

  String _getDepartmentFromBatch() {
    final key = BatchKey.parse(widget.batch);
    return key.program;
  }

  List<_ToolItem> _getUniversalTools() {
    return [
      _ToolItem(
        id: 'cgpa_calculator',
        title: 'CGPA Calculator',
        subtitle: 'Track semester GPA and CGPA',
        icon: Icons.calculate_rounded,
        color: IrisTokens.brand,
        description: 'Compute GPA and CGPA quickly',
      ),
      _ToolItem(
        id: 'teacher_locator',
        title: 'Teacher Locator',
        subtitle: 'Live teacher status and weekly schedule',
        icon: Icons.person_search_rounded,
        color: IrisTokens.purple,
        description: 'Locate a teacher instantly with smart matching',
      ),
      _ToolItem(
        id: 'teacher_directory',
        title: 'Teacher Directory',
        subtitle: 'Contact info and office hours',
        icon: Icons.person_rounded,
        color: IrisTokens.purple,
        description: 'Search all teachers by name and department',
      ),
      _ToolItem(
        id: 'browse_classes',
        title: 'Browse Classes',
        subtitle: 'Open all batch classes and schedules',
        icon: Icons.school_rounded,
        color: IrisTokens.brand,
        description: 'Explore class lists directly from Resources',
      ),
      _ToolItem(
        id: 'makeup_scheduler',
        title: 'Makeup Planner',
        subtitle: 'Find and add makeup lecture slots',
        icon: Icons.event_repeat_rounded,
        color: IrisTokens.warning,
        description: 'Plan and manage makeup lectures from one place',
      ),
      _ToolItem(
        id: 'transport_schedule',
        title: 'Transport Schedule',
        subtitle: 'Bus and shuttle notices',
        icon: Icons.directions_bus_rounded,
        color: IrisTokens.success,
        description: 'Scraper-backed transport updates and timing notices',
      ),
      _ToolItem(
        id: 'library_schedule',
        title: 'Library Schedule',
        subtitle: 'Opening hours and library notices',
        icon: Icons.local_library_rounded,
        color: IrisTokens.blue,
        description: 'Scraper-backed library timing and service updates',
      ),
      _ToolItem(
        id: 'semester_schedule',
        title: 'Semester Schedule',
        subtitle: 'Midterm, finals and semester milestones',
        icon: Icons.event_note_rounded,
        color: IrisTokens.purple,
        description: 'Scraper-backed semester and exam announcements',
      ),
      _ToolItem(
        id: 'find_rooms',
        title: 'Room Finder',
        subtitle: 'Discover available study spaces',
        icon: Icons.location_on_rounded,
        color: IrisTokens.success,
        description: 'Find empty classrooms and labs available now',
      ),
      _ToolItem(
        id: 'doc_workspace',
        title: 'Document Workspace',
        subtitle: 'Edit, convert, and split docs',
        icon: Icons.edit_document,
        color: IrisTokens.brand,
        description: 'Plain-text notepad editor, format converter, and PDF page splitter tools',
      ),
    ];
  }

  String _recommendedToolId(
    String department,
    DateTime now,
    ClassSession? current,
    ClassSession? next,
  ) {
    if (current != null) {
      return 'teacher_locator';
    }

    if (next != null && next.dayIndex == now.weekday) {
      final currentTime = now.hour + (now.minute / 60.0);
      final minsToNext = ((next.safeStartVal - currentTime) * 60).round();
      if (minsToNext >= 0 && minsToNext <= 45) {
        return 'find_rooms';
      }
      if (minsToNext >= 90) {
        return 'find_rooms';
      }
    }

    return 'teacher_locator';
  }

  List<_ToolItem> _prioritizeTool(
    List<_ToolItem> source,
    String recommendedId,
  ) {
    final items = List<_ToolItem>.from(source);
    final index = items.indexWhere((t) => t.id == recommendedId);
    if (index <= 0) {
      return items;
    }
    final picked = items.removeAt(index);
    items.insert(0, picked);
    return items;
  }

  Widget _buildSmartInsightCard({
    required BuildContext context,
    required bool isDark,
    required String department,
    required String recommendedId,
    required ClassSession? current,
    required ClassSession? next,
  }) {
    final now = DateTime.now();
    final currentTime = now.hour + (now.minute / 60.0);
    final minutesToNext = next != null && next.dayIndex == now.weekday
        ? ((next.safeStartVal - currentTime) * 60).round()
        : null;
    final title = current != null
        ? 'You are live in ${current.subject}'
        : next != null
            ? 'Next class: ${next.subject}'
            : 'No upcoming class right now';

    final reason = switch (recommendedId) {
      'find_rooms' => minutesToNext != null && minutesToNext <= 45
          ? 'Smart pick: Room Finder because your next class is soon.'
          : 'Smart pick: Room Finder because you have a long break and a study room may be open.',
      'teacher_locator' => 'Smart pick: Teacher Locator for faculty lookup and schedule status.',
      'cgpa_calculator' => 'Smart pick: CGPA Calculator for semester planning.',
      'transport_schedule' => 'Smart pick: Transport Schedule for campus commute notices.',
      'makeup_scheduler' => 'Smart pick: Makeup Planner to manage lecture overlaps.',
      _ => 'Smart pick: Teacher Locator for quick faculty lookup.',
    };
    return DirectoryAnimationWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VitalTokens.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: VitalTokens.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SMART ASSISTANT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: VitalTokens.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required bool isDark,
    required String title,
    required List<_ToolItem> tools,
    required String department,
  }) {
    if (tools.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
              ),
            ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final crossAxisCount = availableWidth >= 760
                ? 4
                : availableWidth >= 560
                    ? 3
                    : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 0.94,
              children: tools
                  .map(
                    (tool) => _buildToolCard(
                      context: context,
                      isDark: isDark,
                      item: tool,
                      department: department,
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required bool isDark,
    required _ToolItem item,
    required String department,
  }) {
    return VitalCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _handleToolTap(context, item.id, department),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const Spacer(),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _handleToolTap(BuildContext context, String id, String department) {
    IrisHaptics.actionMedium();
    switch (id) {
      case 'cgpa_calculator':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _CgpaCalculatorScreen()),
        );
        return;
      case 'teacher_locator':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TeacherLocatorScreen(
              brain: widget.brain,
              memory: widget.memory,
              currentBatch: widget.batch,
              onRoleChanged: widget.onRoleChanged,
            ),
          ),
        );
        return;
      case 'browse_classes':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _DepartmentClassesScreen(
              memory: widget.memory,
              currentBatch: widget.batch,
              brain: widget.brain,
              onRoleChanged: widget.onRoleChanged,
              showDock: false,
              showBackButton: true,
            ),
          ),
        );
        return;
      case 'teacher_directory':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FacultyDirectoryScreen(
              brain: widget.brain,
              onRoleChanged: widget.onRoleChanged,
              memory: widget.memory,
              currentBatch: widget.batch,
            ),
          ),
        );
        return;
      case 'makeup_scheduler':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MakeupLectureScheduler(
              memory: widget.memory,
              brain: widget.brain,
              batch: widget.batch,
              onAddMakeupClass: widget.onAddMakeupClass ?? (_) async {},
              onRemoveMakeupClass: widget.onRemoveMakeupClass,
              onRoleChanged: widget.onRoleChanged,
              showDock: false,
              showBackButton: true,
            ),
          ),
        );
        return;
      case 'transport_schedule':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _TransportScheduleScreen(),
          ),
        );
        return;
      case 'library_schedule':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _LibraryScheduleScreen(),
          ),
        );
        return;
      case 'semester_schedule':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _SemesterScheduleScreen(batch: widget.batch),
          ),
        );
        return;
      case 'find_rooms':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RoomFinderScreen(memory: widget.memory, brain: widget.brain),
          ),
        );
        return;
      case 'doc_workspace':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DocumentWorkspaceScreen(),
          ),
        );
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Open $id for $department')),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final department = _getDepartmentFromBatch();
    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);
    final recommendedId = _recommendedToolId(department, now, current, next);

    final allUniversal = _prioritizeTool(_getUniversalTools(), recommendedId);
    
    const utilityIds = {'cgpa_calculator', 'doc_workspace'};
    const peopleIds = {'teacher_locator', 'teacher_directory', 'browse_classes', 'find_rooms'};
    const planningIds = {'makeup_scheduler', 'transport_schedule', 'library_schedule', 'semester_schedule'};

    final filteredUniversal = allUniversal.where((t) {
      final matchesSearch = t.title.toLowerCase().contains(widget.searchQuery.toLowerCase()) || 
                          t.subtitle.toLowerCase().contains(widget.searchQuery.toLowerCase());
      if (!matchesSearch) return false;
      
      if (_activeCategory == 'All') return true;
      if (_activeCategory == 'Utilities') return utilityIds.contains(t.id);
      if (_activeCategory == 'People') return peopleIds.contains(t.id);
      if (_activeCategory == 'Planning') return planningIds.contains(t.id);
      return false;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          CustomScrollView(
            controller: widget.scrollController,
            physics: VitalMotion.scrollPhysics,
            slivers: [
              SliverAppBar(
                expandedHeight: 140,
                collapsedHeight: kToolbarHeight,
                pinned: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
                  title: Text(
                    'RESOURCES',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  background: const DirectoryBackgroundWidget(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: _categories.map((c) {
                        final isSelected = _activeCategory == c;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: isSelected,
                            onSelected: (s) => setState(() => _activeCategory = c),
                            backgroundColor: Colors.transparent,
                            selectedColor: IrisTokens.brand.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: isSelected ? IrisTokens.brand : (isDark ? Colors.white54 : Colors.black54),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (widget.searchQuery.isEmpty && _activeCategory == 'All') ...[
                      _buildSmartInsightCard(
                        context: context,
                        isDark: isDark,
                        department: department,
                        recommendedId: recommendedId,
                        current: current,
                        next: next,
                      ),
                      const SizedBox(height: 32),
                    ],
                    if (_activeCategory == 'All' || _activeCategory == 'Utilities')
                      _buildSection(
                        context: context,
                        isDark: isDark,
                        title: 'Utilities',
                        tools: filteredUniversal.where((t) => utilityIds.contains(t.id)).toList(),
                        department: department,
                      ),
                    if (_activeCategory == 'All' || _activeCategory == 'People') ...[
                      if (_activeCategory == 'All') const SizedBox(height: 32),
                      _buildSection(
                        context: context,
                        isDark: isDark,
                        title: 'People & Rooms',
                        tools: filteredUniversal.where((t) => peopleIds.contains(t.id)).toList(),
                        department: department,
                      ),
                    ],
                    if (_activeCategory == 'All' || _activeCategory == 'Planning') ...[
                      if (_activeCategory == 'All') const SizedBox(height: 32),
                      _buildSection(
                        context: context,
                        isDark: isDark,
                        title: 'Academic Planning',
                        tools: filteredUniversal.where((t) => planningIds.contains(t.id)).toList(),
                        department: department,
                      ),
                    ],

                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResourceHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool isDark;

  const _ResourceHeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.78)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: IrisTextStyles.classSubject(context).copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: IrisTextStyles.metaInfo(context).copyWith(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.62),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Select premium animation background dynamically based on content/icon
    final lowerTitle = title.toLowerCase();
    if (icon == Icons.directions_bus_rounded || lowerTitle.contains('transport') || lowerTitle.contains('bus')) {
      return TeacherLocatorAnimationWidget(child: cardContent);
    }
    if (icon == Icons.local_library_rounded || lowerTitle.contains('library')) {
      return DirectoryAnimationWidget(child: cardContent);
    }
    if (icon == Icons.calendar_today_rounded || lowerTitle.contains('semester') || lowerTitle.contains('schedule')) {
      return FinalsAnimationWidget(child: cardContent);
    }

    return GlassCard(child: cardContent);
  }
}


class _SemesterScheduleScreen extends StatefulWidget {
  final String batch;

  const _SemesterScheduleScreen({required this.batch});

  @override
  State<_SemesterScheduleScreen> createState() => _SemesterScheduleScreenState();
}

class _SemesterScheduleScreenState extends State<_SemesterScheduleScreen> {
  final HelpdeskScheduleDataService _service = HelpdeskScheduleDataService();
  late Future<CampusSchedulePayload> _payloadFuture;

  @override
  void initState() {
    super.initState();
    _payloadFuture = _service.fetchSchedulePayload();
  }

  Future<void> _refresh() async {
    setState(() {
      _payloadFuture = _service.fetchSchedulePayload();
    });
    await _payloadFuture;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: irisFrostedAppBar(
        title: 'Semester Schedule',
        isDark: isDark,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          FutureBuilder<CampusSchedulePayload>(
        future: _payloadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final payload = snapshot.data;
          if (payload == null) {
            return const Center(child: Text('No semester data available.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, topInset, 16, 40),
              children: [
                _ResourceHeroCard(
                  title: 'Semester Schedule',
                  subtitle: 'Academic schedule, exams, holidays and milestones for ${widget.batch}',
                  icon: Icons.calendar_today_rounded,
                  accent: VitalTokens.blue,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          payload.source == CampusScheduleSource.asset
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                          size: 16,
                          color: payload.source == CampusScheduleSource.asset
                              ? VitalTokens.blue
                              : VitalTokens.orange,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payload.source == CampusScheduleSource.asset
                                    ? 'Loaded from local cache'
                                    : 'Campus schedule cache is currently unavailable',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                                ),
                              ),
                              if (payload.capturedAt != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Last updated: ${payload.capturedAt!.toLocal().toString().split('.')[0]}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Milestones',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: IrisTokens.brand.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                if (payload.semesterSchedule.isEmpty)
                  const GlassCard(
                    child: Text('No semester milestones found.'),
                  )
                else
                  ...payload.semesterSchedule.map(
                    (milestone) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: IrisTokens.brand.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.event_note_rounded,
                                color: IrisTokens.brand,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    milestone.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    milestone.date,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              milestone.status,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: IrisTokens.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  'Deadlines',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: IrisTokens.brand.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                if (payload.deadlines.isEmpty)
                  const GlassCard(
                    child: Text('No deadlines found.'),
                  )
                else
                  ...payload.deadlines.map(
                    (deadline) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: IrisTokens.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.schedule_rounded,
                                color: IrisTokens.warning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    deadline.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    deadline.date,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              deadline.status,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: IrisTokens.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    ],
  ),
);
  }
}



class _LibraryScheduleScreen extends StatelessWidget {
  const _LibraryScheduleScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final schedule = [
      {'day': 'Monday - Thursday', 'open': '08:30 AM', 'close': '09:00 PM', 'peak': '11:00 AM - 02:00 PM'},
      {'day': 'Friday', 'open': '08:30 AM', 'close': '05:00 PM', 'peak': '10:00 AM - 12:30 PM'},
      {'day': 'Saturday', 'open': '10:00 AM', 'close': '04:00 PM', 'peak': '12:00 PM - 02:00 PM'},
      {'day': 'Sunday', 'open': 'CLOSED', 'close': '', 'peak': ''},
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: irisFrostedAppBar(title: 'Library Timetable', isDark: isDark),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 40),
            children: [
              _ResourceHeroCard(
                title: 'Central Library',
                subtitle: 'Opening hours, study slots and quiet planning',
                icon: Icons.local_library_rounded,
                accent: VitalTokens.blue,
                isDark: isDark,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 16),
                child: Text(
                  'WEEKLY TIMETABLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                  ),
                ),
              ),
              ...schedule.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['day']!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            const SizedBox(height: 4),
                            if (s['open'] == 'CLOSED')
                              const Text('LIBRARY CLOSED', style: TextStyle(color: VitalTokens.pink, fontWeight: FontWeight.w700, fontSize: 12))
                            else
                              Text('${s['open']} — ${s['close']}', style: TextStyle(fontWeight: FontWeight.w700, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                      if (s['peak']!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: VitalTokens.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('PEAK HOURS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: VitalTokens.orange)),
                              Text(s['peak']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: VitalTokens.orange)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              )),
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 16),
                child: Text(
                  'STUDY GUIDELINES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                  ),
                ),
              ),
              ...[
                'Use low-traffic (morning) hours for deep work sessions.',
                'Group formula-heavy revision near reference sections.',
                'Plan assignment and print tasks before 04:00 PM.',
                'Maintain strict silence in the designated Focus Zones.',
              ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 18, color: VitalTokens.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }
}
class _TransportScheduleScreen extends StatefulWidget {
  const _TransportScheduleScreen({super.key});

  @override
  State<_TransportScheduleScreen> createState() => _TransportScheduleScreenState();
}

class _TransportScheduleScreenState extends State<_TransportScheduleScreen> {
  final HelpdeskScheduleDataService _service = HelpdeskScheduleDataService();
  final TextEditingController _searchController = TextEditingController();
  List<TransportRouteData> _allRoutes = [];
  List<TransportRouteData> _filteredRoutes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final payload = await _service.fetchSchedulePayload();
    if (mounted) {
      setState(() {
        _allRoutes = payload.transportRoutes;
        _filteredRoutes = _allRoutes;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRoutes = _allRoutes.where((r) {
        final matchesName = r.route.toLowerCase().contains(query);
        final matchesStop = r.stops.any((s) => s.point.toLowerCase().contains(query));
        return matchesName || matchesStop;
      }).toList();
    });
  }

  void _makeCall(String number) async {
    if (number.isEmpty) return;
    final cleanNumber = number.replaceAll('-', '').replaceAll(' ', '');
    final url = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: irisFrostedAppBar(title: 'Transport Schedule', isDark: isDark),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: VitalTokens.success))
          else if (_allRoutes.isEmpty)
             Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.bus_alert_rounded, size: 64, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
                   const SizedBox(height: 16),
                   Text('No transport data found', style: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4))),
                 ],
               ),
             )
          else
            ListView(
              padding: EdgeInsets.fromLTRB(16, topInset, 16, 40),
              children: [
                _ResourceHeroCard(
                  title: 'Campus Transport',
                  subtitle: 'Live routes, office contacts and shuttle timings',
                  icon: Icons.directions_bus_rounded,
                  accent: VitalTokens.success,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
                
                // Search Bar
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search route or stop...',
                      hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3)),
                      border: InputBorder.none,
                      icon: Icon(Icons.search_rounded, color: VitalTokens.success.withValues(alpha: 0.5)),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ACTIVE ROUTES (${_filteredRoutes.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                        ),
                      ),
                      if (_filteredRoutes.length != _allRoutes.length)
                        Text(
                          'FILTERED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: VitalTokens.success.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
                
                ..._filteredRoutes.map((r) => _RouteCard(
                  route: r,
                  isDark: isDark,
                  onCall: _makeCall,
                )),
                
                const SizedBox(height: 24),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  backgroundColor: VitalTokens.orange.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: VitalTokens.orange),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Routes may vary during exam weeks or public holidays. Contact the transport office for real-time status.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatefulWidget {
  final TransportRouteData route;
  final bool isDark;
  final Function(String) onCall;

  const _RouteCard({
    required this.route,
    required this.isDark,
    required this.onCall,
  });

  @override
  State<_RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<_RouteCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    final isDark = widget.isDark;
    
    // Determine primary display time (usually first stop)
    final mainTime = r.stops.isNotEmpty ? r.stops.first.time : 'Scheduled';
    final stopCount = r.stops.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.route.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: VitalTokens.success.withValues(alpha: 0.6)),
                          const SizedBox(width: 6),
                          Text(
                            'Starts at $mainTime',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      if (r.driverPhone.isNotEmpty)
                        IconButton(
                          onPressed: () => widget.onCall(r.driverPhone),
                          icon: const Icon(Icons.phone_in_talk_rounded, size: 20, color: VitalTokens.success),
                          style: IconButton.styleFrom(
                            backgroundColor: VitalTokens.success.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      if (r.helperPhone.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => widget.onCall(r.helperPhone),
                          icon: const Icon(Icons.support_agent_rounded, size: 20, color: VitalTokens.orange),
                          style: IconButton.styleFrom(
                            backgroundColor: VitalTokens.orange.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Personnel Info
            Row(
              children: [
                _PersonnelTag(
                  label: 'DRIVER',
                  name: r.driverName,
                  isDark: isDark,
                  icon: Icons.person_rounded,
                ),
                if (r.helperName.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _PersonnelTag(
                    label: 'HELPER',
                    name: r.helperName,
                    isDark: isDark,
                    icon: Icons.person_outline_rounded,
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Stops Summary or Expandable
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.route_rounded, size: 14, color: VitalTokens.success),
                            const SizedBox(width: 8),
                            Text(
                              '$stopCount Stops in Route',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 18,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                    if (_isExpanded) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      ...r.stops.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text(
                                s.time,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: VitalTokens.success,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                s.point,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonnelTag extends StatelessWidget {
  final String label;
  final String name;
  final bool isDark;
  final IconData icon;

  const _PersonnelTag({
    required this.label,
    required this.name,
    required this.isDark,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 10, color: VitalTokens.success.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Not assigned' : name,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
