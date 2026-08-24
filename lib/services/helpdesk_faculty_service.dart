import 'dart:convert';
import 'dart:math' as math;

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
  final List<String> aliases;

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
    this.aliases = const [],
  });

  factory FacultyProfile.fromJson(Map<String, dynamic> json) {
    return FacultyProfile(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
      aliases: (json['aliases'] is List)
          ? (json['aliases'] as List).map((e) => e.toString()).toList()
          : const [],
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
      'aliases': aliases,
    };
  }

  FacultyProfile copyWith({
    String? id,
    String? name,
    String? gender,
    String? department,
    String? location,
    String? email,
    String? contact,
    String? image,
    DateTime? updatedAt,
    List<String>? aliases,
  }) {
    return FacultyProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      department: department ?? this.department,
      location: location ?? this.location,
      email: email ?? this.email,
      contact: contact ?? this.contact,
      image: image ?? this.image,
      updatedAt: updatedAt ?? this.updatedAt,
      aliases: aliases ?? this.aliases,
    );
  }

  bool get hasImage => image.trim().isNotEmpty;
}

class HelpdeskFacultyService {
  // static const String _liveUrl = 'https://cui-helpdesk-backend.onrender.com/api/faculty';
  static const String _cacheKey = 'helpdesk_faculty_cache_v2';
  static const String _assetPath = 'assets/helpdesk_backup/helpdesk_snapshot.json';

  static List<FacultyProfile> _memoryCache = const [];

  static const Set<String> _honorificTokens = {
    'dr',
    'mr',
    'mrs',
    'ms',
    'miss',
    'prof',
    'professor',
    'eng',
    'engr',
    'sir',
    'madam',
    'lecturer',
    'asst',
    'assistant',
    'ch',
    'chaudhry',
    'choudhry',
    'hafiz',
    'syed',
    'syeda',
    'molana',
    'maulana',
  };

  static const Map<String, String> _spellingEquivalents = {
    'kousar': 'kausar',
    'shehzad': 'shahzad',
    'mehmood': 'mahmood',
    'ameen': 'amin',
    'fayez': 'faiz',
    'mudassar': 'mudasar',
    'muzammil': 'muzamil',
    'sufiyan': 'sufyan',
    'marriam': 'mariam',
    'muhmmad': 'muhammad',
    'm': 'muhammad',
    'md': 'muhammad',
    'mohd': 'muhammad',
  };

  /// Extracts meaningful normalized tokens stripped of titles and spelling variations
  static List<String> extractCoreTokens(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return const [];
    final words = cleaned.split(' ');
    final result = <String>[];
    for (final w in words) {
      if (w.isEmpty || _honorificTokens.contains(w)) continue;
      final normalized = _spellingEquivalents[w] ?? w;
      if (normalized.isNotEmpty) {
        result.add(normalized);
      }
    }
    return result;
  }

  /// Normalizes a faculty name into a clean canonical search string
  static String normalizeFacultyName(String input) {
    final tokens = extractCoreTokens(input);
    return tokens.join(' ').trim();
  }

  /// Computes a fuzzy semantic similarity score between two faculty/teacher names [0.0 - 1.0]
  static double calculateSimilarity(String name1, String name2) {
    if (name1.trim().toLowerCase() == name2.trim().toLowerCase()) return 1.0;

    final t1 = extractCoreTokens(name1);
    final t2 = extractCoreTokens(name2);
    if (t1.isEmpty || t2.isEmpty) return 0.0;

    final k1 = t1.join(' ');
    final k2 = t2.join(' ');
    if (k1 == k2) return 1.0;

    final s1 = t1.toSet();
    final s2 = t2.toSet();
    final intersection = s1.intersection(s2);
    if (intersection.isEmpty) return 0.0;

    // Subset match (e.g. "Fayez Afzaal" in "Muhammad Fayez Afzaal")
    if (s1.containsAll(s2) || s2.containsAll(s1)) {
      if (intersection.length >= 2) {
        return 0.95;
      } else if (intersection.length == 1 && (s1.length == 1 || s2.length == 1)) {
        // Single unique token match (e.g. "Zunaira", "Saqlain", "Manzoor")
        return 0.72;
      }
    }

    final union = s1.union(s2);
    final jaccard = intersection.length / union.length;
    final minLen = math.min(s1.length, s2.length);
    final overlap = minLen == 0 ? 0.0 : intersection.length / minLen;

    return (jaccard * 0.4) + (overlap * 0.6);
  }

  /// Checks if two name variants belong to the same faculty member
  static bool isNameMatch(String name1, String name2, {double threshold = 0.70}) {
    if (name1.trim().toLowerCase() == name2.trim().toLowerCase()) return true;
    return calculateSimilarity(name1, name2) >= threshold;
  }

  /// Finds the best matching FacultyProfile from a list of profiles
  static FacultyProfile? matchFacultyProfile(
    String teacherName,
    List<FacultyProfile> profiles, {
    double threshold = 0.65,
  }) {
    if (profiles.isEmpty || teacherName.trim().isEmpty) return null;

    final lowerClean = teacherName.trim().toLowerCase();

    // 1. Direct exact name or alias check
    for (final profile in profiles) {
      if (profile.name.trim().toLowerCase() == lowerClean) return profile;
      for (final alias in profile.aliases) {
        if (alias.trim().toLowerCase() == lowerClean) return profile;
      }
    }

    // 2. High-precision fuzzy similarity check
    FacultyProfile? bestProfile;
    var bestScore = -1.0;

    for (final profile in profiles) {
      var score = calculateSimilarity(teacherName, profile.name);
      for (final alias in profile.aliases) {
        final aliasScore = calculateSimilarity(teacherName, alias);
        if (aliasScore > score) score = aliasScore;
      }

      if (score > bestScore) {
        bestScore = score;
        bestProfile = profile;
      }
    }

    if (bestProfile != null && bestScore >= threshold) {
      return bestProfile;
    }
    return null;
  }

  /// Resolves the local or remote asset image path for any teacher name
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
  /// Deduplicates faculty profiles by canonical normalized name, preserving the richest profile data
  static List<FacultyProfile> deduplicateProfiles(List<FacultyProfile> items) {
    if (items.isEmpty) return const [];
    final map = <String, FacultyProfile>{};

    for (final item in items) {
      final key = normalizeFacultyName(item.name);
      if (key.isEmpty) continue;

      if (!map.containsKey(key)) {
        map[key] = item;
      } else {
        final existing = map[key]!;
        final existingScore = (existing.hasImage ? 4 : 0) +
            (existing.email.isNotEmpty ? 2 : 0) +
            (existing.contact.isNotEmpty ? 1 : 0);
        final itemScore = (item.hasImage ? 4 : 0) +
            (item.email.isNotEmpty ? 2 : 0) +
            (item.contact.isNotEmpty ? 1 : 0);

        final mergedAliases = {...existing.aliases, ...item.aliases, existing.name, item.name}.toList();
        if (itemScore > existingScore) {
          map[key] = item.copyWith(aliases: mergedAliases);
        } else {
          map[key] = existing.copyWith(aliases: mergedAliases);
        }
      }
    }
    return map.values.toList();
  }

  /// Seamlessly merges Timetable teachers with Helpdesk snapshot without duplicate fragmentation
  static List<FacultyProfile> mergeWithTimetableTeachers({
    required List<FacultyProfile> helpdeskProfiles,
    required Iterable<String> timetableTeachers,
  }) {
    final cleanHelpdesk = deduplicateProfiles(helpdeskProfiles);
    final result = List<FacultyProfile>.from(cleanHelpdesk);
    final profileAliases = <String, Set<String>>{};
    for (final p in result) {
      profileAliases[p.id] = p.aliases.toSet();
    }

    for (final rawTeacher in timetableTeachers) {
      final clean = rawTeacher.trim();
      if (clean.isEmpty || clean.toLowerCase() == 'unknown') continue;

      // Check if already matches any existing profile in result
      FacultyProfile? bestProfile;
      double bestScore = 0.0;

      for (final profile in result) {
        if (profile.name.toLowerCase() == clean.toLowerCase() ||
            profileAliases[profile.id]!.contains(clean.toLowerCase())) {
          bestProfile = profile;
          bestScore = 1.0;
          break;
        }

        final score = calculateSimilarity(clean, profile.name);
        if (score > bestScore) {
          bestScore = score;
          bestProfile = profile;
        }
      }

      if (bestProfile != null && bestScore >= 0.70) {
        // Associate alias to the existing rich profile
        profileAliases[bestProfile.id]!.add(clean);
      } else {
        // Truly unique teacher not in Helpdesk snapshot (e.g. visiting or new faculty)
        final newProfile = FacultyProfile(
          id: 'pdf_${clean.hashCode}',
          name: clean,
          gender: 'N/A',
          department: 'Academic Faculty',
          location: 'COMSATS Campus',
          contact: 'Campus Office',
          email: '',
          image: '',
          aliases: [clean],
        );
        result.add(newProfile);
        profileAliases[newProfile.id] = {clean};
      }
    }

    // Return with aliases populated
    return result.map((p) {
      final currentAliases = profileAliases[p.id] ?? const {};
      if (currentAliases.isEmpty) return p;
      return p.copyWith(aliases: currentAliases.toList());
    }).toList();
  }

  /// Returns a payload with items and source, for main.dart compatibility
  Future<FacultyFetchPayload> fetchLiveFirstWithFallbackPayload() async {
    final items = await fetchOfflineOnly();
    return FacultyFetchPayload(
      items: items,
      source: items.isNotEmpty ? HelpdeskFacultySource.cache : HelpdeskFacultySource.none,
    );
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
      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(FacultyProfile.fromJson)
          .where((e) => e.name.trim().isNotEmpty)
          .toList();
      return deduplicateProfiles(items);
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
      final items = faculty
          .whereType<Map<String, dynamic>>()
          .map(FacultyProfile.fromJson)
          .where((e) => e.name.trim().isNotEmpty)
          .toList();
      return deduplicateProfiles(items);
    } catch (_) {
      return const [];
    }
  }
}
