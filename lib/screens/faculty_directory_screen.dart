import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import '../core/tokens.dart';
import '../core/models.dart';
import '../core/omni_brain.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';
import '../widgets/glowing_input_wrapper.dart';
import '../core/vital_theme.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';
import '../services/helpdesk_faculty_service.dart';
import '../services/remote_config_service.dart';
import '../widgets/glass_container_transform.dart';
import 'students_week_screen.dart';

String resolveFacultyImageUrl(String raw) {
  final image = raw.trim();
  if (image.isEmpty) return '';
  if (image.contains('uploads/')) {
    final filename = image.split('/').last;
    return 'assets/faculty_images/$filename';
  }
  if (image.startsWith('http://') || image.startsWith('https://')) {
    return image;
  }
  const backendBase = 'https://cui-helpdesk-backend.onrender.com';
  if (image.startsWith('/')) return '$backendBase$image';
  return '$backendBase/$image';
}

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
  final HelpdeskFacultyService _service = HelpdeskFacultyService();
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  List<FacultyProfile> _all = const [];
  List<FacultyProfile> _filtered = const [];
  final Map<String, TeacherLocatorResult> _teacherInsightCache = {};
  final Map<String, GlobalKey> _cardKeys = {};
  final Map<String, String> _profileSearchIndex = {};
  final Map<String, String> _profileBlockIndex = {};
  bool _loading = true;
  String _error = '';
  String _query = '';
  String _selectedDepartment = 'All';
  String _selectedBlock = 'All';
  HelpdeskFacultySource _source = HelpdeskFacultySource.none;
  final ScrollController _scrollController = ScrollController();

  late final VoidCallback _remoteConfigListener;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialTeacherQuery ?? '');
    _query = widget.initialTeacherQuery ?? '';

    _remoteConfigListener = () {
      if (mounted) {
        setState(() {
          _teacherInsightCache.clear();
        });
      }
    };

    RemoteConfigService.activeAcademicPeriod.addListener(_remoteConfigListener);
    RemoteConfigService.lastTimetableUpdateTime.addListener(_remoteConfigListener);

    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _loadFaculty();
    });
  }

  @override
  void dispose() {
    RemoteConfigService.activeAcademicPeriod.removeListener(_remoteConfigListener);
    RemoteConfigService.lastTimetableUpdateTime.removeListener(_remoteConfigListener);
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

    List<FacultyProfile> helpdeskList = List<FacultyProfile>.from(payload.items);

    // Smart Union: Merge PDF Timetable teachers with Helpdesk snapshot without duplicate fragmentation
    if (widget.brain != null) {
      try {
        helpdeskList = HelpdeskFacultyService.mergeWithTimetableTeachers(
          helpdeskProfiles: helpdeskList,
          timetableTeachers: widget.brain!.allTeachers(),
        );
      } catch (_) {
        // Safe fallback
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

    _profileSearchIndex.clear();
    _profileBlockIndex.clear();
    for (final item in helpdeskList) {
      final normalizedName = HelpdeskFacultyService.normalizeFacultyName(item.name);
      final aliasStr = item.aliases.join(' ').toLowerCase();
      final block = _blockFromLocation(item.location);
      _profileBlockIndex[item.id] = block;
      _profileSearchIndex[item.id] =
          '${item.name} $normalizedName $aliasStr ${item.department} ${item.location} $block ${item.email} ${item.contact}'
              .toLowerCase();
    }

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
    return resolveFacultyImageUrl(raw);
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
        .map((e) => _profileBlockIndex[e.id] ?? _blockFromLocation(e.location))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...items];
  }

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    final qTokens = q
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => t.replaceAll('.', ''))
        .toList();

    final selectedDeptLower = _selectedDepartment.toLowerCase();
    final selectedBlockLower = _selectedBlock.toLowerCase();

    final result = _all.where((item) {
      if (_selectedDepartment != 'All' &&
          item.department.toLowerCase() != selectedDeptLower) {
        return false;
      }
      final block = _profileBlockIndex[item.id] ?? _blockFromLocation(item.location);
      if (_selectedBlock != 'All' &&
          block.toLowerCase() != selectedBlockLower) {
        return false;
      }

      if (qTokens.isEmpty) return true;

      final searchIndex = _profileSearchIndex[item.id] ??
          '${item.name} ${item.department} ${item.location}'.toLowerCase();

      for (final token in qTokens) {
        if (!searchIndex.contains(token)) return false;
      }
      return true;
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

  void _openTeacherLocator(FacultyProfile item, {GlobalKey? originKey}) {
    if (widget.isSelectionMode) {
      if (widget.onTeacherSelected != null) {
        widget.onTeacherSelected!(item.name);
      }
      Navigator.maybePop(context);
      return;
    }

    pushGlassContainerMorphRoute(
      context,
      originKey: originKey,
      page: FacultyDetailScreen(
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
    final cardKey = _cardKeys.putIfAbsent(item.id, () => GlobalKey());

    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openTeacherLocator(item, originKey: cardKey),
        child: GlassCard(
          key: cardKey,
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
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                IrisGlowingInputWrapper(
                                  borderRadius: 24,
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
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '${_filtered.length} result${_filtered.length == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.48),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (!_loading && _error.isEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                            sliver: SliverList.builder(
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final item = _filtered[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildFacultyTile(item, isDark),
                                );
                              },
                            ),
                          ),
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

class FacultyDetailScreen extends StatefulWidget {
  final FacultyProfile profile;
  final OmniBrain? brain;
  final VoidCallback onLaunchEmail;
  final VoidCallback onLaunchPhone;

  const FacultyDetailScreen({
    super.key,
    required this.profile,
    required this.brain,
    required this.onLaunchEmail,
    required this.onLaunchPhone,
  });

  @override
  State<FacultyDetailScreen> createState() => _FacultyDetailScreenState();
}

class _FacultyDetailScreenState extends State<FacultyDetailScreen> {
  int _selectedDay = DateTime.now().weekday; // 1: Mon .. 5: Fri
  int _viewSegmentIndex = 0; // 0 = Daily Timeline, 1 = Weekly Matrix

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
      {'idx': 1, 'name': 'Mon', 'fullName': 'Monday'},
      {'idx': 2, 'name': 'Tue', 'fullName': 'Tuesday'},
      {'idx': 3, 'name': 'Wed', 'fullName': 'Wednesday'},
      {'idx': 4, 'name': 'Thu', 'fullName': 'Thursday'},
      {'idx': 5, 'name': 'Fri', 'fullName': 'Friday'},
    ];

    int totalWeeklySessions = 0;
    if (result != null) {
      for (final list in result.weeklySchedule.values) {
        totalWeeklySessions += list.length;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070D1B) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Liquid Glass Top Navigation Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      IrisHaptics.actionMedium();
                      Navigator.of(context).pop();
                    },
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: textPrimary,
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Faculty Profile & Schedule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          item.department.isEmpty ? 'COMSATS Faculty Member' : item.department,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Specular Glass Card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IrisComponents.facultyAvatar(
                                imageUrl: resolveFacultyImageUrl(item.image).isEmpty ? null : resolveFacultyImageUrl(item.image),
                                gender: item.gender,
                                name: item.name,
                                radius: 36,
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
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.department.isEmpty ? 'Academic Faculty' : item.department,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          size: 13,
                                          color: IrisTokens.purple,
                                        ),
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
                          const SizedBox(height: 14),
                          // Quick Contact Action Bar
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: widget.onLaunchEmail,
                                  icon: const Icon(Icons.mail_outline_rounded, size: 16),
                                  label: const Text('Email Faculty'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: IrisTokens.brand,
                                    side: BorderSide(
                                      color: IrisTokens.brand.withValues(alpha: 0.35),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: widget.onLaunchPhone,
                                  icon: const Icon(Icons.phone_outlined, size: 16),
                                  label: const Text('Call Office'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: IrisTokens.success,
                                    side: BorderSide(
                                      color: IrisTokens.success.withValues(alpha: 0.35),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (result != null && result.liveSession != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: IrisTokens.success.withValues(alpha: isDark ? 0.15 : 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: IrisTokens.success.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: IrisTokens.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'LIVE IN SESSION NOW',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: IrisTokens.success,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${result.liveSession!.subject} • Room ${result.liveSession!.room} (${result.liveSession!.batch})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // View Segmented Control (lgw.GlassSegmentedControl)
                    lgw.GlassSegmentedControl(
                      selectedIndex: _viewSegmentIndex,
                      onSegmentSelected: (index) {
                        IrisSfx.pillTap();
                        setState(() => _viewSegmentIndex = index);
                      },
                      segments: [
                        'Daily Timeline',
                        'Week Matrix ($totalWeeklySessions)',
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (_viewSegmentIndex == 0) ...[
                      // Day Choice Chips (Mon - Fri)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: days.map((d) {
                            final idx = d['idx'] as int;
                            final name = d['name'] as String;
                            final count = result?.weeklySchedule[idx]?.length ?? 0;
                            final isSelected = _selectedDay == idx;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(name),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withValues(alpha: 0.25)
                                            : (isDark ? Colors.white12 : Colors.black12),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: isSelected ? Colors.white : textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.white : textPrimary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
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

                      // Day Schedule Cards
                      if (daySessions.isEmpty)
                        GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event_available_rounded,
                                    size: 40,
                                    color: textSecondary.withValues(alpha: 0.35),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No lectures scheduled for this day.',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ...daySessions.map((s) {
                          final isLive = s.isLive;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              child: Row(
                                children: [
                                  Container(
                                    width: 4.5,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isLive ? IrisTokens.success : IrisTokens.brand,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.subject,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule_rounded,
                                              size: 13,
                                              color: isLive ? IrisTokens.success : IrisTokens.brand,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${s.startTime} - ${s.endTime}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isLive ? IrisTokens.success : IrisTokens.brand,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.meeting_room_rounded,
                                              size: 13,
                                              color: textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              s.room,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                s.batch,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isLive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: IrisTokens.success,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'LIVE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ] else ...[
                      // Full Week Matrix Bento View
                      ...days.map((d) {
                        final dayIdx = d['idx'] as int;
                        final dayFullName = d['fullName'] as String;
                        final sessions = result?.weeklySchedule[dayIdx] ?? [];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dayFullName.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                        color: IrisTokens.brand,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: IrisTokens.brand.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${sessions.length} Lecture${sessions.length == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: IrisTokens.brand,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (sessions.isEmpty)
                                  Text(
                                    'No classes scheduled',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic,
                                      color: textSecondary.withValues(alpha: 0.6),
                                    ),
                                  )
                                else
                                  ...sessions.map((s) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: s.isLive
                                            ? IrisTokens.success.withValues(alpha: 0.12)
                                            : (isDark ? Colors.black26 : Colors.white),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: s.isLive
                                              ? IrisTokens.success.withValues(alpha: 0.35)
                                              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  s.subject,
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${s.startTime} - ${s.endTime}  •  ${s.room}  •  ${s.batch}',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (s.isLive)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: IrisTokens.success,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'LIVE',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        );
                      }),
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
  bool _showFullWeeklyMatrix = false; // Toggle between Day View & Full Week Matrix

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
      {'idx': 1, 'name': 'Mon', 'fullName': 'Monday'},
      {'idx': 2, 'name': 'Tue', 'fullName': 'Tuesday'},
      {'idx': 3, 'name': 'Wed', 'fullName': 'Wednesday'},
      {'idx': 4, 'name': 'Thu', 'fullName': 'Thursday'},
      {'idx': 5, 'name': 'Fri', 'fullName': 'Friday'},
    ];

    // Calculate total weekly sessions
    int totalWeeklySessions = 0;
    if (result != null) {
      for (final list in result.weeklySchedule.values) {
        totalWeeklySessions += list.length;
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),

            // Profile Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  IrisComponents.facultyAvatar(
                    imageUrl: item.image.isEmpty ? null : item.image,
                    gender: item.gender,
                    name: item.name,
                    radius: 32,
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
                            fontSize: 17.5,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.department.isEmpty ? 'COMSATS Faculty Member' : item.department,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
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

            // Quick Contact Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onLaunchEmail,
                      icon: const Icon(Icons.mail_outline_rounded, size: 16),
                      label: const Text('Email Faculty'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: IrisTokens.brand,
                        side: BorderSide(color: IrisTokens.brand.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onLaunchPhone,
                      icon: const Icon(Icons.phone_outlined, size: 16),
                      label: const Text('Call Office'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: IrisTokens.success,
                        side: BorderSide(color: IrisTokens.success.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Mode Selector Bar (Day View vs Full Week Matrix)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _showFullWeeklyMatrix ? 'FULL WEEKLY MATRIX' : 'DAY-WISE TIMETABLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: textSecondary,
                        ),
                      ),
                      Text(
                        '$totalWeeklySessions lectures scheduled this week',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  // Segmented Mode Switcher
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            IrisSfx.pillTap();
                            setState(() => _showFullWeeklyMatrix = false);
                          },
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: !_showFullWeeklyMatrix ? IrisTokens.brand : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_view_day_rounded,
                                  size: 13,
                                  color: !_showFullWeeklyMatrix ? Colors.white : textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Daily',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: !_showFullWeeklyMatrix ? Colors.white : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            IrisSfx.pillTap();
                            setState(() => _showFullWeeklyMatrix = true);
                          },
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _showFullWeeklyMatrix ? IrisTokens.brand : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.grid_view_rounded,
                                  size: 13,
                                  color: _showFullWeeklyMatrix ? Colors.white : textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Week Matrix',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: _showFullWeeklyMatrix ? Colors.white : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Content Body: Day View OR Full Week Matrix
            if (!_showFullWeeklyMatrix) ...[
              // Day Selector Chips (Mon - Fri)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: days.map((d) {
                    final idx = d['idx'] as int;
                    final name = d['name'] as String;
                    final count = result?.weeklySchedule[idx]?.length ?? 0;
                    final isSelected = _selectedDay == idx;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : (isDark ? Colors.white12 : Colors.black12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? Colors.white : textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : textPrimary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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

              // Day Schedule Timeline Cards
              Expanded(
                child: daySessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              size: 44,
                              color: textSecondary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No scheduled lectures for this day.',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                          ],
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
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isLive
                                  ? IrisTokens.success.withValues(alpha: isDark ? 0.14 : 0.08)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.02)),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isLive
                                    ? IrisTokens.success.withValues(alpha: 0.45)
                                    : (isDark ? Colors.white10 : Colors.black12),
                                width: isLive ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Left Accent Pillar
                                Container(
                                  width: 4.5,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isLive ? IrisTokens.success : IrisTokens.brand,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Subject Info & Room Tags
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.subject,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.schedule_rounded,
                                            size: 13,
                                            color: isLive ? IrisTokens.success : IrisTokens.brand,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${s.startTime} - ${s.endTime}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isLive ? IrisTokens.success : IrisTokens.brand,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            Icons.meeting_room_rounded,
                                            size: 13,
                                            color: textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            s.room,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              s.batch,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isLive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: IrisTokens.success,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'LIVE NOW',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ] else ...[
              // Full Weekly Overview Matrix View (Mon - Fri Bento Stack)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, idx) {
                    final d = days[idx];
                    final dayIdx = d['idx'] as int;
                    final dayFullName = d['fullName'] as String;
                    final sessions = result?.weeklySchedule[dayIdx] ?? [];

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dayFullName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                  color: IrisTokens.brand,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: IrisTokens.brand.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${sessions.length} Lecture${sessions.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: IrisTokens.brand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (sessions.isEmpty)
                            Text(
                              'No classes scheduled',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                color: textSecondary.withValues(alpha: 0.6),
                              ),
                            )
                          else
                            ...sessions.map((s) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: s.isLive
                                      ? IrisTokens.success.withValues(alpha: 0.12)
                                      : (isDark ? Colors.black26 : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: s.isLive
                                        ? IrisTokens.success.withValues(alpha: 0.35)
                                        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.subject,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${s.startTime} - ${s.endTime}  •  ${s.room}  •  ${s.batch}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (s.isLive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: IrisTokens.success,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'LIVE',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
