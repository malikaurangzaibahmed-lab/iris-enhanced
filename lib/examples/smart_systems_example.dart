/// Complete example showing smart systems integration
/// This demonstrates all optimization patterns working together

import 'package:flutter/material.dart';
// Import all smart systems
import '../services/smart_cache.dart';
import '../services/smart_api_client.dart';
import '../services/memory_manager.dart';
import '../services/analytics_manager.dart';
import '../services/app_config.dart';
import '../widgets/smart_widgets.dart';

/// Example: Smart Schedule Display Screen
class SmartScheduleScreen extends SmartStatefulWidget {
  const SmartScheduleScreen({Key? key}) : super(key: key);

  @override
  State<SmartScheduleScreen> createState() => _SmartScheduleScreenState();
}

class _SmartScheduleScreenState extends SmartState<SmartScheduleScreen> {
  // Service instances
  late SmartApiClient apiClient;
  late AnalyticsManager analytics;
  
  // State
  List<Course>? courses;
  bool isLoading = true;
  String searchQuery = '';
  final searchDebouncer = Debouncer(delay: Duration(milliseconds: 300));

  @override
  void initState() {
    super.initState();
    
    // Initialize services
    apiClient = SmartApiClient();
    analytics = AnalyticsManager();
    
    // Track screen view
    analytics.trackScreenView('schedule_screen');
    
    // Load data
    _loadSchedule();
  }

  /// Load schedule with smart caching
  Future<void> _loadSchedule() async {
    safeSetState(() => isLoading = true);
    
    try {
      // Track timing
      final stopwatch = Stopwatch()..start();
      
      // API call with automatic caching (5 min TTL from config)
      courses = await safeAsync(() async {
        return await apiClient.get<List<Course>>(
          '/api/schedule',
          cacheDuration: Duration(
            minutes: AppConfig().cacheDurationMins,
          ),
          parser: (json) => Course.fromJsonList(json),
        );
      });
      
      stopwatch.stop();
      
      // Track metrics
      analytics.trackTiming(
        'schedule_loading',
        'load_duration',
        stopwatch.elapsedMilliseconds,
      );
      
      analytics.trackEvent('schedule_loaded', properties: {
        'course_count': courses?.length ?? 0,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      
    } catch (e, stack) {
      // Track exception
      analytics.trackException(e, stack, context: 'ScheduleScreen._loadSchedule');
    }
    
    safeSetState(() => isLoading = false);
  }

  /// Smart search with debouncing
  void _onSearchChanged(String query) {
    searchQuery = query;
    
    // Debounce to avoid excessive filtering
    searchDebouncer.call(() {
      debouncedSetState(() {
        // Filtering happens in build()
        analytics.trackEvent('search_query', properties: {
          'query': query,
          'results': _getFilteredCourses().length,
        });
      });
    });
  }

  /// Get filtered courses
  List<Course> _getFilteredCourses() {
    if (courses == null) return [];
    if (searchQuery.isEmpty) return courses!;
    
    return courses!
        .where((c) => c.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  /// Load more (for infinite scroll)
  Future<void> _loadMore() async {
    analytics.trackEvent('load_more_triggered');
    // Implement pagination logic
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Schedule'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search courses...',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                
                // Course list with smart caching
                Expanded(
                  child: SmartListView(
                    itemCount: _getFilteredCourses().length,
                    itemBuilder: (context, index) {
                      final course = _getFilteredCourses()[index];
                      return _buildCourseCard(course);
                    },
                    onEndReached: _loadMore,
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Refresh: bypass cache
          analytics.trackEvent('schedule_refreshed');
          // await apiClient.clearCache();  // clearCache returns void
          await _loadSchedule();
        },
        child: Icon(Icons.refresh),
      ),
    );
  }

  /// Build course card with performance optimization
  Widget _buildCourseCard(Course course) {
    return SmartRepaintBoundary(
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          title: Text(course.name),
          subtitle: Text('${course.startTime} - ${course.endTime}'),
          trailing: Icon(Icons.arrow_forward),
          onTap: () {
            analytics.trackEvent('course_opened', properties: {
              'course_id': course.id,
              'course_name': course.name,
            });
            // Navigate to course details
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchDebouncer.dispose();
    apiClient.printStats();  // Debug: print stats before disposing
    super.dispose();
  }
}

/// Example: Schedule Detail Screen with Performance Monitoring
class SmartScheduleDetailScreen extends SmartStatefulWidget {
  final String courseId;
  
  const SmartScheduleDetailScreen({
    Key? key,
    required this.courseId,
  }) : super(key: key);

  @override
  State<SmartScheduleDetailScreen> createState() =>
      _SmartScheduleDetailScreenState();
}

class _SmartScheduleDetailScreenState
    extends SmartState<SmartScheduleDetailScreen> {
  
  final cache = SmartCache();
  final monitor = PerfMonitor();
  final analytics = AnalyticsManager();
  final streamManager = StreamManager();
  
  late Stream<CourseDetails> detailsStream;
  CourseDetails? details;

  @override
  void initState() {
    super.initState();
    
    analytics.trackScreenView('schedule_detail_screen');
    
    // Setup stream with auto-management
    detailsStream = _getCourseDetailsStream();
    streamManager.subscribe(
      detailsStream,
      (details) => safeSetState(() => this.details = details),
      onError: (e) => analytics.trackException(e, null, context: 'Detail stream'),
    );
  }

  /// Get course details stream (cached)
  Stream<CourseDetails> _getCourseDetailsStream() {
    return Stream.periodic(Duration(seconds: 5), (_) async {
      // Try cache first
      var cached = cache.get<CourseDetails>('course_${widget.courseId}');
      
      if (cached != null) {
        return cached;
      }
      
      // Fetch fresh data
      // In real app: call API
      final details = CourseDetails(
        courseName: 'Data Structures',
        professor: 'Dr. Smith',
        room: 'A-101',
        schedule: ['MWF', '10:00-11:00'],
      );
      
      // Cache for 10 minutes
      cache.set(
        'course_${widget.courseId}',
        details,
        ttl: Duration(minutes: 10),
      );
      
      return details;
    }).asyncMap((event) => event);
  }

  @override
  Widget build(BuildContext context) {
    if (details == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Course Details')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PerformanceMonitor(
      label: 'ScheduleDetail',
      child: Scaffold(
        appBar: AppBar(
          title: Text(details!.courseName),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCourseInfo(),
                SizedBox(height: 24),
                _buildScheduleTimes(),
                SizedBox(height: 24),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseInfo() {
    return SmartRepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            details!.courseName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 8),
          Text('Professor: ${details!.professor}'),
          Text('Room: ${details!.room}'),
        ],
      ),
    );
  }

  Widget _buildScheduleTimes() {
    return SmartRepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          ...details!.schedule
              .map((time) => Text('• $time'))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return SmartRepaintBoundary(
      child: Wrap(
        spacing: 8,
        children: [
          ElevatedButton(
            onPressed: () {
              analytics.trackEvent('add_to_calendar');
            },
            child: Text('Add to Calendar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Force refresh: bypass cache
              cache.set(
                'course_${widget.courseId}',
                details!,
                ttl: Duration(minutes: 1),
              );
              analytics.trackEvent('course_refreshed');
            },
            child: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    streamManager.dispose();  // Auto-cancels subscriptions
    
    // Print debug info
    if (details != null) {
      analytics.trackEvent('schedule_detail_closed', properties: {
        'course_id': widget.courseId,
      });
    }
    
    super.dispose();
  }
}

/// Mock classes for example
class Course {
  final String id;
  final String name;
  final String startTime;
  final String endTime;

  Course({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
  });

  static List<Course> fromJsonList(dynamic json) => [];
}

class CourseDetails {
  final String courseName;
  final String professor;
  final String room;
  final List<String> schedule;

  CourseDetails({
    required this.courseName,
    required this.professor,
    required this.room,
    required this.schedule,
  });
}

// Usage in main.dart:
/*
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize systems
  await AppConfig().initialize();
  ErrorHandler.setupErrorHandling();
  ImageCacheManager.optimizeImageCache();
  
  // Run app
  runApp(
    ErrorBoundary(
      child: MyApp(),
    ),
  );
}

// Then navigate to screen:
Navigator.push(context, MaterialPageRoute(
  builder: (_) => SmartScheduleScreen(),
));
*/
