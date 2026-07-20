import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import '../services/timetable_storage.dart';
import '../services/remote_config_service.dart';

class UniversityMemoryLoader {
  static Future<UniversityMemory> loadFromAssets() async {
    String raw = '';
    bool loadedFromCache = false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cache Reset on App Upgrade: clear old cached timetable when build version bumps
      final lastRunVersion = prefs.getInt('last_run_version_code') ?? 0;
      const currentVersion = RemoteConfigService.CURRENT_VERSION_CODE;
      if (lastRunVersion != currentVersion) {
        debugPrint('ℹ️ App upgraded from build $lastRunVersion to $currentVersion. Resetting timetable cache.');
        await prefs.remove('ota_cached_timetable');
        await prefs.remove('ota_timetable_version');
        await prefs.setInt('last_run_version_code', currentVersion);
      }

      final cachedTimetable = prefs.getString('ota_cached_timetable');
      if (cachedTimetable != null && cachedTimetable.isNotEmpty) {
        debugPrint('✅ Loading cached timetable from OTA update');
        raw = cachedTimetable;
        loadedFromCache = true;
      }
    } catch (e) {
      debugPrint('⚠️ Error checking cached timetable: $e');
    }
    
    List<dynamic> data = [];
    if (loadedFromCache) {
      try {
        data = await compute(_decodeTimetableJson, raw);
      } catch (e) {
        debugPrint('⚠️ Error parsing cached timetable: $e - falling back to assets');
        loadedFromCache = false;
      }
    }
    
    if (!loadedFromCache || data.isEmpty) {
      debugPrint('📚 Loading timetable from assets');
      try {
        raw = await rootBundle.loadString('assets/timetable_seed.json');
        data = await compute(_decodeTimetableJson, raw);
      } catch (e) {
        debugPrint('❌ Critical error loading timetable assets: $e');
      }
    }
    
    var sessions = data
      .whereType<Map<String, dynamic>>()
      .map((item) => ClassSession.fromJson(item))
      .toList();

    // Check if the loaded cached timetable has sessions for the user's selected batch
    bool hasUserBatch = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userBatch = prefs.getString('user_batch')?.trim();
      if (userBatch != null && userBatch.isNotEmpty) {
        hasUserBatch = sessions.any((s) => s.batchKey.batch == userBatch);
      } else {
        hasUserBatch = true; // Setup onboarding will handle it
      }
    } catch (_) {
      hasUserBatch = true;
    }

    // Secondary fallback: if parsed cache is empty or does not contain sessions for the user's batch, load assets
    if (loadedFromCache && (sessions.isEmpty || !hasUserBatch)) {
      debugPrint('⚠️ Parsed OTA timetable is empty or has no sessions for user batch - falling back to assets');
      try {
        raw = await rootBundle.loadString('assets/timetable_seed.json');
        data = await compute(_decodeTimetableJson, raw);
        sessions = data
          .whereType<Map<String, dynamic>>()
          .map((item) => ClassSession.fromJson(item))
          .toList();
      } catch (e) {
        debugPrint('❌ Critical error loading timetable assets: $e');
      }
    }

    final merged = await TimetableStorage.mergeOverrides(sessions);
    return UniversityMemory(merged);
  }
}

List<Map<String, dynamic>> _decodeTimetableJson(String raw) {
  final decoded = jsonDecode(raw);
  final list = <Map<String, dynamic>>[];
  if (decoded is List) {
    for (final item in decoded) {
      if (item is Map) {
        list.add(Map<String, dynamic>.from(item));
      }
    }
  } else if (decoded is Map && decoded['sessions'] is List) {
    for (final item in decoded['sessions']) {
      if (item is Map) {
        list.add(Map<String, dynamic>.from(item));
      }
    }
  }
  return list;
}
