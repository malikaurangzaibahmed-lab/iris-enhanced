import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:iris/core/format_guard.dart';
import 'package:iris/core/models.dart';

class PDFTimetableParser {
  /// Parse timetable from PDF file and extract class sessions
  /// This is a framework - actual PDF parsing would need pdf package integration
  static Future<List<ClassSession>> parsePDFTimetable(
    File pdfFile, {
    required String currentBatch,
  }) async {
    final bytes = await pdfFile.readAsBytes();
    return compute(_parsePdfAndExtractIsolate, {'bytes': bytes, 'batch': currentBatch});
  }

  static List<ClassSession> _parsePdfAndExtractIsolate(Map<String, dynamic> args) {
    final bytes = args['bytes'] as List<int>;
    final currentBatch = args['batch'] as String;
    
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();

    return _parseFromText(text, currentBatch);
  }

  static List<ClassSession> _parseFromText(
    String text,
    String currentBatch,
  ) {
    if (text.trim().isEmpty) {
      return [];
    }

    final normalized = text
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final lines = normalized
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final dayRegex = RegExp(
      r'\b(Mon|Monday|Tue|Tuesday|Wed|Wednesday|Thu|Thursday|Fri|Friday|Sat|Saturday|Sun|Sunday)\b',
      caseSensitive: false,
    );
    final timeRegex = RegExp(
      r'(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?\s*-\s*(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?',
      caseSensitive: false,
    );
    final roomRegex = RegExp(
      r'(?:[A-Z]\d+(?:\.\d)?|[A-Z]{2,3}Lab-?\d*|CLab-?\d+|MOM\s*Lab|EFM\s*Lab|Mechanical\s+Vibrations\s+Lab|Engineering\s+[A-Za-z\s]+?Lab)',
    );
    final teacherRegex = RegExp(
      r'\b(Dr\.?|Prof\.?|Engr\.?|Mr\.?|Ms\.?|Mrs\.?|Sir|Mam)\b',
      caseSensitive: false,
    );
    final initialsRegex = RegExp(r'\b[A-Z]\.\s*[A-Z]\.', caseSensitive: false);

    final batchKey = BatchKey.parse(currentBatch);
    final sessions = <ClassSession>[];
    var counter = 0;
    String? currentDayToken;
    String? buffer;

    for (final line in lines) {
      final dayMatch = dayRegex.firstMatch(line);
      final isDayHeader = dayMatch != null && !timeRegex.hasMatch(line);
      if (isDayHeader) {
        currentDayToken = dayMatch.group(0);
        if (buffer != null) {
          final parsed = _parseRow(
            buffer,
            currentDayToken,
            batchKey,
            counter,
            dayRegex,
            timeRegex,
            roomRegex,
            teacherRegex,
            initialsRegex,
          );
          if (parsed != null) {
            sessions.add(parsed.session);
            counter = parsed.nextCounter;
          }
          buffer = null;
        }
        continue;
      }

      if (timeRegex.hasMatch(line)) {
        if (buffer != null) {
          final parsed = _parseRow(
            buffer,
            currentDayToken,
            batchKey,
            counter,
            dayRegex,
            timeRegex,
            roomRegex,
            teacherRegex,
            initialsRegex,
          );
          if (parsed != null) {
            sessions.add(parsed.session);
            counter = parsed.nextCounter;
          }
        }
        buffer = line;
        if (dayMatch != null) {
          currentDayToken = dayMatch.group(0);
        }
        continue;
      }

      if (buffer != null) {
        buffer = '$buffer ${line.trim()}';
      } else if (dayMatch != null) {
        currentDayToken = dayMatch.group(0);
      }
    }

    if (buffer != null) {
      final parsed = _parseRow(
        buffer,
        currentDayToken,
        batchKey,
        counter,
        dayRegex,
        timeRegex,
        roomRegex,
        teacherRegex,
        initialsRegex,
      );
      if (parsed != null) {
        sessions.add(parsed.session);
      }
    }

    return sessions;
  }

  static _ParsedRow? _parseRow(
    String line,
    String? dayToken,
    BatchKey batchKey,
    int counter,
    RegExp dayRegex,
    RegExp timeRegex,
    RegExp roomRegex,
    RegExp teacherRegex,
    RegExp initialsRegex,
  ) {
    final timeMatch = timeRegex.firstMatch(line);
    if (timeMatch == null) {
      return null;
    }

    final effectiveDay = dayRegex.firstMatch(line)?.group(0) ?? dayToken;
    if (effectiveDay == null || effectiveDay.isEmpty) {
      return null;
    }

    final dayIndex = _dayIndexFromToken(effectiveDay);
    final timeRange = _normalizeTimeRange(timeMatch);
    if (timeRange == null) {
      return null;
    }

    var remainder = line;
    remainder = remainder.replaceFirst(timeMatch.group(0)!, '').trim();
    final dayMatch = dayRegex.firstMatch(remainder);
    if (dayMatch != null) {
      remainder = remainder.replaceFirst(dayMatch.group(0)!, '').trim();
    }

    var room = 'TBD';
    final roomMatch = roomRegex.firstMatch(remainder);
    if (roomMatch != null) {
      room = roomMatch.group(0) ?? 'TBD';
      remainder = remainder.replaceFirst(roomMatch.group(0)!, '').trim();
    }

    remainder = remainder.replaceAll(RegExp(r'\s{2,}'), '  ');

    final parts = remainder
        .split(RegExp(r'\s{2,}|\s\|\s'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    var teacher = 'Unknown';
    int? teacherIndex;
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (teacherRegex.hasMatch(part) || initialsRegex.hasMatch(part)) {
        teacher = part;
        teacherIndex = i;
        break;
      }
    }
    if (teacherIndex != null) {
      parts.removeAt(teacherIndex);
    }

    if (room == 'TBD' && parts.isNotEmpty) {
      final maybeRoom = parts.last;
      if (_looksLikeRoom(maybeRoom)) {
        room = maybeRoom;
        parts.removeLast();
      }
    }

    var subject = parts.isNotEmpty ? parts.first : 'Unknown';
    if (teacher == 'Unknown' && parts.length > 1) {
      final possibleTeacher = parts.last;
      if (_looksLikeTeacher(possibleTeacher)) {
        teacher = possibleTeacher;
        if (parts.length > 2) {
          subject = parts.first;
        }
      }
    }

    if (teacher == 'Unknown') {
      final embedded = _extractTeacherFromSubject(subject);
      if (embedded != null) {
        subject = embedded.subject;
        teacher = embedded.teacher;
      }
    }

    final session = ClassSession(
      id: '${batchKey.batch}-${dayIndex}-${timeRange.start}-${counter}',
      batchKey: batchKey,
      dayIndex: dayIndex,
      startTime: timeRange.start,
      endTime: timeRange.end,
      subject: _cleanLabel(subject),
      teacher: _cleanLabel(teacher),
      room: FormatGuard.sanitizeRoom(room),
    );

    return _ParsedRow(session, counter + 1);
  }

  static _TimeRange? _normalizeTimeRange(RegExpMatch match) {
    final startHour = int.tryParse(match.group(1) ?? '');
    final startMin = int.tryParse(match.group(2) ?? '00') ?? 0;
    final startPeriod = match.group(3)?.toLowerCase();
    final endHour = int.tryParse(match.group(4) ?? '');
    final endMin = int.tryParse(match.group(5) ?? '00') ?? 0;
    final endPeriod = match.group(6)?.toLowerCase();

    if (startHour == null || endHour == null) {
      return null;
    }

    final inferredPeriod = startPeriod ?? endPeriod;
    final normalizedStart = _to24Hour(startHour, startPeriod ?? inferredPeriod);
    var normalizedEnd = _to24Hour(endHour, endPeriod ?? inferredPeriod);

    if (startPeriod == null && endPeriod == null && normalizedEnd < normalizedStart) {
      final adjusted = normalizedEnd + 12;
      if (adjusted <= 23) {
        normalizedEnd = adjusted;
      }
    }

    final startLabel = _formatTime(normalizedStart, startMin);
    final endLabel = _formatTime(normalizedEnd, endMin);
    return _TimeRange(startLabel, endLabel);
  }

  static int _to24Hour(int hour, String? period) {
    if (period == null) return hour;
    if (period == 'pm' && hour < 12) return hour + 12;
    if (period == 'am' && hour == 12) return 0;
    return hour;
  }

  static String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static bool _looksLikeRoom(String value) {
    // Match various room formats
    final roomPatterns = [
      RegExp(r'^[A-Z]\d+(\.\d+)?'),           // A1.1, W3, etc.
      RegExp(r'Lab\s*-?\s*\d', caseSensitive: false),  // Lab-8, CLab-8, etc.
      RegExp(r'Lab\b', caseSensitive: false), // Lab (any lab ending)
      RegExp(r'^Room\s+\w+', caseSensitive: false),    // Room G-201
      RegExp(r'\w+\s+Lab\b', caseSensitive: false),    // Mechanical Vibrations Lab
    ];
    
    return roomPatterns.any((pattern) => pattern.hasMatch(value));
  }

  static bool _looksLikeTeacher(String value) {
    if (value.length < 3) return false;
    if (RegExp(r'\d').hasMatch(value)) return false;
    return RegExp(r'\b(Dr|Prof|Engr|Mr|Ms|Mrs|Sir|Mam)\b',
            caseSensitive: false)
        .hasMatch(value) ||
        RegExp(r'\b[A-Z]\.\s*[A-Z]\.', caseSensitive: false).hasMatch(value) ||
        value.split(' ').length >= 2;
  }

  static _SubjectTeacher? _extractTeacherFromSubject(String value) {
    final match = RegExp(r'^(.*)\(([^)]+)\)$').firstMatch(value);
    if (match == null) return null;
    final subject = match.group(1)?.trim();
    final teacher = match.group(2)?.trim();
    if (subject == null || subject.isEmpty || teacher == null || teacher.isEmpty) {
      return null;
    }
    return _SubjectTeacher(subject, teacher);
  }

  static String _cleanLabel(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int _dayIndexFromToken(String token) {
    switch (token.toLowerCase()) {
      case 'mon':
      case 'monday':
        return 1;
      case 'tue':
      case 'tuesday':
        return 2;
      case 'wed':
      case 'wednesday':
        return 3;
      case 'thu':
      case 'thursday':
        return 4;
      case 'fri':
      case 'friday':
        return 5;
      case 'sat':
      case 'saturday':
        return 6;
      case 'sun':
      case 'sunday':
        return 7;
      default:
        return 1;
    }
  }

  /// Intelligently compare old vs new timetable
  static TimetableComparison compareSchedules(
    List<ClassSession> oldSessions,
    List<ClassSession> newSessions,
  ) {
    final added = <ClassSession>[];
    final removed = <ClassSession>[];
    final modified = <SessionModification>[];

    // Build lookup maps for efficient comparison
    final newMap = {for (var s in newSessions) _getSessionKey(s): s};
    final oldMap = {for (var s in oldSessions) _getSessionKey(s): s};

    // Find new and modified sessions
    for (final newSession in newSessions) {
      final key = _getSessionKey(newSession);
      final oldSession = oldMap[key];

      if (oldSession == null) {
        // Try fuzzy matching for renamed courses
        final fuzzyMatch = _findFuzzyMatch(newSession, oldSessions);
        if (fuzzyMatch != null && !modified.any((m) => m.oldSession == fuzzyMatch)) {
          modified.add(SessionModification(
            oldSession: fuzzyMatch,
            newSession: newSession,
            changes: _detectChanges(fuzzyMatch, newSession),
          ));
        } else {
          added.add(newSession);
        }
      } else if (oldSession != newSession) {
        // Session exists but details changed
        modified.add(SessionModification(
          oldSession: oldSession,
          newSession: newSession,
          changes: _detectChanges(oldSession, newSession),
        ));
      }
    }

    // Find removed sessions
    for (final oldSession in oldSessions) {
      final key = _getSessionKey(oldSession);
      if (!newMap.containsKey(key) &&
          !modified.any((m) => m.oldSession == oldSession)) {
        removed.add(oldSession);
      }
    }

    return TimetableComparison(
      added: added,
      removed: removed,
      modified: modified,
      conflictCount: _calculateConflicts(newSessions),
    );
  }

  /// Generate unique key for session matching (time + room + day)
  static String _getSessionKey(ClassSession session) {
    return '${session.dayIndex}|${session.startTime}|${session.room}';
  }

  /// Find fuzzy match for renamed/modified courses
  static ClassSession? _findFuzzyMatch(
    ClassSession newSession,
    List<ClassSession> oldSessions,
  ) {
    // Find session at same time slot, likely same course
    final timeMatches = oldSessions.where((s) =>
        s.dayIndex == newSession.dayIndex &&
        s.startTime == newSession.startTime &&
        s.room == newSession.room);

    if (timeMatches.isNotEmpty) {
      return timeMatches.first;
    }

    // Find by similarity score (subject name similarity)
    double maxSimilarity = 0;
    ClassSession? bestMatch;

    for (final old in oldSessions) {
      final similarity = _stringSimilarity(
        newSession.subject.toLowerCase(),
        old.subject.toLowerCase(),
      );
      if (similarity > maxSimilarity && similarity > 0.6) {
        maxSimilarity = similarity;
        bestMatch = old;
      }
    }

    return bestMatch;
  }

  /// Calculate string similarity (Levenshtein-inspired)
  static double _stringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;

    final editDistance = _levenshteinDistance(shorter, longer);
    return (longer.length - editDistance) / longer.length;
  }

  /// Levenshtein distance algorithm
  static int _levenshteinDistance(String a, String b) {
    final dp = List<List<int>>.generate(
      a.length + 1,
      (i) => List<int>.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) dp[i][0] = i;
    for (int j = 0; j <= b.length; j++) dp[0][j] = j;

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[a.length][b.length];
  }

  /// Detect specific changes between two sessions
  static List<String> _detectChanges(ClassSession old, ClassSession newSession) {
    final changes = <String>[];

    if (old.subject != newSession.subject) {
      changes.add('Subject: ${old.subject} → ${newSession.subject}');
    }
    if (old.room != newSession.room) {
      changes.add('Room: ${old.room} → ${newSession.room}');
    }
    if (old.teacher != newSession.teacher) {
      changes.add('Teacher: ${old.teacher} → ${newSession.teacher}');
    }
    if (old.startTime != newSession.startTime || old.endTime != newSession.endTime) {
      changes.add('Time: ${old.startTime}-${old.endTime} → ${newSession.startTime}-${newSession.endTime}');
    }

    return changes;
  }

  /// Calculate schedule conflicts
  static int _calculateConflicts(List<ClassSession> sessions) {
    int conflicts = 0;
    for (int i = 0; i < sessions.length; i++) {
      for (int j = i + 1; j < sessions.length; j++) {
        if (_sessionsConflict(sessions[i], sessions[j])) {
          conflicts++;
        }
      }
    }
    return conflicts;
  }

  /// Check if two sessions conflict
  static bool _sessionsConflict(ClassSession a, ClassSession b) {
    if (a.dayIndex != b.dayIndex) return false;
    return !(a.safeEndVal <= b.safeStartVal || b.safeEndVal <= a.safeStartVal);
  }
}

class _TimeRange {
  final String start;
  final String end;

  const _TimeRange(this.start, this.end);
}

class _SubjectTeacher {
  final String subject;
  final String teacher;

  const _SubjectTeacher(this.subject, this.teacher);
}

class _ParsedRow {
  final ClassSession session;
  final int nextCounter;

  const _ParsedRow(this.session, this.nextCounter);
}

class TimetableComparison {
  final List<ClassSession> added;
  final List<ClassSession> removed;
  final List<SessionModification> modified;
  final int conflictCount;

  TimetableComparison({
    required this.added,
    required this.removed,
    required this.modified,
    required this.conflictCount,
  });

  int get totalChanges => added.length + removed.length + modified.length;
}

class SessionModification {
  final ClassSession oldSession;
  final ClassSession newSession;
  final List<String> changes;

  SessionModification({
    required this.oldSession,
    required this.newSession,
    required this.changes,
  });
}
