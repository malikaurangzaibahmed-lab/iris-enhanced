import 'dart:math';

class FormatGuard {
  static final RegExp _timeSplit = RegExp(r'[:.]');
  static final RegExp _roomNoise = RegExp(r'\(\d+\)');

  static String sanitizeRoom(String raw) {
    final cleaned = raw.replaceAll(_roomNoise, '').trim();
    return cleaned.isEmpty ? raw.trim() : cleaned;
  }

  static double toDecimalTime(String raw) {
    final parts = raw.trim().split(_timeSplit);
    if (parts.length < 2) return 0.0;
    var hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    
    // Handle 12-hour format: times 1:00-4:30 are PM (university hours 8:30 AM - 4:30 PM)
    if (hour >= 1 && hour <= 4) {
      hour += 12;
    }
    
    return hour + (minute / 60.0);
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
  static final Set<String> _deptPrefixes = {
    'CS', 'SE', 'AI', 'DS', 'CYS', 'BCS', 'BSE', 'BAI', 'BDS', 'BCY',
    'EE', 'BEE', 'BSEE', 'CE', 'BCE', 'TE', 'BTE', 'PTE',
    'ME', 'BME', 'BSME', 'CVE', 'BCVE', 'BSCE',
    'MS', 'BBA', 'MBA', 'AF', 'BAF', 'BBS', 'EC', 'BEC', 'MGT', 'HRM',
    'MT', 'MTH', 'BMT', 'HUM', 'ENG', 'BEN', 'PSY', 'BPS', 'MCM', 'IR', 'BIR',
    'FSN', 'BTY', 'BCH', 'HND', 'RBS', 'BIO', 'BBI', 'MB', 'PHY', 'CHM', 'VS'
  };

  static String sanitizeSubject(String raw) {
    if (raw.isEmpty || raw.toLowerCase() == 'unknown') return 'Unknown';
    var cleaned = raw.trim();
    
    // Strip parenthesized teacher
    cleaned = cleaned.replaceAll(_parenthesizedTeacherRegex, '');
    // Strip room noise and duration markers
    cleaned = cleaned.replaceAll(_roomNoise, '').replaceAll(_durationNoiseRegex, '');
    // Strip leading/trailing batch identifiers
    cleaned = cleaned.replaceAll(_batchPrefixRegex, '').replaceAll(_batchSuffixRegex, '');
    // Normalize spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    
    return cleaned.isEmpty ? raw.trim() : cleaned;
  }

  static String formatTeacherName(String name) {
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

    // Clean multiple consecutive spaces and preserve authentic timetable casing & initials exactly as in university source
    return raw.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
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
