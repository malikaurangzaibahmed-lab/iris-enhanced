import 'format_guard.dart';
import '../services/remote_config_service.dart';

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
    var raw = batch.trim();
    // Extract purely valid canonical batch pattern: e.g. "FA25-BCS-2-D" or "FA22-BCS-6A" or "FA25-BCE-B1"
    final fullBatchMatch = RegExp(r'^(?:FA|SP)\d{2}-[A-Za-z]+(?:-\d+)?-[A-Za-z0-9]{1,3}', caseSensitive: false).firstMatch(raw);
    if (fullBatchMatch != null) {
      raw = fullBatchMatch.group(0)!;
    } else {
      final shortBatchMatch = RegExp(r'^[A-Za-z]{2,4}-(?:\d+-)?[A-Za-z0-9]{1,3}', caseSensitive: false).firstMatch(raw);
      if (shortBatchMatch != null) {
        raw = shortBatchMatch.group(0)!;
      }
    }

    final parts = raw.split('-');
    if (parts.length < 3) {
      return BatchKey(
        batch: raw,
        program: parts.isNotEmpty ? parts.first.toUpperCase() : 'UNKNOWN',
        semester: 0,
        section: parts.length > 1 ? parts[1].toUpperCase() : 'A',
        intake: parts.isNotEmpty ? parts.first.toUpperCase() : 'NA',
      );
    }

    final intake = parts[0].toUpperCase();
    final program = parts[1].toUpperCase();
    final semesterText = parts[2];
    final semester = int.tryParse(semesterText) ??
        int.tryParse(RegExp(r'\d+').firstMatch(semesterText)?.group(0) ?? '') ??
        0;
    
    // Clean section token e.g. if parts[3] is "DSoftwareEngineering" -> "D"
    var rawSection = parts.length >= 4 ? parts[3] : parts[2];
    final secMatch = RegExp(r'^[A-Za-z0-9]{1,3}').firstMatch(rawSection);
    final section = secMatch != null ? secMatch.group(0)!.toUpperCase() : rawSection.toUpperCase();

    final canonicalBatch = parts.length >= 4 
        ? '$intake-$program-$semesterText-$section'
        : '$intake-$program-$section';

    return BatchKey(
      batch: canonicalBatch,
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
    var subjectStr = (json['subject'] ?? json['course'] ?? json['title'] ?? 'Unknown').toString();
    var teacherStr = (json['teacher'] ?? json['instructor'] ?? json['staff'] ?? 'Unknown').toString();
    final roomStr = (json['room'] ?? json['location'] ?? 'TBD').toString();

    // If teacher is unknown/staff but subject has parenthesized instructor e.g. "CS314 AI (Dr. Shahzad Ali)"
    if ((teacherStr.toLowerCase() == 'unknown' || teacherStr.toLowerCase() == 'staff') && subjectStr.contains('(')) {
      final parenMatch = RegExp(r'\(((?:Dr\.?|Prof\.?|Engr\.?|Mr\.?|Ms\.?|Mrs\.?|Sir|Mam|[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)[^)]*)\)', caseSensitive: false).firstMatch(subjectStr);
      if (parenMatch != null) {
        teacherStr = parenMatch.group(1)!.trim();
      }
    }

    final cleanSub = FormatGuard.sanitizeSubject(subjectStr);

    return ClassSession(
      id: json['id'] as String? ?? '${batchKey.batch}-$dayStr-$start',
      batchKey: batchKey,
      dayIndex: FormatGuard.dayIndex(dayStr),
      startTime: start,
      endTime: end,
      subject: cleanSub,
      teacher: FormatGuard.formatTeacherName(teacherStr),
      room: FormatGuard.sanitizeRoom(roomStr),
    );
  }

  static final RegExp _examTagRegex = RegExp(r'\[EXAM\]', caseSensitive: false);
  static final RegExp _parenthesesRegex = RegExp(r'\(.*?\)', caseSensitive: false);

  static String _resolveExamInvigilator(
    Map<String, dynamic> json,
    BatchKey batchKey,
    String rawSubject,
    UniversityMemory? memory,
  ) {
    var rawTeacher = (json['invigilator'] ??
            json['invigilator_name'] ??
            json['invigilators'] ??
            json['teacher'] ??
            json['instructor'] ??
            json['faculty'] ??
            json['duty'] ??
            json['supervised_by'] ??
            json['supervisor'] ??
            '')
        .toString()
        .trim();

    if (rawTeacher.isNotEmpty &&
        rawTeacher.toLowerCase() != 'invigilator assigned' &&
        rawTeacher.toLowerCase() != 'tbd' &&
        rawTeacher.toLowerCase() != 'unknown') {
      return FormatGuard.formatTeacherName(rawTeacher);
    }

    if (memory != null) {
      final cleanSubject = rawSubject
          .replaceAll(_examTagRegex, '')
          .replaceAll(_parenthesesRegex, '')
          .trim()
          .toLowerCase();

      if (cleanSubject.isNotEmpty) {
        final targetBatch = batchKey.batch.toLowerCase();
        final targetProg = batchKey.program.toLowerCase();
        final targetSec = batchKey.section.toLowerCase();

        for (final session in memory.sessions) {
          final sBatch = session.batchKey.batch.toLowerCase();
          final bMatch = sBatch == targetBatch ||
              (session.batchKey.program.toLowerCase() == targetProg &&
                  session.batchKey.semester == batchKey.semester &&
                  session.batchKey.section.toLowerCase() == targetSec);
          if (bMatch) {
            final sSub = session.subject
                .replaceAll(_parenthesesRegex, '')
                .trim()
                .toLowerCase();
            if (sSub.contains(cleanSubject) || cleanSubject.contains(sSub)) {
              if (session.teacher.isNotEmpty && session.teacher != 'Unknown') {
                return FormatGuard.formatTeacherName(session.teacher);
              }
            }
          }
        }

        for (final session in memory.sessions) {
          final sSub = session.subject
              .replaceAll(_parenthesesRegex, '')
              .trim()
              .toLowerCase();
          if (sSub.contains(cleanSubject) || cleanSubject.contains(sSub)) {
            if (session.teacher.isNotEmpty && session.teacher != 'Unknown') {
              return FormatGuard.formatTeacherName(session.teacher);
            }
          }
        }
      }
    }

    return rawTeacher.isNotEmpty ? FormatGuard.formatTeacherName(rawTeacher) : 'Invigilator Assigned';
  }

  static ClassSession fromExamJson(
    Map<String, dynamic> json, {
    int index = 0,
    UniversityMemory? memory,
  }) {
    final batchStr = (json['batch'] ?? json['session'] ?? json['class_name'] ?? 'ALL').toString();
    final batchKey = BatchKey.parse(batchStr);

    String start = '09:00 AM';
    String end = '12:00 PM';
    final timeStr = (json['time'] ?? '').toString();
    if (timeStr.isNotEmpty) {
      final parts = timeStr.split('-');
      if (parts.length >= 2) {
        start = parts[0].trim();
        end = parts[1].trim();
      } else if (parts.isNotEmpty) {
        start = parts[0].trim();
      }
    }

    final dateStr = (json['date'] ?? '').toString();
    int dayIdx = DateTime.now().weekday;
    final lowerDate = dateStr.toLowerCase();
    if (lowerDate.contains('mon')) {
      dayIdx = 1;
    } else if (lowerDate.contains('tue')) {
      dayIdx = 2;
    } else if (lowerDate.contains('wed')) {
      dayIdx = 3;
    } else if (lowerDate.contains('thu')) {
      dayIdx = 4;
    } else if (lowerDate.contains('fri')) {
      dayIdx = 5;
    } else if (lowerDate.contains('sat')) {
      dayIdx = 6;
    } else if (lowerDate.contains('sun')) {
      dayIdx = 7;
    } else {
      final match = RegExp(r'(\d{2})-(\d{2})-(\d{4})').firstMatch(dateStr);
      if (match != null) {
        final d = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final y = int.parse(match.group(3)!);
        dayIdx = DateTime(y, m, d).weekday;
      }
    }

    final rawSubject = (json['subject'] ?? json['course'] ?? 'EXAM').toString();
    final subjectStr = rawSubject.startsWith('[EXAM]') ? rawSubject : '[EXAM] $rawSubject';
    final teacherStr = _resolveExamInvigilator(json, batchKey, rawSubject, memory);
    final roomStr = (json['room'] ?? json['hall'] ?? 'Exam Hall').toString();

    return ClassSession(
      id: 'exam_${batchKey.batch}_${index}_$start',
      batchKey: batchKey,
      dayIndex: dayIdx,
      startTime: start,
      endTime: end,
      subject: subjectStr,
      teacher: teacherStr,
      room: FormatGuard.sanitizeRoom(roomStr),
    );
  }
}

class UniversityMemory {
  final List<ClassSession> sessions;

  UniversityMemory(this.sessions);

  List<ClassSession>? _cachedActiveSessions;
  String? _cachedPeriodKey;
  int? _cachedExamsHash;

  List<ClassSession> _toRamadanSessions(List<ClassSession> regularSessions) {
    return regularSessions.map((s) {
      String newStart = s.startTime;
      String newEnd = s.endTime;

      if (s.startTime.contains('08:30') || s.startTime.contains('8:30')) {
        newStart = '08:30 AM';
        newEnd = '09:30 AM';
      } else if (s.startTime.contains('10:00')) {
        newStart = '09:30 AM';
        newEnd = '10:30 AM';
      } else if (s.startTime.contains('11:30')) {
        newStart = '10:30 AM';
        newEnd = '11:30 AM';
      } else if (s.startTime.contains('01:30') || s.startTime.contains('1:30')) {
        newStart = '11:30 AM';
        newEnd = '12:30 PM';
      } else if (s.startTime.contains('03:00') || s.startTime.contains('3:00')) {
        newStart = '12:30 PM';
        newEnd = '01:30 PM';
      }

      return ClassSession(
        id: '${s.id}_ramadan',
        batchKey: s.batchKey,
        dayIndex: s.dayIndex,
        startTime: newStart,
        endTime: newEnd,
        subject: s.subject,
        teacher: s.teacher,
        room: s.room,
      );
    }).toList();
  }

  List<ClassSession> activeSessions({
    String? overridePeriod,
    List<dynamic>? customMidterms,
    List<dynamic>? customFinals,
  }) {
    final period = overridePeriod ?? RemoteConfigService.activeAcademicPeriod.value;
    final rawExams = period == 'midterms'
        ? (customMidterms ?? RemoteConfigService.midtermExams.value)
        : (period == 'finals' ? (customFinals ?? RemoteConfigService.finalExams.value) : null);

    final examsHash = rawExams != null ? Object.hash(rawExams.length, rawExams.hashCode) : 0;
    final periodKey = '${period}_$overridePeriod';

    if (_cachedActiveSessions != null &&
        _cachedPeriodKey == periodKey &&
        _cachedExamsHash == examsHash) {
      return _cachedActiveSessions!;
    }

    List<ClassSession> result;
    if ((period == 'midterms' || period == 'finals') && rawExams != null && rawExams.isNotEmpty) {
      final parsed = <ClassSession>[];
      for (int i = 0; i < rawExams.length; i++) {
        final item = rawExams[i];
        if (item is Map<String, dynamic>) {
          parsed.add(ClassSession.fromExamJson(item, index: i, memory: this));
        } else if (item is Map) {
          parsed.add(ClassSession.fromExamJson(Map<String, dynamic>.from(item), index: i, memory: this));
        }
      }
      result = parsed.isNotEmpty ? parsed : sessions;
    } else if (period == 'ramadan') {
      result = _toRamadanSessions(sessions);
    } else {
      result = sessions;
    }

    _cachedActiveSessions = result;
    _cachedPeriodKey = periodKey;
    _cachedExamsHash = examsHash;
    return result;
  }

  List<String> get allBatches {
    final batches = activeSessions().map((s) => s.batchKey.batch).toSet().toList();
    batches.sort();
    return batches;
  }

  Map<String, List<ClassSession>> byBatch() {
    final map = <String, List<ClassSession>>{};
    for (final session in activeSessions()) {
      map.putIfAbsent(session.batchKey.batch, () => []).add(session);
    }
    return map;
  }

  Map<String, List<ClassSession>> byProgram(String program) {
    final map = <String, List<ClassSession>>{};
    for (final session in activeSessions().where((s) => s.batchKey.program == program)) {
      map.putIfAbsent(session.batchKey.batch, () => []).add(session);
    }
    return map;
  }

  List<String> programs() {
    final items = activeSessions().map((s) => s.batchKey.program).toSet().toList();
    items.sort();
    return items;
  }

  List<int> semesters(String program) {
    final items = activeSessions()
        .where((s) => s.batchKey.program == program)
        .map((s) => s.batchKey.semester)
        .toSet()
        .toList();
    items.sort();
    return items;
  }

  List<String> sections(String program, int semester) {
    final items = activeSessions()
        .where((s) => s.batchKey.program == program && s.batchKey.semester == semester)
        .map((s) {
          final sec = s.batchKey.section;
          final m = RegExp(r'^[A-Za-z0-9]{1,3}').firstMatch(sec);
          return m != null ? m.group(0)!.toUpperCase() : sec;
        })
        .where((s) => s.isNotEmpty)
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
