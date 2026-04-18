import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import '../services/timetable_storage.dart';

class UniversityMemoryLoader {
  static Future<UniversityMemory> loadFromAssets() async {
    String raw;
    
    // Try to load cached OTA version first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedTimetable = prefs.getString('ota_cached_timetable');
      if (cachedTimetable != null && cachedTimetable.isNotEmpty) {
        print('✅ Loading cached timetable from OTA update');
        raw = cachedTimetable;
      } else {
        print('📚 Loading timetable from assets (no cache)');
        raw = await rootBundle.loadString('assets/timetable_seed.json');
      }
    } catch (e) {
      print('⚠️ Error loading cached timetable: $e - falling back to assets');
      raw = await rootBundle.loadString('assets/timetable_seed.json');
    }
    
    final data = jsonDecode(raw) as List<dynamic>;
    final sessions = data
      .whereType<Map<String, dynamic>>()
      .map((item) => ClassSession.fromJson(item))
      .toList();

    final merged = await TimetableStorage.mergeOverrides(sessions);
    return UniversityMemory(merged);
  }
}
