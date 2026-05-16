part of '../main.dart';

class _ToolsScreen extends StatefulWidget {
  final UniversityMemory memory;
  final String batch;
  final OmniBrain brain;
  final ValueChanged<String>? onRoleChanged;

  const _ToolsScreen({
    super.key,
    required this.memory,
    required this.batch,
    required this.brain,
    this.onRoleChanged,
  });

  @override
  State<_ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<_ToolsScreen> {
  String _searchQuery = '';
  String _activeCategory = 'All';

  final List<String> _categories = ['All', 'Utilities', 'People', 'Planning', 'Dept'];

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
    ];
  }

  List<_ToolItem> _getDepartmentTools(String department) {
    return [];
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

    return VitalCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: VitalTokens.blue.withValues(alpha: isDark ? 0.12 : 0.06),
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
              mainAxisSpacing: 10,
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
      case 'unit_converter':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _UnitConverterScreen()),
        );
        return;
      case 'universal_calculator':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _UniversalCalculatorScreen()),
        );
        return;
      case 'cgpa_calculator':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _CgpaCalculatorScreen()),
        );
        return;
      case 'base_converter':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _BaseConverterScreen()),
        );
        return;
      case 'equation_solver':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _EquationSolverScreen()),
        );
        return;
      case 'molecular_weight_calculator':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _MolecularWeightCalculatorScreen()),
        );
        return;
      case 'offline_formula_library':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _OfflineFormulaLibraryScreen()),
        );
        return;
      case 'word_counter':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _WordCounterScreen(
              title: 'Word Counter',
              formula: 'words = split(text)',
              description: 'Count words, characters, sentences and paragraphs.',
            ),
          ),
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
              onAddMakeupClass: (_) async {},
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
            builder: (_) => const _CampusResourceScreen(
              title: 'Library Schedule',
              subtitle: 'Library timing, quiet slots and focus planning',
              items: [
                'Use low-traffic hours for deep work sessions.',
                'Group formula-heavy revision near reference sections.',
                'Plan assignment and print tasks before closing time.',
              ],
            ),
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
      case 'timetable_print':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PrintTimetableScreen(brain: widget.brain, batch: widget.batch),
          ),
        );
        return;
      case 'class_analytics':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ClassAnalyticsScreen(brain: widget.brain, batch: widget.batch),
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
      case 'programming_tools':
      case 'lab_resources':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _ProgrammingToolsScreen()),
        );
        return;
      case 'business_resources':
      case 'design_tools':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _DepartmentSmartKitScreen(
              department: department,
              brain: widget.brain,
              batch: widget.batch,
            ),
          ),
        );
        return;
      case 'health_tools':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _HealthToolsScreen(initialTab: 0),
          ),
        );
        return;
      case 'periodic_table':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _HealthToolsScreen(initialTab: 1),
          ),
        );
        return;
      case 'resistor_decoder':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _ResistorColorDecoderScreen(),
          ),
        );
        return;
      case 'dept_smart_kit':
      case 'department_plan':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _DepartmentSmartKitScreen(
              department: department,
              brain: widget.brain,
              batch: widget.batch,
            ),
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
    final departmentTools = _getDepartmentTools(department);
    
    const utilityIds = {'unit_converter', 'universal_calculator', 'base_converter', 'equation_solver', 'word_counter', 'molecular_weight_calculator', 'offline_formula_library', 'cgpa_calculator'};
    const peopleIds = {'teacher_locator', 'teacher_directory', 'browse_classes', 'find_rooms'};
    const planningIds = {'makeup_scheduler', 'class_analytics', 'semester_schedule', 'timetable_print', 'transport_schedule', 'library_schedule'};

    final filteredUniversal = allUniversal.where((t) {
      final matchesSearch = t.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                          t.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;
      
      if (_activeCategory == 'All') return true;
      if (_activeCategory == 'Utilities') return utilityIds.contains(t.id);
      if (_activeCategory == 'People') return peopleIds.contains(t.id);
      if (_activeCategory == 'Planning') return planningIds.contains(t.id);
      return false;
    }).toList();

    final filteredDept = _activeCategory == 'All' || _activeCategory == 'Dept' 
        ? departmentTools.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList()
        : <_ToolItem>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          CustomScrollView(
            physics: VitalMotion.scrollPhysics,
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                collapsedHeight: kToolbarHeight,
                pinned: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 64),
                  title: Text(
                    'RESOURCES',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  background: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: irisFrostedInputDecoration(
                            label: 'Search tools...',
                            isDark: isDark,
                            prefixIcon: Icons.search_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(height: 56), // Space for title
                    ],
                  ),
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
                    if (_searchQuery.isEmpty && _activeCategory == 'All') ...[
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
                    if (_activeCategory == 'All' || _activeCategory == 'Dept') ...[
                      if (_activeCategory == 'All') const SizedBox(height: 32),
                      _buildSection(
                        context: context,
                        isDark: isDark,
                        title: 'Department Kit',
                        tools: filteredDept,
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
    return GlassCard(
      child: Padding(
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
      ),
    );
  }
}

class _CampusResourceScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> items;

  const _CampusResourceScreen({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ResourceHeroCard(
                title: title,
                subtitle: subtitle,
                icon: Icons.travel_explore_rounded,
                accent: IrisTokens.brand,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              size: 18, color: IrisTokens.brand),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: IrisTextStyles.body(context)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Semester Schedule'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
              padding: const EdgeInsets.all(16),
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Semester milestones for ${widget.batch}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        payload.source == CampusScheduleSource.asset
                            ? 'Loaded from the campus schedule cache.'
                            : 'Campus schedule cache is unavailable right now.',
                        style: TextStyle(
                          fontSize: 12,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                        ),
                      ),
                      if (payload.capturedAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Updated ${payload.capturedAt!.toLocal()}',
                          style: TextStyle(
                            fontSize: 11,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                      padding: const EdgeInsets.only(bottom: 10),
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

class _UnitConverterScreen extends StatefulWidget {
  const _UnitConverterScreen();

  @override
  State<_UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<_UnitConverterScreen> {
  final TextEditingController _valueController = TextEditingController(text: '1');
  String _category = 'Length';
  String _fromUnit = 'Meters';
  String _toUnit = 'Feet';

  static const Map<String, Map<String, double>> _units = {
    'Length': {'Meters': 1, 'Kilometers': 1000, 'Centimeters': 0.01, 'Feet': 0.3048, 'Inches': 0.0254},
    'Mass': {'Grams': 1, 'Kilograms': 1000, 'Pounds': 453.59237},
    'Temperature': {},
  };

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  double _convert() {
    final value = double.tryParse(_valueController.text.trim()) ?? 0;
    if (_category == 'Temperature') {
      if (_fromUnit == 'Celsius' && _toUnit == 'Fahrenheit') return (value * 9 / 5) + 32;
      if (_fromUnit == 'Fahrenheit' && _toUnit == 'Celsius') return (value - 32) * 5 / 9;
      return value;
    }
    final map = _units[_category] ?? const {};
    final from = map[_fromUnit] ?? 1;
    final to = map[_toUnit] ?? 1;
    return value * from / to;
  }

  List<String> _options() {
    if (_category == 'Temperature') return const ['Celsius', 'Fahrenheit'];
    return (_units[_category]?.keys.toList() ?? const <String>[]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = _convert();
    final options = _options();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Unit Converter'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: const ['Length', 'Mass', 'Temperature']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _category = value;
                    final opts = _options();
                    _fromUnit = opts.first;
                    _toUnit = opts.length > 1 ? opts[1] : opts.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Value', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String>(
                        initialValue: _fromUnit,
                        items: options
                            .map((value) =>
                                DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _fromUnit = value ?? _fromUnit))),
                const SizedBox(width: 10),
                Expanded(
                    child: DropdownButtonFormField<String>(
                        initialValue: _toUnit,
                        items: options
                            .map((value) =>
                                DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _toUnit = value ?? _toUnit))),
              ]),
              const SizedBox(height: 16),
              GlassCard(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('${result.toStringAsFixed(4)} $_toUnit',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black)))),
            ],
          ),
        ],
      ),
    );
  }
}

class _UniversalCalculatorScreen extends StatefulWidget {
  const _UniversalCalculatorScreen();

  @override
  State<_UniversalCalculatorScreen> createState() => _UniversalCalculatorScreenState();
}

class _UniversalCalculatorScreenState extends State<_UniversalCalculatorScreen> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();
  String _operation = '+';

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  double _result() {
    final left = double.tryParse(_leftController.text.trim()) ?? 0;
    final right = double.tryParse(_rightController.text.trim()) ?? 0;
    switch (_operation) {
      case '-': return left - right;
      case '×': return left * right;
      case '÷': return right == 0 ? 0 : left / right;
      default: return left + right;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = _result();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Universal Calculator'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _leftController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Value 1', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                DropdownButton<String>(
                    value: _operation,
                    items: ['+', '-', '×', '÷']
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: (v) => setState(() => _operation = v ?? '+')),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _rightController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Value 2', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 16),
              GlassCard(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(result.toStringAsFixed(2),
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black)))),
            ],
          ),
        ],
      ),
    );
  }
}

class _BaseConverterScreen extends StatefulWidget {
  const _BaseConverterScreen();

  @override
  State<_BaseConverterScreen> createState() => _BaseConverterScreenState();
}

class _BaseConverterScreenState extends State<_BaseConverterScreen> {
  final TextEditingController _controller = TextEditingController(text: '42');
  String _fromBase = '10';
  String _toBase = '2';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _convert() {
    final input = _controller.text.trim();
    if (input.isEmpty) return '';
    final sourceBase = int.tryParse(_fromBase) ?? 10;
    final targetBase = int.tryParse(_toBase) ?? 10;
    final value = int.tryParse(input, radix: sourceBase) ?? 0;
    return value.toRadixString(targetBase).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = _convert();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Base Converter'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Number', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String>(
                        initialValue: _fromBase,
                        items: const ['2', '8', '10', '16']
                            .map((b) =>
                                DropdownMenuItem(value: b, child: Text('Base $b')))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _fromBase = value ?? _fromBase))),
                const SizedBox(width: 10),
                Expanded(
                    child: DropdownButtonFormField<String>(
                        initialValue: _toBase,
                        items: const ['2', '8', '10', '16']
                            .map((b) =>
                                DropdownMenuItem(value: b, child: Text('Base $b')))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _toBase = value ?? _toBase))),
              ]),
              const SizedBox(height: 16),
              GlassCard(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(result.isEmpty ? 'Enter a value' : result,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)))),
            ],
          ),
        ],
      ),
    );
  }
}

class _EquationSolverScreen extends StatefulWidget {
  const _EquationSolverScreen();

  @override
  State<_EquationSolverScreen> createState() => _EquationSolverScreenState();
}

class _EquationSolverScreenState extends State<_EquationSolverScreen> {
  final TextEditingController _a = TextEditingController(text: '1');
  final TextEditingController _b = TextEditingController(text: '0');
  final TextEditingController _c = TextEditingController(text: '0');

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    super.dispose();
  }

  String _solve() {
    final a = double.tryParse(_a.text.trim()) ?? 0;
    final b = double.tryParse(_b.text.trim()) ?? 0;
    final c = double.tryParse(_c.text.trim()) ?? 0;
    if (a == 0 && b == 0) return 'No equation';
    if (a == 0) return 'x = ${(-c / b).toStringAsFixed(4)}';
    final discriminant = (b * b) - (4 * a * c);
    if (discriminant < 0) return 'No real roots';
    final sqrtD = math.sqrt(discriminant);
    final x1 = (-b + sqrtD) / (2 * a);
    final x2 = (-b - sqrtD) / (2 * a);
    return 'x = ${x1.toStringAsFixed(4)} or ${x2.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Equation Solver'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _a,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'a', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _b,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'b', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _c,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'c', border: OutlineInputBorder())))
              ]),
              const SizedBox(height: 16),
              GlassCard(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_solve(),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)))),
            ],
          ),
        ],
      ),
    );
  }
}

class _MolecularWeightCalculatorScreen extends StatefulWidget {
  const _MolecularWeightCalculatorScreen();

  @override
  State<_MolecularWeightCalculatorScreen> createState() => _MolecularWeightCalculatorScreenState();
}

class _MolecularWeightCalculatorScreenState extends State<_MolecularWeightCalculatorScreen> {
  final TextEditingController _controller = TextEditingController(text: 'H2O');
  static const Map<String, double> _weights = {
    'H': 1.008,
    'C': 12.011,
    'N': 14.007,
    'O': 15.999,
    'Na': 22.990,
    'Mg': 24.305,
    'P': 30.974,
    'S': 32.06,
    'Cl': 35.45,
    'K': 39.098,
    'Ca': 40.078,
    'Fe': 55.845,
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _calculate() {
    final formula = _controller.text.trim();
    final matches = RegExp(r'([A-Z][a-z]?)(\d*)').allMatches(formula);
    var total = 0.0;
    for (final match in matches) {
      final symbol = match.group(1)!;
      final count = int.tryParse(match.group(2) ?? '') ?? 1;
      total += (_weights[symbol] ?? 0) * count;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final value = _calculate();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Molecular Weight'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Formula', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              GlassCard(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('${value.toStringAsFixed(3)} g/mol',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)))),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransportScheduleScreen extends StatelessWidget {
  const _TransportScheduleScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final routes = [
      {'id': 'R1', 'name': 'SADDER ROUTE', 'times': '08:00, 13:30, 16:00', 'stops': 'Lalazar, Cant, Sadder Metro'},
      {'id': 'R2', 'name': 'G-11 ROUTE', 'times': '08:15, 14:00, 16:30', 'stops': 'G-8, G-9, G-10, G-11 Markaz'},
      {'id': 'R3', 'name': 'BAHRIA ROUTE', 'times': '07:45, 13:15, 15:45', 'stops': 'Phase 1-6, Expressway, Gulberg'},
      {'id': 'R4', 'name': 'PWD ROUTE', 'times': '08:30, 14:30, 17:00', 'stops': 'Media Town, PWD, Police Foundation'},
      {'id': 'S1', 'name': 'CAMPUS SHUTTLE', 'times': 'Every 20 mins', 'stops': 'All Blocks, Main Gate, Library'},
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: irisFrostedAppBar(title: 'Transport Schedule', isDark: isDark),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 110, 16, 40),
            children: [
              _ResourceHeroCard(
                title: 'Campus Transport',
                subtitle: 'Daily routes and shuttle timings',
                icon: Icons.directions_bus_rounded,
                accent: VitalTokens.success,
                isDark: isDark,
              ),
              const SizedBox(height: 24),
              ...routes.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: VitalTokens.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(r['id']!, style: const TextStyle(color: VitalTokens.success, fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          Text(r['name']!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 16, color: VitalTokens.success),
                          const SizedBox(width: 8),
                          Text(r['times']!, style: TextStyle(fontWeight: FontWeight.w700, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 16, color: VitalTokens.success),
                          const SizedBox(width: 8),
                          Expanded(child: Text(r['stops']!, style: TextStyle(fontSize: 13, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5)))),
                        ],
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
