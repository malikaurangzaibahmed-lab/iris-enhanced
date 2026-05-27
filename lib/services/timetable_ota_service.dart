import 'dart:convert';
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
  // static const String TIMETABLE_URL = 
  //   'https://firebasestorage.googleapis.com/v0/b/YOUR-PROJECT.appspot.com/o/timetable_seed.json?alt=media';

  // Option 2: GitHub Raw Content (FREE, easy setup)
  // Make sure repo is public and file is in main branch
  // static const String TIMETABLE_URL = 
  //   'https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/timetable_seed.json';

  // GitHub Raw Content (bypasses CDN caching - instant updates!)
  static const String TIMETABLE_URL = 
    'https://raw.githubusercontent.com/malikaurangzaibahmed-lab/student-organizer-timetable/main/timetable_seed.json';
  
  // Metadata endpoint - optional (can be null for simple setups)
  static const String? METADATA_URL = null;

  static const String PREF_TIMETABLE_VERSION = 'ota_timetable_version';
  static const String PREF_LAST_CHECK_TIME = 'ota_last_check_time';
  static const String PREF_CACHED_TIMETABLE = 'ota_cached_timetable';
  static const String PREF_CACHED_METADATA = 'ota_cached_metadata';

  /// Check if new timetable version is available
  static Future<bool> isUpdateAvailable() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('global').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final remoteTimetableVersion = data['active_timetable_version'] as int? ?? 0;
        
        final prefs = await SharedPreferences.getInstance();
        final currentVersion = prefs.getInt(PREF_TIMETABLE_VERSION) ?? 0;
        
        if (remoteTimetableVersion > currentVersion) {
          print('✅ New timetable available! Version $remoteTimetableVersion (current: $currentVersion)');
          return true;
        } else {
          print('✅ Timetable is up-to-date (version $currentVersion)');
        }
      }
    } catch (e) {
      print('⚠️ Update check failed: $e');
    }
    return false;
  }

  /// Download and cache new timetable
  static Future<int> downloadTimetableUpdate() async {
    try {
      print('📥 Downloading timetable update from Firestore...');
      final doc = await FirebaseFirestore.instance.collection('config').doc('global').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final remoteTimetableJson = data['active_timetable_json']?.toString() ?? '';
        final remoteTimetableVersion = data['active_timetable_version'] as int? ?? 0;
        
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
          final cached = prefs.getString(PREF_CACHED_TIMETABLE);
          if (cached == remoteTimetableJson) {
            print('ℹ️ Timetable is already up-to-date (no changes)');
            // Still update last check time even if no change
            await prefs.setInt(PREF_LAST_CHECK_TIME, DateTime.now().millisecondsSinceEpoch);
            return 0; // No update available
          }
          
          // Cache the timetable JSON only if different
          await prefs.setString(PREF_CACHED_TIMETABLE, remoteTimetableJson);
          await prefs.setInt(PREF_TIMETABLE_VERSION, remoteTimetableVersion);
          await prefs.setInt(PREF_LAST_CHECK_TIME, DateTime.now().millisecondsSinceEpoch);
          
          print('✅ Timetable updated from Firestore! ($sessionCount sessions)');
          return 1;
        }
      }
    } catch (e) {
      print('❌ Download failed: $e');
    }
    return -1;
  }

  /// Get cached timetable JSON
  static Future<String?> getCachedTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(PREF_CACHED_TIMETABLE);
  }

  /// Check for updates (rate-limited to once per day)
  static Future<void> checkForUpdatesIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(PREF_LAST_CHECK_TIME) ?? 0;
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
    print('🚀 Checking for timetable updates on startup...');
    if (await isUpdateAvailable()) {
      print('📥 Update available on startup - downloading...');
      await downloadTimetableUpdate();
    } else {
      print('✅ Timetable is current');
      // Update last check time even if no update available
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(PREF_LAST_CHECK_TIME, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Force immediate timetable refresh (for manual update button)
  static Future<int> forceRefresh() async {
    print('🔄 Force refreshing timetable...');
    return await downloadTimetableUpdate();
  }

  /// Get update status info for UI
  static Future<Map<String, dynamic>> getUpdateStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(PREF_TIMETABLE_VERSION) ?? 0;
    final lastCheck = prefs.getInt(PREF_LAST_CHECK_TIME) ?? 0;
    
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
    print('🚀 Initializing OTA timetable service...');
    await checkForUpdatesIfNeeded();
  }
}
