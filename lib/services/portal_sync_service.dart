import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as hp;
import 'package:shared_preferences/shared_preferences.dart';
import '../portal_screen.dart';

/// Data structure for passing parsing context to the Isolate
class _ParserInput {
  final String html;
  final String subject;
  final String type;
  _ParserInput(this.html, this.subject, this.type);
}

/// Service to handle background portal synchronization using saved session cookies.
class PortalSyncService {
  static const String _lastSyncKey = 'portal_last_bg_sync';
  static const String _lastSyncStatusKey = 'portal_last_bg_sync_status'; // 'success' or 'failed'
  static const String _syncCooldownKey = 'portal_sync_cooldown_ms';
  static const int _defaultCooldown = 4 * 60 * 60 * 1000; // 4 hours

  /// Global notifier for portal data changes
  static final ValueNotifier<int> syncNotifier = ValueNotifier(0);
  
  /// A notifier to pause background sync when the user is actively in the portal
  static final ValueNotifier<bool> isSyncPaused = ValueNotifier<bool>(false);

  /// Notifies all listeners that portal data has changed
  static void notifyUpdate() {
    syncNotifier.value++;
  }

  /// Performs a full background sync of assignments and quizzes.
  /// Uses saved cookies to avoid re-login.
  static Future<List<PortalTask>> performBackgroundSync({bool force = false}) async {
    if (isSyncPaused.value) return [];
    final prefs = await SharedPreferences.getInstance();
    
    if (!force) {
      final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
      final cooldown = prefs.getInt(_syncCooldownKey) ?? _defaultCooldown;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastSync < cooldown) return [];
    }

    try {
      final host = 'swl-sis.comsats.edu.pk'; 
      final cookieHeader = prefs.getString('iris_session_student_${host.toLowerCase()}_cookies');
      
      if (cookieHeader == null || cookieHeader.isEmpty) return [];

      final headers = {
        'Cookie': cookieHeader,
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; IRIS) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Referer': 'https://$host/Dashboard',
      };

      final dashResp = await http.get(Uri.parse('https://$host/Courses/Index'), headers: headers);
      if (dashResp.statusCode != 200) {
        await prefs.setString(_lastSyncStatusKey, 'failed');
        notifyUpdate();
        return [];
      }

      // Offload Dashboard Parsing to Isolate
      final courseData = await compute(_parseDashboard, dashResp.body);
      
      final results = <PortalTask>[];
      
      for (final course in courseData) {
        final courseUrl = course['url']!;
        final courseName = course['name']!;

        await http.get(Uri.parse('https://$host$courseUrl'), headers: headers);
        
        final assignResp = await http.get(Uri.parse('https://$host/Assignments/Index'), headers: headers);
        if (assignResp.statusCode == 200) {
          // Offload Assignment Parsing to Isolate
          final tasks = await compute(_parsePortalTableInIsolate, _ParserInput(assignResp.body, courseName, 'Assignment'));
          results.addAll(tasks);
        }

        var quizResp = await http.get(Uri.parse('https://$host/Course/Quizzes'), headers: headers);
        if (quizResp.statusCode != 200) {
           quizResp = await http.get(Uri.parse('https://$host/Quizzes/Index'), headers: headers);
        }
        
        if (quizResp.statusCode == 200) {
          // Offload Quiz Parsing to Isolate
          final tasks = await compute(_parsePortalTableInIsolate, _ParserInput(quizResp.body, courseName, 'Quiz'));
          results.addAll(tasks);
        }
      }

      if (results.isNotEmpty) {
        await _updateStoredTasks(results, prefs);
        notifyUpdate();
      }

      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_lastSyncStatusKey, 'success');
      return results;
    } catch (e) {
      debugPrint('Portal Background Sync Error: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncStatusKey, 'failed');
      notifyUpdate();
      return [];
    }
  }

  /// TOP-LEVEL/STATIC PARSING FUNCTIONS (Run in Isolate)
  static List<Map<String, String>> _parseDashboard(String html) {
    final doc = hp.parse(html);
    final courseRows = doc.querySelectorAll('table tr[onclick]');
    final results = <Map<String, String>>[];
    
    for (final row in courseRows) {
      final onclick = row.attributes['onclick'] ?? '';
      final match = RegExp(r"[']([^']+)[']").firstMatch(onclick);
      if (match == null) continue;
      
      results.add({
        'url': match.group(1)!,
        'name': row.children.length > 1 ? row.children[1].text.trim() : 'Unknown',
      });
    }
    return results;
  }

  static List<PortalTask> _parsePortalTableInIsolate(_ParserInput input) {
    final doc = hp.parse(input.html);
    final tables = doc.querySelectorAll('table');
    if (tables.isEmpty) return [];

    final list = <PortalTask>[];
    
    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 3) continue;

        final rowText = row.text.toLowerCase();
        final rowHtml = row.innerHtml.toLowerCase();
        final hasAction = rowText.contains('download') || 
                         rowText.contains('upload') || 
                         rowText.contains('submit') ||
                         rowHtml.contains('download') || 
                         rowHtml.contains('upload') || 
                         rowHtml.contains('submit') ||
                         rowText.contains('attempt');

        if (hasAction) {
          final title = (cells.length > 1 ? cells[1] : cells[0]).text.trim();
          
          String rawDate = cells.length > 3 ? cells[3].text.trim() : cells.last.text.trim();
          if (input.type == 'Quiz' && cells.length > 2) rawDate = cells[2].text.trim();

          String normalizedDate = rawDate;
          try {
            final parts = rawDate.split('-');
            if (parts.length == 3) {
              const months = {
                'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04', 'may': '05', 'jun': '06',
                'jul': '07', 'aug': '08', 'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12'
              };
              final d = parts[0].padLeft(2, '0');
              final m = months[parts[1].toLowerCase()] ?? '01';
              final y = parts[2];
              normalizedDate = '$y-$m-$d';
            }
          } catch(e) {}

          if (title.toLowerCase().contains('no data') || title.length < 2) continue;

          list.add(PortalTask(
            type: input.type,
            title: title,
            subject: input.subject,
            dueDate: normalizedDate,
            status: rowText.contains('submitted') ? 'Submitted' : 'Pending',
            isCompleted: rowText.contains('submitted') || 
                        rowText.contains('graded') || 
                        rowText.contains('result'),
            scrapedAt: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      }
    }
    return list;
  }

  static Future<void> _updateStoredTasks(List<PortalTask> newTasks, SharedPreferences prefs) async {
    const host = 'swl-sis.comsats.edu.pk';
    const scope = 'student';
    final sessionKey = 'iris_portal_${scope}_session_$host';
    final raw = prefs.getString(sessionKey);
    
    if (raw != null) {
      try {
        final sessionData = jsonDecode(raw) as Map<String, dynamic>;
        final session = PortalSession.fromJson(sessionData);
        
        final existingTasks = session.tasks;
        final mergedMap = <String, PortalTask>{};
        
        // 1. Start with existing tasks that haven't expired yet
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        for (final et in existingTasks) {
          final key = '${et.subject}_${et.title}_${et.type}';
          
          // Keep it if it's completed OR if the due date hasn't passed yet
          // (daysRemaining returns 999 if unparseable, which is fine to keep)
          if (et.isCompleted || et.daysRemaining >= 0) {
            mergedMap[key] = et;
          }
        }

        // 2. Merge in new tasks from the latest scrape
        for (final nt in newTasks) {
          final key = '${nt.subject}_${nt.title}_${nt.type}';
          final existing = mergedMap[key];
          
          if (existing != null) {
            // Update existing with new portal data but preserve user completion status
            mergedMap[key] = nt.copyWith(
              isCompleted: existing.isCompleted || nt.isCompleted,
            );
          } else {
            // Found a brand new task
            mergedMap[key] = nt;
          }
        }

        final updatedSession = session.copyWith(
          tasks: mergedMap.values.toList(),
          lastSyncAt: DateTime.now().millisecondsSinceEpoch,
        );
        await prefs.setString(sessionKey, jsonEncode(updatedSession.toJson()));
      } catch (e) {
        debugPrint('Error merging portal tasks: $e');
      }
    }
  }

  /// Expose the storage logic for use by other sync services (like the Headless scraper)
  static Future<void> updatePersistence(List<PortalTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await _updateStoredTasks(tasks, prefs);
  }
}
