import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Intelligent Device Performance Detector for IRIS.
/// Detects low-RAM devices (<= 4GB), weak processor architectures,
/// and auto-tunes Eco Mode for silky-smooth 60-120 FPS rendering.
class DevicePerformance {
  static bool? _isLowEndCached;
  static String? _deviceSummary;

  static String get deviceSummary => _deviceSummary ?? 'Standard Device';

  /// Determines if the device is a low-end / low-RAM device (e.g. <= 4GB RAM, <= 4 CPU cores, low-RAM Android flag).
  static Future<bool> isLowEndDevice() async {
    if (_isLowEndCached != null) return _isLowEndCached!;

    try {
      if (kIsWeb) {
        _isLowEndCached = false;
        return false;
      }

      final coreCount = Platform.numberOfProcessors;
      bool isLowRam = false;
      int sdkInt = 34;

      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        isLowRam = androidInfo.isLowRamDevice;
        sdkInt = androidInfo.version.sdkInt;

        _deviceSummary =
            '${androidInfo.brand} ${androidInfo.model} ($coreCount cores, Android $sdkInt${isLowRam ? ', Low-RAM' : ''})';
      } else {
        _deviceSummary = '${Platform.operatingSystem} ($coreCount cores)';
      }

      // Criteria for low-end hardware auto-tuning:
      // 1. Android OS marked as isLowRamDevice (devices with <= 3-4 GB RAM)
      // 2. Quad-core or lower processors (<= 4 cores)
      // 3. Android 9 (SDK <= 28) or older legacy device
      final isLowEnd = isLowRam || coreCount <= 4 || sdkInt <= 28;
      _isLowEndCached = isLowEnd;
      return isLowEnd;
    } catch (e) {
      debugPrint('DevicePerformance check error: $e');
      _isLowEndCached = false;
      return false;
    }
  }

  /// Synchronous fallback helper
  static bool isLowEndSync() {
    try {
      return _isLowEndCached ?? (Platform.numberOfProcessors <= 4);
    } catch (_) {
      return false;
    }
  }
}
