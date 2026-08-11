import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../core/omni_brain.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';
import '../core/vital_theme.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';
import '../services/helpdesk_faculty_service.dart';
import 'students_week_screen.dart';

class FacultyDirectoryScreen extends StatefulWidget {
  final OmniBrain? brain;
  final ValueChanged<String>? onTeacherSelected;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;
  final UniversityMemory? memory;
  final String? currentBatch;
  final String? initialTeacherQuery;
  final bool isSelectionMode;

  const FacultyDirectoryScreen({
    this.brain,
    this.onTeacherSelected,
    this.onRoleChanged,
    this.onBatchChanged,
    this.memory,
    this.currentBatch,
    this.initialTeacherQuery,
    this.isSelectionMode = false,
    super.key,
  });

  @override
  State<FacultyDirectoryScreen> createState() => _FacultyDirectoryScreenState();
}

class _FacultyDirectoryScreenState extends State<FacultyDirectoryScreen> {
  static const String _backendBase = 'https://cui-helpdesk-backend.onrender.com';

  final HelpdeskFacultyService _service = HelpdeskFacultyService();
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  List<FacultyProfile> _all = const [];
  List<FacultyProfile> _filtered = const [];
  final Map<String, TeacherLocatorResult> _teacherInsightCache = {};
  bool _loading = true;
  String _error = '';
  String _query = '';
  String _selectedDepartment = 'All';
  String _selectedBlock = 'All';
  HelpdeskFacultySource _source = HelpdeskFacultySource.none;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialTeacherQuery ?? '');
    _query = widget.initialTeacherQuery ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadFaculty());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFaculty() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    final payload = await _service.fetchLiveFirstWithFallbackPayload();
    if (!mounted) return;

    final helpdeskList = List<FacultyProfile>.from(payload.items);
    final Set<String> existingNames = helpdeskList.map((e) => e.name.toLowerCase().trim()).toSet();

    // Fast O(1) Smart Union: Merge PDF Timetable teachers missing from Helpdesk snapshot
    if (widget.brain != null) {
      for (final teacherName in widget.brain!.allTeachers()) {
        final cleanName = teacherName.trim();
        if (cleanName.isEmpty || cleanName == 'Unknown') continue;
        final lower = cleanName.toLowerCase();
        if (!existingNames.contains(lower)) {
          helpdeskList.add(FacultyProfile(
            id: 'pdf_${cleanName.hashCode}',
            name: cleanName,
            gender: 'N/A',
            department: 'Academic Faculty',
            location: 'COMSATS Campus',
            contact: 'Campus Office',
            email: '',
            image: '',
          ));
          existingNames.add(lower);
        }
      }
    }

    if (helpdeskList.isEmpty) {
      setState(() {
        _all = const [];
        _filtered = const [];
        _loading = false;
        _error = 'Unable to load faculty directory right now.';
        _source = HelpdeskFacultySource.none;
      });
      return;
    }
    helpdeskList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _all = helpdeskList;
      _loading = false;
      _source = payload.source;
    });
    _applyFilter();
  }

  String _sourceLabel(HelpdeskFacultySource source) {
    switch (source) {
      case HelpdeskFacultySource.live:
        return 'LIVE';
      case HelpdeskFacultySource.cache:
        return 'CACHE';
      case HelpdeskFacultySource.backup:
        return 'BACKUP';
      case HelpdeskFacultySource.none:
        return 'OFFLINE';
    }
  }

  String _resolveImageUrl(String raw) {
    final image = raw.trim();
    if (image.isEmpty) return '';
    if (image.contains('uploads/')) {
      final filename = image.split('/').last;
      return 'assets/faculty_images/$filename';
    }
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }
    if (image.startsWith('/')) return '$_backendBase$image';
    return '$_backendBase/$image';
  }

  String _blockFromLocation(String location) {
    final value = location.trim();
    if (value.isEmpty) return 'Unknown';
    final upper = value.toUpperCase();
    if (upper.contains('A BLOCK') || upper.startsWith('A')) return 'A Block';
    if (upper.contains('B BLOCK') || upper.startsWith('B')) return 'B Block';
    if (upper.contains('C BLOCK') || upper.startsWith('C')) return 'C Block';
    if (upper.contains('D BLOCK') || upper.startsWith('D')) return 'D Block';
    if (upper.contains('E BLOCK') || upper.startsWith('E')) return 'E Block';
    if (upper.contains('WORKSHOP')) return 'Workshop Block';
    return value;
  }

  List<String> get _departments {
    final items = _all
        .map((e) => e.department.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...items];
  }

  List<String> get _blocks {
    final items = _all
        .map((e) => _blockFromLocation(e.location))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...items];
  }

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    final result = _all.where((item) {
      final departmentOk = _selectedDepartment == 'All' ||
          item.department.toLowerCase() == _selectedDepartment.toLowerCase();
      final blockOk = _selectedBlock == 'All' ||
          _blockFromLocation(item.location).toLowerCase() ==
              _selectedBlock.toLowerCase();

      if (!departmentOk || !blockOk) return false;
      if (q.isEmpty) return true;

      return item.name.toLowerCase().contains(q) ||
          item.department.toLowerCase().contains(q) ||
          item.location.toLowerCase().contains(q) ||
          item.email.toLowerCase().contains(q) ||
          item.contact.toLowerCase().contains(q);
    }).toList();

    setState(() {
      _filtered = result;
    });
  }

  TeacherLocatorResult? _teacherInsight(String teacherName) {
    final brain = widget.brain;
    if (brain == null) return null;
    return _teacherInsightCache.putIfAbsent(
      teacherName,
      () => brain.locateTeacher(teacherName, DateTime.now()),
    );
  }

  void _openTeacherLocator(FacultyProfile item) {
    if (widget.isSelectionMode) {
      if (widget.onTeacherSelected != null) {
        widget.onTeacherSelected!(item.name);
      }
      Navigator.maybePop(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FacultyDetailSheet(
        profile: item,
        brain: widget.brain,
        onLaunchEmail: () => _launchEmail(item.email),
        onLaunchPhone: () => _launchPhone(item.contact),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'faculty_phone_unavailable',
        content: const Text('Phone number unavailable for this faculty member.'),
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
      dedupeKey: 'faculty_phone_launch_failed',
      content: const Text('Unable to open dialer on this device.'),
    );
  }

  Future<void> _launchEmail(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'faculty_email_unavailable',
        content: const Text('Email unavailable for this faculty member.'),
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
      dedupeKey: 'faculty_email_launch_failed',
      content: const Text('Unable to open email client on this device.'),
    );
  }

  Widget _buildFilterStrip({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.42),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final value = options[i];
              final active = selected == value;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  IrisHaptics.chipSelect();
                  onChanged(value);
                },
                child: AnimatedContainer(
                  duration: IrisMotion.fast,
                  curve: IrisMotion.standard,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? IrisTokens.brand.withValues(alpha: isDark ? 0.24 : 0.14)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? IrisTokens.brand.withValues(alpha: 0.40)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.black.withValues(alpha: 0.10)),
                    ),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: active
                          ? IrisTokens.brand
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.82)
                              : Colors.black.withValues(alpha: 0.75)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFacultyTile(FacultyProfile item, bool isDark) {
    final imageUrl = _resolveImageUrl(item.image);
    final insight = _teacherInsight(item.name);
    final status = insight?.status ?? 'unknown';
    final statusText = insight?.statusText ?? '';

    Color statusColor() {
      switch (status) {
        case 'live':
          return IrisTokens.success;
        case 'today':
          return IrisTokens.brand;
        case 'weekly':
        case 'upcoming':
          return IrisTokens.warning;
        default:
          return IrisTokens.purple;
      }
    }

    final smartColor = statusColor();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openTeacherLocator(item),
      child: GlassCard(
        enableOverlay: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IrisComponents.facultyAvatar(
                  imageUrl: imageUrl.isEmpty ? null : imageUrl,
                  gender: item.gender,
                  name: item.name,
                  radius: 28,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.department.isEmpty ? 'Department unavailable' : item.department,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.56),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: IrisTokens.purple.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location.isEmpty ? 'Location unavailable' : item.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.58),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: smartColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: smartColor.withValues(alpha: 0.30)),
                  ),
                  child: Text(
                    status == 'live'
                        ? 'LIVE NOW'
                        : status == 'today'
                            ? 'TODAY'
                            : status == 'weekly' || status == 'upcoming'
                                ? 'UPCOMING'
                                : 'LOCATE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: smartColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText.isEmpty ? 'Tap card to open Teacher Locator' : statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.58),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchEmail(item.email),
                    icon: const Icon(Icons.mail_outline_rounded, size: 16),
                    label: const Text('Email'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: IrisTokens.brand.withValues(alpha: 0.24),
                      ),
                      foregroundColor: IrisTokens.brand,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchPhone(item.contact),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: IrisTokens.success.withValues(alpha: 0.28),
                      ),
                      foregroundColor: IrisTokens.success,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(isDark: isDark),
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadFaculty,
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                      children: [
                        DirectoryAnimationWidget(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [IrisTokens.brand, IrisTokens.purple],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.badge_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Faculty Directory',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    Text(
                                      'Live source with backup fallback',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: IrisTokens.brand.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: IrisTokens.brand.withValues(alpha: 0.24),
                                        ),
                                      ),
                                      child: Text(
                                        _sourceLabel(_source),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.7,
                                          color: IrisTokens.brand.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GlassCard(
                          enableOverlay: false,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              _query = value;
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 120),
                                () {
                                  if (!mounted) return;
                                  _applyFilter();
                                },
                              );
                            },
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search faculty by name, dept, location...',
                              hintStyle: TextStyle(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                              ),
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        IrisHaptics.actionSoft();
                                        _searchController.clear();
                                        _query = '';
                                        _applyFilter();
                                      },
                                      icon: const Icon(Icons.clear_rounded),
                                    ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFilterStrip(
                          title: 'DEPARTMENT',
                          options: _departments,
                          selected: _selectedDepartment,
                          onChanged: (value) {
                            setState(() => _selectedDepartment = value);
                            _applyFilter();
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildFilterStrip(
                          title: 'BLOCK',
                          options: _blocks,
                          selected: _selectedBlock,
                          onChanged: (value) {
                            setState(() => _selectedBlock = value);
                            _applyFilter();
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_error.isNotEmpty)
                          GlassCard(
                            enableOverlay: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Directory unavailable',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton.icon(
                                    onPressed: _loadFaculty,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Try again'),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Text(
                            '${_filtered.length} result${_filtered.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._filtered.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildFacultyTile(item, isDark),
                            ),
                          ),
                        ],
                      ],
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
}

class _FacultyDetailSheet extends StatefulWidget {
  final FacultyProfile profile;
  final OmniBrain? brain;
  final VoidCallback onLaunchEmail;
  final VoidCallback onLaunchPhone;

  const _FacultyDetailSheet({
    required this.profile,
    required this.brain,
    required this.onLaunchEmail,
    required this.onLaunchPhone,
  });

  @override
  State<_FacultyDetailSheet> createState() => _FacultyDetailSheetState();
}

class _FacultyDetailSheetState extends State<_FacultyDetailSheet> {
  int _selectedDay = DateTime.now().weekday; // 1: Mon .. 5: Fri

  @override
  void initState() {
    super.initState();
    if (_selectedDay < 1 || _selectedDay > 5) {
      _selectedDay = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6);
    final item = widget.profile;

    final TeacherLocatorResult? result = widget.brain != null
        ? widget.brain!.locateTeacher(item.name, DateTime.now())
        : null;

    final daySessions = result != null
        ? (result.weeklySchedule[_selectedDay] ?? [])
        : <TeacherScheduleEntry>[];

    final days = [
      {'idx': 1, 'name': 'Mon'},
      {'idx': 2, 'name': 'Tue'},
      {'idx': 3, 'name': 'Wed'},
      {'idx': 4, 'name': 'Thu'},
      {'idx': 5, 'name': 'Fri'},
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IrisComponents.facultyAvatar(
                    imageUrl: item.image.isEmpty ? null : item.image,
                    gender: item.gender,
                    name: item.name,
                    radius: 30,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.department.isEmpty ? 'Faculty Member' : item.department,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 13, color: IrisTokens.purple),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.location.isEmpty ? 'COMSATS Campus' : item.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Contact Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onLaunchEmail,
                      icon: const Icon(Icons.mail_outline_rounded, size: 16),
                      label: const Text('Email'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: IrisTokens.brand,
                        side: BorderSide(color: IrisTokens.brand.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onLaunchPhone,
                      icon: const Icon(Icons.phone_outlined, size: 16),
                      label: const Text('Call Office'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: IrisTokens.success,
                        side: BorderSide(color: IrisTokens.success.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Day selector header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'WEEKLY SCHEDULE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: textSecondary,
                    ),
                  ),
                  if (result?.liveSession != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: IrisTokens.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: IrisTokens.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: IrisTokens.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE IN CLASS',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: IrisTokens.success,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Weekday Selector Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: days.map((d) {
                  final idx = d['idx'] as int;
                  final name = d['name'] as String;
                  final isSelected = _selectedDay == idx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: isSelected,
                      onSelected: (_) {
                        IrisSfx.pillTap();
                        setState(() => _selectedDay = idx);
                      },
                      selectedColor: IrisTokens.brand,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? IrisTokens.brand
                              : (isDark ? Colors.white10 : Colors.black12),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            // Schedule List
            Expanded(
              child: daySessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No scheduled lectures for this day.',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: daySessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final s = daySessions[idx];
                        final isLive = s.isLive;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isLive
                                ? IrisTokens.success.withValues(alpha: isDark ? 0.12 : 0.08)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.02)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isLive
                                  ? IrisTokens.success.withValues(alpha: 0.4)
                                  : (isDark ? Colors.white10 : Colors.black12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isLive ? IrisTokens.success : IrisTokens.brand,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.subject,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${s.startTime} - ${s.endTime}  •  ${s.room}  •  ${s.batch}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: IrisTokens.success,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
