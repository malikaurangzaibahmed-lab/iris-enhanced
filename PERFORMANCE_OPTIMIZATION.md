# Performance & Optimization System Documentation

## Overview

A complete suite of performance optimization, memory management, analytics, and crash reporting systems has been integrated into the Student Organizer app. This document explains each component and how to use them effectively.

## 1. Smart Cache System (`smart_cache.dart`)

**Purpose:** Global in-memory caching with automatic TTL and LRU eviction

### Key Features:
- **Automatic expiration:** Cache entries expire after configurable TTL (default 5 mins)
- **Memory-bounded:** Max 100 items in cache, LRU eviction when full
- **Access tracking:** Favors frequently used items over rarely used ones
- **Type-safe:** Works with any data type using generics

### Usage Example:

```dart
final cache = SmartCache();

// Store value with default 5min TTL
cache.set('user_schedule', scheduleData);

// Store with custom TTL
cache.set('search_results', results, ttl: Duration(minutes: 10));

// Retrieve (returns null if expired)
final schedule = cache.get<Schedule>('user_schedule');

// Check existence without retrieving
if (cache.contains('user_schedule')) {
  // Use cached data
}

// Clear everything
cache.clear();

// Get stats
final stats = cache.getStats();
print('Cache size: ${stats['size']}');
```

### When to Use:
- Expensive computations that don't change frequently
- API responses
- Database queries
- Search results
- User preference calculations

---

## 2. Performance Monitor (`smart_cache.dart`)

**Purpose:** Track operation performance metrics

### Key Features:
- **Automatic tracking:** Records duration of operations
- **Statistics:** Provides min, max, average timelines
- **Memory efficient:** Keeps only last 100 measurements per operation
- **Real-time reporting:** Get performance snapshots anytime

### Usage Example:

```dart
final monitor = PerfMonitor();

// Record a metric
monitor.recordMetric('load_schedule', Duration(milliseconds: 250));

// Get average duration
final avgLoading = monitor.getAverageDuration('load_schedule');
print('Average: ${avgLoading?.inMilliseconds}ms');

// Get detailed report
final report = monitor.getReport();
print('Performance Report:');
report.forEach((op, stats) => print('$op: $stats'));

// Auto-tracking with extension
await _loadScheduleAsync().trackPerf('load_schedule');
```

### When to Use:
- Identify slow operations
- Monitor performance improvements
- Debug performance regressions
- Create performance baselines

---

## 3. Smart API Client (`smart_api_client.dart`)

**Purpose:** HTTP requests with retry logic, caching, and error handling

### Key Features:
- **Automatic retries:** Up to 3 retries with exponential backoff
- **Response caching:** Configurable per request
- **Force refresh:** Bypass cache when needed
- **Batch operations:** Parallel requests
- **Performance tracking:** Automatic metric recording

### Usage Example:

```dart
final apiClient = SmartApiClient();

// GET with caching (5min default)
final schedule = await apiClient.get<Schedule>(
  '/api/schedule',
  cacheDuration: Duration(minutes: 5),
  parser: (json) => Schedule.fromJson(json),
);

// Force refresh, skip cache
final fresh = await apiClient.get<Schedule>(
  '/api/schedule',
  forceRefresh: true,
  parser: (json) => Schedule.fromJson(json),
);

// POST request
final result = await apiClient.post<Response>(
  '/api/update',
  body: {'name': 'New Class'},
  parser: (json) => Response.fromJson(json),
);

// Batch multiple requests
final results = await apiClient.getBatch<Course>(
  ['/api/courses/1', '/api/courses/2', '/api/courses/3'],
  parser: (json) => Course.fromJson(json),
);

// View performance stats
apiClient.printStats();

// Clear cache
apiClient.clearCache();
```

### Debouncer & Throttler:

```dart
// Debounce expensive operations (search inputs)
final searchDebouncer = Debouncer(delay: Duration(milliseconds: 500));

void onSearchChanged(String query) {
  searchDebouncer.call(() {
    performSearch(query);
  });
}

// Throttle frequent operations (scroll listeners)
final scrollThrottler = Throttler(delay: Duration(milliseconds: 100));

onScroll() {
  scrollThrottler.call(() {
    loadMoreItems();
  });
}
```

---

## 4. Memory Manager (`memory_manager.dart`)

**Purpose:** Prevent memory leaks and manage resource cleanup

### Key Features:
- **Resource tracking:** Automatic registration and cleanup
- **Stream management:** Auto-dispose of subscriptions
- **Timer management:** Cancel timers on disposal
- **List caching:** Smart widget caching with auto-trim
- **Image cache optimization:** Configure size limits

### Usage Example:

```dart
// In State class
final streamManager = StreamManager();

@override
void initState() {
  super.initState();
  
  // Auto-managed subscription
  streamManager.subscribe(
    schedulesStream,
    (schedule) => updateUI(schedule),
    onError: (e) => showError(e),
    onDone: () => print('Stream done'),
  );
}

@override
void dispose() {
  streamManager.dispose(); // Auto-cancels all subscriptions
  super.dispose();
}

// Timer management
final timerManager = TimerManager();

// Create auto-managed timer
final timer = timerManager.createTimer(
  Duration(seconds: 30),
  () => refreshData(),
);

// Create periodic timer
final periodicTimer = timerManager.createPeriodicTimer(
  Duration(minutes: 1),
  (timer) => syncData(),
);

// Cleanup on dispose
timerManager.dispose();

// List widget caching
class MyListView extends StatefulWidget {
  @override
  State<MyListView> createState() => _MyListViewState();
}

class _MyListViewState extends State<MyListView> {
  final listController = SmartListViewController();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: listController.controller,
      itemBuilder: (context, index) {
        return listController.getWidget(index, (i) {
          return buildListItem(i); // Built once, cached
        });
      },
    );
  }

  @override
  void dispose() {
    listController.dispose();
    super.dispose();
  }
}

// Image cache optimization
ImageCacheManager.optimizeImageCache(); // 100 images, 50MB max
ImageCacheManager.printImageCacheStats();
ImageCacheManager.clearImageCache();
```

---

## 5. Smart Widgets (`smart_widgets.dart`)

**Purpose:** Performance-optimized widget base classes and components

### Key Features:
- **Automatic mounted checks:** Prevent setState on disposed widgets
- **Debounced updates:** For frequent state changes
- **Smart list views:** Built-in caching and trimming
- **Memory management:** Auto-cleanup of resources
- **Performance monitoring:** Build count and timing

### Usage Example:

```dart
// Use SmartState instead of State for automatic optimization
class MyScheduleScreen extends SmartStatefulWidget {
  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends SmartState<MyScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmartListView(
        itemCount: 100,
        itemBuilder: (context, index) => buildScheduleItem(index),
        onEndReached: loadMoreItems, // Fires at 90% scroll
      ),
    );
  }

  void updateUIFrequently() {
    // Regular setState - checks mounted automatically
    safeSetState(() => _counter++);
    
    // Debounced for very frequent updates
    debouncedSetState(() => _counter++);
  }

  Future<void> loadAsyncData() {
    // Automatic mounted check and error handling
    return safeAsync(() => fetchData());
  }
}

// Wrap sections for repaint boundary optimization
@override
Widget build(BuildContext context) {
  return SmartRepaintBoundary(
    child: ExpensiveWidget(), // Won't rebuild parent
  );
}

// Monitor performance
PerformanceMonitor(
  label: 'MyWidget',
  child: Scaffold(...),
);
```

---

## 6. Analytics & Crash Reporting (`analytics_manager.dart`)

**Purpose:** Track user behavior and catch errors in production

### Key Features:
- **Event tracking:** Custom user actions
- **Crash reporting:** Automatic exception logging
- **Performance metrics:** Timing data collection
- **Memory bounded:** Keeps recent 1000 events, 100 crashes
- **Export capability:** Generate analytics reports

### Usage Example:

```dart
final analytics = AnalyticsManager();

// Track screen views
analytics.trackScreenView('schedule_screen');

// Track custom events
analytics.trackEvent('schedule_exported', properties: {
  'format': 'pdf',
  'course_count': 15,
  'duration_ms': 2500,
});

// Track timing
final stopwatch = Stopwatch()..start();
await expensiveOperation();
stopwatch.stop();
analytics.trackTiming(
  'data_processing',
  'schedule_load',
  stopwatch.elapsedMilliseconds,
);

// Manual exception tracking
try {
  riskyOperation();
} catch (e, stack) {
  analytics.trackException(e, stack, context: 'PDF Export');
}

// In main.dart - setup global error handling
ErrorHandler.setupErrorHandling();

// Get summary
final summary = analytics.getAnalyticsSummary();
print('Events: ${summary['total_events']}');
print('Crashes: ${summary['total_crashes']}');

// View history
final events = analytics.getEventHistory(filterByName: 'schedule', limit: 10);
final crashes = analytics.getCrashReports(limit: 5);

// Export data
final report = analytics.exportAnalytics();
sendToBackend(report);

// Print detailed report
analytics.printReport();

// Clear when rotating or debugging
analytics.clear();
```

### Error Boundary Widget:

```dart
// Wrap sections to catch and handle errors gracefully
ErrorBoundary(
  errorBuilder: (error) => CustomErrorWidget(error),
  child: ExpensiveDetailsSection(),
)
```

---

## 7. App Configuration (`app_config.dart`)

**Purpose:** Centralized configuration and feature flags

### Key Features:
- **Type-safe access:** Automatic type conversion
- **LocalStorage backed:** Persists across app restarts
- **Caching layer:** Fast in-memory access
- **Feature flags:** A/B testing and gradual rollouts
- **Defaults management:** Sensible defaults for all values

### Usage Example:

```dart
// Initialize in main()
await AppConfig().initialize();

// Get configuration values
final cacheDuration = AppConfig().cacheDurationMins; // 5
final maxRetries = AppConfig().maxRetries; // 3
final enableAnalytics = AppConfig().enableAnalytics; // true
final widgetInterval = AppConfig().widgetUpdateIntervalSecs; // 30

// Update configuration
await AppConfig().setValue('cache_duration_mins', 10);

// Get all config
final allConfig = AppConfig().getAll();
print(allConfig);

// Reset to defaults
await AppConfig().resetToDefaults();

// Print current config
AppConfig().printConfig();

// Feature flags
if (FeatureFlags().isEnabled('enhanced_study_spaces')) {
  showEnhancedUI();
}

// Toggle features
FeatureFlags().disable('pdf_timetable_parser');
FeatureFlags().enable('new_feature');

// View all flags
FeatureFlags().printFlags();
```

---

## Integration Guide

### In `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize systems
  await AppConfig().initialize();
  ErrorHandler.setupErrorHandling();
  ImageCacheManager.optimizeImageCache();
  
  // Optional: print initial stats (debug only)
  if (kDebugMode) {
    AppConfig().printConfig();
    FeatureFlags().printFlags();
  }
  
  runApp(
    ErrorBoundary(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final MemoryManager _memoryManager = MemoryManager();

  @override
  void dispose() {
    // Cleanup all resources
    _memoryManager.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(...);
  }
}
```

### In `widget_service.dart` (Already Implemented):

```dart
// Cache widget updates
static String _generateHash(bool isLive, String subject, String room, String teacher, int progress) {
  return '$isLive|$subject|$room|$teacher|$progress'.hashCode.toString();
}

// Smart API caching
final apiClient = SmartApiClient();
final courses = await apiClient.get<List<Course>>(
  '/api/courses',
  cacheDuration: Duration(minutes: 10),
  parser: (json) => Course.fromJsonList(json),
);
```

---

## Performance Best Practices

### 1. **Use SmartListView for Large Lists**
```dart
SmartListView(
  itemCount: 1000,
  itemBuilder: (context, index) => buildItem(index),
  onEndReached: loadMore,
)
```

### 2. **Debounce User Input**
```dart
final searchDebouncer = Debouncer();
void onSearchChanged(String query) {
  searchDebouncer.call(() => performSearch(query));
}
```

### 3. **Cache Expensive Operations**
```dart
final cache = SmartCache();
var data = cache.get<Data>('key') ?? await expensiveOp();
cache.set('key', data);
```

### 4. **Track Slow Operations**
```dart
final monitor = PerfMonitor();
final duration = await operation().trackPerf('op_name');
```

### 5. **Manage Resources Properly**
```dart
final streamManager = StreamManager();
streamManager.subscribe(stream, onData);
// Auto-cleanup on dispose
```

### 6. **Use Feature Flags**
```dart
if (FeatureFlags().isEnabled('new_feature')) {
  showNewFeature();
}
```

### 7. **Monitor Analytics**
```dart
AnalyticsManager().trackEvent('action_name', properties: {...});
AnalyticsManager().trackScreenView('screen_name');
```

---

## Debugging and Monitoring

### Print Performance Report:
```dart
PerfMonitor().getReport().forEach((op, stats) => print('$op: $stats'));
SmartApiClient().printStats();
```

### View Analytics:
```dart
AnalyticsManager().printReport();
appendix of AnalyticsManager().exportAnalytics();
```

### Check Memory Usage:
```dart
MemoryManager().printMemoryStats();
ImageCacheManager.printImageCacheStats();
final stats = SmartCache().getStats();
```

### Verify Configuration:
```dart
AppConfig().printConfig();
FeatureFlags().printFlags();
```

---

## Configuration Reference

| Setting | Default | Configurable |
|---------|---------|--------------|
| Cache Duration | 5 minutes | ✅ |
| Max Retries | 3 | ✅ |
| Max Cache Size | 100 items | ❌ |
| Notification Timeout | 5 seconds | ✅ |
| Widget Update Interval | 30 seconds | ✅ |
| Enable Analytics | true | ✅ |
| Enable Crash Reporting | true | ✅ |

---

## Migration Checklist

- [ ] Initialize AppConfig in main()
- [ ] Setup ErrorHandler.setupErrorHandling()
- [ ] Wrap root app with ErrorBoundary
- [ ] Replace ListViews with SmartListView where applicable
- [ ] Update State classes to SmartState
- [ ] Add analytics tracking to key screens
- [ ] Configure ImageCacheManager
- [ ] Test memory usage with DevTools
- [ ] Review analytics reports regularly
- [ ] Monitor crash reports daily

---

## Conclusion

This optimization suite provides production-grade performance monitoring, memory management, and reliability features. Use them strategically to ensure the Student Organizer app remains fast, responsive, and stable at scale.

Happy optimizing! 🚀
