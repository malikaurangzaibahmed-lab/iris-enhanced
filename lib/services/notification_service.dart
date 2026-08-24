import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../core/models.dart';
import 'helpdesk_faculty_service.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
void startClassNotificationTask() {
  FlutterForegroundTask.setTaskHandler(ClassNotificationTaskHandler());
}

class ClassNotificationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Task started
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Calculate current class info from stored timetable data
    SharedPreferences.getInstance().then((prefs) async {
      try {
        final academicPeriod = prefs.getString('active_academic_period') ?? 'classes';
        if (academicPeriod != 'classes') {
          String notifTitle = '';
          String notifBody = '';
          String headline = '';
          String subline = '';
          String subject = '';
          String room = '';

          String timeInfoStr = 'Active';

          if (academicPeriod == 'vacation' || academicPeriod == 'break') {
            final cachedVac = prefs.getString('cached_vacation_schedule') ?? '';
            final now = DateTime.now();
            final defaultTargetSem = now.month >= 8 ? 'Spring ${now.year + 1}' : 'Fall ${now.year}';
            String targetSem = defaultTargetSem;
            int daysLeft = -1;
            if (cachedVac.isNotEmpty) {
              try {
                final vacMap = jsonDecode(cachedVac);
                targetSem = vacMap['target_semester']?.toString() ?? defaultTargetSem;
                final rStr = vacMap['resumption_date']?.toString();
                if (rStr != null && rStr.isNotEmpty) {
                  final dt = DateTime.tryParse(rStr);
                  if (dt != null) {
                    final diff = DateTime(dt.year, dt.month, dt.day)
                        .difference(DateTime(now.year, now.month, now.day))
                        .inDays;
                    daysLeft = diff;
                  }
                }
              } catch (_) {}
            }
            notifTitle = '🌴 Semester Break';
            if (daysLeft > 1) {
              notifBody = '$daysLeft Days Until $targetSem Resumes';
              timeInfoStr = '$daysLeft DAYS LEFT';
            } else if (daysLeft == 1) {
              notifBody = '1 Day Until $targetSem Resumes';
              timeInfoStr = '1 DAY LEFT';
            } else if (daysLeft == 0) {
              notifBody = 'Resumes Today • Welcome back to $targetSem!';
              timeInfoStr = 'RESUMES TODAY';
            } else if (daysLeft < 0 && daysLeft != -1) {
              notifBody = 'Classes Resumed • Welcome to $targetSem';
              timeInfoStr = 'CLASSES RESUMED';
            } else {
              notifBody = 'Campus in Recess • Enjoy Your Break';
              timeInfoStr = 'RECESS';
            }
            headline = 'Vacation Mode';
            subline = 'Campus in Recess • Lectures Suspended';
            subject = 'Semester Break';
            room = 'Campus in Recess';
          } else if (academicPeriod == 'sports_week') {
            notifTitle = '🏆 Sports Week Active';
            notifBody = '🏅 Students Gala in Session · Enjoy match fixtures!';
            headline = 'Sports Week';
            subline = 'Enjoy matches & events!';
            subject = 'Campus Sports Week';
            room = 'Sports Complex';
            timeInfoStr = 'GALA ACTIVE';
          } else if (academicPeriod == 'midterms' || academicPeriod == 'finals') {
            final isMid = academicPeriod == 'midterms';
            final examLabel = isMid ? 'Midterm Exam' : 'Final Exam';
            notifTitle = isMid ? '✍️ Midterm Exams Active' : '🎓 Terminal Exams Active';
            notifBody = '📝 $examLabel Schedule · Check exam halls';
            headline = isMid ? 'Midterm Exams' : 'Final Exams';
            subline = 'Examination Hall';
            subject = isMid ? 'Midterm Exams' : 'Final Exams';
            room = 'Examination Hall';
            timeInfoStr = 'UPCOMING';
          }

          await HomeWidget.saveWidgetData<bool>('flutter.is_class_live', false);
          await HomeWidget.saveWidgetData<String>('flutter.widget_headline', headline);
          await HomeWidget.saveWidgetData<String>('flutter.widget_subline', subline);
          await HomeWidget.saveWidgetData<String>('flutter.widget_subject', subject);
          await HomeWidget.saveWidgetData<String>('flutter.current_class_subject', subject);
          await HomeWidget.saveWidgetData<String>('flutter.widget_room', room);
          await HomeWidget.saveWidgetData<String>('flutter.current_class_room', room);
          await HomeWidget.saveWidgetData<String>('flutter.current_class_teacher', '');
          await HomeWidget.saveWidgetData<int>('flutter.progress_percentage', 0);
          await HomeWidget.saveWidgetData<String>('flutter.time_info', timeInfoStr);
          await HomeWidget.saveWidgetData<bool>('flutter.is_urgent', false);
          await HomeWidget.saveWidgetData<String>('flutter.active_mode', academicPeriod);

          await HomeWidget.updateWidget(
            name: 'ClassTrackerWidget',
            androidName: 'ClassTrackerWidget',
          );

          await FlutterForegroundTask.updateService(
            notificationTitle: notifTitle,
            notificationText: notifBody,
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
          return;
        }

        final role = prefs.getString('user_role') ?? 'student';
        final batch = prefs.getString('student_batch');
        final teacherName = prefs.getString('faculty_teacher');
        final timetableJson = prefs.getString('timetable_data');

        // Always initialize default message
        String notifTitle = role == 'faculty'
            ? 'IRIS Faculty Tracker'
            : 'IRIS Class Tracker';
        String notifBody = 'No classes scheduled';

        // Validate role and data consistency - but still update notification
        if (role == 'faculty' && (teacherName == null || teacherName.isEmpty)) {
          await FlutterForegroundTask.updateService(
            notificationTitle: notifTitle,
            notificationText: 'Select a teacher to view your schedule',
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
          return;
        }
        if (role == 'student' && (batch == null || batch.isEmpty)) {
          await FlutterForegroundTask.updateService(
            notificationTitle: notifTitle,
            notificationText: 'Select a batch to view your schedule',
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
          return;
        }

        List<ClassSession> allSessions = [];
        if (academicPeriod == 'midterms' || academicPeriod == 'finals') {
          final cachedExams = prefs.getString(academicPeriod == 'midterms' ? 'cached_midterm_exams' : 'cached_finals_exams') ?? '';
          if (cachedExams.isNotEmpty) {
            try {
              final decoded = jsonDecode(cachedExams);
              if (decoded is List) {
                allSessions = decoded.asMap().entries.map((e) => ClassSession.fromExamJson(Map<String, dynamic>.from(e.value), index: e.key)).toList();
              }
            } catch (_) {}
          }
        }

        if (allSessions.isEmpty && timetableJson != null) {
          final List<dynamic> parsedList = jsonDecode(timetableJson);
          allSessions = parsedList.map((json) => ClassSession.fromJson(json)).toList();
        }

        if (allSessions.isEmpty) {
          await FlutterForegroundTask.updateService(
            notificationTitle: notifTitle,
            notificationText: 'No schedule data synced',
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
          return;
        }

        final List<ClassSession> userSchedule = allSessions.where((s) {
          if (role == 'faculty') {
            if (teacherName == null) return false;
            return s.teacher.trim().toLowerCase() == teacherName.trim().toLowerCase();
          } else {
            if (batch == null) return false;
            return s.batchKey.batch.trim().toLowerCase() == batch.trim().toLowerCase();
          }
        }).toList();

        final now = DateTime.now();
        final dayIndex = now.weekday;
        final currentTime = now.hour + (now.minute / 60.0);

        final todaySessions = userSchedule.where((s) => s.dayIndex == dayIndex).toList();

        // Merge consecutive classes
        final sorted = List<ClassSession>.from(todaySessions)
          ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

        final mergedToday = <ClassSession>[];
        ClassSession? currentMerged;
        for (final session in sorted) {
          if (currentMerged == null) {
            currentMerged = session;
            continue;
          }
          if (currentMerged.isConsecutiveWith(session)) {
            currentMerged = ClassSession(
              id: currentMerged.id,
              batchKey: currentMerged.batchKey,
              dayIndex: currentMerged.dayIndex,
              startTime: currentMerged.startTime,
              endTime: session.endTime,
              subject: currentMerged.subject,
              teacher: currentMerged.teacher,
              room: currentMerged.room,
            );
          } else {
            mergedToday.add(currentMerged);
            currentMerged = session;
          }
        }
        if (currentMerged != null) {
          mergedToday.add(currentMerged);
        }

        // Find current live class
        ClassSession? currentLive;
        for (final s in mergedToday) {
          if (currentTime >= s.safeStartVal && currentTime < s.safeEndVal) {
            currentLive = s;
            break;
          }
        }

        // Find next class today or in future days
        ClassSession? nextClass;
        final upcomingToday = mergedToday.where((s) => s.safeStartVal > currentTime).toList()
          ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
        if (upcomingToday.isNotEmpty) {
          nextClass = upcomingToday.first;
        } else {
          for (int daysAhead = 1; daysAhead <= 6; daysAhead++) {
            final targetDay = ((dayIndex + daysAhead - 1) % 7) + 1;
            final daySessions = userSchedule.where((s) => s.dayIndex == targetDay).toList();
            if (daySessions.isNotEmpty) {
              final sortedDay = List<ClassSession>.from(daySessions)
                ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
              final mergedDay = <ClassSession>[];
              ClassSession? curMerged;
              for (final s in sortedDay) {
                if (curMerged == null) { curMerged = s; continue; }
                if (curMerged.isConsecutiveWith(s)) {
                  curMerged = ClassSession(
                    id: curMerged.id,
                    batchKey: curMerged.batchKey,
                    dayIndex: curMerged.dayIndex,
                    startTime: curMerged.startTime,
                    endTime: s.endTime,
                    subject: curMerged.subject,
                    teacher: curMerged.teacher,
                    room: curMerged.room,
                  );
                } else {
                  mergedDay.add(curMerged);
                  curMerged = s;
                }
              }
              if (curMerged != null) mergedDay.add(curMerged);
              mergedDay.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
              nextClass = mergedDay.first;
              break;
            }
          }
        }

        if (currentLive != null) {
          final duration = (currentLive.safeEndVal - currentLive.safeStartVal).abs();
          final progress = ((currentTime - currentLive.safeStartVal) / duration).clamp(0.0, 1.0);
          final progressPercent = (progress * 100).toInt();

          final minutesRemaining = ((currentLive.safeEndVal - currentTime) * 60).round().clamp(0, (duration * 60).round());
          final hoursRemaining = minutesRemaining ~/ 60;
          final minsRemaining = minutesRemaining % 60;

          final timeLeft = hoursRemaining > 0
              ? '${hoursRemaining}h ${minsRemaining}m left'
              : minsRemaining > 0
                  ? '${minsRemaining}m left'
                  : 'Ending now';

          final remaining = mergedToday.where((s) => s.safeStartVal > currentTime).length;
          final classCount = remaining > 0 ? ' • $remaining more today' : ' • Last session today';

          final cleanSubject = currentLive.subject.replaceAll('[EXAM]', '').trim();

          notifTitle = '🎓 $cleanSubject • $progressPercent%';
          notifBody = '⏱️ $timeLeft (${currentLive.startTime} - ${currentLive.endTime})$classCount\n📍 ${currentLive.room} • ${role == 'faculty' ? currentLive.batchKey.batch : currentLive.teacher}';

          // Update ClassTrackerWidget homescreen widget in background
          final displayTime = '${currentLive.startTime} - ${currentLive.endTime}';
          await HomeWidget.saveWidgetData<bool>('flutter.is_class_live', true);
          await HomeWidget.saveWidgetData<String>('flutter.widget_headline', cleanSubject);
          await HomeWidget.saveWidgetData<String>('flutter.widget_subline', currentLive.room);
          await HomeWidget.saveWidgetData<String>('flutter.current_class_teacher', role == 'faculty' ? currentLive.batchKey.batch : currentLive.teacher);
          final teacherImgPath = HelpdeskFacultyService.resolveTeacherImagePath(currentLive.teacher);
          await HomeWidget.saveWidgetData<String>('flutter.teacher_image_url', teacherImgPath);
          await HomeWidget.saveWidgetData<int>('flutter.progress_percentage', progressPercent);
          await HomeWidget.saveWidgetData<String>('flutter.time_info', displayTime);
          await HomeWidget.saveWidgetData<bool>('flutter.is_urgent', false);
        } else if (nextClass != null) {
          int daysAhead = 0;
          if (nextClass.dayIndex != dayIndex) {
            daysAhead = (nextClass.dayIndex - dayIndex + 7) % 7;
            if (daysAhead == 0) daysAhead = 7;
          }

          final totalMinutesUntil = daysAhead > 0
              ? ((24.0 - currentTime) * 60 + (daysAhead - 1) * 24 * 60 + nextClass.safeStartVal * 60).round()
              : ((nextClass.safeStartVal - currentTime) * 60).round();

          final hoursUntil = totalMinutesUntil ~/ 60;
          final minsUntil = totalMinutesUntil % 60;

          String timeUntil = '';
          String emoji = '📌';
          if (daysAhead > 0) {
            const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            final nextDayName = dayNames[nextClass.dayIndex];
            final startHour = nextClass.safeStartVal.floor();
            final startMin = ((nextClass.safeStartVal - startHour) * 60).round();
            final displayHour = startHour > 12 ? startHour - 12 : startHour;
            final amPm = startHour >= 12 ? 'PM' : 'AM';
            timeUntil = '$nextDayName ${displayHour}:${startMin.toString().padLeft(2, '0')} $amPm';
            emoji = '📅';
          } else if (hoursUntil > 0) {
            timeUntil = '${hoursUntil}h ${minsUntil}m';
            emoji = '⏳';
          } else if (minsUntil > 10) {
            timeUntil = '${minsUntil} min';
            emoji = '⏳';
          } else if (minsUntil > 0) {
            timeUntil = '${minsUntil} min';
            emoji = '⚡';
          } else {
            timeUntil = 'now';
            emoji = '🔔';
          }

          final remainingToday = mergedToday.where((s) => s.safeStartVal > currentTime).length;

          String breakInfo = '';
          if (daysAhead == 0) {
            final prevClasses = mergedToday.where((s) => s.safeEndVal <= currentTime).toList();
            if (prevClasses.isNotEmpty) {
              prevClasses.sort((a, b) => b.safeEndVal.compareTo(a.safeEndVal));
              final breakMins = ((nextClass.safeStartVal - prevClasses.first.safeEndVal) * 60).round();
              if (breakMins > 0 && breakMins < 180) {
                breakInfo = ' · ${breakMins}m break';
              }
            }
          }

          String classInfo = daysAhead > 0
              ? 'Done for today ✓'
              : remainingToday > 1
                  ? '$remainingToday classes left'
                  : 'Last class today';

          notifTitle = '$emoji ${nextClass.subject} in $timeUntil';
          notifBody = '$classInfo$breakInfo\n📍 ${nextClass.room} · ${role == 'faculty' ? nextClass.batchKey.batch : nextClass.teacher}';

          // Update ClassTrackerWidget homescreen widget in background
          final isUrgent = daysAhead == 0 && totalMinutesUntil < 15;
          final displayTime = '${nextClass.startTime} - ${nextClass.endTime}';
          await HomeWidget.saveWidgetData<bool>('flutter.is_class_live', false);
          await HomeWidget.saveWidgetData<String>('flutter.widget_headline', nextClass.subject);
          await HomeWidget.saveWidgetData<String>('flutter.widget_subline', nextClass.room);
          await HomeWidget.saveWidgetData<String>('flutter.current_class_teacher', role == 'faculty' ? nextClass.batchKey.batch : nextClass.teacher);
          final nextTeacherImgPath = HelpdeskFacultyService.resolveTeacherImagePath(nextClass.teacher);
          await HomeWidget.saveWidgetData<String>('flutter.teacher_image_url', nextTeacherImgPath);
          await HomeWidget.saveWidgetData<int>('flutter.progress_percentage', 0);
          await HomeWidget.saveWidgetData<String>('flutter.time_info', displayTime);
          await HomeWidget.saveWidgetData<bool>('flutter.is_urgent', isUrgent);
        } else {
          if (dayIndex == 5) {
            // Friday mode with Darood & Jummah recognition
            final isJummahWindow = currentTime >= 11.5 && currentTime <= 14.5;
            if (isJummahWindow) {
              notifTitle = '🕌 Jummah Mubarak · Darood e Pak';
              notifBody = 'Send blessings upon Prophet Muhammad ﷺ';
            } else {
              notifTitle = '✓ All done for today';
              notifBody = 'No more classes scheduled · Jummah Mubarak';
            }
          } else if (dayIndex == 6 || dayIndex == 7) {
            notifTitle = '🎉 Weekend Mode';
            notifBody = 'No classes — enjoy your break!';
          } else {
            notifTitle = '✓ All done for today';
            notifBody = 'No more classes scheduled';
          }

          // Update ClassTrackerWidget homescreen widget to idle in background
          await HomeWidget.saveWidgetData<bool>('flutter.is_class_live', false);
          await HomeWidget.saveWidgetData<String>('flutter.widget_headline', dayIndex == 5 ? 'Jummah Mubarak' : 'System Idle');
          await HomeWidget.saveWidgetData<String>('flutter.widget_subline', dayIndex == 5 ? 'Darood e Pak 🕌' : 'No active class');
          await HomeWidget.saveWidgetData<String>('flutter.current_class_teacher', '');
          await HomeWidget.saveWidgetData<int>('flutter.progress_percentage', 0);
          await HomeWidget.saveWidgetData<String>('flutter.time_info', 'Ready');
          await HomeWidget.saveWidgetData<bool>('flutter.is_urgent', false);
        }

        // Push widget refresh
        await HomeWidget.updateWidget(
          name: 'ClassTrackerWidget',
          androidName: 'ClassTrackerWidget',
        );

        // Update foreground service notification
        await FlutterForegroundTask.updateService(
          notificationTitle: notifTitle,
          notificationText: notifBody,
          notificationButtons: [
            NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
        );
      } catch (e) {
        debugPrint('Error in ClassNotificationTaskHandler: $e');
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Task destroyed
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'open') {
      FlutterForegroundTask.launchApp();
    }
  }
}

class NotificationService {
  Future<void> scheduleClassReminders(List<dynamic> classes) async {
    // Stub implementation
  }

  Future<void> syncClassRemindersFromPrefs() async {
    // Stub implementation
  }

  Future<void> cancelScheduledClassReminders() async {
    // Stub implementation
  }
}
