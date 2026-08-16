import 'package:iris/core/models.dart';
import 'package:iris/core/format_guard.dart';

class RoomOccupancyService {
  final Map<String, Room> _rooms = {};
  final Map<String, Department> _departments = {};

  void registerDepartment(String departmentId, String departmentName) {
    _departments[departmentId] = Department(
      id: departmentId,
      name: departmentName,
      registeredAt: DateTime.now(),
    );
  }

  void registerRoom(String roomId, String building, int capacity, List<String> amenities) {
    final cleanId = FormatGuard.sanitizeRoom(roomId);
    _rooms[cleanId] = Room(
      id: cleanId,
      building: building,
      capacity: capacity,
      amenities: amenities,
      registeredAt: DateTime.now(),
    );
  }

  void registerRoomModel(Room room) {
    final cleanId = FormatGuard.sanitizeRoom(room.id);
    _rooms[cleanId] = room;
  }

  /// Get all available rooms right now
  List<RoomAvailability> getAvailableRoomsNow(
    List<ClassSession> allSessions,
  ) {
    final now = DateTime.now();
    final currentHour = now.hour + (now.minute / 60.0);
    final dayIndex = now.weekday;

    // First pass to build raw availability
    final rawAvailability = <RoomAvailability>[];
    for (final room in _rooms.values) {
      final cleanRoomId = FormatGuard.sanitizeRoom(room.id);
      final occupyingSessions = allSessions.where((s) =>
          FormatGuard.sanitizeRoom(s.room) == cleanRoomId &&
          s.dayIndex == dayIndex &&
          s.safeStartVal <= currentHour &&
          currentHour < s.actualEndVal);

      if (occupyingSessions.isEmpty) {
        final nextSession = _getNextSession(room.id, allSessions, dayIndex, currentHour);
        rawAvailability.add(RoomAvailability(
          roomId: room.id,
          building: room.building,
          capacity: room.capacity,
          amenities: room.amenities,
          isAvailable: true,
          occupiedUntil: null,
          nextSessionAt: nextSession?.safeStartVal,
          nextSessionSubject: nextSession?.subject,
          minulesFreeUntilNextSession: nextSession != null
              ? ((nextSession.safeStartVal - currentHour) * 60).toInt()
              : null,
          studyScore: 0, // Placeholder
        ));
      } else {
        final session = occupyingSessions.first;
        rawAvailability.add(RoomAvailability(
          roomId: room.id,
          building: room.building,
          capacity: room.capacity,
          amenities: room.amenities,
          isAvailable: false,
          occupiedUntil: session.actualEndVal,
          occupiedBy: session.subject,
          occupiedByTeacher: session.teacher,
          minulesFreeUntilNextSession: ((session.actualEndVal - currentHour) * 60).toInt(),
          studyScore: 0,
        ));
      }
    }

    // Second pass to calculate study score with building context
    final availability = rawAvailability.map((a) {
      if (!a.isAvailable) return a;
      final room = _rooms[a.roomId]!;
      final nextSession = _getNextSession(room.id, allSessions, dayIndex, currentHour);
      return RoomAvailability(
        roomId: a.roomId,
        building: a.building,
        capacity: a.capacity,
        amenities: a.amenities,
        isAvailable: true,
        occupiedUntil: null,
        nextSessionAt: a.nextSessionAt,
        nextSessionSubject: a.nextSessionSubject,
        minulesFreeUntilNextSession: a.minulesFreeUntilNextSession,
        studyScore: _calculateStudyScore(room, nextSession, rawAvailability),
      );
    }).toList();

    // Sort by study score (best spaces first)
    availability.sort((a, b) => b.studyScore.compareTo(a.studyScore));
    return availability;
  }

  /// Get availability for a specific future time
  List<RoomAvailability> getRoomAvailabilityAt(
    List<ClassSession> allSessions,
    double targetHour,
    int dayIndex,
  ) {
    final rawAvailability = <RoomAvailability>[];
    for (final room in _rooms.values) {
      final cleanRoomId = FormatGuard.sanitizeRoom(room.id);
      final occupyingSessions = allSessions.where((s) =>
          FormatGuard.sanitizeRoom(s.room) == cleanRoomId &&
          s.dayIndex == dayIndex &&
          s.safeStartVal <= targetHour &&
          targetHour < s.actualEndVal);

      final isAvailable = occupyingSessions.isEmpty;
      final nextSession = isAvailable
          ? _getNextSession(room.id, allSessions, dayIndex, targetHour)
          : null;

      rawAvailability.add(RoomAvailability(
        roomId: room.id,
        building: room.building,
        capacity: room.capacity,
        amenities: room.amenities,
        isAvailable: isAvailable,
        occupiedUntil: isAvailable ? null : occupyingSessions.first.actualEndVal,
        nextSessionAt: nextSession?.safeStartVal,
        nextSessionSubject: nextSession?.subject,
        minulesFreeUntilNextSession: nextSession != null
            ? ((nextSession.safeStartVal - targetHour) * 60).toInt()
            : null,
        studyScore: 0,
      ));
    }

    final availability = rawAvailability.map((a) {
      if (!a.isAvailable) return a;
      final room = _rooms[a.roomId]!;
      final nextSession = _getNextSession(room.id, allSessions, dayIndex, targetHour);
      return RoomAvailability(
        roomId: a.roomId,
        building: a.building,
        capacity: a.capacity,
        amenities: a.amenities,
        isAvailable: true,
        occupiedUntil: null,
        nextSessionAt: a.nextSessionAt,
        nextSessionSubject: a.nextSessionSubject,
        minulesFreeUntilNextSession: a.minulesFreeUntilNextSession,
        studyScore: _calculateStudyScore(room, nextSession, rawAvailability),
      );
    }).toList();

    availability.sort((a, b) => b.studyScore.compareTo(a.studyScore));
    return availability;
  }

  /// Get available rooms for a specific time RANGE (not just a point in time)
  /// Check if room is free for entire duration
  List<String> getAvailableRoomsForTimeRange(
    List<ClassSession> allSessions,
    int dayIndex,
    double startTime,
    double endTime,
  ) {
    final availableRooms = <String>[];

    for (final room in _rooms.values) {
      final cleanRoomId = FormatGuard.sanitizeRoom(room.id);
      // Check if any session overlaps with this time range
      final conflicts = allSessions.where((s) =>
          FormatGuard.sanitizeRoom(s.room) == cleanRoomId &&
          s.dayIndex == dayIndex &&
          // Overlap check: not (one ends before other starts)
          !(s.actualEndVal <= startTime || s.safeStartVal >= endTime));

      if (conflicts.isEmpty) {
        availableRooms.add(room.id);
      }
    }

    return availableRooms;
  }

  /// Detect room conflicts across departments
  List<RoomConflict> detectRoomConflicts(List<ClassSession> allSessions) {
    final conflicts = <RoomConflict>[];
    final sessionsByRoom = <String, List<ClassSession>>{};

    // Group sessions by room
    for (final session in allSessions) {
      final cleanRoom = FormatGuard.sanitizeRoom(session.room);
      sessionsByRoom.putIfAbsent(cleanRoom, () => []).add(session);
    }

    // Check for overlaps in each room
    for (final sessions in sessionsByRoom.values) {
      for (int i = 0; i < sessions.length; i++) {
        for (int j = i + 1; j < sessions.length; j++) {
          final s1 = sessions[i];
          final s2 = sessions[j];

          // Check if same day and time overlap
          if (s1.dayIndex == s2.dayIndex &&
              !(s1.actualEndVal <= s2.safeStartVal || s2.actualEndVal <= s1.safeStartVal)) {
            conflicts.add(RoomConflict(
              room: s1.room,
              session1: s1,
              session2: s2,
              overlapMinutes:
                  ((_getMinTime(s1.actualEndVal, s2.actualEndVal) - _getMaxTime(s1.safeStartVal, s2.safeStartVal)) * 60).toInt(),
              severity: _calculateConflictSeverity(s1, s2),
            ));
          }
        }
      }
    }

    return conflicts;
  }

  /// Get occupancy heatmap for a room across the week
  Map<String, double> getRoomHeatmap(String roomId, List<ClassSession> allSessions) {
    final heatmap = <String, double>{};
    final cleanTarget = FormatGuard.sanitizeRoom(roomId);
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    const hours = [
      '08:00', '09:00', '10:00', '11:00', '12:00', '13:00',
      '14:00', '15:00', '16:00', '17:00', '18:00'
    ];

    // Initialize heatmap
    for (final day in days) {
      for (final hour in hours) {
        heatmap['$day-$hour'] = 0.0;
      }
    }

    // Calculate occupancy density
    for (final session in allSessions) {
      if (FormatGuard.sanitizeRoom(session.room) == cleanTarget) {
        final day = days[session.dayIndex - 1];
        final startHour = session.safeStartVal.toInt();
        final baseName = '$day-$startHour:00';
        heatmap[baseName] = (heatmap[baseName] ?? 0.0) + 1.0;
      }
    }

    return heatmap;
  }

  /// Smart recommendation engine
  RoomRecommendation getSmartRecommendation(
    List<ClassSession> allSessions,
    List<ClassSession> userSchedule,
    int proximityPreference, // 0-100, higher = closer to user's classes
  ) {
    final now = DateTime.now();
    final currentHour = now.hour + (now.minute / 60.0);
    final available = getAvailableRoomsNow(allSessions);

    if (available.isEmpty) {
      return RoomRecommendation(
        recommended: null,
        reason: 'No study spaces available right now',
        alternatives: [],
      );
    }

    // Find user's next class room
    final nextUserClass = userSchedule
        .where((s) =>
            s.dayIndex == now.weekday && s.safeStartVal > currentHour)
        .fold<ClassSession?>(null, (prev, current) =>
            prev == null || current.safeStartVal < prev.safeStartVal
                ? current
                : prev);

    // Score rooms based on:
    // 1. Time until next occupied (longer is better)
    // 2. Proximity to next user class
    final scoredRooms = available.map((room) {
      double score = room.studyScore;

      // Bonus for being near user's next class
      if (nextUserClass != null) {
        final sameBuilding = room.building == nextUserClass.room.split('-').first;
        if (sameBuilding) {
          score += (proximityPreference / 100.0) * 30; // Up to +30 for same building
        }
      }

      return MapEntry(room, score);
    }).toList();

    scoredRooms.sort((a, b) => b.value.compareTo(a.value));

    final best = scoredRooms.first.key;
    final alternatives = scoredRooms.skip(1).take(3).map((e) => e.key).toList();

    String reason = 'Quiet space in ${best.building}';
    if (best.minulesFreeUntilNextSession != null) {
      reason += ' • Free for ${best.minulesFreeUntilNextSession} mins';
    } else {
      reason += ' • Free rest of day';
    }

    return RoomRecommendation(
      recommended: best,
      reason: reason,
      alternatives: alternatives,
    );
  }

  // Helper methods
  ClassSession? _getNextSession(
    String roomId,
    List<ClassSession> allSessions,
    int dayIndex,
    double currentHour,
  ) {
    final cleanTarget = FormatGuard.sanitizeRoom(roomId);
    final upcomingSessions = allSessions.where((s) =>
        FormatGuard.sanitizeRoom(s.room) == cleanTarget &&
        s.dayIndex == dayIndex &&
        s.safeStartVal > currentHour).toList();

    if (upcomingSessions.isEmpty) return null;

    upcomingSessions.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    return upcomingSessions.first;
  }

  double _calculateStudyScore(Room room, ClassSession? nextSession, List<RoomAvailability> allAvailability) {
    double score = 100.0;
    
    // 1. Duration Bonus: Longer free time is better for study
    if (nextSession != null) {
      final now = DateTime.now();
      final currentHour = now.hour + (now.minute / 60.0);
      final freeMinutes = (nextSession.safeStartVal - currentHour) * 60;
      
      if (freeMinutes < 30) {
        score -= 40; // Too short
      } else if (freeMinutes < 60) {
        score -= 20;
      } else {
        score += 10; // Good duration
      }
    } else {
      score += 20; // Free for the rest of the day
    }
    
    // 2. Noise Level Estimation: How many occupied rooms are in the same building?
    final buildingOccupancy = allAvailability.where((a) => a.building == room.building && !a.isAvailable).length;
    final buildingTotal = allAvailability.where((a) => a.building == room.building).length;
    
    if (buildingTotal > 0) {
      double density = buildingOccupancy / buildingTotal;
      score -= (density * 30); // Higher density = lower study score (potential noise)
    }
    
    // 3. Amenity Bonus
    if (room.amenities.contains('AC')) score += 15;
    if (room.amenities.contains('PC')) score += 10;
    if (room.amenities.contains('Internet')) score += 5;
    
    return score.clamp(0, 100);
  }

  String _calculateConflictSeverity(ClassSession s1, ClassSession s2) {
    final overlap = _getMinTime(s1.actualEndVal, s2.actualEndVal) -
        _getMaxTime(s1.safeStartVal, s2.safeStartVal);
    if (overlap >= 0.5) return 'HIGH';
    if (overlap >= 0.25) return 'MEDIUM';
    return 'LOW';
  }

  double _getMinTime(double a, double b) => a < b ? a : b;
  double _getMaxTime(double a, double b) => a > b ? a : b;
}
