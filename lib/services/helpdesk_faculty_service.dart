import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

enum HelpdeskFacultySource { live, cache, backup, none }

class FacultyFetchPayload {
  final List<FacultyProfile> items;
  final HelpdeskFacultySource source;

  const FacultyFetchPayload({required this.items, required this.source});
}

class FacultyProfile {
  final String id;
  final String name;
  final String gender;
  final String department;
  final String location;
  final String email;
  final String contact;
  final String image;
  final DateTime? updatedAt;

  const FacultyProfile({
    required this.id,
    required this.name,
    required this.gender,
    required this.department,
    required this.location,
    required this.email,
    required this.contact,
    required this.image,
    this.updatedAt,
  });

  factory FacultyProfile.fromJson(Map<String, dynamic> json) {
    return FacultyProfile(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'gender': gender,
      'department': department,
      'location': location,
      'email': email,
      'contact': contact,
      'image': image,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  bool get hasImage => image.trim().isNotEmpty;
}


class HelpdeskFacultyService {
  // static const String _liveUrl = 'https://cui-helpdesk-backend.onrender.com/api/faculty';
  static const String _cacheKey = 'helpdesk_faculty_cache_v2';
  static const String _assetPath = 'assets/helpdesk_backup/helpdesk_snapshot.json';

  static List<FacultyProfile> _memoryCache = const [];

  static const Set<String> _honorificTokens = {
    'dr', 'mr', 'mrs', 'ms', 'miss', 'prof', 'professor', 'eng', 'engr', 'sir', 'madam', 'lecturer', 'asst', 'assistant',
  };

  static String normalizeFacultyName(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return cleaned;
    final tokens = cleaned
        .split(' ')
        .where((t) => t.isNotEmpty)
        .where((t) => !_honorificTokens.contains(t))
        .where((t) => t.length > 1)
        .toList();
    return tokens.join(' ').trim();
  }

  static String resolveTeacherImagePath(String teacherName) {
    if (teacherName.trim().isEmpty || _memoryCache.isEmpty) return '';
    final match = matchFacultyProfile(teacherName, _memoryCache);
    if (match != null && match.image.trim().isNotEmpty) {
      final raw = match.image.trim();
      if (raw.contains('uploads/')) {
        final filename = raw.split('/').last;
        return 'assets/faculty_images/$filename';
      }
      return raw;
    }
    return '';
  }

  static FacultyProfile? matchFacultyProfile(
    String teacherName,
    List<FacultyProfile> profiles,
  ) {
    if (profiles.isEmpty || teacherName.trim().isEmpty) return null;
    final query = normalizeFacultyName(teacherName);
    if (query.isEmpty) return null;

    FacultyProfile? best;
    var bestScore = -1.0;
    final queryTokens = query.split(' ').where((t) => t.isNotEmpty).toSet();
    for (final profile in profiles) {
      final candidate = normalizeFacultyName(profile.name);
      if (candidate.isEmpty) continue;
      if (candidate == query) return profile;
      if (candidate.contains(query) || query.contains(candidate)) {
        return profile;
      }
      final candidateTokens = candidate.split(' ').where((t) => t.isNotEmpty).toSet();
      if (candidateTokens.isEmpty) continue;
      final intersection = queryTokens.intersection(candidateTokens).length;
      if (intersection == 0) continue;
      final union = queryTokens.union(candidateTokens).length;
      final jaccard = union == 0 ? 0.0 : intersection / union;
      final coverage = intersection / queryTokens.length;
      final score = (jaccard * 0.65) + (coverage * 0.35);
      if (score > bestScore) {
        bestScore = score;
        best = profile;
      }
    }
    if (best != null && bestScore >= 0.45) return best;
    return null;
  }

  /// Returns a payload with items and source, for main.dart compatibility
  Future<FacultyFetchPayload> fetchLiveFirstWithFallbackPayload() async {
    // No live fetch, just fallback to cache/asset for now
    final items = await fetchOfflineOnly();
    return FacultyFetchPayload(items: items, source: items.isNotEmpty ? HelpdeskFacultySource.cache : HelpdeskFacultySource.none);
  }

  /// Returns only offline data (memory, cache, or asset)
  Future<List<FacultyProfile>> fetchOfflineOnly() async {
    if (_memoryCache.isNotEmpty) {
      return _memoryCache;
    }
    final cached = await _loadFromCache();
    if (cached.isNotEmpty) {
      _memoryCache = cached;
      return cached;
    }
    final backup = await _loadFromAsset();
    if (backup.isNotEmpty) {
      _memoryCache = backup;
      return backup;
    }
    return const [];
  }

  Future<void> _saveCache(List<FacultyProfile> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = items.map((e) => e.toJson()).toList(growable: false);
    await prefs.setString(_cacheKey, jsonEncode(payload));
  }

  Future<List<FacultyProfile>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(FacultyProfile.fromJson)
          .where((e) => e.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<FacultyProfile>> _loadFromAsset() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final dynamic decoded = jsonDecode(raw);
      final data = (decoded is Map<String, dynamic>) ? decoded['data'] : null;
      final faculty = (data is Map<String, dynamic>) ? data['faculty'] : null;
      if (faculty is! List) return const [];
      return faculty
          .whereType<Map<String, dynamic>>()
          .map(FacultyProfile.fromJson)
          .where((e) => e.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
