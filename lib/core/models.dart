import 'format_guard.dart';

class BatchKey {
  final String batch;
  final String program;
  final int semester;
  final String section;
  final String intake;

  const BatchKey({
    required this.batch,
    required this.program,
    required this.semester,
    required this.section,
    required this.intake,
  });

  int get dynamicSemester => calculateSemester(intake);

  static int calculateSemester(String intake, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (intake.length < 4) return 1;
    final term = intake.substring(0, 2).toUpperCase();
    final yearSuffix = intake.substring(2, 4);
    final yearShort = int.tryParse(yearSuffix);
    if (yearShort == null) return 1;
    final intakeYear = 2000 + yearShort;

    final currentYear = current.year;
    final currentMonth = current.month;

    int intakeIndex = intakeYear * 2;
    if (term == 'FA') {
      intakeIndex += 1;
    }

    int currentIndex = currentYear * 2;
    if (currentMonth >= 8) {
      currentIndex += 1;
    }

    final sem = currentIndex - intakeIndex + 1;
    return sem.clamp(1, 8);
  }

  factory BatchKey.parse(String batch) {
    final parts = batch.split('-');
    if (parts.length < 3) {
      return BatchKey(
        batch: batch,
        program: parts.isNotEmpty ? parts.first : 'UNKNOWN',
        semester: 0,
        section: parts.length > 1 ? parts[1] : 'A',
        intake: parts.isNotEmpty ? parts.first : 'NA',
      );
    }

    final intake = parts[0];
    final program = parts[1];
    final semesterText = parts[2];
    final semester = int.tryParse(semesterText) ??
        int.tryParse(RegExp(r'\d+').firstMatch(semesterText)?.group(0) ?? '') ??
        0;
    final section = parts.length >= 4 ? parts[3] : parts[2];
    return BatchKey(
      batch: batch,
      program: program,
      semester: semester,
      section: section,
      intake: intake,
    );
  }
}

class ClassSession {
  final String id;
  final BatchKey batchKey;
  final int dayIndex;
  final String startTime;
  final String endTime;
  final String subject;
  final String teacher;
  final String room;

  const ClassSession({
    required this.id,
    required this.batchKey,
    required this.dayIndex,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.teacher,
    required this.room,
  });

  double get safeStartVal => FormatGuard.toDecimalTime(startTime);
  double get safeEndVal => FormatGuard.toDecimalTime(endTime);

  bool get isOneHourLecture {
    return subject.toLowerCase().contains('(1 hr)') ||
           subject.toLowerCase().contains('(1hr)') ||
           subject.toLowerCase().contains('1 hr)');
  }

  double get actualEndVal {
    if (isOneHourLecture) {
      return safeStartVal + 1.0;
    }
    return safeEndVal;
  }

  bool isLive(DateTime now) {
    final currentT = now.hour + (now.minute / 60.0);
    return dayIndex == now.weekday && currentT >= safeStartVal && currentT < actualEndVal;
  }

  // Check if this session is consecutive with another
  bool isConsecutiveWith(ClassSession other) {
    return dayIndex == other.dayIndex &&
           subject == other.subject &&
           teacher == other.teacher &&
           room == other.room &&
           (actualEndVal - other.safeStartVal).abs() < 0.01; // This session starts when other ends
  }

  // Check if two sessions are the same lecture (for merging)
  bool isSameLectureAs(ClassSession other) {
    return dayIndex == other.dayIndex &&
           subject == other.subject &&
           teacher == other.teacher &&
           room == other.room;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'batch': batchKey.batch,
        'day': FormatGuard.normalizeDay(dayIndex),
        'start': startTime,
        'end': endTime,
        'subject': subject,
        'teacher': teacher,
        'room': room,
      };

  static ClassSession fromJson(Map<String, dynamic> json) {
    final batchStr = (json['batch'] ?? json['class_name'] ?? json['section'] ?? 'UNKNOWN').toString();
    final batchKey = BatchKey.parse(batchStr);
    
    // Parse start and end times, supporting 'period' or 'time' splits
    String start = '00:00';
    String end = '00:00';
    
    if (json['start'] != null && json['end'] != null) {
      start = json['start'].toString();
      end = json['end'].toString();
    } else {
      final timeStr = (json['time'] ?? json['period'] ?? '').toString();
      if (timeStr.isNotEmpty) {
        final parts = timeStr.split('-');
        if (parts.length >= 2) {
          start = parts[0].trim();
          end = parts[1].trim();
        } else if (parts.isNotEmpty) {
          start = parts[0].trim();
        }
      }
    }
    
    final dayStr = (json['day'] ?? json['weekday'] ?? 'Monday').toString();
    final subjectStr = (json['subject'] ?? json['course'] ?? json['title'] ?? 'Unknown').toString();
    final teacherStr = (json['teacher'] ?? json['instructor'] ?? json['staff'] ?? 'Unknown').toString();
    final roomStr = (json['room'] ?? json['location'] ?? 'TBD').toString();

    return ClassSession(
      id: json['id'] as String? ?? '${batchKey.batch}-$dayStr-$start',
      batchKey: batchKey,
      dayIndex: FormatGuard.dayIndex(dayStr),
      startTime: start,
      endTime: end,
      subject: subjectStr,
      teacher: FormatGuard.formatTeacherName(teacherStr),
      room: FormatGuard.sanitizeRoom(roomStr),
    );
  }
}

class UniversityMemory {
  final List<ClassSession> sessions;

  UniversityMemory(this.sessions);

  List<String> get allBatches {
    final batches = sessions.map((s) => s.batchKey.batch).toSet().toList();
    batches.sort();
    return batches;
  }

  Map<String, List<ClassSession>> byBatch() {
    final map = <String, List<ClassSession>>{};
    for (final session in sessions) {
      map.putIfAbsent(session.batchKey.batch, () => []).add(session);
    }
    return map;
  }

  Map<String, List<ClassSession>> byProgram(String program) {
    final map = <String, List<ClassSession>>{};
    for (final session in sessions.where((s) => s.batchKey.program == program)) {
      map.putIfAbsent(session.batchKey.batch, () => []).add(session);
    }
    return map;
  }

  List<String> programs() {
    final items = sessions.map((s) => s.batchKey.program).toSet().toList();
    items.sort();
    return items;
  }

  List<int> semesters(String program) {
    final items = sessions
        .where((s) => s.batchKey.program == program)
        .map((s) => s.batchKey.semester)
        .toSet()
        .toList();
    items.sort();
    return items;
  }

  List<String> sections(String program, int semester) {
    final items = sessions
        .where((s) => s.batchKey.program == program && s.batchKey.semester == semester)
        .map((s) => s.batchKey.section)
        .toSet()
        .toList();
    items.sort();
    return items;
  }
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'building': building,
        'capacity': capacity,
        'amenities': amenities,
        'registeredAt': registeredAt.toIso8601String(),
      };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        building: json['building'] as String,
        capacity: json['capacity'] as int,
        amenities: List<String>.from(json['amenities'] as List),
        registeredAt: DateTime.parse(json['registeredAt'] as String),
      );
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

// Lightweight compatibility helper
class LectureDuration {
  static double getActualDuration(ClassSession session) {
    return (session.safeEndVal - session.safeStartVal).abs();
  }
  static double getActualEndTime(ClassSession session) {
    return session.safeEndVal;
  }
}
