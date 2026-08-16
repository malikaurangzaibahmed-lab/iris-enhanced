import 'models.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/remote_config_service.dart';

// ============ LECTURE DURATION HELPER ============
/// Helper function to detect 1-hour lecture subjects (e.g. Lab theories, seminars)
bool isOneHourLecture(String subject) {
  return subject.toLowerCase().contains('(1 hr)') ||
         subject.toLowerCase().contains('(1hr)') ||
         subject.toLowerCase().contains('1 hr)');
}

double _getActualEndTime(ClassSession session) {
  return session.actualEndVal;
}

class TemporalInsight {
  final String headline;
  final String subline;
  final bool isLive;
  final String? timeInfo; // E.g., "45 mins left", "Starting in 5 mins"
  final String? teacherInfo; // E.g., "Dr. Ahmed Khan"
  final bool isUrgent; // True if class starts within 5 mins
  final String? subject;
  final String? room;
  final String? startTime;

  const TemporalInsight({
    required this.headline,
    required this.subline,
    required this.isLive,
    this.timeInfo,
    this.teacherInfo,
    this.isUrgent = false,
    this.subject,
    this.room,
    this.startTime,
  });
}

/// A single schedule entry for the teacher locator
class TeacherScheduleEntry {
  final int dayIndex;
  final String startTime;
  final String endTime;
  final String subject;
  final String room;
  final String batch;
  final bool isLive;
  final bool isUpcoming; // today but hasn't started

  const TeacherScheduleEntry({
    required this.dayIndex,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.room,
    required this.batch,
    this.isLive = false,
    this.isUpcoming = false,
  });

  static const List<String> dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  String get dayName => dayIndex >= 1 && dayIndex <= 7 ? dayNames[dayIndex - 1] : 'Day $dayIndex';
}

/// Rich result from the teacher locator
class TeacherLocatorResult {
  final String teacherName;
  final String status; // 'live', 'today', 'scheduled', 'not_found'
  final String statusText;
  final TeacherScheduleEntry? liveSession;
  final List<TeacherScheduleEntry> todaySessions;
  final Map<int, List<TeacherScheduleEntry>> weeklySchedule; // dayIndex -> sessions
  final List<String> allRooms;
  final List<String> allSubjects;

  const TeacherLocatorResult({
    required this.teacherName,
    required this.status,
    required this.statusText,
    this.liveSession,
    this.todaySessions = const [],
    this.weeklySchedule = const {},
    this.allRooms = const [],
    this.allSubjects = const [],
  });
}

/// Represents a free time slot
class FreeSlot {
  final int dayIndex;
  final double startTime;
  final double endTime;

  FreeSlot({
    required this.dayIndex,
    required this.startTime,
    required this.endTime,
  });

  String get dayName {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return dayIndex >= 1 && dayIndex <= 7 ? days[dayIndex - 1] : 'Day $dayIndex';
  }

  String timeRangeString(BuildContext? context) {
    final startHour = startTime.toInt();
    final startMin = ((startTime - startHour) * 60).toInt();
    final endHour = endTime.toInt();
    final endMin = ((endTime - endHour) * 60).toInt();
    return '${startHour.toString().padLeft(2, '0')}:${startMin.toString().padLeft(2, '0')} - ${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
  }
}

/// Makeup class suggestion with available rooms
class MakeupSlotSuggestion {
  final int dayIndex;
  final double startTime;
  final double endTime;
  final double durationHours;
  final List<String>? availableRooms;

  MakeupSlotSuggestion({
    required this.dayIndex,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    this.availableRooms,
  });

  String get dayName {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return dayIndex >= 1 && dayIndex <= 7 ? days[dayIndex - 1] : 'Day $dayIndex';
  }

  String timeRangeString() {
    return '${_format12Hour(startTime)} - ${_format12Hour(endTime)}';
  }

  String _format12Hour(double time) {
    final hour24 = time.floor().clamp(0, 23);
    final min = ((time - time.floor()) * 60).round().clamp(0, 59);
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour12:${min.toString().padLeft(2, '0')} $period';
  }
}

class BatchVitalMetrics {
  final double dayProgress;
  final int completedClasses;
  final int totalClassesToday;
  final int remainingClasses;
  final double attendanceHealth;

  const BatchVitalMetrics({
    required this.dayProgress,
    required this.completedClasses,
    required this.totalClassesToday,
    required this.remainingClasses,
    required this.attendanceHealth,
  });
}

class OmniBrain {
  final UniversityMemory memory;

  OmniBrain(this.memory);

  List<ClassSession> scheduleFor(String batch, {String? overridePeriod}) {
    return memory.byBatch(overridePeriod: overridePeriod)[batch] ?? [];
  }

  List<ClassSession> scheduleForTeacher(String teacherName, {String? overridePeriod}) {
    final name = teacherName.trim().toLowerCase();
    return memory.activeSessions(overridePeriod: overridePeriod)
        .where((s) => s.teacher.trim().toLowerCase() == name)
        .toList();
  }

  // Get merged lecture sessions (consecutive slots of same lecture)
  List<ClassSession> getMergedConsecutiveSessions(List<ClassSession> schedule) {
    if (schedule.isEmpty) return [];
    
    final sorted = List<ClassSession>.from(schedule)
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    
    final merged = <ClassSession>[];
    ClassSession? current;
    
    for (final session in sorted) {
      if (current == null) {
        current = session;
        continue;
      }
      
      // Check if this session is consecutive with current
      if (current.isConsecutiveWith(session)) {
        // Merge: create new session with extended end time
        current = ClassSession(
          id: current.id,
          batchKey: current.batchKey,
          dayIndex: current.dayIndex,
          startTime: current.startTime,
          endTime: session.endTime, // Extend to this session's end
          subject: current.subject,
          teacher: current.teacher,
          room: current.room,
        );
      } else {
        merged.add(current);
        current = session;
      }
    }
    
    if (current != null) {
      merged.add(current);
    }
    
    return merged;
  }

  BatchVitalMetrics getVitalMetrics(String batch, DateTime now) {
    final schedule = scheduleFor(batch);
    final today = schedule.where((s) => s.dayIndex == now.weekday).toList();
    final currentT = now.hour + (now.minute / 60.0);

    if (today.isEmpty) {
      return const BatchVitalMetrics(
        dayProgress: 0.0,
        completedClasses: 0,
        totalClassesToday: 0,
        remainingClasses: 0,
        attendanceHealth: 1.0,
      );
    }

    final mergedToday = getMergedConsecutiveSessions(today);
    final completed = mergedToday.where((s) => _getActualEndTime(s) <= currentT).length;
    final total = mergedToday.length;
    final remaining = mergedToday.where((s) => s.safeStartVal > currentT).length;
    
    // Day progress based on completed classes vs total
    final dayProgress = total > 0 ? completed / total : 0.0;
    
    // Simulated attendance health for now (ideally from a service)
    final attendanceHealth = 0.85 + (math.Random(now.day).nextDouble() * 0.12);

    return BatchVitalMetrics(
      dayProgress: dayProgress,
      completedClasses: completed,
      totalClassesToday: total,
      remainingClasses: remaining,
      attendanceHealth: attendanceHealth,
    );
  }

  // Find all consecutive sessions for a given session
  ClassSession getMergedSession(ClassSession session, List<ClassSession> allSessions) {
    final sameDaySessions = allSessions
        .where((s) => s.dayIndex == session.dayIndex && s.isSameLectureAs(session))
        .toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    
    if (sameDaySessions.isEmpty) return session;
    
    final blocks = <List<ClassSession>>[];
    var currentBlock = <ClassSession>[];
    
    for (final s in sameDaySessions) {
      if (currentBlock.isEmpty) {
        currentBlock.add(s);
      } else {
        final last = currentBlock.last;
        if ((s.safeStartVal - last.actualEndVal).abs() < 0.01) {
          currentBlock.add(s);
        } else {
          blocks.add(currentBlock);
          currentBlock = [s];
        }
      }
    }
    if (currentBlock.isNotEmpty) {
      blocks.add(currentBlock);
    }
    
    for (final block in blocks) {
      final containsSession = block.any((s) => s.id == session.id || 
          (s.safeStartVal == session.safeStartVal && s.safeEndVal == session.safeEndVal));
      if (containsSession) {
        return ClassSession(
          id: block.first.id,
          batchKey: block.first.batchKey,
          dayIndex: block.first.dayIndex,
          startTime: block.first.startTime,
          endTime: block.last.endTime,
          subject: block.first.subject,
          teacher: block.first.teacher,
          room: block.first.room,
        );
      }
    }
    
    return session;
  }

  ClassSession? getCurrentClass(String batch, DateTime now) {
    final currentT = now.hour + (now.minute / 60.0);
    final schedule = scheduleFor(batch);
    
    for (final s in schedule) {
      final actualEnd = _getActualEndTime(s);
      if (s.dayIndex == now.weekday && currentT >= s.safeStartVal && currentT < actualEnd) {
        // Return merged session to handle consecutive slots
        return getMergedSession(s, schedule);
      }
    }
    return null;
  }

  ClassSession? getNextClass(String batch, DateTime now) {
    final currentT = now.hour + (now.minute / 60.0);
    final schedule = scheduleFor(batch);

    final today = schedule
        .where((s) => s.dayIndex == now.weekday && s.safeStartVal > currentT)
        .toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    if (today.isNotEmpty) {
      // Return merged session to handle consecutive slots
      return getMergedSession(today.first, schedule);
    }

    for (int daysAhead = 1; daysAhead <= 6; daysAhead++) {
      final nextDay = ((now.weekday + daysAhead - 1) % 7) + 1;
      final candidates = schedule.where((s) => s.dayIndex == nextDay).toList()
        ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      if (candidates.isNotEmpty) {
        // Return merged session to handle consecutive slots
        return getMergedSession(candidates.first, schedule);
      }
    }

    return null;
  }

  ClassSession? getCurrentClassForTeacher(String teacherName, DateTime now) {
    final currentT = now.hour + (now.minute / 60.0);
    final schedule = scheduleForTeacher(teacherName);

    for (final s in schedule) {
      final actualEnd = _getActualEndTime(s);
      if (s.dayIndex == now.weekday && currentT >= s.safeStartVal && currentT < actualEnd) {
        return getMergedSession(s, schedule);
      }
    }
    return null;
  }

  ClassSession? getNextClassForTeacher(String teacherName, DateTime now) {
    final currentT = now.hour + (now.minute / 60.0);
    final schedule = scheduleForTeacher(teacherName);

    final today = schedule
        .where((s) => s.dayIndex == now.weekday && s.safeStartVal > currentT)
        .toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    if (today.isNotEmpty) {
      return getMergedSession(today.first, schedule);
    }

    for (int daysAhead = 1; daysAhead <= 6; daysAhead++) {
      final nextDay = ((now.weekday + daysAhead - 1) % 7) + 1;
      final candidates = schedule.where((s) => s.dayIndex == nextDay).toList()
        ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      if (candidates.isNotEmpty) {
        return getMergedSession(candidates.first, schedule);
      }
    }

    return null;
  }

  List<String> findEmptyRooms(DateTime now) {
    final rooms = <String>{};
    for (final session in memory.activeSessions()) {
      rooms.add(session.room);
    }

    final occupied = <String>{};
    final currentT = now.hour + (now.minute / 60.0);
    for (final session in memory.activeSessions()) {
      final actualEnd = _getActualEndTime(session);
      if (session.dayIndex == now.weekday && currentT >= session.safeStartVal && currentT < actualEnd) {
        occupied.add(session.room);
      }
    }

    final available = rooms.difference(occupied).toList()..sort();
    return available;
  }

  /// Find empty rooms for a specific time slot (used for makeup scheduling)
  List<String> findEmptyRoomsForSlot(int dayIndex, double startTime, double endTime) {
    // Get all unique rooms
    final allRooms = <String>{};
    for (final session in memory.activeSessions()) {
      if (session.room.isNotEmpty && session.room.toLowerCase() != 'unknown') {
        allRooms.add(session.room);
      }
    }

    // Find occupied rooms during this slot
    final occupied = <String>{};
    for (final session in memory.activeSessions()) {
      if (session.dayIndex == dayIndex) {
        // Check if there's any overlap
        final sessionEnd = session.safeEndVal;
        final sessionStart = session.safeStartVal;
        
        // Overlap if: session starts before slot ends AND session ends after slot starts
        if (sessionStart < endTime && sessionEnd > startTime) {
          occupied.add(session.room);
        }
      }
    }

    // Return available rooms, sorted
    final available = allRooms.difference(occupied).toList()..sort();
    return available;
  }

  /// Get all unique teacher names from the registry
  List<String> allTeachers() {
    final names = <String>{};
    for (final session in memory.activeSessions()) {
      if (session.teacher.isNotEmpty && session.teacher != 'Unknown') {
        names.add(session.teacher);
      }
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  /// Smart fuzzy-ish search: matches if all search words appear in the name
  bool _matchesTeacher(String teacherName, String search) {
    final name = teacherName.toLowerCase().replaceAll('.', ' ');
    final cleanSearch = search.toLowerCase().replaceAll('.', ' ');
    final words = cleanSearch.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    // All words must appear in the name
    return words.every((w) => name.contains(w));
  }

  /// Locate a teacher with full weekly schedule and smart status
  TeacherLocatorResult locateTeacher(String query, DateTime now) {
    final search = query.toLowerCase().trim();
    if (search.isEmpty) {
      return const TeacherLocatorResult(
        teacherName: '',
        status: 'empty',
        statusText: 'Enter a teacher name',
      );
    }

    final weekday = now.weekday;
    final currentT = now.hour + (now.minute / 60.0);

    // Gather ALL sessions for matching teachers
    final matchedSessions = <ClassSession>[];
    String? resolvedName;

    for (final session in memory.activeSessions()) {
      if (_matchesTeacher(session.teacher, search)) {
        matchedSessions.add(session);
        // Keep the most common full name
        resolvedName ??= session.teacher;
      }
    }

    if (matchedSessions.isEmpty) {
      return TeacherLocatorResult(
        teacherName: query,
        status: 'not_found',
        statusText: 'No match found in registry',
      );
    }

    // Resolve the most common name variant
    final nameFreq = <String, int>{};
    for (final s in matchedSessions) {
      nameFreq[s.teacher] = (nameFreq[s.teacher] ?? 0) + 1;
    }
    resolvedName = nameFreq.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    // Build weekly schedule
    final weeklySchedule = <int, List<TeacherScheduleEntry>>{};
    final allRooms = <String>{};
    final allSubjects = <String>{};
    TeacherScheduleEntry? liveSession;
    final todaySessions = <TeacherScheduleEntry>[];

    for (final session in matchedSessions) {
      allRooms.add(session.room);
      allSubjects.add(session.subject);

      final isLive = session.dayIndex == weekday &&
          currentT >= session.safeStartVal &&
          currentT < _getActualEndTime(session);
      final isUpcoming = session.dayIndex == weekday &&
          session.safeStartVal > currentT;

      final entry = TeacherScheduleEntry(
        dayIndex: session.dayIndex,
        startTime: session.startTime,
        endTime: session.endTime,
        subject: session.subject,
        room: session.room,
        batch: session.batchKey.batch,
        isLive: isLive,
        isUpcoming: isUpcoming,
      );

      weeklySchedule.putIfAbsent(session.dayIndex, () => []).add(entry);

      if (isLive) liveSession = entry;
      if (session.dayIndex == weekday) todaySessions.add(entry);
    }

    // Sort each day's sessions by start time
    for (final entries in weeklySchedule.values) {
      entries.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    todaySessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Determine status
    String status;
    String statusText;

    if (liveSession != null) {
      status = 'live';
      statusText = 'Live now in ${liveSession.room} — ${liveSession.subject}';
    } else if (todaySessions.any((s) => s.isUpcoming)) {
      status = 'today';
      final next = todaySessions.firstWhere((s) => s.isUpcoming);
      statusText = 'Next at ${next.startTime} in ${next.room} — ${next.subject}';
    } else if (todaySessions.isNotEmpty) {
      status = 'today';
      statusText = 'Done for today (${todaySessions.length} classes completed)';
    } else {
      // Find next day they teach
      status = 'scheduled';
      int? nextDay;
      for (int offset = 1; offset <= 7; offset++) {
        final day = ((weekday - 1 + offset) % 7) + 1;
        if (weeklySchedule.containsKey(day)) {
          nextDay = day;
          break;
        }
      }
      if (nextDay != null) {
        final nextEntries = weeklySchedule[nextDay]!;
        statusText = 'Next on ${TeacherScheduleEntry.dayNames[nextDay - 1]} at ${nextEntries.first.startTime}';
      } else {
        statusText = 'Schedule available';
      }
    }

    return TeacherLocatorResult(
      teacherName: resolvedName,
      status: status,
      statusText: statusText,
      liveSession: liveSession,
      todaySessions: todaySessions,
      weeklySchedule: weeklySchedule,
      allRooms: allRooms.toList()..sort(),
      allSubjects: allSubjects.toList()..sort(),
    );
  }

  TemporalInsight buildTemporalInsight(String batch, DateTime now) {
    final current = getCurrentClass(batch, now);
    final next = getNextClass(batch, now);
    final currentT = now.hour + (now.minute / 60.0);
    final schedule = scheduleFor(batch);
    final today = schedule
        .where((s) => s.dayIndex == now.weekday)
        .toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    final period = RemoteConfigService.activeAcademicPeriod.value;
    final isExam = period == 'midterms' || period == 'finals';

    if (current != null) {
      final actualEndTime = _getActualEndTime(current);
      final minutesLeft = ((actualEndTime - currentT) * 60).round();
      final timeLeft = minutesLeft > 60 
          ? '${(minutesLeft / 60).floor()}h ${minutesLeft % 60}m left'
          : '$minutesLeft mins left';
      
      final headlineText = isExam
          ? (period == 'midterms' ? 'Live Midterm' : 'Live Final Exam')
          : (period == 'sports_week' ? 'Gala Event Live' : 'Live Now');
      
      final roomPrefix = isExam ? 'Hall: ' : '';
      
      return TemporalInsight(
        headline: headlineText,
        subline: '${current.subject} · $roomPrefix${current.room}',
        timeInfo: timeLeft,
        teacherInfo: current.teacher,
        isLive: true,
        isUrgent: false,
        subject: current.subject,
        room: current.room,
        startTime: current.startTime,
      );
    }

    if (today.isNotEmpty) {
      final previous = today.lastWhere(
        (s) => _getActualEndTime(s) <= currentT,
        orElse: () => today.first,
      );
      final upcoming = today.firstWhere(
        (s) => s.safeStartVal > currentT,
        orElse: () => today.first,
      );
      if (_getActualEndTime(previous) <= currentT && upcoming.safeStartVal > currentT) {
        // Get merged version of upcoming class for accurate time display
        final mergedUpcoming = getMergedSession(upcoming, schedule);
        
        // Break time calculations
        final breakMinutes = ((mergedUpcoming.safeStartVal - currentT) * 60).round();
        final breakDuration = breakMinutes > 60 
            ? '${(breakMinutes / 60).floor()}h ${breakMinutes % 60}m break'
            : '$breakMinutes min break';
        
        return TemporalInsight(
          headline: 'Break',
          subline: '${mergedUpcoming.subject} at ${mergedUpcoming.startTime} · ${mergedUpcoming.room}',
          timeInfo: breakDuration,
          teacherInfo: mergedUpcoming.teacher,
          isLive: false,
          subject: mergedUpcoming.subject,
          room: mergedUpcoming.room,
          startTime: mergedUpcoming.startTime,
        );
      }
    }

    if (next != null) {
      final dayDiff = (next.dayIndex - now.weekday) % 7;
      final earlyMorning = now.hour < 8 && dayDiff == 0;
      final label = earlyMorning ? 'Early Morning' : (dayDiff == 0 ? 'Next Up' : 'Next Day');
      
      // Check if starting soon (within 5 minutes for today's classes)
      final isStartingSoon = dayDiff == 0 && now.hour + (now.minute / 60.0) >= (next.safeStartVal - 0.084); // 0.084 = 5 mins
      
      String timeInfo = '';
      if (dayDiff == 0) {
        // Same day class
        final nextMinutes = ((next.safeStartVal - now.hour - (now.minute / 60.0)) * 60).round();
        if (nextMinutes > 0) {
          timeInfo = nextMinutes > 60 
              ? 'in ${(nextMinutes / 60).floor()}h ${nextMinutes % 60}m'
              : 'in $nextMinutes mins';
        }
      } else if (dayDiff > 0) {
        // Next day class - calculate time until class
        final daysUntil = dayDiff == 1 ? 1 : dayDiff;
        final hoursUntilMidnight = 24 - now.hour;
        final minutesUntilMidnight = 60 - now.minute;
        final totalMinutesUntilMidnight = (hoursUntilMidnight * 60) + minutesUntilMidnight - 60;
        
        // Add time from midnight to class start
        final classStartMinutes = (next.safeStartVal * 60).round();
        final totalMinutes = totalMinutesUntilMidnight + classStartMinutes + ((daysUntil - 1) * 24 * 60);
        
        final hours = totalMinutes ~/ 60;
        final mins = totalMinutes % 60;
        
        if (hours > 24) {
          final days = hours ~/ 24;
          final remainingHours = hours % 24;
          timeInfo = remainingHours > 0 
              ? 'in ${days}d ${remainingHours}h'
              : 'in ${days}d';
        } else if (hours > 0) {
          timeInfo = mins > 0 
              ? 'in ${hours}h ${mins}m'
              : 'in ${hours}h';
        } else {
          timeInfo = 'in ${mins}m';
        }
      }
      
      return TemporalInsight(
        headline: label,
        subline: '${next.subject} at ${next.startTime} · ${next.room}',
        timeInfo: timeInfo,
        teacherInfo: next.teacher,
        isLive: false,
        isUrgent: isStartingSoon,
        subject: next.subject,
        room: next.room,
        startTime: next.startTime,
      );
    }

    return const TemporalInsight(
      headline: 'No Classes',
      subline: 'Enjoy the free time',
      isLive: false,
      subject: 'No Classes',
      room: '',
      startTime: '',
    );
  }

  TemporalInsight buildTeacherTemporalInsight(String teacherName, DateTime now) {
    final current = getCurrentClassForTeacher(teacherName, now);
    final next = getNextClassForTeacher(teacherName, now);
    final currentT = now.hour + (now.minute / 60.0);
    final schedule = scheduleForTeacher(teacherName);
    final today = schedule
        .where((s) => s.dayIndex == now.weekday)
        .toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    final period = RemoteConfigService.activeAcademicPeriod.value;
    final isExam = period == 'midterms' || period == 'finals';

    if (current != null) {
      final actualEndTime = _getActualEndTime(current);
      final minutesLeft = ((actualEndTime - currentT) * 60).round();
      final timeLeft = minutesLeft > 60
          ? '${(minutesLeft / 60).floor()}h ${minutesLeft % 60}m left'
          : '$minutesLeft mins left';

      final headlineText = isExam
          ? 'Invigilating Now'
          : (period == 'sports_week' ? 'Gala Event Duty' : 'Teaching Now');
      final roomPrefix = isExam ? 'Supervision Hall: ' : '';

      return TemporalInsight(
        headline: headlineText,
        subline: '${current.subject} · $roomPrefix${current.room}',
        timeInfo: timeLeft,
        teacherInfo: teacherName,
        isLive: true,
        isUrgent: false,
      );
    }

    if (today.isNotEmpty) {
      final hasCompletedClass = today.any((s) => _getActualEndTime(s) <= currentT);
      final upcoming = today.firstWhere(
        (s) => s.safeStartVal > currentT,
        orElse: () => today.first,
      );
      if (hasCompletedClass && upcoming.safeStartVal > currentT) {
        final mergedUpcoming = getMergedSession(upcoming, schedule);
        final breakMinutes = ((mergedUpcoming.safeStartVal - currentT) * 60).round();
        final breakDuration = breakMinutes > 60
            ? '${(breakMinutes / 60).floor()}h ${breakMinutes % 60}m break'
            : '$breakMinutes min break';

        return TemporalInsight(
          headline: 'Break',
          subline: '${mergedUpcoming.subject} at ${mergedUpcoming.startTime} · ${mergedUpcoming.room}',
          timeInfo: breakDuration,
          teacherInfo: teacherName,
          isLive: false,
        );
      }
    }

    if (next != null) {
      final dayDiff = (next.dayIndex - now.weekday) % 7;
      final label = dayDiff == 0 ? 'Next Up' : 'Next Day';
      final isStartingSoon = dayDiff == 0 &&
          now.hour + (now.minute / 60.0) >= (next.safeStartVal - 0.084);

      String timeInfo = '';
      if (dayDiff == 0) {
        final nextMinutes = ((next.safeStartVal - now.hour - (now.minute / 60.0)) * 60).round();
        if (nextMinutes > 0) {
          timeInfo = nextMinutes > 60
              ? 'in ${(nextMinutes / 60).floor()}h ${nextMinutes % 60}m'
              : 'in $nextMinutes mins';
        }
      } else if (dayDiff > 0) {
        final daysUntil = dayDiff == 1 ? 1 : dayDiff;
        final hoursUntilMidnight = 24 - now.hour;
        final minutesUntilMidnight = 60 - now.minute;
        final totalMinutesUntilMidnight = (hoursUntilMidnight * 60) + minutesUntilMidnight - 60;
        final classStartMinutes = (next.safeStartVal * 60).round();
        final totalMinutes = totalMinutesUntilMidnight + classStartMinutes + ((daysUntil - 1) * 24 * 60);
        final hours = totalMinutes ~/ 60;
        final mins = totalMinutes % 60;
        if (hours > 24) {
          final days = hours ~/ 24;
          final remainingHours = hours % 24;
          timeInfo = remainingHours > 0
              ? 'in ${days}d ${remainingHours}h'
              : 'in ${days}d';
        } else if (hours > 0) {
          timeInfo = mins > 0 ? 'in ${hours}h ${mins}m' : 'in ${hours}h';
        } else {
          timeInfo = 'in ${mins}m';
        }
      }

      return TemporalInsight(
        headline: label,
        subline: '${next.subject} at ${next.startTime} · ${next.room}',
        timeInfo: timeInfo,
        teacherInfo: teacherName,
        isLive: false,
        isUrgent: isStartingSoon,
      );
    }

    return TemporalInsight(
      headline: 'No Classes',
      subline: 'No schedule for $teacherName',
      isLive: false,
    );
  }

  /// Get actual operating hours from timetable (earliest start and latest end)
  /// Returns a map of dayIndex -> (minTime, maxTime)
  Map<int, (double, double)> _getOperatingHours() {
    final operatingHours = <int, (double, double)>{};
    
    for (final session in memory.activeSessions()) {
      final day = session.dayIndex;
      final start = session.safeStartVal;
      final end = session.safeEndVal;
      
      if (operatingHours.containsKey(day)) {
        final current = operatingHours[day]!;
        operatingHours[day] = (
          start < current.$1 ? start : current.$1,  // min
          end > current.$2 ? end : current.$2,      // max
        );
      } else {
        operatingHours[day] = (start, end);
      }
    }
    
    return operatingHours;
  }

  /// Find free slots for a batch across a week
  /// Returns list of {day, start_time, end_time} when the batch has no classes
  List<FreeSlot> findFreeSlotsForBatch(String batch) {
    final schedule = scheduleFor(batch);
    if (schedule.isEmpty) return [];

    final freeSlots = <FreeSlot>[];
    final daySlots = <int, List<ClassSession>>{};
    final operatingHours = _getOperatingHours();

    // Group by day
    for (final session in schedule) {
      daySlots.putIfAbsent(session.dayIndex, () => []).add(session);
    }

    // For each weekday (1-7)
    for (int dayIndex = 1; dayIndex <= 7; dayIndex++) {
      // Skip days when university doesn't operate
      if (!operatingHours.containsKey(dayIndex)) continue;
      
      final (dayStart, dayEnd) = operatingHours[dayIndex]!;
      final daySessions = daySlots[dayIndex] ?? [];
      
      if (daySessions.isEmpty) {
        // Batch has no classes but university operates - entire day is free
        freeSlots.add(FreeSlot(
          dayIndex: dayIndex,
          startTime: dayStart,
          endTime: dayEnd,
        ));
        continue;
      }

      // Sort by start time
      daySessions.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

      // Check before first class (only if within operating hours)
      if (daySessions.first.safeStartVal > dayStart) {
        freeSlots.add(FreeSlot(
          dayIndex: dayIndex,
          startTime: dayStart,
          endTime: daySessions.first.safeStartVal,
        ));
      }

      // Check between consecutive classes
      for (int i = 0; i < daySessions.length - 1; i++) {
        final endTime = daySessions[i].safeEndVal;
        final nextStartTime = daySessions[i + 1].safeStartVal;
        if (endTime < nextStartTime) {
          freeSlots.add(FreeSlot(
            dayIndex: dayIndex,
            startTime: endTime,
            endTime: nextStartTime,
          ));
        }
      }

      // Check after last class (only if within operating hours)
      if (daySessions.last.safeEndVal < dayEnd) {
        freeSlots.add(FreeSlot(
          dayIndex: dayIndex,
          startTime: daySessions.last.safeEndVal,
          endTime: dayEnd,
        ));
      }
    }

    return freeSlots;
  }

  /// Find free slots for a teacher across a week
  List<FreeSlot> findFreeSlotsForTeacher(String teacherName) {
    final schedule = scheduleForTeacher(teacherName);
    if (schedule.isEmpty) return [];

    final freeSlots = <FreeSlot>[];
    final daySlots = <int, List<ClassSession>>{};
    final operatingHours = _getOperatingHours();

    // Group by day
    for (final session in schedule) {
      daySlots.putIfAbsent(session.dayIndex, () => []).add(session);
    }

    // For each weekday (1-7)
    for (int dayIndex = 1; dayIndex <= 7; dayIndex++) {
      // Skip days when university doesn't operate
      if (!operatingHours.containsKey(dayIndex)) continue;
      
      final (dayStart, dayEnd) = operatingHours[dayIndex]!;
      final daySessions = daySlots[dayIndex] ?? [];
      
      if (daySessions.isEmpty) {
        // Teacher has no classes but university operates - entire day is free
        freeSlots.add(FreeSlot(
          dayIndex: dayIndex,
          startTime: dayStart,
          endTime: dayEnd,
        ));
        continue;
      }

      daySessions.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

      if (daySessions.first.safeStartVal > dayStart) {
        freeSlots.add(FreeSlot(
          dayIndex: dayIndex,
          startTime: dayStart,
          endTime: daySessions.first.safeStartVal,
        ));
      }

      for (int i = 0; i < daySessions.length - 1; i++) {
        final endTime = daySessions[i].safeEndVal;
        final nextStartTime = daySessions[i + 1].safeStartVal;
        if (endTime < nextStartTime) {
          freeSlots.add(FreeSlot(
            dayIndex: dayIndex,
            startTime: endTime,
            endTime: nextStartTime,
          ));
        }
      }

      if (daySessions.last.safeEndVal < dayEnd) {
        freeSlots.add(FreeSlot(
          dayIndex: dayIndex,
          startTime: daySessions.last.safeEndVal,
          endTime: dayEnd,
        ));
      }
    }

    return freeSlots;
  }

  /// Find common free slots between batch and teacher
  /// Returns list of slots where BOTH are free, with available rooms
  List<MakeupSlotSuggestion> findMakeupSlots(String batch, String teacherName) {
    final batchSlots = findFreeSlotsForBatch(batch);
    final teacherSlots = findFreeSlotsForTeacher(teacherName);

    if (batchSlots.isEmpty || teacherSlots.isEmpty) return [];

    final suggestions = <MakeupSlotSuggestion>[];

    // Find intersections
    for (final bSlot in batchSlots) {
      for (final tSlot in teacherSlots) {
        // Same day
        if (bSlot.dayIndex == tSlot.dayIndex) {
          // Check overlap
          final overlapStart = bSlot.startTime > tSlot.startTime
              ? bSlot.startTime
              : tSlot.startTime;
          final overlapEnd =
              bSlot.endTime < tSlot.endTime ? bSlot.endTime : tSlot.endTime;

          if (overlapStart < overlapEnd) {
            final duration = overlapEnd - overlapStart;
            
            // Split long free periods into reasonable 1-hour makeup slots
            // Typical makeup class should be 1-1.5 hours, not 4+ hours
            if (duration <= 1.5) {
              // Short period - use as is
              final availableRooms = findEmptyRoomsForSlot(
                bSlot.dayIndex,
                overlapStart,
                overlapEnd,
              );
              
              suggestions.add(MakeupSlotSuggestion(
                dayIndex: bSlot.dayIndex,
                startTime: overlapStart,
                endTime: overlapEnd,
                durationHours: duration,
                availableRooms: availableRooms,
              ));
            } else {
              // Long period - split into 1-hour slots
              double currentStart = overlapStart;
              while (currentStart + 1.0 <= overlapEnd) {
                final slotEnd = currentStart + 1.0;
                
                final availableRooms = findEmptyRoomsForSlot(
                  bSlot.dayIndex,
                  currentStart,
                  slotEnd,
                );
                
                suggestions.add(MakeupSlotSuggestion(
                  dayIndex: bSlot.dayIndex,
                  startTime: currentStart,
                  endTime: slotEnd,
                  durationHours: 1.0,
                  availableRooms: availableRooms,
                ));
                
                currentStart += 1.0;
              }
              
              // Add remaining time if >= 30 minutes (0.5 hours)
              final remaining = overlapEnd - currentStart;
              if (remaining >= 0.5) {
                final availableRooms = findEmptyRoomsForSlot(
                  bSlot.dayIndex,
                  currentStart,
                  overlapEnd,
                );
                
                suggestions.add(MakeupSlotSuggestion(
                  dayIndex: bSlot.dayIndex,
                  startTime: currentStart,
                  endTime: overlapEnd,
                  durationHours: remaining,
                  availableRooms: availableRooms,
                ));
              }
            }
          }
        }
      }
    }

    return suggestions;
  }

  GpaPlannerResult calculateRequiredSemesterGpa({
    required double currentCgpa,
    required double targetCgpa,
    required int completedCredits,
    required int semesterCredits,
  }) {
    if (semesterCredits <= 0) {
      return const GpaPlannerResult(
        requiredSemesterGpa: 0.0,
        maxPossibleCgpa: 0.0,
        difficulty: 'moderate',
        message: 'No active courses detected to perform calculation.',
      );
    }

    final totalCredits = completedCredits + semesterCredits;
    final requiredGpa = ((targetCgpa * totalCredits) - (currentCgpa * completedCredits)) / semesterCredits;
    final maxCgpa = ((currentCgpa * completedCredits) + (4.0 * semesterCredits)) / totalCredits;

    if (requiredGpa <= 2.0) {
      return GpaPlannerResult(
        requiredSemesterGpa: requiredGpa.clamp(0.0, 4.0),
        maxPossibleCgpa: maxCgpa,
        difficulty: 'easy',
        message: 'Comfortable target! You need an average GPA of ${requiredGpa.clamp(0.0, 4.0).toStringAsFixed(2)} to hit your target.',
      );
    } else if (requiredGpa > 4.00) {
      return GpaPlannerResult(
        requiredSemesterGpa: requiredGpa,
        maxPossibleCgpa: maxCgpa,
        difficulty: 'impossible',
        message: 'Target out of reach this semester. The highest CGPA you can achieve is ${maxCgpa.toStringAsFixed(2)} (with a perfect 4.00 GPA).',
      );
    } else {
      final difficulty = requiredGpa > 3.5 ? 'challenging' : 'moderate';
      final status = requiredGpa > 3.5 ? 'Challenging' : 'Achievable';
      return GpaPlannerResult(
        requiredSemesterGpa: requiredGpa,
        maxPossibleCgpa: maxCgpa,
        difficulty: difficulty,
        message: '$status target! You need a GPA of ${requiredGpa.toStringAsFixed(2)} in your current courses.',
      );
    }
  }
}

class GpaPlannerResult {
  final double requiredSemesterGpa;
  final double maxPossibleCgpa;
  final String difficulty; // 'easy', 'moderate', 'challenging', 'impossible'
  final String message;

  const GpaPlannerResult({
    required this.requiredSemesterGpa,
    required this.maxPossibleCgpa,
    required this.difficulty,
    required this.message,
  });
}
