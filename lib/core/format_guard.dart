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

  static String formatTeacherName(String name) {
    var raw = name.trim();
    if (raw.isEmpty || raw.toLowerCase() == 'unknown' || raw.toLowerCase() == 'tbd') {
      return raw.isEmpty ? 'Unknown' : raw;
    }

    // 1. Separate common titles/prefixes
    final prefixRegex = RegExp(
      r'^\s*(dr|prof|engr|mr|ms|mrs|sir|mam|lecturer)\b\.?\s*',
      caseSensitive: false,
    );
    
    String? foundPrefix;
    final prefixMatch = prefixRegex.firstMatch(raw);
    if (prefixMatch != null) {
      final matchedText = prefixMatch.group(1)!.toLowerCase();
      // Normalize prefix casing and append dot
      switch (matchedText) {
        case 'dr':
          foundPrefix = 'Dr.';
          break;
        case 'prof':
          foundPrefix = 'Prof.';
          break;
        case 'engr':
          foundPrefix = 'Engr.';
          break;
        case 'mr':
          foundPrefix = 'Mr.';
          break;
        case 'ms':
          foundPrefix = 'Ms.';
          break;
        case 'mrs':
          foundPrefix = 'Mrs.';
          break;
        case 'sir':
          foundPrefix = 'Sir';
          break;
        case 'mam':
          foundPrefix = 'Mam';
          break;
        case 'lecturer':
          foundPrefix = 'Lecturer';
          break;
        default:
          foundPrefix = matchedText[0].toUpperCase() + matchedText.substring(1) + '.';
      }
      raw = raw.substring(prefixMatch.end).trim();
    }

    // 2. Title Case the remaining parts and sanitize double spaces
    final words = raw.split(RegExp(r'\s+'));
    final formattedWords = <String>[];

    for (var word in words) {
      if (word.isEmpty) continue;
      
      // Clean dots if they are initials
      final cleanWord = word.replaceAll('.', '');
      
      if (cleanWord.length == 1) {
        // It's a single letter initial - make it uppercase with a dot
        formattedWords.add('${cleanWord.toUpperCase()}.');
      } else {
        // Normal word - title case it
        final titleCased = cleanWord[0].toUpperCase() + cleanWord.substring(1).toLowerCase();
        formattedWords.add(titleCased);
      }
    }

    // Combine words
    var processedName = formattedWords.join(' ');
    
    // Clean up initials spaces: e.g. "M.Hassan" -> "M. Hassan" or "H. M.Hassan" -> "H. M. Hassan"
    // Also "H.M." -> "H. M."
    processedName = processedName.replaceAllMapped(RegExp(r'\b([A-Z])\.\s*([A-Z])\.?'), (match) {
      return '${match.group(1)}. ${match.group(2)}.';
    });
    
    // Ensure single initials followed by word have space: "M.Hassan" -> "M. Hassan"
    processedName = processedName.replaceAllMapped(RegExp(r'\b([A-Z])\.(?=[A-Za-z]{2,})'), (match) {
      return '${match.group(1)}. ';
    });

    // Merge duplicate dots if any and remove extra spaces
    processedName = processedName.replaceAll(RegExp(r'\.+'), '.').replaceAll(RegExp(r'\s+'), ' ').trim();

    if (foundPrefix != null) {
      return '$foundPrefix $processedName';
    }
    return processedName;
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
