import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/format_guard.dart';
import 'core/animations.dart';
import 'core/models.dart';
import 'core/omni_brain.dart';
import 'core/university_memory.dart';
import 'portal_screen.dart';
import 'services/helpdesk_campus_feed_service.dart';
import 'services/helpdesk_faculty_service.dart';
import 'services/helpdesk_schedule_data_service.dart';
import 'services/timetable_ota_service.dart';
import 'services/ui_feedback.dart';
import 'widget_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:open_filex/open_filex.dart';

const MethodChannel _notificationChannel = MethodChannel(
  'iris/notification_channel',
);

class IrisTokens {
  static const Color brand = Color(0xFF5B7FFF);
  static const Color brandLight = Color(0xFF8BB5FF);
  static const Color brandDark = Color(0xFF4259D6);
  static const Color surfaceDark = Color(0xFF11131A);
  static const Color surfaceLightElevated = Color(0xFFFFFFFF);
  static const List<Color> brandGradient = [brand, brandLight];

  static const List<Color> sunsetGradient = [
    Color(0xFFFF6B9D),
    Color(0xFFC239B3),
  ];
  static const List<Color> oceanGradient = [
    Color(0xFF00C9FF),
    Color(0xFF92FE9D),
  ];
  static const List<Color> successGradient = [
    Color(0xFF00E5A0),
    Color(0xFF00D9F5),
  ];

  // Surface Colors - Depth & Layers
  static const Color surfaceLight = Color(0xFFF5F7FE);
  static const Color surfaceDarkElevated = Color(0xFF1A1A24);

  // Semantic Colors - Vibrant
  static const Color success = Color(0xFF00E5A0);
  static const Color successDark = Color(0xFF00D9F5);
  static const Color warning = Color(0xFFFFB800);
  static const Color warningDark = Color(0xFFFF8A00);
  static const Color error = Color(0xFFFF6B6B);
  static const Color errorDark = Color(0xFFFF4757);
  static const Color info = Color(0xFF5B7FFF);

  // Accent Colors - Playful & Expressive
  static const Color purple = Color(0xFF8B6EFF);
  static const Color purpleLight = Color(0xFFB794F6);
  static const Color blue = Color(0xFF5B9EFF);
  static const Color blueLight = Color(0xFF8BB5FF);
  static const Color pink = Color(0xFFFF6B9D);
  static const Color pinkLight = Color(0xFFFFB3C6);
  static const Color teal = Color(0xFF00D9F5);
  static const Color tealLight = Color(0xFF7FEFFF);

  static const String fontFamily = 'SF Pro Display';

  // Spacing
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;

  // Radius
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radius28 = 28.0;
  static const double radius32 = 32.0;
  static const double radius36 = 36.0;
  static const double radiusFull = 9999.0;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(28));
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(24),
  );
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(20));

  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );
}

class IrisTextStyles {
  static TextStyle display(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w200,
      letterSpacing: -0.5,
      height: 1.1,
      color: isDark ? Colors.white : Colors.black,
    );
  }

  static TextStyle title(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w300,
      letterSpacing: 0.5,
      height: 1.2,
      color: isDark ? Colors.white : Colors.black,
    );
  }

  static TextStyle headline(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      height: 1.3,
      color: isDark ? Colors.white : Colors.black,
    );
  }

  static TextStyle body(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.1,
      height: 1.5,
      color: isDark
          ? Colors.white.withValues(alpha: 0.88)
          : Colors.black.withValues(alpha: 0.87),
    );
  }

  static TextStyle label(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      height: 1.4,
      color: isDark
          ? Colors.white.withValues(alpha: 0.82)
          : Colors.black.withValues(alpha: 0.78),
    );
  }

  static TextStyle caption(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      height: 1.3,
      color: isDark
          ? Colors.white.withValues(alpha: 0.64)
          : Colors.black.withValues(alpha: 0.6),
    );
  }

  static TextStyle overline(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      height: 1.2,
      color: isDark
          ? Colors.white.withValues(alpha: 0.58)
          : Colors.black.withValues(alpha: 0.54),
    );
  }
}

class IrisElevation {
  static List<BoxShadow> level1(Color color, {bool isDark = false}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        offset: const Offset(0, 2),
        blurRadius: 8,
        spreadRadius: -2,
      ),
    ];
  }

  static List<BoxShadow> level2(Color color, {bool isDark = false}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
        offset: const Offset(0, 6),
        blurRadius: 18,
        spreadRadius: -6,
      ),
    ];
  }

  static List<BoxShadow> level3(Color color, {bool isDark = false}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.24),
        offset: const Offset(0, 10),
        blurRadius: 30,
        spreadRadius: -12,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.17 : 0.06),
        offset: const Offset(0, 4),
        blurRadius: 14,
      ),
    ];
  }

  static List<BoxShadow> level4(Color color, {bool isDark = false}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.30),
        offset: const Offset(0, 16),
        blurRadius: 44,
        spreadRadius: -16,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
        offset: const Offset(0, 6),
        blurRadius: 18,
      ),
    ];
  }
}

// Component Builders
class IrisComponents {
  /// Build a status badge (LIVE, NEXT, etc.)
  static Widget statusBadge({
    required String label,
    required Color color,
    required bool isDark,
    bool pulse = false,
  }) {
    final widget = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: IrisTokens.space12,
        vertical: IrisTokens.space8 - 2,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(IrisTokens.radius12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );

    if (pulse) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1.05),
        duration: const Duration(milliseconds: 768),
        curve: IrisMotion.standard,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        onEnd: () {},
        child: widget,
      );
    }

    return widget;
  }

  /// Build a time badge
  static Widget timeBadge({required String time, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: IrisTokens.space12,
        vertical: IrisTokens.space8 - 2,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(IrisTokens.radius12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.black.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Text(
        time,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w700,
          height: 1.0,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.86),
        ),
      ),
    );
  }

  /// Build an icon badge
  static Widget iconBadge({
    required IconData icon,
    required Color color,
    required bool isDark,
    double size = 32,
  }) {
    return Container(
      padding: EdgeInsets.all(size * 0.25),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.32 : 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Icon(icon, size: size * 0.65, color: color),
    );
  }

  /// Build a loading spinner
  static Widget loadingSpinner({
    Color? color,
    double size = 24,
    double strokeWidth = 2.0,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: color != null ? AlwaysStoppedAnimation<Color>(color) : null,
      ),
    );
  }
}

class IrisMotion {
  static const Duration fast = Duration(milliseconds: 176);
  static const Duration normal = Duration(milliseconds: 288);
  static const Duration medium = Duration(milliseconds: 432);
  static const Duration slow = Duration(milliseconds: 720);

  // Global performance toggles for low-jank rendering on large widget trees.
  static const bool reduceMotion = false;
  static const bool reduceBlur = true;

  static const Curve entrance = Cubic(0.18, 0.88, 0.22, 1.0);
  static const Curve standard = Cubic(0.2, 0.82, 0.2, 1.0);
  static const Curve emphasized = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve bouncy = Cubic(0.3, 1.35, 0.45, 1.0);
}

// UI feedback classes moved to services/ui_feedback.dart
// Imported above as:
// import 'services/ui_feedback.dart';

class IrisTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: IrisTokens.brand,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: IrisTokens.surfaceLight,
      fontFamily: IrisTokens.fontFamily,
      pageTransitionsTheme: IrisTokens.pageTransitions,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashColor: IrisTokens.brand.withValues(alpha: 0.08),
      highlightColor: IrisTokens.brand.withValues(alpha: 0.05),
      dividerColor: Colors.black.withValues(alpha: 0.05),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black.withValues(alpha: 0.90),
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ).copyWith(color: Colors.black.withValues(alpha: 0.90)),
        iconTheme: IconThemeData(
          color: Colors.black.withValues(alpha: 0.75),
          size: 26,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IrisTokens.radius28),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IrisTokens.radius32),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ).copyWith(color: Colors.black.withValues(alpha: 0.90)),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.6,
        ).copyWith(color: Colors.black.withValues(alpha: 0.70)),
      ),
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white.withValues(alpha: 0.90),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.90),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.90),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IrisTokens.radius20),
        ),
        side: BorderSide(
          color: IrisTokens.brand.withValues(alpha: 0.24),
          width: 1.5,
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        selectedColor: IrisTokens.brand.withValues(alpha: 0.26),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ).copyWith(color: Colors.black.withValues(alpha: 0.72)),
        secondaryLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ).copyWith(color: IrisTokens.brand),
        padding: const EdgeInsets.symmetric(
          horizontal: IrisTokens.space12,
          vertical: IrisTokens.space8,
        ),
        elevation: 0,
        pressElevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(IrisTokens.radius24),
          ),
          elevation: 0,
          shadowColor: IrisTokens.brand.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(
            horizontal: IrisTokens.space24,
            vertical: IrisTokens.space20,
          ),
          backgroundColor: IrisTokens.brand,
          foregroundColor: Colors.white,
          animationDuration: const Duration(milliseconds: 192),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: IrisTokens.brandDark,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: IrisTokens.surfaceDark,
      brightness: Brightness.dark,
      fontFamily: IrisTokens.fontFamily,
      pageTransitionsTheme: IrisTokens.pageTransitions,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashColor: IrisTokens.brandDark.withValues(alpha: 0.14),
      highlightColor: IrisTokens.brandDark.withValues(alpha: 0.08),
      dividerColor: Colors.white.withValues(alpha: 0.06),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white.withValues(alpha: 0.95),
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ).copyWith(color: Colors.white.withValues(alpha: 0.95)),
        iconTheme: IconThemeData(
          color: Colors.white.withValues(alpha: 0.85),
          size: 26,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IrisTokens.radius28),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: IrisTokens.surfaceDarkElevated.withValues(alpha: 0.98),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IrisTokens.radius32),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ).copyWith(color: Colors.white.withValues(alpha: 0.95)),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.6,
        ).copyWith(color: Colors.white.withValues(alpha: 0.80)),
      ),
      snackBarTheme: const SnackBarThemeData(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF111827).withValues(alpha: 0.90),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            const Color(0xFF111827).withValues(alpha: 0.90),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            const Color(0xFF111827).withValues(alpha: 0.90),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IrisTokens.radius20),
        ),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.26),
          width: 1.5,
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.22),
        selectedColor: IrisTokens.brandDark.withValues(alpha: 0.42),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ).copyWith(color: Colors.white.withValues(alpha: 0.85)),
        secondaryLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ).copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(
          horizontal: IrisTokens.space12,
          vertical: IrisTokens.space8,
        ),
        elevation: 0,
        pressElevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: IrisTokens.buttonRadius,
          ),
          elevation: 0,
          shadowColor: IrisTokens.brandDark.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(
            horizontal: IrisTokens.space20,
            vertical: IrisTokens.space16,
          ),
          backgroundColor: IrisTokens.brandDark,
          foregroundColor: Colors.white,
          animationDuration: const Duration(milliseconds: 192),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ============ LECTURE DURATION HELPER ============
/// Helper to calculate actual lecture duration accounting for "(1 hr)" markers
class LectureDuration {
  /// Check if a subject is marked as a 1-hour lecture
  static bool isOneHourLecture(String subject) {
    return subject.toLowerCase().contains('(1 hr)') ||
        subject.toLowerCase().contains('(1hr)') ||
        subject.toLowerCase().contains('1 hr)');
  }

  /// Get the actual duration of a lecture in decimal hours
  /// Returns 1.0 for 1-hour lectures, otherwise the full slot duration
  static double getActualDuration(ClassSession session) {
    if (isOneHourLecture(session.subject)) {
      return 1.0; // 1 hour in decimal time
    }
    return session.safeEndVal - session.safeStartVal;
  }

  /// Get the actual end time of a lecture
  /// For 1-hour lectures, returns startTime + 1 hour instead of the slot end time
  static double getActualEndTime(ClassSession session) {
    if (isOneHourLecture(session.subject)) {
      return session.safeStartVal + 1.0;
    }
    return session.safeEndVal;
  }
}

// ============ FOREGROUND TASK HANDLER ============
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
          print(
            '⚠️ Faculty mode but no teacher - showing default notification',
          );
          notifBody = 'Select a teacher to view your schedule';
          FlutterForegroundTask.updateService(
            notificationTitle: notifTitle,
            notificationText: notifBody,
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
          return;
        }
        if (role == 'student' && (batch == null || batch.isEmpty)) {
          print('⚠️ Student mode but no batch - showing default notification');
          notifBody = 'Select a batch to view your schedule';
          FlutterForegroundTask.updateService(
            notificationTitle: notifTitle,
            notificationText: notifBody,
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
          return;
        }

        if (timetableJson == null) {
          print('⚠️ Foreground task: Missing timetable data');
          FlutterForegroundTask.updateService(
            notificationTitle: role == 'faculty'
                ? 'IRIS Faculty Tracker'
                : 'IRIS Class Tracker',
            notificationText: 'No schedule data available • Open app to reload',
            notificationButtons: [
              NotificationButton(id: 'open', text: 'Open IRIS'),
            ],
          );
          return;
        }

        // Parse timetable data
        final data = jsonDecode(timetableJson) as Map<String, dynamic>;
        final rawSessions = (data['sessions'] as List)
            .map((s) => ClassSession.fromJson(s))
            .where(
              (s) => role == 'faculty'
                  ? s.teacher.trim().toLowerCase() ==
                        teacherName!.trim().toLowerCase()
                  : s.batchKey.batch == batch,
            )
            .toList();

        // Merge consecutive sessions (same subject/teacher/room back-to-back)
        final sorted = List<ClassSession>.from(rawSessions)
          ..sort((a, b) {
            final d = a.dayIndex.compareTo(b.dayIndex);
            return d != 0 ? d : a.safeStartVal.compareTo(b.safeStartVal);
          });
        final sessions = <ClassSession>[];
        ClassSession? merging;
        for (final s in sorted) {
          if (merging == null) {
            merging = s;
            continue;
          }
          if (merging.isConsecutiveWith(s)) {
            merging = ClassSession(
              id: merging.id,
              batchKey: merging.batchKey,
              dayIndex: merging.dayIndex,
              startTime: merging.startTime,
              endTime: s.endTime,
              subject: merging.subject,
              teacher: merging.teacher,
              room: merging.room,
            );
          } else {
            sessions.add(merging);
            merging = s;
          }
        }
        if (merging != null) sessions.add(merging);

        // Calculate current/next class
        final now = DateTime.now();
        final currentTime = now.hour + (now.minute / 60.0);
        final dayIndex = now.weekday;
        double actualEndFor(ClassSession s) => LectureDuration.getActualEndTime(s);

        ClassSession? current;
        ClassSession? next;

        for (var session in sessions) {
          final actualEnd = actualEndFor(session);
          if (session.dayIndex == dayIndex &&
              currentTime >= session.safeStartVal &&
              currentTime < actualEnd) {
            current = session;
            break;
          }
        }

        if (current == null) {
          // Find next class: today (later) or next days (with week wrapping)
          for (var session in sessions) {
            if (session.dayIndex == dayIndex &&
                currentTime < session.safeStartVal) {
              // Later today
              if (next == null ||
                  session.dayIndex < next.dayIndex ||
                  (session.dayIndex == next.dayIndex &&
                      session.safeStartVal < next.safeStartVal)) {
                next = session;
              }
            }
          }
          if (next == null) {
            // Search upcoming days (wrap around week)
            for (int daysAhead = 1; daysAhead <= 6; daysAhead++) {
              final checkDay = ((dayIndex + daysAhead - 1) % 7) + 1;
              final candidates =
                  sessions.where((s) => s.dayIndex == checkDay).toList()
                    ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
              if (candidates.isNotEmpty) {
                next = candidates.first;
                break;
              }
            }
          }
        }

        String nativeLine1 = notifBody;
        String nativeLine2 = '';
        int nativeProgress = 0;
        bool nativeIsLive = false;

        // Build an animated, colored progress indicator
        String _progressBar(double p) {
          const total = 8;
          final filled = (p * total).round().clamp(0, total);
          // Use colored square emojis for a glowing, animated look
          final progressEmoji = '🟦'; // filled blue
          final emptyEmoji = '⬜'; // empty white
          return progressEmoji * filled + emptyEmoji * (total - filled);
        }

        String _formatStart(double val) {
          final hour = val.floor();
          final minute = ((val - hour) * 60).round();
          final displayHour = hour % 12 == 0 ? 12 : hour % 12;
          final amPm = hour >= 12 ? 'PM' : 'AM';
          return '$displayHour:${minute.toString().padLeft(2, '0')} $amPm';
        }

        // Count total classes today
        final todayAll = sessions.where((s) => s.dayIndex == dayIndex).toList();

        if (current != null) {
          final duration = LectureDuration.getActualDuration(current);
          final actualEndTime = LectureDuration.getActualEndTime(current);
          final progress = ((currentTime - current.safeStartVal) / duration)
              .clamp(0.0, 1.0);
          final progressPercent = (progress * 100).toInt();

          // Calculate time remaining based on actual lecture duration
          final minutesRemaining = ((actualEndTime - currentTime) * 60)
              .round()
              .clamp(0, (duration * 60).round());
          final hoursRemaining = minutesRemaining ~/ 60;
          final minsRemaining = minutesRemaining % 60;

          String timeLeft = '';
          if (hoursRemaining > 0) {
            timeLeft = '${hoursRemaining}h ${minsRemaining}m left';
          } else if (minsRemaining > 0) {
            timeLeft = '${minsRemaining}m left';
          } else {
            timeLeft = 'Ending now';
          }

          // Smart status with animated progress bar and glow effect
          final bar = _progressBar(progress);
          final remaining = todayAll
              .where((s) => s.safeStartVal > currentTime)
              .length;
          final classCount = remaining > 0
              ? ' • $remaining more today'
              : ' • Last one';

          ClassSession? nextAfterCurrent;
          for (final session in todayAll) {
            if (session.safeStartVal > currentTime) {
              if (nextAfterCurrent == null ||
                  session.safeStartVal < nextAfterCurrent.safeStartVal) {
                nextAfterCurrent = session;
              }
            }
          }
          final nextLine = nextAfterCurrent == null
              ? ''
              : ' • Next: ${nextAfterCurrent.subject} ${_formatStart(nextAfterCurrent.safeStartVal)}';

          final statusLine = 'Now • ${current.room} • $timeLeft$classCount';
          final batchLine = role == 'faculty'
              ? '📚 ${current.batchKey.batch}$nextLine'
              : '👤 ${current.teacher}$nextLine';
          notifTitle = '🎓 ${current.subject}';
          notifBody = '$statusLine\n$bar $progressPercent% • $batchLine';
          nativeLine1 = statusLine;
          nativeLine2 = batchLine;
          nativeProgress = progressPercent;
          nativeIsLive = true;
        } else if (next != null) {
          // Calculate time until next class, handling multi-day gaps
          int daysAhead = 0;
          if (next.dayIndex != dayIndex) {
            daysAhead = (next.dayIndex - dayIndex + 7) % 7;
            if (daysAhead == 0) daysAhead = 7;
          }
          final totalMinutesUntil = daysAhead > 0
              ? ((24.0 - currentTime) * 60 +
                        (daysAhead - 1) * 24 * 60 +
                        next.safeStartVal * 60)
                    .round()
              : ((next.safeStartVal - currentTime) * 60).round();
          final hoursUntil = totalMinutesUntil ~/ 60;
          final minsUntil = totalMinutesUntil % 60;

          String timeUntil = '';
          String emoji = '📌';
          if (daysAhead > 0) {
            const dayNames = [
              '',
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ];
            final nextDayName = dayNames[next.dayIndex];
            final startHour = next.safeStartVal.floor();
            final startMin = ((next.safeStartVal - startHour) * 60).round();
            final displayHour = startHour > 12 ? startHour - 12 : startHour;
            final amPm = startHour >= 12 ? 'PM' : 'AM';
            timeUntil =
                '$nextDayName ${displayHour}:${startMin.toString().padLeft(2, '0')} $amPm';
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

          // Count remaining classes today
          final remainingToday = sessions
              .where(
                (s) => s.dayIndex == dayIndex && s.safeStartVal > currentTime,
              )
              .length;

          // Smart break info
          String breakInfo = '';
          if (daysAhead == 0) {
            // Calculate break duration until next
            // Find previous class end time
            final prevClasses = todayAll
                .where((s) => actualEndFor(s) <= currentTime)
                .toList();
            if (prevClasses.isNotEmpty) {
              prevClasses.sort(
                (a, b) => actualEndFor(b).compareTo(actualEndFor(a)),
              );
              final breakMins =
                  ((next.safeStartVal - actualEndFor(prevClasses.first)) * 60)
                      .round();
              if (breakMins > 0 && breakMins < 180) {
                breakInfo = ' · ${breakMins}m break';
              }
            }
          }

          String classInfo;
          if (daysAhead > 0) {
            classInfo = 'Done for today ✓';
          } else if (remainingToday > 1) {
            classInfo = '$remainingToday classes left';
          } else {
            classInfo = 'Last class today';
          }

          notifTitle = '$emoji ${next.subject} • $timeUntil';
          final nextBatchLine = role == 'faculty'
              ? '📚 ${next.batchKey.batch} • $classInfo$breakInfo'
              : '👤 ${next.teacher} • $classInfo$breakInfo';
          notifBody = 'Up next • ${next.room}\n$nextBatchLine';
          nativeLine1 = 'Up next • ${next.room}';
          nativeLine2 = nextBatchLine;
          nativeProgress = 0;
          nativeIsLive = false;
        } else {
          // Check what day it is for smarter idle message
          final weekday = DateTime.now().weekday;
          if (weekday == 6 || weekday == 7) {
            notifTitle = '🌤 Weekend Mode';
            notifBody = 'No classes • recharge and relax';
          } else {
            notifTitle = '✅ All done for today';
            notifBody = 'No more classes • see you tomorrow';
          }
          nativeLine1 = notifBody;
          nativeLine2 = '';
          nativeProgress = 0;
          nativeIsLive = false;
        }

        FlutterForegroundTask.updateService(
          notificationTitle: notifTitle,
          notificationText: notifBody,
          notificationButtons: [
            NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
        );

        if (Platform.isAndroid) {
          try {
            _notificationChannel
                .invokeMethod('updateNotification', {
                  'title': notifTitle,
                  'line1': nativeLine1,
                  'line2': nativeLine2,
                  'progress': nativeProgress,
                  'isLive': nativeIsLive,
                })
                .catchError((_) {});
          } catch (_) {}
        }
      } catch (e) {
        print('⚠️ Foreground task error: $e');
        FlutterForegroundTask.updateService(
          notificationTitle: 'IRIS Class Tracker',
          notificationText: 'Error loading schedule • Open app to reload',
          notificationButtons: [
            NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
        );
        if (Platform.isAndroid) {
          try {
            _notificationChannel
                .invokeMethod('updateNotification', {
                  'title': 'IRIS Class Tracker',
                  'line1': 'Error loading schedule • Open app to reload',
                  'line2': '',
                  'progress': 0,
                  'isLive': false,
                })
                .catchError((_) {});
          } catch (_) {}
        }
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Save state before destruction
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_service_stop', timestamp.millisecondsSinceEpoch);
      print('📌 Foreground service stopped at $timestamp');
    } catch (e) {
      print('⚠️ Error saving service state: $e');
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'open') {
      FlutterForegroundTask.launchApp("/");
    }
  }

  @override
  void onNotificationPressed() {
    // Open app when notification is tapped
    FlutterForegroundTask.launchApp("/");
  }
}

// ============ NOTIFICATION SERVICE ============
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static const String _classReminderPayload = 'class_reminder';
  static const String _classReminderSignatureKey =
      'class_reminder_signature';

  factory NotificationService() {
    return _instance;
  }

  NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isSchedulingReminders = false;

  Future<void> init() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(initSettings);

      // Request Android 13+ notification permission
      if (Platform.isAndroid) {
        final plugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await plugin?.requestNotificationsPermission();
        await plugin?.requestExactAlarmsPermission();
      }
      
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('⚠️ Notification service init failed (non-critical): $e');
      // Continue anyway
    }
  }

  Future<void> showClassReminder({
    required String subject,
    required String teacher,
    required String room,
    required String timeUntil,
  }) async {
    final bigText = BigTextStyleInformation(
      '$subject with $teacher in $room ($timeUntil)',
      contentTitle: '⏰ Class Starting',
      summaryText: 'IRIS',
    );
    final androidDetails = AndroidNotificationDetails(
      'class_reminder_channel',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      styleInformation: bigText,
      color: IrisTokens.brand,
      colorized: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecond,
      '⏰ Class Starting',
      '$subject with $teacher in $room ($timeUntil)',
      platformDetails,
      payload: _classReminderPayload,
    );
  }

  Future<void> cancelScheduledClassReminders() async {
    try {
      final pending = await _localNotifications.pendingNotificationRequests();
      for (final req in pending) {
        if (req.payload == _classReminderPayload) {
          await _localNotifications.cancel(req.id);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_classReminderSignatureKey);
    } catch (e) {
      debugPrint('⚠️ Failed to cancel class reminders: $e');
    }
  }

  // Schedule notifications for upcoming classes (run periodically)
  Future<void> scheduleClassReminders(List<ClassSession> sessions) async {
    if (_isSchedulingReminders) {
      return;
    }

    _isSchedulingReminders = true;
    final now = DateTime.now();
    try {
      final reminderKeys = sessions
          .map(_sessionReminderKey)
          .toList()
        ..sort();
      final signature = reminderKeys.join('|');
      final prefs = await SharedPreferences.getInstance();
      final previousSignature = prefs.getString(_classReminderSignatureKey);

      if (previousSignature == signature) {
        return;
      }

      await cancelScheduledClassReminders();

      for (final session in sessions) {
        // Parse time from session (e.g., "09:00")
        final parts = session.startTime.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        // Compute the next valid occurrence, then set reminder 5 minutes before.
        final classDateTime = _nextWeeklyOccurrence(
          now: now,
          weekday: session.dayIndex,
          hour: hour,
          minute: minute,
        );

        // Schedule notification 5 minutes before class
        final notifyTime = classDateTime.subtract(const Duration(minutes: 5));

        if (notifyTime.isAfter(now)) {
          try {
            final bigText = BigTextStyleInformation(
              '${session.subject} with ${session.teacher} in ${session.room}',
              contentTitle: '⏰ Class in 5 minutes',
              summaryText: 'IRIS',
            );
            final androidDetails = AndroidNotificationDetails(
              'class_reminder_channel',
              'Class Reminders',
              channelDescription: 'Notifications for upcoming classes',
              importance: Importance.high,
              priority: Priority.high,
              enableVibration: true,
              styleInformation: bigText,
              color: IrisTokens.brand,
              colorized: true,
              category: AndroidNotificationCategory.reminder,
              visibility: NotificationVisibility.public,
            );

            final platformDetails = NotificationDetails(android: androidDetails);

            await _localNotifications.zonedSchedule(
              _stableReminderNotificationId(session),
              '⏰ Class in 5 minutes',
              '${session.subject} with ${session.teacher} in ${session.room}',
              tz.TZDateTime.from(notifyTime, tz.local),
              platformDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: _classReminderPayload,
            );
          } catch (e) {
            // Silently handle scheduling errors
          }
        }
      }

      await prefs.setString(_classReminderSignatureKey, signature);
    } finally {
      _isSchedulingReminders = false;
    }
  }

  String _sessionReminderKey(ClassSession session) {
    return '${session.batchKey.batch}|${session.dayIndex}|${session.startTime}|'
        '${session.subject}|${session.teacher}|${session.room}';
  }

  int _stableReminderNotificationId(ClassSession session) {
    final key = _sessionReminderKey(session);
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return hash;
  }

  DateTime _nextWeeklyOccurrence({
    required DateTime now,
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final todayAtTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    final daysAhead = (weekday - now.weekday + 7) % 7;
    var candidate = todayAtTime.add(Duration(days: daysAhead));

    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }

    return candidate;
  }

  Future<void> syncClassRemindersFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('lecture_reminders_enabled') ?? false;

    await cancelScheduledClassReminders();
    if (!enabled) return;

    final timetableJson = prefs.getString('timetable_data');
    if (timetableJson == null || timetableJson.isEmpty) return;

    try {
      final role = prefs.getString('user_role') ?? 'student';
      final batch = prefs.getString('student_batch');
      final teacher = prefs.getString('faculty_teacher');
      final data = jsonDecode(timetableJson) as Map<String, dynamic>;
      final all = (data['sessions'] as List<dynamic>)
          .map((s) => ClassSession.fromJson(s as Map<String, dynamic>))
          .toList();

      final today = DateTime.now().weekday;
      final sessions = all.where((s) {
        if (s.dayIndex != today) return false;
        if (role == 'faculty') {
          return teacher != null &&
              teacher.isNotEmpty &&
              s.teacher.trim().toLowerCase() == teacher.trim().toLowerCase();
        }
        return batch != null && batch.isNotEmpty && s.batchKey.batch == batch;
      }).toList();

      if (sessions.isNotEmpty) {
        await scheduleClassReminders(sessions);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to sync class reminders from prefs: $e');
    }
  }

  // Update persistent notification showing current/next class
  // Update persistent notification showing current/next class
  Future<void> updatePersistentNotification({
    required String title,
    required String body,
    bool isOngoing = true,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'persistent_class_channel',
        'Current Class',
        channelDescription: 'Shows current or next class information',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        enableVibration: false,
        playSound: false,
        ongoing: true, // Always ongoing to prevent dismissal
        autoCancel: false, // Never auto-cancel
        showWhen: true, // Show timestamp
        usesChronometer: false,
        color: IrisTokens.brand, // Brand color
        colorized: false,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
        ticker: title, // For accessibility
      );

      final platformDetails = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        999, // Fixed ID for persistent notification
        title,
        body,
        platformDetails,
        payload: 'persistent_class',
      );
    } catch (e) {
      debugPrint('⚠️ Persistent notification update failed: $e');
    }
  }

  // Dismiss persistent notification
  Future<void> dismissPersistentNotification() async {
    try {
      await _localNotifications.cancel(999);
    } catch (e) {
      debugPrint('⚠️ Failed to dismiss persistent notification: $e');
    }
  }

  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}

final Map<String, int> _irisSnackLastShownMs = <String, int>{};
OverlayEntry? _irisPillOverlayEntry;
Timer? _irisPillExpandTimer;
Timer? _irisPillContentTimer;
Timer? _irisPillCollapseTimer;
Timer? _irisPillDotTimer;
Timer? _irisPillDotPulseTimer;
Timer? _irisPillFadeTimer;
Timer? _irisPillDisposeTimer;

void _clearIrisPillOverlay() {
  _irisPillExpandTimer?.cancel();
  _irisPillContentTimer?.cancel();
  _irisPillCollapseTimer?.cancel();
  _irisPillDotTimer?.cancel();
  _irisPillDotPulseTimer?.cancel();
  _irisPillFadeTimer?.cancel();
  _irisPillDisposeTimer?.cancel();
  _irisPillExpandTimer = null;
  _irisPillContentTimer = null;
  _irisPillCollapseTimer = null;
  _irisPillDotTimer = null;
  _irisPillDotPulseTimer = null;
  _irisPillFadeTimer = null;
  _irisPillDisposeTimer = null;

  _irisPillOverlayEntry?.remove();
  _irisPillOverlayEntry = null;
}

String _extractIrisSnackText(Widget widget) {
  if (widget is Text) {
    return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }
  if (widget is RichText) {
    return widget.text.toPlainText();
  }
  if (widget is DefaultTextStyle) {
    return _extractIrisSnackText(widget.child);
  }
  if (widget is Expanded) {
    return _extractIrisSnackText(widget.child);
  }
  if (widget is Flexible) {
    return _extractIrisSnackText(widget.child);
  }
  if (widget is Padding) {
    final child = widget.child;
    if (child != null) {
      return _extractIrisSnackText(child);
    }
    return '';
  }
  if (widget is SizedBox && widget.child != null) {
    return _extractIrisSnackText(widget.child!);
  }
  if (widget is Row) {
    return widget.children.map(_extractIrisSnackText).where((s) => s.isNotEmpty).join(' ');
  }
  if (widget is Column) {
    return widget.children
        .map(_extractIrisSnackText)
        .where((s) => s.isNotEmpty)
        .join(' ');
  }
  if (widget is Wrap) {
    return widget.children
        .map(_extractIrisSnackText)
        .where((s) => s.isNotEmpty)
        .join(' ');
  }
  return '';
}

String _compactIrisSnackText(String raw) {
  final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return 'Updated';
  if (compact.length <= 62) return compact;
  return '${compact.substring(0, 59)}...';
}

void _showIrisTopPill(
  BuildContext context, {
  required String text,
  Duration duration = const Duration(seconds: 3),
  Color? tint,
  SnackBarAction? action,
  bool clearExisting = true,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      _showIrisTopPill(
        context,
        text: text,
        duration: duration,
        tint: tint,
        action: action,
        clearExisting: clearExisting,
      );
    });
    return;
  }

  if (clearExisting) {
    _clearIrisPillOverlay();
  }

  final tone = tint ?? Colors.white;

  bool expanded = false;
  bool contentVisible = false;
  bool collapsing = false;
  bool dotMode = false;
  bool dotPulse = false;
  bool visible = true;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) {
      final media = MediaQuery.of(overlayContext);
      final availableWidth = media.size.width - 24;
      final targetWidth = math.min(
        346.0,
        math.max(152.0, 66.0 + (text.length * 6.0)),
      ).clamp(108.0, availableWidth);

      final width = dotMode
          ? 10.0
          : (collapsing
            ? 44.0
                : (expanded ? targetWidth.toDouble() : 30.0));
      final height = dotMode ? 10.0 : 40.0;
        final scale = dotMode
          ? (dotPulse ? 1.08 : 0.88)
          : (expanded ? 1.0 : 0.86);
        final cornerRadius = dotMode
          ? 999.0
          : (collapsing ? 16.0 : 24.0);

      return Positioned(
        top: media.padding.top + 6,
        left: 0,
        right: 0,
        child: IgnorePointer(
          ignoring: dotMode,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOutCubic,
            opacity: visible ? 1 : 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              offset: visible ? Offset.zero : const Offset(0, -0.18),
              child: Center(
                child: GestureDetector(
                  onTap: action != null
                      ? () {
                          IrisSfx.pillTap();
                          action.onPressed();
                        }
                      : null,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.fastOutSlowIn,
                    scale: scale,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.fastOutSlowIn,
                      width: width,
                      height: height,
                      padding: dotMode
                          ? EdgeInsets.zero
                          : const EdgeInsets.symmetric(horizontal: 14),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF10131A).withValues(alpha: 0.96),
                            const Color(0xFF07080D).withValues(alpha: 0.92),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(cornerRadius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.46),
                            blurRadius: 24,
                            spreadRadius: -8,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: tone.withValues(alpha: dotMode ? 0.0 : 0.16),
                            blurRadius: 14,
                            spreadRadius: -8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: dotMode
                            ? const SizedBox.shrink(key: ValueKey('dot'))
                            : AnimatedOpacity(
                                key: const ValueKey('pill'),
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                opacity: (contentVisible && !collapsing) ? 1 : 0,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: tone.withValues(alpha: 0.92),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: tone.withValues(alpha: 0.55),
                                            blurRadius: 8,
                                            spreadRadius: -1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.18,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                    if (action != null)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.18),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          action.label,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.14,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _irisPillOverlayEntry = entry;
  overlay.insert(entry);

  void mark() {
    _irisPillOverlayEntry?.markNeedsBuild();
  }

  _irisPillExpandTimer = Timer(const Duration(milliseconds: 16), () {
    expanded = true;
    mark();
  });

  _irisPillContentTimer = Timer(const Duration(milliseconds: 120), () {
    contentVisible = true;
    mark();
  });

  final adaptiveHoldMs = (900 + (text.length * 22)).clamp(1200, 3400);
  final holdMs = math.min(duration.inMilliseconds, adaptiveHoldMs).clamp(
    1100,
    3400,
  );
  _irisPillCollapseTimer = Timer(Duration(milliseconds: holdMs), () {
    collapsing = true;
    contentVisible = false;
    mark();
  });

  _irisPillDotTimer = Timer(Duration(milliseconds: holdMs + 220), () {
    dotMode = true;
    mark();
  });

  _irisPillDotPulseTimer = Timer(Duration(milliseconds: holdMs + 280), () {
    dotPulse = true;
    mark();
  });

  _irisPillFadeTimer = Timer(Duration(milliseconds: holdMs + 340), () {
    visible = false;
    mark();
  });

  _irisPillDisposeTimer = Timer(Duration(milliseconds: holdMs + 460), () {
    if (_irisPillOverlayEntry == entry) {
      _clearIrisPillOverlay();
    }
  });
}

void showIrisFrostedSnackBar(
  BuildContext context, {
  required Widget content,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
  Color? tint,
  EdgeInsetsGeometry? margin,
  String? dedupeKey,
  Duration dedupeWindow = const Duration(milliseconds: 1400),
  bool clearExisting = true,
}) {
  if (!context.mounted) return;

  if (dedupeKey != null && dedupeKey.isNotEmpty) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastMs = _irisSnackLastShownMs[dedupeKey] ?? 0;
    if (nowMs - lastMs < dedupeWindow.inMilliseconds) {
      return;
    }
    _irisSnackLastShownMs[dedupeKey] = nowMs;
  }

  final text = _compactIrisSnackText(_extractIrisSnackText(content));
  _showIrisTopPill(
    context,
    text: text,
    duration: duration,
    tint: tint,
    action: action,
    clearExisting: clearExisting,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database
  tz.initializeTimeZones();

  runApp(const IrisApp());

  unawaited(_bootstrapStartupServices());
}

Future<void> _bootstrapStartupServices() async {
  try {
    await WidgetService.initialize();
  } catch (e) {
    debugPrint('Widget service init failed: $e');
  }

  try {
    await WidgetService.initializeWidgetDefaults();
  } catch (e) {
    debugPrint('Widget defaults init failed: $e');
  }

  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }

  try {
    await IrisSfx.init();
  } catch (e) {
    debugPrint('UI sound init failed: $e');
  }

  try {
    await IrisHaptics.init();
  } catch (e) {
    debugPrint('Haptics init failed: $e');
  }

  try {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'persistent_class_foreground',
        channelName: 'IRIS Class Tracker',
        channelDescription: 'Shows your current and upcoming classes',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          30000,
        ), // Update every 30 seconds
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  } catch (e) {
    debugPrint('Foreground task init failed: $e');
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final persistentEnabled =
        prefs.getBool('persistent_notification_enabled') ?? false;
    final userRole = prefs.getString('user_role') ?? 'student';

    final hasStudentData =
        prefs.containsKey('student_batch') && prefs.containsKey('timetable_data');

    if (persistentEnabled &&
        userRole == 'student' &&
        hasStudentData &&
        !(await FlutterForegroundTask.isRunningService)) {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'IRIS Class Tracker',
        notificationText: 'Loading your schedule...',
        notificationIcon: null,
        notificationButtons: [NotificationButton(id: 'open', text: 'Open IRIS')],
        callback: startClassNotificationTask,
      );
    }
  } catch (e) {
    debugPrint('Foreground service restore failed: $e');
  }

  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (e) {
    debugPrint('System UI mode update failed: $e');
  }

  try {
    unawaited(
      TimetableOTAService.checkForUpdatesOnStartup().catchError((e) {
        debugPrint('OTA check failed on startup: $e');
      }),
    );
  } catch (e) {
    debugPrint('OTA bootstrap failed: $e');
  }

  try {
    await NotificationService().syncClassRemindersFromPrefs();
  } catch (e) {
    debugPrint('Reminder sync failed: $e');
  }
}

class IrisApp extends StatefulWidget {
  const IrisApp({super.key});

  @override
  State<IrisApp> createState() => _IrisAppState();
}

class _IrisAppState extends State<IrisApp> {
  ThemeMode _themeMode = ThemeMode.system;

  String get _themeModeKey {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _themeModeFromKey(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IrisSfx.click();
    });
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('themeMode');
    final legacyMode = prefs.getString('appearance_mode');
    final mode = savedMode ?? legacyMode ?? 'system';

    if (savedMode == null && legacyMode != null) {
      await prefs.setString('themeMode', mode);
    }
    if (legacyMode != mode) {
      await prefs.setString('appearance_mode', mode);
    }

    if (!mounted) return;
    setState(() {
      _themeMode = _themeModeFromKey(mode);
    });
  }

  Future<void> _setThemeMode(String mode) async {
    IrisSfx.tick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode);
    await prefs.setString('appearance_mode', mode);

    if (!mounted) return;
    setState(() {
      _themeMode = _themeModeFromKey(mode);
    });
  }

  Future<void> _toggleTheme() async {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isEffectivelyDark =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);
    final next = isEffectivelyDark ? 'light' : 'dark';
    await _setThemeMode(next);
  }

  @override
  Widget build(BuildContext context) {
    // Set system overlay styles based on theme
    final isDark =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
    return MaterialApp(
      title: 'IRIS',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const SmoothScrollBehavior(),
      themeMode: _themeMode,
      themeAnimationDuration: const Duration(milliseconds: 384),
      themeAnimationCurve: IrisMotion.standard,
      theme: IrisTheme.light(),
      darkTheme: IrisTheme.dark(),
      home: FutureBuilder<UniversityMemory>(
        future: UniversityMemoryLoader.loadFromAssets(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _BootScreen();
          }
          return _AppRoot(
            memory: snapshot.data!,
            onToggleTheme: _toggleTheme,
            onSetThemeMode: _setThemeMode,
            currentThemeMode: _themeModeKey,
          );
        },
      ),
    );
  }
}

class _BootScreen extends StatefulWidget {
  const _BootScreen();

  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: IrisMotion.slow,
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: IrisMotion.standard),
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 2880),
      vsync: this,
    )..repeat();

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          _NeuralAura(background: isDark),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              IrisTokens.brand.withValues(alpha: 0.18),
                              IrisTokens.brand.withValues(alpha: 0.04),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: IrisTokens.brand.withValues(alpha: 0.16),
                              offset: const Offset(0, 8),
                              blurRadius: 22,
                              spreadRadius: -8,
                            ),
                          ],
                        ),
                      ),
                    ),

                    RotationTransition(
                      turns: _rotateAnimation,
                      child: Container(
                        width: 135,
                        height: 135,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: IrisTokens.brand.withValues(alpha: 0.25),
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),

                    RotationTransition(
                      turns: Tween<double>(begin: 0, end: -1).animate(
                        CurvedAnimation(
                          parent: _rotateController,
                          curve: Curves.linear,
                        ),
                      ),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: IrisTokens.purple.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    // Main logo container
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: IrisTokens.warning,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: IrisTokens.warning.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: IrisTokens.warning.withValues(alpha: 0.22),
                              offset: const Offset(0, 6),
                              blurRadius: 14,
                              spreadRadius: -4,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/iris_logo.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'IRIS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 6.0,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'INTELLIGENT ROUTINE & INSIGHT SYSTEM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3.0,
                    color:
                        (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black)
                            .withValues(alpha: 0.40),
                  ),
                ),
                const SizedBox(height: 44),
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(IrisTokens.brand),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  final UniversityMemory memory;
  final VoidCallback onToggleTheme;
  final Future<void> Function(String mode) onSetThemeMode;
  final String currentThemeMode;

  const _AppRoot({
    required this.memory,
    required this.onToggleTheme,
    required this.onSetThemeMode,
    required this.currentThemeMode,
  });

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final OmniBrain _brain;
  String? _selectedBatch;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _brain = OmniBrain(widget.memory);
    _loadUserRole();
    _loadBatch();

    // Show Darood e Pak reminder on app boot with haptic pulse
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IrisHaptics.actionSoft();
      _showDaroodePakDialog();
    });
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role');
    });
  }

  void _showDaroodePakDialog() {
    // Pick a contextual Islamic greeting based on time of day
    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? 'Start your morning with blessings'
        : hour >= 12 && hour < 17
        ? 'Afternoon reminder for Darood'
        : hour >= 17 && hour < 21
        ? 'Evening blessings upon the Prophet'
        : 'Night reminder — send Darood e Pak';

    final bottomSafeSpace = MediaQuery.of(context).padding.bottom + 108;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'startup_darood_reminder',
      dedupeWindow: const Duration(seconds: 10),
      content: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: IrisTokens.successGradient),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: IrisTokens.success.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mosque_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Darood e Pak',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.80),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.favorite_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
      tint: IrisTokens.success,
      duration: const Duration(seconds: 5),
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomSafeSpace),
    );
  }

  Future<void> _loadBatch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedBatch = prefs.getString('selectedBatch');
    });
  }

  Future<void> _saveBatch(String batch) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBatch', batch);
    final isFirstSetup = prefs.getBool('widget_prompt_shown') != true;
    setState(() => _selectedBatch = batch);

    // Show widget setup prompt after first batch selection
    if (isFirstSetup && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _showWidgetSetupPrompt();
      }
    }
  }

  Future<void> _showWidgetSetupPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                offset: const Offset(0, 12),
                blurRadius: 32,
                spreadRadius: -8,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                offset: const Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Widget icon with smooth gradient
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [IrisTokens.blue, IrisTokens.brand],
                  ),
                  borderRadius: BorderRadius.circular(IrisTokens.radius20),
                  boxShadow: [
                    BoxShadow(
                      color: IrisTokens.brand.withValues(alpha: 0.20),
                      offset: const Offset(0, 8),
                      blurRadius: 18,
                      spreadRadius: -6,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Add Home Screen Widget',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: 2.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                'Track your classes at a glance with the IRIS home screen widget.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.65,
                  ),
                  height: 1.5,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Instructions
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.04,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                      0.06,
                    ),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStep(isDark, '1', 'Long press on your home screen'),
                    const SizedBox(height: 12),
                    _buildStep(isDark, '2', 'Tap Widgets'),
                    const SizedBox(height: 12),
                    _buildStep(isDark, '3', 'Search for "IRIS"'),
                    const SizedBox(height: 12),
                    _buildStep(isDark, '4', 'Drag to home screen'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Maybe Later',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        await prefs.setBool('widget_prompt_shown', true);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            IrisTokens.radius16,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Got It!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Mark as shown
    await prefs.setBool('widget_prompt_shown', true);
  }

  Widget _buildStep(bool isDark, String number, String text) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [IrisTokens.error.withValues(alpha: 0.8), IrisTokens.error],
            ),
            border: Border.all(
              color: IrisTokens.error.withValues(alpha: 0.4),
              width: 0.5,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: IrisTokens.error.withValues(alpha: 0.3),
                offset: const Offset(0, 2),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);

    // Don't clear data - just switch role and let onRepeatEvent use the right data for this role
    // This way notifications continue properly during role switching

    // Always stop service when changing roles to ensure clean state
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() => _userRole = role);
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return RoleSelectorScreen(onComplete: _saveUserRole);
    }

    if (_userRole == 'faculty') {
      return FacultyDashboard(
        brain: _brain,
        onToggleTheme: widget.onToggleTheme,
        onSetThemeMode: widget.onSetThemeMode,
        currentThemeMode: widget.currentThemeMode,
        onRoleChanged: _saveUserRole,
      );
    }

    if (_selectedBatch == null) {
      return SetupBot(memory: widget.memory, onComplete: _saveBatch);
    }

    return Dashboard(
      memory: widget.memory,
      brain: _brain,
      batch: _selectedBatch!,
      onToggleTheme: widget.onToggleTheme,
      onSetThemeMode: widget.onSetThemeMode,
      currentThemeMode: widget.currentThemeMode,
      onRoleChanged: _saveUserRole,
      onChangeBatch: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => BatchSelectorSheet(
            memory: widget.memory,
            selected: _selectedBatch!,
          ),
        );
        if (result != null && result != _selectedBatch) {
          await _saveBatch(result);
          IrisHaptics.chipSelect();
        }
      },
    );
  }
}

class SetupBot extends StatefulWidget {
  final UniversityMemory memory;
  final ValueChanged<String> onComplete;

  const SetupBot({required this.memory, required this.onComplete, super.key});

  @override
  State<SetupBot> createState() => _SetupBotState();
}

class RoleSelectorScreen extends StatelessWidget {
  final ValueChanged<String> onComplete;

  const RoleSelectorScreen({required this.onComplete, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          _NeuralAura(background: isDark),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Choose your role',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will personalize your dashboard, tools, and portal access.',
                    style: TextStyle(
                      fontSize: 14,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                        0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    child: Column(
                      children: [
                        _RoleCard(
                          title: 'Student',
                          subtitle: 'Timetable, batch sync, class tracking',
                          icon: Icons.school_rounded,
                          accent: IrisTokens.brand,
                          onTap: () => onComplete('student'),
                        ),
                        const SizedBox(height: 14),
                        _RoleCard(
                          title: 'Faculty',
                          subtitle: 'Faculty portal and teaching tools',
                          icon: Icons.badge_rounded,
                          accent: IrisTokens.blue,
                          onTap: () => onComplete('faculty'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _wobbleController;
  late Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      duration: IrisMotion.fast,
      vsync: this,
    );
    _wobbleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _wobbleController, curve: IrisMotion.standard),
    );
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MotionSlideFade(
      beginOffset: const Offset(100, 0),
      duration: IrisMotion.medium,
      curve: IrisMotion.entrance,
      child: AnimatedBuilder(
        animation: _wobbleAnimation,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - (_wobbleAnimation.value * 0.08),
          child: InkWell(
            onTap: () {
              IrisHaptics.actionHeavy();
              _wobbleController.forward().then(
                (_) => _wobbleController.reverse(),
              );
              widget.onTap();
            },
            onTapDown: (_) => _wobbleController.forward(),
            onTapCancel: () => _wobbleController.reverse(),
            borderRadius: BorderRadius.circular(IrisTokens.radius28),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.accent,
                    widget.accent.withValues(alpha: 0.82),
                  ],
                  stops: const [0.0, 1.0],
                ),
                borderRadius: BorderRadius.circular(IrisTokens.radius28),
                border: Border.all(
                  color: widget.accent.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.20),
                    offset: const Offset(0, 10),
                    blurRadius: 22,
                    spreadRadius: -12,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    offset: const Offset(0, 4),
                    blurRadius: 14,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w200,
                            fontSize: 22,
                            letterSpacing: -0.5,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.5,
                            color: Colors.black.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: widget.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MotionSlideFade extends StatelessWidget {
  final Widget child;
  final Offset beginOffset;
  final Duration duration;
  final Curve curve;

  const _MotionSlideFade({
    required this.child,
    required this.beginOffset,
    this.duration = IrisMotion.medium,
    this.curve = IrisMotion.entrance,
  });

  @override
  Widget build(BuildContext context) {
    if (IrisMotion.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, _) => Transform.translate(
        offset: Offset(
          beginOffset.dx * (1 - value),
          beginOffset.dy * (1 - value),
        ),
        child: Opacity(opacity: value, child: child),
      ),
    );
  }
}

class _MotionScaleFade extends StatelessWidget {
  final Widget child;
  final double beginScale;
  final Duration duration;
  final Curve curve;

  const _MotionScaleFade({
    required this.child,
    this.beginScale = 0.9,
    this.duration = IrisMotion.medium,
    this.curve = IrisMotion.bouncy,
  });

  @override
  Widget build(BuildContext context) {
    if (IrisMotion.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, _) => Transform.scale(
        scale: beginScale + ((1 - beginScale) * value),
        child: Opacity(opacity: value, child: child),
      ),
    );
  }
}

class _SetupBotState extends State<SetupBot> {
  String? _program;
  int? _semester;
  String? _section;
  bool _persistentNotificationEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  // Static method to show widget setup guide from SetupBot
  static Future<void> _showWidgetSetupGuideFromSetup(
    BuildContext context,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                offset: const Offset(0, 12),
                blurRadius: 32,
                spreadRadius: -8,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                offset: const Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Widget icon with gradient
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [IrisTokens.purpleLight, IrisTokens.purple],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: IrisTokens.purpleLight.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: IrisTokens.purple.withValues(alpha: 0.20),
                      offset: const Offset(0, 5),
                      blurRadius: 12,
                      spreadRadius: -5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Add Home Screen Widget',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: 2.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                'Track your classes at a glance with the IRIS home screen widget.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.65,
                  ),
                  height: 1.5,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Instructions
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.04,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                      0.06,
                    ),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepStatic(
                      isDark,
                      '1',
                      'Long press on your home screen',
                    ),
                    const SizedBox(height: 12),
                    _buildStepStatic(isDark, '2', 'Tap Widgets'),
                    const SizedBox(height: 12),
                    _buildStepStatic(isDark, '3', 'Search for "IRIS"'),
                    const SizedBox(height: 12),
                    _buildStepStatic(isDark, '4', 'Drag to home screen'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        await prefs.setBool('widget_prompt_shown', true);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.purple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Got It!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStepStatic(bool isDark, String number, String text) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [IrisTokens.purple, IrisTokens.purpleLight],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _persistentNotificationEnabled =
          prefs.getBool('persistent_notification_enabled') ?? false;
    });
  }

  Future<void> _togglePersistentNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'student';
    final teacher = prefs.getString('faculty_teacher');
    if (role == 'faculty' && value && (teacher == null || teacher.isEmpty)) {
      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          dedupeKey: 'faculty_tracking_requires_teacher',
          content: Row(
            children: const [
              Icon(Icons.info_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select your name first to enable faculty tracking',
                ),
              ),
            ],
          ),
          tint: IrisTokens.brand,
        );
      }
      return;
    }
    await prefs.setBool('persistent_notification_enabled', value);
    setState(() {
      _persistentNotificationEnabled = value;
    });

    if (!value) {
      // Stop foreground service when disabled
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } else {
      // Start foreground service when enabled
      if (!(await FlutterForegroundTask.isRunningService)) {
        // Store default values for first time
        await prefs.setString('notification_title', 'IRIS Class Tracker');
        await prefs.setString(
          'notification_body',
          'Keeping your class schedule handy',
        );

        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'IRIS Class Tracker',
          notificationText: 'Keeping your class schedule handy',
          notificationIcon: null,
          notificationButtons: [
            NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
          callback: startClassNotificationTask,
        );
      }
    }

    IrisHaptics.chipSelect();
  }

  @override
  Widget build(BuildContext context) {
    // Filter out batch-like programs (FA##, SP##, etc.) - show only actual programs
    final programs = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toList();
    final semesters = _program == null
        ? <int>[]
        : widget.memory.semesters(_program!);
    final sections = (_program != null && _semester != null)
        ? widget.memory.sections(_program!, _semester!)
        : <String>[];

    return Scaffold(
      body: Stack(
        children: [
          _NeuralAura(
            background: Theme.of(context).brightness == Brightness.dark,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(IrisTokens.radius32),
                      child: Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              IrisTokens.brand.withValues(alpha: 0.50),
                              IrisTokens.purple.withValues(alpha: 0.42),
                              IrisTokens.purpleLight.withValues(alpha: 0.34),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            IrisTokens.radius32,
                          ),
                          border: Border.all(
                            color: IrisTokens.brand.withValues(alpha: 0.55),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: IrisTokens.brand.withValues(alpha: 0.24),
                              blurRadius: 16,
                              spreadRadius: -2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: IrisTokens.brandGradient,
                                ),
                                borderRadius: BorderRadius.circular(
                                  IrisTokens.radius20,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: IrisTokens.brand.withValues(alpha: 0.45),
                                    blurRadius: 8,
                                    spreadRadius: -1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.psychology_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Neural Setup Bot',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Configure your academic profile',
                                    style: TextStyle(
                                      fontSize: 13,
                                      letterSpacing: 0.3,
                                      color: Colors.white.withValues(alpha: 0.92),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose your program, semester, and section to sync the brain.',
                      style: TextStyle(
                        fontSize: 15,
                        letterSpacing: 0.2,
                        height: 1.4,
                        color: (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.84)
                            : Colors.black.withValues(alpha: 0.78)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SelectorCard(
                      label: 'Program',
                      options: programs,
                      selected: _program,
                      onSelected: (value) => setState(() {
                        _program = value;
                        _semester = null;
                        _section = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _SelectorCard(
                      label: 'Semester',
                      options: semesters.map((e) => e.toString()).toList(),
                      selected: _semester?.toString(),
                      onSelected: (value) => setState(() {
                        _semester = int.tryParse(value ?? '');
                        _section = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _SelectorCard(
                      label: 'Section',
                      options: sections,
                      selected: _section,
                      onSelected: (value) => setState(() => _section = value),
                    ),
                    const SizedBox(height: 24),

                    // Persistent Notification Toggle
                    GlassCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _persistentNotificationEnabled
                                    ? IrisTokens.brandGradient
                                    : [
                                        (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black)
                                            .withValues(alpha: 0.12),
                                        (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black)
                                            .withValues(alpha: 0.08),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(
                                IrisTokens.radius12,
                              ),
                            ),
                            child: Icon(
                              _persistentNotificationEnabled
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_off_rounded,
                              color: _persistentNotificationEnabled
                                  ? Colors.white
                                  : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black)
                                        .withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Class Tracker',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _persistentNotificationEnabled
                                      ? 'Progress bar & schedule in status bar'
                                      : 'Show class info in notification bar',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.72)
                                        : Colors.black.withValues(alpha: 0.70)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _persistentNotificationEnabled,
                            onChanged: _togglePersistentNotification,
                            activeColor: IrisTokens.brand,
                            activeTrackColor: IrisTokens.brand.withValues(alpha: 
                              0.35,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Widget Setup Guide
                    GlassCard(
                      child: InkWell(
                        onTap: () async {
                          await _showWidgetSetupGuideFromSetup(context);
                        },
                        borderRadius: BorderRadius.circular(
                          IrisTokens.radius16,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      IrisTokens.brandGradient[0].withValues(alpha: 
                                        0.9,
                                      ),
                                      IrisTokens.brandGradient[1].withValues(alpha: 
                                        0.9,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    IrisTokens.radius12,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.widgets_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Home Screen Widget',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Add widget to see classes at a glance',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withValues(alpha: 0.72)
                                            : Colors.black.withValues(alpha: 0.70)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color:
                                    (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.48)
                                    : Colors.black.withValues(alpha: 0.45)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Builder(
                      builder: (context) {
                        final isReady =
                            _program != null &&
                            _semester != null &&
                            _section != null;
                        final isDarkBtn =
                            Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: isReady
                                ? LinearGradient(
                                    colors: IrisTokens.brandGradient,
                                  )
                                : null,
                            color: !isReady
                                ? (isDarkBtn
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.08))
                                : null,
                            borderRadius: BorderRadius.circular(
                              IrisTokens.radius20,
                            ),
                            border: !isReady
                                ? Border.all(
                                    color: isDarkBtn
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.black.withValues(alpha: 0.12),
                                    width: 1.5,
                                  )
                                : null,
                            boxShadow: isReady
                                ? [
                                    BoxShadow(
                                      color: IrisTokens.brand.withValues(alpha: 0.45),
                                      blurRadius: 6,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed: isReady
                                ? () {
                                    final batch = widget.memory.allBatches
                                        .firstWhere(
                                          (b) {
                                            final key = BatchKey.parse(b);
                                            return key.program == _program &&
                                                key.semester == _semester &&
                                                key.section == _section;
                                          },
                                          orElse: () =>
                                              widget.memory.allBatches.first,
                                        );
                                    widget.onComplete(batch);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: isReady
                                  ? Colors.white
                                  : (isDarkBtn
                                        ? Colors.white.withValues(alpha: 0.56)
                                        : Colors.black.withValues(alpha: 0.52)),
                              disabledForegroundColor: isDarkBtn
                                  ? Colors.white.withValues(alpha: 0.50)
                                  : Colors.black.withValues(alpha: 0.48),
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              minimumSize: const Size.fromHeight(56),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.rocket_launch_rounded, size: 22),
                                SizedBox(width: 10),
                                Text('Sync My Batch'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorCard extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _SelectorCard({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      enableOverlay: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [IrisTokens.brand, IrisTokens.brandLight],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.45),
                ),
              ),
              if (selected != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: IrisTokens.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    selected!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: IrisTokens.brand,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options
                .map(
                  (opt) => ChoiceChip(
                    label: Text(
                      opt,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    selected: selected == opt,
                    onSelected: (_) => onSelected(opt),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                    side: BorderSide(
                      color: selected == opt
                          ? IrisTokens.brand.withValues(alpha: 0.55)
                          : isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.10),
                      width: 1.2,
                    ),
                    labelStyle: TextStyle(
                      color: selected == opt
                          ? IrisTokens.brand
                          : isDark
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  final UniversityMemory memory;
  final OmniBrain brain;
  final String batch;
  final VoidCallback onToggleTheme;
  final Future<void> Function(String mode) onSetThemeMode;
  final String currentThemeMode;
  final VoidCallback onChangeBatch;
  final ValueChanged<String> onRoleChanged;

  const Dashboard({
    required this.memory,
    required this.brain,
    required this.batch,
    required this.onToggleTheme,
    required this.onSetThemeMode,
    required this.currentThemeMode,
    required this.onChangeBatch,
    required this.onRoleChanged,
    super.key,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class FacultyDashboard extends StatefulWidget {
  final OmniBrain brain;
  final VoidCallback onToggleTheme;
  final Future<void> Function(String mode) onSetThemeMode;
  final String currentThemeMode;
  final ValueChanged<String> onRoleChanged;

  const FacultyDashboard({
    required this.brain,
    required this.onToggleTheme,
    required this.onSetThemeMode,
    required this.currentThemeMode,
    required this.onRoleChanged,
    super.key,
  });

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard>
    with SingleTickerProviderStateMixin {
  static const String _helpdeskBackendBase =
      'https://cui-helpdesk-backend.onrender.com';

  final HelpdeskFacultyService _facultyService = HelpdeskFacultyService();
  String? _selectedTeacher;
  Timer? _ticker;
  int? _overrideDayIndex;
  int _bottomNavIndex = 0;
  int _facultyTabSlideDirection = 1;
  bool _isStudentNavBusy = false;
  bool _navBarReady = false;
  List<ClassSession> _cachedSchedule = [];
  DateTime? _lastScheduleUpdate;
  int? _lastMinute;
  bool _isRefreshing = false;
  bool _facultyProfilesLoading = false;
  HelpdeskFacultySource _facultyProfilesSource = HelpdeskFacultySource.none;
  List<FacultyProfile> _facultyProfiles = const [];
  final GlobalKey _facultyTeacherNavKey = GlobalKey(
    debugLabel: 'faculty_teacher_nav',
  );
  final GlobalKey _facultySelectTeacherCtaKey = GlobalKey(
    debugLabel: 'faculty_select_teacher_cta',
  );
  final GlobalKey _facultyChangeTeacherKey = GlobalKey(
    debugLabel: 'faculty_change_teacher',
  );
  final GlobalKey _facultyPortalNavKey = GlobalKey(
    debugLabel: 'faculty_portal_nav',
  );
  final GlobalKey _facultyAboutNavKey = GlobalKey(
    debugLabel: 'faculty_about_nav',
  );

  @override
  void initState() {
    super.initState();
    _loadSelectedTeacher();
    unawaited(_loadFacultyProfiles());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _navBarReady = true);
      }
    });
    _lastMinute = DateTime.now().minute;
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        final now = DateTime.now();
        final minuteChanged = _lastMinute != now.minute;
        if (minuteChanged) {
          setState(() {
            _lastMinute = now.minute;
          });
        }
        _updateWidgetForTeacher();
      }
    });
    _updateWidgetForTeacher();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    IrisHaptics.refreshStart();

    setState(() => _isRefreshing = true);

    // Simulate data refresh delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Refresh schedule cache
    _updateScheduleCache();

    // Update widget and notifications
    _updateWidgetForTeacher();

    setState(() => _isRefreshing = false);
    IrisHaptics.refreshSuccess();

    // Show success feedback
    if (mounted) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'dashboard_refresh_success',
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              'Schedule refreshed',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        tint: IrisTokens.success,
        duration: const Duration(seconds: 2),
      );
    }
  }

  String _timelineTitle(
    List<ClassSession> schedule,
    DateTime now,
    int? overrideDay,
  ) {
    if (schedule.isEmpty && overrideDay != null) {
      return '${FormatGuard.normalizeDay(overrideDay)} Timeline';
    }
    if (schedule.isEmpty) return 'No Classes';
    final dayIndex = overrideDay ?? schedule.first.dayIndex;

    if (dayIndex == now.weekday) {
      return 'Today\'s Timeline';
    }

    // Check if it's tomorrow
    final tomorrowIndex = (now.weekday % 7) + 1;
    if (dayIndex == tomorrowIndex && overrideDay == null) {
      return 'Tomorrow Morning';
    }

    final dayName = FormatGuard.normalizeDay(dayIndex);
    return '$dayName Timeline';
  }

  String _timelineSubtitle(
    List<ClassSession> schedule,
    DateTime now,
    int? overrideDay,
  ) {
    if (schedule.isEmpty && overrideDay != null) {
      return 'No classes scheduled • Free day! 🎉';
    }
    if (schedule.isEmpty) return 'No sessions in the registry';

    final dayIndex = overrideDay ?? schedule.first.dayIndex;
    final currentTime = now.hour + (now.minute / 60.0);

    if (dayIndex == now.weekday) {
      // Show smart live status
      if (_selectedTeacher != null) {
        final current = widget.brain.getCurrentClassForTeacher(
          _selectedTeacher!,
          now,
        );

        if (current != null && current.isLive(now)) {
          // Currently in a class
          final remaining = schedule
              .where((s) => s.safeStartVal > currentTime)
              .length;
          final classesLeft = remaining > 0
              ? '$remaining ${remaining == 1 ? 'class' : 'classes'} left'
              : 'Last class today';
          return '${current.subject} • $classesLeft';
        }
      }

      return '${schedule.length} classes scheduled';
    }

    return '${schedule.length} classes scheduled';
  }

  Color _getTimelineStatusColor(OmniBrain brain, String teacher, DateTime now) {
    if (_selectedTeacher != null) {
      final current = brain.getCurrentClassForTeacher(_selectedTeacher!, now);
      if (current != null && current.isLive(now)) {
        return IrisTokens.success;
      }
    }
    return IrisTokens.purple;
  }

  Future<void> _loadSelectedTeacher() async {
    final prefs = await SharedPreferences.getInstance();
    // ALWAYS set role to faculty to prevent cross-contamination
    await prefs.setString('user_role', 'faculty');

    // Get teacher and update state
    final teacher = prefs.getString('faculty_teacher');
    setState(() {
      _selectedTeacher = teacher;
    });

    // Now start notification service with the teacher loaded above (pass as parameter)
    if (teacher != null && teacher.isNotEmpty) {
      await _ensureFacultyNotificationService(teacher);
      await _scheduleFacultyClassReminders(teacher);
    }
  }

  Future<void> _loadFacultyProfiles() async {
    _facultyProfilesLoading = true;
    final payload = await _facultyService.fetchLiveFirstWithFallbackPayload();
    if (!mounted) return;
    setState(() {
      _facultyProfiles = payload.items;
      _facultyProfilesSource = payload.source;
      _facultyProfilesLoading = false;
    });
  }

  FacultyProfile? _matchSelectedTeacherProfile() {
    final teacher = _selectedTeacher;
    if (teacher == null || teacher.isEmpty) return null;
    return HelpdeskFacultyService.matchFacultyProfile(teacher, _facultyProfiles);
  }

  String _facultySourceLabel(HelpdeskFacultySource source) {
    switch (source) {
      case HelpdeskFacultySource.live:
        return 'LIVE';
      case HelpdeskFacultySource.cache:
        return 'CACHE';
      case HelpdeskFacultySource.backup:
        return 'BACKUP';
      case HelpdeskFacultySource.none:
        return 'OFFLINE';
    }
  }

  String _resolveFacultyImageUrl(String image) {
    final raw = image.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '$_helpdeskBackendBase$raw';
    return '$_helpdeskBackendBase/$raw';
  }

  Future<void> _launchFacultyEmail(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'faculty_dashboard_email_unavailable',
        content: const Text('Email unavailable for this faculty profile.'),
      );
      return;
    }
    final uri = Uri.parse('mailto:$normalized');
    if (await canLaunchUrl(uri)) {
      IrisSfx.pillTap();
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'faculty_dashboard_email_launch_failed',
      content: const Text('Unable to open email client on this device.'),
    );
  }

  Future<void> _saveSelectedTeacher(String teacherName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('faculty_teacher', teacherName);
    await prefs.setString('user_role', 'faculty');
    await _persistTimetableData();
    setState(() {
      _selectedTeacher = teacherName;
      _overrideDayIndex = null; // Reset day filter when teacher changes
    });
    // Refresh cache and UI immediately
    _updateScheduleCache();
    _updateWidgetForTeacher();
    await _ensureFacultyNotificationService(teacherName);
    await _scheduleFacultyClassReminders(teacherName);
  }

  Future<void> _scheduleFacultyClassReminders(String teacherName) async {
    final prefs = await SharedPreferences.getInstance();
    final remindersEnabled =
        prefs.getBool('lecture_reminders_enabled') ?? false;
    if (!remindersEnabled) {
      await NotificationService().cancelScheduledClassReminders();
      return;
    }

    final todayClasses = widget.brain.memory.sessions
        .where(
          (s) =>
              s.dayIndex == DateTime.now().weekday &&
              s.teacher.trim().toLowerCase() ==
                  teacherName.trim().toLowerCase(),
        )
        .toList();

    if (todayClasses.isNotEmpty) {
      await NotificationService().scheduleClassReminders(todayClasses);
    }
  }

  Future<void> _persistTimetableData() async {
    final prefs = await SharedPreferences.getInstance();
    final timetableData = {
      'sessions': widget.brain.memory.sessions.map((s) => s.toJson()).toList(),
    };
    await prefs.setString('timetable_data', jsonEncode(timetableData));
  }

  Future<void> _ensureFacultyNotificationService(String? teacherParam) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('persistent_notification_enabled') ?? false;
    // Use parameter if provided, otherwise fall back to state
    final teacher = teacherParam ?? _selectedTeacher;
    if (!enabled || teacher == null || teacher.isEmpty) {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      return;
    }

    // Persist all data needed for background service
    await prefs.setString('user_role', 'faculty');
    await prefs.setString('faculty_teacher', teacher);
    await _persistTimetableData();

    // Stop service if running to ensure clean restart
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      // Minimal delay to ensure service fully stops before restart
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Calculate initial notification to show immediately (like student mode)
    final now = DateTime.now();
    final current = widget.brain.getCurrentClassForTeacher(teacher, now);
    final next = widget.brain.getNextClassForTeacher(teacher, now);
    final currentTime = now.hour + (now.minute / 60.0);
    final dayIndex = now.weekday;

    String _bar(double p) {
      const total = 8;
      final filled = (p * total).round().clamp(0, total);
      return '🟦' * filled + '⬜' * (total - filled);
    }

    final teacherSessions = widget.brain.memory.sessions
        .where(
          (s) => s.teacher.trim().toLowerCase() == teacher.trim().toLowerCase(),
        )
        .toList();
    final todayAll = teacherSessions
        .where((s) => s.dayIndex == dayIndex)
        .toList();

    String notifTitle = 'IRIS Faculty Tracker';
    String notifBody = 'Your schedule is ready';

    if (current != null && current.isLive(now)) {
      final duration = LectureDuration.getActualDuration(current);
      final actualEndTime = LectureDuration.getActualEndTime(current);
      final progress = ((currentTime - current.safeStartVal) / duration).clamp(
        0.0,
        1.0,
      );
      final progressPercent = (progress * 100).toInt();

      final minutesRemaining = ((actualEndTime - currentTime) * 60)
          .round()
          .clamp(0, (duration * 60).round());
      final hoursRemaining = minutesRemaining ~/ 60;
      final minsRemaining = minutesRemaining % 60;

      String timeLeft = hoursRemaining > 0
          ? '${hoursRemaining}h ${minsRemaining}m left'
          : minsRemaining > 0
          ? '${minsRemaining}m left'
          : 'Ending now';

      final remaining = todayAll
          .where((s) => s.safeStartVal > currentTime)
          .length;
      final classCount = remaining > 0
          ? ' · $remaining more today'
          : ' · Last one';

      notifTitle = '🎓 ${current.subject} · $timeLeft';
      notifBody =
          '${_bar(progress)} $progressPercent%$classCount\n📍 ${current.room} · 📚 ${current.batchKey.batch}';
    } else if (next != null) {
      int daysAhead = 0;
      if (next.dayIndex != dayIndex) {
        daysAhead = (next.dayIndex - dayIndex + 7) % 7;
        if (daysAhead == 0) daysAhead = 7;
      }
      final totalMinutesUntil = daysAhead > 0
          ? ((24.0 - currentTime) * 60 +
                    (daysAhead - 1) * 24 * 60 +
                    next.safeStartVal * 60)
                .round()
          : ((next.safeStartVal - currentTime) * 60).round();
      final hoursUntil = totalMinutesUntil ~/ 60;
      final minsUntil = totalMinutesUntil % 60;

      String timeUntil = '';
      String emoji = '📌';
      if (daysAhead > 0) {
        const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final nextDayName = dayNames[next.dayIndex];
        final startHour = next.safeStartVal.floor();
        final startMin = ((next.safeStartVal - startHour) * 60).round();
        final displayHour = startHour > 12 ? startHour - 12 : startHour;
        final amPm = startHour >= 12 ? 'PM' : 'AM';
        timeUntil =
            '$nextDayName ${displayHour}:${startMin.toString().padLeft(2, '0')} $amPm';
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

      final remainingToday = todayAll
          .where((s) => s.safeStartVal > currentTime)
          .length;

      String classInfo;
      if (daysAhead > 0) {
        classInfo = 'Done for today ✓';
      } else if (remainingToday > 1) {
        classInfo = '$remainingToday classes left';
      } else {
        classInfo = 'Last class today';
      }

      notifTitle = '$emoji ${next.subject} in $timeUntil';
      notifBody = '$classInfo\n📍 ${next.room} · 📚 ${next.batchKey.batch}';
    } else {
      final weekday = now.weekday;
      if (weekday == 6 || weekday == 7) {
        notifTitle = '🎉 Weekend Mode';
        notifBody = 'No classes — enjoy your break!';
      } else {
        notifTitle = '✓ All done for today';
        notifBody = 'No more classes scheduled';
      }
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: notifTitle,
      notificationText: notifBody,
      notificationIcon: null,
      notificationButtons: [NotificationButton(id: 'open', text: 'Open IRIS')],
      callback: startClassNotificationTask,
    );
  }

  Future<void> _updateWidgetForTeacher() async {
    final teacher = _selectedTeacher;
    if (teacher == null || teacher.isEmpty) {
      await WidgetService.updateWidgetIdle(
        headline: 'Faculty Mode',
        subline: 'Select your name to view schedule',
        teacherInfo: '',
        timeInfo: 'Open IRIS to select',
        isUrgent: false,
      );
      return;
    }

    final now = DateTime.now();
    final insight = widget.brain.buildTeacherTemporalInsight(teacher, now);
    int progressPercent = 0;
    final current = widget.brain.getCurrentClassForTeacher(teacher, now);
    if (current != null && current.isLive(now)) {
      final currentTime = now.hour + (now.minute / 60.0);
      final duration = LectureDuration.getActualDuration(current);
      final progress = ((currentTime - current.safeStartVal) / duration).clamp(
        0.0,
        1.0,
      );
      progressPercent = (progress * 100).toInt();
    }

    // For faculty, show batch instead of teacher name
    String displayInfo = teacher;
    if (current != null) {
      displayInfo = current.batchKey.batch;
    } else {
      // If no current class, try to get batch from next class
      final allSessions = widget.brain.memory.sessions
          .where(
            (s) =>
                s.teacher.trim().toLowerCase() == teacher.trim().toLowerCase(),
          )
          .toList();
      if (allSessions.isNotEmpty) {
        displayInfo = allSessions.first.batchKey.batch;
      }
    }

    await WidgetService.updateWidgetWithInsight(
      headline: insight.headline,
      subline: insight.subline,
      timeInfo: insight.timeInfo ?? '--',
      teacherInfo: displayInfo,
      isLive: insight.isLive,
      isUrgent: insight.isUrgent,
      progressPercentage: progressPercent,
    );
  }

  Future<void> _openTeacherPortal({GlobalKey? originKey}) async {
    await _onBottomNavTap(2);
  }

  Future<void> _openTeacherPicker({GlobalKey? originKey}) async {
    await _onBottomNavTap(1);
  }

  Future<void> _openAbout({GlobalKey? originKey}) async {
    await _onBottomNavTap(3);
  }

  Future<void> _onBottomNavTap(int index) async {
    if (!mounted) return;
    index = index.clamp(0, 5);
    if (_isStudentNavBusy) return;
    final previousIndex = _bottomNavIndex;
    if (index == previousIndex) {
      await IrisHaptics.navTransition(from: previousIndex, to: index);
      return;
    }

    setState(() => _isStudentNavBusy = true);
    await IrisHaptics.navTransition(from: previousIndex, to: index);
    await IrisHaptics.destinationOpen(destination: index);

    if (!mounted) return;
    const lockDuration = Duration(milliseconds: 420);
    setState(() {
      _facultyTabSlideDirection = index > previousIndex ? 1 : -1;
      _bottomNavIndex = index;
    });

    await Future<void>.delayed(lockDuration);
    if (!mounted) return;
    setState(() => _isStudentNavBusy = false);

    if (index == 0) {
      _updateScheduleCache();
    }
  }

  void _setFacultyTabFromDrag(int index) {
    if (!mounted) return;
    if (_isStudentNavBusy) return;
    if (index == _bottomNavIndex) return;
    index = index.clamp(0, 3);
    setState(() {
      _facultyTabSlideDirection = index > _bottomNavIndex ? 1 : -1;
      _bottomNavIndex = index;
    });
    IrisHaptics.chipSelect();
    if (index == 0) {
      _updateScheduleCache();
    }
  }

  void _handleFacultyNavDrag(DragUpdateDetails details, double width) {
    if (width <= 0) return;
    final safeDx = details.localPosition.dx.clamp(0.0, width - 1);
    final itemWidth = width / 4;
    final targetIndex = (safeDx / itemWidth).floor().clamp(0, 3);
    _setFacultyTabFromDrag(targetIndex);
  }

  Widget _buildFacultyTabContent() {
    switch (_bottomNavIndex) {
      case 1:
        return _TeacherLocatorScreen(
          key: const PageStorageKey<String>('faculty_tab_teacher'),
          brain: widget.brain,
          onTeacherSelected: (teacherName) {
            _saveSelectedTeacher(teacherName);
            if (mounted) {
              setState(() {
                _facultyTabSlideDirection = -1;
                _bottomNavIndex = 0;
              });
            }
          },
          onRoleChanged: widget.onRoleChanged,
          showDock: false,
          showBackButton: false,
          closeOnTeacherSelect: false,
        );
      case 2:
        return const PortalScreen(
          key: PageStorageKey<String>('faculty_tab_portal'),
          url:
              'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
          title: 'COMSATS Faculty Portal',
          sessionScope: 'faculty',
          showBackButton: false,
        );
      case 3:
        return AboutScreen(
          key: const PageStorageKey<String>('faculty_tab_about'),
          onRoleChanged: widget.onRoleChanged,
          onSetThemeMode: widget.onSetThemeMode,
          currentThemeMode: widget.currentThemeMode,
          showDock: false,
          showCloseButton: false,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomNavBar(bool isDark) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 420;
    final veryCompact = width < 360;
    final horizontalPadding = veryCompact ? 10.0 : (compact ? 12.0 : 20.0);
    final radius = veryCompact ? 18.0 : (compact ? 22.0 : 28.0);

    final navActive = _bottomNavIndex != 0;
    final activeGlow = _bottomNavIndex == 0
        ? Colors.transparent
        : IrisTokens.purple.withValues(alpha: isDark ? 0.18 : 0.13);

    return AnimatedScale(
      duration: const Duration(milliseconds: 352),
      curve: IrisMotion.standard,
      scale: _navBarReady ? 1.0 : 0.93,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 336),
        curve: IrisMotion.standard,
        offset: _navBarReady ? Offset.zero : const Offset(0, 0.45),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 352),
          opacity: _navBarReady ? 1.0 : 0.0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              10,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: IrisMotion.reduceBlur
                      ? 6
                      : (_bottomNavIndex == 0 ? 16 : 20),
                  sigmaY: IrisMotion.reduceBlur
                      ? 6
                      : (_bottomNavIndex == 0 ? 16 : 20),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 304),
                  curve: IrisMotion.standard,
                  decoration: BoxDecoration(
                    color:
                        (isDark ? IrisTokens.surfaceDarkElevated : Colors.white)
                            .withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: (isDark ? Colors.white : IrisTokens.purple)
                          .withValues(alpha: navActive ? 0.14 : 0.08),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.28 : 0.08,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: activeGlow,
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = constraints.maxWidth / 4;
                      final trailWidth = (itemWidth * 0.34).clamp(
                        14.0,
                        veryCompact ? 20.0 : (compact ? 24.0 : 30.0),
                      );
                      final haloSize = (itemWidth * 0.70).clamp(
                        28.0,
                        veryCompact ? 36.0 : (compact ? 44.0 : 52.0),
                      );
                      final left =
                          (itemWidth * _bottomNavIndex) +
                          ((itemWidth - trailWidth) / 2);
                      final haloLeft =
                          (itemWidth * _bottomNavIndex) +
                          ((itemWidth - haloSize) / 2);
                      final trailColor = isDark
                          ? Colors.white.withValues(alpha: 0.70)
                          : IrisTokens.purple.withValues(alpha: 0.80);

                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) =>
                            _handleFacultyNavDrag(
                              details,
                              constraints.maxWidth,
                            ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: haloLeft,
                              top: veryCompact ? 9 : (compact ? 8 : 7),
                              child: IgnorePointer(
                                child: _NavActiveHalo(
                                  size: haloSize,
                                  color: trailColor,
                                ),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 304),
                              curve: IrisMotion.standard,
                              left: left,
                              top: 0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 304),
                                curve: IrisMotion.standard,
                                width: trailWidth,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: trailColor,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: trailColor.withValues(alpha: 0.20),
                                      blurRadius: 8,
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                veryCompact ? 4 : (compact ? 6 : 8),
                                veryCompact ? 5 : (compact ? 6 : 8),
                                veryCompact ? 4 : (compact ? 6 : 8),
                                veryCompact ? 3 : (compact ? 4 : 6),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _BouncyNavButton(
                                      icon: _bottomNavIndex == 0
                                          ? Icons.home_filled
                                          : Icons.home_rounded,
                                      label: 'Home',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 0,
                                      activeColor: IrisTokens.purple,
                                      onTap: () => _onBottomNavTap(0),
                                    ),
                                  ),
                                  Expanded(
                                    child: _BouncyNavButton(
                                      launchIconKey: _facultyTeacherNavKey,
                                      icon: _bottomNavIndex == 1
                                          ? Icons.badge_rounded
                                          : Icons.badge_outlined,
                                      label: 'Teacher',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 1,
                                      activeColor: IrisTokens.purple,
                                      onTap: () => _onBottomNavTap(1),
                                    ),
                                  ),
                                  Expanded(
                                    child: _BouncyNavButton(
                                      launchIconKey: _facultyPortalNavKey,
                                      icon: Icons.public_rounded,
                                      label: 'Portal',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 2,
                                      activeColor: IrisTokens.purple,
                                      onTap: () => _onBottomNavTap(2),
                                    ),
                                  ),
                                  Expanded(
                                    child: _BouncyNavButton(
                                      launchIconKey: _facultyAboutNavKey,
                                      icon: _bottomNavIndex == 3
                                          ? Icons.info_rounded
                                          : Icons.info_outline_rounded,
                                      label: 'About',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 3,
                                      activeColor: IrisTokens.purple,
                                      onTap: () => _onBottomNavTap(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateScheduleCache() {
    final teacher = _selectedTeacher;
    if (teacher == null || teacher.isEmpty) {
      _cachedSchedule = [];
      return;
    }

    final now = DateTime.now();
    final schedule = _overrideDayIndex != null
        ? _scheduleForDay(teacher, _overrideDayIndex!)
        : _buildSuggestedScheduleForTeacher(teacher, now);

    // Merge consecutive slots of the same lecture for cleaner display
    final mergedSchedule = widget.brain.getMergedConsecutiveSessions(schedule);

    // Ensure final schedule is always sorted in ascending order by start time
    mergedSchedule.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    _cachedSchedule = mergedSchedule;
    _lastScheduleUpdate = now;
  }

  List<ClassSession> _scheduleForDay(String teacher, int dayIndex) {
    final allSessions = widget.brain.scheduleForTeacher(teacher);
    final daySchedule =
        allSessions.where((s) => s.dayIndex == dayIndex).toList()
          ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    return daySchedule;
  }

  List<ClassSession> _buildSuggestedScheduleForTeacher(
    String teacher,
    DateTime now,
  ) {
    final all = widget.brain.scheduleForTeacher(teacher);
    if (all.isEmpty) return [];

    final currentTime = now.hour + (now.minute / 60.0);
    final today = all.where((s) => s.dayIndex == now.weekday).toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    if (today.isNotEmpty) {
      // Check if all today's classes have ended
      final allClassesEnded = today.every((s) => s.safeEndVal <= currentTime);

      if (allClassesEnded) {
        // All classes done for today, show next day automatically
        return _nextDayScheduleForTeacher(all, now.weekday);
      }

      return today; // Show today's full schedule
    }

    return _nextDayScheduleForTeacher(all, now.weekday);
  }

  List<ClassSession> _nextDayScheduleForTeacher(
    List<ClassSession> all,
    int todayIndex,
  ) {
    for (int offset = 1; offset <= 6; offset++) {
      final nextDay = ((todayIndex + offset - 1) % 7) + 1;
      final daySchedule = all.where((s) => s.dayIndex == nextDay).toList()
        ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      if (daySchedule.isNotEmpty) {
        return daySchedule;
      }
    }
    return [];
  }

  String _formatDateLabel(DateTime now) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[(now.weekday - 1) % 7];
    final monthName = months[(now.month - 1).clamp(0, 11)];
    return '$dayName, $monthName ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_bottomNavIndex != 0) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: IrisMotion.entrance,
                switchOutCurve: IrisMotion.standard,
                transitionBuilder: (child, animation) {
                  final isIncoming =
                      child.key == ValueKey<int>(_bottomNavIndex);
                  final direction = _facultyTabSlideDirection.toDouble();
                  
                  // Slide animation: more dramatic distance
                  final slideBegin = isIncoming
                      ? Offset(0.42 * direction, 0)
                      : Offset.zero;
                  final slideEnd = isIncoming
                      ? Offset.zero
                      : Offset(-0.42 * direction, 0);
                  final slideAnimation = Tween<Offset>(begin: slideBegin, end: slideEnd).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: IrisMotion.standard,
                    ),
                  );
                  
                  // Scale animation: adds depth
                  final scaleBegin = isIncoming ? 0.92 : 1.0;
                  final scaleEnd = isIncoming ? 1.0 : 0.96;
                  final scaleAnimation = Tween<double>(begin: scaleBegin, end: scaleEnd).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: IrisMotion.standard,
                    ),
                  );
                  
                  // Fade animation: smoother opacity change
                  final opacityAnimation = Tween<double>(
                    begin: isIncoming ? 0.0 : 1.0,
                    end: isIncoming ? 1.0 : 0.0,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: IrisMotion.standard,
                    ),
                  );
                  
                  return FadeTransition(
                    opacity: opacityAnimation,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      child: SlideTransition(position: slideAnimation, child: child),
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_bottomNavIndex),
                  child: _buildFacultyTabContent(),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: _buildBottomNavBar(isDark)),
            ),
          ],
        ),
      );
    }

    final teacher = _selectedTeacher;
    final now = DateTime.now();
    final dateLabel = _formatDateLabel(now);

    // Build schedule cache for selected teacher
    if (teacher != null && teacher.isNotEmpty) {
      if (_lastScheduleUpdate == null ||
          _lastScheduleUpdate!.day != now.day ||
          _cachedSchedule.isEmpty) {
        _updateScheduleCache();
      }
    }

    final schedule = (teacher != null && teacher.isNotEmpty)
        ? _cachedSchedule
        : <ClassSession>[];
    var insight = teacher != null && teacher.isNotEmpty
        ? widget.brain.buildTeacherTemporalInsight(teacher, now)
        : null;

    // For faculty, update insight to show batch instead of teacher name
    if (insight != null && teacher != null) {
      final current = widget.brain.getCurrentClassForTeacher(teacher, now);
      String batchName = teacher;
      if (current != null) {
        batchName = current.batchKey.batch;
      } else {
        // Try to get batch from any session for this teacher
        final allSessions = widget.brain.memory.sessions
            .where(
              (s) =>
                  s.teacher.trim().toLowerCase() ==
                  teacher.trim().toLowerCase(),
            )
            .toList();
        if (allSessions.isNotEmpty) {
          batchName = allSessions.first.batchKey.batch;
        }
      }
      insight = TemporalInsight(
        headline: insight.headline,
        subline: insight.subline,
        isLive: insight.isLive,
        timeInfo: insight.timeInfo,
        teacherInfo: batchName,
        isUrgent: insight.isUrgent,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          _NeuralAura(background: isDark),
          SafeArea(
            child: teacher == null || teacher.isEmpty
                ? _buildTeacherSelectionView(isDark)
                : _buildFacultyScheduleView(
                    isDark,
                    teacher,
                    schedule,
                    now,
                    dateLabel,
                    insight!,
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: _buildBottomNavBar(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherSelectionView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced premium header card with staggered animation
          _MotionSlideFade(
            beginOffset: const Offset(0, 20),
            duration: IrisMotion.medium,
            curve: IrisMotion.entrance,
            child: Container(
              padding: const EdgeInsets.all(IrisTokens.space24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isDark ? Colors.white : IrisTokens.purple).withValues(alpha: 
                      isDark ? 0.14 : 0.20,
                    ),
                    (isDark ? Colors.white : IrisTokens.purpleLight)
                        .withValues(alpha: isDark ? 0.10 : 0.16),
                    (isDark
                            ? Colors.white
                            : IrisTokens.purpleLight.withValues(alpha: 0.7))
                        .withValues(alpha: isDark ? 0.07 : 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(IrisTokens.radius24),
                border: Border.all(
                  color: (isDark ? Colors.white : IrisTokens.purple)
                      .withValues(alpha: isDark ? 0.20 : 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: IrisTokens.purple.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: IrisTokens.purpleLight.withValues(alpha: 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              IrisTokens.purple.withValues(alpha: 0.85),
                              IrisTokens.purpleLight.withValues(alpha: 0.75),
                              IrisTokens.purpleLight
                                  .withValues(alpha: 0.7)
                                  .withValues(alpha: 0.65),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: IrisTokens.purple.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  IrisTokens.purple,
                                  IrisTokens.purpleLight,
                                  IrisTokens.purpleLight,
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'Faculty Dashboard',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                  letterSpacing: 0.4,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Manage your teaching schedule',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.86),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : IrisTokens.purple)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isDark ? Colors.white : IrisTokens.purple)
                                .withValues(alpha: 0.20),
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            IrisHaptics.actionSoft();
                            widget.onToggleTheme();
                          },
                          tooltip: isDark
                              ? 'Switch to light mode'
                              : 'Switch to dark mode',
                          icon: Icon(
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.94)
                                : IrisTokens.purple,
                          ),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Enhanced instructions card with staggered animation
          _MotionSlideFade(
            beginOffset: const Offset(0, 30),
            duration: IrisMotion.medium,
            curve: IrisMotion.entrance,
            child: GlassCard(
              enableOverlay: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              IrisTokens.purple.withValues(alpha: 0.18),
                              IrisTokens.purpleLight.withValues(alpha: 0.12),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: IrisTokens.purple.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.lightbulb_rounded,
                          size: 20,
                          color: IrisTokens.purple,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Get Started',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 0.3,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                        0.03,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      'Select your name to view your complete teaching schedule, monitor live classes, and access faculty management tools.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            IrisTokens.purple,
                            IrisTokens.purpleLight,
                            IrisTokens.purpleLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: IrisTokens.purple.withValues(alpha: 0.40),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: IrisTokens.purpleLight.withValues(alpha: 0.20),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: AnimatedButton(
                        key: _facultySelectTeacherCtaKey,
                        onPressed: () => _openTeacherPicker(
                          originKey: _facultySelectTeacherCtaKey,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.badge_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Select My Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildFacultyHeaderBadge({bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IrisTokens.purple.withValues(alpha: 0.9),
            IrisTokens.purpleLight.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: IrisTokens.purple.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(
        Icons.badge_rounded,
        color: Colors.white,
        size: compact ? 20 : 24,
      ),
    );
  }

  Widget _buildFacultyHeaderTitle(String teacher, bool isDark, bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teaching Today',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: compact ? 10 : 11,
            letterSpacing: compact ? 0.6 : 0.8,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.50),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          teacher,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: compact ? 18 : 20,
            letterSpacing: 0.2,
            color: isDark ? Colors.white : Colors.black,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildFacultyChangeTeacherButton({
    bool compact = false,
    GlobalKey? originKey,
  }) {
    return AnimatedButton(
      key: originKey,
      onPressed: () => _openTeacherPicker(originKey: originKey),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: IrisTokens.purple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: IrisTokens.purple.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              size: compact ? 13 : 14,
              color: IrisTokens.purple,
            ),
            const SizedBox(width: 4),
            Text(
              'Change',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 10 : 11,
                color: IrisTokens.purple,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyThemeToggleButton(bool isDark, {bool compact = false}) {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : IrisTokens.purple).withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isDark ? Colors.white : IrisTokens.purple).withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: IconButton(
        onPressed: () {
          IrisHaptics.actionSoft();
          widget.onToggleTheme();
        },
        tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        icon: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: compact ? 17 : 18,
          color: isDark
              ? Colors.white.withValues(alpha: 0.82)
              : IrisTokens.purple,
        ),
        padding: EdgeInsets.all(compact ? 7 : 8),
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildFacultyScheduleView(
    bool isDark,
    String teacher,
    List<ClassSession> schedule,
    DateTime now,
    String dateLabel,
    TemporalInsight insight,
  ) {
    final filteredSchedule = schedule;
    final profile = _matchSelectedTeacherProfile();
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactCard = screenWidth < 400;
    final isVeryCompactCard = screenWidth < 360;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: IrisTokens.brand,
      backgroundColor: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
      strokeWidth: 2.5,
      displacement: 60,
      child: CustomScrollView(
        physics: const ButterScrollPhysics(),
        cacheExtent: 500,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: EdgeInsets.all(
                  isVeryCompactCard
                      ? IrisTokens.space16
                      : (isCompactCard
                            ? IrisTokens.space20
                            : IrisTokens.space24),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (isDark ? Colors.white : IrisTokens.purple).withValues(alpha: 
                        isDark ? 0.10 : 0.12,
                      ),
                      (isDark ? Colors.white : IrisTokens.purpleLight)
                          .withValues(alpha: isDark ? 0.06 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(IrisTokens.radius24),
                  border: Border.all(
                    color: (isDark ? Colors.white : IrisTokens.purple)
                        .withValues(alpha: isDark ? 0.20 : 0.30),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: IrisTokens.purple.withValues(alpha: 
                        isDark ? 0.12 : 0.09,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isCompactCard)
                      Row(
                        children: [
                          _buildFacultyHeaderBadge(),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildFacultyHeaderTitle(
                              teacher,
                              isDark,
                              false,
                            ),
                          ),
                          _buildFacultyChangeTeacherButton(
                            originKey: _facultyChangeTeacherKey,
                          ),
                          const SizedBox(width: 8),
                          _buildFacultyThemeToggleButton(isDark),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFacultyHeaderBadge(compact: true),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFacultyHeaderTitle(
                                  teacher,
                                  isDark,
                                  true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildFacultyChangeTeacherButton(
                                compact: true,
                                originKey: _facultyChangeTeacherKey,
                              ),
                              const SizedBox(width: 8),
                              _buildFacultyThemeToggleButton(
                                isDark,
                                compact: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    if (profile != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 46,
                                    height: 46,
                                    child:
                                        _resolveFacultyImageUrl(profile.image)
                                                .isEmpty
                                            ? Container(
                                                color: IrisTokens.brand.withValues(
                                                  alpha: 0.15,
                                                ),
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  color: IrisTokens.brand,
                                                  size: 22,
                                                ),
                                              )
                                            : Image.network(
                                                _resolveFacultyImageUrl(
                                                  profile.image,
                                                ),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  color: IrisTokens.brand
                                                      .withValues(alpha: 0.15),
                                                  child: const Icon(
                                                    Icons.person_rounded,
                                                    color: IrisTokens.brand,
                                                    size: 22,
                                                  ),
                                                ),
                                              ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.department.isEmpty
                                            ? 'Department unavailable'
                                            : profile.department,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.76),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        profile.location.isEmpty
                                            ? 'Location unavailable'
                                            : profile.location,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.58),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: IrisTokens.brand.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: IrisTokens.brand.withValues(
                                        alpha: 0.24,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _facultySourceLabel(_facultyProfilesSource),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                      color: IrisTokens.brand.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _launchFacultyEmail(profile.email),
                                    icon: const Icon(
                                      Icons.mail_outline_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Open Email'),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: IrisTokens.brand.withValues(
                                          alpha: 0.26,
                                        ),
                                      ),
                                      foregroundColor: IrisTokens.brand,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 9,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Privacy-first: personal phone is hidden in faculty mode. Student locator keeps contact actions where needed.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.52),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else if (_facultyProfilesLoading) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.07),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Loading faculty profile...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                dateLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isVeryCompactCard ? 9 : 10,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.65),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isVeryCompactCard ? 9 : 10,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.65),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _MotionScaleFade(
                beginScale: 0.85,
                duration: IrisMotion.medium,
                curve: IrisMotion.emphasized,
                child: _buildInsightCard(insight, isDark),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _buildDaySelector(now, isDark),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SectionHeader(
                title: _timelineTitle(schedule, now, _overrideDayIndex),
                subtitle: _timelineSubtitle(schedule, now, _overrideDayIndex),
                statusIndicator: _getTimelineStatusColor(
                  widget.brain,
                  teacher,
                  now,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            sliver: filteredSchedule.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: _MotionScaleFade(
                        beginScale: 0.9,
                        duration: IrisMotion.medium,
                        curve: IrisMotion.emphasized,
                        child: GlassCard(
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              TweenAnimationBuilder<double>(
                                duration: const Duration(seconds: 3),
                                tween: Tween(begin: 0.0, end: 1.0),
                                curve: IrisMotion.standard,
                                builder: (context, value, child) =>
                                    Transform.rotate(
                                      angle: value * 0.1 * 3.14159,
                                      child: child,
                                    ),
                                onEnd: () => setState(() {}),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        IrisTokens.purple.withValues(alpha: 0.25),
                                        IrisTokens.purpleLight.withValues(alpha: 
                                          0.18,
                                        ),
                                        IrisTokens.purpleLight
                                            .withValues(alpha: 0.7)
                                            .withValues(alpha: 0.12),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: IrisTokens.purple.withValues(alpha: 
                                          0.16,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                        spreadRadius: -4,
                                      ),
                                      BoxShadow(
                                        color: IrisTokens.purple.withValues(alpha: 
                                          0.08,
                                        ),
                                        blurRadius: 24,
                                        offset: const Offset(0, 12),
                                        spreadRadius: -8,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.self_improvement_rounded,
                                    size: 40,
                                    color: IrisTokens.purple.withValues(alpha: 0.90),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'No Classes Scheduled',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      IrisTokens.success.withValues(alpha: 0.20),
                                      IrisTokens.success
                                          .withValues(alpha: 0.8)
                                          .withValues(alpha: 0.12),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: IrisTokens.success.withValues(alpha: 0.35),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  'Time to relax and recharge 🎉',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                    color: IrisTokens.success.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final session = filteredSchedule[index];
                        final fullIndex = schedule.indexOf(session);
                        final nextSession =
                            (fullIndex >= 0 && fullIndex + 1 < schedule.length)
                            ? schedule[fullIndex + 1]
                            : null;
                        return RepaintBoundary(
                          child: _ClassCard(
                            key: ValueKey(
                              'faculty_class_${session.subject}_${session.startTime}_${session.batchKey.batch}',
                            ),
                            session: session,
                            nextSession: nextSession,
                            isFacultyView: true,
                          ),
                        );
                      },
                      childCount: filteredSchedule.length,
                      addAutomaticKeepAlives: true,
                      addRepaintBoundaries: true,
                    ),
                  ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 126)),
        ],
      ),
    );
  }

  Widget _buildInsightCard(TemporalInsight insight, bool isDark) {
    final now = DateTime.now();
    final accentColor = insight.isLive
        ? IrisTokens.success
        : insight.isUrgent
        ? IrisTokens.warning
        : IrisTokens.brand;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: insight.isLive
              ? [
                  (isDark ? Colors.white : IrisTokens.success).withValues(alpha: 
                    isDark ? 0.08 : 0.12,
                  ),
                  (isDark ? Colors.white : IrisTokens.success.withValues(alpha: 0.8))
                      .withValues(alpha: isDark ? 0.05 : 0.08),
                  (isDark ? Colors.white : IrisTokens.successDark).withValues(alpha: 
                    isDark ? 0.03 : 0.05,
                  ),
                ]
              : insight.isUrgent
              ? [
                  (isDark ? Colors.white : IrisTokens.warning).withValues(alpha: 
                    isDark ? 0.07 : 0.10,
                  ),
                  (isDark ? Colors.white : IrisTokens.warningDark).withValues(alpha: 
                    isDark ? 0.05 : 0.07,
                  ),
                  (isDark ? Colors.white : IrisTokens.warning.withValues(alpha: 0.7))
                      .withValues(alpha: isDark ? 0.03 : 0.04),
                ]
              : [
                  (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 
                    isDark ? 0.07 : 0.10,
                  ),
                  (isDark ? Colors.white : IrisTokens.brandLight).withValues(alpha: 
                    isDark ? 0.05 : 0.07,
                  ),
                  (isDark
                          ? Colors.white
                          : IrisTokens.brandLight.withValues(alpha: 0.8))
                      .withValues(alpha: isDark ? 0.03 : 0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? Colors.white : accentColor).withValues(alpha: 
            isDark ? 0.18 : 0.32,
          ),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 18),
            spreadRadius: -14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withValues(alpha: isDark ? 0.15 : 0.20),
                        accentColor.withValues(alpha: isDark ? 0.10 : 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (isDark ? Colors.white : accentColor).withValues(alpha: 
                        isDark ? 0.20 : 0.35,
                      ),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    insight.isLive
                        ? Icons.record_voice_over_rounded
                        : insight.isUrgent
                        ? Icons.notifications_active_rounded
                        : Icons.schedule_rounded,
                    color: accentColor,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            insight.headline,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              color: accentColor,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (insight.isLive)
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 1440),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: IrisMotion.standard,
                            builder: (context, value, child) {
                              final pulse = 0.5 - (value - 0.5).abs();
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      IrisTokens.success.withValues(alpha: 
                                        0.25 + (pulse * 0.15),
                                      ),
                                      IrisTokens.success
                                          .withValues(alpha: 0.8)
                                          .withValues(alpha: 0.18 + (pulse * 0.12)),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: IrisTokens.success.withValues(alpha: 
                                      0.50 + (pulse * 0.3),
                                    ),
                                    width: 1.3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: IrisTokens.success.withValues(alpha: 
                                        0.14 + (pulse * 0.12),
                                      ),
                                      blurRadius: 8 + (pulse * 4),
                                      offset: const Offset(0, 2),
                                      spreadRadius: -1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6 + (pulse * 2),
                                      height: 6 + (pulse * 2),
                                      decoration: BoxDecoration(
                                        color: IrisTokens.success,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: IrisTokens.success
                                                .withValues(alpha: 0.48),
                                            blurRadius: 5 + (pulse * 3),
                                            spreadRadius: -1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'LIVE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: IrisTokens.success,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onEnd: () => setState(() {}),
                          ),
                      ],
                    ),
                    if (insight.timeInfo != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        insight.timeInfo!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: insight.isLive
                              ? IrisTokens.success
                              : insight.isUrgent
                              ? IrisTokens.error
                              : IrisTokens.brand,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
              ),
            ),
            child: Text(
              insight.subline,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.72),
              ),
            ),
          ),
          // Live progress bar for faculty
          if (insight.isLive && _selectedTeacher != null) ...[
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final currentClass = widget.brain.getCurrentClassForTeacher(
                  _selectedTeacher!,
                  now,
                );
                if (currentClass != null) {
                  final currentTime = now.hour + (now.minute / 60.0);
                  final duration = LectureDuration.getActualDuration(
                    currentClass,
                  );
                  final actualEndTime = LectureDuration.getActualEndTime(
                    currentClass,
                  );
                  final progress =
                      ((currentTime - currentClass.safeStartVal) / duration)
                          .clamp(0.0, 1.0);
                  final minutesLeft = ((actualEndTime - currentTime) * 60)
                      .toInt()
                      .clamp(0, (duration * 60).toInt());

                  String progressLabel = '';
                  if (minutesLeft >= 60) {
                    final hours = minutesLeft ~/ 60;
                    final mins = minutesLeft % 60;
                    progressLabel = mins > 0
                        ? '${hours}h ${mins}m left'
                        : '${hours}h left';
                  } else {
                    progressLabel = '${minutesLeft}m left';
                  }

                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: TweenAnimationBuilder<double>(
                          duration: IrisMotion.medium,
                          curve: IrisMotion.entrance,
                          tween: Tween<double>(begin: 0.0, end: progress),
                          builder: (context, value, child) => Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: IrisTokens.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: value.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      IrisTokens.success,
                                      IrisTokens.success,
                                      IrisTokens.successDark,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: IrisTokens.success.withValues(alpha: 
                                        0.28,
                                      ),
                                      blurRadius: 3,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            progressLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w700,
                              color: IrisTokens.success,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w800,
                              color: IrisTokens.success.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          if (insight.teacherInfo != null || insight.timeInfo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  if (insight.timeInfo != null) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: IrisTokens.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: IrisTokens.purple.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      insight.timeInfo!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  if (insight.teacherInfo != null && insight.timeInfo != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (insight.teacherInfo != null) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: IrisTokens.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.groups_rounded,
                        size: 12,
                        color: IrisTokens.purple.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight.teacherInfo!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDaySelector(DateTime now, bool isDark) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final currentDay = _overrideDayIndex;
    final today = now.weekday; // 1=Mon
    final autoSelected = currentDay == null;

    return GlassCard(
      child: SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const ButterScrollPhysics(),
          children: [
            const SizedBox(width: 6),
            AnimatedSlide(
              duration: IrisMotion.fast,
              curve: IrisMotion.standard,
              offset: autoSelected ? const Offset(0, -0.02) : Offset.zero,
              child: AnimatedScale(
                duration: IrisMotion.fast,
                curve: IrisMotion.standard,
                scale: autoSelected ? 1.025 : 1.0,
                child: AnimatedContainer(
                  duration: IrisMotion.fast,
                  curve: IrisMotion.standard,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [],
                  ),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: autoSelected
                              ? IrisTokens.brand
                              : isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Auto',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    selected: autoSelected,
                    onSelected: (_) {
                      IrisHaptics.chipSelect();
                      setState(() {
                        _overrideDayIndex = null;
                        _updateScheduleCache();
                      });
                    },
                    selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    side: BorderSide(
                      color: autoSelected
                          ? IrisTokens.brand.withValues(alpha: 0.56)
                          : isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.10),
                      width: autoSelected ? 1.4 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      color: autoSelected
                          ? IrisTokens.brand
                          : isDark
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.black.withValues(alpha: 0.65),
                    ),
                    elevation: autoSelected ? 0.6 : 0,
                    pressElevation: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ...List.generate(days.length, (index) {
              final dayIndex = index + 1;
              final isSelected = currentDay == dayIndex;
              final isToday = dayIndex == today;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedSlide(
                  duration: IrisMotion.fast,
                  curve: IrisMotion.standard,
                  offset: isSelected ? const Offset(0, -0.02) : Offset.zero,
                  child: AnimatedScale(
                    duration: IrisMotion.fast,
                    curve: IrisMotion.standard,
                    scale: isSelected ? 1.03 : 1.0,
                    child: AnimatedContainer(
                      duration: IrisMotion.fast,
                      curve: IrisMotion.standard,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [],
                      ),
                      child: ChoiceChip(
                        avatar: isToday && !isSelected
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: IrisTokens.success,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        label: Text(
                          days[index],
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          IrisHaptics.chipSelect();
                          setState(() {
                            _overrideDayIndex = dayIndex == today
                                ? null
                                : dayIndex;
                            _updateScheduleCache();
                          });
                        },
                        selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        side: BorderSide(
                          color: isSelected
                              ? IrisTokens.brand.withValues(alpha: 0.56)
                              : isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.10),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? IrisTokens.brand
                              : isDark
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.black.withValues(alpha: 0.65),
                        ),
                        elevation: isSelected ? 0.6 : 0,
                        pressElevation: 1,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

// Faculty Full Schedule Screen
class _FacultyFullScheduleScreen extends StatefulWidget {
  final OmniBrain brain;
  final String teacherName;
  final VoidCallback onToggleTheme;
  final ValueChanged<String>? onRoleChanged;

  const _FacultyFullScheduleScreen({
    required this.brain,
    required this.teacherName,
    required this.onToggleTheme,
    this.onRoleChanged,
  });

  @override
  State<_FacultyFullScheduleScreen> createState() =>
      _FacultyFullScheduleScreenState();
}

class _FacultyFullScheduleScreenState
    extends State<_FacultyFullScheduleScreen> {
  int? _overrideDayIndex;
  List<ClassSession> _cachedSchedule = [];

  @override
  void initState() {
    super.initState();
    _updateScheduleCache();
  }

  void _updateScheduleCache() {
    final now = DateTime.now();
    final schedule = _overrideDayIndex != null
        ? _scheduleForDay(widget.teacherName, _overrideDayIndex!)
        : _buildSuggestedScheduleForTeacher(widget.teacherName, now);

    // Merge consecutive slots of the same lecture for cleaner display
    final mergedSchedule = widget.brain.getMergedConsecutiveSessions(schedule);

    // Ensure final schedule is always sorted in ascending order by start time
    mergedSchedule.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    setState(() {
      _cachedSchedule = mergedSchedule;
    });
  }

  List<ClassSession> _scheduleForDay(String teacher, int dayIndex) {
    final allSessions = widget.brain.scheduleForTeacher(teacher);
    final daySchedule =
        allSessions.where((s) => s.dayIndex == dayIndex).toList()
          ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    return daySchedule;
  }

  List<ClassSession> _buildSuggestedScheduleForTeacher(
    String teacher,
    DateTime now,
  ) {
    final all = widget.brain.scheduleForTeacher(teacher);
    if (all.isEmpty) return [];

    final currentTime = now.hour + (now.minute / 60.0);
    final today = all.where((s) => s.dayIndex == now.weekday).toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    if (today.isNotEmpty) {
      final allClassesEnded = today.every((s) => s.safeEndVal <= currentTime);

      if (allClassesEnded) {
        return _nextDayScheduleForTeacher(all, now.weekday);
      }

      return today;
    }

    return _nextDayScheduleForTeacher(all, now.weekday);
  }

  List<ClassSession> _nextDayScheduleForTeacher(
    List<ClassSession> all,
    int todayIndex,
  ) {
    for (int offset = 1; offset <= 6; offset++) {
      final nextDay = ((todayIndex + offset - 1) % 7) + 1;
      final daySchedule = all.where((s) => s.dayIndex == nextDay).toList()
        ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      if (daySchedule.isNotEmpty) {
        return daySchedule;
      }
    }
    return [];
  }

  String _formatDateLabel(DateTime now) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[(now.weekday - 1) % 7];
    final monthName = months[(now.month - 1).clamp(0, 11)];
    return '$dayName, $monthName ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final dateLabel = _formatDateLabel(now);
    final schedule = _cachedSchedule;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactCard = screenWidth < 400;
    final isVeryCompactCard = screenWidth < 360;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        leading: _AppBackButton(isDark: isDark),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  IrisHaptics.actionSoft();
                  widget.onToggleTheme();
                },
                tooltip: isDark
                    ? 'Switch to light mode'
                    : 'Switch to dark mode',
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark),
          SafeArea(
            child: CustomScrollView(
              physics: const ButterScrollPhysics(),
              cacheExtent: 500,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: GlassCard(
                      padding: EdgeInsets.fromLTRB(
                        isVeryCompactCard ? 14 : (isCompactCard ? 16 : 20),
                        isVeryCompactCard ? 14 : 16,
                        isVeryCompactCard ? 14 : (isCompactCard ? 16 : 20),
                        isVeryCompactCard ? 14 : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isVeryCompactCard ? 8 : 10,
                                  vertical: isVeryCompactCard ? 4 : 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [IrisTokens.blue, IrisTokens.blue],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: IrisTokens.blue.withValues(alpha: 0.22),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/iris_logo.png',
                                      width: isVeryCompactCard ? 10 : 11,
                                      height: isVeryCompactCard ? 10 : 11,
                                      fit: BoxFit.cover,
                                    ),
                                    SizedBox(width: isVeryCompactCard ? 4 : 5),
                                    Text(
                                      'IRIS',
                                      style: TextStyle(
                                        letterSpacing: 2.5,
                                        fontSize: isVeryCompactCard ? 8 : 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'FACULTY SCHEDULE',
                                  style: TextStyle(
                                    fontSize: isVeryCompactCard ? 11 : 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: isDark ? 0.46 : 0.40),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isVeryCompactCard ? 10 : 12,
                              vertical: isVeryCompactCard ? 6 : 7,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: isVeryCompactCard ? 12 : 13,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.62),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: isVeryCompactCard ? 11 : 12,
                                    letterSpacing: 0.35,
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: 0.78),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.teacherName,
                            maxLines: isCompactCard ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: isVeryCompactCard
                                  ? 19
                                  : (isCompactCard ? 20 : 22),
                              height: 1.1,
                              letterSpacing: 0.2,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _buildDaySelector(now, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: _buildScheduleHeader(schedule, now, isDark),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  sliver: schedule.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 50,
                              horizontal: 20,
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 40,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      IrisTokens.brand.withValues(alpha: 
                                        isDark ? 0.12 : 0.08,
                                      ),
                                      IrisTokens.brandLight.withValues(alpha: 
                                        isDark ? 0.06 : 0.03,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: IrisTokens.brand.withValues(alpha: 
                                      isDark ? 0.20 : 0.12,
                                    ),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: IrisTokens.brand.withValues(alpha: 0.12),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            IrisTokens.brand.withValues(alpha: 0.15),
                                            IrisTokens.brandLight.withValues(alpha: 
                                              0.08,
                                            ),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.beach_access_rounded,
                                        size: 36,
                                        color: IrisTokens.brand.withValues(alpha: 
                                          0.80,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'No Classes Today',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        letterSpacing: 0.3,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'You\'re all set for the day! 🎉',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, index) {
                              final session = schedule[index];
                              final nextSession = index + 1 < schedule.length
                                  ? schedule[index + 1]
                                  : null;
                              return StaggeredListItem(
                                index: index,
                                child: RepaintBoundary(
                                  child: _ClassCard(
                                    key: ValueKey(
                                      'faculty_class_${session.subject}_${session.startTime}_${session.batchKey.batch}',
                                    ),
                                    session: session,
                                    nextSession: nextSession,
                                    isFacultyView: true,
                                  ),
                                ),
                              );
                            },
                            childCount: schedule.length,
                            addAutomaticKeepAlives: true,
                            addRepaintBoundaries: true,
                          ),
                        ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 118)),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _SmartScreenDock(
                showFacultySet: true,
                selectedIndex: 1,
                onTeacher: () => pushIconLaunchRoute(
                  context,
                  page: _TeacherLocatorScreen(brain: widget.brain),
                ),
                onPortal: () => pushIconLaunchRoute(
                  context,
                  page: const PortalScreen(
                    url:
                        'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
                    title: 'COMSATS Faculty Portal',
                    sessionScope: 'faculty',
                  ),
                ),
                onAbout: () => pushIconLaunchRoute(
                  context,
                  page: AboutScreen(onRoleChanged: widget.onRoleChanged),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(DateTime now, bool isDark) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final currentDay = _overrideDayIndex;
    final today = now.weekday; // 1=Mon
    final autoSelected = currentDay == null;

    return GlassCard(
      child: SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const ButterScrollPhysics(),
          children: [
            const SizedBox(width: 6),
            AnimatedSlide(
              duration: IrisMotion.fast,
              curve: IrisMotion.standard,
              offset: autoSelected ? const Offset(0, -0.02) : Offset.zero,
              child: AnimatedScale(
                duration: IrisMotion.fast,
                curve: IrisMotion.standard,
                scale: autoSelected ? 1.025 : 1.0,
                child: AnimatedContainer(
                  duration: IrisMotion.fast,
                  curve: IrisMotion.standard,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [],
                  ),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: autoSelected
                              ? IrisTokens.brand
                              : isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Auto',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    selected: autoSelected,
                    onSelected: (_) {
                      IrisHaptics.chipSelect();
                      setState(() {
                        _overrideDayIndex = null;
                        _updateScheduleCache();
                      });
                    },
                    selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    side: BorderSide(
                      color: autoSelected
                          ? IrisTokens.brand.withValues(alpha: 0.56)
                          : isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.10),
                      width: autoSelected ? 1.4 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      color: autoSelected
                          ? IrisTokens.brand
                          : isDark
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.black.withValues(alpha: 0.65),
                    ),
                    elevation: autoSelected ? 0.6 : 0,
                    pressElevation: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ...List.generate(days.length, (index) {
              final dayIndex = index + 1;
              final isSelected = currentDay == dayIndex;
              final isToday = dayIndex == today;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedSlide(
                  duration: IrisMotion.fast,
                  curve: IrisMotion.standard,
                  offset: isSelected ? const Offset(0, -0.02) : Offset.zero,
                  child: AnimatedScale(
                    duration: IrisMotion.fast,
                    curve: IrisMotion.standard,
                    scale: isSelected ? 1.03 : 1.0,
                    child: AnimatedContainer(
                      duration: IrisMotion.fast,
                      curve: IrisMotion.standard,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [],
                      ),
                      child: ChoiceChip(
                        avatar: isToday && !isSelected
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: IrisTokens.success,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        label: Text(
                          days[index],
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          IrisHaptics.chipSelect();
                          setState(() {
                            _overrideDayIndex = dayIndex == today
                                ? null
                                : dayIndex;
                            _updateScheduleCache();
                          });
                        },
                        selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        side: BorderSide(
                          color: isSelected
                              ? IrisTokens.brand.withValues(alpha: 0.56)
                              : isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.10),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? IrisTokens.brand
                              : isDark
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.black.withValues(alpha: 0.65),
                        ),
                        elevation: isSelected ? 0.6 : 0,
                        pressElevation: 1,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleHeader(
    List<ClassSession> schedule,
    DateTime now,
    bool isDark,
  ) {
    final dayIndex =
        _overrideDayIndex ?? schedule.firstOrNull?.dayIndex ?? now.weekday;
    String title;
    String subtitle;
    Color statusColor = IrisTokens.brand;

    if (schedule.isEmpty && _overrideDayIndex != null) {
      title = '${FormatGuard.normalizeDay(_overrideDayIndex!)} SCHEDULE';
      subtitle = 'No classes scheduled • Free day! 🎉';
      statusColor = IrisTokens.purple;
    } else if (schedule.isEmpty) {
      title = 'NO CLASSES';
      subtitle = 'No sessions in the registry';
      statusColor = IrisTokens.brand;
    } else {
      if (dayIndex == now.weekday) {
        title = 'TODAY\'S SCHEDULE';
        final currentTime = now.hour + (now.minute / 60.0);
        final current = widget.brain.getCurrentClassForTeacher(
          widget.teacherName,
          now,
        );

        if (current != null && current.isLive(now)) {
          statusColor = IrisTokens.success;
          final remaining = schedule
              .where((s) => s.safeStartVal > currentTime)
              .length;
          final classesLeft = remaining > 0
              ? '$remaining ${remaining == 1 ? 'class' : 'classes'} left'
              : 'Last class today';
          subtitle = '${current.subject} • $classesLeft';
        } else {
          statusColor = IrisTokens.warning;
          final nextClass = schedule.firstWhere(
            (s) => s.safeStartVal > currentTime,
            orElse: () => schedule.first,
          );

          if (nextClass.safeStartVal > currentTime) {
            final minutesUntil = ((nextClass.safeStartVal - currentTime) * 60)
                .round();

            if (minutesUntil > 60) {
              subtitle =
                  '${(minutesUntil / 60).floor()}h ${minutesUntil % 60}m free • Next: ${nextClass.subject}';
            } else if (minutesUntil > 15) {
              subtitle =
                  '${minutesUntil} min break • ${nextClass.subject} in ${nextClass.room}';
            } else {
              subtitle =
                  'Starting soon: ${nextClass.subject} in ${nextClass.room} ⚡';
            }
          } else {
            subtitle =
                '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} scheduled';
          }
        }
      } else {
        statusColor = IrisTokens.brand;
        final tomorrowIndex = (now.weekday % 7) + 1;
        if (dayIndex == tomorrowIndex && _overrideDayIndex == null) {
          title = 'TOMORROW MORNING';
        } else {
          final dayName = FormatGuard.normalizeDay(dayIndex).toUpperCase();
          title = '$dayName SCHEDULE';
        }
        subtitle =
            '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} scheduled';
      }
    }

    return SectionHeader(
      title: title,
      subtitle: subtitle,
      statusIndicator: statusColor,
    );
  }
}

// Student Dashboard

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  static const String _customMakeupSessionsPrefsKey = 'custom_makeup_sessions';
  late Timer _ticker;
  ClassSession? _previousClass;
  int? _previousProgressPercent;
  String? _previousNotificationHash;
  String? _previousWidgetHash;
  int? _overrideDayIndex;
  int _bottomNavIndex = 0;
  int _studentTabSlideDirection = 1;
  bool _isStudentNavBusy = false;
  bool _navBarReady = false;
  List<ClassSession> _cachedSchedule = [];
  DateTime? _lastScheduleUpdate;
  int? _lastMinute;
  bool _isRefreshing = false;
  final Map<String, List<ClassSession>> _makeupReplacementHistory = {};
  final GlobalKey _studentPortalNavKey = GlobalKey(
    debugLabel: 'student_portal_nav',
  );
  final GlobalKey _studentToolsNavKey = GlobalKey(
    debugLabel: 'student_tools_nav',
  );
  final GlobalKey _studentAboutNavKey = GlobalKey(
    debugLabel: 'student_about_nav',
  );

  bool _isMakeupSession(ClassSession session) =>
      session.id.startsWith('makeup_');

  Future<void> _loadCustomMakeupSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_customMakeupSessionsPrefsKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final existingIds = widget.memory.sessions.map((s) => s.id).toSet();
      var changed = false;

      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final session = ClassSession.fromJson(entry);
        if (existingIds.contains(session.id)) continue;
        widget.memory.sessions.add(session);
        existingIds.add(session.id);
        changed = true;
      }

      if (changed && mounted) {
        _updateScheduleCache();
        setState(() {});
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load custom makeup sessions: $e');
    }
  }

  Future<void> _persistCustomMakeupSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = widget.memory.sessions
          .where(_isMakeupSession)
          .map((s) => s.toJson())
          .toList();
      await prefs.setString(_customMakeupSessionsPrefsKey, jsonEncode(custom));
    } catch (e) {
      debugPrint('⚠️ Failed to persist custom makeup sessions: $e');
    }
  }

  bool _sessionsOverlap(ClassSession a, ClassSession b) {
    if (a.dayIndex != b.dayIndex) return false;
    return a.safeStartVal < b.safeEndVal && b.safeStartVal < a.safeEndVal;
  }

  bool _sameSessionSignature(ClassSession a, ClassSession b) {
    return a.batchKey.batch == b.batchKey.batch &&
        a.dayIndex == b.dayIndex &&
        a.startTime == b.startTime &&
        a.endTime == b.endTime &&
        a.teacher.trim().toLowerCase() == b.teacher.trim().toLowerCase() &&
        a.subject.trim().toLowerCase() == b.subject.trim().toLowerCase();
  }

  Future<void> _addMakeupSession(ClassSession session) async {
    if (session.batchKey.batch != widget.batch) {
      if (!mounted) return;
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_different_batch',
        content: Text('This makeup class belongs to a different batch.'),
      );
      return;
    }

    final duplicate = widget.memory.sessions.any(
      (s) => s.id == session.id || _sameSessionSignature(s, session),
    );
    if (duplicate) {
      if (!mounted) return;
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_duplicate',
        content: Text('That makeup class is already in your timeline.'),
      );
      return;
    }

    final batchSessions = widget.memory.sessions
        .where((s) => s.batchKey.batch == widget.batch)
        .toList();

    final overlaps = batchSessions
        .where((s) => _sessionsOverlap(s, session))
        .toList();
    final regularConflict = overlaps
        .where((s) => !_isMakeupSession(s))
        .toList();
    if (regularConflict.isNotEmpty) {
      final conflict = regularConflict.first;
      if (!mounted) return;
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_conflict_${conflict.id}',
        content: Text(
          'Conflicts with ${conflict.subject} (${conflict.startTime}-${conflict.endTime}). Pick another slot.',
        ),
      );
      return;
    }

    // Intelligent behavior: replace overlapping makeup slots and preserve history for safe restore.
    final makeupOverlaps = overlaps.where(_isMakeupSession).toList();
    if (makeupOverlaps.isNotEmpty) {
      final overlapIds = makeupOverlaps.map((s) => s.id).toSet();
      final removedSnapshots = <ClassSession>[];

      for (final replaced in makeupOverlaps) {
        removedSnapshots.add(replaced);
        final nestedHistory =
            _makeupReplacementHistory.remove(replaced.id) ??
            const <ClassSession>[];
        removedSnapshots.addAll(nestedHistory);
      }

      final unique = <String, ClassSession>{};
      for (final item in removedSnapshots) {
        unique[item.id] = item;
      }
      _makeupReplacementHistory[session.id] = unique.values.toList();

      widget.memory.sessions.removeWhere((s) => overlapIds.contains(s.id));
    }

    widget.memory.sessions.add(session);
    await _persistCustomMakeupSessions();

    if (!mounted) return;
    _updateScheduleCache();
    setState(() {});
    _updateWidgetIfNeeded();
    _updatePersistentNotificationIfNeeded();

    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'makeup_added_${session.id}',
      content: Text(
        makeupOverlaps.isNotEmpty
            ? 'Added ${session.subject} (${session.startTime}-${session.endTime}) and replaced ${makeupOverlaps.length} overlapping makeup slot${makeupOverlaps.length == 1 ? '' : 's'}.'
            : 'Added makeup class: ${session.subject} (${session.startTime}-${session.endTime})',
      ),
    );
  }

  Future<void> _removeMakeupSession(ClassSession session) async {
    if (!_isMakeupSession(session)) return;

    final restoreCandidates =
        _makeupReplacementHistory.remove(session.id) ?? const <ClassSession>[];

    final before = widget.memory.sessions.length;
    widget.memory.sessions.removeWhere((s) => s.id == session.id);
    final removed = before - widget.memory.sessions.length;
    if (removed <= 0) return;

    var restored = 0;
    for (final candidate in restoreCandidates) {
      final duplicate = widget.memory.sessions.any(
        (s) => s.id == candidate.id || _sameSessionSignature(s, candidate),
      );
      if (duplicate) continue;

      final overlap = widget.memory.sessions.any(
        (s) =>
            s.batchKey.batch == widget.batch && _sessionsOverlap(s, candidate),
      );
      if (overlap) continue;

      widget.memory.sessions.add(candidate);
      restored += 1;
    }

    await _persistCustomMakeupSessions();

    if (!mounted) return;
    _updateScheduleCache();
    setState(() {});
    _updateWidgetIfNeeded();
    _updatePersistentNotificationIfNeeded();

    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'makeup_removed_${session.id}',
      content: Text(
        restored > 0
            ? 'Removed makeup class. Restored $restored previously replaced slot${restored == 1 ? '' : 's'}.'
            : 'Removed makeup class from timeline.',
      ),
    );
  }

  Future<void> _confirmAndRemoveMakeupSession(ClassSession session) async {
    if (!_isMakeupSession(session) || !mounted) return;
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLive = session.isLive(now);
    final currentTime = now.hour + (now.minute / 60.0);
    final minutesToStart = ((session.safeStartVal - currentTime) * 60).round();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: (isDark ? const Color(0xFF111827) : Colors.white)
              .withValues(alpha: isDark ? 0.88 : 0.92),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.12,
              ),
            ),
          ),
          title: const Text('Remove makeup class?'),
          content: Text(
            isLive
                ? 'This class is live right now. Remove it from your timeline?'
                : minutesToStart >= 0 && minutesToStart <= 15
                ? 'This class starts in $minutesToStart min. Remove it anyway?'
                : 'Remove ${session.subject} (${session.startTime}-${session.endTime}) from your timeline?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: IrisTokens.error),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _removeMakeupSession(session);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _navBarReady = true);
      }
    });
    _updateScheduleCache();
    _loadCustomMakeupSessions();
    _lastMinute = DateTime.now().minute;

    // Schedule class reminders for today
    _scheduleClassReminders();

    // Start foreground service if notifications enabled
    _startForegroundServiceIfNeeded();

    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        final now = DateTime.now();
        final current = widget.brain.getCurrentClass(widget.batch, now);
        final minuteChanged = _lastMinute != now.minute;
        if (current != _previousClass || minuteChanged) {
          setState(() {
            _lastMinute = now.minute;
            _previousClass = current;
          });
        }
        // Update notifications and widget only if state changed (smarter updates)
        _updatePersistentNotificationIfNeeded();
        _updateWidgetIfNeeded();
      }
    });
    _updatePersistentNotificationIfNeeded();
    _updateWidgetIfNeeded();
  }

  Future<void> _startForegroundServiceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // ALWAYS set role to student to prevent cross-contamination
    await prefs.setString('user_role', 'student');
    await prefs.setString('student_batch', widget.batch);

    final notificationEnabled =
        prefs.getBool('persistent_notification_enabled') ?? false;

    if (notificationEnabled) {
      // Always restart to ensure correct role data
      await _startForegroundService();
    } else {
      // If notifications disabled, stop any running service
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    }
  }

  Future<void> _startForegroundService() async {
    // Stop service if running (from previous role switch) without delay
    // Service restart is handled gracefully by Android
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }

    // Store timetable data for TaskHandler to use
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', 'student');
    await prefs.setString('student_batch', widget.batch);

    // Serialize timetable data
    final timetableData = {
      'sessions': widget.memory.sessions.map((s) => s.toJson()).toList(),
    };
    await prefs.setString('timetable_data', jsonEncode(timetableData));

    final remindersEnabled =
        prefs.getBool('lecture_reminders_enabled') ?? false;
    if (remindersEnabled) {
      // Schedule 5-minute reminders for today's classes
      final todayClasses = widget.memory.sessions
          .where(
            (s) =>
                s.batchKey.batch == widget.batch &&
                s.dayIndex == DateTime.now().weekday,
          )
          .toList();

      if (todayClasses.isNotEmpty) {
        await NotificationService().scheduleClassReminders(todayClasses);
      }
    }

    // Calculate initial notification
    final now = DateTime.now();
    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);
    final currentTime = now.hour + (now.minute / 60.0);
    final dayIndex = now.weekday;

    // Animated colored progress bar with glowy emojis
    String _bar(double p) {
      const total = 8;
      final filled = (p * total).round().clamp(0, total);
      return '🟦' * filled + '⬜' * (total - filled);
    }

    final todayAll = widget.memory.sessions
        .where(
          (s) => s.batchKey.batch == widget.batch && s.dayIndex == dayIndex,
        )
        .toList();

    String notifTitle = 'IRIS Class Tracker';
    String notifBody = 'Keeping your class schedule handy';

    if (current != null && current.isLive(now)) {
      final duration = LectureDuration.getActualDuration(current);
      final actualEndTime = LectureDuration.getActualEndTime(current);
      final progress = ((currentTime - current.safeStartVal) / duration).clamp(
        0.0,
        1.0,
      );
      final progressPercent = (progress * 100).toInt();

      final minutesRemaining = ((actualEndTime - currentTime) * 60)
          .round()
          .clamp(0, (duration * 60).round());
      final hoursRemaining = minutesRemaining ~/ 60;
      final minsRemaining = minutesRemaining % 60;

      String timeLeft = hoursRemaining > 0
          ? '${hoursRemaining}h ${minsRemaining}m left'
          : minsRemaining > 0
          ? '${minsRemaining}m left'
          : 'Ending now';

      final remaining = todayAll
          .where((s) => s.safeStartVal > currentTime)
          .length;
      final classCount = remaining > 0
          ? ' · $remaining more today'
          : ' · Last one';

      notifTitle = '🎓 ${current.subject} · $timeLeft';
      notifBody =
          '${_bar(progress)} $progressPercent%$classCount\n📍 ${current.room} · ${current.teacher}';
    } else if (next != null) {
      int daysAhead = 0;
      if (next.dayIndex != dayIndex) {
        daysAhead = (next.dayIndex - dayIndex + 7) % 7;
        if (daysAhead == 0) daysAhead = 7;
      }
      final totalMinutesUntil = daysAhead > 0
          ? ((24.0 - currentTime) * 60 +
                    (daysAhead - 1) * 24 * 60 +
                    next.safeStartVal * 60)
                .round()
          : ((next.safeStartVal - currentTime) * 60).round();
      final hoursUntil = totalMinutesUntil ~/ 60;
      final minsUntil = totalMinutesUntil % 60;

      String timeUntil = '';
      String emoji = '📌';
      if (daysAhead > 0) {
        const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final nextDayName = dayNames[next.dayIndex];
        final startHour = next.safeStartVal.floor();
        final startMin = ((next.safeStartVal - startHour) * 60).round();
        final displayHour = startHour > 12 ? startHour - 12 : startHour;
        final amPm = startHour >= 12 ? 'PM' : 'AM';
        timeUntil =
            '$nextDayName ${displayHour}:${startMin.toString().padLeft(2, '0')} $amPm';
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

      final remainingToday = todayAll
          .where((s) => s.safeStartVal > currentTime)
          .length;

      String classInfo;
      if (daysAhead > 0) {
        classInfo = 'Done for today ✓';
      } else if (remainingToday > 1) {
        classInfo = '$remainingToday classes left';
      } else {
        classInfo = 'Last class today';
      }

      notifTitle = '$emoji ${next.subject} in $timeUntil';
      notifBody = '$classInfo\n📍 ${next.room} · ${next.teacher}';
    } else {
      final weekday = now.weekday;
      if (weekday == 6 || weekday == 7) {
        notifTitle = '🎉 Weekend Mode';
        notifBody = 'No classes — enjoy your break!';
      } else {
        notifTitle = '✓ All done for today';
        notifBody = 'No more classes scheduled';
      }
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: notifTitle,
      notificationText: notifBody,
      notificationIcon: null,
      notificationButtons: [NotificationButton(id: 'open', text: 'Open IRIS')],
      callback: startClassNotificationTask,
    );
  }

  @override
  void didUpdateWidget(Dashboard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detect batch change and refresh everything
    if (widget.batch != oldWidget.batch) {
      _updateScheduleCache();
      _previousClass = null;
      // Force rebuild of timeline cards and UI
      setState(() {});
      _scheduleClassReminders();
      _updatePersistentNotificationIfNeeded();
      _updateWidgetIfNeeded();
    }
  }

  String _formatDateLabel(DateTime now) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[(now.weekday - 1) % 7];
    final monthName = months[(now.month - 1).clamp(0, 11)];
    return '$dayName, $monthName ${now.day}';
  }

  void _updateScheduleCache() {
    final now = DateTime.now();
    _cachedSchedule = _buildTimelineSchedule(now);
    _lastScheduleUpdate = now;
  }

  void _scheduleClassReminders() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        final remindersEnabled =
            prefs.getBool('lecture_reminders_enabled') ?? false;
        if (!remindersEnabled) {
          NotificationService().cancelScheduledClassReminders();
          return;
        }

        // Get today's classes for the student's batch
        final todayClasses = widget.memory.sessions
            .where(
              (s) =>
                  s.batchKey.batch == widget.batch &&
                  s.dayIndex == DateTime.now().weekday,
            )
            .toList();

        if (todayClasses.isNotEmpty) {
          NotificationService().scheduleClassReminders(todayClasses);
        }
      });
    } catch (e) {
      // Silently handle scheduling errors - non-critical feature
      debugPrint('⚠️ Failed to schedule class reminders: $e');
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    // Don't stop foreground service here - it should persist
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    IrisHaptics.refreshStart();

    setState(() => _isRefreshing = true);

    // Simulate data refresh delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Refresh schedule cache
    _updateScheduleCache();

    // Update widget and notifications
    _updateWidgetIfNeeded();
    _updatePersistentNotificationIfNeeded();

    setState(() => _isRefreshing = false);
    IrisHaptics.refreshSuccess();

    // Show success feedback
    if (mounted) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'schedule_refreshed_faculty',
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              'Schedule refreshed',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        tint: IrisTokens.success,
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _updatePersistentNotificationIfNeeded() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final notificationEnabled =
        prefs.getBool('persistent_notification_enabled') ?? false;

    if (!notificationEnabled) return;

    // Health check: restart service if it should be running but isn't
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      print('⚠️ Service not running but should be - restarting...');
      await _startForegroundService();
      return; // Service will update on its own after start
    }

    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);
    final currentTime = now.hour + (now.minute / 60.0);
    final dayIndex = now.weekday;

    // Calculate state hash to determine if update is needed
    String _generateStateHash() {
      if (current != null && current.isLive(now)) {
        final duration = LectureDuration.getActualDuration(current);
        final progress = ((currentTime - current.safeStartVal) / duration)
            .clamp(0.0, 1.0);
        final progressPercent = (progress * 100).toInt();
        return 'live_${current.subject}_${progressPercent}';
      } else if (next != null) {
        return 'next_${next.subject}_${next.safeStartVal}';
      }
      return 'idle';
    }

    final currentHash = _generateStateHash();

    // Only update if state changed significantly (class changed or progress milestone reached)
    if (_previousNotificationHash == currentHash && current == _previousClass) {
      return; // No meaningful change, skip update
    }

    _previousNotificationHash = currentHash;

    // Animated colored progress bar with glowy emojis
    String _bar(double p) {
      const total = 8;
      final filled = (p * total).round().clamp(0, total);
      return '🟦' * filled + '⬜' * (total - filled);
    }

    final todayAll = widget.memory.sessions
        .where(
          (s) => s.batchKey.batch == widget.batch && s.dayIndex == dayIndex,
        )
        .toList();

    try {
      String notifTitle = '';
      String notifBody = '';

      if (current != null && current.isLive(now)) {
        final duration = LectureDuration.getActualDuration(current);
        final actualEndTime = LectureDuration.getActualEndTime(current);
        final progress = ((currentTime - current.safeStartVal) / duration)
            .clamp(0.0, 1.0);
        final progressPercent = (progress * 100).toInt();

        final minutesRemaining = ((actualEndTime - currentTime) * 60)
            .round()
            .clamp(0, (duration * 60).round());
        final hoursRemaining = minutesRemaining ~/ 60;
        final minsRemaining = minutesRemaining % 60;

        String timeLeft = hoursRemaining > 0
            ? '${hoursRemaining}h ${minsRemaining}m left'
            : minsRemaining > 0
            ? '${minsRemaining}m left'
            : 'Ending now';

        final remaining = todayAll
            .where((s) => s.safeStartVal > currentTime)
            .length;
        final classCount = remaining > 0
            ? ' · $remaining more today'
            : ' · Last one';

        notifTitle = '🎓 ${current.subject} · $timeLeft';
        notifBody =
            '${_bar(progress)} $progressPercent%$classCount\n📍 ${current.room} · ${current.teacher}';
      } else if (next != null) {
        int daysAhead = 0;
        if (next.dayIndex != dayIndex) {
          daysAhead = (next.dayIndex - dayIndex + 7) % 7;
          if (daysAhead == 0) daysAhead = 7;
        }
        final totalMinutesUntil = daysAhead > 0
            ? ((24.0 - currentTime) * 60 +
                      (daysAhead - 1) * 24 * 60 +
                      next.safeStartVal * 60)
                  .round()
            : ((next.safeStartVal - currentTime) * 60).round();
        final hoursUntil = totalMinutesUntil ~/ 60;
        final minsUntil = totalMinutesUntil % 60;

        String timeUntil = '';
        String emoji = '📌';
        if (daysAhead > 0) {
          const dayNames = [
            '',
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
            'Sat',
            'Sun',
          ];
          final nextDayName = dayNames[next.dayIndex];
          final startHour = next.safeStartVal.floor();
          final startMin = ((next.safeStartVal - startHour) * 60).round();
          final displayHour = startHour > 12 ? startHour - 12 : startHour;
          final amPm = startHour >= 12 ? 'PM' : 'AM';
          timeUntil =
              '$nextDayName ${displayHour}:${startMin.toString().padLeft(2, '0')} $amPm';
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

        final remainingToday = todayAll
            .where((s) => s.safeStartVal > currentTime)
            .length;

        // Break info
        String breakInfo = '';
        if (daysAhead == 0) {
          final prevClasses = todayAll
              .where((s) => s.safeEndVal <= currentTime)
              .toList();
          if (prevClasses.isNotEmpty) {
            prevClasses.sort((a, b) => b.safeEndVal.compareTo(a.safeEndVal));
            final breakMins =
                ((next.safeStartVal - prevClasses.first.safeEndVal) * 60)
                    .round();
            if (breakMins > 0 && breakMins < 180) {
              breakInfo = ' · ${breakMins}m break';
            }
          }
        }

        String classInfo;
        if (daysAhead > 0) {
          classInfo = 'Done for today ✓';
        } else if (remainingToday > 1) {
          classInfo = '$remainingToday classes left';
        } else {
          classInfo = 'Last class today';
        }

        notifTitle = '$emoji ${next.subject} in $timeUntil';
        notifBody = '$classInfo$breakInfo\n📍 ${next.room} · ${next.teacher}';
      } else {
        final weekday = now.weekday;
        if (weekday == 6 || weekday == 7) {
          notifTitle = '🎉 Weekend Mode';
          notifBody = 'No classes — enjoy your break!';
        } else {
          notifTitle = '✓ All done for today';
          notifBody = 'No more classes scheduled';
        }
      }

      // Store notification content for foreground service to read
      await prefs.setString('notification_title', notifTitle);
      await prefs.setString('notification_body', notifBody);

      // Update foreground service notification if running
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: notifTitle,
          notificationText: notifBody,
          notificationButtons: [
            NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
        );
      }
    } catch (e) {
      debugPrint('❌ Persistent notification update failed: $e');
    }
  }

  /// Update home widget with temporal insight data
  Future<void> _updateWidgetIfNeeded() async {
    try {
      final now = DateTime.now();
      final insight = widget.brain.buildTemporalInsight(widget.batch, now);

      // Calculate progress percentage if live
      int progressPercent = 0;
      if (insight.isLive) {
        final current = widget.brain.getCurrentClass(widget.batch, now);
        if (current != null) {
          final currentTime = now.hour + (now.minute / 60.0);
          final duration = LectureDuration.getActualDuration(current);
          final progress = ((currentTime - current.safeStartVal) / duration)
              .clamp(0.0, 1.0);
          progressPercent = (progress * 100).toInt();
        }
      }

      // Generate state hash to determine if widget update is needed
      String _generateWidgetHash() {
        return '${insight.headline}_${insight.isLive}_${progressPercent}_${insight.isUrgent}';
      }

      final currentHash = _generateWidgetHash();

      // Only update widget if state changed (smarter updates to save battery)
      if (_previousWidgetHash == currentHash &&
          progressPercent == _previousProgressPercent) {
        return; // No meaningful change, skip widget update
      }

      _previousWidgetHash = currentHash;
      _previousProgressPercent = progressPercent;

      // Update widget with insight data
      await WidgetService.updateWidgetWithInsight(
        headline: insight.headline,
        subline: insight.subline,
        timeInfo: insight.timeInfo ?? '--',
        teacherInfo: insight.teacherInfo ?? '',
        isLive: insight.isLive,
        isUrgent: insight.isUrgent,
        progressPercentage: progressPercent,
      );
    } catch (e) {
      debugPrint('⚠️ Widget update failed: $e');
    }
  }

  Future<void> _openPortal({GlobalKey? originKey}) async {
    if (!mounted) return;
    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      page: const PortalScreen(
        url: 'https://swl-sis.comsats.edu.pk/Login/Index',
        title: 'COMSATS Student Portal',
        sessionScope: 'student',
      ),
    );
  }

  Future<void> _openTeacherPortal({GlobalKey? originKey}) async {
    if (!mounted) return;
    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      page: const PortalScreen(
        url:
            'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
        title: 'COMSATS Faculty Portal',
        sessionScope: 'faculty',
      ),
    );
  }

  Future<void> _openAbout({GlobalKey? originKey}) async {
    if (!mounted) return;
    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      page: AboutScreen(
        onRoleChanged: widget.onRoleChanged,
        onSetThemeMode: widget.onSetThemeMode,
        currentThemeMode: widget.currentThemeMode,
      ),
    );

    // Widget updates automatically via ticker - no manual refresh needed
  }

  Future<void> _openDepartmentClassesBrowser({GlobalKey? originKey}) async {
    if (!mounted) return;
    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      page: _DepartmentClassesScreen(
        memory: widget.memory,
        currentBatch: widget.batch,
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
        showDock: false,
      ),
    );
  }

  Future<void> _openTeacherSearch({GlobalKey? originKey}) async {
    if (!mounted) return;
    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      page: _TeacherLocatorScreen(
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
        memory: widget.memory,
        currentBatch: widget.batch,
        showDock: false,
      ),
    );
  }

  Future<void> _onBottomNavTap(int index) async {
    if (!mounted) return;
    if (_isStudentNavBusy) return;
    final previousIndex = _bottomNavIndex;
    if (index == previousIndex) {
      await IrisHaptics.navTransition(from: previousIndex, to: index);
      return;
    }

    setState(() => _isStudentNavBusy = true);
    await IrisHaptics.navTransition(from: previousIndex, to: index);
    await IrisHaptics.destinationOpen(destination: index);

    if (!mounted) return;
    const lockDuration = Duration(milliseconds: 420);
    setState(() {
      _studentTabSlideDirection = index > previousIndex ? 1 : -1;
      _bottomNavIndex = index;
    });

    await Future<void>.delayed(lockDuration);
    if (!mounted) return;
    setState(() => _isStudentNavBusy = false);

    if (index == 0) {
      _updateScheduleCache();
    }
  }

  void _setStudentTabFromDrag(int index) {
    if (!mounted) return;
    if (_isStudentNavBusy) return;
    if (index == _bottomNavIndex) return;
    index = index.clamp(0, 3);
    setState(() {
      _studentTabSlideDirection = index > _bottomNavIndex ? 1 : -1;
      _bottomNavIndex = index;
    });
    IrisHaptics.chipSelect();
    if (index == 0) {
      _updateScheduleCache();
    }
  }

  void _handleStudentNavDrag(DragUpdateDetails details, double width) {
    if (width <= 0) return;
    final safeDx = details.localPosition.dx.clamp(0.0, width - 1);
    final itemWidth = width / 4;
    final targetIndex = (safeDx / itemWidth).floor().clamp(0, 3);
    _setStudentTabFromDrag(targetIndex);
  }

  Widget _buildStudentTabContent() {
    switch (_bottomNavIndex) {
      case 1:
        return const PortalScreen(
          key: PageStorageKey<String>('student_tab_portal'),
          url: 'https://swl-sis.comsats.edu.pk/Login/Index',
          title: 'COMSATS Student Portal',
          sessionScope: 'student',
          showBackButton: false,
        );
      case 2:
        return _ToolsScreen(
          key: const PageStorageKey<String>('student_tab_tools'),
          memory: widget.memory,
          batch: widget.batch,
          brain: widget.brain,
          onRoleChanged: widget.onRoleChanged,
        );
      case 3:
        return AboutScreen(
          key: const PageStorageKey<String>('student_tab_about'),
          onRoleChanged: widget.onRoleChanged,
          onSetThemeMode: widget.onSetThemeMode,
          currentThemeMode: widget.currentThemeMode,
          showDock: false,
          showCloseButton: false,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStudentBottomNavBar(bool isDark) {
    final width = MediaQuery.of(context).size.width;
    final now = DateTime.now();
    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);
    final currentTime = now.hour + (now.minute / 60.0);
    final minutesToNext = next == null
        ? 9999
        : ((next.safeStartVal - currentTime) * 60).round();
    final classesNeedAttention =
        current != null ||
        (next != null &&
            next.dayIndex == now.weekday &&
            minutesToNext >= 0 &&
            minutesToNext <= 25);
    final makeupCount = widget.memory.sessions
        .where((s) => s.batchKey.batch == widget.batch && _isMakeupSession(s))
        .length;
    final hasMakeup = makeupCount > 0;
    final navPriorityColor = current != null
        ? IrisTokens.success
        : (classesNeedAttention
              ? IrisTokens.warning
              : (hasMakeup ? IrisTokens.purple : IrisTokens.brand));
    final compact = width < 420;
    final veryCompact = width < 360;
    final horizontalPadding = veryCompact ? 10.0 : (compact ? 12.0 : 20.0);
    final radius = veryCompact ? 18.0 : (compact ? 22.0 : 28.0);

    final navActive = _bottomNavIndex != 0;
    final activeGlow = _bottomNavIndex == 0
        ? Colors.transparent
        : navPriorityColor.withValues(alpha: isDark ? 0.20 : 0.15);

    return AnimatedScale(
      duration: const Duration(milliseconds: 352),
      curve: IrisMotion.standard,
      scale: _navBarReady ? 1.0 : 0.93,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 336),
        curve: IrisMotion.standard,
        offset: _navBarReady ? Offset.zero : const Offset(0, 0.45),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 352),
          opacity: _navBarReady ? 1.0 : 0.0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              10,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: IrisMotion.reduceBlur
                      ? 6
                      : (_bottomNavIndex == 0 ? 16 : 20),
                  sigmaY: IrisMotion.reduceBlur
                      ? 6
                      : (_bottomNavIndex == 0 ? 16 : 20),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 304),
                  curve: IrisMotion.standard,
                  decoration: BoxDecoration(
                    color:
                        (isDark ? IrisTokens.surfaceDarkElevated : Colors.white)
                            .withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: (isDark ? Colors.white : navPriorityColor)
                          .withValues(alpha: navActive ? 0.14 : 0.08),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: activeGlow,
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = constraints.maxWidth / 4;
                      final trailWidth = (itemWidth * 0.34).clamp(
                        12.0,
                        veryCompact ? 16.0 : (compact ? 20.0 : 24.0),
                      );
                      final haloSize = (itemWidth * 0.70).clamp(
                        24.0,
                        veryCompact ? 30.0 : (compact ? 36.0 : 44.0),
                      );
                      final left =
                          (itemWidth * _bottomNavIndex) +
                          ((itemWidth - trailWidth) / 2);
                      final haloLeft =
                          (itemWidth * _bottomNavIndex) +
                          ((itemWidth - haloSize) / 2);
                      final trailColor = isDark
                          ? Colors.white.withValues(alpha: 0.70)
                          : navPriorityColor.withValues(alpha: 0.84);

                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) =>
                            _handleStudentNavDrag(details, constraints.maxWidth),
                        child: Stack(
                          children: [
                            Positioned(
                              left: haloLeft,
                              top: veryCompact ? 9 : (compact ? 8 : 7),
                              child: IgnorePointer(
                                child: _NavActiveHalo(
                                  size: haloSize,
                                  color: trailColor,
                                ),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 304),
                              curve: IrisMotion.standard,
                              left: left,
                              top: 0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 304),
                                curve: IrisMotion.standard,
                                width: trailWidth,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: trailColor,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: trailColor.withValues(alpha: 0.20),
                                      blurRadius: 8,
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                veryCompact ? 4 : (compact ? 6 : 8),
                                veryCompact ? 5 : (compact ? 6 : 8),
                                veryCompact ? 4 : (compact ? 6 : 8),
                                veryCompact ? 3 : (compact ? 4 : 6),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _BouncyNavButton(
                                      icon: _bottomNavIndex == 0
                                          ? Icons.home_filled
                                          : Icons.home_rounded,
                                      label: 'Home',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 0,
                                      enabled: !_isStudentNavBusy,
                                      activeColor: IrisTokens.brand,
                                      onTap: () => _onBottomNavTap(0),
                                    ),
                                  ),
                                  Expanded(
                                    child: _BouncyNavButton(
                                      launchIconKey: _studentPortalNavKey,
                                      icon: Icons.public_rounded,
                                      label: 'Portal',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 1,
                                      enabled: !_isStudentNavBusy,
                                      activeColor: IrisTokens.brand,
                                      onTap: () => _onBottomNavTap(1),
                                    ),
                                  ),
                                  Expanded(
                                    child: _BouncyNavButton(
                                      launchIconKey: _studentToolsNavKey,
                                      icon: _bottomNavIndex == 2
                                          ? Icons.grid_view_rounded
                                          : Icons.grid_view_outlined,
                                      label: 'Resources',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 2,
                                      enabled: !_isStudentNavBusy,
                                      showIndicator: hasMakeup,
                                      indicatorCount: makeupCount,
                                      indicatorColor: IrisTokens.purple,
                                      activeColor: IrisTokens.brand,
                                      onTap: () => _onBottomNavTap(2),
                                    ),
                                  ),
                                  Expanded(
                                    child: _BouncyNavButton(
                                      launchIconKey: _studentAboutNavKey,
                                      icon: _bottomNavIndex == 3
                                          ? Icons.info_rounded
                                          : Icons.info_outline_rounded,
                                      label: 'About',
                                      isDark: isDark,
                                      isSelected: _bottomNavIndex == 3,
                                      enabled: !_isStudentNavBusy,
                                      activeColor: IrisTokens.brand,
                                      onTap: () => _onBottomNavTap(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMakeupScheduler({GlobalKey? originKey}) async {
    if (!mounted) return;

    IrisHaptics.actionMedium();

    await pushIconLaunchRoute(
      context,
      originKey: originKey,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: MakeupLectureScheduler(
        memory: widget.memory,
        brain: widget.brain,
        batch: widget.batch,
        onAddMakeupClass: _addMakeupSession,
        onRemoveMakeupClass: _removeMakeupSession,
        onRoleChanged: widget.onRoleChanged,
        showDock: false,
      ),
    );

    if (!mounted) return;
    _updateScheduleCache();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_bottomNavIndex != 0) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: IrisMotion.entrance,
                switchOutCurve: IrisMotion.standard,
                transitionBuilder: (child, animation) {
                  final isIncoming =
                      child.key == ValueKey<int>(_bottomNavIndex);
                  final direction = _studentTabSlideDirection.toDouble();
                  
                  // Slide animation: more dramatic distance
                  final slideBegin = isIncoming
                      ? Offset(0.42 * direction, 0)
                      : Offset.zero;
                  final slideEnd = isIncoming
                      ? Offset.zero
                      : Offset(-0.42 * direction, 0);
                  final slideAnimation = Tween<Offset>(begin: slideBegin, end: slideEnd).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: IrisMotion.standard,
                    ),
                  );
                  
                  // Scale animation: adds depth
                  final scaleBegin = isIncoming ? 0.92 : 1.0;
                  final scaleEnd = isIncoming ? 1.0 : 0.96;
                  final scaleAnimation = Tween<double>(begin: scaleBegin, end: scaleEnd).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: IrisMotion.standard,
                    ),
                  );
                  
                  // Fade animation: smoother opacity change
                  final opacityAnimation = Tween<double>(
                    begin: isIncoming ? 0.0 : 1.0,
                    end: isIncoming ? 1.0 : 0.0,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: IrisMotion.standard,
                    ),
                  );
                  
                  return FadeTransition(
                    opacity: opacityAnimation,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      child: SlideTransition(position: slideAnimation, child: child),
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_bottomNavIndex),
                  child: _buildStudentTabContent(),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _buildStudentBottomNavBar(isDark),
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final dateLabel = _formatDateLabel(now);
    final insight = widget.brain.buildTemporalInsight(widget.batch, now);

    // Update cache if day changed or schedule is empty
    if (_lastScheduleUpdate == null ||
        _lastScheduleUpdate!.day != now.day ||
        _cachedSchedule.isEmpty) {
      _updateScheduleCache();
    }
    final schedule = _cachedSchedule;
    final filteredSchedule = schedule;

    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(child: _NeuralAura(background: isDark)),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: IrisTokens.brand,
              backgroundColor: isDark
                  ? IrisTokens.surfaceDarkElevated
                  : Colors.white,
              child: CustomScrollView(
                physics: const ButterScrollPhysics(),
                cacheExtent: 500, // Preload items 500px ahead
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: GlassCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: RippleEffect(
                                onTap: widget.onChangeBatch,
                                borderRadius: 16,
                                rippleColor: IrisTokens.brand,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                IrisTokens.brand,
                                                IrisTokens.brandLight,
                                                IrisTokens.purpleLight,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: IrisTokens.brand
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Image.asset(
                                                'assets/iris_logo.png',
                                                width: 11,
                                                height: 11,
                                                fit: BoxFit.cover,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'IRIS',
                                                style: const TextStyle(
                                                  letterSpacing: 2.5,
                                                  fontSize: 9,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _getSmartGreeting(now.hour),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.8,
                                            color:
                                                (isDark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withValues(alpha: 0.35),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.08,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.12,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.08,
                                                ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 12,
                                            color:
                                                (isDark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            dateLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2,
                                              color:
                                                  (isDark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.batch,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.4,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                          child: Icon(
                                            Icons.swap_horiz_rounded,
                                            size: 16,
                                            color: IrisTokens.brand.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color:
                                    (isDark ? Colors.white : IrisTokens.brand)
                                        .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      (isDark ? Colors.white : IrisTokens.brand)
                                          .withValues(alpha: 0.12),
                                ),
                              ),
                              child: IconButton(
                                onPressed: widget.onToggleTheme,
                                icon: Icon(
                                  isDark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                  size: 22,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : IrisTokens.brand,
                                ),
                                tooltip: isDark
                                    ? 'Switch to light mode'
                                    : 'Switch to dark mode',
                                padding: const EdgeInsets.all(10),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GlassCard(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 336),
                          switchInCurve: IrisMotion.entrance,
                          switchOutCurve: IrisMotion.standard,
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: const Offset(0, 0.08),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: offset,
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            key: ValueKey(
                              '${insight.headline}-${insight.subline}',
                            ),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Icon with live pulse glow (no glitchy circle)
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: insight.isUrgent
                                            ? [
                                                IrisTokens.error,
                                                const Color(0xFFFCA5A5),
                                              ]
                                            : insight.isLive
                                            ? [
                                                IrisTokens.success,
                                                IrisTokens.success.withValues(alpha: 
                                                  0.8,
                                                ),
                                              ]
                                            : [
                                                IrisTokens.brand,
                                                IrisTokens.brandLight,
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (insight.isUrgent
                                                      ? IrisTokens.error
                                                      : insight.isLive
                                                      ? IrisTokens.success
                                                      : IrisTokens.brand)
                                                  .withValues(alpha: 0.22),
                                          blurRadius: insight.isLive ? 10 : 7,
                                          spreadRadius: -2,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      insight.isUrgent
                                          ? Icons.notifications_active
                                          : insight.isLive
                                          ? Icons.play_circle_filled_rounded
                                          : Icons.insights_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          insight.headline,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 17,
                                            letterSpacing: 0.3,
                                            height: 1.2,
                                            color: insight.isLive
                                                ? IrisTokens.success
                                                : null,
                                          ),
                                        ),
                                        if (insight.timeInfo != null) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            insight.timeInfo!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: insight.isUrgent
                                                  ? IrisTokens.error
                                                  : insight.isLive
                                                  ? IrisTokens.success
                                                  : IrisTokens.brand,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Subline with accent bar
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 3,
                                    height: 18,
                                    margin: const EdgeInsets.only(
                                      top: 2,
                                      right: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: insight.isLive
                                          ? IrisTokens.success.withValues(
                                              alpha: 0.4,
                                            )
                                          : IrisTokens.brand.withValues(
                                              alpha: 0.3,
                                            ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      insight.subline,
                                      style: TextStyle(
                                        fontSize: 14,
                                        letterSpacing: 0.2,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                        color: (isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.72,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.55,
                                              )),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Progress bar for live classes
                              if (insight.isLive) ...[
                                const SizedBox(height: 14),
                                Builder(
                                  builder: (context) {
                                    final currentClass = widget.brain
                                        .getCurrentClass(widget.batch, now);
                                    if (currentClass != null) {
                                      final currentTime =
                                          now.hour + (now.minute / 60.0);
                                      // Use actual lecture duration (1.0 for 1-hour lectures, full duration otherwise)
                                      final duration =
                                          LectureDuration.getActualDuration(
                                            currentClass,
                                          );
                                      final actualEndTime =
                                          LectureDuration.getActualEndTime(
                                            currentClass,
                                          );
                                      final progress =
                                          ((currentTime -
                                                      currentClass
                                                          .safeStartVal) /
                                                  duration)
                                              .clamp(0.0, 1.0);
                                      final minutesLeft =
                                          ((actualEndTime - currentTime) * 60)
                                              .toInt()
                                              .clamp(
                                                0,
                                                (duration * 60).toInt(),
                                              );

                                      String progressLabel = '';
                                      if (minutesLeft >= 60) {
                                        final hours = minutesLeft ~/ 60;
                                        final mins = minutesLeft % 60;
                                        progressLabel = mins > 0
                                            ? '${hours}h ${mins}m left'
                                            : '${hours}h left';
                                      } else {
                                        progressLabel = '${minutesLeft}m left';
                                      }

                                      return Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: TweenAnimationBuilder<double>(
                                              duration: const Duration(
                                                milliseconds: 768,
                                              ),
                                              curve: IrisMotion.entrance,
                                              tween: Tween<double>(
                                                begin: 0.0,
                                                end: progress,
                                              ),
                                              builder:
                                                  (
                                                    context,
                                                    value,
                                                    child,
                                                  ) => Container(
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: IrisTokens.success
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: FractionallySizedBox(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      widthFactor: value.clamp(
                                                        0.0,
                                                        1.0,
                                                      ),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              IrisTokens
                                                                  .success,
                                                              IrisTokens
                                                                  .success,
                                                              IrisTokens
                                                                  .successDark,
                                                            ],
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: IrisTokens
                                                                  .success
                                                                  .withValues(
                                                                    alpha: 0.28,
                                                                  ),
                                                              blurRadius: 3,
                                                              spreadRadius: -1,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                progressLabel,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  letterSpacing: 0.3,
                                                  fontWeight: FontWeight.w700,
                                                  color: IrisTokens.success,
                                                ),
                                              ),
                                              Text(
                                                '${(progress * 100).toInt()}%',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  letterSpacing: 0.3,
                                                  fontWeight: FontWeight.w800,
                                                  color: IrisTokens.success
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                              if (insight.teacherInfo != null &&
                                  insight.teacherInfo!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.10)
                                          : Colors.black.withValues(
                                              alpha: 0.06,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: IrisTokens.brand.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 12,
                                          color: IrisTokens.brand.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          insight.teacherInfo!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                (isDark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withValues(alpha: 0.6),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: _DaySwitcher(
                        selectedDayIndex: _overrideDayIndex,
                        onSelected: (value) => setState(() {
                          _overrideDayIndex = value;
                          _updateScheduleCache();
                        }),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: SectionHeader(
                        title: _timelineTitle(schedule, now, _overrideDayIndex),
                        subtitle: _timelineSubtitle(
                          schedule,
                          now,
                          _overrideDayIndex,
                        ),
                        statusIndicator: _getTimelineStatusColor(
                          widget.brain,
                          widget.batch,
                          now,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    sliver: filteredSchedule.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 24,
                              ),
                              child: GlassCard(
                                child: Column(
                                  children: [
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            IrisTokens.brand.withValues(
                                              alpha: 0.15,
                                            ),
                                            IrisTokens.brandLight.withValues(
                                              alpha: 0.08,
                                            ),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: IrisTokens.brand.withValues(
                                              alpha: 0.14,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: -4,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.beach_access_rounded,
                                        size: 40,
                                        color: IrisTokens.brand.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'No classes scheduled',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                        letterSpacing: 0.3,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.85),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Enjoy your free time! 🎉',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, index) {
                                final session = filteredSchedule[index];
                                final fullIndex = schedule.indexOf(session);
                                final nextSession =
                                    (fullIndex >= 0 &&
                                        fullIndex + 1 < schedule.length)
                                    ? schedule[fullIndex + 1]
                                    : null;
                                return StaggeredListItem(
                                  index: index,
                                  child: RepaintBoundary(
                                    child: _ClassCard(
                                      key: ValueKey(
                                        'class_${session.subject}_${session.startTime}',
                                      ),
                                      session: session,
                                      nextSession: nextSession,
                                      isFacultyView: false,
                                      onRemoveMakeup: _isMakeupSession(session)
                                          ? () =>
                                                _confirmAndRemoveMakeupSession(
                                                  session,
                                                )
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              childCount: filteredSchedule.length,
                              addAutomaticKeepAlives: true,
                              addRepaintBoundaries: true,
                            ),
                          ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 126)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _buildStudentBottomNavBar(isDark),
            ),
          ),
        ],
      ),
    );
  }

  List<ClassSession> _buildTimelineSchedule(DateTime now) {
    final schedule = _overrideDayIndex != null
        ? _scheduleForDay(
            widget.brain.scheduleFor(widget.batch),
            _overrideDayIndex!,
          )
        : _buildSuggestedSchedule(now);

    // Merge consecutive slots of the same lecture for cleaner display
    final mergedSchedule = widget.brain.getMergedConsecutiveSessions(schedule);

    // Ensure final schedule is always sorted in ascending order by start time
    mergedSchedule.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    return mergedSchedule;
  }

  List<ClassSession> _scheduleForDay(List<ClassSession> all, int dayIndex) {
    final daySchedule = all.where((s) => s.dayIndex == dayIndex).toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
    return daySchedule;
  }

  List<ClassSession> _buildSuggestedSchedule(DateTime now) {
    final all = widget.brain.scheduleFor(widget.batch);
    if (all.isEmpty) return [];

    final currentTime = now.hour + (now.minute / 60.0);
    final today = all.where((s) => s.dayIndex == now.weekday).toList()
      ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    if (today.isNotEmpty) {
      // Check if all today's classes have ended
      final allClassesEnded = today.every((s) => s.safeEndVal <= currentTime);

      if (allClassesEnded) {
        // All classes done for today, show next day automatically
        return _nextDaySchedule(all, now.weekday);
      }

      return today; // Show today's full schedule
    }

    return _nextDaySchedule(all, now.weekday);
  }

  List<ClassSession> _nextDaySchedule(List<ClassSession> all, int todayIndex) {
    for (int offset = 1; offset <= 6; offset++) {
      final nextDay = ((todayIndex + offset - 1) % 7) + 1;
      final daySchedule = all.where((s) => s.dayIndex == nextDay).toList()
        ..sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      if (daySchedule.isNotEmpty) {
        return daySchedule;
      }
    }
    return [];
  }

  String _timelineTitle(
    List<ClassSession> schedule,
    DateTime now,
    int? overrideDay,
  ) {
    if (schedule.isEmpty && overrideDay != null) {
      return '${FormatGuard.normalizeDay(overrideDay)} Timeline';
    }
    if (schedule.isEmpty) return 'No Classes';
    final dayIndex = overrideDay ?? schedule.first.dayIndex;

    if (dayIndex == now.weekday) {
      return 'Today\'s Timeline';
    }

    // Check if it's tomorrow
    final tomorrowIndex = (now.weekday % 7) + 1;
    if (dayIndex == tomorrowIndex && overrideDay == null) {
      return 'Tomorrow Morning';
    }

    final dayName = FormatGuard.normalizeDay(dayIndex);
    return '$dayName Timeline';
  }

  String _timelineSubtitle(
    List<ClassSession> schedule,
    DateTime now,
    int? overrideDay,
  ) {
    if (schedule.isEmpty && overrideDay != null) {
      return 'No classes scheduled • Free day! 🎉';
    }
    if (schedule.isEmpty) return 'No sessions in the registry';

    final dayIndex = overrideDay ?? schedule.first.dayIndex;
    final currentTime = now.hour + (now.minute / 60.0);

    if (dayIndex == now.weekday) {
      // Show smart live status
      final current = widget.brain.getCurrentClass(widget.batch, now);

      if (current != null && current.isLive(now)) {
        // Currently in a class
        final remaining = schedule
            .where((s) => s.safeStartVal > currentTime)
            .length;
        final classesLeft = remaining > 0
            ? '$remaining ${remaining == 1 ? 'class' : 'classes'} left'
            : 'Last class today';
        return '${current.subject} • $classesLeft';
      } else {
        // Between classes or before first class
        final nextClass = schedule.firstWhere(
          (s) => s.safeStartVal > currentTime,
          orElse: () => schedule.first,
        );

        if (nextClass.safeStartVal > currentTime) {
          final minutesUntil = ((nextClass.safeStartVal - currentTime) * 60)
              .round();

          if (minutesUntil > 60) {
            return '${(minutesUntil / 60).floor()}h ${minutesUntil % 60}m free • Next: ${nextClass.subject}';
          } else if (minutesUntil > 15) {
            return '${minutesUntil} min break • ${nextClass.subject} in ${nextClass.room}';
          } else {
            return 'Starting soon: ${nextClass.subject} in ${nextClass.room} ⚡';
          }
        }
      }

      return '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} today';
    }

    // Check if it's tomorrow
    final tomorrowIndex = (now.weekday % 7) + 1;
    if (dayIndex == tomorrowIndex && overrideDay == null) {
      return '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} tomorrow • First: ${schedule.first.subject}';
    }

    if (overrideDay != null) {
      return '${schedule.length} ${schedule.length == 1 ? 'class' : 'classes'} • ${_getDayName(dayIndex)}';
    }

    return 'Upcoming schedule';
  }

  String _getDayName(int day) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[(day - 1) % 7];
  }

  String _getSmartGreeting(int hour) {
    if (hour >= 5 && hour < 12) return 'MORNING';
    if (hour >= 12 && hour < 17) return 'AFTERNOON';
    if (hour >= 17 && hour < 21) return 'EVENING';
    return 'NIGHT';
  }

  Color _getTimelineStatusColor(OmniBrain brain, String batch, DateTime now) {
    final current = brain.getCurrentClass(batch, now);
    if (current != null && current.isLive(now)) {
      // Green - lectures are active
      return IrisTokens.success;
    }

    // Check if there's a class starting soon (within next 15 minutes)
    final schedule = brain.scheduleFor(batch);
    final currentTime = now.hour + (now.minute / 60.0);
    final upcomingSoon = schedule
        .where(
          (s) =>
              s.dayIndex == now.weekday &&
              s.safeStartVal > currentTime &&
              s.safeStartVal - currentTime <= 0.25, // 15 minutes
        )
        .isNotEmpty;

    if (upcomingSoon) {
      // Blue - lectures about to start
      return IrisTokens.blue;
    }

    // Red - no active lectures
    return IrisTokens.error;
  }
}

class _DaySwitcher extends StatelessWidget {
  final int? selectedDayIndex;
  final ValueChanged<int?> onSelected;

  const _DaySwitcher({
    required this.selectedDayIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday; // 1=Mon
    final autoSelected = selectedDayIndex == null;
    return GlassCard(
      child: SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const ButterScrollPhysics(),
          children: [
            const SizedBox(width: 6),
            AnimatedSlide(
              duration: IrisMotion.fast,
              curve: IrisMotion.standard,
              offset: autoSelected ? const Offset(0, -0.02) : Offset.zero,
              child: AnimatedScale(
                duration: IrisMotion.fast,
                curve: IrisMotion.standard,
                scale: autoSelected ? 1.025 : 1.0,
                child: AnimatedContainer(
                  duration: IrisMotion.fast,
                  curve: IrisMotion.standard,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [],
                  ),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: autoSelected
                              ? IrisTokens.brand
                              : isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Auto',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    selected: autoSelected,
                    onSelected: (_) {
                      IrisHaptics.chipSelect();
                      onSelected(null);
                    },
                    selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    side: BorderSide(
                      color: autoSelected
                          ? IrisTokens.brand.withValues(alpha: 0.56)
                          : isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.10),
                      width: autoSelected ? 1.4 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      color: autoSelected
                          ? IrisTokens.brand
                          : isDark
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.black.withValues(alpha: 0.65),
                    ),
                    elevation: autoSelected ? 0.6 : 0,
                    pressElevation: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ...List.generate(days.length, (index) {
              final dayIndex = index + 1;
              final isSelected = selectedDayIndex == dayIndex;
              final isToday = dayIndex == today;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedSlide(
                  duration: IrisMotion.fast,
                  curve: IrisMotion.standard,
                  offset: isSelected ? const Offset(0, -0.02) : Offset.zero,
                  child: AnimatedScale(
                    duration: IrisMotion.fast,
                    curve: IrisMotion.standard,
                    scale: isSelected ? 1.03 : 1.0,
                    child: AnimatedContainer(
                      duration: IrisMotion.fast,
                      curve: IrisMotion.standard,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [],
                      ),
                      child: ChoiceChip(
                        avatar: isToday && !isSelected
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: IrisTokens.success,
                                ),
                              )
                            : null,
                        label: Text(
                          days[index],
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          IrisHaptics.chipSelect();
                          onSelected(dayIndex == today ? null : dayIndex);
                        },
                        selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        side: BorderSide(
                          color: isSelected
                              ? IrisTokens.brand.withValues(alpha: 0.56)
                              : isToday
                              ? IrisTokens.success.withValues(alpha: 0.28)
                              : isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.10),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? IrisTokens.brand
                              : isDark
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.black.withValues(alpha: 0.65),
                        ),
                        elevation: isSelected ? 0.6 : 0,
                        pressElevation: 1,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _ClassCard extends StatefulWidget {
  final ClassSession session;
  final ClassSession? nextSession;
  final bool isFacultyView;
  final VoidCallback? onRemoveMakeup;

  const _ClassCard({
    super.key,
    required this.session,
    this.nextSession,
    this.isFacultyView = false,
    this.onRemoveMakeup,
  });

  @override
  State<_ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<_ClassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _nextPulseAnimation;
  bool _pulseRunning = false;

  void _syncPulse(bool shouldPulse) {
    if (shouldPulse && !_pulseRunning) {
      _pulseController.repeat(reverse: true);
      _pulseRunning = true;
    } else if (!shouldPulse && _pulseRunning) {
      _pulseController.stop();
      _pulseController.value = 0.0;
      _pulseRunning = false;
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final isLive = widget.session.isLive(now);

    _pulseController = AnimationController(
      duration: IrisMotion.slow,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: IrisMotion.standard),
    );

    _nextPulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: IrisMotion.standard),
    );

    _syncPulse(isLive);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final live = widget.session.isLive(now);
    final currentTime = now.hour + (now.minute / 60.0);
    final isUpcoming =
        !live &&
        widget.session.dayIndex == now.weekday &&
        widget.session.safeStartVal > currentTime &&
        widget.session.safeStartVal - currentTime <= 0.75;

    _syncPulse(live || isUpcoming);

    // Calculate actual lecture duration accounting for "(1 hr)" markers
    final duration = LectureDuration.getActualDuration(widget.session);
    final actualEndTime = LectureDuration.getActualEndTime(widget.session);

    // Calculate progress and label based on actual lecture duration
    double progress = 0.0;
    String progressLabel = '';

    if (live) {
      // Calculate progress using actual duration (1 hour for 1hr lectures, full slot otherwise)
      progress = ((currentTime - widget.session.safeStartVal) / duration).clamp(
        0.0,
        1.0,
      );
      final minutesLeft = ((actualEndTime - currentTime) * 60).toInt().clamp(
        0,
        (duration * 60).toInt(),
      );

      if (minutesLeft >= 60) {
        final hours = minutesLeft ~/ 60;
        final mins = minutesLeft % 60;
        progressLabel = mins > 0 ? '${hours}h ${mins}m left' : '${hours}h left';
      } else {
        progressLabel = '${minutesLeft}m left';
      }
    }

    final timeLabel = '${widget.session.startTime} - ${widget.session.endTime}';

    final accentColor = live
        ? IrisTokens.success
        : isUpcoming
        ? IrisTokens.brand
        : IrisTokens.purple;
    final textPrimary = isDark ? Colors.white : IrisTokens.surfaceDark;
    final textSecondary = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.68,
    );

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: IrisMotion.medium,
          curve: IrisMotion.entrance,
          builder: (context, bounceval, child) => Transform.scale(
            scale: 0.96 + (bounceval * 0.04),
            child: GlassCard(
              glow: live,
              shimmer: false,
              enableBlur: true,
              enableShadow: true,
              enableOverlay: true,
              padding: const EdgeInsets.all(20),
              borderRadius: 22.0,
              elevation: live ? 3 : 2,
              accentColor: accentColor,
              tilt: live,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.session.subject,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: 0.0,
                            height: 1.1,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      if (live) ...[
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) => Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: IrisTokens.space12,
                                vertical: IrisTokens.space8 - 1,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    accentColor,
                                    accentColor.withValues(alpha: 0.88),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  IrisTokens.radius12,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.24),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.22),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: IrisTokens.space8),
                      ] else if (isUpcoming) ...[
                        AnimatedBuilder(
                          animation: _nextPulseAnimation,
                          builder: (context, child) => Transform.scale(
                            scale: _nextPulseAnimation.value,
                            child: child,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: IrisTokens.space12,
                              vertical: IrisTokens.space8 - 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  IrisTokens.brand,
                                  IrisTokens.brand.withValues(alpha: 0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                IrisTokens.radius12,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.24),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: IrisTokens.brand.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 7,
                                  spreadRadius: -2,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'NEXT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: IrisTokens.space8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: IrisTokens.space12,
                          vertical: IrisTokens.space8 - 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(
                            IrisTokens.radius12,
                          ),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : Colors.black.withValues(alpha: 0.07),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      if (widget.onRemoveMakeup != null) ...[
                        const SizedBox(width: IrisTokens.space8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              IrisTokens.radius12,
                            ),
                            onTap: widget.onRemoveMakeup,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: IrisTokens.space12,
                                vertical: IrisTokens.space8 - 2,
                              ),
                              decoration: BoxDecoration(
                                color: IrisTokens.error.withValues(
                                  alpha: isDark ? 0.22 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(
                                  IrisTokens.radius12,
                                ),
                                border: Border.all(
                                  color: IrisTokens.error.withValues(
                                    alpha: 0.30,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 14,
                                    color: IrisTokens.error,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Remove',
                                    style: TextStyle(
                                      fontSize: 11,
                                      letterSpacing: 0.2,
                                      fontWeight: FontWeight.w700,
                                      color: IrisTokens.error,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(IrisTokens.space8 - 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: isDark ? 0.32 : 0.16,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.room_outlined,
                          size: 16,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: IrisTokens.space12),
                      Expanded(
                        child: Text(
                          widget.session.room,
                          style: TextStyle(
                            fontSize: 14,
                            letterSpacing: 0.1,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: textSecondary.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: widget.isFacultyView
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: IrisTokens.space12,
                                  vertical: IrisTokens.space8 - 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accentColor.withValues(
                                        alpha: isDark ? 0.26 : 0.16,
                                      ),
                                      accentColor.withValues(
                                        alpha: isDark ? 0.20 : 0.12,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    IrisTokens.radius12,
                                  ),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.30),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  widget.session.batchKey.batch,
                                  style: TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                    height: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : Text(
                                widget.session.teacher,
                                style: TextStyle(
                                  fontSize: 14,
                                  letterSpacing: 0.1,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  if (live &&
                      widget.nextSession != null &&
                      widget.nextSession!.dayIndex ==
                          widget.session.dayIndex) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: IrisTokens.brand.withValues(
                          alpha: isDark ? 0.20 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: IrisTokens.brand.withValues(alpha: 0.26),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: IrisTokens.brand,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Next: ${widget.nextSession!.room}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: IrisTokens.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (live) ...[
                    const SizedBox(height: 18),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TweenAnimationBuilder<double>(
                        duration: IrisMotion.medium,
                        curve: IrisMotion.standard,
                        tween: Tween<double>(begin: 0.0, end: progress),
                        builder: (context, value, child) {
                          final clamped = value.clamp(0.0, 1.0);
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final maxWidth = constraints.maxWidth;
                              final dotSize = 10.0;
                              final left =
                                  ((maxWidth * clamped) - (dotSize / 2)).clamp(
                                    0.0,
                                    maxWidth - dotSize,
                                  );
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: clamped,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            accentColor,
                                            accentColor.withValues(alpha: 0.78),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: left,
                                    top: -1,
                                    child: Container(
                                      width: dotSize,
                                      height: dotSize,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.95,
                                              )
                                            : accentColor.withValues(
                                                alpha: 0.85,
                                              ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? accentColor.withValues(
                                                  alpha: 0.35,
                                                )
                                              : Colors.white.withValues(
                                                  alpha: 0.85,
                                                ),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accentColor.withValues(
                                              alpha: 0.22,
                                            ),
                                            blurRadius: 5,
                                            spreadRadius: -1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          progressLabel,
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 0.2,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        TweenAnimationBuilder<int>(
                          tween: IntTween(
                            begin: 0,
                            end: (progress * 100).toInt(),
                          ),
                          duration: IrisMotion.medium,
                          curve: IrisMotion.standard,
                          builder: (context, value, child) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: IrisTokens.space8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(
                                alpha: isDark ? 0.30 : 0.16,
                              ),
                              borderRadius: BorderRadius.circular(
                                IrisTokens.radius8,
                              ),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '$value%',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.3,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final bool glow;
  final bool shimmer;
  final bool enableBlur;
  final bool enableShadow;
  final bool enableOverlay;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final int elevation;
  final Color? accentColor;
  final bool tilt;

  const GlassCard({
    required this.child,
    this.glow = false,
    this.shimmer = false,
    this.enableBlur = true,
    this.enableShadow = true,
    this.enableOverlay = false,
    this.padding,
    this.borderRadius,
    this.elevation = 2,
    this.accentColor,
    this.tilt = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectivePadding =
        padding ?? const EdgeInsets.all(IrisTokens.space24);
    final effectiveRadius = borderRadius ?? 28.0; // More fluid radius
    final tintColor =
        accentColor ?? (isDark ? IrisTokens.brandDark : IrisTokens.brand);

    // Stronger, more readable surfaces with controlled translucency.
    final baseColor = isDark
        ? IrisTokens.surfaceDarkElevated.withValues(alpha: glow ? 0.94 : 0.90)
        : Colors.white.withValues(alpha: glow ? 0.985 : 0.96);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: glow ? 0.24 : 0.18)
        : Colors.black.withValues(alpha: glow ? 0.10 : 0.07);

    // Softer, more diffused shadows for depth
    final softShadow = isDark
        ? Colors.black.withValues(alpha: 0.34)
        : IrisTokens.surfaceDark.withValues(alpha: 0.08);
    final glowShadow = tintColor.withValues(alpha: isDark ? 0.12 : 0.08);

    final tiltAngle = tilt ? 0.006 : 0.0;
    final blurSigma = enableBlur ? (IrisMotion.reduceBlur ? 6.0 : 14.0) : 0.0;

    // Enhanced elevation with softer shadows
    final shadowOffsetY = elevation == 1
        ? 4.0
        : elevation == 2
        ? 8.0
        : elevation == 3
        ? 14.0
        : 20.0;
    final shadowBlur = elevation == 1
        ? 12.0
        : elevation == 2
        ? 24.0
        : elevation == 3
        ? 36.0
        : 48.0;
    final shadowSpread = elevation == 1
        ? -4.0
        : elevation == 2
        ? -8.0
        : elevation == 3
        ? -12.0
        : -16.0;

    final cardBody = Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(effectiveRadius),
        boxShadow: enableShadow
            ? [
                BoxShadow(
                  color: softShadow,
                  offset: Offset(0, shadowOffsetY),
                  blurRadius: shadowBlur,
                  spreadRadius: shadowSpread,
                ),
                if (glow)
                  BoxShadow(
                    color: glowShadow,
                    offset: const Offset(0, 0),
                    blurRadius: 12,
                    spreadRadius: -16,
                  ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: effectivePadding,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(effectiveRadius),
              border: Border.all(color: borderColor, width: 1.5),
              // Aquamorphic gradient overlay - fluid and dynamic
              gradient: enableOverlay
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.10 : 0.30),
                        Colors.white.withValues(alpha: isDark ? 0.03 : 0.12),
                      ],
                      stops: const [0.0, 1.0],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.04 : 0.10),
                        Colors.transparent,
                      ],
                    ),
              // Inner glow for depth
              boxShadow: glow
                  ? [
                      BoxShadow(
                        color: tintColor.withValues(alpha: 0.05),
                        blurRadius: 12,
                        spreadRadius: -8,
                        offset: const Offset(0, 0),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );

    if (IrisMotion.reduceMotion) {
      return Transform.rotate(angle: tiltAngle, child: cardBody);
    }

    return Transform.rotate(
      angle: tiltAngle,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: IrisMotion.medium,
        curve: IrisMotion.entrance,
        builder: (context, animValue, child) =>
            Transform.scale(scale: 0.97 + (animValue * 0.03), child: child),
        child: cardBody,
      ),
    );
  }

  // Removed - neobrutalism uses flat offset shadows only
}

class _GlassShimmer extends StatefulWidget {
  const _GlassShimmer();

  @override
  State<_GlassShimmer> createState() => _GlassShimmerState();
}

class _GlassShimmerState extends State<_GlassShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3456),
    )..repeat();
    _curve = CurvedAnimation(parent: _controller, curve: IrisMotion.standard);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final shift = (_curve.value * 2) - 1;
            return FractionalTranslation(
              translation: Offset(shift, 0),
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color statusIndicator;

  const SectionHeader({
    required this.title,
    required this.subtitle,
    required this.statusIndicator,
    super.key,
  });

  @override
  State<SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<SectionHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: IrisMotion.slow,
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: IrisMotion.standard),
    );
    _glowAnimation = Tween<double>(begin: 0.05, end: 0.09).animate(
      CurvedAnimation(parent: _bounceController, curve: IrisMotion.standard),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: IrisMotion.medium,
        curve: IrisMotion.bouncy,
        builder: (context, animValue, child) => Transform.translate(
          offset: Offset(-36 * (1 - animValue), 8 * (1 - animValue)),
          child: Transform.scale(
            scale: 0.96 + (0.04 * animValue),
            child: Opacity(opacity: animValue, child: child),
          ),
        ),
        child: AnimatedBuilder(
          animation: _bounceController,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.all(IrisTokens.space20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.statusIndicator.withValues(
                      alpha: isDark ? 0.26 : 0.18,
                    ),
                    widget.statusIndicator.withValues(
                      alpha: isDark ? 0.14 : 0.10,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(IrisTokens.radius24),
                border: Border.all(
                  color: widget.statusIndicator.withValues(
                    alpha: isDark ? 0.34 : 0.24,
                  ),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.statusIndicator.withValues(
                      alpha: _glowAnimation.value,
                    ),
                    offset: const Offset(0, 8),
                    blurRadius: 20,
                    spreadRadius: -14,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
                    offset: const Offset(0, 3),
                    blurRadius: 12,
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 304),
                    switchInCurve: IrisMotion.entrance,
                    switchOutCurve: IrisMotion.standard,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Transform.translate(
                      key: ValueKey(widget.statusIndicator.value),
                      offset: Offset(0, _bounceAnimation.value),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: widget.statusIndicator.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.statusIndicator.withValues(
                                alpha: 0.18,
                              ),
                              blurRadius: 6,
                              spreadRadius: -3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                            fontSize: 10,
                            height: 1.4,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.66),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.90),
                            height: 1.22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavActiveHalo extends StatefulWidget {
  final double size;
  final Color color;

  const _NavActiveHalo({required this.size, required this.color});

  @override
  State<_NavActiveHalo> createState() => _NavActiveHaloState();
}

class _NavActiveHaloState extends State<_NavActiveHalo>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entrance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1536),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: IrisMotion.standard);

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 576),
    );
    _entrance = CurvedAnimation(
      parent: _entranceCtrl,
      curve: IrisMotion.entrance,
    );
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _entrance]),
      builder: (context, _) {
        final t = _pulse.value;
        final e = _entrance.value;
        return Transform.scale(
          scale: e * (0.97 + (t * 0.04)),
          child: Opacity(
            opacity: e.clamp(0.0, 1.0),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color.withValues(alpha: 0.14 + (t * 0.05)),
                    widget.color.withValues(alpha: 0.05 + (t * 0.02)),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.72, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isHeavy;

  const SpringButton({
    super.key,
    required this.child,
    required this.onTap,
    this.isHeavy = false,
  });

  @override
  State<SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<SpringButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final SpringDescription _spring = const SpringDescription(
    mass: 0.9,
    stiffness: 150.0,
    damping: 16.0,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, upperBound: 1.0)
      ..value = 0.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runAnimation(double target) {
    final simulation = SpringSimulation(
      _spring,
      _controller.value,
      target,
      0.0,
    );
    _controller.animateWith(simulation);
  }

  void _onTapDown(TapDownDetails details) {
    _runAnimation(0.15);
    IrisHaptics.actionSoft();
  }

  void _onTapUp(TapUpDetails details) {
    _runAnimation(0.0);
    if (widget.isHeavy) {
      IrisHaptics.actionHeavy();
    } else {
      IrisHaptics.chipSelect();
    }
    widget.onTap();
  }

  void _onTapCancel() {
    _runAnimation(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          return Transform.scale(scale: 1.0 - _controller.value, child: child);
        },
      ),
    );
  }
}

class _BouncyNavButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool isSelected;
  final bool enabled;
  final bool showLabelAlways;
  final bool showIndicator;
  final int? indicatorCount;
  final Color? indicatorColor;
  final Color activeColor;
  final VoidCallback onTap;
  final GlobalKey? launchIconKey;

  const _BouncyNavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isDark,
    required this.isSelected,
    this.enabled = true,
    this.showLabelAlways = false,
    this.showIndicator = false,
    this.indicatorCount,
    this.indicatorColor,
    required this.activeColor,
    required this.onTap,
    this.launchIconKey,
  });

  @override
  State<_BouncyNavButton> createState() => _BouncyNavButtonState();
}

class _BouncyNavButtonState extends State<_BouncyNavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selectCtrl;
  late final Animation<double> _scaleCurve;
  late final Animation<double> _slideCurve;

  @override
  void initState() {
    super.initState();
    _selectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleCurve = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _selectCtrl, curve: IrisMotion.entrance));
    _slideCurve = Tween<double>(
      begin: 0.0,
      end: -0.85,
    ).animate(CurvedAnimation(parent: _selectCtrl, curve: IrisMotion.entrance));
    if (widget.isSelected) _selectCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_BouncyNavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _selectCtrl.forward(from: 0.0);
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _selectCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _selectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isSelected
        ? widget.activeColor
        : (widget.isDark ? Colors.white38 : Colors.black38);
    final color = widget.enabled
        ? baseColor
        : baseColor.withValues(alpha: widget.isDark ? 0.48 : 0.42);
    final showLabel = widget.isSelected || widget.showLabelAlways;
    final indicatorColor = widget.indicatorColor ?? widget.activeColor;
    final badgeCount = widget.indicatorCount ?? 0;
    final showCountBadge = badgeCount > 0 && !widget.isSelected;
    final badgeText = badgeCount > 9 ? '9+' : '$badgeCount';

    Widget buildIcon(double size, bool veryCompact) {
      return Container(
        key: widget.launchIconKey,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 192),
              switchInCurve: IrisMotion.entrance,
              switchOutCurve: IrisMotion.standard,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                widget.icon,
                key: ValueKey('${widget.icon.codePoint}_${widget.isSelected}'),
                color: color,
                size: size,
              ),
            ),
            if (widget.showIndicator && !widget.isSelected)
              Positioned(
                right: showCountBadge ? -8 : -2,
                top: showCountBadge ? -6 : -1,
                child: showCountBadge
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 14),
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: widget.isDark
                                ? IrisTokens.surfaceDarkElevated
                                : Colors.white,
                            width: 1.1,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            letterSpacing: 0.1,
                          ),
                        ),
                      )
                    : Container(
                        width: veryCompact ? 7 : 8,
                        height: veryCompact ? 7 : 8,
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isDark
                                ? IrisTokens.surfaceDarkElevated
                                : Colors.white,
                            width: 1.1,
                          ),
                        ),
                      ),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth;
        final veryCompact = slotWidth < 56;
        final compact = slotWidth < 74;
        final roomy = slotWidth > 108;

        return AnimatedBuilder(
          animation: _selectCtrl,
          builder: (context, child) {
            final yOffset = widget.showLabelAlways
                ? (_slideCurve.value * 0.32)
                : _slideCurve.value;
            final scale = widget.showLabelAlways
                ? (1.0 + ((_scaleCurve.value - 1.0) * 0.32))
                : _scaleCurve.value;
            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: SpringButton(
            onTap: widget.enabled ? widget.onTap : () {},
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.showLabelAlways
                    ? (veryCompact ? 2 : (compact ? 3 : 6))
                    : (veryCompact ? 3 : (compact ? 4 : (roomy ? 10 : 7))),
                vertical: widget.showLabelAlways
                    ? (veryCompact ? 4 : 5)
                    : (veryCompact ? 4 : (compact ? 5 : 7)),
              ),
              decoration: widget.isSelected
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.activeColor.withValues(alpha: 0.24),
                          widget.activeColor.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(veryCompact ? 16 : (compact ? 20 : 24)),
                      border: Border.all(
                        color: widget.activeColor.withValues(alpha: 0.20),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.activeColor.withValues(alpha: 0.16),
                          blurRadius: 16,
                          spreadRadius: -8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    )
                  : const BoxDecoration(color: Colors.transparent),
              child: widget.showLabelAlways
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildIcon(veryCompact ? 16 : (compact ? 17 : 19), veryCompact),
                        const SizedBox(height: 2),
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.isSelected
                                ? color
                                : (widget.isDark
                                      ? Colors.white.withValues(alpha: 0.72)
                                      : Colors.black.withValues(alpha: 0.62)),
                            fontWeight: widget.isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: veryCompact ? 8 : (compact ? 9 : 10),
                            height: 1.0,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildIcon(veryCompact ? 16 : (compact ? 18 : 21), veryCompact),
                        if (showLabel) ...[
                          SizedBox(width: veryCompact ? 3 : (compact ? 4 : (roomy ? 8 : 6))),
                          Flexible(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 192),
                              curve: IrisMotion.standard,
                              style: TextStyle(
                                color: widget.isSelected
                                    ? color
                                    : (widget.isDark
                                          ? Colors.white.withValues(alpha: 0.62)
                                          : Colors.black.withValues(alpha: 0.55)),
                                fontWeight: widget.isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: veryCompact ? 8 : (compact ? 9 : 12),
                              ),
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _SmartScreenDock extends StatelessWidget {
  final VoidCallback? onHome;
  final VoidCallback? onTeacher;
  final VoidCallback? onPortal;
  final VoidCallback? onClasses;
  final VoidCallback? onTools;
  final VoidCallback? onMakeup;
  final VoidCallback? onAbout;
  final bool showFacultySet;
  final int selectedIndex;

  const _SmartScreenDock({
    this.onHome,
    this.onTeacher,
    this.onPortal,
    this.onClasses,
    this.onTools,
    this.onMakeup,
    this.onAbout,
    this.showFacultySet = false,
    this.selectedIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final compact = width < (showFacultySet ? 420 : 470);
    final veryCompact = width < (showFacultySet ? 360 : 400);
    final navHeight = showFacultySet
      ? (veryCompact ? 48.0 : (compact ? 52.0 : 56.0))
      : (veryCompact ? 54.0 : (compact ? 58.0 : 62.0));
    final horizontalPadding = showFacultySet
      ? (veryCompact ? 10.0 : (compact ? 12.0 : 20.0))
      : (veryCompact ? 8.0 : (compact ? 10.0 : 14.0));
    final radius = showFacultySet
      ? (veryCompact ? 18.0 : (compact ? 22.0 : 28.0))
      : (veryCompact ? 18.0 : (compact ? 20.0 : 24.0));
    final itemCount = showFacultySet ? 4 : 7;
    final safeSelected = selectedIndex.clamp(0, itemCount - 1);
    final activeColor = showFacultySet ? IrisTokens.purple : IrisTokens.brand;
    final navActive = safeSelected != 0;
    final activeGlow = safeSelected == 0
        ? Colors.transparent
        : activeColor.withValues(alpha: isDark ? 0.18 : 0.13);

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: IrisMotion.reduceBlur ? 6 : (safeSelected == 0 ? 16 : 20),
            sigmaY: IrisMotion.reduceBlur ? 6 : (safeSelected == 0 ? 16 : 20),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 304),
            curve: IrisMotion.standard,
            decoration: BoxDecoration(
              color: (isDark ? IrisTokens.surfaceDarkElevated : Colors.white)
                  .withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: (isDark ? Colors.white : activeColor).withValues(
                  alpha: navActive ? 0.14 : 0.08,
                ),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: activeGlow,
                  blurRadius: 18,
                  spreadRadius: -4,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SizedBox(
              height: navHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / itemCount;
                  final ultraDense = itemWidth < 48;
                  final dense = itemWidth < 56;
                  final trailWidth = showFacultySet
                      ? (veryCompact ? 16.0 : (compact ? 20.0 : 26.0))
                      : (ultraDense
                            ? 9.0
                            : (dense ? 12.0 : (veryCompact ? 14.0 : 18.0)));
                  final haloSize = showFacultySet
                      ? (veryCompact ? 30.0 : (compact ? 38.0 : 46.0))
                      : (ultraDense
                            ? 20.0
                            : (dense ? 24.0 : (veryCompact ? 28.0 : 34.0)));
                  final left =
                      (itemWidth * safeSelected) +
                      ((itemWidth - trailWidth) / 2);
                  final haloLeft =
                      (itemWidth * safeSelected) + ((itemWidth - haloSize) / 2);
                  final trailColor = isDark
                      ? Colors.white.withValues(alpha: 0.70)
                      : activeColor.withValues(alpha: 0.80);

                  return Stack(
                    children: [
                      Positioned(
                        left: haloLeft,
                        top: ultraDense ? 11 : (veryCompact ? 9 : (compact ? 8 : 7)),
                        child: IgnorePointer(
                          child: _NavActiveHalo(
                            size: haloSize,
                            color: trailColor,
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 360),
                        curve: IrisMotion.standard,
                        left: left,
                        top: 0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 360),
                          curve: IrisMotion.standard,
                          width: trailWidth,
                          height: 4,
                          decoration: BoxDecoration(
                            color: trailColor,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: trailColor.withValues(alpha: 0.20),
                                blurRadius: 8,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          ultraDense ? 1 : (veryCompact ? 3 : (compact ? 5 : 6)),
                          ultraDense ? 1 : (veryCompact ? 2 : (compact ? 3 : 4)),
                          ultraDense ? 1 : (veryCompact ? 3 : (compact ? 5 : 6)),
                          ultraDense ? 1 : (veryCompact ? 2 : (compact ? 3 : 4)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _BouncyNavButton(
                                icon: safeSelected == 0
                                    ? Icons.home_filled
                                    : Icons.home_rounded,
                                label: 'Home',
                                isDark: isDark,
                                isSelected: safeSelected == 0,
                                activeColor: activeColor,
                                onTap:
                                    onHome ??
                                    () => Navigator.of(
                                      context,
                                    ).popUntil((route) => route.isFirst),
                              ),
                            ),
                            Expanded(
                              child: _BouncyNavButton(
                                icon: showFacultySet
                                    ? (safeSelected == 1
                                          ? Icons.badge_rounded
                                          : Icons.badge_outlined)
                                    : Icons.search_rounded,
                                label: 'Teacher',
                                isDark: isDark,
                                isSelected: safeSelected == 1,
                                activeColor: activeColor,
                                onTap: onTeacher ?? () {},
                              ),
                            ),
                            Expanded(
                              child: _BouncyNavButton(
                                icon: Icons.public_rounded,
                                label: 'Portal',
                                isDark: isDark,
                                isSelected: safeSelected == 2,
                                activeColor: activeColor,
                                onTap: onPortal ?? () {},
                              ),
                            ),
                            if (showFacultySet)
                              Expanded(
                                child: _BouncyNavButton(
                                  icon: safeSelected == 3
                                      ? Icons.info_rounded
                                      : Icons.info_outline_rounded,
                                  label: 'About',
                                  isDark: isDark,
                                  isSelected: safeSelected == 3,
                                  activeColor: activeColor,
                                  onTap: onAbout ?? () {},
                                ),
                              )
                            else ...[
                              Expanded(
                                child: _BouncyNavButton(
                                  icon: safeSelected == 3
                                      ? Icons.school_rounded
                                      : Icons.school_outlined,
                                  label: 'Classes',
                                  isDark: isDark,
                                  isSelected: safeSelected == 3,
                                  activeColor: activeColor,
                                  onTap: onClasses ?? () {},
                                ),
                              ),
                              Expanded(
                                child: _BouncyNavButton(
                                  icon: safeSelected == 4
                                      ? Icons.build_rounded
                                      : Icons.build_outlined,
                                  label: 'Tools',
                                  isDark: isDark,
                                  isSelected: safeSelected == 4,
                                  activeColor: activeColor,
                                  onTap:
                                      onTools ??
                                      () {
                                        showIrisFrostedSnackBar(
                                          context,
                                          dedupeKey: 'tools_unavailable_from_screen',
                                          content: Text(
                                            'Tools are unavailable from this screen.',
                                          ),
                                        );
                                      },
                                ),
                              ),
                              Expanded(
                                child: _BouncyNavButton(
                                  icon: safeSelected == 5
                                      ? Icons.event_repeat_rounded
                                      : Icons.event_repeat_outlined,
                                  label: 'Makeup',
                                  isDark: isDark,
                                  isSelected: safeSelected == 5,
                                  activeColor: activeColor,
                                  onTap: onMakeup ?? () {},
                                ),
                              ),
                              Expanded(
                                child: _BouncyNavButton(
                                  icon: safeSelected == 6
                                      ? Icons.info_rounded
                                      : Icons.info_outline_rounded,
                                  label: 'About',
                                  isDark: isDark,
                                  isSelected: safeSelected == 6,
                                  activeColor: activeColor,
                                  onTap: onAbout ?? () {},
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBackButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onTap;

  const _AppBackButton({required this.isDark, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: SpringButton(
        onTap: onTap ?? () => Navigator.pop(context),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ============ TOOLS SCREEN ============
class _ToolsScreen extends StatelessWidget {
  final UniversityMemory memory;
  final String batch;
  final OmniBrain brain;
  final ValueChanged<String>? onRoleChanged;

  const _ToolsScreen({
    Key? key,
    required this.memory,
    required this.batch,
    required this.brain,
    this.onRoleChanged,
  }) : super(key: key);

  String _getDepartmentFromBatch() {
    final key = BatchKey.parse(batch);
    return key.program;
  }

  List<_ToolItem> _getUniversalTools() {
    return [
      _ToolItem(
        id: 'unit_converter',
        title: 'Unit Converter',
        subtitle: 'Length, weight, temperature and more',
        icon: Icons.swap_horiz_rounded,
        color: IrisTokens.blue,
        description: 'Convert common engineering and daily-use units quickly',
      ),
      _ToolItem(
        id: 'word_counter',
        title: 'Word Counter',
        subtitle: 'Words, chars, read time and speaking time',
        icon: Icons.text_fields_rounded,
        color: IrisTokens.purple,
        description: 'Analyze writing quality and pacing instantly',
      ),
      _ToolItem(
        id: 'universal_calculator',
        title: 'Universal Calculator',
        subtitle: 'Arithmetic, markup and scientific operations',
        icon: Icons.functions_rounded,
        color: IrisTokens.success,
        description:
            'Solve standard calculations, profit pricing and scientific values',
      ),
      _ToolItem(
        id: 'cgpa_calculator',
        title: 'CGPA Calculator',
        subtitle: 'Track semester GPA and cumulative CGPA',
        icon: Icons.calculate_rounded,
        color: IrisTokens.brand,
        description: 'Compute GPA per semester and your overall CGPA quickly',
      ),
      _ToolItem(
        id: 'base_converter',
        title: 'Base Converter',
        subtitle: 'Binary, octal, decimal and hexadecimal',
        icon: Icons.memory_rounded,
        color: IrisTokens.success,
        description: 'Smart number base conversion with auto-detect mode',
      ),
      _ToolItem(
        id: 'equation_solver',
        title: 'Equation Solver',
        subtitle: 'Linear, quadratic and calculus helpers',
        icon: Icons.calculate_outlined,
        color: IrisTokens.warning,
        description: 'Solve equations with step-by-step intelligent feedback',
      ),
      _ToolItem(
        id: 'molecular_weight_calculator',
        title: 'Molecular Weight Calculator',
        subtitle: 'Molar mass from chemical formulas',
        icon: Icons.science_rounded,
        color: IrisTokens.success,
        description:
            'Smart chemistry parser with grouped compounds and hydrate support',
      ),
      _ToolItem(
        id: 'offline_formula_library',
        title: 'Formula Library & Constants',
        subtitle: 'Offline formulas for thermo, circuits, mechanics',
        icon: Icons.menu_book_rounded,
        color: IrisTokens.blue,
        description: 'Searchable offline reference with smart categorization',
      ),
      _ToolItem(
        id: 'export_schedule',
        title: 'Export Schedule',
        subtitle: 'Download timetable as PDF or calendar',
        icon: Icons.download_rounded,
        color: IrisTokens.blue,
        description:
            'Export your schedule in multiple formats for offline access',
      ),
      _ToolItem(
        id: 'find_rooms',
        title: 'Room Finder',
        subtitle: 'Discover available study spaces',
        icon: Icons.location_on_rounded,
        color: IrisTokens.success,
        description: 'Find empty classrooms and labs available now',
      ),
      _ToolItem(
        id: 'teacher_directory',
        title: 'Teacher Directory',
        subtitle: 'Contact info and office hours',
        icon: Icons.person_rounded,
        color: IrisTokens.purple,
        description: 'Search all teachers by name and department',
      ),
      _ToolItem(
        id: 'teacher_locator',
        title: 'Teacher Locator',
        subtitle: 'Live teacher status and weekly schedule',
        icon: Icons.person_search_rounded,
        color: IrisTokens.purple,
        description: 'Locate a teacher instantly with smart matching',
      ),
      _ToolItem(
        id: 'browse_classes',
        title: 'Browse Classes',
        subtitle: 'Open all batch classes and schedules',
        icon: Icons.school_rounded,
        color: IrisTokens.brand,
        description: 'Explore class lists directly from Resources',
      ),
      _ToolItem(
        id: 'makeup_scheduler',
        title: 'Makeup Planner',
        subtitle: 'Find and add makeup lecture slots',
        icon: Icons.event_repeat_rounded,
        color: IrisTokens.warning,
        description: 'Plan and manage makeup lectures from one place',
      ),
      _ToolItem(
        id: 'transport_schedule',
        title: 'Transport Schedule',
        subtitle: 'Bus and shuttle notices',
        icon: Icons.directions_bus_rounded,
        color: IrisTokens.success,
        description: 'Scraper-backed transport updates and timing notices',
      ),
      _ToolItem(
        id: 'library_schedule',
        title: 'Library Schedule',
        subtitle: 'Opening hours and library notices',
        icon: Icons.local_library_rounded,
        color: IrisTokens.blue,
        description: 'Scraper-backed library timing and service updates',
      ),
      _ToolItem(
        id: 'semester_schedule',
        title: 'Semester Schedule',
        subtitle: 'Midterm, finals and semester milestones',
        icon: Icons.event_note_rounded,
        color: IrisTokens.purple,
        description: 'Scraper-backed semester and exam announcements',
      ),
      _ToolItem(
        id: 'timetable_print',
        title: 'Print Timetable',
        subtitle: 'Get a printable schedule',
        icon: Icons.print_rounded,
        color: IrisTokens.warning,
        description: 'Generate a formatted timetable for printing',
      ),
      _ToolItem(
        id: 'class_analytics',
        title: 'Class Analytics',
        subtitle: 'Schedule insights and patterns',
        icon: Icons.analytics_rounded,
        color: IrisTokens.brand,
        description: 'View your class distribution, busiest days, and patterns',
      ),
    ];
  }

  List<_ToolItem> _getDepartmentTools(String department) {
    final deptTools = <String, List<_ToolItem>>{
      'BCS': [
        _ToolItem(
          id: 'lab_resources',
          title: 'CS Lab Resources',
          subtitle: 'IDE guides and compiler info',
          icon: Icons.computer_rounded,
          color: IrisTokens.brand,
          description: 'Access software lab guidelines and development tools',
        ),
        _ToolItem(
          id: 'programming_tools',
          title: 'Programming Tools',
          subtitle: 'Compilers, IDEs, and frameworks',
          icon: Icons.code_rounded,
          color: IrisTokens.blue,
          description: 'Setup guides for common development environments',
        ),
      ],
      'BBA': [
        _ToolItem(
          id: 'business_resources',
          title: 'Business Resources',
          subtitle: 'Case studies and market data',
          icon: Icons.trending_up_rounded,
          color: IrisTokens.brand,
          description: 'Access business databases and research resources',
        ),
      ],
      'RHND': [
        _ToolItem(
          id: 'design_tools',
          title: 'Design Resources',
          subtitle: 'CAD software and design guides',
          icon: Icons.architecture_rounded,
          color: IrisTokens.brand,
          description: 'Resources for architectural design and visualization',
        ),
      ],
    };

    final tools = List<_ToolItem>.from(deptTools[department] ?? []);
    if (_isHealthDepartment(department)) {
      tools.addAll([
        _ToolItem(
          id: 'health_tools',
          title: 'Health Calculators',
          subtitle: 'BMI, hydration and vitals assistant',
          icon: Icons.monitor_heart_rounded,
          color: IrisTokens.success,
          description: 'Smart health checks tailored for routine monitoring',
        ),
        _ToolItem(
          id: 'periodic_table',
          title: 'Periodic Table',
          subtitle: 'Quick chemistry reference',
          icon: Icons.grid_view_rounded,
          color: IrisTokens.brand,
          description: 'Searchable mini periodic table for common elements',
        ),
      ]);
    }

    if (_isMecDepartment(department)) {
      tools.add(
        _ToolItem(
          id: 'resistor_decoder',
          title: 'Resistor Color Decoder',
          subtitle: '4-band resistor value and tolerance',
          icon: Icons.settings_input_component_rounded,
          color: IrisTokens.warning,
          description:
              'Smart resistor decoding with human-friendly units and guidance',
        ),
      );
    }

    if (_isOtherDepartment(department)) {
      tools.add(
        _ToolItem(
          id: 'dept_smart_kit',
          title: 'Department Smart Kit',
          subtitle: 'Adaptive accessories and estimators',
          icon: Icons.auto_graph_rounded,
          color: IrisTokens.blue,
          description:
              'Intelligent planning tools tailored to your department profile',
        ),
      );
    }

    return tools;
  }

  bool _isHealthDepartment(String department) {
    final d = department.toLowerCase();
    return d.contains('health') ||
        d.contains('nursing') ||
        d.contains('medical') ||
        d.contains('pharm') ||
        d.contains('dpt') ||
        d.contains('physio') ||
        d.contains('bio');
  }

  bool _isMecDepartment(String department) {
    final d = department.toLowerCase();
    return d.contains('mec') ||
        d.contains('mechanical') ||
        d.contains('electrical') ||
        d.contains('electronics') ||
        d.contains('mechatronics');
  }

  bool _isOtherDepartment(String department) {
    if (department == 'BCS' || department == 'BBA' || department == 'RHND') {
      return false;
    }
    if (_isHealthDepartment(department) || _isMecDepartment(department)) {
      return false;
    }
    return true;
  }

  String _recommendedToolId(
    String department,
    DateTime now,
    ClassSession? current,
    ClassSession? next,
  ) {
    if (current != null) {
      return 'class_analytics';
    }

    if (next != null && next.dayIndex == now.weekday) {
      final currentTime = now.hour + (now.minute / 60.0);
      final minsToNext = ((next.safeStartVal - currentTime) * 60).round();
      if (minsToNext >= 0 && minsToNext <= 25) {
        return 'find_rooms';
      }
    }

    if (department == 'BCS') {
      return 'base_converter';
    }

    if (_isHealthDepartment(department)) {
      return 'health_tools';
    }

    if (_isMecDepartment(department)) {
      return 'resistor_decoder';
    }

    if (_isOtherDepartment(department)) {
      return 'dept_smart_kit';
    }

    if (department == 'RHND') {
      return 'molecular_weight_calculator';
    }

    if (department == 'BBA') {
      return 'offline_formula_library';
    }

    return 'cgpa_calculator';
  }

  List<_ToolItem> _prioritizeTool(
    List<_ToolItem> source,
    String recommendedId,
  ) {
    final items = List<_ToolItem>.from(source);
    final index = items.indexWhere((t) => t.id == recommendedId);
    if (index <= 0) {
      return items;
    }
    final picked = items.removeAt(index);
    items.insert(0, picked);
    return items;
  }

  Widget _buildSmartInsightCard({
    required bool isDark,
    required String department,
    required String recommendedId,
    required ClassSession? current,
    required ClassSession? next,
  }) {
    final title = current != null
        ? 'You are live in ${current.subject}'
        : next != null
        ? 'Next class: ${next.subject}'
        : 'No upcoming class right now';

    final reason = switch (recommendedId) {
      'find_rooms' => 'Smart pick: Room Finder because your next class is soon.',
      'programming_tools' =>
        'Smart pick: Programming Tools based on your $department profile.',
      'base_converter' =>
        'Smart pick: Base Converter for fast number-system conversions.',
      'equation_solver' =>
        'Smart pick: Equation Solver for quick algebra and calculus checks.',
      'molecular_weight_calculator' =>
        'Smart pick: Molecular Weight Calculator for chemistry-focused formulas.',
      'offline_formula_library' =>
        'Smart pick: Formula Library for instant offline concept recall.',
      'health_tools' =>
        'Smart pick: Health calculators based on your department profile.',
      'periodic_table' =>
        'Smart pick: Periodic table for fast element lookup.',
      'resistor_decoder' =>
        'Smart pick: Resistor decoder for quick lab component reading.',
      'dept_smart_kit' =>
        'Smart pick: Adaptive department kit for planning and quick estimates.',
      'class_analytics' =>
        'Smart pick: Class Analytics to track live load and timing patterns.',
      _ => 'Smart pick: CGPA Calculator to stay on top of your semester progress.',
    };

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: IrisTokens.brandGradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Smart Tools Assistant',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: TextStyle(
                fontSize: 12,
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceStatChip({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color tint,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: isDark ? 0.17 : 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tint.withValues(alpha: isDark ? 0.33 : 0.20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: tint),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.58,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadCampusHubData() async {
    final schedule = await HelpdeskScheduleDataService().fetchSchedulePayload();
    final noticesPayload =
      await HelpdeskCampusFeedService().fetchNoticesLiveFirstWithFallbackPayload();

    final entries = <Map<String, String>>[];

    for (final route in schedule.transportRoutes) {
      final first = route.stops.isNotEmpty ? route.stops.first.time : '--';
      final last = route.stops.isNotEmpty ? route.stops.last.time : '--';
      final stopKeywords = route.stops.map((e) => e.point).join(' ');
      entries.add({
        'type': 'transport',
        'title': route.route,
        'subtitle': '${route.stops.length} stops • $first to $last',
        'search': '${route.route} $stopKeywords ${route.driverName} ${route.helperName}'.toLowerCase(),
      });
    }

    for (final item in schedule.semesterSchedule) {
      entries.add({
        'type': 'semester',
        'title': item.title,
        'subtitle': '${item.date} • ${item.status.toUpperCase()}',
        'search': '${item.title} ${item.date} ${item.status}'.toLowerCase(),
      });
    }

    for (final item in schedule.deadlines) {
      entries.add({
        'type': 'deadline',
        'title': item.title,
        'subtitle': '${item.date} • ${item.status.toUpperCase()}',
        'search': '${item.title} ${item.date} ${item.status}'.toLowerCase(),
      });
    }

    final library = schedule.librarySchedule;
    if (library != null) {
      entries.addAll([
        {
          'type': 'library',
          'title': 'Library Opening Time',
          'subtitle': library.open,
          'search': 'library open ${library.open}'.toLowerCase(),
        },
        {
          'type': 'library',
          'title': 'Library Break Time',
          'subtitle': library.breakTime,
          'search': 'library break ${library.breakTime}'.toLowerCase(),
        },
        {
          'type': 'library',
          'title': 'Library Closing Time',
          'subtitle': library.close,
          'search': 'library close ${library.close}'.toLowerCase(),
        },
      ]);
    }

    for (final notice in noticesPayload.items.take(15)) {
      entries.add({
        'type': 'notice',
        'title': notice.title,
        'subtitle': notice.detail.replaceAll('\n', ' ').trim(),
        'search': notice.searchable,
      });
    }

    try {
      final raw = await rootBundle.loadString(
        'assets/helpdesk_backup/helpdesk_snapshot.json',
      );
      final decoded = jsonDecode(raw);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      final events = data is Map<String, dynamic> ? data['events'] : null;
      if (events is List) {
        for (final event in events.whereType<Map<String, dynamic>>().take(20)) {
          final title = (event['title'] ?? event['name'] ?? 'Campus Event')
              .toString()
              .trim();
          final detail = (event['detail'] ?? event['description'] ?? event['about'] ?? '')
              .toString()
              .trim();
          final date = (event['date'] ?? event['createdAt'] ?? '').toString().trim();
          entries.add({
            'type': 'event',
            'title': title,
            'subtitle': date.isEmpty ? detail : '$date • $detail',
            'search': '$title $detail $date event'.toLowerCase(),
          });
        }
      }
    } catch (_) {
      // Keep hub resilient when optional event snapshot is unavailable.
    }

    return {
      'entries': entries,
      'transportCount': schedule.transportRoutes.length,
      'semesterCount': schedule.semesterSchedule.length,
      'deadlineCount': schedule.deadlines.length,
    };
  }

  Widget _buildCampusDataHubPanel(
    BuildContext context,
    bool isDark,
    String department,
  ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadCampusHubData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Building unified campus data surface...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.66,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final allEntries =
            (snapshot.data!['entries'] as List<Map<String, String>>)
                .toList(growable: false);
        var query = '';

        return StatefulBuilder(
          builder: (context, setLocalState) {
            final lowered = query.trim().toLowerCase();
            final filtered = lowered.isEmpty
                ? allEntries
                : allEntries
                    .where((e) => (e['search'] ?? '').contains(lowered))
                    .toList(growable: false);

            Color colorForType(String type) {
              switch (type) {
                case 'transport':
                  return IrisTokens.success;
                case 'library':
                  return IrisTokens.blue;
                case 'semester':
                case 'deadline':
                  return IrisTokens.warning;
                case 'event':
                  return IrisTokens.purple;
                default:
                  return IrisTokens.brand;
              }
            }

            IconData iconForType(String type) {
              switch (type) {
                case 'transport':
                  return Icons.alt_route_rounded;
                case 'library':
                  return Icons.local_library_rounded;
                case 'semester':
                  return Icons.event_note_rounded;
                case 'deadline':
                  return Icons.task_alt_rounded;
                case 'event':
                  return Icons.celebration_rounded;
                default:
                  return Icons.notifications_active_rounded;
              }
            }

            return GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UNIFIED CAMPUS DATA HUB',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: (isDark ? Colors.white : Colors.black).withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Search transport routes, library timings, semester flow, deadlines, events and notices in one place.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (isDark ? Colors.white : Colors.black).withValues(
                          alpha: 0.68,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (value) => setLocalState(() => query = value),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search anything in campus data...',
                        prefixIcon: const Icon(Icons.manage_search_rounded, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: (isDark ? Colors.white : Colors.black).withValues(
                          alpha: isDark ? 0.09 : 0.04,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildResourceStatChip(
                          isDark: isDark,
                          icon: Icons.directions_bus_rounded,
                          label: 'Routes',
                          value: '${snapshot.data!['transportCount']}',
                          tint: IrisTokens.success,
                        ),
                        const SizedBox(width: 8),
                        _buildResourceStatChip(
                          isDark: isDark,
                          icon: Icons.event_note_rounded,
                          label: 'Semester',
                          value: '${snapshot.data!['semesterCount']}',
                          tint: IrisTokens.warning,
                        ),
                        const SizedBox(width: 8),
                        _buildResourceStatChip(
                          isDark: isDark,
                          icon: Icons.assignment_turned_in_rounded,
                          label: 'Deadlines',
                          value: '${snapshot.data!['deadlineCount']}',
                          tint: IrisTokens.brand,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...filtered.take(16).map((entry) {
                      final type = entry['type'] ?? 'notice';
                      final tint = colorForType(type);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            if (type == 'transport') {
                              _handleToolTap(context, 'transport_schedule', department);
                              return;
                            }
                            if (type == 'library') {
                              _handleToolTap(context, 'library_schedule', department);
                              return;
                            }
                            if (type == 'semester' || type == 'deadline') {
                              _handleToolTap(context, 'semester_schedule', department);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: tint.withValues(alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: tint.withValues(alpha: isDark ? 0.28 : 0.20),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(iconForType(type), size: 16, color: tint),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry['title'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        entry['subtitle'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.62),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (filtered.length > 16)
                      Text(
                        '+${filtered.length - 16} more results. Keep typing to narrow down.',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: (isDark ? Colors.white : Colors.black).withValues(
                            alpha: 0.58,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final department = _getDepartmentFromBatch();
    final current = brain.getCurrentClass(batch, now);
    final next = brain.getNextClass(batch, now);
    final recommendedId = _recommendedToolId(department, now, current, next);
    final universalTools = _prioritizeTool(_getUniversalTools(), recommendedId);
    final deptTools = _getDepartmentTools(department);
    const quickIds = {
      'teacher_locator',
      'browse_classes',
      'makeup_scheduler',
      'teacher_directory',
    };
    const campusDataIds = {
      'transport_schedule',
      'library_schedule',
      'semester_schedule',
      'class_analytics',
      'timetable_print',
    };
    const calculatorIds = {
      'universal_calculator',
      'cgpa_calculator',
      'unit_converter',
      'base_converter',
      'equation_solver',
      'molecular_weight_calculator',
    };

    final quickTools = universalTools
        .where((tool) => quickIds.contains(tool.id))
        .toList(growable: false);
    final campusDataTools = universalTools
        .where((tool) => campusDataIds.contains(tool.id))
        .toList(growable: false);
    final calculatorTools = universalTools
        .where((tool) => calculatorIds.contains(tool.id))
        .toList(growable: false);
    final otherTools = universalTools
        .where(
          (tool) =>
              !quickIds.contains(tool.id) &&
              !campusDataIds.contains(tool.id) &&
              !calculatorIds.contains(tool.id),
        )
        .toList(growable: false);

    SliverPadding sectionGrid(List<_ToolItem> items) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.16,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final tool = items[index];
            return _ToolCard(
              tool: tool,
              isDark: isDark,
              onTap: () => _handleToolTap(context, tool.id, department),
            );
          }, childCount: items.length),
        ),
      );
    }

    SliverPadding sectionTitle(String title) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        sliver: SliverToBoxAdapter(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.46),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Resources',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          sectionTitle('QUICK ACCESS'),
          sectionGrid(quickTools),
          sectionTitle('CAMPUS DATA'),
          sectionGrid(campusDataTools),
          sectionTitle('CALCULATORS'),
          sectionGrid(calculatorTools),
          sectionTitle('OTHER TOOLS'),
          sectionGrid(otherTools),
          if (deptTools.isNotEmpty) ...[
            sectionTitle('${department.toUpperCase()} KIT'),
            sectionGrid(deptTools),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  bool _isMakeupSession(ClassSession session) =>
      session.id.startsWith('makeup_');

  Future<void> _persistCustomMakeupSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = memory.sessions.where(_isMakeupSession).map((s) => s.toJson()).toList();
    await prefs.setString('custom_makeup_sessions', jsonEncode(custom));
  }

  Future<void> _addMakeupSessionFromTools(
    BuildContext context,
    ClassSession session,
  ) async {
    if (session.batchKey.batch != batch) return;
    final duplicate = memory.sessions.any((s) => s.id == session.id);
    if (duplicate) return;
    memory.sessions.add(session);
    await _persistCustomMakeupSessions();
    if (!context.mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'tools_makeup_added_${session.id}',
      content: Text('Added makeup class: ${session.subject}'),
    );
  }

  Future<void> _removeMakeupSessionFromTools(ClassSession session) async {
    memory.sessions.removeWhere((s) => s.id == session.id);
    await _persistCustomMakeupSessions();
  }

  void _handleToolTap(BuildContext context, String toolId, String department) {
    IrisHaptics.actionSoft();
    switch (toolId) {
      case 'unit_converter':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _UnitConverterScreen()),
        );
        break;
      case 'word_counter':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _WordCounterScreen()),
        );
        break;
      case 'universal_calculator':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _UniversalCalculatorScreen()),
        );
        break;
      case 'cgpa_calculator':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _CgpaCalculatorScreen(),
          ),
        );
        break;
      case 'base_converter':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _BaseConverterScreen()),
        );
        break;
      case 'equation_solver':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _EquationSolverScreen()),
        );
        break;
      case 'molecular_weight_calculator':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _MolecularWeightCalculatorScreen(),
          ),
        );
        break;
      case 'offline_formula_library':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _OfflineFormulaLibraryScreen(),
          ),
        );
        break;
      case 'export_schedule':
        _showFeatureComingSoon(context, 'Schedule Export');
        break;
      case 'find_rooms':
        _showFeatureComingSoon(context, 'Room Finder');
        break;
      case 'teacher_directory':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FacultyDirectoryScreen(
              brain: brain,
              onRoleChanged: onRoleChanged,
              memory: memory,
              currentBatch: batch,
            ),
          ),
        );
        break;
      case 'teacher_locator':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _TeacherLocatorScreen(
              brain: brain,
              onRoleChanged: onRoleChanged,
              memory: memory,
              currentBatch: batch,
              showDock: false,
            ),
          ),
        );
        break;
      case 'browse_classes':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _DepartmentClassesScreen(
              memory: memory,
              currentBatch: batch,
              brain: brain,
              onRoleChanged: onRoleChanged,
              showDock: false,
            ),
          ),
        );
        break;
      case 'makeup_scheduler':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MakeupLectureScheduler(
              memory: memory,
              brain: brain,
              batch: batch,
              onAddMakeupClass: (session) =>
                  _addMakeupSessionFromTools(context, session),
              onRemoveMakeupClass: _removeMakeupSessionFromTools,
              onRoleChanged: onRoleChanged,
              showDock: false,
            ),
          ),
        );
        break;
      case 'transport_schedule':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _CampusScheduleFeedScreen(
              feedType: _CampusFeedType.transport,
            ),
          ),
        );
        break;
      case 'library_schedule':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _CampusScheduleFeedScreen(
              feedType: _CampusFeedType.library,
            ),
          ),
        );
        break;
      case 'semester_schedule':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _CampusScheduleFeedScreen(
              feedType: _CampusFeedType.semester,
            ),
          ),
        );
        break;
      case 'timetable_print':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PrintTimetableScreen(brain: brain, batch: batch),
          ),
        );
        break;
      case 'class_analytics':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ClassAnalyticsScreen(brain: brain, batch: batch),
          ),
        );
        break;
      case 'lab_resources':
        _showFeatureComingSoon(context, 'Lab Resources');
        break;
      case 'programming_tools':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _ProgrammingToolsScreen()),
        );
        break;
      case 'business_resources':
        _showFeatureComingSoon(context, 'Business Resources');
        break;
      case 'design_tools':
        _showFeatureComingSoon(context, 'Design Tools');
        break;
      case 'health_tools':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _HealthToolsScreen(initialTab: 0),
          ),
        );
        break;
      case 'periodic_table':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _HealthToolsScreen(initialTab: 1),
          ),
        );
        break;
      case 'resistor_decoder':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _ResistorColorDecoderScreen(),
          ),
        );
        break;
      case 'dept_smart_kit':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _DepartmentSmartKitScreen(
              department: department,
              brain: brain,
              batch: batch,
            ),
          ),
        );
        break;
    }
  }

  void _showFeatureComingSoon(BuildContext context, String featureName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                offset: const Offset(0, 12),
                blurRadius: 32,
                spreadRadius: -8,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: IrisTokens.brandGradient),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: IrisTokens.brand.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$featureName is under development',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.7,
                  ),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: IrisTokens.brand,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got It',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitConverterScreen extends StatefulWidget {
  const _UnitConverterScreen();

  @override
  State<_UnitConverterScreen> createState() => _UnitConverterScreenState();
}

enum _CampusFeedType { transport, library, semester }

class _CampusScheduleFeedScreen extends StatefulWidget {
  final _CampusFeedType feedType;

  const _CampusScheduleFeedScreen({required this.feedType});

  @override
  State<_CampusScheduleFeedScreen> createState() =>
      _CampusScheduleFeedScreenState();
}

class _CampusScheduleFeedScreenState extends State<_CampusScheduleFeedScreen> {
  final HelpdeskScheduleDataService _scheduleService = HelpdeskScheduleDataService();
  final HelpdeskCampusFeedService _noticeService = HelpdeskCampusFeedService();
  CampusSchedulePayload? _payload;
  HelpdeskCampusFeedSource _noticeSource = HelpdeskCampusFeedSource.none;
  bool _loading = true;
  List<CampusNotice> _relatedNotices = const [];
  String _routeQuery = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final schedulePayload = await _scheduleService.fetchSchedulePayload();
    final noticePayload = await _noticeService.fetchNoticesLiveFirstWithFallbackPayload();
    final filtered = HelpdeskCampusFeedService.filterByKeywords(noticePayload.items, _keywords);
    if (!mounted) return;
    setState(() {
      _payload = schedulePayload;
      _noticeSource = noticePayload.source;
      _relatedNotices = filtered.take(8).toList(growable: false);
      _loading = false;
    });
  }

  String get _title {
    switch (widget.feedType) {
      case _CampusFeedType.transport:
        return 'Transport Schedule';
      case _CampusFeedType.library:
        return 'Library Schedule';
      case _CampusFeedType.semester:
        return 'Semester Schedule';
    }
  }

  String get _subtitle {
    switch (widget.feedType) {
      case _CampusFeedType.transport:
        return 'Full route map, stops and contacts';
      case _CampusFeedType.library:
        return 'Opening hours, break window and updates';
      case _CampusFeedType.semester:
        return 'Milestones, exams and deadline tracker';
    }
  }

  IconData get _icon {
    switch (widget.feedType) {
      case _CampusFeedType.transport:
        return Icons.directions_bus_rounded;
      case _CampusFeedType.library:
        return Icons.local_library_rounded;
      case _CampusFeedType.semester:
        return Icons.event_note_rounded;
    }
  }

  List<String> get _keywords {
    switch (widget.feedType) {
      case _CampusFeedType.transport:
        return const ['transport', 'bus', 'route', 'shuttle', 'pickup', 'drop'];
      case _CampusFeedType.library:
        return const ['library', 'books', 'timing', 'hours', 'librarian'];
      case _CampusFeedType.semester:
        return const ['semester', 'mid', 'midterm', 'final', 'terminal', 'exam', 'calendar'];
    }
  }

  String _sourceLabel(HelpdeskCampusFeedSource source) {
    switch (source) {
      case HelpdeskCampusFeedSource.live:
        return 'LIVE';
      case HelpdeskCampusFeedSource.cache:
        return 'CACHE';
      case HelpdeskCampusFeedSource.backup:
        return 'BACKUP';
      case HelpdeskCampusFeedSource.none:
        return 'OFFLINE';
    }
  }

  String _scheduleSourceLabel(CampusScheduleSource source) {
    switch (source) {
      case CampusScheduleSource.asset:
        return 'ASSET';
      case CampusScheduleSource.none:
        return 'OFFLINE';
    }
  }

  String _prettyDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}-${local.month.toString().padLeft(2, '0')}-${local.year}';
  }

  String _dateLabel(String input) {
    final dt = DateTime.tryParse(input);
    if (dt == null) return input.isEmpty ? 'TBA' : input;
    return _prettyDate(dt);
  }

  String _statusLabel(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('expired') || v.contains('passed')) return 'Done';
    if (v.contains('upcoming')) return 'Upcoming';
    return 'Scheduled';
  }

  Color _statusColor(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('expired') || v.contains('passed')) return IrisTokens.warning;
    if (v.contains('upcoming')) return IrisTokens.success;
    return IrisTokens.brand;
  }

  List<TransportRouteData> _filteredRoutes(List<TransportRouteData> routes) {
    final query = _routeQuery.trim().toLowerCase();
    if (query.isEmpty) return routes;
    return routes.where((route) {
      if (route.route.toLowerCase().contains(query)) return true;
      return route.stops.any((stop) => stop.point.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  Future<void> _launchTransportPhone(String rawPhone) async {
    final cleaned = rawPhone.trim().replaceAll(' ', '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'transport_phone_unavailable',
      content: const Text('Unable to open dialer on this device'),
    );
  }

  Widget _buildNoticeCard(bool isDark, CampusNotice item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.detail,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${item.createdBy.isEmpty ? 'Admin' : item.createdBy} • ${_prettyDate(item.createdAt)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: IrisTokens.brand.withValues(alpha: 0.86),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransportBody(bool isDark, CampusSchedulePayload payload) {
    final routes = _filteredRoutes(payload.transportRoutes);
    return Column(
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _routeQuery = value),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search route or stop...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.09 : 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: IrisTokens.success.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: IrisTokens.success.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '${routes.length} routes',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: IrisTokens.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...routes.map((route) {
          final firstStop = route.stops.isNotEmpty ? route.stops.first.time : '--';
          final lastStop = route.stops.isNotEmpty ? route.stops.last.time : '--';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  title: Text(
                    route.route,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    '${route.stops.length} stops • $firstStop to $lastStop',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.58),
                    ),
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: route.driverPhone.isNotEmpty
                              ? InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () =>
                                      _launchTransportPhone(route.driverPhone),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      'Driver: ${route.driverName.isEmpty ? 'N/A' : route.driverName} (${route.driverPhone}) • Tap to call',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: IrisTokens.brand,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  'Driver: ${route.driverName.isEmpty ? 'N/A' : route.driverName}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: IrisTokens.brand,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    if (route.helperName.isNotEmpty || route.helperPhone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: route.helperPhone.isNotEmpty
                                ? InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () =>
                                        _launchTransportPhone(route.helperPhone),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        'Helper: ${route.helperName.isEmpty ? 'N/A' : route.helperName} (${route.helperPhone}) • Tap to call',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: IrisTokens.purple,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Helper: ${route.helperName.isEmpty ? 'N/A' : route.helperName}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: IrisTokens.purple,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    ...route.stops.asMap().entries.map((entry) {
                      final index = entry.key;
                      final stop = entry.value;
                      final isFirst = index == 0;
                      final isLast = index == route.stops.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Column(
                                children: [
                                  Container(
                                    width: 2,
                                    height: 8,
                                    color: isFirst
                                        ? Colors.transparent
                                        : IrisTokens.success.withValues(alpha: 0.45),
                                  ),
                                  Container(
                                    width: isFirst || isLast ? 10 : 8,
                                    height: isFirst || isLast ? 10 : 8,
                                    decoration: BoxDecoration(
                                      color: isFirst
                                          ? IrisTokens.brand
                                          : isLast
                                          ? IrisTokens.warning
                                          : IrisTokens.success,
                                      borderRadius: BorderRadius.circular(99),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isFirst
                                                  ? IrisTokens.brand
                                                  : isLast
                                                  ? IrisTokens.warning
                                                  : IrisTokens.success)
                                              .withValues(alpha: 0.36),
                                          blurRadius: 8,
                                          spreadRadius: -2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 2,
                                    height: 22,
                                    color: isLast
                                        ? Colors.transparent
                                        : IrisTokens.success.withValues(alpha: 0.45),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withValues(
                                    alpha: isDark ? 0.07 : 0.03,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (isDark ? Colors.white : Colors.black).withValues(
                                      alpha: 0.08,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        stop.point,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      stop.time,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: 0.64),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLibraryBody(bool isDark, CampusSchedulePayload payload) {
    final library = payload.librarySchedule;
    final entries = [
      {'label': 'Open', 'value': library?.open ?? 'N/A', 'color': IrisTokens.success},
      {'label': 'Break', 'value': library?.breakTime ?? 'N/A', 'color': IrisTokens.warning},
      {'label': 'Close', 'value': library?.close ?? 'N/A', 'color': IrisTokens.brand},
    ];

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: entries.map((entry) {
            final color = entry['color'] as Color;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['label']! as String,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry['value']! as String,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildSemesterBody(bool isDark, CampusSchedulePayload payload) {
    return Column(
      children: [
        ...payload.semesterSchedule.map((item) {
          final color = _statusColor(item.status);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dateLabel(item.date),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color.withValues(alpha: 0.28)),
                      ),
                      child: Text(
                        _statusLabel(item.status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (payload.deadlines.isNotEmpty)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assignment Deadlines',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...payload.deadlines.take(8).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: _statusColor(item.status)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          Text(
                            _dateLabel(item.date),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 10;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark),
          RefreshIndicator(
            onRefresh: _load,
            color: IrisTokens.brand,
            child: ListView(
              physics: const ButterScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, topInset, 16, 24),
              children: [
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: IrisTokens.brandGradient),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_icon, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: IrisTokens.brand.withValues(alpha: 0.13),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.24)),
                                    ),
                                    child: Text(
                                      _payload == null
                                          ? 'OFFLINE'
                                          : _scheduleSourceLabel(_payload!.source),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: IrisTokens.brand,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: IrisTokens.success.withValues(alpha: 0.13),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: IrisTokens.success.withValues(alpha: 0.24)),
                                    ),
                                    child: Text(
                                      _sourceLabel(_noticeSource),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: IrisTokens.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_payload == null)
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'No $_title data available right now.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  )
                else ...[
                  if (widget.feedType == _CampusFeedType.transport)
                    _buildTransportBody(isDark, _payload!),
                  if (widget.feedType == _CampusFeedType.library)
                    _buildLibraryBody(isDark, _payload!),
                  if (widget.feedType == _CampusFeedType.semester)
                    _buildSemesterBody(isDark, _payload!),
                  if (_relatedNotices.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Related Notices',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._relatedNotices.map((item) => _buildNoticeCard(isDark, item)),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitConverterScreenState extends State<_UnitConverterScreen> {
  final TextEditingController _valueController = TextEditingController();
  final List<String> _categories = ['Length', 'Weight', 'Temperature'];
  String _category = 'Length';
  String _from = 'Meter';
  String _to = 'Kilometer';
  double _result = 0.0;

  static const Map<String, Map<String, double>> _ratioMap = {
    'Length': {
      'Meter': 1.0,
      'Kilometer': 1000.0,
      'Centimeter': 0.01,
      'Millimeter': 0.001,
      'Foot': 0.3048,
      'Inch': 0.0254,
    },
    'Weight': {
      'Kilogram': 1.0,
      'Gram': 0.001,
      'Pound': 0.45359237,
      'Ounce': 0.028349523,
    },
  };

  List<String> _unitsFor(String category) {
    if (category == 'Temperature') {
      return ['Celsius', 'Fahrenheit', 'Kelvin'];
    }
    return _ratioMap[category]!.keys.toList();
  }

  @override
  void initState() {
    super.initState();
    _valueController.text = '1';
    _compute();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  double _convertTemperature(double value, String from, String to) {
    double celsius;
    if (from == 'Celsius') {
      celsius = value;
    } else if (from == 'Fahrenheit') {
      celsius = (value - 32) * (5 / 9);
    } else {
      celsius = value - 273.15;
    }

    if (to == 'Celsius') {
      return celsius;
    }
    if (to == 'Fahrenheit') {
      return (celsius * 9 / 5) + 32;
    }
    return celsius + 273.15;
  }

  void _compute() {
    final input = double.tryParse(_valueController.text.trim()) ?? 0.0;
    double converted;

    if (_category == 'Temperature') {
      converted = _convertTemperature(input, _from, _to);
    } else {
      final map = _ratioMap[_category]!;
      final inBase = input * map[_from]!;
      converted = inBase / map[_to]!;
    }

    setState(() {
      _result = converted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final units = _unitsFor(_category);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Unit Converter'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'core'),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final nextUnits = _unitsFor(value);
                      setState(() {
                        _category = value;
                        _from = nextUnits.first;
                        _to = nextUnits.length > 1
                            ? nextUnits[1]
                            : nextUnits.first;
                      });
                      _compute();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _compute(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _from,
                          decoration: const InputDecoration(
                            labelText: 'From',
                            border: OutlineInputBorder(),
                          ),
                          items: units
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _from = value);
                            _compute();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _to,
                          decoration: const InputDecoration(
                            labelText: 'To',
                            border: OutlineInputBorder(),
                          ),
                          items: units
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _to = value);
                            _compute();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Result',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_result.toStringAsFixed(4)} $_to',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WordCounterScreen extends StatefulWidget {
  const _WordCounterScreen();

  @override
  State<_WordCounterScreen> createState() => _WordCounterScreenState();
}

class _UniversalCalculatorScreen extends StatefulWidget {
  const _UniversalCalculatorScreen();

  @override
  State<_UniversalCalculatorScreen> createState() =>
      _UniversalCalculatorScreenState();
}

class _UniversalCalculatorScreenState extends State<_UniversalCalculatorScreen> {
  final TextEditingController _aController = TextEditingController(text: '0');
  final TextEditingController _bController = TextEditingController(text: '0');
  final TextEditingController _costController = TextEditingController(text: '0');
  final TextEditingController _markupController = TextEditingController(
    text: '20',
  );
  final TextEditingController _valueController = TextEditingController(
    text: '1',
  );

  String _operation = '+';
  String _resultText = '0';
  String _markupResultText = '0';
  String _scientificResultText = '1';

  @override
  void initState() {
    super.initState();
    _computeStandard();
    _computeMarkup();
  }

  @override
  void dispose() {
    _aController.dispose();
    _bController.dispose();
    _costController.dispose();
    _markupController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  String _formatNum(double value) {
    if (value.isNaN || value.isInfinite) return 'Invalid';
    final fixed = value.toStringAsFixed(6);
    final trimmed = fixed.replaceFirst(RegExp(r'\.0+$'), '');
    return trimmed.replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  void _computeStandard() {
    final a = double.tryParse(_aController.text.trim()) ?? 0;
    final b = double.tryParse(_bController.text.trim()) ?? 0;
    double result;
    switch (_operation) {
      case '+':
        result = a + b;
        break;
      case '-':
        result = a - b;
        break;
      case '*':
        result = a * b;
        break;
      case '/':
        result = b == 0 ? double.nan : a / b;
        break;
      case '%':
        result = b == 0 ? double.nan : a % b;
        break;
      default:
        result = a + b;
    }

    setState(() {
      _resultText = _formatNum(result);
    });
  }

  void _computeMarkup() {
    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final markup = double.tryParse(_markupController.text.trim()) ?? 0;
    final sellPrice = cost * (1 + (markup / 100));
    setState(() {
      _markupResultText = _formatNum(sellPrice);
    });
  }

  void _applyScientific(String op) {
    final value = double.tryParse(_valueController.text.trim()) ?? 0;
    double result;
    switch (op) {
      case 'x^2':
        result = value * value;
        break;
      case 'sqrt':
        result = value < 0 ? double.nan : math.sqrt(value);
        break;
      case '1/x':
        result = value == 0 ? double.nan : 1 / value;
        break;
      case 'sin':
        result = math.sin(value);
        break;
      case 'cos':
        result = math.cos(value);
        break;
      case 'tan':
        result = math.tan(value);
        break;
      case 'ln':
        result = value <= 0 ? double.nan : math.log(value);
        break;
      default:
        result = value;
    }
    setState(() {
      _scientificResultText = _formatNum(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Universal Calculator'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'core'),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Standard',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _aController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'A',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => _computeStandard(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: DropdownButtonFormField<String>(
                          initialValue: _operation,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: const ['+', '-', '*', '/', '%']
                              .map(
                                (op) => DropdownMenuItem(
                                  value: op,
                                  child: Text(op),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _operation = value);
                            _computeStandard();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _bController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'B',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => _computeStandard(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Result: $_resultText',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Markup Calculator',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _costController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Cost Price',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => _computeMarkup(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _markupController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Markup %',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => _computeMarkup(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Selling Price: $_markupResultText',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scientific Quick Ops',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Input Value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const ['x^2', 'sqrt', '1/x', 'sin', 'cos', 'tan', 'ln']
                        .map(
                          (op) => SizedBox(
                            width: 74,
                            child: _SciOpButton(op: op),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Scientific Result: $_scientificResultText',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SciOpButton extends StatelessWidget {
  final String op;

  const _SciOpButton({required this.op});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final state = context.findAncestorStateOfType<
            _UniversalCalculatorScreenState>();
        state?._applyScientific(op);
      },
      child: Text(op),
    );
  }
}

class _BaseConverterScreen extends StatefulWidget {
  const _BaseConverterScreen();

  @override
  State<_BaseConverterScreen> createState() => _BaseConverterScreenState();
}

class _BaseConverterScreenState extends State<_BaseConverterScreen> {
  final TextEditingController _inputController = TextEditingController(
    text: '1010',
  );
  bool _autoDetect = true;
  int _manualBase = 2;
  String _status = 'Auto-detected as Binary';
  BigInt? _parsedValue = BigInt.from(10);

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  ({String normalized, int base}) _resolveBase(String input) {
    final raw = input.trim().toLowerCase();
    if (raw.startsWith('0b')) return (normalized: raw.substring(2), base: 2);
    if (raw.startsWith('0x')) return (normalized: raw.substring(2), base: 16);
    if (raw.startsWith('0o')) return (normalized: raw.substring(2), base: 8);

    if (!_autoDetect) return (normalized: raw, base: _manualBase);

    if (RegExp(r'^[01]+$').hasMatch(raw)) {
      return (normalized: raw, base: 2);
    }
    if (RegExp(r'^[0-7]+$').hasMatch(raw)) {
      return (normalized: raw, base: 8);
    }
    if (RegExp(r'^[0-9]+$').hasMatch(raw)) {
      return (normalized: raw, base: 10);
    }
    if (RegExp(r'^[0-9a-f]+$').hasMatch(raw)) {
      return (normalized: raw, base: 16);
    }

    return (normalized: raw, base: _manualBase);
  }

  String _baseName(int base) {
    switch (base) {
      case 2:
        return 'Binary';
      case 8:
        return 'Octal';
      case 10:
        return 'Decimal';
      case 16:
        return 'Hexadecimal';
      default:
        return 'Base $base';
    }
  }

  void _compute() {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _parsedValue = null;
        _status = 'Enter a value to convert';
      });
      return;
    }

    final resolved = _resolveBase(input);
    try {
      final value = BigInt.parse(resolved.normalized, radix: resolved.base);
      setState(() {
        _parsedValue = value;
        _status = 'Detected as ${_baseName(resolved.base)}';
      });
    } catch (_) {
      setState(() {
        _parsedValue = null;
        _status = 'Invalid number for selected/detected base';
      });
    }
  }

  String _out(int radix) {
    if (_parsedValue == null) return '-';
    return _parsedValue!.toRadixString(radix).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final value = _parsedValue;
    final bitLen = value == null ? '-' : value.toRadixString(2).length.toString();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Base Converter'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'core'),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Input',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _inputController,
                    decoration: const InputDecoration(
                      labelText: 'Value (prefix: 0b / 0o / 0x supported)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _compute(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Switch(
                        value: _autoDetect,
                        onChanged: (v) {
                          setState(() => _autoDetect = v);
                          _compute();
                        },
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Auto detect base')),
                    ],
                  ),
                  if (!_autoDetect)
                    DropdownButtonFormField<int>(
                      initialValue: _manualBase,
                      decoration: const InputDecoration(
                        labelText: 'Manual Base',
                        border: OutlineInputBorder(),
                      ),
                      items: const [2, 8, 10, 16]
                          .map(
                            (b) => DropdownMenuItem(
                              value: b,
                              child: Text('${_baseName(b)} ($b)'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _manualBase = v);
                        _compute();
                      },
                    ),
                  const SizedBox(height: 10),
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _parsedValue == null ? IrisTokens.error : IrisTokens.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conversions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _BaseOutRow(label: 'Binary (2)', value: _out(2)),
                  _BaseOutRow(label: 'Octal (8)', value: _out(8)),
                  _BaseOutRow(label: 'Decimal (10)', value: _out(10)),
                  _BaseOutRow(label: 'Hex (16)', value: _out(16)),
                  const Divider(height: 18),
                  _BaseOutRow(label: 'Bit Length', value: bitLen),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BaseOutRow extends StatelessWidget {
  final String label;
  final String value;

  const _BaseOutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.75,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquationSolverScreen extends StatefulWidget {
  const _EquationSolverScreen();

  @override
  State<_EquationSolverScreen> createState() => _EquationSolverScreenState();
}

class _EquationSolverScreenState extends State<_EquationSolverScreen> {
  final TextEditingController _aController = TextEditingController(text: '1');
  final TextEditingController _bController = TextEditingController(text: '0');
  final TextEditingController _cController = TextEditingController(text: '0');
  final TextEditingController _xController = TextEditingController(text: '1');
  final TextEditingController _lowController = TextEditingController(text: '0');
  final TextEditingController _highController = TextEditingController(text: '1');

  String _mode = 'Linear';
  String _headline = 'Ready';
  String _details = 'Enter values and tap Solve.';

  @override
  void dispose() {
    _aController.dispose();
    _bController.dispose();
    _cController.dispose();
    _xController.dispose();
    _lowController.dispose();
    _highController.dispose();
    super.dispose();
  }

  String _fmt(double value) {
    if (value.isNaN || value.isInfinite) return 'Invalid';
    final fixed = value.toStringAsFixed(6);
    final trimmed = fixed.replaceFirst(RegExp(r'\.0+$'), '');
    return trimmed.replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  double _poly(double x, double a, double b, double c) => (a * x * x) + (b * x) + c;

  void _solve() {
    final a = double.tryParse(_aController.text.trim()) ?? 0;
    final b = double.tryParse(_bController.text.trim()) ?? 0;
    final c = double.tryParse(_cController.text.trim()) ?? 0;
    final x0 = double.tryParse(_xController.text.trim()) ?? 0;
    final low = double.tryParse(_lowController.text.trim()) ?? 0;
    final high = double.tryParse(_highController.text.trim()) ?? 0;

    if (_mode == 'Linear') {
      if (a == 0 && b == 0) {
        setState(() {
          _headline = 'Infinite or no solutions';
          _details = 'Equation $c = 0 depends on constant value.';
        });
        return;
      }
      if (a == 0) {
        setState(() {
          _headline = 'No solution';
          _details = 'a = 0 makes equation degenerate: ${_fmt(b)}x + ${_fmt(c)} = 0';
        });
        return;
      }
      final x = -b / a;
      setState(() {
        _headline = 'x = ${_fmt(x)}';
        _details =
            'Solved ${_fmt(a)}x + ${_fmt(b)} = 0 using x = -b/a.';
      });
      return;
    }

    if (_mode == 'Quadratic') {
      if (a == 0) {
        if (b == 0) {
          setState(() {
            _headline = 'No quadratic form';
            _details = 'Both a and b are zero.';
          });
          return;
        }
        final x = -c / b;
        setState(() {
          _headline = 'Linear fallback: x = ${_fmt(x)}';
          _details = 'a = 0, so equation reduced to linear bx + c = 0.';
        });
        return;
      }

      final disc = (b * b) - (4 * a * c);
      if (disc < 0) {
        final real = -b / (2 * a);
        final imag = math.sqrt(-disc) / (2 * a).abs();
        setState(() {
          _headline = 'Complex roots';
          _details =
              'Discriminant = ${_fmt(disc)}. Roots: ${_fmt(real)} ± ${_fmt(imag)}i';
        });
        return;
      }

      final sqrtDisc = math.sqrt(disc);
      final x1 = (-b + sqrtDisc) / (2 * a);
      final x2 = (-b - sqrtDisc) / (2 * a);
      setState(() {
        _headline = 'x1 = ${_fmt(x1)}, x2 = ${_fmt(x2)}';
        _details =
            'Used quadratic formula with discriminant ${_fmt(disc)}.';
      });
      return;
    }

    final h = 0.0001;
    final fxh1 = _poly(x0 + h, a, b, c);
    final fxh2 = _poly(x0 - h, a, b, c);
    final derivative = (fxh1 - fxh2) / (2 * h);

    final antiHigh = (a * math.pow(high, 3) / 3) + (b * math.pow(high, 2) / 2) + (c * high);
    final antiLow = (a * math.pow(low, 3) / 3) + (b * math.pow(low, 2) / 2) + (c * low);
    final integral = (antiHigh - antiLow).toDouble();

    setState(() {
      _headline = 'f\'(x0) = ${_fmt(derivative)}';
      _details =
          'For f(x)=ax^2+bx+c at x0=${_fmt(x0)}: derivative ≈ ${_fmt(derivative)}, integral[${_fmt(low)}, ${_fmt(high)}] = ${_fmt(integral)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Equation Solver'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'core'),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: ['Linear', 'Quadratic', 'Calculus']
                        .map(
                          (m) => ChoiceChip(
                            label: Text(m),
                            selected: _mode == m,
                            onSelected: (_) => setState(() => _mode = m),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _mode == 'Linear' ? 'a (ax + b = 0)' : 'a (ax² + bx + c)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _bController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _mode == 'Linear' ? 'b (ax + b = 0)' : 'b (ax² + bx + c)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'c (for quadratic/calculus)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_mode == 'Calculus') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _xController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'x0 for derivative',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _lowController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Integral lower',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _highController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Integral upper',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _solve,
                      icon: const Icon(Icons.auto_graph_rounded),
                      label: const Text('Solve Smartly'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headline,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _details,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MolecularWeightCalculatorScreen extends StatefulWidget {
  const _MolecularWeightCalculatorScreen();

  @override
  State<_MolecularWeightCalculatorScreen> createState() =>
      _MolecularWeightCalculatorScreenState();
}

class _MolecularWeightCalculatorScreenState
    extends State<_MolecularWeightCalculatorScreen> {
  final TextEditingController _formulaController = TextEditingController(
    text: 'C6H12O6',
  );

  String _status = 'Ready';
  String _molarMass = '-';
  List<String> _breakdown = const [];

  static const Map<String, double> _atomicWeights = {
    'H': 1.008,
    'He': 4.0026,
    'Li': 6.94,
    'Be': 9.0122,
    'B': 10.81,
    'C': 12.011,
    'N': 14.007,
    'O': 15.999,
    'F': 18.998,
    'Ne': 20.180,
    'Na': 22.990,
    'Mg': 24.305,
    'Al': 26.982,
    'Si': 28.085,
    'P': 30.974,
    'S': 32.06,
    'Cl': 35.45,
    'K': 39.098,
    'Ar': 39.948,
    'Ca': 40.078,
    'Cr': 51.996,
    'Mn': 54.938,
    'Fe': 55.845,
    'Co': 58.933,
    'Ni': 58.693,
    'Cu': 63.546,
    'Zn': 65.38,
    'Br': 79.904,
    'Ag': 107.868,
    'I': 126.904,
    'Ba': 137.327,
    'Au': 196.967,
    'Hg': 200.592,
    'Pb': 207.2,
  };

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void dispose() {
    _formulaController.dispose();
    super.dispose();
  }

  ({Map<String, int> counts, int index}) _parseGroup(String s, int start) {
    final counts = <String, int>{};
    int i = start;

    int readNumber() {
      final begin = i;
      while (i < s.length && RegExp(r'[0-9]').hasMatch(s[i])) {
        i++;
      }
      if (i == begin) return 1;
      return int.parse(s.substring(begin, i));
    }

    while (i < s.length) {
      final ch = s[i];
      if (ch == '(') {
        final nested = _parseGroup(s, i + 1);
        i = nested.index;
        final mult = readNumber();
        nested.counts.forEach((k, v) {
          counts[k] = (counts[k] ?? 0) + (v * mult);
        });
        continue;
      }

      if (ch == ')') {
        return (counts: counts, index: i + 1);
      }

      if (RegExp(r'[A-Z]').hasMatch(ch)) {
        var symbol = ch;
        i++;
        if (i < s.length && RegExp(r'[a-z]').hasMatch(s[i])) {
          symbol += s[i];
          i++;
        }
        final mult = readNumber();
        counts[symbol] = (counts[symbol] ?? 0) + mult;
        continue;
      }

      i++;
    }

    return (counts: counts, index: i);
  }

  Map<String, int> _parseFormula(String formula) {
    final cleaned = formula.replaceAll('·', '.').replaceAll(' ', '');
    final parts = cleaned.split('.').where((p) => p.isNotEmpty).toList();
    final total = <String, int>{};

    for (final part in parts) {
      var i = 0;
      while (i < part.length && RegExp(r'[0-9]').hasMatch(part[i])) {
        i++;
      }
      final lead = i == 0 ? 1 : int.parse(part.substring(0, i));
      final body = part.substring(i);
      final parsed = _parseGroup(body, 0).counts;
      parsed.forEach((k, v) {
        total[k] = (total[k] ?? 0) + (v * lead);
      });
    }

    return total;
  }

  void _compute() {
    final formula = _formulaController.text.trim();
    if (formula.isEmpty) {
      setState(() {
        _status = 'Enter a formula like H2O, C6H12O6, Ca(OH)2, CuSO4·5H2O';
        _molarMass = '-';
        _breakdown = const [];
      });
      return;
    }

    try {
      final counts = _parseFormula(formula);
      if (counts.isEmpty) {
        setState(() {
          _status = 'Could not parse formula.';
          _molarMass = '-';
          _breakdown = const [];
        });
        return;
      }

      double totalMass = 0;
      final lines = <String>[];
      for (final symbol in counts.keys.toList()..sort()) {
        final count = counts[symbol]!;
        final aw = _atomicWeights[symbol];
        if (aw == null) {
          setState(() {
            _status = 'Unknown element symbol: $symbol';
            _molarMass = '-';
            _breakdown = ['Tip: verify capitalization, e.g., Co vs CO'];
          });
          return;
        }
        final subtotal = aw * count;
        totalMass += subtotal;
        lines.add('$symbol × $count = ${subtotal.toStringAsFixed(4)} g/mol');
      }

      setState(() {
        _status = 'Parsed successfully';
        _molarMass = '${totalMass.toStringAsFixed(4)} g/mol';
        _breakdown = lines;
      });
    } catch (_) {
      setState(() {
        _status = 'Invalid formula syntax';
        _molarMass = '-';
        _breakdown = const [
          'Examples: H2O, NaCl, Ca(OH)2, Al2(SO4)3, CuSO4·5H2O',
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Molecular Weight Calculator'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'learning'),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _formulaController,
                    decoration: const InputDecoration(
                      labelText: 'Chemical Formula',
                      hintText: 'e.g. C6H12O6 or CuSO4·5H2O',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _compute(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _status == 'Parsed successfully'
                                ? IrisTokens.success
                                : (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _compute,
                        icon: const Icon(Icons.science_rounded),
                        label: const Text('Compute'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Molar Mass',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _molarMass,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._breakdown.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: 12,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthToolsScreen extends StatefulWidget {
  final int initialTab;

  const _HealthToolsScreen({this.initialTab = 0});

  @override
  State<_HealthToolsScreen> createState() => _HealthToolsScreenState();
}

class _HealthToolsScreenState extends State<_HealthToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _weightController = TextEditingController(text: '70');
  final TextEditingController _heightController = TextEditingController(text: '170');
  final TextEditingController _waterController = TextEditingController(text: '70');
  final TextEditingController _sysController = TextEditingController(text: '120');
  final TextEditingController _diaController = TextEditingController(text: '80');
  final TextEditingController _elementSearchController = TextEditingController();

  static const List<Map<String, String>> _elements = [
    {'symbol': 'H', 'name': 'Hydrogen', 'number': '1'},
    {'symbol': 'He', 'name': 'Helium', 'number': '2'},
    {'symbol': 'C', 'name': 'Carbon', 'number': '6'},
    {'symbol': 'N', 'name': 'Nitrogen', 'number': '7'},
    {'symbol': 'O', 'name': 'Oxygen', 'number': '8'},
    {'symbol': 'Na', 'name': 'Sodium', 'number': '11'},
    {'symbol': 'Mg', 'name': 'Magnesium', 'number': '12'},
    {'symbol': 'P', 'name': 'Phosphorus', 'number': '15'},
    {'symbol': 'S', 'name': 'Sulfur', 'number': '16'},
    {'symbol': 'Cl', 'name': 'Chlorine', 'number': '17'},
    {'symbol': 'K', 'name': 'Potassium', 'number': '19'},
    {'symbol': 'Ca', 'name': 'Calcium', 'number': '20'},
    {'symbol': 'Fe', 'name': 'Iron', 'number': '26'},
    {'symbol': 'Zn', 'name': 'Zinc', 'number': '30'},
    {'symbol': 'Cu', 'name': 'Copper', 'number': '29'},
    {'symbol': 'I', 'name': 'Iodine', 'number': '53'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _waterController.dispose();
    _sysController.dispose();
    _diaController.dispose();
    _elementSearchController.dispose();
    super.dispose();
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  String _bpCategory(int s, int d) {
    if (s < 120 && d < 80) return 'Normal';
    if (s < 130 && d < 80) return 'Elevated';
    if (s < 140 || d < 90) return 'Stage 1';
    return 'Stage 2';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset =
        MediaQuery.paddingOf(context).top +
        kToolbarHeight +
        kTextTabBarHeight +
        12;
    final w = double.tryParse(_weightController.text) ?? 0;
    final hCm = double.tryParse(_heightController.text) ?? 0;
    final hM = hCm > 0 ? hCm / 100 : 0;
    final bmi = hM > 0 ? w / (hM * hM) : 0;
    final hydration = (double.tryParse(_waterController.text) ?? 0) * 0.033;
    final s = int.tryParse(_sysController.text) ?? 0;
    final d = int.tryParse(_diaController.text) ?? 0;
    final query = _elementSearchController.text.trim().toLowerCase();
    final filtered = _elements.where((e) {
      if (query.isEmpty) return true;
      return e['symbol']!.toLowerCase().contains(query) ||
          e['name']!.toLowerCase().contains(query) ||
          e['number']!.contains(query);
    }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Health Smart Suite'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Calculators'),
            Tab(text: 'Periodic Table'),
          ],
        ),
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'health'),
          TabBarView(
            controller: _tabController,
            children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BMI Assistant', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _heightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('BMI: ${bmi.toStringAsFixed(2)} • ${_bmiCategory(bmi.toDouble())}', style: const TextStyle(fontWeight: FontWeight.w700, color: IrisTokens.brand)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hydration Estimator', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _waterController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Body Weight (kg)', border: OutlineInputBorder()),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text('Daily water target: ${hydration.toStringAsFixed(2)} L', style: const TextStyle(fontWeight: FontWeight.w700, color: IrisTokens.success)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vitals Check (BP)', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _sysController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Systolic', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _diaController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Diastolic', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('BP category: ${_bpCategory(s, d)}', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _elementSearchController,
                        decoration: const InputDecoration(
                          labelText: 'Search element by name/symbol/number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      Text('${filtered.length} elements found', style: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...filtered.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: IrisTokens.brand.withValues(alpha: 0.2),
                        child: Text(e['symbol']!, style: const TextStyle(fontWeight: FontWeight.w800, color: IrisTokens.brand)),
                      ),
                      title: Text(e['name']!),
                      subtitle: Text('Atomic Number: ${e['number']}'),
                    ),
                  ),
                ),
              ),
            ],
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResistorColorDecoderScreen extends StatefulWidget {
  const _ResistorColorDecoderScreen();

  @override
  State<_ResistorColorDecoderScreen> createState() =>
      _ResistorColorDecoderScreenState();
}

class _ResistorColorDecoderScreenState extends State<_ResistorColorDecoderScreen> {
  String _band1 = 'Brown';
  String _band2 = 'Black';
  String _multiplier = 'Red';
  String _tolerance = 'Gold';

  static const Map<String, int> _digitMap = {
    'Black': 0,
    'Brown': 1,
    'Red': 2,
    'Orange': 3,
    'Yellow': 4,
    'Green': 5,
    'Blue': 6,
    'Violet': 7,
    'Gray': 8,
    'White': 9,
  };

  static const Map<String, int> _multiplierExp = {
    'Black': 0,
    'Brown': 1,
    'Red': 2,
    'Orange': 3,
    'Yellow': 4,
    'Green': 5,
    'Blue': 6,
    'Violet': 7,
    'Gray': 8,
    'White': 9,
    'Gold': -1,
    'Silver': -2,
  };

  static const Map<String, double> _toleranceMap = {
    'Brown': 1.0,
    'Red': 2.0,
    'Green': 0.5,
    'Blue': 0.25,
    'Violet': 0.1,
    'Gray': 0.05,
    'Gold': 5.0,
    'Silver': 10.0,
  };

  static const Map<String, Color> _colorMap = {
    'Black': Colors.black,
    'Brown': Color(0xFF8D6E63),
    'Red': Color(0xFFE53935),
    'Orange': Color(0xFFFB8C00),
    'Yellow': Color(0xFFFDD835),
    'Green': Color(0xFF43A047),
    'Blue': Color(0xFF1E88E5),
    'Violet': Color(0xFF8E24AA),
    'Gray': Color(0xFF9E9E9E),
    'White': Color(0xFFF5F5F5),
    'Gold': Color(0xFFFFC107),
    'Silver': Color(0xFFB0BEC5),
  };

  double _resistance() {
    final first = _digitMap[_band1] ?? 0;
    final second = _digitMap[_band2] ?? 0;
    final base = (first * 10) + second;
    final exp = _multiplierExp[_multiplier] ?? 0;
    return (base * math.pow(10, exp)).toDouble();
  }

  String _formatOhms(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)} MΩ';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)} kΩ';
    }
    return '${value.toStringAsFixed(2)} Ω';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final value = _resistance();
    final tol = _toleranceMap[_tolerance] ?? 5.0;
    final min = value * (1 - tol / 100);
    final max = value * (1 + tol / 100);

    Widget bandDropdown(
      String title,
      String current,
      List<String> options,
      ValueChanged<String> onChanged,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: current,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: options
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _colorMap[c],
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(c),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Resistor Color Decoder'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'engineering'),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: bandDropdown(
                          'Band 1',
                          _band1,
                          _digitMap.keys.toList(),
                          (v) => setState(() => _band1 = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: bandDropdown(
                          'Band 2',
                          _band2,
                          _digitMap.keys.toList(),
                          (v) => setState(() => _band2 = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: bandDropdown(
                          'Multiplier',
                          _multiplier,
                          _multiplierExp.keys.toList(),
                          (v) => setState(() => _multiplier = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: bandDropdown(
                          'Tolerance',
                          _tolerance,
                          _toleranceMap.keys.toList(),
                          (v) => setState(() => _tolerance = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatOhms(value),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tolerance: ±${tol.toStringAsFixed(2)}%'
                    '  •  Range: ${_formatOhms(min)} to ${_formatOhms(max)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Smart tip: Read from the side with the tolerance band (usually gold/silver).',
                    style: TextStyle(fontSize: 12, color: IrisTokens.brand),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DepartmentSmartKitScreen extends StatefulWidget {
  final String department;
  final OmniBrain brain;
  final String batch;

  const _DepartmentSmartKitScreen({
    required this.department,
    required this.brain,
    required this.batch,
  });

  @override
  State<_DepartmentSmartKitScreen> createState() =>
      _DepartmentSmartKitScreenState();
}

class _DepartmentSmartKitScreenState extends State<_DepartmentSmartKitScreen> {
  final TextEditingController _assignmentsController =
      TextEditingController(text: '2');
  final TextEditingController _quizzesController =
      TextEditingController(text: '1');
  final TextEditingController _labsController = TextEditingController(text: '1');
  final TextEditingController _prepHoursController =
      TextEditingController(text: '8');

  final TextEditingController _currentScoreController =
      TextEditingController(text: '72');
  final TextEditingController _targetScoreController =
      TextEditingController(text: '85');
  final TextEditingController _remainingWeightController =
      TextEditingController(text: '40');

  @override
  void dispose() {
    _assignmentsController.dispose();
    _quizzesController.dispose();
    _labsController.dispose();
    _prepHoursController.dispose();
    _currentScoreController.dispose();
    _targetScoreController.dispose();
    _remainingWeightController.dispose();
    super.dispose();
  }

  double _parseNum(String value) => double.tryParse(value.trim()) ?? 0;

  ({double score, String band}) _workloadScore() {
    final assignments = _parseNum(_assignmentsController.text);
    final quizzes = _parseNum(_quizzesController.text);
    final labs = _parseNum(_labsController.text);
    final prepHours = _parseNum(_prepHoursController.text);
    final score = (assignments * 2.0) +
        (quizzes * 3.0) +
        (labs * 4.0) +
        (prepHours * 0.5);
    if (score >= 26) {
      return (score: score, band: 'High intensity week');
    }
    if (score >= 16) {
      return (score: score, band: 'Balanced workload');
    }
    return (score: score, band: 'Light workload window');
  }

  ({double required, bool impossible}) _targetPlanner() {
    final current = _parseNum(_currentScoreController.text).clamp(0, 100);
    final target = _parseNum(_targetScoreController.text).clamp(0, 100);
    final remainingWeight =
        (_parseNum(_remainingWeightController.text).clamp(1, 100)) / 100.0;
    final completedWeight = 1.0 - remainingWeight;
    final required = (target - (current * completedWeight)) / remainingWeight;
    return (required: required, impossible: required > 100);
  }

  List<String> _departmentTips(String department) {
    final d = department.toLowerCase();
    if (d.contains('civil')) {
      return const [
        'Prioritize surveying and design studio deliverables early.',
        'Batch numericals by topic to reduce context switching.',
        'Reserve one long block for CAD/BIM practice each week.',
      ];
    }
    if (d.contains('chem')) {
      return const [
        'Group reaction-mechanism practice with formula review.',
        'Use short spaced sessions for nomenclature retention.',
        'Keep one weekly block for lab prep and report templates.',
      ];
    }
    if (d.contains('eco') || d.contains('account') || d.contains('finance')) {
      return const [
        'Split theory revision and numerical practice into separate blocks.',
        'Use one-day lag review after every major lecture.',
        'Track trend questions for faster exam pattern recognition.',
      ];
    }
    return const [
      'Use 45-10 focused cycles for heavy concept days.',
      'Front-load assignments before quiz windows to reduce overlap stress.',
      'Keep one recap block to compress week-long notes into 1-page summaries.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final now = DateTime.now();
    final current = widget.brain.getCurrentClass(widget.batch, now);
    final next = widget.brain.getNextClass(widget.batch, now);
    final workload = _workloadScore();
    final targetPlan = _targetPlanner();
    final tips = _departmentTips(widget.department);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Department Smart Kit'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'analytics'),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
              GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.department.toUpperCase()} adaptive assistant',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    current != null
                        ? 'Live now: ${current.subject}'
                        : next != null
                        ? 'Next class: ${next.subject}'
                        : 'No class right now. Good time to plan your week.',
                    style: TextStyle(
                      fontSize: 13,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Workload Estimator',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _numField('Assignments', _assignmentsController),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _numField('Quizzes', _quizzesController)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _numField('Labs', _labsController)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numField('Prep Hours', _prepHoursController),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Load score: ${workload.score.toStringAsFixed(1)} • ${workload.band}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: IrisTokens.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target Grade Planner',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _numField('Current %', _currentScoreController),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numField('Target %', _targetScoreController),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _numField('Remaining Weight %', _remainingWeightController),
                  const SizedBox(height: 12),
                  Text(
                    targetPlan.impossible
                        ? 'Required in remaining assessments: ${targetPlan.required.toStringAsFixed(1)}% (above 100%, adjust target or strategy).'
                        : 'Required in remaining assessments: ${targetPlan.required.clamp(0, 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: IrisTokens.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Department Smart Tips',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (final tip in tips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '• $tip',
                        style: TextStyle(
                          fontSize: 13,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _PrintTimetableScreen extends StatefulWidget {
  final OmniBrain brain;
  final String batch;

  const _PrintTimetableScreen({
    required this.brain,
    required this.batch,
  });

  @override
  State<_PrintTimetableScreen> createState() => _PrintTimetableScreenState();
}

class _PrintTimetableScreenState extends State<_PrintTimetableScreen> {
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    // Automatically generate and print the PDF
    _generateAndPrintPdf();
  }

  Future<void> _generateAndPrintPdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final schedule = widget.brain.scheduleFor(widget.batch);
      final dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];

      // Group sessions by day
      final grouped = <int, List<ClassSession>>{};
      for (final session in schedule) {
        grouped.putIfAbsent(session.dayIndex, () => []).add(session);
      }
      for (final day in grouped.values) {
        day.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));
      }

      // Create PDF document
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;

      // Add title
      graphics.drawString(
        'IRIS Timetable',
        PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold),
        bounds: const Rect.fromLTWH(20, 20, 500, 40),
        brush: PdfSolidBrush(PdfColor(0, 122, 255)),
      );

      // Add batch info
      graphics.drawString(
        'Batch: ${widget.batch}',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(20, 70, 500, 20),
      );

      // Create table
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 4);

      // Add headers
      final PdfGridRow headerRow = grid.rows.add();
      headerRow.cells[0].value = 'Time';
      headerRow.cells[1].value = 'Subject';
      headerRow.cells[2].value = 'Teacher';
      headerRow.cells[3].value = 'Room';

      // Style header
      for (int i = 0; i < 4; i++) {
        headerRow.cells[i].style = PdfGridCellStyle(
          backgroundBrush: PdfSolidBrush(PdfColor(0, 122, 255)),
          textBrush: PdfSolidBrush(PdfColor(255, 255, 255)),
          font: PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
        );
      }

      // Add data rows
      for (int dayIndex = 1; dayIndex <= 7; dayIndex++) {
        if (grouped.containsKey(dayIndex)) {
          // Add day header row
          final dayRow = grid.rows.add();
          dayRow.cells[0].value = '${dayNames[dayIndex - 1]} Schedule';
          dayRow.cells[0].columnSpan = 4;
          dayRow.cells[0].style = PdfGridCellStyle(
            backgroundBrush: PdfSolidBrush(PdfColor(230, 230, 230)),
            font: PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
          );

          // Add sessions
          for (final session in grouped[dayIndex]!) {
            final row = grid.rows.add();
            row.cells[0].value = '${session.startTime} – ${session.endTime}';
            row.cells[1].value = session.subject;
            row.cells[2].value = session.teacher;
            row.cells[3].value = session.room;
          }
        }
      }

      // Draw table on page
      grid.draw(page: page, bounds: Rect.fromLTWH(20, 110, 550, 500));

      // Save to temporary file
      final bytes = await document.save();
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/iris_timetable_${widget.batch}.pdf');
      await file.writeAsBytes(bytes);
      document.dispose();

      // Open print dialog
      if (!mounted) return;

      // Use native Android printing via method channel
      const platform = MethodChannel('iris/print');
      try {
        await platform.invokeMethod('printPdf', {
          'filePath': file.path,
          'jobName': 'IRIS Timetable - ${widget.batch}',
        });
      } catch (e) {
        debugPrint('Print failed: $e');
        // Fallback: share the PDF
        if (mounted) {
          _showPrintFallback(file);
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('PDF generation error: $e');
      setState(() => _isGeneratingPdf = false);
      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          dedupeKey: 'pdf_generation_error',
          content: Text('Error generating PDF: $e'),
          tint: IrisTokens.error,
        );
      }
    }
  }

  void _showPrintFallback(File file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1AFFFFFF) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: IrisTokens.brandGradient),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.print_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'PDF Ready',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your timetable PDF is ready. Open it to print using your device printer.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.7,
                  ),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await OpenFilex.open(file.path);
                        if (mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.brand,
                      ),
                      child: const Text('Open PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Print Timetable'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'analytics'),
          Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Center(
              child: _isGeneratingPdf
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0x1AFFFFFF)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    IrisTokens.brand,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Generating PDF...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your timetable is being prepared for printing',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: IrisTokens.brandGradient,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 60,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'PDF Ready',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Your timetable PDF has been generated and opened in your printer.',
                              style: TextStyle(
                                fontSize: 15,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.7),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: IrisTokens.brand,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineFormulaLibraryScreen extends StatefulWidget {
  const _OfflineFormulaLibraryScreen();

  @override
  State<_OfflineFormulaLibraryScreen> createState() =>
      _OfflineFormulaLibraryScreenState();
}

class _OfflineFormulaLibraryScreenState
    extends State<_OfflineFormulaLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _category = 'All';

  static const List<String> _categories = [
    'All',
    'Thermodynamics',
    'Circuits',
    'Mechanics',
    'Constants',
  ];

  static final List<_FormulaEntry> _entries = [
    _FormulaEntry(
      category: 'Thermodynamics',
      title: 'First Law',
      formula: 'ΔU = Q - W',
      description: 'Change in internal energy equals heat added minus work done.',
    ),
    _FormulaEntry(
      category: 'Thermodynamics',
      title: 'Ideal Gas Law',
      formula: 'PV = nRT',
      description: 'Pressure-volume relationship for ideal gases.',
    ),
    _FormulaEntry(
      category: 'Circuits',
      title: 'Ohm\'s Law',
      formula: 'V = I R',
      description: 'Voltage equals current multiplied by resistance.',
    ),
    _FormulaEntry(
      category: 'Circuits',
      title: 'Electric Power',
      formula: 'P = V I = I²R = V²/R',
      description: 'Equivalent forms of electrical power.',
    ),
    _FormulaEntry(
      category: 'Mechanics',
      title: 'Newton Second Law',
      formula: 'F = m a',
      description: 'Force equals mass times acceleration.',
    ),
    _FormulaEntry(
      category: 'Mechanics',
      title: 'Kinetic Energy',
      formula: 'KE = 1/2 m v²',
      description: 'Energy due to motion.',
    ),
    _FormulaEntry(
      category: 'Constants',
      title: 'Gas Constant',
      formula: 'R = 8.314 J/(mol·K)',
      description: 'Universal gas constant.',
    ),
    _FormulaEntry(
      category: 'Constants',
      title: 'Gravitational Acceleration',
      formula: 'g = 9.81 m/s²',
      description: 'Standard gravity near Earth surface.',
    ),
    _FormulaEntry(
      category: 'Constants',
      title: 'Speed of Light',
      formula: 'c = 2.998 × 10^8 m/s',
      description: 'Light speed in vacuum.',
    ),
  ];

  List<_FormulaEntry> _filtered() {
    final q = _searchController.text.trim().toLowerCase();
    return _entries.where((e) {
      final catMatch = _category == 'All' || e.category == _category;
      if (!catMatch) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          e.formula.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final entries = _filtered();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Formula Library & Constants'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'learning'),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search formula, symbol, topic',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories
                        .map(
                          (c) => ChoiceChip(
                            label: Text(c),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${entries.length} references available offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        e.formula,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: IrisTokens.brand,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.description,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgrammingToolsScreen extends StatefulWidget {
  const _ProgrammingToolsScreen();

  @override
  State<_ProgrammingToolsScreen> createState() => _ProgrammingToolsScreenState();
}

class _ProgrammingToolsScreenState extends State<_ProgrammingToolsScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _dryRunInputController = TextEditingController(
    text: '5, 1, 4, 2, 8',
  );

  String _language = 'Dart';
  String _status = 'Ready';
  String _summary = 'Pick a language and run Smart Check.';
  List<String> _warnings = const [];
  int _complexityScore = 0;
  String _accessoryMode = 'Snippet Vault';
  String _accessoryOutput = 'Pick an accessory mode and generate output.';

  static const Map<String, String> _templates = {
    'Dart': 'void main() {\n  print("Hello IRIS");\n}\n',
    'Python': 'def main():\n    print("Hello IRIS")\n\nif __name__ == "__main__":\n    main()\n',
    'C++': '#include <iostream>\nusing namespace std;\n\nint main() {\n  cout << "Hello IRIS" << endl;\n  return 0;\n}\n',
    'Java': 'public class Main {\n  public static void main(String[] args) {\n    System.out.println("Hello IRIS");\n  }\n}\n',
  };

  static const Map<String, String> _algorithmTemplates = {
    'Binary Search':
        'while (low <= high) {\n  int mid = low + (high - low) / 2;\n  if (arr[mid] == target) return mid;\n  if (arr[mid] < target) low = mid + 1;\n  else high = mid - 1;\n}\nreturn -1;',
    'DFS (Recursive)':
        'void dfs(int node) {\n  visited[node] = true;\n  for (final nxt in graph[node]) {\n    if (!visited[nxt]) dfs(nxt);\n  }\n}',
    'BFS':
        'final q = Queue<int>();\nq.add(start);\nvisited[start] = true;\nwhile (q.isNotEmpty) {\n  final u = q.removeFirst();\n  for (final v in graph[u]) {\n    if (!visited[v]) {\n      visited[v] = true;\n      q.add(v);\n    }\n  }\n}',
  };

  @override
  void initState() {
    super.initState();
    _codeController.text = _templates[_language]!;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _dryRunInputController.dispose();
    super.dispose();
  }

  bool _bracketsBalanced(String input) {
    final stack = <String>[];
    final opens = {'(': ')', '{': '}', '[': ']'};
    final closes = {')', '}', ']'};
    for (final ch in input.split('')) {
      if (opens.containsKey(ch)) {
        stack.add(ch);
      } else if (closes.contains(ch)) {
        if (stack.isEmpty) return false;
        final last = stack.removeLast();
        if (opens[last] != ch) return false;
      }
    }
    return stack.isEmpty;
  }

  int _complexityHeuristic(String input) {
    final lower = input.toLowerCase();
    final patterns = [
      RegExp(r'\bif\b'),
      RegExp(r'\bfor\b'),
      RegExp(r'\bwhile\b'),
      RegExp(r'\bswitch\b'),
      RegExp(r'\bcase\b'),
      RegExp(r'\bcatch\b'),
      RegExp(r'&&|\|\|'),
      RegExp(r'\?'),
    ];
    var score = 1;
    for (final p in patterns) {
      score += p.allMatches(lower).length;
    }
    return score;
  }

  void _loadTemplate() {
    setState(() {
      _codeController.text = _templates[_language]!;
      _status = 'Template loaded';
      _summary = 'Press Smart Check to analyze this $_language snippet.';
      _warnings = const [];
      _complexityScore = 0;
    });
  }

  void _smartCheck() {
    final code = _codeController.text;
    final warnings = <String>[];
    final lineCount = '\n'.allMatches(code).length + 1;
    final hasBalanced = _bracketsBalanced(code);

    if (!hasBalanced) {
      warnings.add('Unbalanced brackets detected.');
    }

    if (_language == 'Python' && code.contains('{') && code.contains('}')) {
      warnings.add('Python style warning: avoid braces for blocks.');
    }

    if ((_language == 'Java' || _language == 'C++' || _language == 'Dart') &&
        code.contains('print(') &&
        !code.contains(';')) {
      warnings.add('Possible missing semicolon in print statement.');
    }

    if (code.trim().isEmpty) {
      warnings.add('Code is empty.');
    }

    final complexity = _complexityHeuristic(code);
    final status = warnings.isEmpty ? 'Smart Check Passed' : 'Needs Attention';
    final summary =
        'Language: $_language • Lines: $lineCount • Complexity: $complexity';

    setState(() {
      _status = status;
      _summary = summary;
      _warnings = warnings;
      _complexityScore = complexity;
    });
  }

  void _runAccessory() {
    if (_accessoryMode == 'Snippet Vault') {
      final items = _algorithmTemplates.entries
          .map((e) => '${e.key}:\n${e.value}')
          .join('\n\n');
      setState(() {
        _accessoryOutput = 'Top Snippets:\n\n$items';
      });
      return;
    }

    if (_accessoryMode == 'Algorithm Templates') {
      final bestFit = _complexityScore > 6
          ? 'BFS / DFS with visited set'
          : 'Binary Search / Two Pointers';
      setState(() {
        _accessoryOutput =
            'Suggested template family: $bestFit\n\nTip: choose based on data shape and constraints.';
      });
      return;
    }

    final raw = _dryRunInputController.text
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
    if (raw.isEmpty) {
      setState(() {
        _accessoryOutput = 'Dry-run helper needs comma-separated integers.';
      });
      return;
    }

    final sorted = List<int>.from(raw)..sort();
    final minV = sorted.first;
    final maxV = sorted.last;
    final avg = sorted.reduce((a, b) => a + b) / sorted.length;

    setState(() {
      _accessoryOutput =
          'Dry-run Snapshot\nInput: $raw\nSorted: $sorted\nMin: $minV, Max: $maxV, Avg: ${avg.toStringAsFixed(2)}\n\nUse this as a quick sanity-check before coding.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('CS Compiler Suite'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'cs'),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _language,
                          decoration: const InputDecoration(
                            labelText: 'Language',
                            border: OutlineInputBorder(),
                          ),
                          items: _templates.keys
                              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _language = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _loadTemplate,
                        child: const Text('Load'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeController,
                    minLines: 10,
                    maxLines: 16,
                    decoration: const InputDecoration(
                      labelText: 'Code Editor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _smartCheck,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Smart Check'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _warnings.isEmpty
                          ? IrisTokens.success
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _summary,
                    style: TextStyle(
                      fontSize: 13,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complexity Score: $_complexityScore',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: IrisTokens.brand,
                    ),
                  ),
                  if (_warnings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._warnings.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $w',
                          style: const TextStyle(
                            fontSize: 12,
                            color: IrisTokens.warning,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compiler Suite Accessories',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Snippet Vault', 'Algorithm Templates', 'Dry-run Helper']
                        .map(
                          (m) => ChoiceChip(
                            label: Text(m),
                            selected: _accessoryMode == m,
                            onSelected: (_) => setState(() => _accessoryMode = m),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  if (_accessoryMode == 'Dry-run Helper')
                    TextField(
                      controller: _dryRunInputController,
                      decoration: const InputDecoration(
                        labelText: 'Sample numbers (comma-separated)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _runAccessory,
                      icon: const Icon(Icons.build_rounded),
                      label: const Text('Generate Smart Output'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _accessoryOutput,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormulaEntry {
  final String category;
  final String title;
  final String formula;
  final String description;

  const _FormulaEntry({
    required this.category,
    required this.title,
    required this.formula,
    required this.description,
  });
}


class _WordCounterScreenState extends State<_WordCounterScreen> {
  final TextEditingController _controller = TextEditingController();

  int get _characters => _controller.text.length;
  int get _charactersNoSpaces => _controller.text.replaceAll(' ', '').length;

  int get _words {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  int get _sentences {
    final matches = RegExp(r'[.!?]+').allMatches(_controller.text);
    return matches.length;
  }

  int get _paragraphs {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .length;
  }

  int get _readMinutes {
    if (_words == 0) return 0;
    return (_words / 220).ceil();
  }

  int get _speakMinutes {
    if (_words == 0) return 0;
    return (_words / 140).ceil();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Word Counter'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'core'),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _controller,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: 'Paste or write your text here...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(label: 'Words', value: '$_words'),
              _MetricChip(label: 'Characters', value: '$_characters'),
              _MetricChip(label: 'No Spaces', value: '$_charactersNoSpaces'),
              _MetricChip(label: 'Sentences', value: '$_sentences'),
              _MetricChip(label: 'Paragraphs', value: '$_paragraphs'),
              _MetricChip(label: 'Read Time', value: '${_readMinutes}m'),
              _MetricChip(label: 'Speak Time', value: '${_speakMinutes}m'),
            ],
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.68,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassAnalyticsScreen extends StatelessWidget {
  final OmniBrain brain;
  final String batch;

  const _ClassAnalyticsScreen({required this.brain, required this.batch});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final sessions = brain.scheduleFor(batch);
    final dayMap = <int, int>{};
    final roomMap = <String, int>{};

    for (final s in sessions) {
      dayMap[s.dayIndex] = (dayMap[s.dayIndex] ?? 0) + 1;
      roomMap[s.room] = (roomMap[s.room] ?? 0) + 1;
    }

    final busiestDay = dayMap.entries.isEmpty
        ? null
        : dayMap.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final topRoom = roomMap.entries.isEmpty
        ? null
        : roomMap.entries.reduce((a, b) => a.value >= b.value ? a : b);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Class Analytics'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark, tone: 'analytics'),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 28),
            children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricChip(label: 'Total Sessions', value: '${sessions.length}'),
                  _MetricChip(label: 'Unique Rooms', value: '${roomMap.keys.length}'),
                  _MetricChip(label: 'Busiest Day', value: busiestDay == null ? '-' : FormatGuard.normalizeDay(busiestDay.key)),
                  _MetricChip(label: 'Top Room', value: topRoom?.key ?? '-'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (dayMap.isNotEmpty)
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sessions by Day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...(() {
                      final sorted = dayMap.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key));
                      return sorted
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      FormatGuard.normalizeDay(entry.key),
                                    ),
                                  ),
                                  Text('${entry.value}'),
                                ],
                              ),
                            ),
                          )
                          .toList();
                    })(),
                  ],
                ),
              ),
            ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CgpaCalculatorScreen extends StatefulWidget {
  const _CgpaCalculatorScreen();

  @override
  State<_CgpaCalculatorScreen> createState() => _CgpaCalculatorScreenState();
}

class _CgpaCalculatorScreenState extends State<_CgpaCalculatorScreen> {
  final List<_CgpaCourseRow> _rows = [
    _CgpaCourseRow(),
    _CgpaCourseRow(),
    _CgpaCourseRow(),
  ];

  double _semesterGpa = 0.0;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _recalculate() {
    double qualityPoints = 0;
    double totalCredits = 0;

    for (final row in _rows) {
      final credits = double.tryParse(row.creditsController.text) ?? 0;
      if (credits <= 0) {
        continue;
      }
      qualityPoints += credits * row.gradePoint;
      totalCredits += credits;
    }

    setState(() {
      _semesterGpa = totalCredits > 0 ? qualityPoints / totalCredits : 0.0;
    });
  }

  void _addRow() {
    setState(() {
      _rows.add(_CgpaCourseRow());
    });
    _recalculate();
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
    _recalculate();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('CGPA Calculator'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // Neural aura background
          _NeuralAura(background: isDark, tone: 'learning'),
          ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
          20,
          36,
        ),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: IrisTokens.brand.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: IrisTokens.brand,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Semester GPA',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.68),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _semesterGpa.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Add your courses below',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.72,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(_rows.length, (index) {
            final row = _rows[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CgpaRowCard(
                index: index,
                row: row,
                onChanged: _recalculate,
                onDelete: () => _removeRow(index),
              ),
            );
          }),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Course'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _recalculate,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Recalculate'),
                ),
              ),
            ],
          ),
        ],
      ),
        ],
      ),
    );
  }
}

class _CgpaCourseRow {
  _CgpaCourseRow();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController creditsController = TextEditingController();
  String grade = 'A';

  static const Map<String, double> _gradePoints = {
    'A': 4.0,
    'A-': 3.67,
    'B+': 3.33,
    'B': 3.00,
    'B-': 2.67,
    'C+': 2.33,
    'C': 2.00,
    'C-': 1.67,
    'D+': 1.33,
    'D': 1.00,
    'F': 0.0,
  };

  double get gradePoint => _gradePoints[grade] ?? 0.0;

  List<String> get gradeOptions => _gradePoints.keys.toList();

  void dispose() {
    nameController.dispose();
    creditsController.dispose();
  }
}

class _CgpaRowCard extends StatelessWidget {
  final int index;
  final _CgpaCourseRow row;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _CgpaRowCard({
    required this.index,
    required this.row,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Course ${index + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: row.nameController,
              decoration: const InputDecoration(
                labelText: 'Course Name (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.creditsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Credit Hours',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: row.grade,
                    decoration: const InputDecoration(
                      labelText: 'Grade',
                      border: OutlineInputBorder(),
                    ),
                    items: row.gradeOptions
                        .map(
                          (g) => DropdownMenuItem<String>(
                            value: g,
                            child: Text('$g (${_CgpaCourseRow._gradePoints[g]})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      row.grade = value;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String description;

  _ToolItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class _ToolCard extends StatelessWidget {
  final _ToolItem tool;
  final bool isDark;
  final VoidCallback onTap;
  final bool compact;

  const _ToolCard({
    required this.tool,
    required this.isDark,
    required this.onTap,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tool.color.withValues(alpha: isDark ? 0.18 : 0.12),
              tool.color.withValues(alpha: isDark ? 0.08 : 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: tool.color.withValues(alpha: isDark ? 0.2 : 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: tool.color.withValues(alpha: isDark ? 0.1 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: tool.color.withValues(alpha: 0.1),
            highlightColor: tool.color.withValues(alpha: 0.05),
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tool.color.withValues(alpha: isDark ? 0.3 : 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tool.color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(tool.icon, color: tool.color, size: 22),
                  ),
                  SizedBox(height: compact ? 10 : 12),
                  Text(
                    tool.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tool.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.62,
                      ),
                      height: 1.25,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 8),
                    Text(
                      tool.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: (isDark ? Colors.white : Colors.black).withValues(
                          alpha: 0.55,
                        ),
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AboutScreen extends StatefulWidget {
  final ValueChanged<String>? onRoleChanged;
  final Future<void> Function(String mode)? onSetThemeMode;
  final String? currentThemeMode;
  final bool showDock;
  final bool showCloseButton;

  const AboutScreen({
    this.onRoleChanged,
    this.onSetThemeMode,
    this.currentThemeMode,
    this.showDock = true,
    this.showCloseButton = true,
    super.key,
  });

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Timer? _revealTimer;
  bool _revealQuote = false;
  int _tapCount = 0;
  bool _isChangingAppearance = false;
  bool _persistentNotificationEnabled = false;
  bool _lectureRemindersEnabled = false;
  bool _uiSoundsEnabled = true;
  bool _uiHapticsEnabled = true;
  bool _widgetDarkMode = false;
  String _feedbackProfile = 'balanced';
  String _appearanceMode = 'system'; // 'system', 'light', 'dark'
  Map<String, dynamic>? _otaStatus;
  bool _isRefreshing = false;
  bool _isSwitchingRole = false;
  String _userRole = 'student';
  bool _showChangeLog = false;

  @override
  void initState() {
    super.initState();
    _appearanceMode = widget.currentThemeMode ?? _appearanceMode;
    _loadNotificationSetting();
    _loadLectureReminderSetting();
    _loadUiSoundsSetting();
    _loadUiHapticsSetting();
    _loadFeedbackProfile();
    _loadWidgetDarkModeSetting();
    _loadOTAStatus();
    _loadUserRole();
    if (widget.currentThemeMode == null) {
      _loadAppearanceMode();
    }
  }

  @override
  void didUpdateWidget(covariant AboutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incomingMode = widget.currentThemeMode;
    if (incomingMode != null && incomingMode != _appearanceMode) {
      setState(() {
        _appearanceMode = incomingMode;
      });
    }
  }

  Future<void> _loadAppearanceMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode =
        prefs.getString('themeMode') ??
        prefs.getString('appearance_mode') ??
        'system';
    if (!mounted) return;
    setState(() {
      _appearanceMode = mode;
    });
  }

  Future<void> _setAppearanceMode(String mode) async {
    if (_appearanceMode == mode || _isChangingAppearance) return;
    if (mounted) {
      setState(() {
        _appearanceMode = mode;
        _isChangingAppearance = true;
      });
    }
    IrisHaptics.chipSelect();

    try {
      if (widget.onSetThemeMode != null) {
        await widget.onSetThemeMode!(mode);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('themeMode', mode);
        await prefs.setString('appearance_mode', mode);
      }
      await Future.delayed(const Duration(milliseconds: 160));
    } finally {
      if (mounted) {
        setState(() {
          _isChangingAppearance = false;
        });
      }
    }
  }

  Future<void> _handleBackNavigation() async {
    if (_isChangingAppearance) {
      await Future.delayed(const Duration(milliseconds: 180));
    }
    if (!mounted) return;

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role') ?? 'student';
    });
  }

  Future<void> _setUserRole(String role) async {
    if (_userRole == role || _isSwitchingRole) return;
    if (mounted) {
      setState(() {
        _isSwitchingRole = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);
      if (role == 'faculty' && await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }
      widget.onRoleChanged?.call(role);
      IrisHaptics.chipSelect();

      // Close stacked routes opened via navbar to avoid transient role/UI desync.
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 80));
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingRole = false;
        });
      }
    }
  }

  Future<void> _loadOTAStatus() async {
    final status = await TimetableOTAService.getUpdateStatus();
    if (mounted) {
      setState(() {
        _otaStatus = status;
      });
    }
  }

  Future<void> _refreshOTA() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    IrisHaptics.actionMedium();

    final refreshResult = await TimetableOTAService.forceRefresh();

    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });

      if (refreshResult > 0) {
        IrisHaptics.actionHeavy();
        showIrisFrostedSnackBar(
          context,
          dedupeKey: 'ota_refresh_updated',
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('✅ Timetable updated! Refreshing...'),
            ],
          ),
          tint: IrisTokens.success,
          duration: const Duration(seconds: 3),
        );

        // Wait briefly, then pop back to Dashboard which will auto-reload timetable
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        IrisHaptics.actionSoft();
        showIrisFrostedSnackBar(
          context,
          dedupeKey: 'ota_refresh_no_update',
          content: Row(
            children: const [
              Icon(Icons.info_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Already up-to-date or network unavailable'),
              ),
            ],
          ),
          tint: IrisTokens.brand,
        );
        await _loadOTAStatus();
      }
    }
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _persistentNotificationEnabled =
          prefs.getBool('persistent_notification_enabled') ?? false;
    });
  }

  Future<void> _loadWidgetDarkModeSetting() async {
    final isDark = await WidgetService.getWidgetDarkMode();
    setState(() {
      _widgetDarkMode = isDark;
    });
  }

  Future<void> _loadLectureReminderSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lectureRemindersEnabled =
          prefs.getBool('lecture_reminders_enabled') ?? false;
    });
  }

  Future<void> _loadUiSoundsSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _uiSoundsEnabled = prefs.getBool('ui_sounds_enabled') ?? true;
    });
  }

  Future<void> _loadUiHapticsSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _uiHapticsEnabled = prefs.getBool('ui_haptics_enabled') ?? true;
    });
  }

  Future<void> _loadFeedbackProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _feedbackProfile = prefs.getString('ui_feedback_profile') ?? 'balanced';
    });
  }

  Future<void> _togglePersistentNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'student';
    final teacher = prefs.getString('faculty_teacher');
    if (role == 'faculty' && value && (teacher == null || teacher.isEmpty)) {
      if (mounted) {
        showIrisFrostedSnackBar(
          context,
          dedupeKey: 'settings_faculty_tracking_requires_teacher',
          content: Row(
            children: const [
              Icon(Icons.info_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select your name first to enable faculty tracking',
                ),
              ),
            ],
          ),
          tint: IrisTokens.brand,
        );
      }
      return;
    }
    await prefs.setBool('persistent_notification_enabled', value);
    setState(() {
      _persistentNotificationEnabled = value;
    });

    if (!value) {
      // Stop foreground service when disabled
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } else {
      // Start foreground service when enabled
      if (!(await FlutterForegroundTask.isRunningService)) {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: role == 'faculty'
              ? 'IRIS Faculty Tracker'
              : 'IRIS Class Tracker',
          notificationText: 'Keeping your class schedule handy',
          notificationIcon: null,
          notificationButtons: [
            NotificationButton(id: 'open', text: 'Open IRIS'),
          ],
          callback: startClassNotificationTask,
        );
      }
    }

    IrisHaptics.chipSelect();
  }

  Future<void> _toggleWidgetDarkMode(bool value) async {
    await WidgetService.setWidgetDarkMode(value);
    setState(() {
      _widgetDarkMode = value;
    });
    IrisHaptics.chipSelect();
  }

  Future<void> _toggleLectureReminders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lecture_reminders_enabled', value);
    setState(() {
      _lectureRemindersEnabled = value;
    });

    if (value) {
      await NotificationService().syncClassRemindersFromPrefs();
    } else {
      await NotificationService().cancelScheduledClassReminders();
    }

    IrisHaptics.chipSelect();
  }

  Future<void> _toggleUiSounds(bool value) async {
    await IrisSfx.setEnabled(value);
    setState(() {
      _uiSoundsEnabled = value;
    });
    if (value) {
      IrisSfx.confirm();
    }
  }

  Future<void> _toggleUiHaptics(bool value) async {
    await IrisHaptics.setEnabled(value);
    setState(() {
      _uiHapticsEnabled = value;
    });
    if (value) {
      IrisHaptics.actionSoft();
    }
  }

  Future<void> _setFeedbackProfile(String profile) async {
    if (_feedbackProfile == profile) return;
    await IrisSfx.setProfile(profile);
    await IrisHaptics.setProfile(profile);
    setState(() {
      _feedbackProfile = profile;
    });
    IrisHaptics.actionMedium();
  }

  Future<void> _showWidgetSetupGuideFromDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                offset: const Offset(0, 12),
                blurRadius: 32,
                spreadRadius: -8,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                offset: const Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Widget icon with gradient
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [IrisTokens.purpleLight, IrisTokens.purple],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: IrisTokens.purpleLight.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: IrisTokens.purple.withValues(alpha: 0.20),
                      offset: const Offset(0, 5),
                      blurRadius: 12,
                      spreadRadius: -5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Add Home Screen Widget',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: 2.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                'Track your classes at a glance with the IRIS home screen widget.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.65,
                  ),
                  height: 1.5,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Instructions
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.04,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                      0.06,
                    ),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepForDialog(
                      isDark,
                      '1',
                      'Long press on your home screen',
                    ),
                    const SizedBox(height: 12),
                    _buildStepForDialog(isDark, '2', 'Tap Widgets'),
                    const SizedBox(height: 12),
                    _buildStepForDialog(isDark, '3', 'Search for "IRIS"'),
                    const SizedBox(height: 12),
                    _buildStepForDialog(isDark, '4', 'Drag to home screen'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        await prefs.setBool('widget_prompt_shown', true);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.purple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Got It!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepForDialog(bool isDark, String number, String text) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [IrisTokens.purple, IrisTokens.purpleLight],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  void _registerRevealTap() {
    if (_revealQuote) return;
    _tapCount += 1;
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(seconds: 2), () {
      _tapCount = 0;
    });
    if (_tapCount >= 5) {
      _revealTimer?.cancel();
      _tapCount = 0;
      if (!mounted) return;
      setState(() {
        _revealQuote = true;
      });
      IrisHaptics.actionSoft();
    }
  }

  void _showChangelog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
          decoration: BoxDecoration(
            color: isDark ? IrisTokens.surfaceDarkElevated : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                offset: const Offset(0, 8),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [IrisTokens.brand, IrisTokens.brandLight],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Version History',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            'v1.0.0+1',
                            style: TextStyle(
                              fontSize: 12,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close_rounded,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
              ),
              // Changelog content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChangelogEntry(
                        isDark,
                        'v1.0.0',
                        'Initial Release',
                        [
                          'Complete redesign of About & Settings screen',
                          'New neumorphic visual style',
                          'Added appearance mode selector (System/Light/Dark)',
                          'Improved settings organization',
                          'Enhanced changelog viewer',
                          'All existing features preserved and optimized',
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangelogEntry(
    bool isDark,
    String version,
    String title,
    List<String> changes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: IrisTokens.brand.withValues(alpha: 0.1),
                border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                version,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: IrisTokens.brand,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...changes
            .map(
              (change) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: IrisTokens.success,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        change,
                        style: TextStyle(
                          fontSize: 12,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          _NeuralAura(background: isDark),
          SafeArea(
            child: ScrollConfiguration(
              behavior: const SmoothScrollBehavior(),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 118),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Back Button
                    Row(
                      children: [
                        AnimatedButton(
                          onPressed: _handleBackNavigation,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 
                                    isDark ? 0.2 : 0.04,
                                  ),
                                  offset: const Offset(0, 2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: isDark ? Colors.white : Colors.black,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Settings',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                'Configure IRIS appearance & behavior',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Profile Section (About Developer)
                    _buildProfileHeader(isDark),
                    const SizedBox(height: 28),

                    // Interface Section
                    _buildSectionLabel(isDark, 'Interface'),
                    const SizedBox(height: 12),
                    _buildAppearanceModeCard(isDark),
                    const SizedBox(height: 12),
                    _buildUiSoundsCard(isDark),
                    const SizedBox(height: 12),
                    _buildUserRoleCard(isDark),
                    const SizedBox(height: 28),

                    // Notifications & Widget Section
                    _buildSectionLabel(isDark, 'Notifications & Widget'),
                    const SizedBox(height: 12),
                    _buildClassTrackerCard(isDark),
                    const SizedBox(height: 12),
                    _buildLectureReminderCard(isDark),
                    const SizedBox(height: 12),
                    _buildWidgetSettingsCard(isDark),
                    const SizedBox(height: 28),

                    // Updates Section
                    _buildSectionLabel(isDark, 'Updates'),
                    const SizedBox(height: 12),
                    _buildOTACard(isDark),
                    const SizedBox(height: 28),

                    // Info Section
                    _buildSectionLabel(isDark, 'Information'),
                    const SizedBox(height: 12),
                    _buildChangelogButton(isDark),
                    const SizedBox(height: 12),
                    _buildSupportButton(isDark),
                    const SizedBox(height: 28),

                    // Close Button
                    if (widget.showCloseButton) ...[
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _handleBackNavigation,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.03),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          child: Text(
                            'Done',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _SmartScreenDock(
                  showFacultySet: _userRole == 'faculty',
                  selectedIndex: _userRole == 'faculty' ? 3 : 6,
                  onPortal: () => pushIconLaunchRoute(
                    context,
                    page: const PortalScreen(
                      url: 'https://swl-sis.comsats.edu.pk/Login/Index',
                      title: 'COMSATS Student Portal',
                      sessionScope: 'student',
                    ),
                  ),
                  onAbout: () {},
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Neumorphic Builder Methods

  Widget _buildSectionLabel(bool isDark, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [IrisTokens.brand, IrisTokens.brandLight],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: IrisTokens.brand.withValues(alpha: 0.3),
                  offset: const Offset(0, 3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.info_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _registerRevealTap,
                  child: Text(
                    'Developed by Malik Aurangzaib Channer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (_revealQuote) ...[
                  Text(
                    '🎯 "Obstacles are but stepping stones."',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: IrisTokens.brand,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  Text(
                    'IRIS - v1.0.0+1',
                    style: TextStyle(
                      fontSize: 12,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                        0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              try {
                final uri = Uri.parse(
                  'mailto:malikaurangzaibahmed@gmail.com?subject=IRIS%20Support%20Request',
                );
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                IrisHaptics.actionSoft();
              } catch (e) {
                if (mounted) {
                  showIrisFrostedSnackBar(
                    context,
                    dedupeKey: 'install_email_app_support',
                    content: Row(
                      children: const [
                        Icon(
                          Icons.info_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Text('Install an email app')),
                      ],
                    ),
                    tint: IrisTokens.brand,
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: IrisTokens.brand.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.email_rounded,
                color: IrisTokens.brand,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceModeCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IrisTokens.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: IrisTokens.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Appearance Mode',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildAppearanceButton(
                  isDark,
                  'System',
                  'system',
                  Icons.brightness_auto_rounded,
                ),
                const SizedBox(width: 4),
                _buildAppearanceButton(
                  isDark,
                  'Light',
                  'light',
                  Icons.light_mode_rounded,
                ),
                const SizedBox(width: 4),
                _buildAppearanceButton(
                  isDark,
                  'Dark',
                  'dark',
                  Icons.dark_mode_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceButton(
    bool isDark,
    String label,
    String mode,
    IconData icon,
  ) {
    final isSelected = _appearanceMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setAppearanceMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? IrisTokens.purple.withValues(alpha: isDark ? 0.25 : 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? IrisTokens.purple.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? IrisTokens.purple
                    : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? IrisTokens.purple
                      : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUiSoundsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _uiSoundsEnabled
            ? IrisTokens.blue.withValues(alpha: isDark ? 0.12 : 0.07)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _uiSoundsEnabled
              ? IrisTokens.blue.withValues(alpha: 0.26)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IrisTokens.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _uiSoundsEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: IrisTokens.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haptics & Sound Tuning',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _uiSoundsEnabled
                          ? 'ColorOS-inspired tactile and audio feedback'
                          : 'Silent profile for interface actions',
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFeedbackToggle(
                  isDark: isDark,
                  label: 'UI Sounds',
                  icon: _uiSoundsEnabled
                      ? Icons.music_note_rounded
                      : Icons.music_off_rounded,
                  value: _uiSoundsEnabled,
                  onChanged: _toggleUiSounds,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFeedbackToggle(
                  isDark: isDark,
                  label: 'Haptics',
                  icon: _uiHapticsEnabled
                      ? Icons.vibration_rounded
                      : Icons.phone_iphone_rounded,
                  value: _uiHapticsEnabled,
                  onChanged: _toggleUiHaptics,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildFeedbackProfileButton(
                  isDark: isDark,
                  label: 'Gentle',
                  profile: 'gentle',
                ),
                const SizedBox(width: 4),
                _buildFeedbackProfileButton(
                  isDark: isDark,
                  label: 'Balanced',
                  profile: 'balanced',
                ),
                const SizedBox(width: 4),
                _buildFeedbackProfileButton(
                  isDark: isDark,
                  label: 'Crisp',
                  profile: 'crisp',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackToggle({
    required bool isDark,
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: IrisTokens.blue.withValues(alpha: value ? 0.95 : 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.78),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: IrisTokens.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackProfileButton({
    required bool isDark,
    required String label,
    required String profile,
  }) {
    final isSelected = _feedbackProfile == profile;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setFeedbackProfile(profile),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? IrisTokens.blue.withValues(alpha: isDark ? 0.26 : 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? IrisTokens.blue.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? IrisTokens.blue
                  : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.56),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserRoleCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _userRole == 'faculty'
                      ? Icons.badge_rounded
                      : Icons.school_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Role',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      _userRole == 'faculty' ? 'Faculty tools' : 'Student mode',
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: AbsorbPointer(
              absorbing: _isSwitchingRole,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _setUserRole('student'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _userRole == 'student'
                              ? IrisTokens.brand.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _userRole == 'student'
                                ? IrisTokens.brand.withValues(alpha: 0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.school_rounded,
                              size: 14,
                              color: _userRole == 'student'
                                  ? IrisTokens.brand
                                  : (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Student',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: _userRole == 'student'
                                    ? IrisTokens.brand
                                    : (isDark ? Colors.white : Colors.black)
                                          .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _setUserRole('faculty'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _userRole == 'faculty'
                              ? IrisTokens.blue.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _userRole == 'faculty'
                                ? IrisTokens.blue.withValues(alpha: 0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.badge_rounded,
                              size: 14,
                              color: _userRole == 'faculty'
                                  ? IrisTokens.blue
                                  : (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Faculty',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: _userRole == 'faculty'
                                    ? IrisTokens.blue
                                    : (isDark ? Colors.white : Colors.black)
                                          .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassTrackerCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _persistentNotificationEnabled
            ? IrisTokens.brand.withValues(alpha: isDark ? 0.1 : 0.06)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _persistentNotificationEnabled
              ? IrisTokens.brand.withValues(alpha: 0.2)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: IrisTokens.brand.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _persistentNotificationEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: IrisTokens.brand,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Class Tracker',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _persistentNotificationEnabled
                      ? 'Showing schedule in notification'
                      : 'Enable to track classes',
                  style: TextStyle(
                    fontSize: 11,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                      0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _persistentNotificationEnabled,
            onChanged: _togglePersistentNotification,
            activeColor: IrisTokens.brand,
          ),
        ],
      ),
    );
  }

  Widget _buildLectureReminderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lectureRemindersEnabled
            ? IrisTokens.success.withValues(alpha: isDark ? 0.14 : 0.08)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _lectureRemindersEnabled
              ? IrisTokens.success.withValues(alpha: 0.3)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: IrisTokens.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _lectureRemindersEnabled
                  ? Icons.alarm_on_rounded
                  : Icons.alarm_off_rounded,
              color: IrisTokens.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lecture Reminder',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _lectureRemindersEnabled
                      ? 'Alerts 5 min before class starts'
                      : 'Get notified before upcoming classes',
                  style: TextStyle(
                    fontSize: 11,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                      0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _lectureRemindersEnabled,
            onChanged: _toggleLectureReminders,
            activeColor: IrisTokens.success,
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetSettingsCard(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showWidgetSetupGuideFromDashboard,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: IrisTokens.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.widgets_rounded,
                        color: IrisTokens.purple,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Home Screen Widget',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Add IRIS widget to home screen',
                            style: TextStyle(
                              fontSize: 11,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: IrisTokens.purple.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _widgetDarkMode
                ? IrisTokens.brand.withValues(alpha: isDark ? 0.1 : 0.06)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _widgetDarkMode
                  ? IrisTokens.brand.withValues(alpha: 0.2)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IrisTokens.brand.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _widgetDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: IrisTokens.brand,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Widget Dark Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _widgetDarkMode
                          ? 'Dark colors for widget'
                          : 'Light colors for widget',
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _widgetDarkMode,
                onChanged: _toggleWidgetDarkMode,
                activeColor: IrisTokens.brand,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOTACard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IrisTokens.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.cloud_download_rounded,
                  color: IrisTokens.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timetable Updates',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _otaStatus == null
                          ? 'Checking...'
                          : 'Last: ${_otaStatus!['lastCheck']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isRefreshing)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(IrisTokens.brand),
                  ),
                )
              else
                GestureDetector(
                  onTap: _refreshOTA,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: IrisTokens.brand.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: IrisTokens.brand,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
          if (_otaStatus != null && _otaStatus!['hasCached'] == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: IrisTokens.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: IrisTokens.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: IrisTokens.success,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-updates daily',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: IrisTokens.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChangelogButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showChangelog,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: IrisTokens.brand.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: IrisTokens.brand,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Version History',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'v1.0.0+1 - Latest',
                        style: TextStyle(
                          fontSize: 11,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: IrisTokens.brand.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            try {
              final uri = Uri.parse(
                'mailto:malikaurangzaibahmed@gmail.com?subject=IRIS%20Support',
              );
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              IrisHaptics.actionSoft();
            } catch (e) {
              if (mounted) {
                showIrisFrostedSnackBar(
                  context,
                  dedupeKey: 'install_email_client_contact',
                  content: const Text('Install an email client'),
                  tint: IrisTokens.brand,
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: IrisTokens.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: IrisTokens.purple,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Support & Feedback',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Get help or send feedback',
                        style: TextStyle(
                          fontSize: 11,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: IrisTokens.purple.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BatchSelectorSheet extends StatefulWidget {
  final UniversityMemory memory;
  final String selected;

  const BatchSelectorSheet({
    required this.memory,
    required this.selected,
    super.key,
  });

  @override
  State<BatchSelectorSheet> createState() => _BatchSelectorSheetState();
}

class _BatchSelectorSheetState extends State<BatchSelectorSheet> {
  String? program;
  int? semester;
  String? section;

  @override
  void initState() {
    super.initState();
    final key = BatchKey.parse(widget.selected);
    program = key.program;
    semester = key.semester;
    section = key.section;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Filter out batch-like programs (FA##, SP##, etc.) - show only actual programs
    final programs = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\\d{2}$').hasMatch(p))
        .toList();
    final semesters = program == null
        ? <int>[]
        : widget.memory.semesters(program!);
    final sections = (program != null && semester != null)
        ? widget.memory.sections(program!, semester!)
        : <String>[];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.07),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.80),
                      Colors.white.withValues(alpha: 0.60),
                    ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.70),
              width: isDark ? 1.5 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: IrisTokens.brand.withValues(alpha: isDark ? 0.14 : 0.10),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: (isDark ? Colors.black : Colors.black.withValues(alpha: 0.5))
                    .withValues(alpha: 0.18),
                blurRadius: 28,
                spreadRadius: -10,
                offset: const Offset(0, 16),
              ),
              if (isDark)
                BoxShadow(
                  color: IrisTokens.brand.withValues(alpha: 0.06),
                  blurRadius: 20,
                  spreadRadius: -8,
                ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -12,
                left: -12,
                child: IgnorePointer(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.16 : 0.24),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -16,
                right: -16,
                child: IgnorePointer(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.14 : 0.20),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [IrisTokens.brand, IrisTokens.brandLight],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: IrisTokens.brand.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Batch Resolver',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Configure your academic profile',
                              style: TextStyle(
                                fontSize: 14,
                                letterSpacing: 0.3,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _EnhancedDropDownRow(
                    label: 'Program',
                    value: program,
                    items: programs,
                    icon: Icons.school_rounded,
                    onChanged: (value) => setState(() {
                      program = value;
                      semester = null;
                      section = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _EnhancedDropDownRow(
                    label: 'Semester',
                    value: semester?.toString(),
                    items: semesters.map((e) => e.toString()).toList(),
                    icon: Icons.calendar_month_rounded,
                    onChanged: (value) => setState(() {
                      semester = int.tryParse(value ?? '');
                      section = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _EnhancedDropDownRow(
                    label: 'Section',
                    value: section,
                    items: sections,
                    icon: Icons.group_rounded,
                    onChanged: (value) => setState(() => section = value),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient:
                                (program != null &&
                                    semester != null &&
                                    section != null)
                                ? const LinearGradient(
                                    colors: [
                                      IrisTokens.brand,
                                      IrisTokens.brandLight,
                                    ],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow:
                                (program != null &&
                                    semester != null &&
                                    section != null)
                                ? [
                                    BoxShadow(
                                      color: IrisTokens.brand.withValues(alpha: 0.4),
                                      blurRadius: 5,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed:
                                (program != null &&
                                    semester != null &&
                                    section != null)
                                ? () {
                                    final batch = widget.memory.allBatches
                                        .firstWhere((b) {
                                          final key = BatchKey.parse(b);
                                          return key.program == program &&
                                              key.semester == semester &&
                                              key.section == section;
                                        }, orElse: () => widget.selected);
                                    Navigator.pop(context, batch);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.08),
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Apply Changes',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnhancedDropDownRow extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _EnhancedDropDownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.10),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black.withValues(alpha: 0.5))
                .withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: IrisTokens.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: IrisTokens.brand, size: 20),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                hint: Text(
                  'Select',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                dropdownColor: isDark
                    ? IrisTokens.surfaceDarkElevated
                    : Colors.white,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeuralAura extends StatefulWidget {
  final bool background;
  final String tone;

  const _NeuralAura({required this.background, this.tone = 'default'});

  @override
  State<_NeuralAura> createState() => _NeuralAuraState();
}

class _NeuralAuraState extends State<_NeuralAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _lerpColorLists(List<Color> a, List<Color> b, double t) {
    final count = math.min(a.length, b.length);
    if (count == 0) return const [];
    return List<Color>.generate(
      count,
      (index) => Color.lerp(a[index], b[index], t) ?? a[index],
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    List<Color> toneStopsDark() {
      switch (widget.tone) {
        case 'core':
          return [
            IrisTokens.surfaceDark,
            IrisTokens.brand.withValues(alpha: 0.14),
            IrisTokens.surfaceDarkElevated,
          ];
        case 'cs':
          return [
            IrisTokens.surfaceDark,
            IrisTokens.blue.withValues(alpha: 0.18),
            IrisTokens.surfaceDarkElevated,
          ];
        case 'health':
          return [
            IrisTokens.surfaceDark,
            IrisTokens.teal.withValues(alpha: 0.18),
            IrisTokens.surfaceDarkElevated,
          ];
        case 'engineering':
          return [
            IrisTokens.surfaceDark,
            IrisTokens.warningDark.withValues(alpha: 0.18),
            IrisTokens.surfaceDarkElevated,
          ];
        case 'analytics':
          return [
            IrisTokens.surfaceDark,
            IrisTokens.purple.withValues(alpha: 0.18),
            IrisTokens.surfaceDarkElevated,
          ];
        default:
          return [
            IrisTokens.surfaceDark,
            IrisTokens.surfaceDark,
            IrisTokens.surfaceDarkElevated,
            IrisTokens.surfaceDarkElevated,
          ];
      }
    }

    List<Color> toneStopsDarkAlt() {
      switch (widget.tone) {
        case 'core':
          return [
            IrisTokens.surfaceDarkElevated,
            IrisTokens.teal.withValues(alpha: 0.13),
            IrisTokens.surfaceDark,
          ];
        case 'cs':
          return [
            IrisTokens.surfaceDarkElevated,
            IrisTokens.brand.withValues(alpha: 0.14),
            IrisTokens.surfaceDark,
          ];
        case 'health':
          return [
            IrisTokens.surfaceDarkElevated,
            IrisTokens.success.withValues(alpha: 0.14),
            IrisTokens.surfaceDark,
          ];
        case 'engineering':
          return [
            IrisTokens.surfaceDarkElevated,
            IrisTokens.warning.withValues(alpha: 0.13),
            IrisTokens.surfaceDark,
          ];
        case 'analytics':
          return [
            IrisTokens.surfaceDarkElevated,
            IrisTokens.blue.withValues(alpha: 0.13),
            IrisTokens.surfaceDark,
          ];
        default:
          return [
            IrisTokens.surfaceDarkElevated,
            IrisTokens.brand.withValues(alpha: 0.10),
            IrisTokens.surfaceDark,
            IrisTokens.surfaceDark,
          ];
      }
    }

    List<Color> toneStopsLight() {
      switch (widget.tone) {
        case 'core':
          return [
            IrisTokens.surfaceLight,
            IrisTokens.brandLight.withValues(alpha: 0.18),
            IrisTokens.surfaceLightElevated,
            IrisTokens.teal.withValues(alpha: 0.10),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
        case 'cs':
          return [
            IrisTokens.surfaceLight,
            IrisTokens.blueLight.withValues(alpha: 0.16),
            IrisTokens.surfaceLightElevated,
            IrisTokens.brandLight.withValues(alpha: 0.10),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
        case 'health':
          return [
            IrisTokens.surfaceLight,
            IrisTokens.teal.withValues(alpha: 0.16),
            IrisTokens.surfaceLightElevated,
            IrisTokens.success.withValues(alpha: 0.10),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
        case 'engineering':
          return [
            IrisTokens.surfaceLight,
            IrisTokens.warning.withValues(alpha: 0.14),
            IrisTokens.surfaceLightElevated,
            IrisTokens.pinkLight.withValues(alpha: 0.09),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
        case 'analytics':
          return [
            IrisTokens.surfaceLight,
            IrisTokens.purpleLight.withValues(alpha: 0.16),
            IrisTokens.surfaceLightElevated,
            IrisTokens.blueLight.withValues(alpha: 0.10),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
        case 'learning':
          return [
            IrisTokens.surfaceLight,
            IrisTokens.pinkLight.withValues(alpha: 0.14),
            IrisTokens.surfaceLightElevated,
            IrisTokens.teal.withValues(alpha: 0.08),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
        default:
          return [
            IrisTokens.surfaceLight,
            IrisTokens.brandLight.withValues(alpha: 0.15),
            IrisTokens.surfaceLightElevated,
            IrisTokens.pinkLight.withValues(alpha: 0.09),
            IrisTokens.surfaceLight,
            IrisTokens.surfaceLightElevated,
          ];
      }
    }

    List<Color> toneStopsLightAlt() {
      switch (widget.tone) {
        case 'core':
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.teal.withValues(alpha: 0.14),
            IrisTokens.surfaceLight,
            IrisTokens.brandLight.withValues(alpha: 0.11),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
        case 'cs':
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.brandLight.withValues(alpha: 0.14),
            IrisTokens.surfaceLight,
            IrisTokens.blueLight.withValues(alpha: 0.10),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
        case 'health':
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.success.withValues(alpha: 0.14),
            IrisTokens.surfaceLight,
            IrisTokens.teal.withValues(alpha: 0.10),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
        case 'engineering':
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.pinkLight.withValues(alpha: 0.12),
            IrisTokens.surfaceLight,
            IrisTokens.warning.withValues(alpha: 0.10),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
        case 'analytics':
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.blueLight.withValues(alpha: 0.13),
            IrisTokens.surfaceLight,
            IrisTokens.purpleLight.withValues(alpha: 0.10),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
        case 'learning':
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.teal.withValues(alpha: 0.12),
            IrisTokens.surfaceLight,
            IrisTokens.pinkLight.withValues(alpha: 0.09),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
        default:
          return [
            IrisTokens.surfaceLightElevated,
            IrisTokens.pinkLight.withValues(alpha: 0.12),
            IrisTokens.surfaceLight,
            IrisTokens.brandLight.withValues(alpha: 0.09),
            IrisTokens.surfaceLightElevated,
            IrisTokens.surfaceLight,
          ];
      }
    }

    List<Color> toneMeshLight() {
      switch (widget.tone) {
        case 'core':
          return [
            IrisTokens.brandLight.withValues(alpha: 0.11),
            Colors.transparent,
            IrisTokens.teal.withValues(alpha: 0.06),
          ];
        case 'cs':
          return [
            IrisTokens.blueLight.withValues(alpha: 0.10),
            Colors.transparent,
            IrisTokens.brandLight.withValues(alpha: 0.08),
          ];
        case 'health':
          return [
            IrisTokens.teal.withValues(alpha: 0.10),
            Colors.transparent,
            IrisTokens.success.withValues(alpha: 0.07),
          ];
        case 'engineering':
          return [
            IrisTokens.warning.withValues(alpha: 0.09),
            Colors.transparent,
            IrisTokens.pinkLight.withValues(alpha: 0.05),
          ];
        case 'analytics':
          return [
            IrisTokens.purpleLight.withValues(alpha: 0.10),
            Colors.transparent,
            IrisTokens.blueLight.withValues(alpha: 0.06),
          ];
        case 'learning':
          return [
            IrisTokens.pinkLight.withValues(alpha: 0.08),
            Colors.transparent,
            IrisTokens.teal.withValues(alpha: 0.05),
          ];
        default:
          return [
            IrisTokens.brandLight.withValues(alpha: 0.09),
            Colors.transparent,
            IrisTokens.pinkLight.withValues(alpha: 0.06),
          ];
      }
    }

    List<Color> toneMeshLightAlt() {
      switch (widget.tone) {
        case 'core':
          return [
            IrisTokens.teal.withValues(alpha: 0.10),
            Colors.transparent,
            IrisTokens.brandLight.withValues(alpha: 0.07),
          ];
        case 'cs':
          return [
            IrisTokens.brandLight.withValues(alpha: 0.10),
            Colors.transparent,
            IrisTokens.blueLight.withValues(alpha: 0.06),
          ];
        case 'health':
          return [
            IrisTokens.success.withValues(alpha: 0.09),
            Colors.transparent,
            IrisTokens.teal.withValues(alpha: 0.06),
          ];
        case 'engineering':
          return [
            IrisTokens.pinkLight.withValues(alpha: 0.08),
            Colors.transparent,
            IrisTokens.warning.withValues(alpha: 0.06),
          ];
        case 'analytics':
          return [
            IrisTokens.blueLight.withValues(alpha: 0.09),
            Colors.transparent,
            IrisTokens.purpleLight.withValues(alpha: 0.06),
          ];
        case 'learning':
          return [
            IrisTokens.teal.withValues(alpha: 0.08),
            Colors.transparent,
            IrisTokens.pinkLight.withValues(alpha: 0.05),
          ];
        default:
          return [
            IrisTokens.pinkLight.withValues(alpha: 0.08),
            Colors.transparent,
            IrisTokens.brandLight.withValues(alpha: 0.05),
          ];
      }
    }

    Color darkPrimaryAccent() {
      switch (widget.tone) {
        case 'core':
          return IrisTokens.brand.withValues(alpha: 0.12);
        case 'cs':
          return IrisTokens.blue.withValues(alpha: 0.10);
        case 'health':
          return IrisTokens.teal.withValues(alpha: 0.10);
        case 'engineering':
          return IrisTokens.warning.withValues(alpha: 0.10);
        case 'analytics':
          return IrisTokens.purple.withValues(alpha: 0.10);
        default:
          return IrisTokens.brand.withValues(alpha: 0.08);
      }
    }

    Color darkSecondaryAccent() {
      switch (widget.tone) {
        case 'core':
          return IrisTokens.teal.withValues(alpha: 0.07);
        case 'cs':
          return IrisTokens.brand.withValues(alpha: 0.08);
        case 'health':
          return IrisTokens.success.withValues(alpha: 0.08);
        case 'engineering':
          return IrisTokens.pink.withValues(alpha: 0.07);
        case 'analytics':
          return IrisTokens.blue.withValues(alpha: 0.07);
        default:
          return IrisTokens.purple.withValues(alpha: 0.06);
      }
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final phase = t * 2 * math.pi;
        final wave = 0.5 + (0.5 * math.sin(phase));
        final waveSlow = 0.5 + (0.5 * math.sin((phase * 0.72) + 0.9));
        final driftX = 0.30 * math.sin(phase + 1.0);
        final driftY = 0.22 * math.cos((phase * 0.86) + 0.6);
        final shimmer = 0.5 + (0.5 * math.sin((phase * 2.3) + 2.2));
        final pulse = 0.5 + (0.5 * math.sin((phase * 1.45) + 0.4));

        final baseColors = widget.background
            ? _lerpColorLists(toneStopsDark(), toneStopsDarkAlt(), wave)
            : _lerpColorLists(toneStopsLight(), toneStopsLightAlt(), wave);

        final meshColors = widget.background
            ? _lerpColorLists(
                [darkPrimaryAccent(), Colors.transparent, darkSecondaryAccent()],
                [darkSecondaryAccent(), Colors.transparent, darkPrimaryAccent()],
                wave,
              )
            : _lerpColorLists(toneMeshLight(), toneMeshLightAlt(), wave);

        return Stack(
          children: [
        // Base gradient — deeper, richer
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + driftX, -1.0 + driftY),
              end: Alignment(1.0 - driftX, 1.0 - driftY),
              colors: baseColors,
              stops: widget.background
                  ? const [0.0, 0.3, 0.7, 1.0]
                  : const [0.0, 0.15, 0.35, 0.55, 0.78, 1.0],
            ),
          ),
        ),

        // Mesh overlay for premium depth
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(1.0 - driftY, -1.0 + driftX),
                  end: Alignment(-1.0 + driftY, 1.0 - driftX),
                  colors: meshColors,
                ),
              ),
            ),
          ),
        ),

        // Sweeping highlight layer for livelier movement
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: widget.background ? (0.06 + (shimmer * 0.05)) : (0.05 + (shimmer * 0.06)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1.2 + (waveSlow * 1.6), -1.0),
                    end: Alignment(-0.2 + (waveSlow * 1.6), 1.0),
                    colors: [
                      Colors.transparent,
                      (widget.background ? Colors.white : IrisTokens.brand).withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Counter sweep to avoid static directional feel
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: widget.background ? (0.04 + (pulse * 0.05)) : (0.03 + (pulse * 0.05)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(1.1 - (waveSlow * 1.5), -1.0),
                    end: Alignment(0.1 - (waveSlow * 1.5), 1.0),
                    colors: [
                      Colors.transparent,
                      (widget.background ? IrisTokens.blue : IrisTokens.purple).withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Moving pulse core for energetic depth
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.5 + (wave * 1.0), -0.2 + ((1 - wave) * 0.8)),
                  radius: 0.9 + (pulse * 0.2),
                  colors: [
                    (widget.background ? IrisTokens.teal : IrisTokens.brand).withValues(alpha: 0.10 + (pulse * 0.08)),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        if (widget.background)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.9 - driftX, -0.9 + (driftY * 0.6)),
                    radius: 1.0,
                    colors: [
                      darkPrimaryAccent(),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (widget.background)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.9 + (driftY * 0.6), 0.9 - driftX),
                    radius: 1.0,
                    colors: [
                      darkSecondaryAccent(),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (!widget.background)
          Positioned(
            top: -160,
            left: -120,
            child: _AuraBlob(
              colors: [
                IrisTokens.brand.withValues(alpha: 0.14),
                IrisTokens.brandLight.withValues(alpha: 0.08),
                IrisTokens.brandLight.withValues(alpha: 0.03),
              ],
              size: 460,
            ),
          ),

        if (!widget.background)
          Positioned(
            top: -60,
            right: -100,
            child: _AuraBlob(
              colors: [
                IrisTokens.pink.withValues(alpha: 0.10),
                IrisTokens.pink.withValues(alpha: 0.05),
                IrisTokens.pinkLight.withValues(alpha: 0.02),
              ],
              size: 320,
            ),
          ),

        // Bottom-right — deep purple
        if (!widget.background)
          Positioned(
            bottom: -140,
            right: -120,
            child: _AuraBlob(
              colors: [
                IrisTokens.purple.withValues(alpha: 0.12),
                IrisTokens.purpleLight.withValues(alpha: 0.06),
                IrisTokens.purpleLight.withValues(alpha: 0.03),
              ],
              size: 500,
            ),
          ),

        if (widget.background)
          Positioned(
            top: -120,
            left: -120,
            child: _AuraBlob(
              colors: [
                IrisTokens.brand.withValues(alpha: 0.08),
                IrisTokens.brand.withValues(alpha: 0.04),
                Colors.transparent,
              ],
              size: 440,
            ),
          ),

        if (widget.background)
          Positioned(
            top: 20,
            right: -110,
            child: _AuraBlob(
              colors: [
                IrisTokens.purple.withValues(alpha: 0.08),
                IrisTokens.purpleLight.withValues(alpha: 0.04),
                Colors.transparent,
              ],
              size: 360,
            ),
          ),

        if (widget.background)
          Positioned(
            bottom: -130,
            left: -90,
            child: _AuraBlob(
              colors: [
                IrisTokens.teal.withValues(alpha: 0.07),
                IrisTokens.success.withValues(alpha: 0.04),
                Colors.transparent,
              ],
              size: 380,
            ),
          ),

        if (widget.background)
          Positioned(
            bottom: -150,
            right: -140,
            child: _AuraBlob(
              colors: [
                IrisTokens.warning.withValues(alpha: 0.06),
                IrisTokens.warningDark.withValues(alpha: 0.03),
                Colors.transparent,
              ],
              size: 420,
            ),
          ),

        if (!widget.background)
          Positioned(
            top: h * 0.32,
            right: -90,
            child: _AuraBlob(
              colors: [
                IrisTokens.warning.withValues(alpha: 0.07),
                IrisTokens.warning.withValues(alpha: 0.04),
                IrisTokens.warningDark.withValues(alpha: 0.02),
              ],
              size: 300,
            ),
          ),

        if (!widget.background)
          Positioned(
            bottom: h * 0.12,
            left: -80,
            child: _AuraBlob(
              colors: [
                IrisTokens.teal.withValues(alpha: 0.08),
                IrisTokens.success.withValues(alpha: 0.04),
                IrisTokens.successDark.withValues(alpha: 0.02),
              ],
              size: 320,
            ),
          ),

        if (!widget.background)
          Positioned(
            top: h * 0.18,
            left: w * 0.25,
            child: _AuraBlob(
              colors: [
                IrisTokens.blue.withValues(alpha: 0.05),
                IrisTokens.blueLight.withValues(alpha: 0.03),
                IrisTokens.brandLight.withValues(alpha: 0.01),
              ],
              size: 240,
            ),
          ),

        if (!widget.background)
          Positioned(
            top: h * 0.6,
            left: w * 0.4,
            child: _AuraBlob(
              colors: [
                IrisTokens.purple.withValues(alpha: 0.06),
                IrisTokens.purple.withValues(alpha: 0.03),
                IrisTokens.purpleLight.withValues(alpha: 0.01),
              ],
              size: 260,
            ),
          ),

        // Subtle grain/noise overlay for depth
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0, -1.0 + (driftX * 0.7)),
                  end: Alignment(0, 1.0 - (driftY * 0.7)),
                  colors: [
                    Colors.transparent,
                    (widget.background ? Colors.black : Colors.white).withValues(alpha: 
                      0.03,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
          ],
        );
      },
    );
  }
}

class SmoothScrollBehavior extends MaterialScrollBehavior {
  const SmoothScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use platform-native physics for better performance
    // Android: ClampingScrollPhysics (native feel, better performance)
    // iOS/macOS: BouncingScrollPhysics (native feel)
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        );
      case TargetPlatform.android:
      default:
        return const ClampingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        );
    }
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class _AuraBlob extends StatefulWidget {
  final List<Color> colors;
  final double size;

  const _AuraBlob({required this.colors, required this.size});

  @override
  State<_AuraBlob> createState() => _AuraBlobState();
}

class _AuraBlobState extends State<_AuraBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final durationMs = (3200 + (widget.size * 4)).round();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = (widget.size % 97) / 97;
    final travel = (widget.size / 280.0).clamp(0.95, 2.2);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final p = (t + phase) * 2 * math.pi;
        final floatY = (math.sin(p) * 10.5 + math.sin((p * 0.68) + 0.8) * 5.0) * travel;
        final floatX = (math.cos((p * 0.94) + 0.5) * 6.2 + math.sin((p * 0.42) + 1.1) * 2.6) * travel;
        final scale = 0.975 + (math.sin((p * 0.82) + 0.3) * 0.022);

        return Transform.translate(
          offset: Offset(floatX, floatY),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: widget.colors,
                  stops: widget.colors.length == 3
                      ? const [0.0, 0.6, 1.0]
                      : const [0.0, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (widget.colors.first).withValues(alpha: 0.16),
                    blurRadius: widget.size * 0.15,
                    spreadRadius: widget.size * -0.08,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TeacherLocatorScreen extends StatefulWidget {
  final OmniBrain brain;
  final ValueChanged<String>? onTeacherSelected;
  final ValueChanged<String>? onRoleChanged;
  final UniversityMemory? memory;
  final String? currentBatch;
  final String? initialTeacherQuery;
  final bool autoSearchInitial;
  final bool showDock;
  final bool showBackButton;
  final bool closeOnTeacherSelect;

  const _TeacherLocatorScreen({
    required this.brain,
    this.onTeacherSelected,
    this.onRoleChanged,
    this.memory,
    this.currentBatch,
    this.initialTeacherQuery,
    this.autoSearchInitial = false,
    this.showDock = true,
    this.showBackButton = true,
    this.closeOnTeacherSelect = true,
    super.key,
  });

  @override
  State<_TeacherLocatorScreen> createState() => _TeacherLocatorScreenState();
}

class _TeacherLocatorScreenState extends State<_TeacherLocatorScreen> {
  static const String _helpdeskBackendBase =
      'https://cui-helpdesk-backend.onrender.com';

  final HelpdeskFacultyService _facultyService = HelpdeskFacultyService();
  late TextEditingController _controller;
  TeacherLocatorResult? _result;
  bool _searching = false;
  bool _facultyProfilesLoading = false;
  HelpdeskFacultySource _facultyProfilesSource = HelpdeskFacultySource.none;
  List<String> _suggestions = [];
  List<String> _quickPicks = [];
  List<FacultyProfile> _facultyProfiles = const [];

  String _normalizeTeacherName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previous = List<int>.generate(b.length + 1, (i) => i);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      for (var j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }
    return previous[b.length];
  }

  String? _bestTeacherMatch(String query) {
    final normalizedQuery = _normalizeTeacherName(query);
    if (normalizedQuery.isEmpty) return null;

    String? best;
    var bestDistance = 1 << 30;
    for (final teacher in widget.brain.allTeachers()) {
      final normalizedTeacher = _normalizeTeacherName(teacher);
      if (normalizedTeacher.isEmpty) continue;

      if (normalizedTeacher.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedTeacher)) {
        return teacher;
      }

      final distance = _levenshteinDistance(normalizedQuery, normalizedTeacher);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = teacher;
      }
    }

    final threshold = math.max(2, (normalizedQuery.length * 0.35).round());
    if (best != null && bestDistance <= threshold) return best;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    final initial = widget.initialTeacherQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _controller.text = initial;
      if (widget.autoSearchInitial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _performSearch(initial);
        });
      }
    }
    _quickPicks = widget.brain.allTeachers().take(4).toList();
    unawaited(_loadFacultyProfiles());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFacultyProfiles() async {
    _facultyProfilesLoading = true;
    final payload = await _facultyService.fetchLiveFirstWithFallbackPayload();
    if (!mounted) return;
    setState(() {
      _facultyProfiles = payload.items;
      _facultyProfilesSource = payload.source;
      _facultyProfilesLoading = false;
    });
  }

  String _facultySourceLabel(HelpdeskFacultySource source) {
    switch (source) {
      case HelpdeskFacultySource.live:
        return 'LIVE';
      case HelpdeskFacultySource.cache:
        return 'CACHE';
      case HelpdeskFacultySource.backup:
        return 'BACKUP';
      case HelpdeskFacultySource.none:
        return 'OFFLINE';
    }
  }

  FacultyProfile? _matchFacultyProfile(String teacherName) {
    return HelpdeskFacultyService.matchFacultyProfile(
      teacherName,
      _facultyProfiles,
    );
  }

  String _resolveFacultyImageUrl(String image) {
    final raw = image.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '$_helpdeskBackendBase$raw';
    return '$_helpdeskBackendBase/$raw';
  }

  Future<void> _launchFacultyPhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'teacher_locator_phone_unavailable',
        content: const Text('Phone number unavailable for this teacher.'),
      );
      return;
    }
    final uri = Uri.parse('tel:$normalized');
    if (await canLaunchUrl(uri)) {
      IrisSfx.pillTap();
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'teacher_locator_phone_launch_failed',
      content: const Text('Unable to open dialer on this device.'),
    );
  }

  Future<void> _launchFacultyEmail(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'teacher_locator_email_unavailable',
        content: const Text('Email unavailable for this teacher.'),
      );
      return;
    }
    final uri = Uri.parse('mailto:$normalized');
    if (await canLaunchUrl(uri)) {
      IrisSfx.pillTap();
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'teacher_locator_email_launch_failed',
      content: const Text('Unable to open email client on this device.'),
    );
  }

  void _updateSuggestions(String query) {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final q = query.toLowerCase().trim();
    final all = widget.brain.allTeachers();
    final directMatches = all
        .where((t) => t.toLowerCase().contains(q))
        .toList();
    if (directMatches.isNotEmpty) {
      setState(() => _suggestions = directMatches.take(5).toList());
      return;
    }

    final normalizedQuery = _normalizeTeacherName(query);
    final scored =
        all
            .map(
              (name) => MapEntry(
                name,
                _levenshteinDistance(
                  normalizedQuery,
                  _normalizeTeacherName(name),
                ),
              ),
            )
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    final fuzzy = scored.take(5).map((e) => e.key).toList();
    final threshold = math.max(2, (normalizedQuery.length * 0.45).round());
    final filteredFuzzy = scored
        .where((e) => e.value <= threshold)
        .take(5)
        .map((e) => e.key)
        .toList();
    final matches = filteredFuzzy.isNotEmpty ? filteredFuzzy : fuzzy;
    setState(() => _suggestions = matches);
  }

  void _performSearch([String? override]) {
    final query = override ?? _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _suggestions = [];
    });

    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        var effectiveQuery = query;
        var result = widget.brain.locateTeacher(query, DateTime.now());

        if (result.status == 'not_found' || result.status == 'empty') {
          final bestMatch = _bestTeacherMatch(query);
          if (bestMatch != null) {
            effectiveQuery = bestMatch;
            result = widget.brain.locateTeacher(bestMatch, DateTime.now());
          }
        }

        setState(() {
          _result = result;
          _searching = false;
          if (result.status != 'not_found' && result.status != 'empty') {
            _controller.text = result.teacherName;
          }
        });

        if (effectiveQuery != query &&
            result.status != 'not_found' &&
            result.status != 'empty') {
          showIrisFrostedSnackBar(
            context,
            dedupeKey: 'teacher_closest_match_${result.teacherName}',
            content: Text('Showing closest match: ${result.teacherName}'),
          );
        }
        IrisHaptics.actionMedium();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFacultySelection = widget.onTeacherSelected != null;
    const purple = IrisTokens.purple;
    const purpleLight = IrisTokens.purpleLight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        leading: widget.showBackButton ? _AppBackButton(isDark: isDark) : null,
      ),
      body: Stack(
        children: [
          // Neural aura background
          _NeuralAura(background: isDark),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [purple, purpleLight, purpleLight],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: purple.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_search_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [purple, purpleLight],
                              ).createShader(bounds),
                              child: Text(
                                isFacultySelection
                                    ? 'Select Teacher'
                                    : 'Teacher Locator',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isFacultySelection
                                  ? 'Choose a teacher to load your faculty schedule'
                                  : 'Find any teacher\'s real-time location & schedule',
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 0.1,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Search card
                  GlassCard(
                    enableOverlay: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search field
                        AnimatedContainer(
                          duration: IrisMotion.fast,
                          curve: IrisMotion.standard,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      Colors.black.withValues(alpha: 0.50),
                                      Colors.black.withValues(alpha: 0.45),
                                    ]
                                  : [
                                      Colors.white.withValues(alpha: 0.85),
                                      Colors.white.withValues(alpha: 0.80),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              IrisTokens.radius20,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : IrisTokens.brand.withValues(alpha: 0.10),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: IrisTokens.brand.withValues(
                                  alpha: isDark ? 0.08 : 0.06,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                                spreadRadius: -2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.25 : 0.04,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _controller,
                            autofocus: false,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _performSearch(),
                            enabled: !_searching,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search by name...',
                              hintStyle: TextStyle(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.40),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: IrisTokens.brand,
                                size: 24,
                              ),
                              suffixIcon: _controller.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.45),
                                        size: 22,
                                      ),
                                      splashRadius: 22,
                                      onPressed: () {
                                        IrisHaptics.actionSoft();
                                        _controller.clear();
                                        setState(() {
                                          _result = null;
                                          _suggestions = [];
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: IrisTokens.space20,
                                vertical: IrisTokens.space20,
                              ),
                            ),
                            onChanged: (v) {
                              _updateSuggestions(v);
                              setState(() {});
                            },
                          ),
                        ),

                        if (_controller.text.trim().isEmpty &&
                            _quickPicks.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 14,
                                  color: IrisTokens.brand.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Quick picks',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 0.6,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: 0.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickPicks.map((name) {
                              return InkWell(
                                onTap: () {
                                  _controller.text = name;
                                  _performSearch(name);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: purple.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        // Suggestions dropdown
                        if (_suggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: purple.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Column(
                              children: _suggestions.map((name) {
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    _controller.text = name;
                                    _performSearch(name);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline_rounded,
                                          size: 18,
                                          color: purple.withValues(alpha: 0.7),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.white.withValues(alpha: 
                                                      0.9,
                                                    )
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.north_west_rounded,
                                          size: 14,
                                          color: purple.withValues(alpha: 0.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),
                        // Search button
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [purple, purpleLight],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: purple.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed:
                                  _searching || _controller.text.trim().isEmpty
                                  ? null
                                  : _performSearch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                disabledForegroundColor: Colors.white
                                    .withValues(alpha: 0.5),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _searching
                                  ? TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(
                                        milliseconds: 1152,
                                      ),
                                      curve: IrisMotion.standard,
                                      builder: (context, value, child) =>
                                          Transform.scale(
                                            scale:
                                                0.85 +
                                                (0.15 *
                                                    (1 -
                                                        (value - 0.5).abs() *
                                                            2)),
                                            child: child,
                                          ),
                                      onEnd: () {},
                                      child: const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.near_me_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Locate Now',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 224),
                    switchInCurve: IrisMotion.entrance,
                    switchOutCurve: IrisMotion.standard,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.98,
                          end: 1.0,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _searching
                        ? GlassCard(
                            key: const ValueKey('search_loading'),
                            enableOverlay: false,
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Locating teacher...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : (_result != null && _result!.status != 'empty')
                        ? SizedBox(
                            key: ValueKey(
                              'search_result_${_result!.teacherName}_${_result!.status}',
                            ),
                            child: _buildResultSection(
                              context,
                              _result!,
                              isDark,
                            ),
                          )
                        : const SizedBox(key: ValueKey('search_idle')),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _SmartScreenDock(
                  showFacultySet: isFacultySelection,
                  selectedIndex: 1,
                  onPortal: () => pushIconLaunchRoute(
                    context,
                    page: PortalScreen(
                      url: isFacultySelection
                          ? 'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/'
                          : 'https://swl-sis.comsats.edu.pk/Login/Index',
                      title: isFacultySelection
                          ? 'COMSATS Faculty Portal'
                          : 'COMSATS Student Portal',
                      sessionScope: isFacultySelection ? 'faculty' : 'student',
                    ),
                  ),
                  onClasses:
                      widget.memory != null && widget.currentBatch != null
                      ? () => pushIconLaunchRoute(
                          context,
                          page: _DepartmentClassesScreen(
                            memory: widget.memory!,
                            currentBatch: widget.currentBatch!,
                            brain: widget.brain,
                            onRoleChanged: widget.onRoleChanged,
                          ),
                        )
                      : () {
                          showIrisFrostedSnackBar(
                            context,
                            dedupeKey: 'classes_unavailable_faculty_selection',
                            content: Text(
                              'Classes view is unavailable in faculty selection mode.',
                            ),
                          );
                        },
                  onTools: !isFacultySelection &&
                          widget.memory != null &&
                          widget.currentBatch != null
                      ? () => pushIconLaunchRoute(
                          context,
                          page: _ToolsScreen(
                            memory: widget.memory!,
                            batch: widget.currentBatch!,
                            brain: widget.brain,
                            onRoleChanged: widget.onRoleChanged,
                          ),
                        )
                      : () {
                          showIrisFrostedSnackBar(
                            context,
                            dedupeKey: 'tools_unavailable_faculty_selection',
                            content: Text(
                              'Tools view is unavailable in faculty selection mode.',
                            ),
                          );
                        },
                  onAbout: () => pushIconLaunchRoute(
                    context,
                    page: AboutScreen(onRoleChanged: widget.onRoleChanged),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultSection(
    BuildContext context,
    TeacherLocatorResult result,
    bool isDark,
  ) {
    const purple = IrisTokens.purple;
    final profile = _matchFacultyProfile(result.teacherName);
    final isLiveNow = result.status == 'live';
    final hasEmail =
      profile != null &&
      profile.email.trim().isNotEmpty &&
      profile.email.trim().toLowerCase() != 'not available';
    final hasPhone =
      profile != null &&
      profile.contact.trim().isNotEmpty &&
      profile.contact.trim().toLowerCase() != 'not available';
    final canCallNow = hasPhone && !isLiveNow;

    if (result.status == 'not_found') {
      return GlassCard(
        enableOverlay: false,
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.red.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No teacher found matching "${_controller.text}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different spelling or partial name',
              style: TextStyle(
                fontSize: 12,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Teacher name & status badge
        GlassCard(
          glow: result.status == 'live',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: result.status == 'live'
                            ? [
                                IrisTokens.success,
                                IrisTokens.success.withValues(alpha: 0.8),
                              ]
                            : [purple, IrisTokens.purpleLight],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        result.teacherName.isNotEmpty
                            ? result.teacherName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.teacherName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${result.allSubjects.length} subject${result.allSubjects.length == 1 ? '' : 's'} · ${result.weeklySchedule.length} day${result.weeklySchedule.length == 1 ? '' : 's'}/week',
                          style: TextStyle(
                            fontSize: 12,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  _buildStatusBadge(result, isDark),
                ],
              ),
              const SizedBox(height: 14),
              // Status text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: result.status == 'live'
                      ? IrisTokens.success.withValues(alpha: isDark ? 0.15 : 0.1)
                      : purple.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: result.status == 'live'
                        ? IrisTokens.success.withValues(alpha: 0.2)
                        : purple.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      result.status == 'live'
                          ? Icons.location_on_rounded
                          : result.status == 'today'
                          ? Icons.schedule_rounded
                          : Icons.event_rounded,
                      size: 16,
                      color: result.status == 'live'
                          ? IrisTokens.success
                          : purple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.statusText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: result.status == 'live'
                              ? IrisTokens.success
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (profile != null) ...[
          const SizedBox(height: 10),
          GlassCard(
            enableOverlay: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: _resolveFacultyImageUrl(profile.image).isEmpty
                            ? Container(
                                color: IrisTokens.brand.withValues(alpha: 0.16),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: IrisTokens.brand,
                                  size: 22,
                                ),
                              )
                            : Image.network(
                                _resolveFacultyImageUrl(profile.image),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: IrisTokens.brand.withValues(alpha: 0.16),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: IrisTokens.brand,
                                    size: 22,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.department.isEmpty
                                ? 'Department unavailable'
                                : profile.department,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.72),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 13,
                                color: IrisTokens.purple.withValues(alpha: 0.76),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  profile.location.isEmpty
                                      ? 'Location unavailable'
                                      : profile.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.58),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: IrisTokens.brand.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: IrisTokens.brand.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Text(
                        _facultySourceLabel(_facultyProfilesSource),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: IrisTokens.brand.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasEmail
                            ? () => _launchFacultyEmail(profile.email)
                            : null,
                        icon: const Icon(Icons.mail_outline_rounded, size: 16),
                        label: Text(hasEmail ? 'Email' : 'No Email'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: IrisTokens.brand.withValues(alpha: 0.26),
                          ),
                          foregroundColor: IrisTokens.brand,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canCallNow
                            ? () => _launchFacultyPhone(profile.contact)
                            : null,
                        icon: Icon(
                          isLiveNow
                              ? Icons.do_not_disturb_on_rounded
                              : Icons.call_rounded,
                          size: 16,
                        ),
                        label: Text(
                          isLiveNow
                              ? 'In Class'
                              : (hasPhone ? 'Call' : 'No Phone'),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: IrisTokens.success.withValues(alpha: 0.3),
                          ),
                          foregroundColor: IrisTokens.success,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isLiveNow
                      ? 'Smart tip: teacher appears live in class right now, so email is prioritized.'
                      : 'Smart tip: call is available when not in a live class.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.52,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (_facultyProfilesLoading) ...[
          const SizedBox(height: 10),
          GlassCard(
            enableOverlay: false,
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading live faculty profile...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMetricChip(
              icon: Icons.menu_book_rounded,
              label: '${result.allSubjects.length} subjects',
              color: IrisTokens.brand,
              isDark: isDark,
            ),
            _buildMetricChip(
              icon: Icons.today_rounded,
              label: '${result.todaySessions.length} today',
              color: IrisTokens.success,
              isDark: isDark,
            ),
            _buildMetricChip(
              icon: Icons.calendar_month_rounded,
              label: '${result.weeklySchedule.length} days/week',
              color: IrisTokens.warning,
              isDark: isDark,
            ),
          ],
        ),

        if (widget.onTeacherSelected != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onTeacherSelected?.call(result.teacherName);
                if (widget.closeOnTeacherSelect &&
                    Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Use this teacher for my schedule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],

        // Today's schedule (if any)
        if (result.todaySessions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'TODAY\'S SCHEDULE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
              ),
            ),
          ),
          ...result.todaySessions.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RepaintBoundary(
                child: _buildSessionTile(entry, isDark, showDay: false),
              ),
            ),
          ),
        ],

        // Weekly schedule
        if (result.weeklySchedule.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'FULL WEEKLY SCHEDULE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
              ),
            ),
          ),
          ..._buildWeeklySchedule(result, isDark),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(TeacherLocatorResult result, bool isDark) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (result.status) {
      case 'live':
        bg = IrisTokens.success;
        fg = Colors.white;
        label = 'LIVE';
        icon = Icons.circle;
        break;
      case 'today':
        bg = IrisTokens.brand;
        fg = Colors.white;
        label = 'TODAY';
        icon = Icons.today_rounded;
        break;
      default:
        bg = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.06);
        fg = isDark
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.black.withValues(alpha: 0.6);
        label = 'WEEKLY';
        icon = Icons.calendar_month_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: result.status == 'live'
            ? [BoxShadow(color: bg.withValues(alpha: 0.4), blurRadius: 8)]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result.status == 'live') ...[
            Icon(icon, size: 8, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(
    TeacherScheduleEntry entry,
    bool isDark, {
    bool showDay = true,
  }) {
    const purple = IrisTokens.purple;

    return GlassCard(
      enableOverlay: false,
      enableShadow: false,
      child: Row(
        children: [
          // Time column
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: entry.isLive
                  ? IrisTokens.success.withValues(alpha: isDark ? 0.15 : 0.1)
                  : purple.withValues(alpha: isDark ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  entry.startTime,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: entry.isLive ? IrisTokens.success : purple,
                  ),
                ),
                Container(
                  width: 1,
                  height: 8,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.1,
                  ),
                ),
                Text(
                  entry.endTime,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                      0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (entry.isLive) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: IrisTokens.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        entry.subject,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.room_rounded,
                      size: 13,
                      color: purple.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.room,
                      style: TextStyle(
                        fontSize: 12,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    if (showDay) ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.groups_rounded,
                        size: 13,
                        color: purple.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          entry.batch,
                          style: TextStyle(
                            fontSize: 11,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.4),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.groups_rounded,
                        size: 13,
                        color: purple.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          entry.batch,
                          style: TextStyle(
                            fontSize: 11,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.4),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (entry.isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: IrisTokens.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'NOW',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: IrisTokens.success,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          if (entry.isUpcoming && !entry.isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: IrisTokens.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'NEXT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: IrisTokens.brand,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildWeeklySchedule(TeacherLocatorResult result, bool isDark) {
    const purple = IrisTokens.purple;
    final sortedDays = result.weeklySchedule.keys.toList()..sort();
    final today = DateTime.now().weekday;

    return sortedDays.map((day) {
      final entries = result.weeklySchedule[day]!;
      final isToday = day == today;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? purple.withValues(alpha: isDark ? 0.2 : 0.12)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: purple.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Text(
                      TeacherScheduleEntry.dayNames[day - 1],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isToday
                            ? purple
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.black.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: purple.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${entries.length} class${entries.length == 1 ? '' : 'es'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                        0.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RepaintBoundary(
                  child: _buildSessionTile(entry, isDark, showDay: true),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _DepartmentClassesScreen extends StatefulWidget {
  final UniversityMemory memory;
  final String currentBatch;
  final OmniBrain? brain;
  final ValueChanged<String>? onRoleChanged;
  final bool showDock;
  final bool showBackButton;

  const _DepartmentClassesScreen({
    required this.memory,
    required this.currentBatch,
    this.brain,
    this.onRoleChanged,
    this.showDock = true,
    this.showBackButton = true,
    super.key,
  });

  @override
  State<_DepartmentClassesScreen> createState() =>
      _DepartmentClassesScreenState();
}


class _FacultyDirectoryScreen extends StatefulWidget {
  final OmniBrain? brain;
  final ValueChanged<String>? onRoleChanged;
  final UniversityMemory? memory;
  final String? currentBatch;

  const _FacultyDirectoryScreen({
    this.brain,
    this.onRoleChanged,
    this.memory,
    this.currentBatch,
    super.key,
  });

  @override
  State<_FacultyDirectoryScreen> createState() => _FacultyDirectoryScreenState();
}

class _FacultyDirectoryScreenState extends State<_FacultyDirectoryScreen> {
  static const String _backendBase = 'https://cui-helpdesk-backend.onrender.com';

  final HelpdeskFacultyService _service = HelpdeskFacultyService();
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  List<FacultyProfile> _all = const [];
  List<FacultyProfile> _filtered = const [];
  final Map<String, TeacherLocatorResult> _teacherInsightCache = {};
  bool _loading = true;
  String _error = '';
  String _query = '';
  String _selectedDepartment = 'All';
  String _selectedBlock = 'All';
  HelpdeskFacultySource _source = HelpdeskFacultySource.none;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    unawaited(_loadFaculty());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFaculty() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    final list = await _service.fetchOfflineOnly();
    if (!mounted) return;

    if (list.isEmpty) {
      setState(() {
        _all = const [];
        _filtered = const [];
        _loading = false;
        _error = 'Unable to load faculty directory right now.';
        _source = HelpdeskFacultySource.none;
      });
      return;
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _all = list;
      _loading = false;
      _source = HelpdeskFacultySource.cache;
    });
    _applyFilter();
  }

  String _sourceLabel(HelpdeskFacultySource source) {
    switch (source) {
      case HelpdeskFacultySource.live:
        return 'LIVE';
      case HelpdeskFacultySource.cache:
        return 'CACHE';
      case HelpdeskFacultySource.backup:
        return 'BACKUP';
      case HelpdeskFacultySource.none:
        return 'OFFLINE';
    }
  }

  String _resolveImageUrl(String raw) {
    final image = raw.trim();
    if (image.isEmpty) return '';
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }
    if (image.startsWith('/')) return '$_backendBase$image';
    return '$_backendBase/$image';
  }

  String _blockFromLocation(String location) {
    final value = location.trim();
    if (value.isEmpty) return 'Unknown';
    final upper = value.toUpperCase();
    if (upper.contains('A BLOCK')) return 'A Block';
    if (upper.contains('B BLOCK')) return 'B Block';
    if (upper.contains('C BLOCK')) return 'C Block';
    if (upper.contains('D BLOCK')) return 'D Block';
    return value;
  }

  List<String> get _departments {
    final items = _all
        .map((e) => e.department.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...items];
  }

  List<String> get _blocks {
    final items = _all
        .map((e) => _blockFromLocation(e.location))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...items];
  }

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    final result = _all.where((item) {
      final departmentOk = _selectedDepartment == 'All' ||
          item.department.toLowerCase() == _selectedDepartment.toLowerCase();
      final blockOk = _selectedBlock == 'All' ||
          _blockFromLocation(item.location).toLowerCase() ==
              _selectedBlock.toLowerCase();

      if (!departmentOk || !blockOk) return false;
      if (q.isEmpty) return true;

      return item.name.toLowerCase().contains(q) ||
          item.department.toLowerCase().contains(q) ||
          item.location.toLowerCase().contains(q) ||
          item.email.toLowerCase().contains(q) ||
          item.contact.toLowerCase().contains(q);
    }).toList();

    setState(() {
      _filtered = result;
    });
  }

  TeacherLocatorResult? _teacherInsight(String teacherName) {
    final brain = widget.brain;
    if (brain == null) return null;
    return _teacherInsightCache.putIfAbsent(
      teacherName,
      () => brain.locateTeacher(teacherName, DateTime.now()),
    );
  }

  Future<void> _openTeacherLocator(FacultyProfile item) async {
    if (widget.brain == null) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'faculty_locator_brain_missing',
        content: const Text('Teacher locator is unavailable right now.'),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TeacherLocatorScreen(
          brain: widget.brain!,
          onRoleChanged: widget.onRoleChanged,
          memory: widget.memory,
          currentBatch: widget.currentBatch,
          initialTeacherQuery: item.name,
          autoSearchInitial: true,
          showDock: false,
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'faculty_phone_unavailable',
        content: const Text('Phone number unavailable for this faculty member.'),
      );
      return;
    }
    final uri = Uri.parse('tel:$normalized');
    if (await canLaunchUrl(uri)) {
      IrisSfx.pillTap();
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'faculty_phone_launch_failed',
      content: const Text('Unable to open dialer on this device.'),
    );
  }

  Future<void> _launchEmail(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'not available') {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'faculty_email_unavailable',
        content: const Text('Email unavailable for this faculty member.'),
      );
      return;
    }
    final uri = Uri.parse('mailto:$normalized');
    if (await canLaunchUrl(uri)) {
      IrisSfx.pillTap();
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    showIrisFrostedSnackBar(
      context,
      dedupeKey: 'faculty_email_launch_failed',
      content: const Text('Unable to open email client on this device.'),
    );
  }

  Widget _buildFilterStrip({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.42),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final value = options[i];
              final active = selected == value;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  IrisHaptics.chipSelect();
                  onChanged(value);
                },
                child: AnimatedContainer(
                  duration: IrisMotion.fast,
                  curve: IrisMotion.standard,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? IrisTokens.brand.withValues(alpha: isDark ? 0.24 : 0.14)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? IrisTokens.brand.withValues(alpha: 0.40)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : Colors.black.withValues(alpha: 0.10)),
                    ),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: active
                          ? IrisTokens.brand
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.82)
                                : Colors.black.withValues(alpha: 0.75)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFacultyTile(FacultyProfile item, bool isDark) {
    final imageUrl = _resolveImageUrl(item.image);
    final insight = _teacherInsight(item.name);
    final status = insight?.status ?? 'unknown';
    final statusText = insight?.statusText ?? '';

    Color statusColor() {
      switch (status) {
        case 'live':
          return IrisTokens.success;
        case 'today':
          return IrisTokens.brand;
        case 'weekly':
        case 'upcoming':
          return IrisTokens.warning;
        default:
          return IrisTokens.purple;
      }
    }

    final smartColor = statusColor();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openTeacherLocator(item),
      child: GlassCard(
        enableOverlay: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: imageUrl.isEmpty
                        ? Container(
                            color: IrisTokens.brand.withValues(alpha: 0.14),
                            child: const Icon(
                              Icons.person_rounded,
                              color: IrisTokens.brand,
                              size: 26,
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: IrisTokens.brand.withValues(alpha: 0.14),
                              child: const Icon(
                                Icons.person_rounded,
                                color: IrisTokens.brand,
                                size: 26,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.department.isEmpty
                            ? 'Department unavailable'
                            : item.department,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.56),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: IrisTokens.purple.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location.isEmpty
                                  ? 'Location unavailable'
                                  : item.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.58),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: smartColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: smartColor.withValues(alpha: 0.30)),
                  ),
                  child: Text(
                    status == 'live'
                        ? 'LIVE NOW'
                        : status == 'today'
                        ? 'TODAY'
                        : status == 'weekly' || status == 'upcoming'
                        ? 'UPCOMING'
                        : 'LOCATE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: smartColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText.isEmpty ? 'Tap card to open Teacher Locator' : statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.58),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchEmail(item.email),
                    icon: const Icon(Icons.mail_outline_rounded, size: 16),
                    label: const Text('Email'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: IrisTokens.brand.withValues(alpha: 0.24),
                      ),
                      foregroundColor: IrisTokens.brand,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchPhone(item.contact),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: IrisTokens.success.withValues(alpha: 0.28),
                      ),
                      foregroundColor: IrisTokens.success,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _AppBackButton(isDark: isDark),
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadFaculty,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [IrisTokens.brand, IrisTokens.purple],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.badge_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Faculty Directory',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  Text(
                                    'Live source with backup fallback',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: (isDark ? Colors.white : Colors.black)
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: IrisTokens.brand.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: IrisTokens.brand.withValues(alpha: 0.24),
                                      ),
                                    ),
                                    child: Text(
                                      _sourceLabel(_source),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.7,
                                        color: IrisTokens.brand.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GlassCard(
                          enableOverlay: false,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              _query = value;
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 120),
                                () {
                                  if (!mounted) return;
                                  _applyFilter();
                                },
                              );
                            },
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search faculty by name, dept, location...',
                              hintStyle: TextStyle(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.45),
                              ),
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        IrisHaptics.actionSoft();
                                        _searchController.clear();
                                        _query = '';
                                        _applyFilter();
                                      },
                                      icon: const Icon(Icons.clear_rounded),
                                    ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFilterStrip(
                          title: 'DEPARTMENT',
                          options: _departments,
                          selected: _selectedDepartment,
                          onChanged: (value) {
                            setState(() => _selectedDepartment = value);
                            _applyFilter();
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildFilterStrip(
                          title: 'BLOCK',
                          options: _blocks,
                          selected: _selectedBlock,
                          onChanged: (value) {
                            setState(() => _selectedBlock = value);
                            _applyFilter();
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_error.isNotEmpty)
                          GlassCard(
                            enableOverlay: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Directory unavailable',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton.icon(
                                    onPressed: _loadFaculty,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Try again'),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Text(
                            '${_filtered.length} result${_filtered.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._filtered.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildFacultyTile(item, isDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentClassesScreenState extends State<_DepartmentClassesScreen> {
  String? selectedProgram;
  int? selectedSemester;
  String? selectedSection;
  int? selectedDay;

  @override
  void initState() {
    super.initState();
    // Filter out batch-like programs and select the first valid one
    final validPrograms = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toList();
    if (validPrograms.isNotEmpty) {
      selectedProgram = validPrograms.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Filter out batch-like programs (FA##, SP##, etc.) to avoid Sem 0 display
    final programs = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toList();
    final selectedProgram = this.selectedProgram;

    List<ClassSession> displayedSessions = [];
    if (selectedProgram != null) {
      displayedSessions = widget.memory.sessions
          .where((s) => s.batchKey.program == selectedProgram)
          .toList();

      if (selectedSemester != null && selectedSemester! > 0) {
        displayedSessions = displayedSessions
            .where((s) => s.batchKey.semester == selectedSemester)
            .toList();
      }

      if (selectedSection != null) {
        displayedSessions = displayedSessions
            .where((s) => s.batchKey.section == selectedSection)
            .toList();
      }

      if (selectedDay != null) {
        displayedSessions = displayedSessions
            .where((s) => s.dayIndex == selectedDay)
            .toList();
      }
    }

    // Get unique semesters and sections for filters
    final semesters = selectedProgram == null
        ? []
        : widget.memory.semesters(selectedProgram);
    final sections = selectedProgram == null || selectedSemester == null
        ? []
        : widget.memory.sections(selectedProgram, selectedSemester ?? 1);

    // Get available days from filtered sessions
    final List<String> dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final availableDays = <int>{};

    var dayFilteredSessions = widget.memory.sessions;
    if (selectedProgram != null) {
      dayFilteredSessions = dayFilteredSessions
          .where((s) => s.batchKey.program == selectedProgram)
          .toList();
    }
    if (selectedSemester != null && selectedSemester! > 0) {
      dayFilteredSessions = dayFilteredSessions
          .where((s) => s.batchKey.semester == selectedSemester)
          .toList();
    }
    if (selectedSection != null) {
      dayFilteredSessions = dayFilteredSessions
          .where((s) => s.batchKey.section == selectedSection)
          .toList();
    }
    for (final session in dayFilteredSessions) {
      availableDays.add(session.dayIndex);
    }
    final sortedDays = availableDays.toList()..sort();
    final today = DateTime.now().weekday;
    final smartDays = List<int>.from(sortedDays);
    if (smartDays.contains(today)) {
      smartDays.remove(today);
      smartDays.insert(0, today);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        leading: widget.showBackButton ? _AppBackButton(isDark: isDark) : null,
      ),
      body: Stack(
        children: [
          _NeuralAura(background: isDark),
          SafeArea(
            child: CustomScrollView(
              physics: const ButterScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        // Header
                        _MotionSlideFade(
                          beginOffset: const Offset(0, 14),
                          duration: IrisMotion.medium,
                          curve: IrisMotion.entrance,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      IrisTokens.brand,
                                      IrisTokens.brandLight,
                                      IrisTokens.purpleLight,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: IrisTokens.brand.withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.school_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                            colors: [
                                              IrisTokens.brand,
                                              IrisTokens.brandLight,
                                            ],
                                          ).createShader(bounds),
                                      child: const Text(
                                        'Browse Classes',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 24,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'View classes from all departments',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Filters card
                        _MotionSlideFade(
                          beginOffset: const Offset(0, 18),
                          duration: IrisMotion.medium,
                          curve: IrisMotion.entrance,
                          child: GlassCard(
                            enableOverlay: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Department Filter
                                Text(
                                  'DEPARTMENT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: 0.4),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: programs
                                        .map(
                                          (program) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: _buildFilterChip(
                                              label: program,
                                              selected:
                                                  selectedProgram == program,
                                              color: IrisTokens.purple,
                                              isDark: isDark,
                                              onSelected: (selected) {
                                                if (selected) {
                                                  setState(() {
                                                    this.selectedProgram =
                                                        program;
                                                    selectedSemester = null;
                                                    selectedSection = null;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),

                                // Semester Filter
                                if (semesters.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'SEMESTER',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: semesters
                                          .map(
                                            (sem) => Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: _buildFilterChip(
                                                label: 'Sem $sem',
                                                selected:
                                                    selectedSemester == sem,
                                                color: const Color(0xFF06B6D4),
                                                isDark: isDark,
                                                onSelected: (selected) {
                                                  setState(() {
                                                    selectedSemester = selected
                                                        ? sem
                                                        : null;
                                                    selectedSection = null;
                                                  });
                                                },
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],

                                // Section Filter
                                if (sections.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'SECTION',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: sections
                                          .map(
                                            (section) => Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: _buildFilterChip(
                                                label: section,
                                                selected:
                                                    selectedSection == section,
                                                color: IrisTokens.success,
                                                isDark: isDark,
                                                onSelected: (selected) {
                                                  setState(() {
                                                    selectedSection = selected
                                                        ? section
                                                        : null;
                                                  });
                                                },
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],

                                // Day Filter
                                if (smartDays.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'DAY',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: smartDays
                                          .map(
                                            (day) => Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: _buildFilterChip(
                                                label: day == today
                                                    ? 'Today'
                                                    : dayNames[day - 1],
                                                selected: selectedDay == day,
                                                color: day == today
                                                    ? IrisTokens.success
                                                    : IrisTokens.warning,
                                                isDark: isDark,
                                                onSelected: (selected) {
                                                  setState(() {
                                                    selectedDay = selected
                                                        ? day
                                                        : null;
                                                  });
                                                },
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '${displayedSessions.length} classes found',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Classes list
                if (displayedSessions.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 118),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final session = displayedSessions[index];
                          final isInMySchedule =
                              widget.currentBatch == session.batchKey.batch;
                          final isLive = session.isLive(DateTime.now());
                          final programAccent = _accentForProgram(
                            session.batchKey.program,
                          );

                          return StaggeredListItem(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                enableOverlay: false,
                                enableShadow: false,
                                glow: isLive,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Time column
                                    Container(
                                      width: 54,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLive
                                            ? IrisTokens.success.withValues(alpha: 
                                                isDark ? 0.15 : 0.1,
                                              )
                                            : IrisTokens.brand.withValues(alpha: 
                                                isDark ? 0.1 : 0.06,
                                              ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            session.startTime,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isLive
                                                  ? IrisTokens.success
                                                  : IrisTokens.brand,
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 6,
                                            color:
                                                (isDark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withValues(alpha: 0.1),
                                          ),
                                          Text(
                                            session.endTime,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  (isDark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (isLive) ...[
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color:
                                                            IrisTokens.success,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  session.subject,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: isLive
                                                        ? IrisTokens.success
                                                        : (isDark
                                                              ? programAccent
                                                                    .withValues(alpha: 
                                                                      0.95,
                                                                    )
                                                              : programAccent
                                                                    .withValues(alpha: 
                                                                      0.90,
                                                                    )),
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isInMySchedule)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: programAccent
                                                        .withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: programAccent
                                                          .withValues(alpha: 0.2),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'MY CLASS',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: programAccent,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              _buildMetaChip(
                                                icon: Icons
                                                    .person_outline_rounded,
                                                text: session.teacher,
                                                color: IrisTokens.brand,
                                                isDark: isDark,
                                              ),
                                              _buildMetaChip(
                                                icon: Icons.room_rounded,
                                                text: session.room,
                                                color: IrisTokens.success,
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: IrisTokens.purple
                                                  .withValues(alpha: 
                                                    isDark ? 0.14 : 0.10,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: IrisTokens.purple
                                                    .withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Text(
                                              session.batchKey.batch,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: IrisTokens.purple,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: displayedSessions.length,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),

                // Empty state
                if (displayedSessions.isEmpty && selectedProgram != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: GlassCard(
                        enableOverlay: false,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.25),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No classes found',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try adjusting the filters',
                              style: TextStyle(
                                fontSize: 12,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _SmartScreenDock(
                  selectedIndex: 3,
                  onTeacher: widget.brain != null
                      ? () => pushIconLaunchRoute(
                          context,
                          page: _TeacherLocatorScreen(
                            brain: widget.brain!,
                            onRoleChanged: widget.onRoleChanged,
                            memory: widget.memory,
                            currentBatch: widget.currentBatch,
                          ),
                        )
                      : () {},
                  onPortal: () => pushIconLaunchRoute(
                    context,
                    page: const PortalScreen(
                      url: 'https://swl-sis.comsats.edu.pk/Login/Index',
                      title: 'COMSATS Student Portal',
                      sessionScope: 'student',
                    ),
                  ),
                  onClasses: () {},
                  onTools: widget.brain != null
                      ? () => pushIconLaunchRoute(
                          context,
                          page: _ToolsScreen(
                            memory: widget.memory,
                            batch: widget.currentBatch,
                            brain: widget.brain!,
                            onRoleChanged: widget.onRoleChanged,
                          ),
                        )
                      : () {
                          showIrisFrostedSnackBar(
                            context,
                            dedupeKey: 'tools_unavailable_session',
                            content: Text(
                              'Tools view is unavailable for this session.',
                            ),
                          );
                        },
                  onAbout: () => pushIconLaunchRoute(
                    context,
                    page: AboutScreen(onRoleChanged: widget.onRoleChanged),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _accentForProgram(String program) {
    final key = program.toLowerCase();
    if (key.contains('cs') || key.contains('computer')) return IrisTokens.brand;
    if (key.contains('se') || key.contains('software')) return IrisTokens.blue;
    if (key.contains('it') || key.contains('information'))
      return const Color(0xFF06B6D4);
    if (key.contains('ee') || key.contains('electrical'))
      return IrisTokens.warning;
    if (key.contains('ai') || key.contains('ml')) return IrisTokens.purple;
    if (key.contains('mech') || key.contains('mechanical'))
      return IrisTokens.error;
    return IrisTokens.success;
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Color color,
    required bool isDark,
    required ValueChanged<bool> onSelected,
  }) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: IrisMotion.fast,
        curve: IrisMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        margin: const EdgeInsets.symmetric(vertical: 2),
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          color: selected
              ? color
              : isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.8)
                : isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: -6,
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                    0.75,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MakeupLectureScheduler extends StatefulWidget {
  final UniversityMemory memory;
  final OmniBrain brain;
  final String batch;
  final Future<void> Function(ClassSession session) onAddMakeupClass;
  final Future<void> Function(ClassSession session)? onRemoveMakeupClass;
  final ValueChanged<String>? onRoleChanged;
  final bool showDock;
  final bool showBackButton;

  const MakeupLectureScheduler({
    required this.memory,
    required this.brain,
    required this.batch,
    required this.onAddMakeupClass,
    this.onRemoveMakeupClass,
    this.onRoleChanged,
    this.showDock = true,
    this.showBackButton = true,
    super.key,
  });

  @override
  State<MakeupLectureScheduler> createState() => _MakeupLectureSchedulerState();
}

class _MakeupLectureSchedulerState extends State<MakeupLectureScheduler> {
  late TextEditingController _teacherController;
  String? _selectedTeacher;
  String? _selectedSuggestionKey;
  bool _autoSelectedTeacher = false;
  List<MakeupSlotSuggestion> _suggestions = [];
  List<MakeupSlotSuggestion> _filteredSuggestions = [];
  List<String> _filteredTeachers = [];
  bool _isLoading = false;
  final List<String> _allTeachers = [];

  // Smart filters
  int? _filterDayIndex;
  double _minDuration = 0.5;
  int _minRooms = 0;
  String _sortBy = 'earliest'; // 'earliest', 'duration', 'rooms'

  @override
  void initState() {
    super.initState();
    _teacherController = TextEditingController();
    // Get all teachers from memory
    final teachers = <String>{};
    for (final session in widget.memory.sessions) {
      teachers.add(session.teacher);
    }
    _allTeachers.addAll(teachers.toList()..sort());
    _filteredTeachers = List.from(_allTeachers);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait for route transition to complete before heavy slot discovery.
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) _autoSelectSmartTeacher();
      });
    });
  }

  @override
  void dispose() {
    _teacherController.dispose();
    super.dispose();
  }

  void _updateTeacherSuggestions(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredTeachers = List.from(_allTeachers));
      return;
    }
    final q = query.toLowerCase().trim();
    final matches = _allTeachers
        .where((t) => t.toLowerCase().contains(q))
        .toList();
    setState(() => _filteredTeachers = matches);
  }

  void _selectTeacher(String teacher) {
    setState(() {
      _selectedTeacher = teacher;
      _selectedSuggestionKey = null;
      _autoSelectedTeacher = false;
      _teacherController.text = teacher;
      _filteredTeachers = [];
    });
    IrisHaptics.chipSelect();
    _findMakeupSlots();
  }

  String? _pickSmartTeacherForBatch() {
    final now = DateTime.now();
    final nowVal = now.hour + (now.minute / 60.0);
    final batchSessions = widget.memory.sessions
        .where(
          (s) =>
              s.batchKey.batch == widget.batch && !s.id.startsWith('makeup_'),
        )
        .toList();
    if (batchSessions.isEmpty) return null;

    final today = batchSessions
        .where((s) => s.dayIndex == now.weekday)
        .toList();
    today.sort((a, b) => a.safeStartVal.compareTo(b.safeStartVal));

    final live = today
        .where((s) => s.safeStartVal <= nowVal && nowVal < s.safeEndVal)
        .toList();
    if (live.isNotEmpty) return live.first.teacher;

    final upcoming = today.where((s) => s.safeStartVal > nowVal).toList();
    if (upcoming.isNotEmpty) return upcoming.first.teacher;

    final frequency = <String, int>{};
    for (final session in batchSessions) {
      final key = session.teacher.trim();
      if (key.isEmpty) continue;
      frequency.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    if (frequency.isEmpty) return null;
    return frequency.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  void _autoSelectSmartTeacher() {
    if (_selectedTeacher != null || _isLoading || _allTeachers.isEmpty) return;

    final smartTeacher = _pickSmartTeacherForBatch();
    if (smartTeacher == null || !_allTeachers.contains(smartTeacher)) return;

    setState(() {
      _selectedTeacher = smartTeacher;
      _teacherController.text = smartTeacher;
      _selectedSuggestionKey = null;
      _filteredTeachers = [];
      _autoSelectedTeacher = true;
    });

    _findMakeupSlots();
  }

  String _timeFromDecimal(double value) {
    final hour = value.floor().clamp(0, 23);
    final minute = ((value - value.floor()) * 60).round().clamp(0, 59);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _slotKey(MakeupSlotSuggestion suggestion) {
    final teacherKey = (_selectedTeacher ?? '').trim().toLowerCase();
    return '${suggestion.dayIndex}_${suggestion.startTime.toStringAsFixed(3)}_${suggestion.endTime.toStringAsFixed(3)}_$teacherKey';
  }

  bool _sameTimeSlot(ClassSession session, MakeupSlotSuggestion suggestion) {
    return session.dayIndex == suggestion.dayIndex &&
        (session.safeStartVal - suggestion.startTime).abs() < 0.001 &&
        (session.safeEndVal - suggestion.endTime).abs() < 0.001;
  }

  ClassSession? _existingMakeupSessionForSuggestion(
    MakeupSlotSuggestion suggestion,
  ) {
    final teacher = _selectedTeacher?.trim().toLowerCase();
    if (teacher == null || teacher.isEmpty) return null;

    for (final session in widget.memory.sessions) {
      if (!session.id.startsWith('makeup_')) continue;
      if (session.batchKey.batch != widget.batch) continue;
      if (session.teacher.trim().toLowerCase() != teacher) continue;
      if (_sameTimeSlot(session, suggestion)) return session;
    }
    return null;
  }

  bool _sessionsOverlapWithSuggestion(
    ClassSession session,
    MakeupSlotSuggestion suggestion,
  ) {
    if (session.dayIndex != suggestion.dayIndex) return false;
    return session.safeStartVal < suggestion.endTime &&
        suggestion.startTime < session.safeEndVal;
  }

  ClassSession? _regularConflictForSuggestion(MakeupSlotSuggestion suggestion) {
    for (final session in widget.memory.sessions) {
      if (session.batchKey.batch != widget.batch) continue;
      if (session.id.startsWith('makeup_')) continue;
      if (_sessionsOverlapWithSuggestion(session, suggestion)) return session;
    }
    return null;
  }

  List<ClassSession> _overlappingMakeupsForSuggestion(
    MakeupSlotSuggestion suggestion,
  ) {
    final teacher = _selectedTeacher?.trim().toLowerCase();
    return widget.memory.sessions.where((session) {
      if (!session.id.startsWith('makeup_')) return false;
      if (session.batchKey.batch != widget.batch) return false;
      if (!_sessionsOverlapWithSuggestion(session, suggestion)) return false;
      if (teacher != null &&
          teacher.isNotEmpty &&
          session.teacher.trim().toLowerCase() == teacher &&
          _sameTimeSlot(session, suggestion)) {
        return false;
      }
      return true;
    }).toList();
  }

  String _inferMakeupSubject(String teacher) {
    final teacherKey = teacher.trim().toLowerCase();
    final frequency = <String, int>{};
    for (final session in widget.memory.sessions) {
      if (session.batchKey.batch != widget.batch) continue;
      if (session.id.startsWith('makeup_')) continue;
      if (session.teacher.trim().toLowerCase() != teacherKey) continue;
      final subject = session.subject.trim();
      if (subject.isEmpty) continue;
      frequency.update(subject, (count) => count + 1, ifAbsent: () => 1);
    }
    if (frequency.isEmpty) return 'Makeup Class';
    return frequency.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _pickBestRoom(MakeupSlotSuggestion suggestion, String teacher) {
    final available = suggestion.availableRooms;
    if (available == null || available.isEmpty) {
      return 'TBD';
    }

    final teacherKey = teacher.trim().toLowerCase();
    final roomFrequency = <String, int>{};
    for (final session in widget.memory.sessions) {
      if (session.batchKey.batch != widget.batch) continue;
      if (session.teacher.trim().toLowerCase() != teacherKey) continue;
      final room = session.room.trim();
      if (room.isEmpty) continue;
      roomFrequency.update(room, (count) => count + 1, ifAbsent: () => 1);
    }

    final rankedRooms = available.toList();
    rankedRooms.sort((a, b) {
      final aScore = roomFrequency[a] ?? 0;
      final bScore = roomFrequency[b] ?? 0;
      return bScore.compareTo(aScore);
    });

    return rankedRooms.first;
  }

  ClassSession _buildMakeupSession(MakeupSlotSuggestion suggestion) {
    final teacher = _selectedTeacher ?? 'Unknown Teacher';
    final inferredSubject = _inferMakeupSubject(teacher);
    final start = _timeFromDecimal(suggestion.startTime);
    final end = _timeFromDecimal(suggestion.endTime);
    final room = _pickBestRoom(suggestion, teacher);
    final teacherSlug = teacher
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final slotSlug =
        '${suggestion.dayIndex}_${(suggestion.startTime * 100).round()}_${(suggestion.endTime * 100).round()}';

    return ClassSession(
      id: 'makeup_${widget.batch}_${teacherSlug}_$slotSlug',
      batchKey: BatchKey.parse(widget.batch),
      dayIndex: suggestion.dayIndex,
      startTime: start,
      endTime: end,
      subject: inferredSubject,
      teacher: teacher,
      room: room,
    );
  }

  Future<void> _handleSuggestionAction(MakeupSlotSuggestion suggestion) async {
    if (_selectedTeacher == null || _selectedTeacher!.isEmpty) return;

    final existing = _existingMakeupSessionForSuggestion(suggestion);
    final regularConflict = _regularConflictForSuggestion(suggestion);

    if (existing == null && regularConflict != null) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_slot_conflict_${regularConflict.id}',
        content: Text(
          'Cannot add: conflicts with ${regularConflict.subject} (${regularConflict.startTime}-${regularConflict.endTime}).',
        ),
      );
      return;
    }

    if (existing != null) {
      if (widget.onRemoveMakeupClass != null) {
        await widget.onRemoveMakeupClass!(existing);
      }
    } else {
      final session = _buildMakeupSession(suggestion);
      await widget.onAddMakeupClass(session);
    }

    if (!mounted) return;
    setState(() {});
  }

  void _findMakeupSlots() {
    if (_selectedTeacher == null || _selectedTeacher!.isEmpty) {
      showIrisFrostedSnackBar(
        context,
        dedupeKey: 'makeup_select_teacher_first',
        content: const Text('Please select a teacher'),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Yield one frame so loading state can paint before heavy computation starts.
    Future.delayed(Duration.zero, () {
      if (!mounted) return;

      final computed = widget.brain.findMakeupSlots(
        widget.batch,
        _selectedTeacher!,
      );
      setState(() {
        _suggestions = computed;
        _applyFiltersAndSort();
      });

      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() => _isLoading = false);

          if (_filteredSuggestions.isEmpty) {
            showIrisFrostedSnackBar(
              context,
              dedupeKey: _suggestions.isEmpty
                  ? 'makeup_slots_none_common'
                  : 'makeup_slots_none_filtered',
              content: Text(
                _suggestions.isEmpty
                    ? 'No common free slots found'
                    : 'No slots match your filters. Try adjusting them.',
              ),
            );
          }
        }
      });
    });
  }

  Future<void> _openTeacherFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: _TeacherLocatorScreen(
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
        memory: widget.memory,
        currentBatch: widget.batch,
      ),
    );
  }

  Future<void> _openPortalFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: const PortalScreen(
        url: 'https://swl-sis.comsats.edu.pk/Login/Index',
        title: 'COMSATS Student Portal',
        sessionScope: 'student',
      ),
    );
  }

  Future<void> _openClassesFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: _DepartmentClassesScreen(
        memory: widget.memory,
        currentBatch: widget.batch,
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
      ),
    );
  }

  Future<void> _openToolsFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: _ToolsScreen(
        memory: widget.memory,
        batch: widget.batch,
        brain: widget.brain,
        onRoleChanged: widget.onRoleChanged,
      ),
    );
  }

  Future<void> _openAboutFromMakeup() async {
    if (!mounted) return;
    await pushIconLaunchRoute(
      context,
      lightweight: true,
      transitionDuration: const Duration(milliseconds: 304),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      page: AboutScreen(onRoleChanged: widget.onRoleChanged),
    );
  }

  void _applyFiltersAndSort() {
    var filtered = List<MakeupSlotSuggestion>.from(_suggestions);

    // Apply filters
    if (_filterDayIndex != null) {
      filtered = filtered.where((s) => s.dayIndex == _filterDayIndex).toList();
    }
    if (_minDuration > 0.5) {
      filtered = filtered
          .where((s) => s.durationHours >= _minDuration)
          .toList();
    }
    if (_minRooms > 0) {
      filtered = filtered
          .where(
            (s) =>
                s.availableRooms != null &&
                s.availableRooms!.length >= _minRooms,
          )
          .toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'earliest':
        filtered.sort((a, b) {
          final dayCompare = a.dayIndex.compareTo(b.dayIndex);
          if (dayCompare != 0) return dayCompare;
          return a.startTime.compareTo(b.startTime);
        });
        break;
      case 'duration':
        filtered.sort((a, b) => b.durationHours.compareTo(a.durationHours));
        break;
      case 'rooms':
        filtered.sort((a, b) {
          final aRooms = a.availableRooms?.length ?? 0;
          final bRooms = b.availableRooms?.length ?? 0;
          return bRooms.compareTo(aRooms);
        });
        break;
    }

    _filteredSuggestions = filtered;
  }

  void _resetFilters() {
    setState(() {
      _filterDayIndex = null;
      _minDuration = 0.5;
      _minRooms = 0;
      _sortBy = 'earliest';
      _applyFiltersAndSort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const purple = IrisTokens.purple;
    const purpleLight = IrisTokens.purpleLight;
    const indigo = IrisTokens.brand;
    const amber = Color(0xFFF59E0B);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        leading: widget.showBackButton ? _AppBackButton(isDark: isDark) : null,
      ),
      body: Stack(
        children: [
          // Neural aura background
          _NeuralAura(background: isDark),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          purple.withValues(alpha: 0.18),
                          indigo.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: purple.withValues(alpha: isDark ? 0.35 : 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [purple, purpleLight, purpleLight],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: purple.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [purple, purpleLight],
                                    ).createShader(bounds),
                                child: const Text(
                                  'Schedule Makeup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 26,
                                    letterSpacing: 0.3,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Find free slots with your teacher',
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 0.1,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Search card
                  GlassCard(
                    enableOverlay: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: purple.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Teacher',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.7),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Search field
                        AnimatedContainer(
                          duration: IrisMotion.fast,
                          curve: IrisMotion.standard,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      Colors.black.withValues(alpha: 0.50),
                                      Colors.black.withValues(alpha: 0.45),
                                    ]
                                  : [
                                      Colors.white.withValues(alpha: 0.85),
                                      Colors.white.withValues(alpha: 0.80),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              IrisTokens.radius20,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : IrisTokens.brand.withValues(alpha: 0.10),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: IrisTokens.brand.withValues(
                                  alpha: isDark ? 0.08 : 0.06,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                                spreadRadius: -2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.25 : 0.04,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _teacherController,
                            onChanged: (value) {
                              _updateTeacherSuggestions(value);
                              setState(() {});
                            },
                            textInputAction: TextInputAction.search,
                            enabled: !_isLoading,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search by name...',
                              hintStyle: TextStyle(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.40),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                              prefixIcon: const Icon(
                                Icons.person_search_rounded,
                                color: IrisTokens.brand,
                                size: 24,
                              ),
                              suffixIcon:
                                  _selectedTeacher != null ||
                                      _teacherController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.45),
                                        size: 22,
                                      ),
                                      splashRadius: 22,
                                      onPressed: () {
                                        IrisHaptics.actionSoft();
                                        _teacherController.clear();
                                        setState(() {
                                          _selectedTeacher = null;
                                          _selectedSuggestionKey = null;
                                          _autoSelectedTeacher = false;
                                          _filteredTeachers = List.from(
                                            _allTeachers,
                                          );
                                          _suggestions = [];
                                          _filteredSuggestions = [];
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: IrisTokens.space20,
                                vertical: IrisTokens.space20,
                              ),
                            ),
                          ),
                        ),
                        // Filtered suggestions dropdown
                        if (_filteredTeachers.isNotEmpty &&
                            _teacherController.text.isNotEmpty)
                          Column(
                            children: [
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : Colors.black.withValues(alpha: 0.06),
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  maxHeight: 220,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  itemCount: _filteredTeachers.length,
                                  itemBuilder: (context, index) {
                                    final teacher = _filteredTeachers[index];
                                    final isSelected =
                                        _selectedTeacher == teacher;
                                    return InkWell(
                                      onTap: () => _selectTeacher(teacher),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? purple.withValues(alpha: 
                                                  isDark ? 0.16 : 0.10,
                                                )
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? Icons.check_circle_rounded
                                                  : Icons.person_rounded,
                                              size: 16,
                                              color: isSelected
                                                  ? purple
                                                  : (isDark
                                                            ? Colors.white
                                                            : Colors.black)
                                                        .withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                teacher,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        if (_selectedTeacher != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: purple.withValues(alpha: isDark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: purple.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                  color: IrisTokens.purple,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedTeacher!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 
                                      isDark ? 0.08 : 0.7,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _autoSelectedTeacher
                                        ? 'Smart Pick'
                                        : 'Selected',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Find Slots Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _selectedTeacher == null
                          ? null
                          : _findMakeupSlots,
                      icon: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(
                        _isLoading ? 'Searching...' : 'Find Available Slots',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: purple.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                        shadowColor: purple.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Results with Filters and Sort
                  if (_suggestions.isNotEmpty) ...[
                    // Statistics Summary
                    GlassCard(
                      enableOverlay: false,
                      enableShadow: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics_rounded,
                                size: 16,
                                color: purple.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Summary',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                Icons.event_available_rounded,
                                _filteredSuggestions.length.toString(),
                                'Slots',
                                isDark,
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: purple.withValues(alpha: 0.2),
                              ),
                              _buildStatItem(
                                Icons.access_time_rounded,
                                '${_filteredSuggestions.fold<double>(0, (sum, s) => sum + s.durationHours).toStringAsFixed(1)}h',
                                'Total',
                                isDark,
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: purple.withValues(alpha: 0.2),
                              ),
                              _buildStatItem(
                                Icons.meeting_room_rounded,
                                _filteredSuggestions
                                    .where(
                                      (s) =>
                                          (s.availableRooms?.isNotEmpty ??
                                          false),
                                    )
                                    .length
                                    .toString(),
                                'With Rooms',
                                isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filter & Sort Controls
                    GlassCard(
                      enableOverlay: false,
                      enableShadow: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 16,
                                color: purple.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Filters & Sorting',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _resetFilters,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: amber.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: amber.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'Reset',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: amber,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Day Filter
                              Expanded(
                                child: _buildFilterChip(
                                  icon: Icons.calendar_today_rounded,
                                  label: _filterDayIndex == null
                                      ? 'All Days'
                                      : [
                                          'Mon',
                                          'Tue',
                                          'Wed',
                                          'Thu',
                                          'Fri',
                                          'Sat',
                                          'Sun',
                                        ][_filterDayIndex! - 1],
                                  onTap: () => _showDayFilter(isDark),
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Sort
                              Expanded(
                                child: _buildFilterChip(
                                  icon: Icons.sort_rounded,
                                  label: _sortBy == 'earliest'
                                      ? 'Earliest'
                                      : _sortBy == 'duration'
                                      ? 'Longest'
                                      : 'Most Rooms',
                                  onTap: () => _showSortOptions(isDark),
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Slots Header
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [purple, purpleLight],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Available Slots',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_filteredSuggestions.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Slots List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredSuggestions.length,
                      separatorBuilder: (_, index2) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final suggestion = _filteredSuggestions[index];
                        return _buildMakeupSlotCard(suggestion, isDark);
                      },
                    ),
                    const SizedBox(height: 20),
                  ] else if (!_isLoading && _selectedTeacher != null) ...[
                    GlassCard(
                      enableOverlay: false,
                      enableShadow: false,
                      child: Row(
                        children: [
                          Icon(Icons.info_rounded, color: amber, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'No common free slots found. Try another teacher.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
          if (widget.showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _SmartScreenDock(
                  selectedIndex: 5,
                  onTeacher: _openTeacherFromMakeup,
                  onPortal: _openPortalFromMakeup,
                  onClasses: _openClassesFromMakeup,
                  onTools: _openToolsFromMakeup,
                  onMakeup: () {},
                  onAbout: _openAboutFromMakeup,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMakeupSlotCard(MakeupSlotSuggestion suggestion, bool isDark) {
    final slotKey = _slotKey(suggestion);
    final isSelected = _selectedSuggestionKey == slotKey;
    final existing = _existingMakeupSessionForSuggestion(suggestion);
    final isAdded = existing != null;
    final regularConflict = _regularConflictForSuggestion(suggestion);
    final overlappingMakeups = _overlappingMakeupsForSuggestion(suggestion);
    final isBlocked = regularConflict != null && !isAdded;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IrisTokens.brand.withValues(
              alpha: isSelected
                  ? (isDark ? 0.22 : 0.14)
                  : (isDark ? 0.14 : 0.08),
            ),
            IrisTokens.brandLight.withValues(
              alpha: isSelected
                  ? (isDark ? 0.14 : 0.10)
                  : (isDark ? 0.10 : 0.06),
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? IrisTokens.brand.withValues(alpha: 0.46)
              : IrisTokens.brand.withValues(alpha: 0.28),
          width: isSelected ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: IrisTokens.brand.withValues(alpha: isDark ? 0.2 : 0.12),
            blurRadius: isSelected ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _selectedSuggestionKey = slotKey);
          IrisHaptics.actionSoft();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day and Time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [IrisTokens.brand, IrisTokens.brandLight],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      suggestion.dayName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion.timeRangeString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: IrisTokens.brand,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: IrisTokens.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: IrisTokens.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${suggestion.durationHours.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: IrisTokens.success,
                      ),
                    ),
                  ),
                ],
              ),
              if (isAdded) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: IrisTokens.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.success.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: IrisTokens.success,
                        size: 15,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Already in your timeline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: IrisTokens.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isBlocked) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: IrisTokens.error.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.error.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: IrisTokens.error,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Conflicts with ${regularConflict.subject} (${regularConflict.startTime}-${regularConflict.endTime})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: IrisTokens.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (!isAdded && overlappingMakeups.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: IrisTokens.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.brand.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.autorenew_rounded,
                        color: IrisTokens.brand,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Will replace ${overlappingMakeups.length} overlapping makeup slot${overlappingMakeups.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: IrisTokens.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Suggested free window',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.55,
                  ),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),

              // Available Rooms
              if (suggestion.availableRooms != null &&
                  suggestion.availableRooms!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: IrisTokens.success.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: IrisTokens.success.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_rounded,
                            size: 16,
                            color: IrisTokens.success,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Available Rooms (${suggestion.availableRooms!.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: IrisTokens.success,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: suggestion.availableRooms!
                            .take(10) // Show max 10 rooms
                            .map(
                              (room) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: IrisTokens.success.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: IrisTokens.success.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  room,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (suggestion.availableRooms!.length > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+${suggestion.availableRooms!.length - 10} more rooms',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: IrisTokens.success.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.orange.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No rooms available during this slot',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedTeacher == null || isBlocked)
                      ? null
                      : () => _handleSuggestionAction(suggestion),
                  icon: Icon(
                    isBlocked
                        ? Icons.block_rounded
                        : (isAdded
                              ? Icons.remove_circle_outline_rounded
                              : Icons.add_circle_outline_rounded),
                  ),
                  label: Text(
                    isBlocked
                        ? 'Conflicting Slot'
                        : (isAdded
                              ? 'Remove From Timeline'
                              : 'Add To Timeline'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlocked
                        ? (isDark ? Colors.white24 : Colors.black26)
                        : (isAdded ? IrisTokens.error : IrisTokens.brand),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              if (!isAdded && !isBlocked) ...[
                const SizedBox(height: 8),
                Text(
                  overlappingMakeups.isNotEmpty
                      ? 'This will replace overlapping makeup slots and keep restore history.'
                      : 'If this overlaps another makeup slot, the app replaces it intelligently.',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    bool isDark,
  ) {
    return Column(
      children: [
        Icon(icon, color: IrisTokens.brand, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: IrisTokens.brand.withValues(alpha: isDark ? 0.16 : 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.3)),
          boxShadow: const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: IrisTokens.brand),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDayFilter(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: (isDark ? const Color(0xFF111827) : Colors.white)
              .withValues(alpha: isDark ? 0.88 : 0.92),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.12,
              ),
            ),
          ),
          title: const Text('Filter by Day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Days'),
                leading: Radio<int?>(
                  value: null,
                  groupValue: _filterDayIndex,
                  onChanged: (val) {
                    setState(() {
                      _filterDayIndex = val;
                      _applyFiltersAndSort();
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
              ...List.generate(7, (i) {
                final days = [
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday',
                ];
                return ListTile(
                  title: Text(days[i]),
                  leading: Radio<int?>(
                    value: i + 1,
                    groupValue: _filterDayIndex,
                    onChanged: (val) {
                      setState(() {
                        _filterDayIndex = val;
                        _applyFiltersAndSort();
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortOptions(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: (isDark ? const Color(0xFF111827) : Colors.white)
              .withValues(alpha: isDark ? 0.88 : 0.92),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.12,
              ),
            ),
          ),
          title: const Text('Sort By'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ListTile(
              title: const Text('Earliest First'),
              leading: Radio<String>(
                value: 'earliest',
                groupValue: _sortBy,
                onChanged: (val) {
                  setState(() {
                    _sortBy = val!;
                    _applyFiltersAndSort();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            ListTile(
              title: const Text('Longest Duration'),
              leading: Radio<String>(
                value: 'duration',
                groupValue: _sortBy,
                onChanged: (val) {
                  setState(() {
                    _sortBy = val!;
                    _applyFiltersAndSort();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            ListTile(
              title: const Text('Most Rooms Available'),
              leading: Radio<String>(
                value: 'rooms',
                groupValue: _sortBy,
                onChanged: (val) {
                  setState(() {
                    _sortBy = val!;
                    _applyFiltersAndSort();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
