import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CampusScheduleSource { live, asset, cached, none }

class TransportStopData {
  final String point;
  final String time;

  const TransportStopData({required this.point, required this.time});

  factory TransportStopData.fromJson(Map<String, dynamic> json) {
    return TransportStopData(
      point: (json['point'] ?? '').toString().trim(),
      time: (json['time'] ?? '').toString().trim(),
    );
  }
}

class TransportRouteData {
  final String route;
  final String driverName;
  final String driverPhone;
  final String helperName;
  final String helperPhone;
  final List<TransportStopData> stops;

  const TransportRouteData({
    required this.route,
    required this.driverName,
    required this.driverPhone,
    required this.helperName,
    required this.helperPhone,
    required this.stops,
  });

  factory TransportRouteData.fromJson(Map<String, dynamic> json) {
    final driverMap = json['driver'] is Map<String, dynamic>
        ? json['driver'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final helperMap = json['helper'] is Map<String, dynamic>
        ? json['helper'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawStops = json['stops'] is List ? json['stops'] as List : const [];

    final parsedStops = rawStops
        .whereType<Map<String, dynamic>>()
        .map(TransportStopData.fromJson)
        .where((s) => s.point.isNotEmpty || s.time.isNotEmpty)
        .toList(growable: false);

    return TransportRouteData(
      route: (json['route'] ?? '').toString().trim(),
      driverName: (driverMap['name'] ?? '').toString().trim(),
      driverPhone: (driverMap['phone'] ?? '').toString().trim(),
      helperName: (helperMap['name'] ?? '').toString().trim(),
      helperPhone: (helperMap['phone'] ?? '').toString().trim(),
      stops: parsedStops,
    );
  }
}

class SemesterMilestoneEvaluator {
  static const Map<String, int> _monthMap = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Parses date range from strings like:
  /// "Aug 31 – Sep 4, 2026 (Mon–Fri)"
  /// "Sep 7, 2026 (Mon)"
  /// "Nov 9–14, 2026 (Mon–Sat)"
  /// "2026-09-07"
  /// "2026-08-31 to 2026-09-04"
  static ({DateTime? start, DateTime? end}) parseDateRange(String dateStr, [DateTime? referenceNow]) {
    final now = referenceNow ?? DateTime.now();
    final clean = dateStr.replaceAll('–', '-').replaceAll('—', '-').trim();
    if (clean.isEmpty) return (start: null, end: null);

    // 1. ISO date range: YYYY-MM-DD to YYYY-MM-DD
    final isoRange = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})\s*(?:to|-)\s*(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(clean);
    if (isoRange != null) {
      final s = DateTime(int.parse(isoRange.group(1)!), int.parse(isoRange.group(2)!), int.parse(isoRange.group(3)!));
      final e = DateTime(int.parse(isoRange.group(4)!), int.parse(isoRange.group(5)!), int.parse(isoRange.group(6)!), 23, 59, 59);
      return (start: s, end: e);
    }

    // 2. Single ISO date: YYYY-MM-DD
    final isoSingle = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(clean);
    if (isoSingle != null) {
      final s = DateTime(int.parse(isoSingle.group(1)!), int.parse(isoSingle.group(2)!), int.parse(isoSingle.group(3)!));
      final e = DateTime(s.year, s.month, s.day, 23, 59, 59);
      return (start: s, end: e);
    }

    // 3. Multi-month range: Aug 31 - Sep 4, 2026
    final multiMonth = RegExp(r'([A-Za-z]{3,9})\s+(\d{1,2})\s*-\s*([A-Za-z]{3,9})\s+(\d{1,2})(?:[,\s]+(\d{4}))?').firstMatch(clean);
    if (multiMonth != null) {
      final m1Name = multiMonth.group(1)!.substring(0, 3).toLowerCase();
      final d1 = int.parse(multiMonth.group(2)!);
      final m2Name = multiMonth.group(3)!.substring(0, 3).toLowerCase();
      final d2 = int.parse(multiMonth.group(4)!);
      final year = multiMonth.group(5) != null ? int.parse(multiMonth.group(5)!) : now.year;
      if (_monthMap.containsKey(m1Name) && _monthMap.containsKey(m2Name)) {
        final m1 = _monthMap[m1Name]!;
        final m2 = _monthMap[m2Name]!;
        final y2 = m2 < m1 ? year + 1 : year;
        final s = DateTime(year, m1, d1);
        final e = DateTime(y2, m2, d2, 23, 59, 59);
        return (start: s, end: e);
      }
    }

    // 4. Same-month range: Nov 9-14, 2026
    final sameMonth = RegExp(r'([A-Za-z]{3,9})\s+(\d{1,2})\s*-\s*(\d{1,2})(?:[,\s]+(\d{4}))?').firstMatch(clean);
    if (sameMonth != null) {
      final mName = sameMonth.group(1)!.substring(0, 3).toLowerCase();
      final d1 = int.parse(sameMonth.group(2)!);
      final d2 = int.parse(sameMonth.group(3)!);
      final year = sameMonth.group(4) != null ? int.parse(sameMonth.group(4)!) : now.year;
      if (_monthMap.containsKey(mName)) {
        final m = _monthMap[mName]!;
        final s = DateTime(year, m, d1);
        final e = DateTime(year, m, d2, 23, 59, 59);
        return (start: s, end: e);
      }
    }

    // 5. Single month date: Sep 7, 2026 (Mon)
    final singleMonth = RegExp(r'([A-Za-z]{3,9})\s+(\d{1,2})(?:[,\s]+(\d{4}))?').firstMatch(clean);
    if (singleMonth != null) {
      final mName = singleMonth.group(1)!.substring(0, 3).toLowerCase();
      final d = int.parse(singleMonth.group(2)!);
      final year = singleMonth.group(3) != null ? int.parse(singleMonth.group(3)!) : now.year;
      if (_monthMap.containsKey(mName)) {
        final m = _monthMap[mName]!;
        final s = DateTime(year, m, d);
        final e = DateTime(year, m, d, 23, 59, 59);
        return (start: s, end: e);
      }
    }

    return (start: null, end: null);
  }

  /// Evaluates whether a milestone is 'completed', 'active', or 'upcoming' based on current date.
  static String evaluateStatus(String dateStr, {String? explicitStatus, DateTime? referenceNow}) {
    if (explicitStatus == 'expired' || explicitStatus == 'completed') return 'completed';
    final now = referenceNow ?? DateTime.now();
    final range = parseDateRange(dateStr, now);
    if (range.start == null || range.end == null) {
      return explicitStatus?.isNotEmpty == true ? explicitStatus! : 'upcoming';
    }

    final todayStart = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(range.end!.year, range.end!.month, range.end!.day, 23, 59, 59);
    final startDay = DateTime(range.start!.year, range.start!.month, range.start!.day);

    if (now.isAfter(endDay)) {
      return 'completed';
    } else if (!todayStart.isBefore(startDay) && !todayStart.isAfter(endDay)) {
      return 'active';
    } else {
      return 'upcoming';
    }
  }

  static bool isCompleted(String dateStr, {String? explicitStatus, bool? isDoneExplicit, DateTime? referenceNow}) {
    if (isDoneExplicit == true) return true;
    return evaluateStatus(dateStr, explicitStatus: explicitStatus, referenceNow: referenceNow) == 'completed';
  }
}

class SemesterMilestoneData {
  final String title;
  final String date;
  final String status;
  final String category;
  final String level;

  const SemesterMilestoneData({
    required this.title,
    required this.date,
    required this.status,
    this.category = 'General',
    this.level = '',
  });

  /// Real-time dynamically calculated status ('completed', 'active', or 'upcoming')
  String get dynamicStatus => SemesterMilestoneEvaluator.evaluateStatus(date, explicitStatus: status);

  /// True if the milestone date has passed or is explicitly completed
  bool get isDone => SemesterMilestoneEvaluator.isCompleted(date, explicitStatus: status);

  factory SemesterMilestoneData.fromJson(Map<String, dynamic> json) {
    return SemesterMilestoneData(
      title: (json['title'] ?? '').toString().trim(),
      date: (json['date'] ?? '').toString().trim(),
      status: (json['status'] ?? '').toString().trim(),
      category: (json['category'] ?? 'General').toString().trim(),
      level: (json['level'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'date': date,
    'status': status,
    'category': category,
    'level': level,
  };
}

class DeadlineData {
  final String title;
  final String date;
  final String status;

  const DeadlineData({
    required this.title,
    required this.date,
    required this.status,
  });

  factory DeadlineData.fromJson(Map<String, dynamic> json) {
    return DeadlineData(
      title: (json['title'] ?? '').toString().trim(),
      date: (json['date'] ?? '').toString().trim(),
      status: (json['status'] ?? '').toString().trim(),
    );
  }
}

class LibraryScheduleData {
  final String open;
  final String breakTime;
  final String close;

  const LibraryScheduleData({
    required this.open,
    required this.breakTime,
    required this.close,
  });

  factory LibraryScheduleData.fromJson(Map<String, dynamic> json) {
    return LibraryScheduleData(
      open: (json['open'] ?? '').toString().trim(),
      breakTime: (json['break'] ?? '').toString().trim(),
      close: (json['close'] ?? '').toString().trim(),
    );
  }
}

class CampusSchedulePayload {
  final CampusScheduleSource source;
  final DateTime? capturedAt;
  final List<TransportRouteData> transportRoutes;
  final List<SemesterMilestoneData> semesterSchedule;
  final List<DeadlineData> deadlines;
  final LibraryScheduleData? librarySchedule;

  const CampusSchedulePayload({
    required this.source,
    required this.capturedAt,
    required this.transportRoutes,
    required this.semesterSchedule,
    required this.deadlines,
    required this.librarySchedule,
  });
}

class HelpdeskScheduleDataService {
  static const String _assetPath =
      'assets/helpdesk_backup/helpdesk_schedule_seed.json';
  static const String _prefCachedScheduleKey = 'cached_firestore_semester_schedule';

  Future<CampusSchedulePayload> fetchSchedulePayload() async {
    CampusScheduleSource scheduleSource = CampusScheduleSource.asset;
    List<SemesterMilestoneData> resolvedSemesterMilestones = [];
    DateTime? capturedTime;

    // 1. First, attempt live fetch from Firestore Admin Portal schedule
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('global')
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final rawSchedule = data['semester_schedule'];
        if (rawSchedule is List && rawSchedule.isNotEmpty) {
          resolvedSemesterMilestones = rawSchedule
              .where((item) => item is Map)
              .map((item) => SemesterMilestoneData.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .where((m) => m.title.isNotEmpty)
              .toList(growable: false);

          if (resolvedSemesterMilestones.isNotEmpty) {
            scheduleSource = CampusScheduleSource.live;
            final rawTime = data['semester_schedule_updated_at'] ??
                data['active_semester_version'] ??
                data['updated_at'];
            if (rawTime is Timestamp) {
              capturedTime = rawTime.toDate();
            } else if (rawTime is int) {
              capturedTime = DateTime.fromMillisecondsSinceEpoch(rawTime);
            } else if (rawTime is String) {
              capturedTime = DateTime.tryParse(rawTime);
            }
            // Cache to local storage for instant offline access
            _cacheRemoteSchedule(rawSchedule);
          }
        }
      }

      // Fallback check on dedicated 'semester_schedule' document if global was empty
      if (resolvedSemesterMilestones.isEmpty) {
        final scheduleDoc = await FirebaseFirestore.instance
            .collection('config')
            .doc('semester_schedule')
            .get()
            .timeout(const Duration(seconds: 4));

        if (scheduleDoc.exists && scheduleDoc.data() != null) {
          final sData = scheduleDoc.data()!;
          final milestonesRaw = sData['milestones'] ?? sData['semester_schedule'];
          if (milestonesRaw is List && milestonesRaw.isNotEmpty) {
            resolvedSemesterMilestones = milestonesRaw
                .where((item) => item is Map)
                .map((item) => SemesterMilestoneData.fromJson(
                    Map<String, dynamic>.from(item as Map)))
                .where((m) => m.title.isNotEmpty)
                .toList(growable: false);

            if (resolvedSemesterMilestones.isNotEmpty) {
              scheduleSource = CampusScheduleSource.live;
              final rawTime = sData['updated_at'] ?? sData['version'];
              if (rawTime is Timestamp) {
                capturedTime = rawTime.toDate();
              } else if (rawTime is int) {
                capturedTime = DateTime.fromMillisecondsSinceEpoch(rawTime);
              }
              _cacheRemoteSchedule(milestonesRaw);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ℹ️ Live semester schedule query failed (offline or timeout): $e');
    }

    // 2. If live query was unavailable, check SharedPreferences cache
    if (resolvedSemesterMilestones.isEmpty) {
      final cached = await _getCachedRemoteSchedule();
      if (cached.isNotEmpty) {
        resolvedSemesterMilestones = cached;
        scheduleSource = CampusScheduleSource.cached;
      }
    }

    // 3. Load base asset seed (for Transport Routes & Library schedules)
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _empty(scheduleSource);
      }

      final transportRaw = decoded['transport_routes'] is List
          ? decoded['transport_routes'] as List
          : const [];
      final deadlinesRaw = decoded['deadlines'] is List
          ? decoded['deadlines'] as List
          : const [];
      final libraryRaw = decoded['library_schedule'] is Map<String, dynamic>
          ? decoded['library_schedule'] as Map<String, dynamic>
          : null;

      // If no live or cached semester milestones found, fall back to asset seed
      if (resolvedSemesterMilestones.isEmpty) {
        final semesterRaw = decoded['semester_schedule'] is List
            ? decoded['semester_schedule'] as List
            : const [];

        resolvedSemesterMilestones = semesterRaw
            .where((item) => item is Map)
            .map((item) => SemesterMilestoneData.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .where((m) => m.title.isNotEmpty)
            .toList(growable: false);
        scheduleSource = CampusScheduleSource.asset;
      }

      return CampusSchedulePayload(
        source: scheduleSource,
        capturedAt: capturedTime ??
            DateTime.tryParse((decoded['captured_at'] ?? '').toString()),
        transportRoutes: transportRaw
            .where((item) => item is Map)
            .map((item) => TransportRouteData.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .where((route) => route.route.isNotEmpty)
            .toList(growable: false),
        semesterSchedule: resolvedSemesterMilestones,
        deadlines: deadlinesRaw
            .where((item) => item is Map)
            .map((item) =>
                DeadlineData.fromJson(Map<String, dynamic>.from(item as Map)))
            .where((d) => d.title.isNotEmpty)
            .toList(growable: false),
        librarySchedule: libraryRaw == null
            ? null
            : LibraryScheduleData.fromJson(libraryRaw),
      );
    } catch (_) {
      return _empty(CampusScheduleSource.none);
    }
  }

  Future<void> _cacheRemoteSchedule(List rawSchedule) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCachedScheduleKey, jsonEncode(rawSchedule));
    } catch (_) {}
  }

  Future<List<SemesterMilestoneData>> _getCachedRemoteSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCachedScheduleKey);
      if (raw != null && raw.isNotEmpty) {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .where((item) => item is Map)
              .map((item) => SemesterMilestoneData.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .where((m) => m.title.isNotEmpty)
              .toList(growable: false);
        }
      }
    } catch (_) {}
    return const [];
  }

  CampusSchedulePayload _empty(CampusScheduleSource source) {
    return CampusSchedulePayload(
      source: source,
      capturedAt: null,
      transportRoutes: const [],
      semesterSchedule: const [],
      deadlines: const [],
      librarySchedule: null,
    );
  }
}
