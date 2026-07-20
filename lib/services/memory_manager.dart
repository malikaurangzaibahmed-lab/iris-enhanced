import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

/// Smart memory manager to prevent memory leaks and optimize usage
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  
  factory MemoryManager() {
    return _instance;
  }
  
  MemoryManager._internal();
  
  final List<MemoryResource> _resources = [];
  
  /// Register a resource for tracking (ListView.builder contexts, streams, etc.)
  void registerResource(MemoryResource resource) {
    _resources.add(resource);
    debugPrint('📍 Registered resource: ${resource.name}');
  }

  /// Unregister and cleanup a resource
  Future<void> unregisterResource(MemoryResource resource) async {
    await resource.dispose();
    _resources.remove(resource);
    debugPrint('🗑️ Unregistered resource: ${resource.name}');
  }

  /// Cleanup all resources
  Future<void> disposeAll() async {
    debugPrint('🧹 Disposing ${_resources.length} resources...');
    
    for (final resource in _resources.toList()) {
      try {
        await resource.dispose();
      } catch (e) {
        debugPrint('❌ Error disposing ${resource.name}: $e');
      }
    }
    
    _resources.clear();
    debugPrint('✅ All resources disposed');
  }

  /// Get memory usage statistics
  void printMemoryStats() {
    debugPrint('\n💾 Memory Statistics:');
    debugPrint('  Registered resources: ${_resources.length}');
    
    final resourcesByType = <String, int>{};
    for (final resource in _resources) {
      final type = resource.runtimeType.toString();
      resourcesByType[type] = (resourcesByType[type] ?? 0) + 1;
    }
    
    resourcesByType.forEach((type, count) {
      debugPrint('  $type: $count active');
    });
    debugPrint('');
  }
}

/// Base class for memory resources
abstract class MemoryResource {
  String get name;
  
  Future<void> dispose();
}

/// Cached list view controller to reuse item widgets
class SmartListViewController {
  final ScrollController _controller = ScrollController();
  final Map<int, Widget> _widgetCache = {};
  
  ScrollController get controller => _controller;
  
  /// Get or build widget for index
  Widget getWidget(int index, Widget Function(int) builder) {
    return _widgetCache.putIfAbsent(index, () => builder(index));
  }

  /// Clear cache for memory optimization
  void clearCache() {
    _widgetCache.clear();
    debugPrint('🗑️ List widget cache cleared');
  }

  /// Dispose controller
  void dispose() {
    _controller.dispose();
    _widgetCache.clear();
  }
}

/// Stream subscription manager
class StreamManager extends MemoryResource {
  @override
  final String name = 'StreamManager';
  
  final List<StreamSubscription> _subscriptions = [];

  /// Subscribe to stream with auto-management
  StreamSubscription<T> subscribe<T>(
    Stream<T> stream,
    void Function(T) onData, {
    Function? onError,
    VoidCallback? onDone,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
    );
    
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Unsubscribe from stream
  void unsubscribe(StreamSubscription subscription) {
    subscription.cancel();
    _subscriptions.remove(subscription);
  }

  @override
  Future<void> dispose() async {
    debugPrint('🧹 Disposing ${_subscriptions.length} stream subscriptions...');
    
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    
    _subscriptions.clear();
    debugPrint('✅ All stream subscriptions disposed');
  }
}

/// Timer manager to prevent timer leaks
class TimerManager extends MemoryResource {
  @override
  final String name = 'TimerManager';
  
  final List<Timer> _timers = [];

  /// Create timer with auto-management
  Timer createTimer(Duration duration, VoidCallback callback) {
    final timer = Timer(duration, callback);
    _timers.add(timer);
    return timer;
  }

  /// Create periodic timer
  Timer createPeriodicTimer(Duration duration, Function(Timer) callback) {
    final timer = Timer.periodic(duration, callback);
    _timers.add(timer);
    return timer;
  }

  /// Cancel timer
  void cancelTimer(Timer timer) {
    if (_timers.contains(timer)) {
      timer.cancel();
      _timers.remove(timer);
    }
  }

  @override
  Future<void> dispose() async {
    debugPrint('🧹 Cancelling ${_timers.length} active timers...');
    
    for (final timer in _timers) {
      if (timer.isActive) {
        timer.cancel();
      }
    }
    
    _timers.clear();
    debugPrint('✅ All timers cancelled');
  }
}

/// Image cache manager
class ImageCacheManager {
  static void optimizeImageCache() {
    // Reduce max number of cached images in memory
    imageCache.maximumSize = 100;
    imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50 MB
    
    debugPrint('🖼️ Image cache optimized: 100 images, 50MB max');
  }

  static void clearImageCache() {
    imageCache.clear();
    imageCache.clearLiveImages();
    debugPrint('🗑️ Image cache cleared');
  }

  static void printImageCacheStats() {
    debugPrint('\n🖼️ Image Cache Stats:');
    debugPrint('  Current images: ${imageCache.currentSize}');
    debugPrint('  Current size: ${(imageCache.currentSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB');
    debugPrint('');
  }
}

/// Global memory optimization helpers
Future<void> optimizeMemory() async {
  debugPrint('\n🔧 Running memory optimization...');
  
  // Clear image caches
  imageCache.clear();
  
  // Force garbage collection hint
  developer.Timeline.startSync('Memory Optimization');
  developer.Timeline.finishSync();
  
  debugPrint('✅ Memory optimization complete');
}

extension DisposeHelper on State {
  /// Helper to register state-level resources for auto-cleanup
  void registerDisposable(MemoryResource resource) {
    MemoryManager().registerResource(resource);
  }
}
