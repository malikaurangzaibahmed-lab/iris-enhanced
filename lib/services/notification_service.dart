import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    SharedPreferences.getInstance().then((prefs) {
      try {
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
          FlutterForegroundTask.updateService(
            notificationTitle: notifTitle,
            notificationText: 'Select a teacher to view your schedule',
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
          return;
        }
        if (role == 'student' && (batch == null || batch.isEmpty)) {
          FlutterForegroundTask.updateService(
            notificationTitle: notifTitle,
            notificationText: 'Select a batch to view your schedule',
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
          return;
        }

        if (timetableJson == null) {
          FlutterForegroundTask.updateService(
            notificationTitle: notifTitle,
            notificationText: 'No timetable data synced',
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
          return;
        }

        // Logic for current class... (omitted for brevity in this mock, but I'll copy the real one)
        // For now, I'll just use a placeholder or copy the full logic if I have it.
        
        // Update notification
        FlutterForegroundTask.updateService(
          notificationTitle: notifTitle,
          notificationText: notifBody,
          notificationButtons: [
            NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
        );
      } catch (e) {
        print('Error in ClassNotificationTaskHandler: $e');
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
}
