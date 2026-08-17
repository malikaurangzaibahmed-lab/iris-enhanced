import 'format_guard.dart';
import '../services/remote_config_service.dart';

class BatchKey {
  final String batch;
  final String program;
  final int semester;
  final String section;
  final String intake;
  final String department;

  const BatchKey({
    required this.batch,
    required this.program,
    required this.semester,
    required this.section,
    required this.intake,
    required this.department,
  });

  /// e.g. "FA" -> "Fall", "SP" -> "Spring"
  String get intakeSeason {
    if (intake.startsWith('FA')) return 'Fall';
    if (intake.startsWith('SP')) return 'Spring';
    return intake;
  }

  /// e.g. "FA25" -> 2025
  int get intakeYear {
    if (intake.length >= 4) {
      final y = int.tryParse(intake.substring(2, 4));
      if (y != null) return 2000 + y;
    }
    return 2025;
  }

  /// Full descriptive title e.g. "Fall 2025 - BS Computer Science (Semester 2, Section C)"
  String get fullDescription {
    final semStr = semester > 0 ? 'Semester $semester' : 'Semester $dynamicSemester';
    final secStr = section.isNotEmpty ? ', Section $section' : '';
    return '$intakeSeason $intakeYear - $programFullName ($semStr$secStr)';
  }

  /// Readable Program Name
  String get programFullName {
    switch (program.toUpperCase()) {
      case 'BCS':
        return 'BS Computer Science';
      case 'BSE':
        return 'BS Software Engineering';
      case 'BEE':
        return 'BS Electrical Engineering';
      case 'BME':
        return 'BS Mechanical Engineering';
      case 'CVE':
      case 'BCE':
      case 'CE':
        return 'BS Civil Engineering';
      case 'BBA':
        return 'Bachelor of Business Administration';
      case 'BBC':
      case 'BCH':
        return 'BS Biochemistry';
      case 'BTY':
        return 'BS Biotechnology';
      case 'FSN':
        return 'BS Food Science & Nutrition';
      case 'HND':
        return 'BS Human Nutrition & Dietetics';
      case 'RBS':
        return 'BS Remote Sensing & GIS';
      case 'BEN':
        return 'BS English';
      case 'MCS':
      case 'MSCS':
        return 'MS Computer Science';
      case 'MSSE':
        return 'MS Software Engineering';
      case 'MSEE':
        return 'MS Electrical Engineering';
      case 'MSME':
        return 'MS Mechanical Engineering';
      case 'MSMS':
      case 'MBA':
        return 'Master of Business Administration';
      default:
        return 'BS $program';
    }
  }

  static String resolveDepartment(String prog) {
    switch (prog.toUpperCase()) {
      case 'SE':
      case 'BSE':
      case 'MSSE':
        return 'Software Engineering';
      case 'CS':
      case 'BCS':
      case 'MCS':
      case 'MSCS':
        return 'Computer Science';
      case 'EE':
      case 'BEE':
      case 'MSEE':
        return 'Electrical Engineering';
      case 'ME':
      case 'BME':
      case 'MSME':
        return 'Mechanical Engineering';
      case 'CVE':
      case 'BCE':
      case 'CE':
      case 'MSCE':
        return 'Civil Engineering';
      case 'BBA':
      case 'BBS':
      case 'AF':
      case 'MS':
      case 'MSMS':
      case 'MBA':
        return 'Management Sciences';
      case 'BTY':
        return 'Biotechnology';
      case 'BBC':
      case 'BCH':
        return 'Biochemistry';
      case 'FSN':
        return 'Food Science & Nutrition';
      case 'HND':
        return 'Human Nutrition & Dietetics';
      case 'RBS':
        return 'Remote Sensing & GIS';
      case 'BI':
        return 'Biosciences';
      case 'BEN':
      case 'ENG':
      case 'HUM':
        return 'Humanities';
      case 'MT':
      case 'MTH':
        return 'Mathematics';
      case 'VS':
        return 'Visiting Faculty';
      default:
        return 'General';
    }
  }

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

    // Term Index Calculation:
    // Spring (Mar-Aug) = year * 2
    // Fall (Sep-Feb) = year * 2 + 1
    final intakeIndex = (intakeYear * 2) + (term == 'FA' ? 1 : 0);

    int currentAcademicYear = currentYear;
    bool isFall = false;

    if (currentMonth >= 9) {
      // Sep-Dec: Fall of current year
      isFall = true;
      currentAcademicYear = currentYear;
    } else if (currentMonth <= 2) {
      // Jan-Feb: Fall of previous year
      isFall = true;
      currentAcademicYear = currentYear - 1;
    } else {
      // Mar-Aug: Spring of current year
      isFall = false;
      currentAcademicYear = currentYear;
    }

    final currentIndex = (currentAcademicYear * 2) + (isFall ? 1 : 0);
    final sem = currentIndex - intakeIndex + 1;
    return sem.clamp(1, 8);
  }

  factory BatchKey.parse(String batch) {
    var raw = batch.trim();
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
      final prog = parts.isNotEmpty ? parts.first.toUpperCase() : 'UNKNOWN';
      return BatchKey(
        batch: raw,
        program: prog,
        semester: 1,
        section: parts.length > 1 ? parts[1].toUpperCase() : 'A',
        intake: parts.isNotEmpty ? parts.first.toUpperCase() : 'NA',
        department: resolveDepartment(prog),
      );
    }

    final intake = parts[0].toUpperCase();
    final program = parts[1].toUpperCase();
    final dept = resolveDepartment(program);

    // Case 1: 4-part batch e.g. "FA25-BCS-2-C" -> intake="FA25", prog="BCS", sem=2, sec="C"
    if (parts.length >= 4) {
      final semParsed = int.tryParse(parts[2]) ?? calculateSemester(intake);
      final rawSec = parts[3];
      final secMatch = RegExp(r'^[A-Za-z0-9]{1,3}').firstMatch(rawSec);
      final section = secMatch != null ? secMatch.group(0)!.toUpperCase() : rawSec.toUpperCase();
      final canonical = '$intake-$program-$semParsed-$section';
      return BatchKey(
        batch: canonical,
        program: program,
        semester: semParsed,
        section: section,
        intake: intake,
        department: dept,
      );
    }

    // Case 2: 3-part batch e.g. "FA24-BSE-A" or "SP23-FSN-B" -> calculate semester dynamically
    final lastPart = parts[2];
    final semMatch = RegExp(r'^\d+').firstMatch(lastPart);
    int semParsed = calculateSemester(intake);
    String section = 'A';

    if (semMatch != null) {
      semParsed = int.tryParse(semMatch.group(0)!) ?? semParsed;
      final secRem = lastPart.substring(semMatch.group(0)!.length);
      if (secRem.isNotEmpty) {
        section = secRem.toUpperCase();
      }
    } else {
      final secMatch = RegExp(r'^[A-Za-z0-9]{1,3}').firstMatch(lastPart);
      section = secMatch != null ? secMatch.group(0)!.toUpperCase() : lastPart.toUpperCase();
    }

    final canonical = '$intake-$program-$section';
    return BatchKey(
      batch: canonical,
      program: program,
      semester: semParsed,
      section: section,
      intake: intake,
      department: dept,
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
           subject.trim().toLowerCase() == other.subject.trim().toLowerCase() &&
           teacher.trim().toLowerCase() == other.teacher.trim().toLowerCase() &&
           FormatGuard.sanitizeRoom(room) == FormatGuard.sanitizeRoom(other.room) &&
           ((actualEndVal - other.safeStartVal).abs() < 0.1 || (safeEndVal - other.safeStartVal).abs() < 0.1);
  }

  // Check if two sessions are the same lecture (for merging)
  bool isSameLectureAs(ClassSession other) {
    return dayIndex == other.dayIndex &&
           subject.trim().toLowerCase() == other.subject.trim().toLowerCase() &&
           teacher.trim().toLowerCase() == other.teacher.trim().toLowerCase() &&
           FormatGuard.sanitizeRoom(room) == FormatGuard.sanitizeRoom(other.room);
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

    // If subject indicates (1 hr) and duration exceeds 1 hour (e.g. regular 1.5-hr slot), clamp duration to 1 hour
    if (RegExp(r'\(1\s*(?:hr|hour)\)', caseSensitive: false).hasMatch(subjectStr)) {
      final startDec = FormatGuard.toDecimalTime(start);
      final endDec = FormatGuard.toDecimalTime(end);
      if (endDec - startDec > 1.05) {
        final newEndDec = startDec + 1.0;
        final endH = newEndDec.toInt();
        final endM = ((newEndDec - endH) * 60).round();
        final origH = int.tryParse(start.split(RegExp(r'[:.]'))[0]) ?? 0;
        final adjustedH = origH + 1;
        end = '${adjustedH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';
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

  UniversityMemory([this.sessions = const []]);

  List<ClassSession>? _cachedActiveSessions;
  String? _cachedPeriodKey;
  int? _cachedExamsHash;
  final Map<String, Map<String, List<ClassSession>>> _cachedByBatchMap = {};
  final Map<String, Map<String, List<ClassSession>>> _cachedByTeacherMap = {};
  final Map<String, Map<String, List<ClassSession>>> _cachedByProgramMap = {};
  List<String>? _cachedAllBatches;
  List<String>? _cachedPrograms;
  final Map<String, List<String>> _cachedAllRooms = {};
  final Map<String, List<String>> _cachedAllTeachers = {};
  final Map<String, List<int>> _cachedSemesters = {};
  final Map<String, List<String>> _cachedIntakes = {};
  final Map<String, List<String>> _cachedSectionsForIntake = {};
  final Map<String, List<String>> _cachedSections = {};

  void clearCaches() {
    _cachedActiveSessions = null;
    _cachedPeriodKey = null;
    _cachedExamsHash = null;
    _cachedByBatchMap.clear();
    _cachedByTeacherMap.clear();
    _cachedByProgramMap.clear();
    _cachedAllBatches = null;
    _cachedPrograms = null;
    _cachedAllRooms.clear();
    _cachedAllTeachers.clear();
    _cachedSemesters.clear();
    _cachedIntakes.clear();
    _cachedSectionsForIntake.clear();
    _cachedSections.clear();
  }

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
    _cachedByBatchMap.remove(periodKey);
    _cachedByTeacherMap.remove(periodKey);
    _cachedByProgramMap.remove(periodKey);
    return result;
  }

  List<String> get allBatches {
    if (_cachedAllBatches != null) return _cachedAllBatches!;
    final batches = sessions.map((s) => s.batchKey.batch).toSet().toList();
    batches.sort();
    _cachedAllBatches = batches;
    return batches;
  }

  Map<String, List<ClassSession>> byBatch({String? overridePeriod}) {
    final periodKey = overridePeriod ?? 'default';
    final cached = _cachedByBatchMap[periodKey];
    if (cached != null) return cached;

    final map = <String, List<ClassSession>>{};
    for (final session in activeSessions(overridePeriod: overridePeriod)) {
      map.putIfAbsent(session.batchKey.batch, () => []).add(session);
    }
    _cachedByBatchMap[periodKey] = map;
    return map;
  }

  Map<String, List<ClassSession>> byTeacher({String? overridePeriod}) {
    final periodKey = overridePeriod ?? 'default';
    final cached = _cachedByTeacherMap[periodKey];
    if (cached != null) return cached;

    final map = <String, List<ClassSession>>{};
    for (final session in activeSessions(overridePeriod: overridePeriod)) {
      final key = session.teacher.trim().toLowerCase();
      if (key.isNotEmpty && key != 'unknown' && key != 'na') {
        map.putIfAbsent(key, () => []).add(session);
      }
    }
    _cachedByTeacherMap[periodKey] = map;
    return map;
  }

  Map<String, List<ClassSession>> byProgram(String program, {String? overridePeriod}) {
    final progUpper = program.toUpperCase().trim();
    final periodKey = '${overridePeriod ?? "default"}_$progUpper';
    final cached = _cachedByProgramMap[periodKey];
    if (cached != null) return cached;

    final map = <String, List<ClassSession>>{};
    for (final session in activeSessions(overridePeriod: overridePeriod).where((s) => s.batchKey.program.toUpperCase().trim() == progUpper)) {
      map.putIfAbsent(session.batchKey.batch, () => []).add(session);
    }
    _cachedByProgramMap[periodKey] = map;
    return map;
  }

  List<String> programs() {
    if (_cachedPrograms != null) return _cachedPrograms!;
    final items = sessions
        .map((s) => s.batchKey.program.toUpperCase().trim())
        .where((p) => p.isNotEmpty && p != 'UNKNOWN' && p != 'NA' && !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toSet()
        .toList();
    items.sort();
    _cachedPrograms = items;
    return items;
  }

  List<int> semesters(String program) {
    final progUpper = program.toUpperCase().trim();
    final cached = _cachedSemesters[progUpper];
    if (cached != null) return cached;

    final items = sessions
        .where((s) => s.batchKey.program.toUpperCase().trim() == progUpper)
        .map((s) => s.batchKey.semester)
        .where((sem) => sem > 0)
        .toSet()
        .toList();
    items.sort();
    _cachedSemesters[progUpper] = items;
    return items;
  }

  List<String> intakes(String program) {
    final progUpper = program.toUpperCase().trim();
    final cached = _cachedIntakes[progUpper];
    if (cached != null) return cached;

    final items = sessions
        .where((s) => s.batchKey.program.toUpperCase().trim() == progUpper)
        .map((s) => s.batchKey.intake.toUpperCase().trim())
        .where((intake) => intake.isNotEmpty && intake != 'UNKNOWN' && intake != 'NA')
        .toSet()
        .toList();
    items.sort((a, b) {
      final aYear = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '') ?? 0;
      final bYear = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '') ?? 0;
      if (aYear != bYear) return bYear.compareTo(aYear);
      return b.compareTo(a);
    });
    _cachedIntakes[progUpper] = items;
    return items;
  }

  List<String> sectionsForIntake(String program, String intake) {
    final progUpper = program.toUpperCase().trim();
    final intakeUpper = intake.toUpperCase().trim();
    final cacheKey = '${progUpper}_$intakeUpper';
    final cached = _cachedSectionsForIntake[cacheKey];
    if (cached != null) return cached;

    final items = sessions
        .where((s) =>
            s.batchKey.program.toUpperCase().trim() == progUpper &&
            s.batchKey.intake.toUpperCase().trim() == intakeUpper)
        .map((s) {
          final sec = s.batchKey.section.trim();
          final m = RegExp(r'^[A-Za-z0-9]{1,3}').firstMatch(sec);
          return m != null ? m.group(0)!.toUpperCase() : sec.toUpperCase();
        })
        .where((s) => s.isNotEmpty && s != 'UNKNOWN' && s != 'NA')
        .toSet()
        .toList();
    items.sort();
    _cachedSectionsForIntake[cacheKey] = items;
    return items;
  }

  List<String> sections(String program, int semester) {
    final progUpper = program.toUpperCase().trim();
    final cacheKey = '${progUpper}_$semester';
    final cached = _cachedSections[cacheKey];
    if (cached != null) return cached;

    final items = sessions
        .where((s) => s.batchKey.program.toUpperCase().trim() == progUpper && s.batchKey.semester == semester)
        .map((s) {
          final sec = s.batchKey.section.trim();
          final m = RegExp(r'^[A-Za-z0-9]{1,3}').firstMatch(sec);
          return m != null ? m.group(0)!.toUpperCase() : sec.toUpperCase();
        })
        .where((s) => s.isNotEmpty && s != 'UNKNOWN' && s != 'NA')
        .toSet()
        .toList();
    items.sort();
    _cachedSections[cacheKey] = items;
    return items;
  }

  List<String> allRooms({String? overridePeriod}) {
    final periodKey = overridePeriod ?? 'default';
    final cached = _cachedAllRooms[periodKey];
    if (cached != null) return cached;

    final rooms = <String>{};
    for (final session in activeSessions(overridePeriod: overridePeriod)) {
      final r = session.room.trim();
      if (r.isNotEmpty && r.toLowerCase() != 'unknown' && r.toLowerCase() != 'na') {
        rooms.add(r);
      }
    }
    final sorted = rooms.toList()..sort();
    _cachedAllRooms[periodKey] = sorted;
    return sorted;
  }

  List<String> allTeachers({String? overridePeriod}) {
    final periodKey = overridePeriod ?? 'default';
    final cached = _cachedAllTeachers[periodKey];
    if (cached != null) return cached;

    final names = <String>{};
    for (final session in activeSessions(overridePeriod: overridePeriod)) {
      final t = session.teacher.trim();
      if (t.isNotEmpty && t.toLowerCase() != 'unknown' && t.toLowerCase() != 'na') {
        names.add(t);
      }
    }
    final sorted = names.toList()..sort();
    _cachedAllTeachers[periodKey] = sorted;
    return sorted;
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
