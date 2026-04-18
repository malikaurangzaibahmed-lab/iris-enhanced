import 'package:iris/core/models.dart';

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
    _rooms[roomId] = Room(
      id: roomId,
      building: building,
      capacity: capacity,
      amenities: amenities,
      registeredAt: DateTime.now(),
    );
  }

  /// Get all available rooms right now
  List<RoomAvailability> getAvailableRoomsNow(
    List<ClassSession> allSessions,
  ) {
    final now = DateTime.now();
    final currentHour = now.hour + (now.minute / 60.0);
    final dayIndex = now.weekday;

    final availability = <RoomAvailability>[];

    for (final room in _rooms.values) {
      // Find all sessions in this room at current time
      final occupyingSessions = allSessions.where((s) =>
          s.room == room.id &&
          s.dayIndex == dayIndex &&
          s.safeStartVal <= currentHour &&
          currentHour < s.safeEndVal);

      if (occupyingSessions.isEmpty) {
        // Room is free now
        final nextSession = _getNextSession(room.id, allSessions, dayIndex, currentHour);
        availability.add(RoomAvailability(
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
          studyScore: _calculateStudyScore(room, nextSession),
        ));
      } else {
        // Room is occupied
        final session = occupyingSessions.first;
        availability.add(RoomAvailability(
          roomId: room.id,
          building: room.building,
          capacity: room.capacity,
          amenities: room.amenities,
          isAvailable: false,
          occupiedUntil: session.safeEndVal,
          occupiedBy: session.subject,
          occupiedByTeacher: session.teacher,
          minulesFreeUntilNextSession: ((session.safeEndVal - currentHour) * 60).toInt(),
          studyScore: 0,
        ));
      }
    }

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
    final availability = <RoomAvailability>[];

    for (final room in _rooms.values) {
      final occupyingSessions = allSessions.where((s) =>
          s.room == room.id &&
          s.dayIndex == dayIndex &&
          s.safeStartVal <= targetHour &&
          targetHour < s.safeEndVal);

      final isAvailable = occupyingSessions.isEmpty;
      final nextSession = isAvailable
          ? _getNextSession(room.id, allSessions, dayIndex, targetHour)
          : null;

      availability.add(RoomAvailability(
        roomId: room.id,
        building: room.building,
        capacity: room.capacity,
        amenities: room.amenities,
        isAvailable: isAvailable,
        occupiedUntil: isAvailable ? null : occupyingSessions.first.safeEndVal,
        nextSessionAt: nextSession?.safeStartVal,
        nextSessionSubject: nextSession?.subject,
        minulesFreeUntilNextSession: nextSession != null
            ? ((nextSession.safeStartVal - targetHour) * 60).toInt()
            : null,
        studyScore: isAvailable ? _calculateStudyScore(room, nextSession) : 0,
      ));
    }

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
      // Check if any session overlaps with this time range
      final conflicts = allSessions.where((s) =>
          s.room == room.id &&
          s.dayIndex == dayIndex &&
          // Overlap check: not (one ends before other starts)
          !(s.safeEndVal <= startTime || s.safeStartVal >= endTime));

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
      sessionsByRoom.putIfAbsent(session.room, () => []).add(session);
    }

    // Check for overlaps in each room
    for (final sessions in sessionsByRoom.values) {
      for (int i = 0; i < sessions.length; i++) {
        for (int j = i + 1; j < sessions.length; j++) {
          final s1 = sessions[i];
          final s2 = sessions[j];

          // Check if same day and time overlap
          if (s1.dayIndex == s2.dayIndex &&
              !(s1.safeEndVal <= s2.safeStartVal || s2.safeEndVal <= s1.safeStartVal)) {
            conflicts.add(RoomConflict(
              room: s1.room,
              session1: s1,
              session2: s2,
              overlapMinutes:
                  ((_getMinTime(s1.safeEndVal, s2.safeEndVal) - _getMaxTime(s1.safeStartVal, s2.safeStartVal)) * 60).toInt(),
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
      if (session.room == roomId) {
        final day = days[session.dayIndex - 1];
        final startHour = session.safeStartVal.toInt();
        final baseName = '$day-${startHour}:00';
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
    // 3. Amenities
    // 4. Quiet score (based on occupancy patterns)

    final scored = available.map((room) {
      double score = room.studyScore;

      // Bonus for rooms far from occupied classes
      score += (room.minulesFreeUntilNextSession ?? 60).toDouble() * 0.5;

      // Proximity bonus if near next user class
      if (nextUserClass != null) {
        score += proximityPreference.toDouble() * 0.01;
      }

      // Amenity bonus
      score += room.amenities.length * 5.0;

      return (room, score);
    }).toList();

    scored.sort((a, b) => b.$2.compareTo(a.$2));

    final best = scored.first.$1;
    final alternatives = scored.skip(1).take(2).map((e) => e.$1).toList();

    return RoomRecommendation(
      recommended: best,
      reason: best.minulesFreeUntilNextSession != null
          ? 'Free for ${best.minulesFreeUntilNextSession} minutes'
          : 'Currently available',
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
    return allSessions
        .where((s) =>
            s.room == roomId && s.dayIndex == dayIndex && s.safeStartVal > currentHour)
        .fold<ClassSession?>(null, (prev, current) =>
            prev == null || current.safeStartVal < prev.safeStartVal
                ? current
                : prev);
  }

  double _calculateStudyScore(Room room, ClassSession? nextSession) {
    double score = 100.0;
    score -= room.amenities.isEmpty ? 10 : 0;
    if (nextSession != null) {
      score -= ((nextSession.safeStartVal * 10).toInt()).toDouble();
    }
    return score.clamp(0, 100);
  }

  String _calculateConflictSeverity(ClassSession s1, ClassSession s2) {
    final overlap = _getMinTime(s1.safeEndVal, s2.safeEndVal) -
        _getMaxTime(s1.safeStartVal, s2.safeStartVal);
    if (overlap >= 0.5) return 'HIGH';
    if (overlap >= 0.25) return 'MEDIUM';
    return 'LOW';
  }

  double _getMinTime(double a, double b) => a < b ? a : b;
  double _getMaxTime(double a, double b) => a > b ? a : b;
}

class Room {
  final String id;
  final String building;
  final int capacity;
  final List<String> amenities;
  final DateTime registeredAt;

  Room({
    required this.id,
    required this.building,
    required this.capacity,
    required this.amenities,
    required this.registeredAt,
  });
}

class Department {
  final String id;
  final String name;
  final DateTime registeredAt;

  Department({
    required this.id,
    required this.name,
    required this.registeredAt,
  });
}

class RoomAvailability {
  final String roomId;
  final String building;
  final int capacity;
  final List<String> amenities;
  final bool isAvailable;
  final double? occupiedUntil;
  final String? occupiedBy;
  final String? occupiedByTeacher;
  final double? nextSessionAt;
  final String? nextSessionSubject;
  final int? minulesFreeUntilNextSession;
  final double studyScore;

  RoomAvailability({
    required this.roomId,
    required this.building,
    required this.capacity,
    required this.amenities,
    required this.isAvailable,
    this.occupiedUntil,
    this.occupiedBy,
    this.occupiedByTeacher,
    this.nextSessionAt,
    this.nextSessionSubject,
    this.minulesFreeUntilNextSession,
    required this.studyScore,
  });
}

class RoomConflict {
  final String room;
  final ClassSession session1;
  final ClassSession session2;
  final int overlapMinutes;
  final String severity; // HIGH, MEDIUM, LOW

  RoomConflict({
    required this.room,
    required this.session1,
    required this.session2,
    required this.overlapMinutes,
    required this.severity,
  });
}

class RoomRecommendation {
  final RoomAvailability? recommended;
  final String reason;
  final List<RoomAvailability> alternatives;

  RoomRecommendation({
    required this.recommended,
    required this.reason,
    required this.alternatives,
  });
}
