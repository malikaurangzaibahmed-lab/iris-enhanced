import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:student_organizer/core/models.dart';

/// Debug parser that logs detailed extraction info for each row
class PDFDebugParser {
  /// Parse and log detailed debug info about extraction
  /// Returns null if PDF cannot be read
  static Future<PDFDebugResult?> parseWithDebug(
    File pdfFile, {
    required String currentBatch,
  }) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();

      final logs = <String>[];
      logs.add('=== PDF Debug Parse: ${pdfFile.path} ===');
      logs.add('Raw text length: ${text.length} chars');
      logs.add('');

      final sessions = <ClassSession>[];
      final rows = <DebugRow>[];

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

      logs.add('Extracted ${lines.length} lines');
      logs.add('');

      final dayRegex = RegExp(
        r'\b(Mon|Monday|Tue|Tuesday|Wed|Wednesday|Thu|Thursday|Fri|Friday|Sat|Saturday|Sun|Sunday)\b',
        caseSensitive: false,
      );
      final timeRegex = RegExp(
        r'(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?\s*-\s*(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?',
        caseSensitive: false,
      );

      String? currentDay;
      String? buffer;

      for (int idx = 0; idx < lines.length; idx++) {
        final line = lines[idx];
        final dayMatch = dayRegex.firstMatch(line);
        final isDayHeader = dayMatch != null && !timeRegex.hasMatch(line);

        logs.add('[Line ${idx + 1}] $line');

        if (isDayHeader) {
          currentDay = dayMatch.group(0);
          logs.add('  → Day header: $currentDay');

          if (buffer != null) {
            final parsed = _tryParseRow(buffer, currentDay, currentBatch, logs);
            if (parsed != null) {
              sessions.add(parsed.session);
              rows.add(parsed.debugRow);
            }
            buffer = null;
          }
          continue;
        }

        if (timeRegex.hasMatch(line)) {
          if (buffer != null) {
            final parsed = _tryParseRow(buffer, currentDay, currentBatch, logs);
            if (parsed != null) {
              sessions.add(parsed.session);
              rows.add(parsed.debugRow);
            }
          }
          buffer = line;
          if (dayMatch != null) {
            currentDay = dayMatch.group(0);
          }
          logs.add('  → Time row (buffered)');
          continue;
        }

        if (buffer != null) {
          buffer = '$buffer $line';
          logs.add('  → Appended to buffer');
        } else if (dayMatch != null) {
          currentDay = dayMatch.group(0);
        }
      }

      if (buffer != null) {
        final parsed = _tryParseRow(buffer, currentDay, currentBatch, logs);
        if (parsed != null) {
          sessions.add(parsed.session);
          rows.add(parsed.debugRow);
        }
      }

      logs.add('');
      logs.add('=== Summary ===');
      logs.add('Parsed ${sessions.length} sessions');
      logs.add('');

      return PDFDebugResult(
        sessions: sessions,
        rows: rows,
        logs: logs,
      );
    } catch (e, st) {
      return PDFDebugResult(
        sessions: [],
        rows: [],
        logs: ['ERROR: $e', st.toString()],
      );
    }
  }

  static _ParsedDebug? _tryParseRow(
    String line,
    String? dayToken,
    String currentBatch,
    List<String> logs,
  ) {
    final timeRegex = RegExp(
      r'(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?\s*-\s*(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?',
      caseSensitive: false,
    );
    final timeMatch = timeRegex.firstMatch(line);

    if (timeMatch == null) {
      logs.add('  ✗ No time match in: $line');
      return null;
    }

    if (dayToken == null || dayToken.isEmpty) {
      logs.add('  ✗ No day token for: $line');
      return null;
    }

    final batchKey = BatchKey.parse(currentBatch);
    final dayIndex = _dayIndexFromToken(dayToken);

    final startHour = int.tryParse(timeMatch.group(1) ?? '');
    final startMin = int.tryParse(timeMatch.group(2) ?? '00') ?? 0;
    final startPeriod = timeMatch.group(3)?.toLowerCase();
    final endHour = int.tryParse(timeMatch.group(4) ?? '');
    final endMin = int.tryParse(timeMatch.group(5) ?? '00') ?? 0;
    final endPeriod = timeMatch.group(6)?.toLowerCase();

    if (startHour == null || endHour == null) {
      logs.add('  ✗ Time parse failed: ${timeMatch.group(0)}');
      return null;
    }

    final inferredPeriod = startPeriod ?? endPeriod;
    final normalizedStart = _to24Hour(startHour, startPeriod ?? inferredPeriod);
    var normalizedEnd = _to24Hour(endHour, endPeriod ?? inferredPeriod);

    if (startPeriod == null && endPeriod == null && normalizedEnd < normalizedStart) {
      normalizedEnd += 12;
    }

    final startLabel = _formatTime(normalizedStart, startMin);
    final endLabel = _formatTime(normalizedEnd, endMin);

    var remainder = line.replaceFirst(timeMatch.group(0)!, '').trim();

    var room = 'TBD';
    final roomRegex = RegExp(r'\b(?:[A-Z]{1,3}|Lab|LAB|Room|Rm|R)\s*-?\s*\d{1,3}\b');
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

    var subject = parts.isNotEmpty ? parts[0] : 'Unknown';
    var teacher = parts.length > 1 ? parts[1] : 'Unknown';

    final session = ClassSession(
      id: '${batchKey.batch}-${dayIndex}-${startLabel}',
      batchKey: batchKey,
      dayIndex: dayIndex,
      startTime: startLabel,
      endTime: endLabel,
      subject: subject,
      teacher: teacher,
      room: room,
    );

    final debugRow = DebugRow(
      rawLine: line,
      day: dayToken,
      timeRange: '${timeMatch.group(0)}',
      subject: subject,
      teacher: teacher,
      room: room,
      confidence: _calculateConfidence(subject, teacher, room),
    );

    logs.add('  ✓ Day=$dayToken Time=$startLabel-$endLabel Room=$room Subject=$subject Teacher=$teacher (conf=${debugRow.confidence}%)');

    return _ParsedDebug(session: session, debugRow: debugRow);
  }

  static int _calculateConfidence(String subject, String teacher, String room) {
    int conf = 100;
    if (subject.toLowerCase() == 'unknown') conf -= 30;
    if (teacher.toLowerCase() == 'unknown') conf -= 25;
    if (room.toLowerCase() == 'tbd' || room.toLowerCase() == 'unknown') conf -= 20;
    return conf.clamp(0, 100);
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
        return 0;
    }
  }
}

class DebugRow {
  final String rawLine;
  final String day;
  final String timeRange;
  final String subject;
  final String teacher;
  final String room;
  final int confidence;

  DebugRow({
    required this.rawLine,
    required this.day,
    required this.timeRange,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.confidence,
  });

  @override
  String toString() => '[$confidence%] $day $timeRange | $subject | $teacher | $room';
}

class _ParsedDebug {
  final ClassSession session;
  final DebugRow debugRow;

  _ParsedDebug({required this.session, required this.debugRow});
}

class PDFDebugResult {
  final List<ClassSession> sessions;
  final List<DebugRow> rows;
  final List<String> logs;

  PDFDebugResult({
    required this.sessions,
    required this.rows,
    required this.logs,
  });

  String logsAsString() => logs.join('\n');
}
