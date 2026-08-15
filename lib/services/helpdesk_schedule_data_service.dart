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

class SemesterMilestoneData {
  final String title;
  final String date;
  final String status;
  final String category;

  const SemesterMilestoneData({
    required this.title,
    required this.date,
    required this.status,
    this.category = 'General',
  });

  factory SemesterMilestoneData.fromJson(Map<String, dynamic> json) {
    return SemesterMilestoneData(
      title: (json['title'] ?? '').toString().trim(),
      date: (json['date'] ?? '').toString().trim(),
      status: (json['status'] ?? '').toString().trim(),
      category: (json['category'] ?? 'General').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'date': date,
    'status': status,
    'category': category,
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
