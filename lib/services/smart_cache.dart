import 'package:flutter/foundation.dart';

/// Smart performance optimization layer
class SmartCache {
  static final SmartCache _instance = SmartCache._internal();
  
  factory SmartCache() {
    return _instance;
  }
  
  SmartCache._internal();
  
  final Map<String, _CacheEntry> _cache = {};
  final Map<String, int> _accessCount = {};
  
  static const int _maxCacheSize = 100;
  static const Duration _defaultTTL = Duration(minutes: 5);

  /// Get cached value or null if expired
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (DateTime.now().isAfter(entry.expiryTime)) {
      _cache.remove(key);
      return null;
    }
    
    // Track access for smart eviction
    _accessCount[key] = (_accessCount[key] ?? 0) + 1;
    return entry.value as T?;
  }

  /// Set cache value with optional TTL
  void set<T>(String key, T value, {Duration? ttl}) {
    if (_cache.length >= _maxCacheSize) {
      _evictLeastUsed();
    }
    
    _cache[key] = _CacheEntry(
      value: value,
      expiryTime: DateTime.now().add(ttl ?? _defaultTTL),
    );
  }

  /// Check if key exists and is valid
  bool contains(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    
    if (DateTime.now().isAfter(entry.expiryTime)) {
      _cache.remove(key);
      return false;
    }
    
    return true;
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
    _accessCount.clear();
  }

  /// Evict least used entry
  void _evictLeastUsed() {
    if (_cache.isEmpty) return;
    
    final leastUsed = _accessCount.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
    
    _cache.remove(leastUsed);
    _accessCount.remove(leastUsed);
  }

  /// Get cache stats
  Map<String, dynamic> getStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
      'accuracy': _cache.isNotEmpty 
          ? _accessCount.values.fold(0, (a, b) => a + b) / _cache.length 
          : 0,
    };
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiryTime;

  _CacheEntry({
    required this.value,
    required this.expiryTime,
  });
}

/// Performance monitor
class PerfMonitor {
  static final PerfMonitor _instance = PerfMonitor._internal();
  
  factory PerfMonitor() {
    return _instance;
  }
  
  PerfMonitor._internal();
  
  final Map<String, List<Duration>> _metrics = {};
  
  /// Record operation duration
  void recordMetric(String name, Duration duration) {
    _metrics.putIfAbsent(name, () => []).add(duration);
    
    // Keep only last 100 measurements for memory efficiency
    if (_metrics[name]!.length > 100) {
      _metrics[name]!.removeAt(0);
    }
  }

  /// Get average duration for operation
  Duration? getAverageDuration(String name) {
    final measurements = _metrics[name];
    if (measurements == null || measurements.isEmpty) return null;
    
    final total = measurements.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    return Duration(milliseconds: total ~/ measurements.length);
  }

  /// Get performance report
  Map<String, String> getReport() {
    final report = <String, String>{};
    
    _metrics.forEach((name, measurements) {
      if (measurements.isNotEmpty) {
        final avg = getAverageDuration(name);
        final min = measurements.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
        final max = measurements.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        
        report[name] = 'avg: ${avg?.inMilliseconds}ms, min: ${min}ms, max: ${max}ms';
      }
    });
    
    return report;
  }

  /// Clear metrics
  void clear() {
    _metrics.clear();
  }
}

/// Global performance tracker for expensive operations
extension PerfTracker<T> on Future<T> {
  Future<T> trackPerf(String operationName) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await this;
    } finally {
      stopwatch.stop();
      PerfMonitor().recordMetric(operationName, stopwatch.elapsed);
      debugPrint('⏱️ $operationName: ${stopwatch.elapsedMilliseconds}ms');
    }
  }
}
