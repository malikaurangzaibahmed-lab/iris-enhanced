import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
      final prefs = await SharedPreferences.getInstance();
      
      // If no metadata endpoint, check if we have never downloaded before
      if (METADATA_URL == null) {
        final cachedTimetable = prefs.getString(PREF_CACHED_TIMETABLE);
        if (cachedTimetable == null) {
          print('✅ No cached timetable - update available');
          return true;
        }
        
        // For simple setups: download and compare content
        print('📡 Checking timetable for changes...');
        // Add cache-busting parameter to force GitHub to serve fresh file
        final cacheBustUrl = '$TIMETABLE_URL?t=${DateTime.now().millisecondsSinceEpoch}';
        final response = await http.get(Uri.parse(cacheBustUrl))
            .timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final isDifferent = response.body != cachedTimetable;
          if (isDifferent) {
            print('✅ Timetable has changed - update available');
          } else {
            print('✅ Timetable is up-to-date');
          }
          return isDifferent;
        }
        return false;
      }
      
      // With metadata endpoint
      final currentVersion = prefs.getInt(PREF_TIMETABLE_VERSION) ?? 0;
      print('📡 Checking for timetable updates...');
      final response = await http.get(Uri.parse(METADATA_URL!))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final metadata = jsonDecode(response.body) as Map<String, dynamic>;
        final latestVersion = metadata['version'] as int? ?? 1;
        
        if (latestVersion > currentVersion) {
          print('✅ New timetable available! Version $latestVersion (current: $currentVersion)');
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
      print('📥 Downloading timetable update...');
      // Add cache-busting parameter to force GitHub to serve fresh file
      final cacheBustUrl = '$TIMETABLE_URL?t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.get(Uri.parse(cacheBustUrl))
          .timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        // Validate JSON before caching
        final data = jsonDecode(response.body);
        
        // Support both formats:
        // 1. Direct array: [{"batch":...}, ...]
        // 2. Object with sessions key: {"sessions": [...]}
        int sessionCount = 0;
        if (data is List) {
          sessionCount = data.length;
        } else if (data is Map && data['sessions'] is List) {
          sessionCount = (data['sessions'] as List).length;
        } else {
          throw Exception('Invalid timetable format');
        }
        
        final prefs = await SharedPreferences.getInstance();
        
        // Check if content actually changed
        final cached = prefs.getString(PREF_CACHED_TIMETABLE);
        if (cached == response.body) {
          print('ℹ️ Timetable is already up-to-date (no changes)');
          // Still update last check time even if no change
          await prefs.setInt(PREF_LAST_CHECK_TIME, DateTime.now().millisecondsSinceEpoch);
          return 0; // No update available
        }
        
        // Cache the timetable JSON only if different
        await prefs.setString(PREF_CACHED_TIMETABLE, response.body);
        
        // Use current timestamp as version (simple but effective)
        final version = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(PREF_TIMETABLE_VERSION, version);
        await prefs.setInt(PREF_LAST_CHECK_TIME, version);
        
        print('✅ Timetable updated! ($sessionCount sessions, ${response.body.length} bytes)');
        return 1;
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
