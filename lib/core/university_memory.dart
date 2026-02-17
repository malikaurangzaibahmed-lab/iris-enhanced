import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';
import '../services/timetable_storage.dart';

class UniversityMemoryLoader {
  static Future<UniversityMemory> loadFromAssets() async {
    final raw = await rootBundle.loadString('assets/timetable_seed.json');
    final data = jsonDecode(raw) as List<dynamic>;
    final sessions = data
      .whereType<Map<String, dynamic>>()
      .map((item) => ClassSession.fromJson(item))
      .toList();

    final merged = await TimetableStorage.mergeOverrides(sessions);
    return UniversityMemory(merged);
  }
}
