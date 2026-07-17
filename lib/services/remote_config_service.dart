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
  static const int CURRENT_VERSION_CODE = 2;
  static const String CURRENT_VERSION_NAME = '1.0.1';

  static final ValueNotifier<String> activeAcademicPeriod = ValueNotifier<String>('classes');
  static final ValueNotifier<Map<String, dynamic>?> latestApkUpdate = ValueNotifier<Map<String, dynamic>?>(null);
  static final ValueNotifier<Map<String, dynamic>?> liveAnnouncement = ValueNotifier<Map<String, dynamic>?>(null);
  static final ValueNotifier<DateTime?> lastConfigUpdateTime = ValueNotifier<DateTime?>(null);
  static final ValueNotifier<DateTime?> lastTimetableUpdateTime = ValueNotifier<DateTime?>(null);
  static final ValueNotifier<List<dynamic>> midtermExams = ValueNotifier<List<dynamic>>([]);
  static final ValueNotifier<List<dynamic>> finalExams = ValueNotifier<List<dynamic>>([]);


  /// Helper to format raw timestamps/DateTimes safely in a custom, premium aesthetic
  static String formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return 'Never';
    final localDateTime = dateTime.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[localDateTime.month - 1];
    final day = localDateTime.day;
    final hourVal = localDateTime.hour == 0 ? 12 : (localDateTime.hour > 12 ? localDateTime.hour - 12 : localDateTime.hour);
    final minuteVal = localDateTime.minute.toString().padLeft(2, '0');
    final period = localDateTime.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $hourVal:$minuteVal $period';
  }
  
  static bool _isListening = false;

  /// Start real-time Firestore stream to listen for remote administration config changes
  static void startRemoteListener(BuildContext context) {
    if (_isListening) return;
    _isListening = true;

    // Load cached exams and mode from local storage for offline resiliency
    SharedPreferences.getInstance().then((prefs) {
      final cachedPeriod = prefs.getString('active_academic_period') ?? 'classes';
      activeAcademicPeriod.value = cachedPeriod;

      final cachedMidterms = prefs.getString('cached_midterm_exams') ?? '';
      if (cachedMidterms.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedMidterms);
          if (decoded is List) {
            midtermExams.value = decoded;
          }
        } catch (_) {}
      }
      final cachedFinals = prefs.getString('cached_finals_exams') ?? '';
      if (cachedFinals.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedFinals);
          if (decoded is List) {
            finalExams.value = decoded;
          }
        } catch (_) {}
      }
    });

    debugPrint('📡 IRIS Remote Engine: Connecting Firestore streams...');
    
    FirebaseFirestore.instance
        .collection('config')
        .doc('global')
        .snapshots()
        .listen((DocumentSnapshot doc) async {
      if (!doc.exists) {
        debugPrint('⚠️ IRIS Remote Engine: Global remote config document not found.');
        return;
      }

      final data = doc.data() as Map<String, dynamic>? ?? {};

      // Parse config update time
      final dynamic configUpdateRaw = data['updated_at'];
      if (configUpdateRaw != null) {
        if (configUpdateRaw is Timestamp) {
          lastConfigUpdateTime.value = configUpdateRaw.toDate();
        } else if (configUpdateRaw is DateTime) {
          lastConfigUpdateTime.value = configUpdateRaw;
        } else if (configUpdateRaw is String) {
          lastConfigUpdateTime.value = DateTime.tryParse(configUpdateRaw);
        }
      }

      // 1. Process Academic Period Mode Swapping
      final remotePeriod = data['academic_period']?.toString() ?? 'classes';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_academic_period', remotePeriod);

      if (remotePeriod != activeAcademicPeriod.value) {
        activeAcademicPeriod.value = remotePeriod;
        debugPrint('⚡ IRIS Remote Engine: Academic Period Swapped to: $remotePeriod');
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
      final remoteTimetableVersion = (data['active_timetable_version'] as num?)?.toInt() ?? 0;
      final remoteTimetableJson = data['active_timetable_json']?.toString() ?? '';
      
      if (remoteTimetableVersion > 0) {
        if (remoteTimetableVersion.toString().length == 10) {
          lastTimetableUpdateTime.value = DateTime.fromMillisecondsSinceEpoch(remoteTimetableVersion * 1000);
        } else {
          lastTimetableUpdateTime.value = DateTime.fromMillisecondsSinceEpoch(remoteTimetableVersion);
        }
      }

      if (remoteTimetableJson.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final currentTimetableVersion = prefs.getInt(TimetableOTAService.prefTimetableVersion) ?? 0;
        
        if (remoteTimetableVersion > currentTimetableVersion) {
          debugPrint('📥 IRIS Remote Engine: Downloading remote timetable seed upgrade (v$remoteTimetableVersion)...');
          try {
            // Validate and parse the raw JSON payload directly
            final decoded = jsonDecode(remoteTimetableJson);
            int sessionCount = 0;
            if (decoded is List) {
              sessionCount = decoded.length;
            } else if (decoded is Map && decoded['sessions'] is List) {
              sessionCount = (decoded['sessions'] as List).length;
            }
            
            final oldJson = prefs.getString(TimetableOTAService.prefCachedTimetable) ?? '';
            final userBatch = prefs.getString('user_batch') ?? '';
            if (oldJson.isNotEmpty && userBatch.isNotEmpty) {
              final diffs = _calculateTimetableDiffs(oldJson, remoteTimetableJson, userBatch);
              if (diffs.isNotEmpty) {
                await prefs.setString('ota_timetable_changes', jsonEncode(diffs));
              }
            }
            
            // Persist locally
            await prefs.setString(TimetableOTAService.prefCachedTimetable, remoteTimetableJson);
            await prefs.setInt(TimetableOTAService.prefTimetableVersion, remoteTimetableVersion);
            await prefs.setInt(TimetableOTAService.prefLastCheckTime, remoteTimetableVersion);
            
            debugPrint('✅ IRIS Remote Engine: Saved timetable OTA data ($sessionCount sessions)');
            
            if (context.mounted) {
              showIrisFrostedSnackBar(
                context,
                content: const Text('✅ Remote Timetable sync complete! Rebuilding schedule...'),
                tint: const Color(0xFF10B981),
              );
            }
          } catch (e) {
            debugPrint('❌ IRIS Remote Engine: Timetable sync failed: $e');
          }
        }
      }

      // 3. Process Remote APK Update Notifications
      final rawUpdate = data['latest_apk_update'];
      Map<String, dynamic>? updateData;
      if (rawUpdate is Map) {
        updateData = Map<String, dynamic>.from(rawUpdate);
      }
      if (updateData != null) {
        final showUpdate = updateData['show_update_card'] as bool? ?? true;
        if (showUpdate) {
          latestApkUpdate.value = updateData;
        } else {
          latestApkUpdate.value = null;
        }
      } else {
        latestApkUpdate.value = null;
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

      // 5. Process Midterm and Final term Date Sheets
      final midtermJsonRaw = data['active_midterm_json']?.toString() ?? '';
      if (midtermJsonRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(midtermJsonRaw);
          if (decoded is List) {
            midtermExams.value = decoded;
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('cached_midterm_exams', midtermJsonRaw);
            });
          }
        } catch (e) {
          debugPrint('❌ IRIS Remote Engine: Failed to parse active_midterm_json: $e');
        }
      } else {
        midtermExams.value = [];
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('cached_midterm_exams');
        });
      }

      final finalsJsonRaw = data['active_finals_json']?.toString() ?? '';
      if (finalsJsonRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(finalsJsonRaw);
          if (decoded is List) {
            finalExams.value = decoded;
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('cached_finals_exams', finalsJsonRaw);
            });
          }
        } catch (e) {
          debugPrint('❌ IRIS Remote Engine: Failed to parse active_finals_json: $e');
        }
      } else {
        finalExams.value = [];
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('cached_finals_exams');
        });
      }
    }, onError: (err) {
      debugPrint('⚠️ IRIS Remote Engine Stream Error: $err');
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

  static List<String> _calculateTimetableDiffs(
      String oldJson, String newJson, String userBatch) {
    final List<String> diffs = [];
    try {
      final oldDecoded = jsonDecode(oldJson);
      final newDecoded = jsonDecode(newJson);

      List<dynamic> oldList = [];
      if (oldDecoded is List) {
        oldList = oldDecoded;
      } else if (oldDecoded is Map && oldDecoded['sessions'] is List) {
        oldList = oldDecoded['sessions'] as List;
      }

      List<dynamic> newList = [];
      if (newDecoded is List) {
        newList = newDecoded;
      } else if (newDecoded is Map && newDecoded['sessions'] is List) {
        newList = newDecoded['sessions'] as List;
      }

      final targetBatchLower = userBatch.trim().toLowerCase();

      // Helper to match batch
      bool matchesBatch(dynamic item) {
        if (item is! Map) return false;
        final batchVal = (item['batch'] ?? item['class_name'] ?? item['section'] ?? '').toString().trim().toLowerCase();
        return batchVal == targetBatchLower;
      }

      final oldSessions = oldList
          .where(matchesBatch)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final newSessions = newList
          .where(matchesBatch)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      // Helpers to identify key fields
      String getDay(Map<String, dynamic> item) => (item['day'] ?? item['weekday'] ?? 'Monday').toString();
      String getSubject(Map<String, dynamic> item) => (item['subject'] ?? item['course'] ?? item['title'] ?? 'Unknown').toString();
      String getRoom(Map<String, dynamic> item) => (item['room'] ?? item['location'] ?? 'TBD').toString();
      String getTeacher(Map<String, dynamic> item) => (item['teacher'] ?? item['instructor'] ?? item['staff'] ?? 'Unknown').toString();
      String getTime(Map<String, dynamic> item) {
        if (item['start'] != null) {
          return '${item['start']}-${item['end']}';
        }
        return (item['time'] ?? item['period'] ?? '00:00').toString();
      }

      // Check for room changes or teacher changes or removed classes
      for (final oldItem in oldSessions) {
        final oldDay = getDay(oldItem);
        final oldTime = getTime(oldItem);
        final oldSubj = getSubject(oldItem);

        // Find match in new sessions
        final match = newSessions.firstWhere(
          (newItem) =>
              getDay(newItem).toLowerCase() == oldDay.toLowerCase() &&
              getTime(newItem).toLowerCase() == oldTime.toLowerCase() &&
              getSubject(newItem).toLowerCase() == oldSubj.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );

        if (match.isEmpty) {
          // Class was removed
          diffs.add('Cancelled class: $oldSubj on $oldDay at $oldTime');
        } else {
          final oldRoom = getRoom(oldItem);
          final newRoom = getRoom(match);
          if (oldRoom.toLowerCase() != newRoom.toLowerCase()) {
            diffs.add('Room changed: $oldSubj now in $newRoom (was $oldRoom) on $oldDay at $oldTime');
          }

          final oldTeach = getTeacher(oldItem);
          final newTeach = getTeacher(match);
          if (oldTeach.toLowerCase() != newTeach.toLowerCase()) {
            diffs.add('Instructor changed: $oldSubj now taught by $newTeach on $oldDay');
          }
        }
      }

      // Check for newly added classes
      for (final newItem in newSessions) {
        final newDay = getDay(newItem);
        final newTime = getTime(newItem);
        final newSubj = getSubject(newItem);

        final exists = oldSessions.any(
          (oldItem) =>
              getDay(oldItem).toLowerCase() == newDay.toLowerCase() &&
              getTime(oldItem).toLowerCase() == newTime.toLowerCase() &&
              getSubject(oldItem).toLowerCase() == newSubj.toLowerCase(),
        );

        if (!exists) {
          final newRoom = getRoom(newItem);
          diffs.add('New class added: $newSubj in $newRoom on $newDay at $newTime');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to calculate timetable diffs: $e');
    }
    return diffs;
  }

}

