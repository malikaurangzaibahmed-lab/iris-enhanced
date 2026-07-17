import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central configuration management system
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  
  factory AppConfig() {
    return _instance;
  }
  
  AppConfig._internal();
  
  late SharedPreferences _prefs;
  final Map<String, dynamic> _configCache = {};
  
  // Default configurations
  static const String _keyAppVersion = 'app_version';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyCacheDuration = 'cache_duration_mins';
  static const String _keyMaxRetries = 'max_retries';
  static const String _keyEnableAnalytics = 'enable_analytics';
  static const String _keyEnableCrashReporting = 'enable_crash_reporting';
  static const String _keyNotificationTimeout = 'notification_timeout_secs';
  static const String _keyWidgetUpdateInterval = 'widget_update_interval_secs';
  
  // Default values
  /// App version
  static const String version = '1.0.0';
  static const int defaultCacheDurationMins = 5;
  static const int defaultMaxRetries = 3;
  static const bool defaultEnableAnalytics = true;
  static const bool defaultEnableCrashReporting = true;
  static const int defaultNotificationTimeoutSecs = 5;
  static const int defaultWidgetUpdateIntervalSecs = 30;

  /// Initialize configuration system
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('⚙️ AppConfig initialized');
  }

  // Getters for all configuration values
  String get appVersion => getValue<String>(_keyAppVersion, version);
  
  String get themeMode =>
      getValue<String>(_keyThemeMode, 'system');

  int get cacheDurationMins =>
      getValue<int>(_keyCacheDuration, defaultCacheDurationMins);

  int get maxRetries =>
      getValue<int>(_keyMaxRetries, defaultMaxRetries);

  bool get enableAnalytics =>
      getValue<bool>(_keyEnableAnalytics, defaultEnableAnalytics);

  bool get enableCrashReporting =>
      getValue<bool>(_keyEnableCrashReporting, defaultEnableCrashReporting);

  int get notificationTimeoutSecs =>
      getValue<int>(_keyNotificationTimeout, defaultNotificationTimeoutSecs);

  int get widgetUpdateIntervalSecs =>
      getValue<int>(_keyWidgetUpdateInterval, defaultWidgetUpdateIntervalSecs);

  /// Generic getter with type safety
  T getValue<T>(String key, T defaultValue) {
    if (_configCache.containsKey(key)) {
      return _configCache[key] as T;
    }

    try {
      if (T == String) {
        final value = _prefs.getString(key) ?? defaultValue;
        _configCache[key] = value;
        return value as T;
      } else if (T == int) {
        final value = _prefs.getInt(key) ?? defaultValue;
        _configCache[key] = value;
        return value as T;
      } else if (T == bool) {
        final value = _prefs.getBool(key) ?? defaultValue;
        _configCache[key] = value;
        return value as T;
      } else if (T == double) {
        final value = _prefs.getDouble(key) ?? defaultValue;
        _configCache[key] = value;
        return value as T;
      }
    } catch (e) {
      debugPrint('❌ Error reading config $key: $e');
    }

    return defaultValue;
  }

  /// Generic setter with caching
  Future<bool> setValue<T>(String key, T value) async {
    try {
      bool success = false;

      if (value is String) {
        success = await _prefs.setString(key, value);
      } else if (value is int) {
        success = await _prefs.setInt(key, value);
      } else if (value is bool) {
        success = await _prefs.setBool(key, value);
      } else if (value is double) {
        success = await _prefs.setDouble(key, value);
      }

      if (success) {
        _configCache[key] = value;
        print('✅ Config updated: $key = $value');
      } else {
        print('❌ Failed to save config: $key');
      }

      return success;
    } catch (e) {
      print('❌ Error saving config $key: $e');
      return false;
    }
  }

  /// Get all configuration as map
  Map<String, dynamic> getAll() {
    return {
      'appVersion': appVersion,
      'themeMode': themeMode,
      'cacheDurationMins': cacheDurationMins,
      'maxRetries': maxRetries,
      'enableAnalytics': enableAnalytics,
      'enableCrashReporting': enableCrashReporting,
      'notificationTimeoutSecs': notificationTimeoutSecs,
      'widgetUpdateIntervalSecs': widgetUpdateIntervalSecs,
    };
  }

  /// Print configuration
  void printConfig() {
    print('\n⚙️ App Configuration:');
    getAll().forEach((key, value) {
      print('  $key: $value');
    });
    print('');
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    print('🔄 Resetting configuration to defaults...');
    
    await setValue(_keyAppVersion, appVersion);
    await setValue(_keyThemeMode, 'system');
    await setValue(_keyCacheDuration, defaultCacheDurationMins);
    await setValue(_keyMaxRetries, defaultMaxRetries);
    await setValue(_keyEnableAnalytics, defaultEnableAnalytics);
    await setValue(_keyEnableCrashReporting, defaultEnableCrashReporting);
    await setValue(_keyNotificationTimeout, defaultNotificationTimeoutSecs);
    await setValue(_keyWidgetUpdateInterval, defaultWidgetUpdateIntervalSecs);
    
    print('✅ Configuration reset to defaults');
  }

  /// Clear all configuration
  Future<void> clear() async {
    await _prefs.clear();
    _configCache.clear();
    print('🗑️ All configuration cleared');
  }
}

/// Feature flag system for A/B testing and gradual rollouts
class FeatureFlags {
  static final FeatureFlags _instance = FeatureFlags._internal();
  
  factory FeatureFlags() {
    return _instance;
  }
  
  FeatureFlags._internal();
  
  final Map<String, bool> _flags = {
    'enhanced_study_spaces': true,
    'pdf_timetable_parser': true,
    'room_occupancy_tracking': true,
    'smart_caching': true,
    'crash_reporting': true,
    'analytics': true,
  };

  /// Check if feature is enabled
  bool isEnabled(String featureName) {
    return _flags[featureName] ?? false;
  }

  /// Enable feature
  void enable(String featureName) {
    _flags[featureName] = true;
    print('✅ Feature enabled: $featureName');
  }

  /// Disable feature
  void disable(String featureName) {
    _flags[featureName] = false;
    print('❌ Feature disabled: $featureName');
  }

  /// Get all flags
  Map<String, bool> getAll() => Map.from(_flags);

  /// Print flags
  void printFlags() {
    print('\n🚩 Feature Flags:');
    _flags.forEach((name, enabled) {
      print('  $name: ${enabled ? '✅' : '❌'}');
    });
    print('');
  }
}
