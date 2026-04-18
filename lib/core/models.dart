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

  bool isLive(DateTime now) {
    final currentT = now.hour + (now.minute / 60.0);
    return dayIndex == now.weekday && currentT >= safeStartVal && currentT < safeEndVal;
  }

  // Check if this session is consecutive with another
  bool isConsecutiveWith(ClassSession other) {
    return dayIndex == other.dayIndex &&
           subject == other.subject &&
           teacher == other.teacher &&
           room == other.room &&
           (safeEndVal - other.safeStartVal).abs() < 0.01; // This session starts when other ends
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
    final batchKey = BatchKey.parse(json['batch'] as String? ?? 'UNKNOWN');
    return ClassSession(
      id: json['id'] as String? ?? '${batchKey.batch}-${json['day']}-${json['start']}',
      batchKey: batchKey,
      dayIndex: FormatGuard.dayIndex(json['day'] as String? ?? 'Monday'),
      startTime: json['start'] as String? ?? '00:00',
      endTime: json['end'] as String? ?? '00:00',
      subject: json['subject'] as String? ?? 'Unknown',
      teacher: json['teacher'] as String? ?? 'Unknown',
      room: FormatGuard.sanitizeRoom(json['room'] as String? ?? 'TBD'),
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
