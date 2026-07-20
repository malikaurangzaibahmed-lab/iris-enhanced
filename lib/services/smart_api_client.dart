import 'dart:async';
import 'package:flutter/foundation.dart';
import 'smart_cache.dart';

/// Smart API client with built-in retry logic, caching, and performance optimization
class SmartApiClient {
  static final SmartApiClient _instance = SmartApiClient._internal();
  
  factory SmartApiClient() {
    return _instance;
  }
  
  SmartApiClient._internal();
  
  final SmartCache _cache = SmartCache();
  final PerfMonitor _monitor = PerfMonitor();
  
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  /// Execute GET request with caching and retry logic
  Future<T?> get<T>(
    String endpoint, {
    Duration? cacheDuration,
    bool forceRefresh = false,
    required T Function(dynamic json) parser,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = _cache.get<T>('get_$endpoint');
      if (cached != null) {
        debugPrint('💾 Cache hit: $endpoint');
        return cached;
      }
    }
    
    // Perform request with retries
    T? result;
    int retries = 0;
    
    final stopwatch = Stopwatch()..start();
    
    while (retries < _maxRetries) {
      try {
        // Simulate API call (replace with actual HTTP in production)
        result = parser({});
        stopwatch.stop();
        
        // Cache result
        _cache.set('get_$endpoint', result, ttl: cacheDuration);
        _monitor.recordMetric(endpoint, stopwatch.elapsed);
        
        debugPrint('✅ API call successful: $endpoint (${stopwatch.elapsedMilliseconds}ms)');
        return result;
      } catch (e) {
        retries++;
        debugPrint('❌ API call failed ($retries/$_maxRetries): $endpoint - $e');
        
        if (retries < _maxRetries) {
          await Future.delayed(_retryDelay * retries);
        }
      }
    }
    
    debugPrint('🚨 API call failed permanently: $endpoint');
    return result;
  }

  /// Execute POST request with error handling
  Future<T?> post<T>(
    String endpoint, {
    required dynamic body,
    required T Function(dynamic json) parser,
  }) async {
    int retries = 0;
    final stopwatch = Stopwatch()..start();
    
    while (retries < _maxRetries) {
      try {
        // Simulate API call (replace with actual HTTP in production)
        final result = parser({});
        stopwatch.stop();
        
        _monitor.recordMetric('${endpoint}_post', stopwatch.elapsed);
        debugPrint('✅ POST successful: $endpoint (${stopwatch.elapsedMilliseconds}ms)');
        
        return result;
      } catch (e) {
        retries++;
        debugPrint('❌ POST failed ($retries/$_maxRetries): $endpoint - $e');
        
        if (retries < _maxRetries) {
          await Future.delayed(_retryDelay * retries);
        }
      }
    }
    
    return null;
  }

  /// Batch multiple GET requests efficiently
  Future<List<T>> getBatch<T>(
    List<String> endpoints, {
    required T Function(dynamic json) parser,
    Duration? cacheDuration,
  }) async {
    final futures = endpoints.map((endpoint) =>
        get<T>(endpoint, cacheDuration: cacheDuration, parser: parser)
    ).toList();
    
    final results = await Future.wait(futures);
    return results.whereType<T>().toList();
  }

  /// Get performance stats
  void printStats() {
    debugPrint('\n📊 API Performance Report:');
    _monitor.getReport().forEach((operation, stats) {
      debugPrint('  $operation: $stats');
    });
    
    debugPrint('\n💾 Cache Stats:');
    final stats = _cache.getStats();
    debugPrint('  Size: ${stats['size']}/${stats['maxSize']}');
    debugPrint('  Hit Accuracy: ${(stats['accuracy'] * 100).toStringAsFixed(1)}%');
    debugPrint('');
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    debugPrint('🗑️ Cache cleared');
  }
}

/// Debouncer for expensive operations (search, filtering, etc.)
class Debouncer {
  final Duration delay;
  Timer? _timer;
  
  Debouncer({this.delay = const Duration(milliseconds: 300)});
  
  void call(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }
  
  void cancel() {
    _timer?.cancel();
  }
  
  void dispose() {
    _timer?.cancel();
  }
}

/// Throttler for rate-limiting operations (scroll listeners, etc.)
class Throttler {
  final Duration delay;
  DateTime? _lastCall;
  
  Throttler({this.delay = const Duration(milliseconds: 100)});
  
  void call(VoidCallback callback) {
    final now = DateTime.now();
    if (_lastCall == null || now.difference(_lastCall!).inMilliseconds >= delay.inMilliseconds) {
      _lastCall = now;
      callback();
    }
  }
}
