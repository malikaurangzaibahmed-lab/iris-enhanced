import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple OTA (Over-The-Air) timetable update service
/// Enables pushing timetable updates to users without requiring app rebuild
class TimetableOTAService {
  // ============================================================
  // CONFIGURATION: Update these URLs based on your infrastructure
  // ============================================================
  
  // Option 1: Firebase Storage (FREE, recommended)
  // Enable public access in Firebase Storage rules:
  // if (resource.name.matches('.*timetable.*')) {
  //   allow read: if true;
  // }
  // static const String _timetableUrl = 
  //   'https://firebasestorage.googleapis.com/v0/b/YOUR-PROJECT.appspot.com/o/timetable_seed.json?alt=media';

  // Option 2: GitHub Raw Content (FREE, easy setup)
  // Make sure repo is public and file is in main branch
  // static const String _timetableUrl = 
  //   'https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/timetable_seed.json';

  // GitHub Raw Content (bypasses CDN caching - instant updates!)
  static const String _timetableUrl = 
    'https://raw.githubusercontent.com/malikaurangzaibahmed-lab/student-organizer-timetable/main/timetable_seed.json';
  
  // Metadata endpoint - optional (can be null for simple setups)
  static const String? _metadataUrl = null;

  static const String prefTimetableVersion = 'ota_timetable_version';
  static const String prefLastCheckTime = 'ota_last_check_time';
  static const String prefCachedTimetable = 'ota_cached_timetable';

  // Getter to suppress unused warnings on configuration constants
  static String get timetableUrl => _timetableUrl;
  static String? get metadataUrl => _metadataUrl;

  /// Check if new timetable version is available
  static Future<bool> isUpdateAvailable() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('global').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final remoteTimetableVersion = (data['active_timetable_version'] as num?)?.toInt() ?? 0;
        
        final prefs = await SharedPreferences.getInstance();
        final currentVersion = prefs.getInt(prefTimetableVersion) ?? 0;
        
        if (remoteTimetableVersion > currentVersion) {
          debugPrint('✅ New timetable available! Version $remoteTimetableVersion (current: $currentVersion)');
          return true;
        } else {
          debugPrint('✅ Timetable is up-to-date (version $currentVersion)');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Update check failed: $e');
    }
    return false;
  }

  /// Download and cache new timetable
  static Future<int> downloadTimetableUpdate() async {
    try {
      debugPrint('📥 Downloading timetable update from Firestore...');
      final doc = await FirebaseFirestore.instance.collection('config').doc('global').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final remoteTimetableJson = data['active_timetable_json']?.toString() ?? '';
        final remoteTimetableVersion = (data['active_timetable_version'] as num?)?.toInt() ?? 0;
        
        if (remoteTimetableJson.isNotEmpty) {
          // Validate JSON before caching
          final decoded = jsonDecode(remoteTimetableJson);
          int sessionCount = 0;
          if (decoded is List) {
            sessionCount = decoded.length;
          } else if (decoded is Map && decoded['sessions'] is List) {
            sessionCount = (decoded['sessions'] as List).length;
          } else {
            throw Exception('Invalid timetable format');
          }
          
          final prefs = await SharedPreferences.getInstance();
          
          // Check if content actually changed
          final cached = prefs.getString(prefCachedTimetable);
          if (cached == remoteTimetableJson) {
            debugPrint('ℹ️ Timetable is already up-to-date (no changes)');
            // Still update last check time even if no change
            await prefs.setInt(prefLastCheckTime, DateTime.now().millisecondsSinceEpoch);
            return 0; // No update available
          }
          
          // Cache the timetable JSON only if different
          await prefs.setString(prefCachedTimetable, remoteTimetableJson);
          await prefs.setInt(prefTimetableVersion, remoteTimetableVersion);
          await prefs.setInt(prefLastCheckTime, DateTime.now().millisecondsSinceEpoch);
          
          debugPrint('✅ Timetable updated from Firestore! ($sessionCount sessions)');
          return 1;
        }
      }
    } catch (e) {
      debugPrint('❌ Download failed: $e');
    }
    return -1;
  }

  /// Get cached timetable JSON
  static Future<String?> getCachedTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefCachedTimetable);
  }

  /// Check for updates (rate-limited to once per day)
  static Future<void> checkForUpdatesIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(prefLastCheckTime) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Only check once every 24 hours
    const checkInterval = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    
    if (now - lastCheck > checkInterval) {
      if (await isUpdateAvailable()) {
        await downloadTimetableUpdate();
      }
    }
  }

  /// Check for updates on app startup (no rate limit)
  static Future<void> checkForUpdatesOnStartup() async {
    debugPrint('🚀 Checking for timetable updates on startup...');
    if (await isUpdateAvailable()) {
      debugPrint('📥 Update available on startup - downloading...');
      await downloadTimetableUpdate();
    } else {
      debugPrint('✅ Timetable is current');
      // Update last check time even if no update available
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefLastCheckTime, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Force immediate timetable refresh (for manual update button)
  static Future<int> forceRefresh() async {
    debugPrint('🔄 Force refreshing timetable...');
    return await downloadTimetableUpdate();
  }

  /// Get update status info for UI
  static Future<Map<String, dynamic>> getUpdateStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(prefTimetableVersion) ?? 0;
    final lastCheck = prefs.getInt(prefLastCheckTime) ?? 0;
    
    String lastCheckStr = 'Never';
    if (lastCheck > 0) {
      final lastDate = DateTime.fromMillisecondsSinceEpoch(lastCheck);
      final now = DateTime.now();
      final diff = now.difference(lastDate);
      
      if (diff.inMinutes < 60) {
        lastCheckStr = '${diff.inMinutes} min ago';
      } else if (diff.inHours < 24) {
        lastCheckStr = '${diff.inHours} hours ago';
      } else {
        lastCheckStr = '${diff.inDays} days ago';
      }
    }
    
    return {
      'version': version,
      'lastCheck': lastCheckStr,
      'hasCached': await getCachedTimetable() != null,
    };
  }

  /// Integration point: Call this from main.dart on app startup
  static Future<void> initializeOTA() async {
    debugPrint('🚀 Initializing OTA timetable service...');
    await checkForUpdatesIfNeeded();
  }
}
