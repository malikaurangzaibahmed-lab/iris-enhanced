---
name: performance-profiling
description: "Guide to profiling, optimizing, and debugging IRIS performance. Use when: experiencing slow performance, want to profile widgets/services, optimizing for battery/memory, or investigating jank/stuttering."
---

# IRIS Performance Profiling & Optimization

## Performance Profiling Workflow

### Step 1: Identify the Problem

**Symptoms:**
- UI stutters/jank (frame drops)
- App slow to launch
- High memory usage
- Rapid battery drain
- Slow data loading

**Tools:**
- Flutter DevTools (Performance timeline)
- Android Studio Profiler (native)
- Firebase Performance Monitoring
- Custom logging with `DateTime.now().microsecondsSinceEpoch`

### Step 2: Profile with DevTools

```bash
# Run with profiling enabled
flutter run --profile

# Or attach to running app
flutter attach

# In DevTools UI:
# - Performance tab → Record → capture timeline
# - Memory tab → Monitor allocations
# - CPU Profiler → Track CPU usage
```

### Step 3: Analyze Results

**Key metrics:**
- **Frame time**: Should be < 16.67ms (60fps)
- **Memory**: Watch for growth/leaks
- **CPU**: Identify hot functions
- **I/O**: Check Firestore/network calls

## Common Performance Issues & Solutions

### Issue 1: Widget Rebuilds Too Often

**Problem**: `build()` called repeatedly, causing jank

**Diagnosis**:
```dart
@override
Widget build(BuildContext context) {
  print('${this.runtimeType} built'); // Add to identify excessive rebuilds
  // ...
}
```

**Solutions**:
```dart
// ✅ Use const constructors
class MyWidget extends StatelessWidget {
  const MyWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) => const SizedBox(height: 100);
}

// ✅ Use shouldRebuild for InheritedWidget
class MyInheritedWidget extends InheritedWidget {
  final int value;
  
  const MyInheritedWidget({required this.value, required Widget child})
    : super(child: child);

  @override
  bool updateShouldNotify(MyInheritedWidget oldWidget) {
    return oldWidget.value != value;
  }
}

// ✅ Use Provider correctly
final counterProvider = StateNotifierProvider((ref) => 
  CounterNotifier()); // Create once, reuse

// ✅ Extract expensive builds
class ExpensiveWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ExpensiveChildWidget(), // Const constructor
        Text('Title'),
      ],
    );
  }
}
```

### Issue 2: Slow Firestore Queries

**Problem**: Queries taking >1 second to complete

**Diagnosis**:
```dart
Future<List<Class>> getClasses() async {
  final stopwatch = Stopwatch()..start();
  
  final result = await firestore.collection('classes')
    .where('timetableId', isEqualTo: timetableId)
    .get();
  
  stopwatch.stop();
  print('Firestore query took ${stopwatch.elapsedMilliseconds}ms');
  
  return result.docs.map((doc) => Class.fromJson(doc.data())).toList();
}
```

**Solutions**:
```dart
// ✅ Add composite indexes for complex queries
// In Firebase Console: Run query → Create index

// ✅ Use pagination for large datasets
Future<List<Class>> getClassesPaged(int page, int pageSize) async {
  Query query = firestore.collection('classes')
    .where('timetableId', isEqualTo: timetableId)
    .orderBy('startTime')
    .limit(pageSize);
  
  if (page > 0) {
    final previousPage = await query.limit(page * pageSize).get();
    query = query.startAfterDocument(previousPage.docs.last);
  }
  
  return query.get().then((snap) => 
    snap.docs.map((doc) => Class.fromJson(doc.data())).toList());
}

// ✅ Cache results locally
class TimetableService {
  Map<String, List<Class>> _cache = {};
  
  Future<List<Class>> getClasses(String timetableId) async {
    if (_cache.containsKey(timetableId)) {
      return _cache[timetableId]!;
    }
    
    final result = await firestore.collection('classes')
      .where('timetableId', isEqualTo: timetableId)
      .get()
      .then((snap) => snap.docs.map((doc) => Class.fromJson(doc.data())).toList());
    
    _cache[timetableId] = result;
    return result;
  }
  
  void invalidateCache(String timetableId) {
    _cache.remove(timetableId);
  }
}

// ✅ Use one-time reads instead of listeners when possible
// ❌ Inefficient: listener active all the time
Stream<List<Class>> watchClasses(String timetableId) {
  return firestore.collection('classes')
    .where('timetableId', isEqualTo: timetableId)
    .snapshots()
    .map((snap) => snap.docs.map((doc) => Class.fromJson(doc.data())).toList());
}

// ✅ Better: read once when needed
Future<List<Class>> getClasses(String timetableId) async {
  return firestore.collection('classes')
    .where('timetableId', isEqualTo: timetableId)
    .get()
    .then((snap) => snap.docs.map((doc) => Class.fromJson(doc.data())).toList());
}
```

### Issue 3: ListView Slow with Large Datasets

**Problem**: Scrolling jank with many items

**Diagnosis**:
```dart
// ❌ Never build all items at once
ListView(
  children: [
    for (int i = 0; i < 10000; i++)
      ClassCard(classData: classes[i]),
  ],
)

// Check in DevTools: Memory usage spikes with scrolling
```

**Solutions**:
```dart
// ✅ Use ListView.builder
ListView.builder(
  itemCount: classes.length,
  itemBuilder: (context, index) => ClassCard(classData: classes[index]),
)

// ✅ Use more efficient CustomScrollView with sliver widgets
CustomScrollView(
  slivers: [
    SliverAppBar(title: const Text('Classes')),
    SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => ClassCard(classData: classes[index]),
        childCount: classes.length,
      ),
    ),
  ],
)

// ✅ Implement caching for list items
class ClassCardWidget extends StatelessWidget {
  final ClassData classData;
  
  const ClassCardWidget({Key? key, required this.classData}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Pre-compute expensive calculations
    final formattedTime = classData.startTime.format(context);
    
    return Card(
      child: ListTile(
        title: Text(classData.name),
        subtitle: Text(formattedTime),
      ),
    );
  }
}
```

### Issue 4: App Launch Time Slow

**Problem**: App takes >3 seconds to launch

**Diagnosis**:
```dart
void main() {
  final stopwatch = Stopwatch()..start();
  
  print('App startup: ${stopwatch.elapsed}');
  runApp(const MyApp());
  
  stopwatch.stop();
  print('Total startup time: ${stopwatch.elapsedMilliseconds}ms');
}
```

**Solutions**:
```dart
// ✅ Lazy load expensive resources
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SplashScreen(), // Show splash while loading
      onGenerateRoute: (settings) {
        // Lazy load routes
        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            );
          default:
            return null;
        }
      },
    );
  }
}

// ✅ Use FutureBuilder for async initialization
class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  Future<void> initializeApp() async {
    // Load critical data first
    // Then load optional data in background
    await Future.wait([
      initializeFirebase(),
      loadUserPreferences(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const HomeScreen();
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

// ✅ Defer non-critical initialization
// Run after app is visible
Future.delayed(const Duration(milliseconds: 500), () {
  // Load analytics, crash reporting, etc.
  initializeAnalytics();
});
```

### Issue 5: Memory Leaks

**Problem**: Memory grows over time, never released

**Diagnosis**:
```bash
# In DevTools Memory tab:
# 1. Record initial memory
# 2. Perform action repeatedly
# 3. Force GC (garbage collection)
# 4. Check if memory returns to baseline

# If memory keeps growing → leak present
```

**Solutions**:
```dart
// ✅ Cancel streams in dispose
class TimetableWidget extends StatefulWidget {
  const TimetableWidget({Key? key}) : super(key: key);

  @override
  State<TimetableWidget> createState() => _TimetableWidgetState();
}

class _TimetableWidgetState extends State<TimetableWidget> {
  late StreamSubscription<List<Class>> _classesSubscription;

  @override
  void initState() {
    super.initState();
    _classesSubscription = timetableService.watchClasses().listen((_) {});
  }

  @override
  void dispose() {
    _classesSubscription.cancel(); // ✅ Important!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// ✅ Avoid Context leaks
// ❌ Bad: Passing context to callback that outlives widget
void sendNotification(BuildContext context) {
  Future.delayed(const Duration(seconds: 5), () {
    // Context might be invalid after 5 seconds
    ScaffoldMessenger.of(context).showSnackBar(...);
  });
}

// ✅ Good: Use Navigator instead
void sendNotification() {
  Navigator.of(context).pushNamed('/success');
}

// ✅ Clean up AnimationControllers
class AnimatedClassCard extends StatefulWidget {
  const AnimatedClassCard({Key? key}) : super(key: key);

  @override
  State<AnimatedClassCard> createState() => _AnimatedClassCardState();
}

class _AnimatedClassCardState extends State<AnimatedClassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // ✅ Important!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}
```

## Performance Monitoring

### Custom Performance Metrics

```dart
// lib/services/performance_service.dart
class PerformanceService {
  static final _metrics = <String, List<int>>{};

  static void startMeasure(String label) {
    _metrics[label] = [DateTime.now().microsecondsSinceEpoch];
  }

  static void endMeasure(String label) {
    if (_metrics[label] == null || _metrics[label]!.isEmpty) return;
    
    final start = _metrics[label]!.first;
    final end = DateTime.now().microsecondsSinceEpoch;
    final duration = end - start;
    
    print('$label took ${duration / 1000}ms');
    _metrics[label]!.add(duration);
  }

  static Map<String, double> getAverages() {
    return {
      for (final entry in _metrics.entries)
        entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length,
    };
  }
}

// Usage
Future<List<Class>> getClasses() async {
  PerformanceService.startMeasure('fetch_classes');
  
  final result = await firestore.collection('classes').get();
  
  PerformanceService.endMeasure('fetch_classes');
  return result.docs.map((doc) => Class.fromJson(doc.data())).toList();
}
```

### Firebase Performance Monitoring Integration

```dart
// In pubspec.yaml
dependencies:
  firebase_performance: ^0.9.0

// In code
final trace = FirebasePerformance.instance.newTrace('timetable_load');
await trace.start();

try {
  final timetable = await timetableService.getTimetable();
  trace.incrementMetric('timetables_loaded', 1);
} finally {
  await trace.stop();
}
```

## Optimization Checklist

- [ ] Profile app with DevTools
- [ ] Use ListView.builder for lists >100 items
- [ ] Apply const constructors to widgets
- [ ] Cache expensive computations
- [ ] Limit simultaneous Firestore listeners
- [ ] Clean up resources in dispose methods
- [ ] Test on lower-end devices (API 21+)
- [ ] Monitor memory with DevTools Memory tab
- [ ] Profile animations at 120fps
- [ ] Use ProGuard for release builds
- [ ] Split APKs per ABI for smaller downloads
- [ ] Monitor Firebase Performance metrics
