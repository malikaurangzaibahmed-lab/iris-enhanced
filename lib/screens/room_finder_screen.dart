import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import '../services/room_occupancy_service.dart';
import '../services/room_persistence_service.dart';
import '../services/analytics_manager.dart';
import '../core/models.dart';
import '../core/format_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/glowing_input_wrapper.dart';
import '../core/vital_theme.dart';
import '../services/ui_feedback.dart';
import '../services/remote_config_service.dart';
import 'students_week_screen.dart';

// ==========================================================================
// ROOM FINDER SCREEN OVERHAUL
// ==========================================================================

class RoomFinderScreen extends StatefulWidget {
  final dynamic memory;
  final dynamic brain;

  const RoomFinderScreen({required this.memory, required this.brain, super.key});

  @override
  State<RoomFinderScreen> createState() => _RoomFinderScreenState();
}

class _RoomFinderScreenState extends State<RoomFinderScreen> {
  final RoomOccupancyService _service = RoomOccupancyService();
  final RoomPersistenceService _persistence = RoomPersistenceService();
  String _query = '';
  double? _targetHour;
  int? _targetDay;
  int? _targetSlot;
  String _filterBuilding = 'All';
  
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _slots = [
    'Slot 1 (08:30 - 10:00 AM)',
    'Slot 2 (10:00 - 11:30 AM)',
    'Slot 3 (11:30 AM - 01:00 PM)',
    'Slot 4 (01:40 - 03:05 PM)',
    'Slot 5 (03:05 - 04:30 PM)',
  ];

  // Caching variables for performance optimization
  List<RoomAvailability> _allAvailability = [];
  List<RoomAvailability> _filteredRooms = [];
  RoomRecommendation _recommendation = RoomRecommendation(recommended: null, reason: '', alternatives: const []);
  List<String> _buildings = ['All'];
  String _filterStatus = 'All'; // 'All', 'Vacant', 'Occupied', 'Labs'
  bool _showExamSlots = false;

  List<String> get _currentSlots {
    final period = RemoteConfigService.activeAcademicPeriod.value;
    final isExamPeriod = period == 'midterms' || period == 'finals' || period == 'exams';
    if (isExamPeriod && _showExamSlots) {
      return ['Exam Slot 1 (09:30 - 11:30 AM)', 'Exam Slot 2 (01:30 - 03:30 PM)'];
    }
    return _slots;
  }

  ({double start, double end}) _slotToRange(int slotIndex) {
    final period = RemoteConfigService.activeAcademicPeriod.value;
    final isExamPeriod = period == 'midterms' || period == 'finals' || period == 'exams';
    if (isExamPeriod && _showExamSlots) {
      switch (slotIndex) {
        case 0: return (start: 9.5, end: 11.5);  // 09:30 AM - 11:30 AM Exam Paper Slot
        case 1: return (start: 13.5, end: 15.5); // 01:30 PM - 03:30 PM Exam Paper Slot
        default: return (start: 9.5, end: 11.5);
      }
    }
    switch (slotIndex) {
      case 0: return (start: 8.5, end: 10.0);     // 08:30 - 10:00 AM (1st)
      case 1: return (start: 10.0, end: 11.5);    // 10:00 - 11:30 AM (2nd)
      case 2: return (start: 11.5, end: 13.0);    // 11:30 AM - 01:00 PM (3rd)
      case 3: return (start: 13.667, end: 15.083); // 01:40 - 03:05 PM (4th)
      case 4: return (start: 15.083, end: 16.5);   // 03:05 - 04:30 PM (5th)
      default: return (start: 8.5, end: 10.0);
    }
  }

  @override
  void initState() {
    super.initState();
    AnalyticsManager().trackScreenView('RoomFinderScreen');
    _initService();
  }

  Future<void> _initService() async {
    final storedRooms = await _persistence.loadRooms();
    final Map<String, Room> roomMap = {for (var r in storedRooms) r.id: r};
    
    final sessionsRooms = widget.memory.activeSessions().map((s) => s.room).toSet();
    bool newlyAdded = false;

    for (final r in sessionsRooms) {
      if (r == 'TBD' || r.isEmpty) continue;
      
      if (!roomMap.containsKey(r)) {
        final newRoom = _persistence.generateDefaultRoom(r);
        roomMap[r] = newRoom;
        newlyAdded = true;
      }
    }

    if (newlyAdded) {
      await _persistence.saveRooms(roomMap.values.toList());
    }

    for (final room in roomMap.values) {
      _service.registerRoomModel(room);
    }
    
    _updateFilteredAvailability();
  }

  void _updateFilteredAvailability() {
    if (!mounted) return;
    final now = DateTime.now();
    final day = _targetDay ?? now.weekday;
    final allSessions = widget.memory.activeSessions();

    if (_targetSlot != null) {
      final range = _slotToRange(_targetSlot!);
      _allAvailability = _service.getRoomAvailabilityForSlotRange(allSessions, range.start, range.end, day);
      _recommendation = RoomRecommendation(recommended: null, reason: '', alternatives: const []);
    } else if (_targetHour != null) {
      _allAvailability = _service.getRoomAvailabilityAt(allSessions, _targetHour!, day);
      _recommendation = RoomRecommendation(recommended: null, reason: '', alternatives: const []);
    } else {
      final hour = now.hour + (now.minute / 60.0);
      _allAvailability = _service.getRoomAvailabilityAt(allSessions, hour, day);
      _recommendation = _service.getSmartRecommendation(
        allSessions, 
        widget.memory.activeSessions().where((s) => s.batchKey.batch == 'UNKNOWN').toList(),
        80,
      );
    }

    final baseBuildings = _allAvailability
        .map((e) => e.building)
        .where((b) => b != 'Other' && b != 'Academic Block')
        .toSet()
        .toList();
    baseBuildings.sort();
    
    setState(() {
      _buildings = ['All', ...baseBuildings];
      _filteredRooms = _allAvailability.where((a) {
        final q = _query.toLowerCase().trim();
        final matchesQuery = q.isEmpty ||
            a.roomId.toLowerCase().contains(q) || 
            a.building.toLowerCase().contains(q) ||
            (a.formattedLocation != null && a.formattedLocation!.toLowerCase().contains(q)) ||
            (a.occupiedBy != null && a.occupiedBy!.toLowerCase().contains(q)) ||
            (a.occupiedByTeacher != null && a.occupiedByTeacher!.toLowerCase().contains(q));
        final matchesBuilding = _filterBuilding == 'All' || a.building == _filterBuilding;
        final isLab = a.roomId.toLowerCase().contains('lab') || a.amenities.any((am) => am.toLowerCase().contains('lab'));
        final matchesStatus = _filterStatus == 'All' ||
            (_filterStatus == 'Vacant' && a.isAvailable) ||
            (_filterStatus == 'Occupied' && !a.isAvailable) ||
            (_filterStatus == 'Labs' && isLab);
        return matchesQuery && matchesBuilding && matchesStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 16;

    final totalRoomsCount = _allAvailability.length;
    final availableRoomsCount = _allAvailability.where((a) => a.isAvailable).length;
    final double vacancyPercent = totalRoomsCount > 0 ? (availableRoomsCount / totalRoomsCount) : 0.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? IrisTokens.surfaceDark : IrisTokens.surfaceLight,
      appBar: irisFrostedAppBar(title: 'Room Finder', isDark: isDark),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          CustomScrollView(
            physics: const ButterScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, topInset, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    
                    // 1. Premium Visual Donut Header Analytics Card
                    _buildOccupancyConsoleCard(availableRoomsCount, totalRoomsCount, vacancyPercent, isDark),
                    const SizedBox(height: 24),

                    // 2. Smart recommendation layer
                    if (_recommendation.recommended != null && _targetHour == null) ...[
                      _buildSectionHeader('SMART RECOMMENDATION', isDark),
                      const SizedBox(height: 12),
                      _buildRecommendationCard(_recommendation.recommended!, _recommendation.reason, isDark),
                      const SizedBox(height: 28),
                    ],

                    // 3. Search & Custom Time Selection Deck
                    _buildSearchDeck(isDark),
                    const SizedBox(height: 24),

                    // 3b. Space Status & Type Filter
                    _buildSectionHeader('SPACE STATUS & TYPE', isDark),
                    const SizedBox(height: 12),
                    _buildHorizontalPillRow(
                      items: const ['All', 'Vacant', 'Occupied', 'Labs'],
                      selectedValue: _filterStatus,
                      onSelected: (val) {
                        setState(() {
                          _filterStatus = val;
                          _updateFilteredAvailability();
                        });
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),

                    // 4. Quick building filtering pill deck
                    _buildSectionHeader('BUILDING BLOCKS', isDark),
                    const SizedBox(height: 12),
                    _buildHorizontalPillRow(
                      items: _buildings,
                      selectedValue: _filterBuilding,
                      onSelected: (val) {
                        setState(() {
                          _filterBuilding = val;
                          _updateFilteredAvailability();
                        });
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    
                    // 5. Day selectors bento grid
                    _buildSectionHeader('SELECT TARGET DAY', isDark),
                    const SizedBox(height: 12),
                    _buildHorizontalPillRow(
                      items: _days,
                      selectedValue: _days[( _targetDay ?? DateTime.now().weekday) - 1],
                      onSelected: (val) {
                        setState(() {
                          _targetDay = _days.indexOf(val) + 1;
                          _updateFilteredAvailability();
                        });
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),

                    ValueListenableBuilder<String>(
                      valueListenable: RemoteConfigService.activeAcademicPeriod,
                      builder: (context, period, _) {
                        final isExam = period == 'midterms' || period == 'finals' || period == 'exams';
                        if (!isExam) {
                          return _buildSectionHeader('LECTURE SLOTS', isDark);
                        }

                        final examTitle = period == 'midterms' ? 'Midterm Slots' : 'Final Slots';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              _showExamSlots ? 'EXAM PAPER SLOTS' : 'LECTURE SLOTS',
                              isDark,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        IrisHaptics.chipSelect();
                                        setState(() {
                                          _showExamSlots = false;
                                          _targetSlot = null;
                                          _targetHour = null;
                                          _updateFilteredAvailability();
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        decoration: BoxDecoration(
                                          color: !_showExamSlots
                                              ? (isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(9),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Lecture Slots',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: !_showExamSlots ? FontWeight.w800 : FontWeight.w600,
                                              color: !_showExamSlots
                                                  ? (isDark ? Colors.white : Colors.black87)
                                                  : (isDark ? Colors.white54 : Colors.black45),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        IrisHaptics.chipSelect();
                                        setState(() {
                                          _showExamSlots = true;
                                          _targetSlot = null;
                                          _targetHour = null;
                                          _updateFilteredAvailability();
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _showExamSlots
                                              ? IrisTokens.brand.withValues(alpha: isDark ? 0.35 : 0.20)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(9),
                                        ),
                                        child: Center(
                                          child: Text(
                                            examTitle,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: _showExamSlots ? FontWeight.w800 : FontWeight.w600,
                                              color: _showExamSlots
                                                  ? (isDark ? Colors.white : Colors.black87)
                                                  : (isDark ? Colors.white54 : Colors.black45),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(_currentSlots.length, (index) {
                          final isSelected = _targetSlot == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: RoomFilterChip(
                              label: _currentSlots[index],
                              isSelected: isSelected,
                              onSelected: (s) {
                                setState(() {
                                  if (s) {
                                    _targetSlot = index;
                                    _targetHour = _slotToRange(index).start;
                                  } else {
                                    _targetSlot = null;
                                    _targetHour = null;
                                  }
                                  _updateFilteredAvailability();
                                });
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('ALL SPACES', isDark),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),

              // 7. Availabilities list mapping
              if (_filteredRooms.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildEmptyState(isDark),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final a = _filteredRooms[index];
                        return RepaintBoundary(
                          child: RoomAvailabilityCard(
                            availability: a,
                            isDark: isDark,
                            allSessions: widget.memory.sessions,
                            targetDay: _targetDay ?? DateTime.now().weekday,
                          ),
                        );
                      },
                      childCount: _filteredRooms.length,
                    ),
                  ),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // VIEW BUILDERS
  // ==========================================================================

  Widget _buildOccupancyConsoleCard(int free, int total, double percent, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'REALTIME ROOM INDEX',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                      ),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<String>(
                      valueListenable: RemoteConfigService.activeAcademicPeriod,
                      builder: (context, period, _) {
                        String badge = 'CLASSES MODE';
                        if (period == 'midterms' || period == 'finals' || period == 'exams') {
                          badge = '📝 EXAM HALL MODE';
                        } else if (period == 'sports_week' || period == 'students_week') {
                          badge = '🏆 GALA MODE';
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: IrisTokens.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: IrisTokens.brand,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$free Rooms Vacant',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Out of $total registered slots on campus',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Custom occupancy donut radial chart
          SizedBox(
            width: 82,
            height: 82,
            child: CustomPaint(
              painter: _OccupancyDonutPainter(
                percent: percent,
                color: Color.lerp(const Color(0xFFEF4444), const Color(0xFF10B981), percent) ?? const Color(0xFF10B981),
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchDeck(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: IrisGlowingInputWrapper(
            borderRadius: 20,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              borderRadius: 20,
              child: TextField(
                onChanged: (v) {
                  _query = v;
                  _updateFilteredAvailability();
                },
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search room, lab, or block...',
                  prefixIcon: const Icon(Icons.search_rounded, color: IrisTokens.brand),
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildTimePicker(context, isDark),
      ],
    );
  }

  Widget _buildHorizontalPillRow({
    required List<String> items,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items.map((item) {
          final isSelected = item == selectedValue;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                item,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  IrisHaptics.chipSelect();
                  onSelected(item);
                }
              },
              selectedColor: IrisTokens.brand,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(
                color: isSelected
                    ? IrisTokens.brandLight.withValues(alpha: 0.3)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                width: 1.2,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimePicker(BuildContext context, bool isDark) {
    final active = _targetHour != null;
    return Container(
      decoration: BoxDecoration(
        color: active
            ? IrisTokens.brand.withValues(alpha: 0.16)
            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? IrisTokens.brand.withValues(alpha: 0.4) : (isDark ? Colors.white10 : Colors.black12),
          width: 1.2,
        ),
      ),
      child: IconButton(
        onPressed: () async {
          final time = await showTimePicker(
            context: context, 
            initialTime: TimeOfDay.now()
          );
          if (time != null) {
            setState(() {
              _targetHour = time.hour + time.minute / 60.0;
              _targetSlot = null; // Clear slot if manual time picked
              _updateFilteredAvailability();
            });
            AnalyticsManager().trackEvent('room_pick_time', properties: {
              'hour': time.hour,
              'minute': time.minute,
            });
          }
        },
        icon: Icon(
          active ? Icons.history_toggle_off_rounded : Icons.access_time_rounded,
          color: active ? IrisTokens.brand : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(RoomAvailability room, String reason, bool isDark) {
    return RoomFinderAnimationWidget(
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderRadius: 28,
        glow: true,
        accentColor: IrisTokens.brand,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [IrisTokens.brand, IrisTokens.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.roomId,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reason,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildSmallInfo(Icons.business_rounded, room.building, isDark),
                const SizedBox(width: 20),
                _buildSmallInfo(Icons.bolt_rounded, 'Study Score: ${room.studyScore.toInt()}%', isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallInfo(IconData icon, String label, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: IrisTokens.brand),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Vacant Rooms Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Try altering day or building filter configurations.',
            textAlign: TextAlign.center,
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
}

// ==========================================================================
// RADIAL PAINTER: OCCUPANCY DONUT
// ==========================================================================

class _OccupancyDonutPainter extends CustomPainter {
  final double percent;
  final Color color;
  final bool isDark;

  _OccupancyDonutPainter({
    required this.percent,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;

    final bgPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percent,
      false,
      progressPaint,
    );

    // Write text in center
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(percent * 100).toInt()}%',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _OccupancyDonutPainter oldDelegate) =>
      oldDelegate.percent != percent ||
      oldDelegate.color != color ||
      oldDelegate.isDark != isDark;
}

// ==========================================================================
// ROOM AVAILABILITY CARD
// ==========================================================================

class RoomAvailabilityCard extends StatelessWidget {
  final RoomAvailability availability;
  final bool isDark;
  final List<ClassSession> allSessions;
  final int targetDay;

  const RoomAvailabilityCard({
    required this.availability,
    required this.isDark,
    required this.allSessions,
    required this.targetDay,
    super.key,
  });

  Widget _buildOccupancyTimeline(String roomId, bool isDark) {
    final cachedSlots = availability.slotOccupancy;
    if (cachedSlots != null && cachedSlots.length == 5) {
      return Row(
        children: List.generate(5, (slotIndex) {
          final isOccupied = cachedSlots[slotIndex];
          return Expanded(
            child: Container(
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: isOccupied
                    ? const Color(0xFFEF4444).withValues(alpha: 0.8)
                    : const Color(0xFF10B981).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3.5),
                border: Border.all(
                  color: isOccupied
                      ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                      : const Color(0xFF10B981).withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
            ),
          );
        }),
      );
    }

    final slotStarts = [8.5, 9.916, 11.333, 13.666, 15.083];
    final slotEnds = [9.916, 11.333, 12.75, 15.083, 16.5];

    return Row(
      children: List.generate(5, (slotIndex) {
        final startHour = slotStarts[slotIndex];
        final endHour = slotEnds[slotIndex];
        final slotMiddle = startHour + (endHour - startHour) / 2;
        
        final isOccupied = allSessions.any((s) =>
            s.room == roomId &&
            s.dayIndex == targetDay &&
            s.safeStartVal <= slotMiddle &&
            slotMiddle < s.safeEndVal);

        return Expanded(
          child: Container(
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: isOccupied
                  ? const Color(0xFFEF4444).withValues(alpha: 0.8)
                  : const Color(0xFF10B981).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(3.5),
              border: Border.all(
                color: isOccupied
                    ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                    : const Color(0xFF10B981).withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = availability.isAvailable ? IrisTokens.success : IrisTokens.error;
    final locationText = availability.formattedLocation ??
        RoomPersistenceService.parseRoomCode(availability.roomId).formattedLocation;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: 32,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(32),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          availability.roomId.replaceAll(RegExp(r'[^0-9]'), '').isEmpty 
                            ? availability.roomId.substring(0, 1).toUpperCase()
                            : availability.roomId.replaceAll(RegExp(r'[^0-9]'), '').substring(0, math.min(2, availability.roomId.replaceAll(RegExp(r'[^0-9]'), '').length)),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            availability.roomId,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.business_rounded, 
                                size: 14, 
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                locationText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
                          ),
                          child: Text(
                            availability.isAvailable ? 'FREE' : 'IN USE',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          availability.isAvailable 
                            ? (availability.minulesFreeUntilNextSession != null ? '${availability.minulesFreeUntilNextSession}m free' : 'Until EOD')
                            : 'Until ${FormatGuard.formatDecimalTime(availability.occupiedUntil ?? 0)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: statusColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Schedule Timeline Grid Overlay
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "DAILY OCCUPANCY TIMELINE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.40),
                          ),
                        ),
                        Text(
                          "8:30 AM - 4:30 PM",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildOccupancyTimeline(availability.roomId, isDark),
                  ],
                ),
              ),

              if (availability.nextSessionSubject != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.event_note_rounded, 
                          size: 14, 
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Next: ${availability.nextSessionSubject} at ${FormatGuard.formatDecimalTime(availability.nextSessionAt ?? 0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (isDark ? Colors.white70 : Colors.black87),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
  }
}

// ==========================================================================
// FILTER CHIP
// ==========================================================================

class RoomFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const RoomFilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          fontSize: 13,
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: IrisTokens.brand,
      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      side: BorderSide(
        color: isSelected
            ? IrisTokens.brandLight.withValues(alpha: 0.3)
            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
        width: 1.2,
      ),
      showCheckmark: false,
    );
  }
}
