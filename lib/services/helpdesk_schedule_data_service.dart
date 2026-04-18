import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

enum CampusScheduleSource { asset, none }

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

  const SemesterMilestoneData({
    required this.title,
    required this.date,
    required this.status,
  });

  factory SemesterMilestoneData.fromJson(Map<String, dynamic> json) {
    return SemesterMilestoneData(
      title: (json['title'] ?? '').toString().trim(),
      date: (json['date'] ?? '').toString().trim(),
      status: (json['status'] ?? '').toString().trim(),
    );
  }
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

  Future<CampusSchedulePayload> fetchSchedulePayload() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _empty(CampusScheduleSource.none);
      }

      final transportRaw = decoded['transport_routes'] is List
          ? decoded['transport_routes'] as List
          : const [];
      final semesterRaw = decoded['semester_schedule'] is List
          ? decoded['semester_schedule'] as List
          : const [];
      final deadlinesRaw = decoded['deadlines'] is List
          ? decoded['deadlines'] as List
          : const [];
      final libraryRaw = decoded['library_schedule'] is Map<String, dynamic>
          ? decoded['library_schedule'] as Map<String, dynamic>
          : null;

      final payload = CampusSchedulePayload(
        source: CampusScheduleSource.asset,
        capturedAt: DateTime.tryParse((decoded['captured_at'] ?? '').toString()),
        transportRoutes: transportRaw
            .whereType<Map<String, dynamic>>()
            .map(TransportRouteData.fromJson)
            .where((route) => route.route.isNotEmpty)
            .toList(growable: false),
        semesterSchedule: semesterRaw
            .whereType<Map<String, dynamic>>()
            .map(SemesterMilestoneData.fromJson)
            .where((m) => m.title.isNotEmpty)
            .toList(growable: false),
        deadlines: deadlinesRaw
            .whereType<Map<String, dynamic>>()
            .map(DeadlineData.fromJson)
            .where((d) => d.title.isNotEmpty)
            .toList(growable: false),
        librarySchedule:
            libraryRaw == null ? null : LibraryScheduleData.fromJson(libraryRaw),
      );

      return payload;
    } catch (_) {
      return _empty(CampusScheduleSource.none);
    }
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
