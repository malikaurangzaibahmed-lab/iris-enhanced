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
  
  const parsePortalDate = (str) => {
    if (!str || str === "N/A") return "";
    try {
      const clean = str.trim().toLowerCase().replace(/\s+/g, ' ');
      // Split by common separators: dash, slash, space
      const parts = clean.split(/[-/ ]/);
      if (parts.length >= 3) {
        const months = {
          'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04', 'may': '05', 'jun': '06',
          'jul': '07', 'aug': '08', 'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
          '01': '01', '02': '02', '03': '03', '04': '04', '05': '05', '06': '06',
          '07': '07', '08': '08', '09': '09', '10': '10', '11': '11', '12': '12'
        };
        
        let d, m, y;
        // Heuristic: identify which part is the month
        if (months[parts[1]]) { // Format: DD-MMM-YYYY
          d = parts[0];
          m = months[parts[1]];
          y = parts[2];
        } else if (months[parts[0]]) { // Format: MMM DD, YYYY
          m = months[parts[0]];
          d = parts[1].replace(',', '');
          y = parts[2];
        } else { // Assume DD-MM-YYYY
          d = parts[0];
          m = parts[1].padStart(2, '0');
          y = parts[2];
        }

        d = d.padStart(2, '0').slice(-2);
        // Normalize year: 26 -> 2026
        if (y.length === 2) y = '20' + y;
        
        const iso = `${y}-${m}-${d}T23:59:00`;
        return isNaN(Date.parse(iso)) ? str : iso;
      }
    } catch(e) {}
    return str;
  };

  async function getPortalDataForFlutter() {
      const parser = new DOMParser();
      const finalData = [];

      try {
          const dashResp = await fetch('/Courses/Index');
          const dashHtml = await dashResp.text();
          if (dashHtml.includes('cf-challenge')) return;
          
          const dashDoc = parser.parseFromString(dashHtml, 'text/html');
          const courses = Array.from(dashDoc.querySelectorAll('table tbody tr')).map(tr => ({
              name: tr.cells[1]?.innerText.trim(),
              id: tr.getAttribute('onclick')?.match(/\d+/)?.[0]
          })).filter(c => c.id);

          for (const course of courses) {
              await fetch(`/Courses/SetCourse/${course.id}`);
              await sleep(1000); 

              // Parallelize Assignment and Quiz fetches for speed
              const [assHtml, quizHtml] = await Promise.all([
                  fetch('/Assignments/Index').then(r => r.text()),
                  fetch('/Course/Quizzes').then(r => r.text())
              ]);

              const assDoc = parser.parseFromString(assHtml, 'text/html');
              const assRows = Array.from(assDoc.querySelectorAll('table tbody tr'));
              const assignments = assRows.map(row => {
                  const cells = row.cells;
                  if (cells.length < 8) return null;
                  const hasDownload = cells[6]?.innerText.includes('Download');
                  const hasUpload = cells[7]?.innerText.includes('Upload');

                  if (hasDownload || hasUpload) {
                      return {
                          title: cells[1]?.innerText.trim(),
                          deadline: parsePortalDate(cells[3]?.innerText.trim()),
                          status: hasUpload ? "Action Required" : "Download Available",
                          type: "Assignment"
                      };
                  }
                  return null;
              }).filter(item => item !== null);

              const quizDoc = parser.parseFromString(quizHtml, 'text/html');
              const quizRows = Array.from(quizDoc.querySelectorAll('table tbody tr'));
              const quizzes = quizRows.map(row => {
                  if (row.innerText.toLowerCase().includes('not attempted')) {
                      return {
                          title: row.cells[1]?.innerText.trim(),
                          deadline: parsePortalDate(row.cells[2]?.innerText.trim()),
                          status: "Not Attempted",
                          type: "Quiz"
                      };
                  }
                  return null;
              }).filter(item => item !== null);

              if (assignments.length > 0 || quizzes.length > 0) {
                  finalData.push({
                      courseName: course.name,
                      courseId: course.id,
                      tasks: [...assignments, ...quizzes]
                  });
              }
          }
      } catch (e) { console.error("[Iris] Shadow Scrape Failed", e); }

      if (window.IrisPortalChannel) {
          window.IrisPortalChannel.postMessage(JSON.stringify({
              type: 'portal_sync_tasks',
              tasks: finalData
          }));
      }
  }
  getPortalDataForFlutter();
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
    // Listen for sync lock changes
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
    } else {
      debugPrint('IRIS: Background sync resumed');
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
    if (widget.pause) return;

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
    debugPrint('IRIS: Shadow Scraper Waking Up...');
    _controller.runJavaScript(HeadlessPortalSync.syncPortalScript);
  }

  void _handleJsMessage(String json) {
    try {
      final data = jsonDecode(json);
      if (data['type'] == 'portal_sync_tasks') {
        final List<dynamic> courseData = data['tasks'] as List<dynamic>? ?? [];
        final List<PortalTask> flattenedTasks = [];
        
        for (final course in courseData) {
          final courseName = course['courseName']?.toString() ?? 'Unknown';
          final tasks = course['tasks'] as List<dynamic>? ?? [];
          
          for (final t in tasks) {
            flattenedTasks.add(PortalTask(
              type: t['type']?.toString() ?? 'Assignment',
              title: t['title']?.toString() ?? 'Untitled',
              subject: courseName,
              dueDate: t['deadline']?.toString() ?? '',
              status: t['status']?.toString() ?? '',
              scrapedAt: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }

        if (flattenedTasks.isNotEmpty) {
          // Notify the app that new tasks were found
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
