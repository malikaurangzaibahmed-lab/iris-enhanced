# Smart Systems Quick Reference

## 🚀 Core Services

### SmartCache - Global In-Memory Cache
```dart
SmartCache cache = SmartCache();
cache.set('key', value, ttl: Duration(minutes: 5));
cache.get<Type>('key');  // Returns null if expired
cache.clear();
```

### PerfMonitor - Performance Tracking
```dart
PerfMonitor monitor = PerfMonitor();
monitor.recordMetric('operation', Duration(...));
monitor.getAverageDuration('operation');
monitor.getReport();
```

### SmartApiClient - HTTP with Retries & Caching
```dart
SmartApiClient api = SmartApiClient();
api.get('/endpoint', cacheDuration: ..., parser: ...);
api.post('/endpoint', body: ..., parser: ...);
api.getBatch([...], parser: ...);
api.printStats();
api.clearCache();
```

### Debouncer & Throttler - Rate Limiting
```dart
// Debounce: Wait for quiet period (good for search)
Debouncer debouncer = Debouncer(delay: Duration(ms: 300));
debouncer.call(() => expensiveOp());

// Throttle: Maximum frequency (good for scroll)
Throttler throttler = Throttler(delay: Duration(ms: 100));
throttler.call(() => loadMore());
```

---

## 🧠 Memory Management

### MemoryManager - Resource Lifecycle
```dart
MemoryManager manager = MemoryManager();
manager.registerResource(resource);
await manager.disposeAll();  // Call in dispose()
manager.printMemoryStats();
```

### StreamManager - Auto-Dispose Streams
```dart
StreamManager streams = StreamManager();
streams.subscribe(stream, onData, onError, onDone);
await streams.dispose();  // Auto-cancels all
```

### TimerManager - Auto-Cancel Timers
```dart
TimerManager timers = TimerManager();
timers.createTimer(duration, callback);
timers.createPeriodicTimer(duration, callback);
await timers.dispose();  // Auto-cancels all
```

### ImageCacheManager - Image Optimization
```dart
ImageCacheManager.optimizeImageCache();  // 100 images, 50MB
ImageCacheManager.printImageCacheStats();
ImageCacheManager.clearImageCache();
```

---

## 🎨 Smart Widgets

### SmartState - Optimized State Base Class
```dart
class MyScreen extends SmartStatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends SmartState<MyScreen> {
  @override
  Widget build(BuildContext context) { }
  
  // Methods available:
  safeSetState(() => {...});  // Mounted check
  debouncedSetState(() => {...});  // Frequency limited
  safeAsync(() => operation());  // Mounted + error handling
  registerResource(resource);  // Auto cleanup
}
```

### SmartListView - Optimized List with Caching
```dart
SmartListView(
  itemCount: 1000,
  itemBuilder: (context, index) => buildItem(index),
  onEndReached: loadMore,
  retrimDuration: Duration(seconds: 2),
)
```

### SmartGridView - Optimized Grid
```dart
SmartGridView(
  itemCount: 100,
  itemBuilder: (context, index) => buildItem(index),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
)
```

### PerformanceMonitor - Build Tracking
```dart
PerformanceMonitor(
  label: 'MyWidget',
  child: ExpensiveWidget(),
)  // Prints: "MyWidget: Built X times, last build: Yms"
```

### SmartRepaintBoundary - Isolation
```dart
SmartRepaintBoundary(
  child: ExpensiveWidget(),  // Won't trigger parent rebuild
)
```

---

## 📊 Analytics & Crash Tracking

### AnalyticsManager - User Tracking
```dart
AnalyticsManager analytics = AnalyticsManager();

// Track actions
analytics.trackEvent('action_name', properties: {'key': value});
analytics.trackScreenView('screen_name');
analytics.trackTiming('category', 'variable', milliseconds);

// Track exceptions
analytics.trackException(error, stackTrace, context: 'context');

// View data
analytics.getAnalyticsSummary();
analytics.getEventHistory(filterByName: '...', limit: 10);
analytics.getCrashReports(limit: 5);
analytics.printReport();
analytics.exportAnalytics();
analytics.clear();
```

### ErrorHandler - Global Error Setup
```dart
ErrorHandler.setupErrorHandling();  // Call in main()
// Automatically catches Flutter and Dart errors
```

### ErrorBoundary - Error UI Wrapper
```dart
ErrorBoundary(
  errorBuilder: (error) => CustomErrorUI(error),
  child: RiskyWidget(),
)
```

---

## ⚙️ Configuration & Features

### AppConfig - Centralized Settings
```dart
AppConfig config = AppConfig();
await config.initialize();

// Getters
config.appVersion;
config.cacheDurationMins;
config.maxRetries;
config.enableAnalytics;
config.widgetUpdateIntervalSecs;
// ... more

// Setters
await config.setValue('cache_duration_mins', 10);

// Utilities
config.getAll();
config.printConfig();
await config.resetToDefaults();
await config.clear();
```

### FeatureFlags - A/B Testing
```dart
FeatureFlags flags = FeatureFlags();

flags.isEnabled('feature_name');
flags.enable('feature_name');
flags.disable('feature_name');
flags.getAll();
flags.printFlags();
```

---

## 🎯 Extension Methods

### Future Performance Tracking
```dart
await expensiveOp().trackPerf('operation_name');
// Prints: ⏱️ operation_name: XXms
// Records metric automatically
```

### State Resource Registration
```dart
registerDisposable(resource);  // Call in State to auto-cleanup
```

---

## 📋 Initialization Checklist

### main.dart:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize config
  await AppConfig().initialize();
  
  // 2. Setup error handling
  ErrorHandler.setupErrorHandling();
  
  // 3. Optimize image cache
  ImageCacheManager.optimizeImageCache();
  
  runApp(
    ErrorBoundary(  // 4. Wrap with ErrorBoundary
      child: MyApp(),
    ),
  );
}
```

### In State.dispose():
```dart
@override
void dispose() {
  // If you created managers
  await memoryManager.disposeAll();
  
  // If using timers
  timerManager.dispose();
  
  // If using streams
  streamManager.dispose();
  
  super.dispose();
}
```

---

## 🔍 Debugging Tips

### Check Performance
```dart
PerfMonitor().getReport().forEach((op, stats) => print('$op: $stats'));
SmartApiClient().printStats();
```

### Check Memory
```dart
MemoryManager().printMemoryStats();
ImageCacheManager.printImageCacheStats();
SmartCache().getStats();
```

### Check Analytics
```dart
AnalyticsManager().printReport();
print(AnalyticsManager().exportAnalytics());
```

### Check Configuration
```dart
AppConfig().printConfig();
FeatureFlags().printFlags();
```

---

## ⏱️ Common Patterns

### Debounce Search Input
```dart
final searchDebouncer = Debouncer();
void onSearchChanged(String query) {
  searchDebouncer.call(() => _performSearch(query));
}
```

### Scroll Throttle
```dart
final scrollThrottler = Throttler();
_controller.addListener(() {
  scrollThrottler.call(() => _loadMore());
});
```

### Cache API Response
```dart
final apiClient = SmartApiClient();
var data = await apiClient.get<Data>(
  '/api/data',
  cacheDuration: Duration(minutes: 10),
  parser: (json) => Data.fromJson(json),
);
```

### Track Screen View
```dart
@override
void initState() {
  super.initState();
  AnalyticsManager().trackScreenView('my_screen');
}
```

### Safe Async Operation
```dart
Future<void> loadData() async {
  final result = await safeAsync(() => _fetchRemoteData());
  // Automatically handles mounted check + error
}
```

### Monitor Performance
```dart
final duration = await _expensiveOp().trackPerf('load_data');
// ⏱️ load_data: 250ms
// Metric also recorded automatically
```

---

## 🚨 Error Handling

```dart
try {
  risky();
} catch (e, stack) {
  AnalyticsManager().trackException(e, stack, context: 'RiskyOp');
}

// Or auto-captured via ErrorHandler.setupErrorHandling()
// Check crashes: AnalyticsManager().getCrashReports()
```

---

## 📚 Full Documentation

See `PERFORMANCE_OPTIMIZATION.md` for comprehensive guide with examples for each system.

---

**Version:** 1.0  
**Last Updated:** 2024  
**Status:** Production Ready ✅
