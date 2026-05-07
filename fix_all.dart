import 'dart:io';

void main() {
  void replaceInFile(String path, Pattern from, String to) {
    if (!File(path).existsSync()) return;
    String content = File(path).readAsStringSync();
    if (content.contains(from)) {
      File(path).writeAsStringSync(content.replaceAll(from, to));
      print('Fixed in ' + path);
    }
  }

  // Fix 1: _TeacherLocatorScreen to TeacherLocatorScreen
  final filesWithTeacherLocator = [
    'lib/main.dart',
    'lib/screens/dashboard_screen.dart',
    'lib/screens/faculty_dashboard_screen.dart'
  ];
  for (var file in filesWithTeacherLocator) {
    replaceInFile(file, '_TeacherLocatorScreen', 'TeacherLocatorScreen');
  }

  // Fix 2: AboutScreen constructor arguments in dashboard and faculty_dashboard
  final oldAboutCall = '''AboutScreen(
          key: const PageStorageKey<String>('student_tab_about'),
          onRoleChanged: widget.onRoleChanged,
          onSetThemeMode: widget.onSetThemeMode,
          currentThemeMode: widget.currentThemeMode,
          showDock: false,
          showCloseButton: false,
        )''';
  final newAboutCallStudent = '''AboutScreen(
          key: const PageStorageKey<String>('student_tab_about'),
          memory: widget.memory,
        )''';
  replaceInFile('lib/screens/dashboard_screen.dart', oldAboutCall, newAboutCallStudent);

  final oldAboutCallFaculty = '''AboutScreen(
          key: const PageStorageKey<String>('faculty_tab_about'),
          onRoleChanged: widget.onRoleChanged,
          onSetThemeMode: widget.onSetThemeMode,
          currentThemeMode: widget.currentThemeMode,
          showDock: false,
          showCloseButton: false,
        )''';
  final newAboutCallFaculty = '''AboutScreen(
          key: const PageStorageKey<String>('faculty_tab_about'),
          memory: widget.brain.memory,
        )''';
  replaceInFile('lib/screens/faculty_dashboard_screen.dart', oldAboutCallFaculty, newAboutCallFaculty);

  // Fix 3: about_screen.dart checkStatus undefined
  replaceInFile('lib/screens/about_screen.dart', 'TimetableOTAService.checkStatus()', 'TimetableOTAService.checkUpdates(widget.memory)');
  replaceInFile('lib/screens/about_screen.dart', 'Icons.Settings_outlined', 'Icons.settings_outlined');
  replaceInFile('lib/screens/about_screen.dart', 'activeColor:', 'activeTrackColor:');
  
  // Fix 4: Add LectureDuration to OmniBrain where it logically belongs, or import it.
  // We'll just define class LectureDuration in core/models.dart because it takes a ClassSession.
  String modelsData = File('lib/core/models.dart').readAsStringSync();
  if (!modelsData.contains('class LectureDuration')) {
    File('lib/core/models.dart').writeAsStringSync(modelsData + '''

// Lightweight compatibility helper
class LectureDuration {
  static double getActualDuration(ClassSession session) {
    return (session.safeEndVal - session.safeStartVal).abs();
  }
  static double getActualEndTime(ClassSession session) {
    return session.safeEndVal;
  }
}
''');
  }

  // Remove the duplicate LectureDuration from faculty_dashboard_screen.dart
  replaceInFile('lib/screens/faculty_dashboard_screen.dart', '''// Lightweight compatibility helpers copied here to avoid circular imports.
class LectureDuration {
  static double getActualDuration(ClassSession session) {
    return (session.safeEndVal - session.safeStartVal).abs();
  }

  static double getActualEndTime(ClassSession session) {
    return session.safeEndVal;
  }
}''', '');
  
  // Fix NotificationService. It is used as wait NotificationService().scheduleClassReminders(todayClasses);
  // we add it to lib/services/notification_service.dart.
  String notifService = File('lib/services/notification_service.dart').readAsStringSync();
  if (!notifService.contains('class NotificationService')) {
    File('lib/services/notification_service.dart').writeAsStringSync(notifService + '''

class NotificationService {
  Future<void> scheduleClassReminders(List<dynamic> classes) async {
    // Stub implementation
  }
}
''');
  }
}
