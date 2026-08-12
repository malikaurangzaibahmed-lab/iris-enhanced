import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../screens/portal_screen.dart';

class BlurLevel {
  static const int none = 0;
  static const int low = 1;
  static const int medium = 2;
  static const int high = 3;

  static String getName(int level) {
    switch (level) {
      case none:
        return 'Off';
      case low:
        return 'Low';
      case medium:
        return 'Medium';
      case high:
        return 'High';
      default:
        return 'Medium';
    }
  }

  static double getBlurSigma(int level) {
    switch (level) {
      case none:
        return 0;
      case low:
        return 2.5;
      case medium:
        return 5.4;
      case high:
        return 18;
      default:
        return 5.4;
    }
  }
}

class WidgetService {
  static const String _prefCurrentClassSubject = 'flutter.current_class_subject';
  static const String _prefCurrentClassRoom = 'flutter.current_class_room';
  static const String _prefCurrentClassTeacher = 'flutter.current_class_teacher';
  static const String _prefCurrentClassEndTime = 'flutter.current_class_end_time';
  static const String _prefProgressPercentage = 'flutter.progress_percentage';
  static const String _prefIsClassLive = 'flutter.is_class_live';
  static const String _prefBlurLevel = 'flutter.blur_level';
  static const String _prefTimeInfo = 'flutter.time_info';
  static const String _prefIsUrgent = 'flutter.is_urgent';
  static const String _prefLastUpdate = 'flutter.last_update_hash';
  
  static const String _prefHeadline = 'flutter.widget_headline';
  static const String _prefSubline = 'flutter.widget_subline';
  static const String _prefWidgetDarkMode = 'flutter.widget_dark_mode';
  static const String _prefWidgetSubject = 'flutter.widget_subject';
  static const String _prefWidgetRoom = 'flutter.widget_room';
  static const String _prefWidgetStartTime = 'flutter.widget_start_time';
  static const String _prefActiveRole = 'flutter.active_role';
  static const String _prefWidgetBatch = 'flutter.widget_batch';

  static Future<void> setActiveRole(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefActiveRole, role);
      await HomeWidget.saveWidgetData<String>(_prefActiveRole, role);
      await HomeWidget.updateWidget(
        name: 'ClassTrackerWidget',
        iOSName: 'OmniFlowWidget',
        androidName: 'ClassTrackerWidget',
      );
    } catch (e) {
      debugPrint('⚠️ setActiveRole failed: $e');
    }
  }

  static Future<void> setBatch(String batch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefWidgetBatch, batch);
      await HomeWidget.saveWidgetData<String>(_prefWidgetBatch, batch);
      await HomeWidget.updateWidget(
        name: 'ClassTrackerWidget',
        iOSName: 'OmniFlowWidget',
        androidName: 'ClassTrackerWidget',
      );
    } catch (e) {
      debugPrint('⚠️ setBatch failed: $e');
    }
  }

  static const String _widgetGroupId = 'com.iris.app';

  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(_widgetGroupId);
      debugPrint('✅ Home Widget Service initialized');
    } catch (e) {
      debugPrint('⚠️ Widget initialization: $e');
    }
  }

  /// Initialize widget with default "idle" state on app startup
  static Future<void> initializeWidgetDefaults() async {
    try {
      debugPrint('🔧 Initializing widget defaults...');
      await updateWidgetIdle(
        headline: 'System Idle',
        subline: 'No active class',
        teacherInfo: '',
        timeInfo: 'Ready to go',
        isUrgent: false,
      );
      debugPrint('✅ Widget defaults initialized');
    } catch (e) {
      debugPrint('⚠️ Widget defaults init failed: $e');
    }
  }

  /// Completely rebuild widget with validation at every step
  static Future<void> updateWidget({
    required bool isLive,
    required String subject,
    required String room,
    required String teacher,
    required String endTime,
    required int progressPercentage,
    required String nextClassSubject,
    required String nextClassStartTime,
    required String nextClassRoom,
    String timeInfo = '',
    bool isUrgent = false,
  }) async {
    try {
      // STEP 1: Validate and sanitize all inputs
      final sanitizedSubject = _validateString(subject, 'System Idle', 50);
      final sanitizedRoom = _validateString(room, 'No active class', 100);
      final sanitizedTeacher = _validateString(teacher, '', 50);
      final sanitizedEndTime = _validateString(endTime, '', 20);
      final sanitizedTimeInfo = _validateString(timeInfo, '', 50);
      final sanitizedProgress = progressPercentage.clamp(0, 100);

      debugPrint('🔧 Widget update initiated');
      debugPrint('  Subject: $sanitizedSubject');
      debugPrint('  Room: $sanitizedRoom');
      debugPrint('  Live: $isLive');
      debugPrint('  Progress: $sanitizedProgress%');

      // STEP 2: Save to local shared preferences first (backup)
      final prefs = await SharedPreferences.getInstance();
      
      try {
        await prefs.setBool(_prefIsClassLive, isLive);
        await prefs.setString(_prefCurrentClassSubject, sanitizedSubject);
        await prefs.setString(_prefCurrentClassRoom, sanitizedRoom);
        await prefs.setString(_prefCurrentClassTeacher, sanitizedTeacher);
        await prefs.setString(_prefCurrentClassEndTime, sanitizedEndTime);
        await prefs.setInt(_prefProgressPercentage, sanitizedProgress);
        await prefs.setString(_prefTimeInfo, sanitizedTimeInfo);
        await prefs.setBool(_prefIsUrgent, isUrgent);

        await prefs.setString(_prefHeadline, sanitizedSubject);
        await prefs.setString(_prefSubline, isLive ? 'Ending $sanitizedEndTime • $sanitizedRoom' : sanitizedRoom);
        await prefs.setString(_prefWidgetSubject, sanitizedSubject);
        await prefs.setString(_prefWidgetRoom, sanitizedRoom);
        await prefs.setString(_prefWidgetStartTime, nextClassStartTime);
        debugPrint('✅ Local preferences saved');
      } catch (e) {
        debugPrint('⚠️ Local pref save failed: $e');
      }

      // STEP 3: Save to HomeWidget (Android device storage)
      try {
        await HomeWidget.saveWidgetData<bool>(_prefIsClassLive, isLive);
        await HomeWidget.saveWidgetData<String>(_prefCurrentClassSubject, sanitizedSubject);
        await HomeWidget.saveWidgetData<String>(_prefCurrentClassRoom, sanitizedRoom);
        await HomeWidget.saveWidgetData<String>(_prefCurrentClassTeacher, sanitizedTeacher);
        await HomeWidget.saveWidgetData<String>(_prefCurrentClassEndTime, sanitizedEndTime);
        await HomeWidget.saveWidgetData<int>(_prefProgressPercentage, sanitizedProgress);
        await HomeWidget.saveWidgetData<String>(_prefTimeInfo, sanitizedTimeInfo);
        await HomeWidget.saveWidgetData<bool>(_prefIsUrgent, isUrgent);

        await HomeWidget.saveWidgetData<String>(_prefHeadline, sanitizedSubject);
        await HomeWidget.saveWidgetData<String>(_prefSubline, isLive ? 'Ending $sanitizedEndTime • $sanitizedRoom' : sanitizedRoom);
        await HomeWidget.saveWidgetData<String>(_prefWidgetSubject, sanitizedSubject);
        await HomeWidget.saveWidgetData<String>(_prefWidgetRoom, sanitizedRoom);
        await HomeWidget.saveWidgetData<String>(_prefWidgetStartTime, nextClassStartTime);
        debugPrint('✅ HomeWidget data saved');
      } catch (e) {
        debugPrint('⚠️ HomeWidget save failed: $e');
      }

      // STEP 4: Request widget update
      try {
        await HomeWidget.updateWidget(
          name: 'ClassTrackerWidget',
          iOSName: 'OmniFlowWidget',
          androidName: 'ClassTrackerWidget',
        );
        debugPrint('✅ Widget update sent to ClassTrackerWidget');
      } catch (e) {
        debugPrint('⚠️ Widget update request failed: $e');
      }
    } catch (e) {
      debugPrint('🔥 Widget update failed: $e');
    }
  }

  /// Update widget for idle state
  static Future<void> updateWidgetIdle({
    required String headline,
    required String subline,
    required String teacherInfo,
    String timeInfo = '',
    bool isUrgent = false,
  }) async {
    await updateWidget(
      isLive: false,
      subject: headline,
      room: subline,
      teacher: teacherInfo,
      endTime: '',
      progressPercentage: 0,
      nextClassSubject: '',
      nextClassStartTime: '',
      nextClassRoom: '',
      timeInfo: timeInfo,
      isUrgent: isUrgent,
    );
  }

  /// Validate and sanitize string input
  static String _validateString(String? input, String defaultValue, int maxLength) {
    try {
      if (input == null || input.isEmpty) {
        return defaultValue;
      }
      
      String trimmed = input.trim();
      if (trimmed.isEmpty) {
        return defaultValue;
      }
      
      // Sanitize first preserving dots, commas, colons, dashes, brackets
      String sanitized = trimmed.replaceAll(RegExp(r'[^\w\s·–\-:/().,&+]'), '');
      
      // Then limit length safely
      if (sanitized.length > maxLength) {
        sanitized = sanitized.substring(0, maxLength);
      }
      
      sanitized = sanitized.trim();
      return sanitized.isEmpty ? defaultValue : sanitized;
    } catch (e) {
      debugPrint('⚠️ String validation error for "$input": $e');
      return defaultValue;
    }
  }

  static Future<void> setTimeInfo(String timeInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefTimeInfo, timeInfo);
      await HomeWidget.saveWidgetData<String>(_prefTimeInfo, timeInfo);
    } catch (e) {
      debugPrint('⚠️ setTimeInfo failed: $e');
    }
  }

  static Future<void> setUrgent(bool isUrgent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsUrgent, isUrgent);
      await HomeWidget.saveWidgetData<bool>(_prefIsUrgent, isUrgent);
    } catch (e) {
      debugPrint('⚠️ setUrgent failed: $e');
    }
  }

  static Future<String> getTimeInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefTimeInfo) ?? '';
    } catch (e) {
      debugPrint('⚠️ getTimeInfo failed: $e');
      return '';
    }
  }

  static Future<bool> getUrgent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefIsUrgent) ?? false;
    } catch (e) {
      debugPrint('⚠️ getUrgent failed: $e');
      return false;
    }
  }

  static Future<void> setBlurLevel(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefBlurLevel, level);
    } catch (e) {
      debugPrint('⚠️ setBlurLevel failed: $e');
    }
  }

  static Future<int> getBlurLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_prefBlurLevel) ?? BlurLevel.medium;
    } catch (e) {
      debugPrint('⚠️ getBlurLevel failed: $e');
      return BlurLevel.medium;
    }
  }

  /// Force clear widget cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefLastUpdate);
      debugPrint('🗑️ Widget cache cleared');
    } catch (e) {
      debugPrint('⚠️ Cache clear failed: $e');
    }
  }

  // Widget dark mode toggle methods
  static Future<void> setWidgetDarkMode(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefWidgetDarkMode, isDark);
      await HomeWidget.saveWidgetData<bool>(_prefWidgetDarkMode, isDark);
      debugPrint('✅ Widget dark mode set to: $isDark');
    } catch (e) {
      debugPrint('⚠️ setWidgetDarkMode failed: $e');
    }
  }

  static Future<bool> getWidgetDarkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Default to system dark mode (false = light, true = dark)
      return prefs.getBool(_prefWidgetDarkMode) ?? false;
    } catch (e) {
      debugPrint('⚠️ getWidgetDarkMode failed: $e');
      return false;
    }
  }

  /// Update widget with temporal insight data
  static Future<void> updateWidgetWithInsight({
    required String headline,
    required String subline,
    required String timeInfo,
    required String teacherInfo,
    required bool isLive,
    required bool isUrgent,
    required int progressPercentage,
    String? subject,
    String? room,
    String? startTime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final finalSubject = subject ?? headline;
      final finalRoom = room ?? '';
      final finalStartTime = startTime ?? '';

      // Save all data to local prefs
      await prefs.setString(_prefHeadline, headline);
      await prefs.setString(_prefSubline, subline);
      await prefs.setString(_prefTimeInfo, timeInfo);
      await prefs.setString(_prefCurrentClassTeacher, teacherInfo);
      await prefs.setBool(_prefIsClassLive, isLive);
      await prefs.setBool(_prefIsUrgent, isUrgent);
      await prefs.setInt(_prefProgressPercentage, progressPercentage);
      await prefs.setString(_prefWidgetSubject, finalSubject);
      await prefs.setString(_prefWidgetRoom, finalRoom);
      await prefs.setString(_prefWidgetStartTime, finalStartTime);
      
      // Save to HomeWidget
      await HomeWidget.saveWidgetData<String>(_prefHeadline, headline);
      await HomeWidget.saveWidgetData<String>(_prefSubline, subline);
      await HomeWidget.saveWidgetData<String>(_prefTimeInfo, timeInfo);
      await HomeWidget.saveWidgetData<String>(_prefCurrentClassTeacher, teacherInfo);
      await HomeWidget.saveWidgetData<bool>(_prefIsClassLive, isLive);
      await HomeWidget.saveWidgetData<bool>(_prefIsUrgent, isUrgent);
      await HomeWidget.saveWidgetData<int>(_prefProgressPercentage, progressPercentage);
      await HomeWidget.saveWidgetData<String>(_prefWidgetSubject, finalSubject);
      await HomeWidget.saveWidgetData<String>(_prefWidgetRoom, finalRoom);
      await HomeWidget.saveWidgetData<String>(_prefWidgetStartTime, finalStartTime);
      
      // Request widget update
      await HomeWidget.updateWidget(
        name: 'ClassTrackerWidget',
        iOSName: 'OmniFlowWidget',
        androidName: 'ClassTrackerWidget',
      );
      
      debugPrint('✅ Widget updated with insight: $headline');
    } catch (e) {
      debugPrint('🔥 updateWidgetWithInsight failed: $e');
    }
  }

  /// Update PortalTasksWidget with current assignments/quizzes
  static Future<void> updatePortalTasksWidget(List<PortalTask> tasks) async {
    try {
      final pendingTasks = tasks.where((t) => !t.isCompleted).toList();
      
      // Sort tasks by days remaining (closest due date first)
      pendingTasks.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
      
      final count = pendingTasks.length;
      final urgentCount = pendingTasks.where((t) => t.isUrgent || t.daysRemaining <= 1).length;
      final prefs = await SharedPreferences.getInstance();
      
      // Serialize pending tasks to JSON format for scrollable widget listview
      final List<Map<String, dynamic>> tasksJsonList = pendingTasks.map((t) {
        final daysLeft = t.daysRemaining;
        final String dueStr = daysLeft == 0 
            ? 'Due Today' 
            : daysLeft == 1 
                ? 'Due Tomorrow' 
                : daysLeft > 1 
                    ? 'Due in $daysLeft days' 
                    : 'Overdue by ${daysLeft.abs()} days';
        return {
          'title': t.title,
          'subject': t.subject,
          'due': dueStr,
          'urgent': t.isUrgent || daysLeft <= 1,
          'type': t.type.toUpperCase(),
        };
      }).toList();

      final String serializedJson = jsonEncode(tasksJsonList);
      final String summaryText = count == 0 
          ? '✓ All Tasks Complete' 
          : '$count Pending (${urgentCount > 0 ? "$urgentCount Urgent" : "Normal"})';

      // Save counts, summary, and JSON to local storage and HomeWidget
      await prefs.setInt('flutter.portal_task_count', count);
      await prefs.setString('flutter.portal_tasks_json', serializedJson);
      await prefs.setString('flutter.portal_summary', summaryText);
      
      await HomeWidget.saveWidgetData<int>('flutter.portal_task_count', count);
      await HomeWidget.saveWidgetData<String>('flutter.portal_tasks_json', serializedJson);
      await HomeWidget.saveWidgetData<String>('flutter.portal_summary', summaryText);
      
      // Generate formatted time
      final now = DateTime.now();
      final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final syncText = 'Synced $formattedTime';
      await prefs.setString('flutter.portal_last_sync', syncText);
      await HomeWidget.saveWidgetData<String>('flutter.portal_last_sync', syncText);

      // Request widget update
      await HomeWidget.updateWidget(
        name: 'PortalTasksWidget',
        androidName: 'PortalTasksWidget',
      );
      
      debugPrint('✅ PortalTasksWidget successfully updated with $count pending tasks');
    } catch (e) {
      debugPrint('🔥 updatePortalTasksWidget failed: $e');
    }
  }
}