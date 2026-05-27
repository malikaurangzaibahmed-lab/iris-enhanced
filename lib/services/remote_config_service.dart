import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'timetable_ota_service.dart';
import '../services/ui_feedback.dart';

/// Central Remote Synchronization Engine for IRIS Enhanced.
/// Establishes real-time listeners with Firebase Firestore to toggle academic modes,
/// sync OTA timetable schedules, and notify users about system update APKs.
class RemoteConfigService {
  static const int CURRENT_VERSION_CODE = 1;
  static const String CURRENT_VERSION_NAME = '1.0.0';

  static final ValueNotifier<String> activeAcademicPeriod = ValueNotifier<String>('classes');
  static final ValueNotifier<Map<String, dynamic>?> latestApkUpdate = ValueNotifier<Map<String, dynamic>?>(null);
  static final ValueNotifier<Map<String, dynamic>?> liveAnnouncement = ValueNotifier<Map<String, dynamic>?>(null);
  
  static bool _isListening = false;

  /// Start real-time Firestore stream to listen for remote administration config changes
  static void startRemoteListener(BuildContext context) {
    if (_isListening) return;
    _isListening = true;

    print('📡 IRIS Remote Engine: Connecting Firestore streams...');
    
    FirebaseFirestore.instance
        .collection('config')
        .doc('global')
        .snapshots()
        .listen((DocumentSnapshot doc) async {
      if (!doc.exists) {
        print('⚠️ IRIS Remote Engine: Global remote config document not found.');
        return;
      }

      final data = doc.data() as Map<String, dynamic>? ?? {};

      // 1. Process Academic Period Mode Swapping
      final remotePeriod = data['academic_period']?.toString() ?? 'classes';
      if (remotePeriod != activeAcademicPeriod.value) {
        activeAcademicPeriod.value = remotePeriod;
        print('⚡ IRIS Remote Engine: Academic Period Swapped to: $remotePeriod');
        IrisHaptics.actionHeavy();
        
        // Notify user about remote academic mode shift
        if (context.mounted) {
          showIrisFrostedSnackBar(
            context,
            content: Text(
              'Academic mode changed to: ${remotePeriod.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            tint: _getModeColor(remotePeriod),
          );
        }
      }

      // 2. Process OTA Timetable Upgrades
      final remoteTimetableVersion = data['active_timetable_version'] as int? ?? 0;
      final remoteTimetableJson = data['active_timetable_json']?.toString() ?? '';
      
      if (remoteTimetableJson.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final currentTimetableVersion = prefs.getInt(TimetableOTAService.PREF_TIMETABLE_VERSION) ?? 0;
        
        if (remoteTimetableVersion > currentTimetableVersion) {
          print('📥 IRIS Remote Engine: Downloading remote timetable seed upgrade (v$remoteTimetableVersion)...');
          try {
            // Validate and parse the raw JSON payload directly
            final decoded = jsonDecode(remoteTimetableJson);
            int sessionCount = 0;
            if (decoded is List) {
              sessionCount = decoded.length;
            } else if (decoded is Map && decoded['sessions'] is List) {
              sessionCount = (decoded['sessions'] as List).length;
            }
            
            // Persist locally
            await prefs.setString(TimetableOTAService.PREF_CACHED_TIMETABLE, remoteTimetableJson);
            await prefs.setInt(TimetableOTAService.PREF_TIMETABLE_VERSION, remoteTimetableVersion);
            await prefs.setInt(TimetableOTAService.PREF_LAST_CHECK_TIME, remoteTimetableVersion);
            
            print('✅ IRIS Remote Engine: Saved timetable OTA data ($sessionCount sessions)');
            
            if (context.mounted) {
              showIrisFrostedSnackBar(
                context,
                content: const Text('✅ Remote Timetable sync complete! Rebuilding schedule...'),
                tint: const Color(0xFF10B981),
              );
            }
          } catch (e) {
            print('❌ IRIS Remote Engine: Timetable sync failed: $e');
          }
        }
      }

      // 3. Process Remote APK Update Notifications
      final updateData = data['latest_apk_update'] as Map<String, dynamic>?;
      if (updateData != null) {
        final remoteCode = updateData['version_code'] as int? ?? 1;
        if (remoteCode > CURRENT_VERSION_CODE) {
          print('🚀 IRIS Remote Engine: APK System Update available! version_code: $remoteCode');
          latestApkUpdate.value = updateData;
        } else {
          latestApkUpdate.value = null; // Up-to-date
        }
      }

      // 4. Process Live Broadcast Announcement Banners
      final broadcastEnabled = data['broadcast_enabled'] as bool? ?? false;
      final broadcastMsg = data['broadcast_message']?.toString() ?? '';
      
      if (broadcastEnabled && broadcastMsg.isNotEmpty) {
        liveAnnouncement.value = {
          'message': broadcastMsg,
          'enabled': broadcastEnabled,
          'updated_at': data['updated_at'] ?? Timestamp.now(),
        };
      } else {
        liveAnnouncement.value = null;
      }
    }, onError: (err) {
      print('⚠️ IRIS Remote Engine Stream Error: $err');
    });
  }

  static Color _getModeColor(String period) {
    switch (period) {
      case 'classes': return const Color(0xFF3A86FF); // Brand blue
      case 'midterms': return const Color(0xFFF59E0B); // Amber
      case 'finals': return const Color(0xFFF43F5E); // Rose
      case 'sports_week': return const Color(0xFF10B981); // Emerald
      default: return const Color(0xFF3A86FF);
    }
  }
}
