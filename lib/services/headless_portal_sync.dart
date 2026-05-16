import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../portal_screen.dart';
import 'portal_sync_service.dart';

/// A hidden WebView that performs background scraping without interrupting the user.
class HeadlessPortalSync extends StatefulWidget {
  final String url;
  final Function(List<PortalTask>)? onSyncComplete;

  final bool pause;

  const HeadlessPortalSync({
    required this.url,
    this.onSyncComplete,
    this.pause = false,
    super.key,
  });

  static const String syncPortalScript = r'''
(() => {
  const sleep = (ms) => new Promise(r => setTimeout(r, ms));

  async function scrapeAllCourses() {
      const results = [];
      const parser = new DOMParser();
      
      console.log(`[IRIS] Engine: Starting deep sync from ${window.location.pathname}...`);

      // 1. Fetch the main course index directly for maximum reliability
      let dashHtml;
      try {
          dashHtml = await fetch('/Courses/Index').then(res => res.text());
      } catch (e) {
          console.log("[IRIS] Engine ERROR: Failed to reach course index.");
          return [];
      }

      const dashDoc = parser.parseFromString(dashHtml, 'text/html');
      const rows = Array.from(dashDoc.querySelectorAll('table tbody tr'))
          .filter(r => r.getAttribute('onclick') && r.getAttribute('onclick').includes('SetCourse'));

      console.log(`[IRIS] Engine: Identified ${rows.length} courses.`);

      for (let row of rows) {
          try {
              const onclick = row.getAttribute('onclick');
              const courseId = onclick.match(/\d+/)[0];
              const cells = row.querySelectorAll('td');

              const courseInfo = {
                  id: courseId,
                  code: cells[0]?.innerText.trim() || "N/A",
                  name: cells[1]?.innerText.trim() || "Unknown",
                  teacher: cells[3]?.innerText.trim() || "Unknown"
              };

              console.log(`[IRIS] Syncing: ${courseInfo.name}...`);

              // Step A: Set session context
              await fetch(`/Courses/SetCourse/${courseId}`);
              await sleep(400); 

              // Step B: Parallel fetch for Assignments and Quizzes
              const [assignHtml, quizHtml] = await Promise.all([
                  fetch('/Assignments/Index').then(res => res.text()),
                  fetch('/Course/Quizzes').then(res => res.text()).catch(() => fetch('/Quizzes/Index').then(r => r.text()))
              ]);

              // Step C: Parse results
              results.push({
                  ...courseInfo,
                  assignments: parseTable(assignHtml, "Assignment", parser),
                  quizzes: parseTable(quizHtml, "Quiz", parser)
              });

          } catch (e) {
              console.error(`Error scraping course:`, e);
          }
      }
      return results;
  }

  function parseTable(html, type, parser) {
      const doc = parser.parseFromString(html, 'text/html');
      const rows = Array.from(doc.querySelectorAll('table tbody tr'));

      return rows.map(r => {
          if (r.cells.length < 4 || r.innerText.toLowerCase().includes("no record found")) return null;

          return {
              type: type,
              title: r.cells[1]?.innerText.trim(),
              startDate: r.cells[2]?.innerText.trim(),
              dueDate: r.cells[3]?.innerText.trim(),
              status: r.cells[r.cells.length - 1]?.innerText.trim() || "",
              isActionable: r.innerHTML.toLowerCase().includes('upload') || r.innerHTML.toLowerCase().includes('download')
          };
      }).filter(i => i !== null);
  }

  scrapeAllCourses().then(data => {
      if (window.IrisPortalChannel) {
          window.IrisPortalChannel.postMessage(JSON.stringify({
              type: 'portal_sync_tasks',
              courses: data
          }));
      }
  });
})();
''';

  @override
  State<HeadlessPortalSync> createState() => _HeadlessPortalSyncState();
}

class _HeadlessPortalSyncState extends State<HeadlessPortalSync> {
  late final WebViewController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
    PortalSyncService.isSyncPaused.addListener(_handlePauseChange);
  }

  @override
  void dispose() {
    PortalSyncService.isSyncPaused.removeListener(_handlePauseChange);
    super.dispose();
  }

  void _handlePauseChange() {
    if (PortalSyncService.isSyncPaused.value) {
      debugPrint('IRIS: Background sync paused (User is in portal)');
    }
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'IrisPortalChannel',
        onMessageReceived: (message) {
          _handleJsMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _onPageFinished(url);
          },
        ),
      );
    
    _controller.loadRequest(Uri.parse(widget.url));
  }

  DateTime? _lastSyncTime;

  void _onPageFinished(String url) {
    if (widget.pause || PortalSyncService.isSyncPaused.value) return;

    final lowerUrl = url.toLowerCase();
    final isChallenge = lowerUrl.contains('challenge') || lowerUrl.contains('captcha');
    
    if (!isChallenge && lowerUrl.contains('comsats.edu.pk')) {
      final now = DateTime.now();
      if (_lastSyncTime == null || now.difference(_lastSyncTime!).inMinutes >= 15) {
        _lastSyncTime = now;
        _triggerScraper();
      }
    }
  }

  void _triggerScraper() {
    if (PortalSyncService.isSyncPaused.value) return;
    debugPrint('IRIS: Shadow Scraper Waking Up...');
    _controller.runJavaScript(HeadlessPortalSync.syncPortalScript);
  }

  Future<void> _handleJsMessage(String json) async {
    try {
      final data = jsonDecode(json);
      if (data['type'] == 'portal_sync_tasks') {
        final List<dynamic> courses = data['courses'] as List<dynamic>? ?? [];
        final List<PortalTask> flattenedTasks = [];
        
        for (final course in courses) {
          final courseName = course['name']?.toString() ?? 'Unknown';
          final courseId = course['id']?.toString();
          
          final assignments = course['assignments'] as List<dynamic>? ?? [];
          final quizzes = course['quizzes'] as List<dynamic>? ?? [];
          
          for (final t in [...assignments, ...quizzes]) {
            flattenedTasks.add(PortalTask(
              type: t['type']?.toString() ?? 'Task',
              title: t['title']?.toString() ?? 'Untitled',
              subject: courseName,
              dueDate: t['dueDate']?.toString() ?? '',
              startDate: t['startDate']?.toString() ?? '',
              status: t['status']?.toString() ?? '',
              isActionable: t['isActionable'] == true,
              courseId: courseId,
              scrapedAt: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }

        if (flattenedTasks.isNotEmpty) {
          // Persist the tasks to SharedPreferences via the central service
          await PortalSyncService.updatePersistence(flattenedTasks);
          
          // Notify the UI to rebuild
          PortalSyncService.notifyUpdate();
          widget.onSyncComplete?.call(flattenedTasks);
        }
      }
    } catch (e) {
      debugPrint('Shadow Scraper Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep it tiny and invisible
    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(
        opacity: 0.01,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
