import 'models.dart';
import 'format_guard.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/remote_config_service.dart';
import '../services/helpdesk_faculty_service.dart';

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
  final DateTime? specificDate;

  const TeacherScheduleEntry({
    required this.dayIndex,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.room,
    required this.batch,
    this.isLive = false,
    this.isUpcoming = false,
    this.specificDate,
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
  final String? slotName;
  final List<String>? availableRooms;

  MakeupSlotSuggestion({
    required this.dayIndex,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    this.slotName,
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
    final index = memory.byTeacher(overridePeriod: overridePeriod);
    final direct = index[name];
    if (direct != null && direct.isNotEmpty) return direct;

    // Smart Canonical Fuzzy fallback
    var bestScore = 0.0;
    List<ClassSession>? bestList;
    for (final entry in index.entries) {
      final score = HelpdeskFacultyService.calculateSimilarity(entry.key, name);
      if (score >= 0.65 && score > bestScore) {
        bestScore = score;
        bestList = entry.value;
      }
    }
    return bestList ?? [];
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
      if (s.specificDate != null) {
        final isSameDate = s.specificDate!.year == now.year &&
            s.specificDate!.month == now.month &&
            s.specificDate!.day == now.day;
        if (!isSameDate) continue;
      }
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
        .where((s) {
          if (s.specificDate != null) {
            final isSameDate = s.specificDate!.year == now.year &&
                s.specificDate!.month == now.month &&
                s.specificDate!.day == now.day;
            if (!isSameDate) return false;
          }
          return s.dayIndex == now.weekday && s.safeStartVal > currentT;
        })
        .toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    if (today.isNotEmpty) {
      // Return merged session to handle consecutive slots
      return getMergedSession(today.first, schedule);
    }

    for (int daysAhead = 1; daysAhead <= 6; daysAhead++) {
      final nextDay = ((now.weekday + daysAhead - 1) % 7) + 1;
      final targetDate = now.add(Duration(days: daysAhead));
      final candidates = schedule.where((s) {
        if (s.specificDate != null) {
          final isSameDate = s.specificDate!.year == targetDate.year &&
              s.specificDate!.month == targetDate.month &&
              s.specificDate!.day == targetDate.day;
          if (!isSameDate) return false;
        }
        return s.dayIndex == nextDay;
      }).toList()
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
      if (s.specificDate != null) {
        final isSameDate = s.specificDate!.year == now.year &&
            s.specificDate!.month == now.month &&
            s.specificDate!.day == now.day;
        if (!isSameDate) continue;
      }
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
        .where((s) {
          if (s.specificDate != null) {
            final isSameDate = s.specificDate!.year == now.year &&
                s.specificDate!.month == now.month &&
                s.specificDate!.day == now.day;
            if (!isSameDate) return false;
          }
          return s.dayIndex == now.weekday && s.safeStartVal > currentT;
        })
        .toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    if (today.isNotEmpty) {
      return getMergedSession(today.first, schedule);
    }

    for (int daysAhead = 1; daysAhead <= 6; daysAhead++) {
      final nextDay = ((now.weekday + daysAhead - 1) % 7) + 1;
      final targetDate = now.add(Duration(days: daysAhead));
      final candidates = schedule.where((s) {
        if (s.specificDate != null) {
          final isSameDate = s.specificDate!.year == targetDate.year &&
              s.specificDate!.month == targetDate.month &&
              s.specificDate!.day == targetDate.day;
          if (!isSameDate) return false;
        }
        return s.dayIndex == nextDay;
      }).toList()
        ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      if (candidates.isNotEmpty) {
        return getMergedSession(candidates.first, schedule);
      }
    }

    return null;
  }

  List<String> findEmptyRooms(DateTime now) {
    final allRoomsList = memory.allRooms();
    final occupied = <String>{};
    final currentT = now.hour + (now.minute / 60.0);
    for (final session in memory.activeSessions()) {
      if (session.specificDate != null) {
        final isSameDate = session.specificDate!.year == now.year &&
            session.specificDate!.month == now.month &&
            session.specificDate!.day == now.day;
        if (!isSameDate) continue;
      }
      if (session.dayIndex == now.weekday && currentT >= session.safeStartVal && currentT < _getActualEndTime(session)) {
        occupied.add(session.room);
      }
    }

    final available = allRoomsList.where((r) => !occupied.contains(r)).toList()..sort();
    return available;
  }

  /// Find empty rooms for a specific time slot (used for makeup scheduling)
  List<String> findEmptyRoomsForSlot(int dayIndex, double startTime, double endTime) {
    final allRoomsList = memory.allRooms();
    final occupied = <String>{};
    for (final session in memory.activeSessions()) {
      if (session.dayIndex == dayIndex) {
        if (session.safeStartVal < endTime && session.safeEndVal > startTime) {
          occupied.add(session.room);
        }
      }
    }

    final available = allRoomsList.where((r) => !occupied.contains(r)).toList()..sort();
    return available;
  }

  /// Get all unique teacher names from the registry
  List<String> allTeachers() {
    return memory.allTeachers();
  }

  /// Smart fuzzy-ish search: matches exact, normalized, or subset tokens
  bool _matchesTeacher(String teacherName, String search) {
    if (teacherName.trim().isEmpty || search.trim().isEmpty) return false;
    final name = teacherName.toLowerCase().replaceAll('.', ' ').trim();
    final cleanSearch = search.toLowerCase().replaceAll('.', ' ').trim();
    if (name == cleanSearch) return true;
    if (HelpdeskFacultyService.isNameMatch(teacherName, search, threshold: 0.65)) {
      return true;
    }
    final words = cleanSearch.split(RegExp(r'\s+')).where((w) => w.length > 1);
    if (words.isNotEmpty && words.every((w) => name.contains(w))) {
      return true;
    }
    return false;
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

    // Fast O(1) lookup via byTeacher index, fallback to unique teacher name keys
    final teacherIndex = memory.byTeacher();
    final matchedSessions = <ClassSession>[];
    String? resolvedName;

    final exactSessions = teacherIndex[search];
    if (exactSessions != null && exactSessions.isNotEmpty) {
      matchedSessions.addAll(exactSessions);
      resolvedName = exactSessions.first.teacher;
    } else {
      var bestScore = 0.0;
      List<ClassSession>? bestList;
      String? bestName;

      for (final entry in teacherIndex.entries) {
        if (_matchesTeacher(entry.key, search)) {
          final score = HelpdeskFacultyService.calculateSimilarity(entry.key, search);
          if (score > bestScore || bestList == null) {
            bestScore = score;
            bestList = entry.value;
            bestName = entry.value.isNotEmpty ? entry.value.first.teacher : entry.key;
          }
        }
      }

      if (bestList != null && bestList.isNotEmpty) {
        matchedSessions.addAll(bestList);
        resolvedName = bestName;
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

      final isDateValid = session.specificDate == null ||
          (session.specificDate!.year == now.year &&
              session.specificDate!.month == now.month &&
              session.specificDate!.day == now.day);

      final isLive = isDateValid &&
          session.dayIndex == weekday &&
          currentT >= session.safeStartVal &&
          currentT < _getActualEndTime(session);
      final isUpcoming = isDateValid &&
          session.dayIndex == weekday &&
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
        specificDate: session.specificDate,
      );

      weeklySchedule.putIfAbsent(session.dayIndex, () => []).add(entry);

      if (isLive) liveSession = entry;
      if (session.dayIndex == weekday && isDateValid) todaySessions.add(entry);
    }

    // Sort each day's sessions by start time
    for (final entries in weeklySchedule.values) {
      entries.sort((a, b) => FormatGuard.toDecimalTime(a.startTime).compareTo(FormatGuard.toDecimalTime(b.startTime)));
    }
    todaySessions.sort((a, b) => FormatGuard.toDecimalTime(a.startTime).compareTo(FormatGuard.toDecimalTime(b.startTime)));

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

  /// Builds intelligent temporal insight for exam periods (midterms / finals)
  TemporalInsight buildExamTemporalInsight(String batch, DateTime now, String period) {
    final rawExams = period == 'midterms'
        ? RemoteConfigService.midtermExams.value
        : RemoteConfigService.finalExams.value;

    final matchedExams = rawExams.where((exam) {
      final examBatchRaw = (exam['batch'] ?? '').toString();
      return BatchKey.isBatchMatch(batch, examBatchRaw);
    }).toList();

    final examLabel = period == 'midterms' ? 'Midterm Exam' : 'Final Exam';

    if (matchedExams.isEmpty) {
      return TemporalInsight(
        headline: '$examLabel Period',
        subline: 'Check Date Sheet Noticeboard',
        timeInfo: 'EXAMS IN SESSION',
        isLive: false,
        subject: '$examLabel Schedule',
        room: 'Examination Center',
        startTime: '',
      );
    }

    // Deduplicate and parse exams
    final List<Map<String, dynamic>> parsedList = [];
    for (final e in matchedExams) {
      final subject = (e['subject'] ?? '').toString().trim();
      final dateStr = (e['date'] ?? '').toString().trim();
      final timeStr = (e['time'] ?? '').toString().trim();
      final room = (e['room'] ?? '').toString().trim();
      if (subject.isEmpty) continue;

      final parsedDt = FormatGuard.parseDate(dateStr);

      parsedList.add({
        'subject': subject,
        'date': dateStr,
        'time': timeStr,
        'room': room.isNotEmpty ? room : 'Exam Hall',
        'dateTime': parsedDt,
      });
    }

    if (parsedList.isEmpty) {
      return TemporalInsight(
        headline: '$examLabel Period',
        subline: 'Check Date Sheet Noticeboard',
        timeInfo: 'EXAMS IN SESSION',
        isLive: false,
        subject: '$examLabel Schedule',
        room: 'Examination Center',
        startTime: '',
      );
    }

    // Sort chronologically by date and time
    parsedList.sort((a, b) {
      final dtA = (a['dateTime'] as DateTime?) ?? DateTime(3000);
      final dtB = (b['dateTime'] as DateTime?) ?? DateTime(3000);
      if (dtA != dtB) return dtA.compareTo(dtB);
      final tA = (a['time'] ?? '').toString();
      final tB = (b['time'] ?? '').toString();
      return tA.compareTo(tB);
    });

    final todayMidnight = DateTime(now.year, now.month, now.day);

    // Find the next upcoming or today's exam
    Map<String, dynamic>? targetExam;
    for (final exam in parsedList) {
      final dt = exam['dateTime'] as DateTime?;
      if (dt != null) {
        final examDay = DateTime(dt.year, dt.month, dt.day);
        if (!examDay.isBefore(todayMidnight)) {
          targetExam = exam;
          break;
        }
      } else {
        targetExam = exam;
        break;
      }
    }

    // If all exams are in the past
    if (targetExam == null) {
      return TemporalInsight(
        headline: 'All Exams Finished',
        subline: 'Great job! Enjoy your semester break 🎉',
        timeInfo: 'COMPLETED',
        isLive: false,
        subject: '$examLabel Period Concluded',
        room: 'Campus in Recess',
        startTime: '',
      );
    }

    final subject = targetExam['subject'] as String;
    final room = targetExam['room'] as String;
    final timeStr = targetExam['time'] as String;
    final dateStr = targetExam['date'] as String;
    final parsedDt = targetExam['dateTime'] as DateTime?;

    String countdownText = 'UPCOMING';
    if (parsedDt != null) {
      final isToday = parsedDt.year == now.year && parsedDt.month == now.month && parsedDt.day == now.day;
      if (isToday) {
        countdownText = timeStr.isNotEmpty ? 'TODAY • $timeStr' : 'TODAY';
      } else {
        const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final monthStr = monthNames[parsedDt.month];
        countdownText = timeStr.isNotEmpty ? '$monthStr ${parsedDt.day} • $timeStr' : '$monthStr ${parsedDt.day}';
      }
    } else if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
      countdownText = '$dateStr • $timeStr';
    } else if (dateStr.isNotEmpty) {
      countdownText = dateStr;
    } else if (timeStr.isNotEmpty) {
      countdownText = 'AT $timeStr';
    }

    return TemporalInsight(
      headline: 'Next $examLabel',
      subline: 'Venue: $room',
      timeInfo: countdownText,
      isLive: false,
      subject: subject,
      room: room,
      startTime: timeStr,
    );
  }

  /// Builds intelligent temporal insight for Vacation / Semester Break mode
  TemporalInsight buildVacationTemporalInsight(String batch, DateTime now) {
    // Default semester resumption target (e.g. 42 days or config target)
    final targetDate = now.add(const Duration(days: 42));
    final daysLeft = targetDate.difference(now).inDays.clamp(1, 120);

    return TemporalInsight(
      headline: 'Vacation Mode',
      subline: 'Campus in Recess • Lectures Suspended',
      timeInfo: '$daysLeft DAYS LEFT',
      isLive: false,
      subject: 'Semester Break',
      room: 'Campus in Recess',
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

  /// Merges overlapping and consecutive busy intervals into disjoint blocks
  List<(double, double)> _mergeIntervals(List<(double, double)> intervals) {
    if (intervals.isEmpty) return const [];
    final sorted = List<(double, double)>.from(intervals)
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(double, double)>[sorted.first];
    for (int i = 1; i < sorted.length; i++) {
      final cur = sorted[i];
      final last = merged.last;
      if (cur.$1 <= last.$2) {
        merged[merged.length - 1] = (last.$1, math.max(last.$2, cur.$2));
      } else {
        merged.add(cur);
      }
    }
    return merged;
  }

  /// Calculates mathematically exact, conflict-free free intervals for a given session list
  List<FreeSlot> _computeFreeSlotsForSessions(List<ClassSession> schedule) {
    if (schedule.isEmpty) return const [];

    final freeSlots = <FreeSlot>[];
    final daySlots = <int, List<ClassSession>>{};
    final operatingHours = _getOperatingHours();

    for (final session in schedule) {
      daySlots.putIfAbsent(session.dayIndex, () => []).add(session);
    }

    for (int dayIndex = 1; dayIndex <= 7; dayIndex++) {
      if (!operatingHours.containsKey(dayIndex)) continue;

      final (dayStart, dayEnd) = operatingHours[dayIndex]!;
      final daySessions = daySlots[dayIndex] ?? const [];

      if (daySessions.isEmpty) {
        freeSlots.add(FreeSlot(
          dayIndex: dayIndex,
          startTime: dayStart,
          endTime: dayEnd,
        ));
        continue;
      }

      final busyIntervals = daySessions
          .map((s) => (s.safeStartVal, s.safeEndVal))
          .toList();
      final mergedBusy = _mergeIntervals(busyIntervals);

      double current = dayStart;
      for (final busy in mergedBusy) {
        final bStart = math.max(dayStart, busy.$1);
        final bEnd = math.min(dayEnd, busy.$2);
        if (bStart > current) {
          freeSlots.add(FreeSlot(
            dayIndex: dayIndex,
            startTime: current,
            endTime: bStart,
          ));
        }
        if (bEnd > current) {
          current = bEnd;
        }
      }

      if (current < dayEnd) {
        freeSlots.add(FreeSlot(
          dayIndex: dayIndex,
          startTime: current,
          endTime: dayEnd,
        ));
      }
    }

    return freeSlots;
  }

  /// Find free slots for a batch across a week
  /// Returns list of {day, start_time, end_time} when the batch has no classes
  List<FreeSlot> findFreeSlotsForBatch(String batch) {
    final schedule = scheduleFor(batch);
    return _computeFreeSlotsForSessions(schedule);
  }

  /// Find free slots for a teacher across a week
  List<FreeSlot> findFreeSlotsForTeacher(String teacherName) {
    final schedule = scheduleForTeacher(teacherName);
    return _computeFreeSlotsForSessions(schedule);
  }

  static const List<({String name, double startTime, double endTime, double durationHours})> _officialStandardSlots = [
    // Standard 1.5-hr lecture slots (CS/SE/EE/BBA standard grid)
    (name: 'Slot 1 (Morning)', startTime: 8.5, endTime: 10.0, durationHours: 1.5),
    (name: 'Slot 2 (Mid-Morning)', startTime: 10.0, endTime: 11.5, durationHours: 1.5),
    (name: 'Slot 3 (Noon)', startTime: 11.5, endTime: 13.0, durationHours: 1.5),
    (name: 'Slot 4 (Afternoon)', startTime: 13.667, endTime: 15.083, durationHours: 1.417),
    (name: 'Slot 5 (Late Afternoon)', startTime: 15.083, endTime: 16.5, durationHours: 1.417),
    
    // Standard 1-Hour lecture slots (Management/Humanities/Single-credit)
    (name: '1-Hour Slot (08:00 - 09:00 AM)', startTime: 8.0, endTime: 9.0, durationHours: 1.0),
    (name: '1-Hour Slot (09:00 - 10:00 AM)', startTime: 9.0, endTime: 10.0, durationHours: 1.0),
    (name: '1-Hour Slot (10:00 - 11:00 AM)', startTime: 10.0, endTime: 11.0, durationHours: 1.0),
    (name: '1-Hour Slot (11:00 AM - 12:00 PM)', startTime: 11.0, endTime: 12.0, durationHours: 1.0),
    (name: '1-Hour Slot (01:00 - 02:00 PM)', startTime: 13.0, endTime: 14.0, durationHours: 1.0),
    (name: '1-Hour Slot (02:00 - 03:00 PM)', startTime: 14.0, endTime: 15.0, durationHours: 1.0),
    (name: '1-Hour Slot (03:00 - 04:00 PM)', startTime: 15.0, endTime: 16.0, durationHours: 1.0),
  ];

  static const List<({String name, double startTime, double endTime, double durationHours})> _ramadanAcademicSlots = [
    (name: 'Ramadan Slot 1', startTime: 8.5, endTime: 9.5, durationHours: 1.0),
    (name: 'Ramadan Slot 2', startTime: 9.5, endTime: 10.5, durationHours: 1.0),
    (name: 'Ramadan Slot 3', startTime: 10.5, endTime: 11.5, durationHours: 1.0),
    (name: 'Ramadan Slot 4', startTime: 11.5, endTime: 12.5, durationHours: 1.0),
    (name: 'Ramadan Slot 5', startTime: 12.5, endTime: 13.5, durationHours: 1.0),
  ];

  /// Find authentic, standard university makeup slots where BOTH batch and teacher are free,
  /// with verified available physical rooms on campus.
  List<MakeupSlotSuggestion> findMakeupSlots(String batch, String teacherName) {
    final batchSessions = scheduleFor(batch);
    final teacherSessions = scheduleForTeacher(teacherName);

    if (batchSessions.isEmpty && teacherSessions.isEmpty) return [];

    final suggestions = <MakeupSlotSuggestion>[];
    final isRamadan = RemoteConfigService.activeAcademicPeriod.value == 'ramadan';
    final candidateSlots = isRamadan ? _ramadanAcademicSlots : _officialStandardSlots;

    for (int dayIndex = 1; dayIndex <= 5; dayIndex++) {
      final dayBatchSessions = batchSessions.where((s) => s.dayIndex == dayIndex).toList();
      final dayTeacherSessions = teacherSessions.where((s) => s.dayIndex == dayIndex).toList();

      for (final slot in candidateSlots) {
        final slotStart = slot.startTime;
        final slotEnd = slot.endTime;

        // 1. Strict Batch Conflict check (with 2-minute margin of tolerance)
        final batchHasConflict = dayBatchSessions.any((s) =>
            s.safeStartVal < (slotEnd - 0.03) && s.safeEndVal > (slotStart + 0.03));
        if (batchHasConflict) continue;

        // 2. Strict Teacher Conflict check (with 2-minute margin)
        final teacherHasConflict = dayTeacherSessions.any((s) =>
            s.safeStartVal < (slotEnd - 0.03) && s.safeEndVal > (slotStart + 0.03));
        if (teacherHasConflict) continue;

        // 3. Physical Room Availability Check
        final availableRooms = findEmptyRoomsForSlot(dayIndex, slotStart, slotEnd);
        if (availableRooms.isEmpty) continue;

        suggestions.add(MakeupSlotSuggestion(
          dayIndex: dayIndex,
          startTime: slotStart,
          endTime: slotEnd,
          durationHours: slot.durationHours,
          slotName: slot.name,
          availableRooms: availableRooms,
        ));
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
