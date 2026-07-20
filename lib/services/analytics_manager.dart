import 'package:flutter/material.dart';
import 'dart:ui';

/// Comprehensive analytics and crash reporting system
class AnalyticsManager {
  static final AnalyticsManager _instance = AnalyticsManager._internal();
  
  factory AnalyticsManager() {
    return _instance;
  }
  
  AnalyticsManager._internal();
  
  final List<AnalyticsEvent> _events = [];
  final List<CrashReport> _crashes = [];
  
  static const int _maxEventsKept = 1000;
  static const int _maxCrashesKept = 100;

  /// Record user action
  void trackEvent(
    String eventName, {
    Map<String, dynamic>? properties,
  }) {
    final event = AnalyticsEvent(
      name: eventName,
      timestamp: DateTime.now(),
      properties: properties ?? {},
    );
    
    _events.add(event);
    
    // Keep memory bounded
    if (_events.length > _maxEventsKept) {
      _events.removeAt(0);
    }
    
    debugPrint('📊 Event tracked: $eventName');
  }

  /// Record user engagement
  void trackScreenView(String screenName) {
    trackEvent('screen_view', properties: {'screen': screenName});
  }

  /// Record timing metric
  void trackTiming(String category, String variable, int duration) {
    trackEvent('timing', properties: {
      'category': category,
      'variable': variable,
      'duration_ms': duration,
    });
  }

  /// Track exception/crash
  void trackException(
    dynamic exception,
    StackTrace? stackTrace, {
    String? context,
  }) {
    final crash = CrashReport(
      exception: exception.toString(),
      stackTrace: stackTrace?.toString() ?? 'No stack trace',
      context: context,
      timestamp: DateTime.now(),
    );
    
    _crashes.add(crash);
    
    // Keep memory bounded
    if (_crashes.length > _maxCrashesKept) {
      _crashes.removeAt(0);
    }
    
    debugPrint('❌ Exception tracked: $exception\nContext: $context');
  }

  /// Get analytics summary
  Map<String, dynamic> getAnalyticsSummary() {
    final eventCounts = <String, int>{};
    
    for (final event in _events) {
      eventCounts[event.name] = (eventCounts[event.name] ?? 0) + 1;
    }
    
    return {
      'total_events': _events.length,
      'event_counts': eventCounts,
      'total_crashes': _crashes.length,
      'last_event': _events.isNotEmpty ? _events.last.name : null,
      'last_crash': _crashes.isNotEmpty ? _crashes.last.exception : null,
    };
  }

  /// Get event history
  List<AnalyticsEvent> getEventHistory({
    String? filterByName,
    int? limit,
  }) {
    var events = _events;
    
    if (filterByName != null) {
      events = events.where((e) => e.name.contains(filterByName)).toList();
    }
    
    if (limit != null && events.length > limit) {
      events = events.sublist(events.length - limit);
    }
    
    return events;
  }

  /// Get crash reports
  List<CrashReport> getCrashReports({int? limit}) {
    var crashes = _crashes;
    
    if (limit != null && crashes.length > limit) {
      crashes = crashes.sublist(crashes.length - limit);
    }
    
    return crashes;
  }

  /// Print detailed report
  void printReport() {
    debugPrint('\n📊 Analytics Report:');
    debugPrint('Total events: ${_events.length}');
    debugPrint('Total crashes: ${_crashes.length}');
    
    final summary = getAnalyticsSummary();
    debugPrint('\nEvent Summary:');
    (summary['event_counts'] as Map).forEach((event, count) {
      debugPrint('  $event: $count');
    });
    
    if (_crashes.isNotEmpty) {
      debugPrint('\nRecent Crashes:');
      final recentCrashes = _crashes.length > 5 ? _crashes.sublist(_crashes.length - 5) : _crashes;
      for (final crash in recentCrashes) {
        debugPrint('  ${crash.timestamp}: ${crash.exception}');
        if (crash.context != null) {
          debugPrint('    Context: ${crash.context}');
        }
      }
    }
    debugPrint('');
  }

  /// Export analytics data (could be sent to backend)
  String exportAnalytics() {
    final summary = getAnalyticsSummary();
    final recentEvents = _events.length > 10 ? _events.sublist(_events.length - 10) : _events;
    final recentEventsStr = recentEvents.map((e) => '- ${e.timestamp}: ${e.name}').join('\n');
    final recentCrashes = _crashes.length > 5 ? _crashes.sublist(_crashes.length - 5) : _crashes;
    final recentCrashesStr = recentCrashes.map((c) => '- ${c.timestamp}: ${c.exception}').join('\n');
    return '''
Analytics Export:
Generated: ${DateTime.now()}
Total Events: ${_events.length}
Total Crashes: ${_crashes.length}
Event Types: ${(summary['event_counts'] as Map).keys.join(', ')}

Recent Events (last 10):
$recentEventsStr

Recent Crashes (last 5):
$recentCrashesStr
''';
  }

  /// Clear analytics data
  void clear() {
    _events.clear();
    _crashes.clear();
    debugPrint('🗑️ Analytics data cleared');
  }
}

/// Single analytics event
class AnalyticsEvent {
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic> properties;

  AnalyticsEvent({
    required this.name,
    required this.timestamp,
    required this.properties,
  });

  @override
  String toString() =>
      'AnalyticsEvent(name: $name, time: ${timestamp.toString()}, props: $properties)';
}

/// Crash report with context
class CrashReport {
  final String exception;
  final String stackTrace;
  final String? context;
  final DateTime timestamp;

  CrashReport({
    required this.exception,
    required this.stackTrace,
    required this.context,
    required this.timestamp,
  });

  @override
  String toString() => '''
CrashReport:
  Exception: $exception
  Context: ${context ?? 'Unknown'}
  Time: $timestamp
  Stack: ${stackTrace.split('\n').take(3).join('\n  ')}
''';
}

/// Global error handler
class ErrorHandler {
  static void setupErrorHandling() {
    // Handle uncaught errors in Flutter
    FlutterError.onError = (FlutterErrorDetails details) {
      AnalyticsManager().trackException(
        details.exception,
        details.stack,
        context: 'Flutter Framework Error',
      );
      
      // Continue showing error in debug mode
      FlutterError.presentError(details);
    };
    
    // Handle Dart errors
    PlatformDispatcher.instance.onError = (error, stack) {
      AnalyticsManager().trackException(
        error,
        stack,
        context: 'Dart Runtime Error',
      );
      
      return true;
    };
    
    debugPrint('🛡️ Global error handling configured');
  }
}

/// Error boundary widget to isolate and recover from UI crashes
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  const ErrorBoundary({
    Key? key,
    required this.child,
    this.errorBuilder,
  }) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(error, _stackTrace);
      }
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.report_problem_rounded,
                  color: Colors.redAccent,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _stackTrace = null;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final originalBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      AnalyticsManager().trackException(
        details.exception,
        details.stack,
        context: 'ErrorBoundary Catch',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _error = details.exception;
            _stackTrace = details.stack;
          });
        }
      });
      return const SizedBox.shrink();
    };

    final result = widget.child;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ErrorWidget.builder = originalBuilder;
    });

    return result;
  }
}
