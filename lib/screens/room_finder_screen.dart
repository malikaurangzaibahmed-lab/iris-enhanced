import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassCard;
import '../core/tokens.dart';
import '../core/animations.dart';
import '../widgets/iris_components.dart';
import '../services/room_occupancy_service.dart';
import '../services/room_persistence_service.dart';
import '../services/analytics_manager.dart';
import '../core/models.dart';
import '../core/format_guard.dart';
import '../widgets/glass_card.dart';
import '../core/vital_theme.dart';
import 'students_week_screen.dart';

class RoomFinderScreen extends StatefulWidget {
  final dynamic memory; // Using dynamic for now to avoid circular deps if possible
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
  final List<String> _slots = ['1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th'];

  // Caching variables for performance optimization
  List<RoomAvailability> _allAvailability = [];
  List<RoomAvailability> _filteredRooms = [];
  RoomRecommendation _recommendation = RoomRecommendation(recommended: null, reason: '', alternatives: const []);
  String? _likelyBuilding;
  int _likelyBuildingCount = 0;
  List<String> _buildings = ['All'];
  
  double _slotToHour(int slotIndex) {
    return 8.5 + (slotIndex * 1.5);
  }

  String? _bestBuildingSuggestion(List<RoomAvailability> availability) {
    final counts = <String, int>{};
    for (final room in availability) {
      if (!room.isAvailable) continue;
      if (room.building == 'Other' || room.building == 'Academic Block') continue;
      counts[room.building] = (counts[room.building] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.first.key;
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
    
    final sessionsRooms = widget.memory.sessions.map((s) => s.room).toSet();
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
    final hour = _targetHour ?? (now.hour + (now.minute / 60.0));
    final allSessions = widget.memory.sessions;

    _allAvailability = _service.getRoomAvailabilityAt(allSessions, hour, day);
    
    if (_targetHour == null) {
      _recommendation = _service.getSmartRecommendation(
        allSessions, 
        widget.memory.sessions.where((s) => s.batchKey.batch == 'UNKNOWN').toList(),
        80,
      );
    } else {
      _recommendation = RoomRecommendation(recommended: null, reason: '', alternatives: const []);
    }

    _likelyBuilding = _bestBuildingSuggestion(_allAvailability);
    _likelyBuildingCount = _likelyBuilding == null
        ? 0
        : _allAvailability
            .where((a) => a.isAvailable && a.building == _likelyBuilding)
            .length;

    final baseBuildings = _allAvailability
        .map((e) => e.building)
        .where((b) => b != 'Other' && b != 'Academic Block')
        .toSet()
        .toList();
    baseBuildings.sort();
    
    setState(() {
      _buildings = ['All', ...baseBuildings];
      _filteredRooms = _allAvailability.where((a) {
        final matchesQuery = a.roomId.toLowerCase().contains(_query.toLowerCase()) || 
                            a.building.toLowerCase().contains(_query.toLowerCase());
        final matchesBuilding = _filterBuilding == 'All' || a.building == _filterBuilding;
        return matchesQuery && matchesBuilding;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
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
                    if (_recommendation.recommended != null && _targetHour == null) ...[
                      _buildSectionHeader('SMART RECOMMENDATION', isDark),
                      const SizedBox(height: 12),
                      _buildRecommendationCard(_recommendation.recommended!, _recommendation.reason, isDark),
                      const SizedBox(height: 32),
                    ],
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) {
                              _query = v;
                              _updateFilteredAvailability();
                            },
                            style: IrisTextStyles.body(context).copyWith(fontWeight: FontWeight.w600),
                            decoration: irisFrostedInputDecoration(
                              label: 'Search rooms or blocks...',
                              isDark: isDark,
                              prefixIcon: Icons.search_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildTimePicker(context, isDark),
                      ],
                    ),
                    if (_query.trim().length < 3 && _filterBuilding == 'All' && _likelyBuilding != null) ...[
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: IrisTokens.brand.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: IrisTokens.brand,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Likely match: $_likelyBuilding has $_likelyBuildingCount open room${_likelyBuildingCount == 1 ? '' : 's'} right now',
                                style: IrisTextStyles.metaInfo(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                _filterBuilding = _likelyBuilding!;
                                _updateFilteredAvailability();
                              },
                              child: const Text('Use filter'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    _buildSectionHeader('SELECT DAY', isDark),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(7, (index) {
                          final dayNum = index + 1;
                          final isSelected = (_targetDay ?? DateTime.now().weekday) == dayNum;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: RoomFilterChip(
                              label: _days[index],
                              isSelected: isSelected,
                              onSelected: (s) {
                                _targetDay = dayNum;
                                _updateFilteredAvailability();
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('LECTURE SLOTS', isDark),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(_slots.length, (index) {
                          final isSelected = _targetSlot == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: RoomFilterChip(
                              label: _slots[index],
                              isSelected: isSelected,
                              onSelected: (s) {
                                if (s) {
                                  _targetSlot = index;
                                  _targetHour = _slotToHour(index);
                                } else {
                                  _targetSlot = null;
                                  _targetHour = null;
                                }
                                _updateFilteredAvailability();
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('FILTER BLOCKS', isDark),
                    const SizedBox(height: 12),
                    
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _buildings.map((b) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: RoomFilterChip(
                            label: b,
                            isSelected: _filterBuilding == b,
                            onSelected: (s) {
                              _filterBuilding = b;
                              _updateFilteredAvailability();
                              AnalyticsManager().trackEvent('room_filter_building', properties: {'building': b});
                            },
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('ROOM AVAILABILITY', isDark),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_filteredRooms.length} found',
                            style: IrisTextStyles.metaInfo(context).copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
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
                          child: RoomAvailabilityCard(availability: a, isDark: isDark),
                        );
                      },
                      childCount: _filteredRooms.length,
                    ),
                  ),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: IrisTextStyles.overline(context).copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w900),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 60),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.search_off_rounded,
            size: 48,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'No rooms match your filters',
          style: IrisTextStyles.classSubject(context).copyWith(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Try adjusting your time or building filters',
          textAlign: TextAlign.center,
          style: IrisTextStyles.body(context).copyWith(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildTimePicker(BuildContext context, bool isDark) {
    return IconButton.filledTonal(
      onPressed: () async {
        final time = await showTimePicker(
          context: context, 
          initialTime: TimeOfDay.now()
        );
        if (time != null) {
          setState(() {
            _targetHour = time.hour + time.minute / 60.0;
            _targetSlot = null; // Clear slot if manual time picked
          });
          AnalyticsManager().trackEvent('room_pick_time', properties: {
            'hour': time.hour,
            'minute': time.minute,
          });
        }
      },
      icon: Icon(_targetHour == null ? Icons.access_time_rounded : Icons.history_toggle_off_rounded),
      style: IconButton.styleFrom(
        backgroundColor: _targetHour != null ? IrisTokens.brand.withValues(alpha: 0.2) : null,
      ),
    );
  }

  Widget _buildRecommendationCard(RoomAvailability room, String reason, bool isDark) {
    return RoomFinderAnimationWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [IrisTokens.brand, IrisTokens.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: IrisTokens.brand.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${room.roomId}',
                      style: IrisTextStyles.classSubject(context).copyWith(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    Text(
                      reason,
                      style: IrisTextStyles.metaInfo(context).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildSmallInfo(Icons.business_rounded, room.building, isDark),
              const SizedBox(width: 20),
              _buildSmallInfo(Icons.bolt_rounded, 'Study Score: ${room.studyScore.toInt()}%', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(IconData icon, String label, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: IrisTokens.brand),
        const SizedBox(width: 4),
        Text(label, style: IrisTextStyles.label(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class RoomAvailabilityCard extends StatelessWidget {
  final RoomAvailability availability;
  final bool isDark;

  const RoomAvailabilityCard({required this.availability, required this.isDark, super.key});

  @override
  Widget build(BuildContext context) {
    final statusColor = availability.isAvailable ? IrisTokens.success : IrisTokens.error;
    
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
                          style: IrisTextStyles.classProgress(context).copyWith(color: statusColor, fontWeight: FontWeight.w900, fontSize: 24),
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
                            style: IrisTextStyles.classSubject(context).copyWith(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
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
                                availability.building,
                                style: IrisTextStyles.metaInfo(context).copyWith(fontSize: 13, fontWeight: FontWeight.w700),
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
                            style: IrisTextStyles.badgeText(context).copyWith(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          availability.isAvailable 
                            ? (availability.minulesFreeUntilNextSession != null ? '${availability.minulesFreeUntilNextSession}m free' : 'Until EOD')
                            : 'Until ${FormatGuard.formatDecimalTime(availability.occupiedUntil ?? 0)}',
                          style: IrisTextStyles.metaInfo(context).copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: statusColor.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Slot Indicator Bar
              ClipRRect(
                child: Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: availability.isAvailable ? 1.0 : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [statusColor, statusColor.withValues(alpha: 0.6)],
                        ),
                      ),
                    ),
                  ),
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
                          style: IrisTextStyles.metaInfo(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
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
    return GlassChip(
      label: label,
      selected: isSelected,
      onTap: () => onSelected(!isSelected),
      useOwnLayer: true,
      selectedColor: IrisTokens.brand.withOpacity(0.3),
      labelStyle: IrisTextStyles.label(context).copyWith(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
