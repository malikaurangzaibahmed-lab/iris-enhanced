import 'core/format_guard.dart';

class FormatGuardValidator {
  static bool isValidTime(String raw) {
    final parts = raw.trim().split(RegExp(r'[:.]'));
    if (parts.length != 2) return false;
    final hour = int.tryParse(parts[0]) ?? -1;
    final minute = int.tryParse(parts[1]) ?? -1;
    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  static String normalizeRoom(String raw) {
    return FormatGuard.sanitizeRoom(raw);
  }
}
