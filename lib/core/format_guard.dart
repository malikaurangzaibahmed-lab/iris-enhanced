import 'dart:math';

class FormatGuard {
  static final RegExp _timeSplit = RegExp(r'[:.]');
  static final RegExp _roomNoise = RegExp(r'\(\d+\)');
  static final RegExp _roomParen = RegExp(r'\s*\([^)]*\)');
  static final RegExp _alphaOnly = RegExp(r'[A-Z]');
  static final RegExp _multiSpace = RegExp(r'\s{2,}');

  static final RegExp _roomDashRegex = RegExp(r'^([A-Za-z]+)\s*-\s*([0-9.]+)$');
  static final RegExp _wcrRegex = RegExp(r'^(WCR)\s*(\d+)$', caseSensitive: false);
  static final RegExp _dRegex = RegExp(r'^([D])\s*(\d+)$', caseSensitive: false);
  static final RegExp _clabRegex = RegExp(r'^(?:C-Lab|CLab|Computer\s*Lab)\s*[- ]?(\d+)$', caseSensitive: false);

  static final RegExp _weekdayPrefixRegex = RegExp(
    r'^(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)[,\s]+',
    caseSensitive: false,
  );
  static final RegExp _isoDateRegex = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$');
  static final RegExp _namedDateRegex = RegExp(r'^(\d{1,2})[-/\s]([A-Za-z]{3,9})[-/\s](\d{2,4})$');
  static final RegExp _dmyDateRegex = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$');
  static final RegExp _embeddedDateRegex = RegExp(r'(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})');

  static final RegExp _batchPrefixRegex = RegExp(
    r'^(?:(?:FA|SP)\d{2}-[A-Z0-9]+(?:-[A-Z0-9]+)?|[A-Z]{2,4}-\d+[A-Z]?|(?:BCS|BSE|BAI|BDS|BEE|BME|BBA|BSCS|BSSE|BSAI|BSDS|BSEE|BSME)-?\d*[A-Z]?)\s*[-/:]?\s*',
    caseSensitive: false,
  );
  static final RegExp _batchSuffixRegex = RegExp(
    r'\s*[-/:]?\s*(?:(?:FA|SP)\d{2}-[A-Z0-9]+(?:-[A-Z0-9]+)?|[A-Z]{2,4}-\d+[A-Z]?|(?:BCS|BSE|BAI|BDS|BEE|BME|BBA)-?\d*[A-Z]?)$',
    caseSensitive: false,
  );
  static final RegExp _parenthesizedTeacherRegex = RegExp(
    r'\s*\([^)]*(?:Dr|Prof|Engr|Mr|Ms|Mrs|Sir|Mam|[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)[^)]*\)',
    caseSensitive: false,
  );
  static final RegExp _durationNoiseRegex = RegExp(
    r'\s*\(\s*\d+\s*(?:hrs?|hours?)\s*\)\s*',
    caseSensitive: false,
  );
  static final RegExp _teacherHonorificDotRegex = RegExp(
    r'^(Dr|Prof|Engr|Mr|Ms|Mrs|Sir|Mam)\.([A-Za-z])',
    caseSensitive: false,
  );
  static final RegExp _teacherHonorificNoSpaceRegex = RegExp(
    r'^(Dr|Prof|Engr|Mr|Ms|Mrs|Sir|Mam)([A-Z])',
    caseSensitive: false,
  );

  static final Set<String> _deptPrefixes = {
    'CS', 'SE', 'AI', 'DS', 'CYS', 'BCS', 'BSE', 'BAI', 'BDS', 'BCY',
    'EE', 'BEE', 'BSEE', 'CE', 'BCE', 'TE', 'BTE', 'PTE',
    'ME', 'BME', 'BSME', 'CVE', 'BCVE', 'BSCE',
    'MS', 'BBA', 'MBA', 'AF', 'BAF', 'BBS', 'EC', 'BEC', 'MGT', 'HRM',
    'MT', 'MTH', 'BMT', 'HUM', 'ENG', 'BEN', 'PSY', 'BPS', 'MCM', 'IR', 'BIR',
    'FSN', 'BTY', 'BCH', 'HND', 'RBS', 'BIO', 'BBI', 'MB', 'PHY', 'CHM', 'VS'
  };

  static const Map<String, int> _monthMap = {
    'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3,
    'apr': 4, 'april': 4, 'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7,
    'aug': 8, 'august': 8, 'sep': 9, 'september': 9, 'oct': 10, 'october': 10,
    'nov': 11, 'november': 11, 'dec': 12, 'december': 12
  };

  // Memoization Caches
  static final Map<String, String> _roomSanitizeCache = {};
  static final Map<String, double> _decimalTimeCache = {};
  static final Map<String, String> _teacherFormatCache = {};
  static final Map<String, String> _subjectSanitizeCache = {};

  /// Canonicalize room name across PDF timetables and Excel date sheets
  static String sanitizeRoom(String raw) {
    if (raw.isEmpty) return 'TBA';
    final cached = _roomSanitizeCache[raw];
    if (cached != null) return cached;

    var cleaned = raw.replaceAll(_roomNoise, '').replaceAll(_roomParen, '').trim();
    
    // Normalize dashes and spaces: "A - 3" -> "A-3", "C - 1.1" -> "C-1.1"
    cleaned = cleaned.replaceAllMapped(
      _roomDashRegex,
      (m) => '${m[1]!.toUpperCase()}-${m[2]}',
    );

    // Normalize "WCR 1" -> "WCR-1", "D 1" -> "D1"
    cleaned = cleaned.replaceAllMapped(
      _wcrRegex,
      (m) => 'WCR-${m[2]}',
    );
    cleaned = cleaned.replaceAllMapped(
      _dRegex,
      (m) => 'D${m[2]}',
    );

    // Normalize "C-Lab 3", "CLab 3", "Computer Lab 3" -> "CLab-3"
    cleaned = cleaned.replaceAllMapped(
      _clabRegex,
      (m) => 'CLab-${m[1]}',
    );

    final result = cleaned.isEmpty ? raw.trim() : cleaned;
    _roomSanitizeCache[raw] = result;
    return result;
  }

  /// Comprehensive date parser handling all university date sheet variations:
  /// - "Mon 08-12-2025", "Monday 08-12-25", "08-12-2025", "08-12-25"
  /// - "25/03/2026", "25/03/26", "08-Dec-2025", "25-Mar-2026", "2025-12-08"
  static DateTime? parseDate(String raw) {
    if (raw.trim().isEmpty) return null;
    var s = raw.trim();

    // Strip weekday prefix e.g. "Monday 08-12-2025" or "Mon, 08-12-2025"
    s = s.replaceAll(_weekdayPrefixRegex, '').trim();

    // 1. ISO format: YYYY-MM-DD
    var match = _isoDateRegex.firstMatch(s);
    if (match != null) {
      final y = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      final d = int.parse(match.group(3)!);
      return DateTime(y, m, d);
    }

    // 2. Named Month: DD-MMM-YYYY or DD-MMM-YY (e.g. 08-Dec-2025, 25-Mar-26)
    match = _namedDateRegex.firstMatch(s);
    if (match != null) {
      final d = int.parse(match.group(1)!);
      final monthStr = match.group(2)!.toLowerCase();
      var y = int.parse(match.group(3)!);
      if (y < 100) y += 2000;

      final m = _monthMap[monthStr] ?? 1;
      return DateTime(y, m, d);
    }

    // 3. Numeric DMY: DD-MM-YYYY or DD-MM-YY or DD/MM/YYYY or DD/MM/YY
    match = _dmyDateRegex.firstMatch(s);
    if (match != null) {
      final d = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      var y = int.parse(match.group(3)!);
      if (y < 100) y += 2000;
      return DateTime(y, m, d);
    }

    // Fallback: search anywhere in string for DD-MM-YYYY or DD-MM-YY
    match = _embeddedDateRegex.firstMatch(raw);
    if (match != null) {
      final d = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      var y = int.parse(match.group(3)!);
      if (y < 100) y += 2000;
      return DateTime(y, m, d);
    }

    // 4. Excel Serial Date number e.g. "45999" (days since 1899-12-30)
    final serial = int.tryParse(s);
    if (serial != null && serial >= 35000 && serial <= 65000) {
      return DateTime(1899, 12, 30).add(Duration(days: serial));
    }

    return null;
  }

  /// Expands combined cohort sections e.g. "FA25-BCS-2-A&B" -> ["FA25-BCS-2-A", "FA25-BCS-2-B"]
  static List<String> expandBatchSections(String raw) {
    if (raw.trim().isEmpty) return [];
    final clean = raw.trim().toUpperCase();

    // Check for combined section markers '&', ',', '/'
    if (clean.contains('&') || clean.contains(',') || clean.contains('/')) {
      // Check compound batches: "FA25-BME/FA24-BME/FA22-BEE"
      if (RegExp(r'(?:FA|SP)\d{2}').allMatches(clean).length > 1) {
        return clean.split(RegExp(r'[/,]')).map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
      }

      // Check section combo: "FA25-BCS-2-A&B" or "FA24-BSE-A,B"
      final parts = clean.split('-');
      if (parts.length >= 3) {
        final lastPart = parts.last;
        final sections = lastPart.split(RegExp(r'[&,/]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (sections.length > 1) {
          final prefix = parts.sublist(0, parts.length - 1).join('-');
          return sections.map((sec) => '$prefix-$sec').toList();
        }
      }
    }

    return [clean];
  }

  static double toDecimalTime(String raw) {
    if (raw.isEmpty) return 8.5;
    final cached = _decimalTimeCache[raw];
    if (cached != null) return cached;

    var s = raw.trim().toUpperCase();
    final isPM = s.contains('PM');
    final isAM = s.contains('AM');
    s = s.replaceAll(_alphaOnly, '').trim();

    final parts = s.split(_timeSplit);
    if (parts.isEmpty) return 0.0;
    var hour = int.tryParse(parts[0].trim()) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;

    if (isPM && hour < 12) {
      hour += 12;
    } else if (isAM && hour == 12) {
      hour = 0;
    } else if (!isPM && !isAM) {
      // University timetable fallback heuristic: times 1:00-5:30 are PM
      if (hour >= 1 && hour <= 5) {
        hour += 12;
      }
    }

    final result = hour + (minute / 60.0);
    _decimalTimeCache[raw] = result;
    return result;
  }

  static int dayIndex(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'monday':
        return 1;
      case 'tuesday':
        return 2;
      case 'wednesday':
        return 3;
      case 'thursday':
        return 4;
      case 'friday':
        return 5;
      case 'saturday':
        return 6;
      case 'sunday':
        return 7;
      default:
        return 1;
    }
  }

  static String normalizeDay(int dayIndex) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[max(1, min(7, dayIndex)) - 1];
  }

  static String formatDecimalTime(double decimal) {
    int hour = decimal.toInt();
    int minutes = ((decimal - hour) * 60).round();
    
    String period = 'AM';
    if (hour >= 12) {
      period = 'PM';
      if (hour > 12) hour -= 12;
    }
    if (hour == 0) hour = 12;
    
    return '${hour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period';
  }

  static String sanitizeSubject(String raw) {
    if (raw.isEmpty || raw.toLowerCase() == 'unknown') return 'Unknown';
    final cached = _subjectSanitizeCache[raw];
    if (cached != null) return cached;

    var cleaned = raw.trim();
    
    // Strip parenthesized teacher
    cleaned = cleaned.replaceAll(_parenthesizedTeacherRegex, '');
    // Strip room noise and duration markers
    cleaned = cleaned.replaceAll(_roomNoise, '').replaceAll(_durationNoiseRegex, '');
    // Strip leading/trailing batch identifiers
    cleaned = cleaned.replaceAll(_batchPrefixRegex, '').replaceAll(_batchSuffixRegex, '');
    // Normalize spaces
    cleaned = cleaned.replaceAll(_multiSpace, ' ').trim();
    
    final result = cleaned.isEmpty ? raw.trim() : cleaned;
    _subjectSanitizeCache[raw] = result;
    return result;
  }

  static String formatTeacherName(String name) {
    final cached = _teacherFormatCache[name];
    if (cached != null) return cached;

    var raw = name.trim();
    if (raw.isEmpty || raw.toLowerCase() == 'unknown' || raw.toLowerCase() == 'tbd' || raw.toLowerCase() == 'none') {
      return 'Staff';
    }
    if (raw.toLowerCase() == 'staff' || raw.toLowerCase() == 'lecture') {
      return 'Staff';
    }

    // Strip department prefix if any e.g. "CS Dr. Shahzad Ali" -> "Dr. Shahzad Ali", "ME Zafar Farooq" -> "Zafar Farooq"
    final firstSpaceIdx = raw.indexOf(' ');
    if (firstSpaceIdx > 0) {
      final firstToken = raw.substring(0, firstSpaceIdx).replaceAll('.', '').toUpperCase();
      if (_deptPrefixes.contains(firstToken)) {
        raw = raw.substring(firstSpaceIdx + 1).trim();
      }
    }

    // Normalize missing space after honorific title e.g. "Dr.Saqib" -> "Dr. Saqib", "Engr.Hafiz" -> "Engr. Hafiz"
    raw = raw.replaceAllMapped(
      _teacherHonorificDotRegex,
      (m) => '${m[1]}. ${m[2]}',
    );
    raw = raw.replaceAllMapped(
      _teacherHonorificNoSpaceRegex,
      (m) => '${m[1]} ${m[2]}',
    );

    // Clean multiple consecutive spaces and preserve authentic timetable casing & initials exactly as in university source
    final result = raw.replaceAll(_multiSpace, ' ').trim();
    _teacherFormatCache[name] = result;
    return result;
  }

  static String truncateTeacherName(String name, {int maxLength = 18}) {
    final formatted = formatTeacherName(name);
    if (formatted.length <= maxLength) {
      return formatted;
    }

    // If it's still too long, let's extract words and see if we can abbreviate middle names/initials
    final prefixRegex = RegExp(
      r'^\s*(Dr\.|Prof\.|Engr\.|Mr\.|Ms\.|Mrs\.|Sir|Mam|Lecturer)\s*',
    );
    
    String? prefix;
    var rawName = formatted;
    final prefixMatch = prefixRegex.firstMatch(formatted);
    if (prefixMatch != null) {
      prefix = prefixMatch.group(0);
      rawName = formatted.substring(prefixMatch.end).trim();
    }

    final words = rawName.split(' ');
    if (words.length <= 2) {
      final combined = prefix != null ? '$prefix$rawName' : rawName;
      if (combined.length <= maxLength) return combined;
      return '${combined.substring(0, maxLength - 3)}...';
    }

    // We have 3 or more words, e.g. "Muhammad Aurangzaib Ahmed"
    // Keep first and last word, turn middle words into initials
    final firstWord = words.first;
    final lastWord = words.last;
    final middleInitials = <String>[];

    for (int i = 1; i < words.length - 1; i++) {
      final w = words[i];
      if (w.endsWith('.') && w.length <= 2) {
        middleInitials.add(w);
      } else {
        middleInitials.add('${w[0].toUpperCase()}.');
      }
    }

    final middleStr = middleInitials.join(' ');
    var shortened = '$firstWord $middleStr $lastWord';
    if (prefix != null) {
      shortened = '$prefix$shortened';
    }

    if (shortened.length <= maxLength) {
      return shortened;
    }

    // If still too long, keep only prefix + first initial + last name
    final firstInitial = '${firstWord[0].toUpperCase()}.';
    shortened = '$firstInitial $lastWord';
    if (prefix != null) {
      shortened = '$prefix$shortened';
    }

    if (shortened.length <= maxLength) {
      return shortened;
    }

    // Hard truncate
    return '${shortened.substring(0, maxLength - 3)}...';
  }
}
