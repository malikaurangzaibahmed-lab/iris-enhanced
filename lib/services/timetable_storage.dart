import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:iris/core/models.dart';

class TimetableStorage {
  static const String _overrideFileName = 'timetable_override.json';

  static Future<File> _getOverrideFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_overrideFileName');
  }

  static Future<List<ClassSession>> loadOverrides() async {
    try {
      final file = await _getOverrideFile();
      if (!await file.exists()) {
        return [];
      }
      final raw = await file.readAsString();
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => ClassSession.fromJson(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveOverrides(List<ClassSession> sessions) async {
    final file = await _getOverrideFile();
    final payload = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await file.writeAsString(payload);
  }

  static Future<List<ClassSession>> mergeOverrides(
    List<ClassSession> seedSessions,
  ) async {
    final overrides = await loadOverrides();
    if (overrides.isEmpty) {
      return seedSessions;
    }

    final overrideBatches = overrides.map((s) => s.batchKey.batch).toSet();
    final merged = <ClassSession>[];

    for (final session in seedSessions) {
      if (!overrideBatches.contains(session.batchKey.batch)) {
        merged.add(session);
      }
    }

    merged.addAll(overrides);
    return merged;
  }

  static Future<void> applyBatchOverride({
    required UniversityMemory memory,
    required String batch,
    required List<ClassSession> newSessions,
  }) async {
    final existingOverrides = await loadOverrides();
    final updatedOverrides = <ClassSession>[]
      ..addAll(existingOverrides.where((s) => s.batchKey.batch != batch))
      ..addAll(newSessions);

    await saveOverrides(updatedOverrides);

    memory.sessions
      ..removeWhere((s) => s.batchKey.batch == batch)
      ..addAll(newSessions);
  }
}
