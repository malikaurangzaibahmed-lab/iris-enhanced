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
}
