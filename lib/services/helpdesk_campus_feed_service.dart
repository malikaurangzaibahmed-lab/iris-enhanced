import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

enum HelpdeskCampusFeedSource { live, cache, backup, none }

class CampusNotice {
  final String id;
  final String title;
  final String detail;
  final String createdBy;
  final DateTime? createdAt;

  const CampusNotice({
    required this.id,
    required this.title,
    required this.detail,
    required this.createdBy,
    required this.createdAt,
  });

  factory CampusNotice.fromJson(Map<String, dynamic> json) {
    return CampusNotice(
      id: (json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'detail': detail,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  String get searchable =>
      '${title.toLowerCase()} ${detail.toLowerCase()} ${createdBy.toLowerCase()}';
}

class CampusNoticePayload {
  final List<CampusNotice> items;
  final HelpdeskCampusFeedSource source;

  const CampusNoticePayload({required this.items, required this.source});
}

class HelpdeskCampusFeedService {
  // static const String _liveNoticesUrl = 'https://cui-helpdesk-backend.onrender.com/api/notices';
  static const String _cacheKey = 'helpdesk_notices_cache_v1';
  static const String _assetPath = 'assets/helpdesk_backup/helpdesk_snapshot.json';

  static List<CampusNotice> _memoryCache = const [];

  /// Returns a payload with items and source, for main.dart compatibility
  Future<CampusNoticePayload> fetchNoticesLiveFirstWithFallbackPayload() async {
    // No live fetch, just fallback to cache/asset for now
    final items = await fetchNoticesOfflineOnly();
    return CampusNoticePayload(items: items, source: items.isNotEmpty ? HelpdeskCampusFeedSource.cache : HelpdeskCampusFeedSource.none);
  }

  /// Returns only offline data (memory, cache, or asset)
  Future<List<CampusNotice>> fetchNoticesOfflineOnly() async {
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

  static List<CampusNotice> filterByKeywords(
    List<CampusNotice> items,
    List<String> keywords,
  ) {
    final lowered = keywords.map((e) => e.toLowerCase()).toList(growable: false);
    final matches = items.where((notice) {
      final haystack = notice.searchable;
      return lowered.any(haystack.contains);
    }).toList();
    matches.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return matches;
  }

  Future<void> _saveCache(List<CampusNotice> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = items.map((e) => e.toJson()).toList(growable: false);
    await prefs.setString(_cacheKey, jsonEncode(payload));
  }

  Future<List<CampusNotice>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CampusNotice.fromJson)
          .where((e) => e.title.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<CampusNotice>> _loadFromAsset() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final dynamic decoded = jsonDecode(raw);
      final data = (decoded is Map<String, dynamic>) ? decoded['data'] : null;
      final notices = (data is Map<String, dynamic>) ? data['notices'] : null;
      if (notices is! List) return const [];
      return notices
          .whereType<Map<String, dynamic>>()
          .map(CampusNotice.fromJson)
          .where((e) => e.title.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
