import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/portal_screen.dart';
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

  async function scrapeAll() {
      console.log(`[IRIS] Engine: Starting deep sync from ${window.location.pathname}...`);
      
      const parser = new DOMParser();
      let doc = document;
      
      // Look for SetCourse tr rows globally
      let rows = Array.from(doc.querySelectorAll('table tbody tr[onclick*="SetCourse"]'));
      
      // If we are not on the dashboard/course index, load it
      if (rows.length === 0) {
          try {
              const dashHtml = await fetch('/Courses/Index').then(res => res.text());
              doc = parser.parseFromString(dashHtml, 'text/html');
              rows = Array.from(doc.querySelectorAll('table tbody tr[onclick*="SetCourse"]'));
          } catch (e) {
              console.log("[IRIS] Engine ERROR: Failed to reach course index.");
              return null;
          }
      }

      if (rows.length === 0) {
          console.log("[IRIS] Engine: No course rows found.");
          return null;
      }

      // Try to extract student name and registration number/id
      let studentName = "";
      let studentId = "";
      
      const welcomeMsg = doc.querySelector('.welcome_msg, .user-name, #student-name, .profile-name')?.innerText || "";
      if (welcomeMsg) {
          studentName = welcomeMsg.replace(/Welcome\s*:/i, '').trim();
      }
      
      const idEl = doc.querySelector('.reg_no, .student-id, #reg-no, td[class*="reg" i], span[class*="reg" i], td[class*="roll" i]') || 
                   Array.from(doc.querySelectorAll('td, span, div')).find(el => /FA\d{2}-B[A-Z]{2,3}-\d{3}/i.test(el.innerText));
      if (idEl) {
          studentId = idEl.innerText.trim();
      }

      // We can also compute overall average attendance
      let totalAttendanceSum = 0;
      let validAttendanceCount = 0;

      const masterData = {
          student: studentName || "Student",
          student_id: studentId || "",
          extracted_at: new Date().toISOString(),
          semester_summary: {
              total_courses: rows.length,
              total_pending_tasks: 0,
              overall_attendance_avg: "0%"
          },
          courses: []
      };

      for (const row of rows) {
          try {
              const onclick = row.getAttribute('onclick');
              const courseId = onclick.match(/\/SetCourse\/(\d+)/)?.[1] || onclick.match(/\d+/)?.[0];
              if (!courseId) continue;

              const cells = row.querySelectorAll('td');
              const attendanceStr = cells[5]?.innerText.trim() || "0%";
              
              // Extract numeric percentage for calculations
              const pctMatch = attendanceStr.match(/(\d+)%/);
              if (pctMatch) {
                  totalAttendanceSum += parseInt(pctMatch[1]);
                  validAttendanceCount++;
              }

              const course = {
                  id: courseId,
                  code: cells[0]?.innerText.trim() || "N/A",
                  name: cells[1]?.innerText.trim() || "Unknown",
                  credits: cells[2]?.innerText.trim() || "3",
                  instructor: cells[3]?.innerText.trim() || "Unknown",
                  attendance: attendanceStr,
                  assignments: [],
                  quizzes: []
              };

              console.log(`[IRIS] Syncing Course: ${course.name}`);

              // Switch session context
              await fetch(`/Courses/SetCourse/${courseId}`);
              await sleep(350);

              // Fetch sub-data in parallel
              const [aDoc, qDoc] = await Promise.all([
                  fetch('/Assignments/Index').then(res => res.text()).then(h => parser.parseFromString(h, 'text/html')),
                  fetch('/Quizzes/Index').then(res => res.text()).catch(() => fetch('/Course/Quizzes').then(r => r.text())).then(h => parser.parseFromString(h, 'text/html'))
              ]);

              const parseTable = (subDoc) => Array.from(subDoc.querySelectorAll('table tbody tr'))
                  .filter(r => r.cells.length > 3 && !r.innerText.toLowerCase().includes('no record found') && !r.innerText.toLowerCase().includes('no data'))
                  .map(r => ({
                      title: r.cells[1]?.innerText.trim(),
                      due: r.cells[3]?.innerText.trim() || r.cells[2]?.innerText.trim() || "",
                      status: r.innerHTML.toLowerCase().includes('upload') ? 'OPEN' : 'CLOSED'
                  }));

              course.assignments = parseTable(aDoc);
              course.quizzes = parseTable(qDoc);
              
              masterData.courses.push(course);
              
              // Count open tasks
              const openAssignments = course.assignments.filter(a => a.status === 'OPEN').length;
              const openQuizzes = course.quizzes.filter(q => q.status === 'OPEN').length;
              masterData.semester_summary.total_pending_tasks += (openAssignments + openQuizzes);

          } catch (e) {
              console.error("Error scraping course row:", e);
          }
      }

      if (validAttendanceCount > 0) {
          masterData.semester_summary.overall_attendance_avg = `${Math.round(totalAttendanceSum / validAttendanceCount)}%`;
      }

      return masterData;
  }

  scrapeAll().then(data => {
      if (data && window.IrisPortalChannel) {
          window.IrisPortalChannel.postMessage(JSON.stringify({
              type: 'portal_sync_academics',
              data: data
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
  Timer? _periodicSyncTimer;
  Completer<void>? _syncCompleter;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    PortalSyncService.isSyncPaused.addListener(_handlePauseChange);
    PortalSyncService.triggerHeadlessSync = _manualTrigger;

    // Set up a 30-minute background periodic timer to trigger a fresh dashboard check/sync
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (!widget.pause && !PortalSyncService.isSyncPaused.value) {
        debugPrint('IRIS Headless: Periodic background sync cycle waking up...');
        _restoreCookiesAndLoad();
      }
    });

    // Defer heavy WebView initialization to prevent UI stutter/jank on app launch and role switches
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          _initController();
        }
      });
    });
  }

  @override
  void dispose() {
    PortalSyncService.isSyncPaused.removeListener(_handlePauseChange);
    _periodicSyncTimer?.cancel();
    if (PortalSyncService.triggerHeadlessSync == _manualTrigger) {
      PortalSyncService.triggerHeadlessSync = null;
    }
    _completeSync();
    super.dispose();
  }

  void _handlePauseChange() {
    if (PortalSyncService.isSyncPaused.value) {
      debugPrint('IRIS: Background sync paused (User is in portal)');
    }
  }

  Future<void> _manualTrigger() async {
    if (!_isInitialized) {
      debugPrint('IRIS Headless: Deferring manual sync trigger until WebView is initialized...');
      return;
    }
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      return _syncCompleter!.future;
    }
    
    debugPrint('IRIS Headless: Manual trigger request received, starting sync...');
    _syncCompleter = Completer<void>();
    _lastSyncTime = null; // Clear rate-limit so pagefinished immediately triggers scraper
    await _restoreCookiesAndLoad();
    
    // Safety timeout: complete after 30 seconds if it hangs
    Future.delayed(const Duration(seconds: 30), () {
      _completeSync();
    });
    
    return _syncCompleter!.future;
  }

  void _completeSync() {
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      _syncCompleter!.complete();
      _syncCompleter = null;
      debugPrint('IRIS Headless: Manual sync operation completed successfully.');
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
    
    setState(() {
      _isInitialized = true;
    });
    
    _restoreCookiesAndLoad();
  }

  Future<void> _restoreCookiesAndLoad() async {
    if (!_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final uri = Uri.parse(widget.url);
      final host = uri.host;
      final cookieKey = 'iris_session_student_${host.toLowerCase()}_cookies';
      final cookieHeader = prefs.getString(cookieKey);
      
      if (cookieHeader != null && cookieHeader.trim().isNotEmpty) {
        final cookieManager = WebViewCookieManager();
        
        for (final part in cookieHeader.split(';')) {
          final trimmed = part.trim();
          if (trimmed.isEmpty) continue;
          final idx = trimmed.indexOf('=');
          if (idx == -1) continue;
          final name = trimmed.substring(0, idx).trim();
          final value = trimmed.substring(idx + 1).trim();
          try {
            await cookieManager.setCookie(
              WebViewCookie(
                name: name,
                value: value,
                domain: host,
                path: '/',
              ),
            );
          } catch (_) {}
        }
        debugPrint('IRIS Headless: Restored cookies for $host');
      }
      
      // Load the authenticated dashboard directly if possible
      final targetUrl = 'https://$host/Dashboard';
      await _controller.loadRequest(Uri.parse(targetUrl));
    } catch (e) {
      debugPrint('IRIS Headless Error restoring cookies: $e');
      // Fallback
      await _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  DateTime? _lastSyncTime;
  int _headlessLoginAttempts = 0;

  Future<void> _persistHeadlessCookies(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    try {
      final host = uri.host;
      final raw = await _controller.runJavaScriptReturningResult('document.cookie');
      var cookieString = raw.toString().trim();
      if (cookieString.startsWith('"') && cookieString.endsWith('"')) {
        cookieString = cookieString.substring(1, cookieString.length - 1);
      }
      cookieString = cookieString
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\');
      
      if (cookieString.isNotEmpty && !cookieString.contains('<html>')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('iris_session_student_${host.toLowerCase()}_cookies', cookieString);
        debugPrint('🍪 IRIS Headless: Captured and persisted fresh cookies for $host');
      }
    } catch (e) {
      debugPrint('⚠️ IRIS Headless: Failed to back up cookies: $e');
    }
  }

  Future<void> _tryHeadlessLogin(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) {
        _completeSync();
        return;
      }
      
      final host = uri.host;
      final prefs = await SharedPreferences.getInstance();
      
      // Check student scope, global scope, and legacy key formats
      final u = prefs.getString('iris_login_student_${host.toLowerCase()}_u') ??
                prefs.getString('iris_login_global_${host.toLowerCase()}_u') ??
                prefs.getString('iris_login_user_${host.toLowerCase()}');
      final p = prefs.getString('iris_login_student_${host.toLowerCase()}_p') ??
                prefs.getString('iris_login_global_${host.toLowerCase()}_p') ??
                prefs.getString('iris_login_pass_${host.toLowerCase()}');
      
      if (u == null || p == null) {
        debugPrint('IRIS Headless: No saved login for $host, cannot auto-login.');
        _completeSync();
        return;
      }

      if (_headlessLoginAttempts >= 1) {
        debugPrint('IRIS Headless: Headless auto-login already attempted and failed. Preventing loop.');
        _completeSync();
        return;
      }

      _headlessLoginAttempts++;
      debugPrint('IRIS Headless: Attempting background auto-login for $host...');

      final username = utf8.decode(base64Decode(u));
      final password = utf8.decode(base64Decode(p));

      final jsUser = jsonEncode(username);
      final jsPass = jsonEncode(password);

      final script = '''
(() => {
  const setNativeValue = (element, value) => {
    if (!element) return false;
    const descriptor = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value') || Object.getOwnPropertyDescriptor(Object.getPrototypeOf(element), 'value');
    if (descriptor && descriptor.set) {
      descriptor.set.call(element, value);
    } else {
      element.value = value;
    }
    element.dispatchEvent(new Event('input', { bubbles: true }));
    element.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  };

  const pwd = document.querySelector('input[type="password"]');
  const user = document.querySelector('input[type="text"], input[type="email"], input[name*="user" i], input[id*="user" i], input[name*="roll" i], input[name*="reg" i]');
  
  if (user && pwd) {
    setNativeValue(user, $jsUser);
    setNativeValue(pwd, $jsPass);
    
    const form = pwd.form || document.querySelector('form');
    if (form) {
      form.submit();
      return 'submitted_form';
    }
    
    const btn = document.querySelector('button[type="submit"], input[type="submit"], button');
    if (btn) {
      btn.click();
      return 'clicked_button';
    }
  }
  return 'not_found';
})();
''';

      final rawResult = await _controller.runJavaScriptReturningResult(script);
      final result = rawResult.toString().toLowerCase();
      debugPrint('IRIS Headless: Auto-login execution result: $result');
      
      if (!result.contains('submitted') && !result.contains('clicked')) {
        _completeSync();
      }
    } catch (e) {
      debugPrint('IRIS Headless Auto-login Error: $e');
      _completeSync();
    }
  }

  void _onPageFinished(String url) {
    if (widget.pause || PortalSyncService.isSyncPaused.value) {
      _completeSync();
      return;
    }

    final lowerUrl = url.toLowerCase();
    final isChallenge = lowerUrl.contains('challenge') || lowerUrl.contains('captcha');
    final isLogin = lowerUrl.contains('login/index') || lowerUrl.contains('account/login');
    
    if (!isChallenge && !isLogin && lowerUrl.contains('comsats.edu.pk')) {
      _headlessLoginAttempts = 0; // Reset on successful auth page load
      
      _persistHeadlessCookies(url).then((_) {
        final now = DateTime.now();
        if (_lastSyncTime == null || now.difference(_lastSyncTime!).inMinutes >= 15) {
          _lastSyncTime = now;
          _triggerScraper();
        } else {
          _completeSync();
        }
      });
    } else if (isLogin && !isChallenge) {
      _tryHeadlessLogin(url);
    } else {
      _completeSync();
    }
  }

  void _triggerScraper() {
    if (PortalSyncService.isSyncPaused.value) {
      _completeSync();
      return;
    }
    debugPrint('IRIS: Shadow Scraper Waking Up...');
    _controller.runJavaScript(HeadlessPortalSync.syncPortalScript);
  }

  Future<void> _handleJsMessage(String json) async {
    try {
      final data = jsonDecode(json);
      
      if (data['type'] == 'portal_sync_academics') {
        final academicsData = data['data'] as Map<String, dynamic>? ?? {};
        
        // 1. Save academics details
        await PortalSyncService.saveCachedAcademics(academicsData);
        
        // 2. Flatten and merge tasks
        final List<dynamic> courses = academicsData['courses'] as List<dynamic>? ?? [];
        final List<PortalTask> flattenedTasks = [];
        
        for (final course in courses) {
          final courseName = course['name']?.toString() ?? 'Unknown';
          final courseId = course['id']?.toString();
          
          final assignments = course['assignments'] as List<dynamic>? ?? [];
          final quizzes = course['quizzes'] as List<dynamic>? ?? [];
          
          for (final a in assignments) {
            flattenedTasks.add(PortalTask(
              type: 'Assignment',
              title: a['title']?.toString() ?? 'Untitled',
              subject: courseName,
              dueDate: a['due']?.toString() ?? '',
              status: a['status']?.toString() ?? 'OPEN',
              isCompleted: a['status']?.toString().toUpperCase() == 'CLOSED',
              isActionable: a['status']?.toString().toUpperCase() == 'OPEN',
              courseId: courseId,
              scrapedAt: DateTime.now().millisecondsSinceEpoch,
            ));
          }
          
          for (final q in quizzes) {
            flattenedTasks.add(PortalTask(
              type: 'Quiz',
              title: q['title']?.toString() ?? 'Untitled',
              subject: courseName,
              dueDate: q['due']?.toString() ?? '',
              status: q['status']?.toString() ?? 'OPEN',
              isCompleted: q['status']?.toString().toUpperCase() == 'CLOSED',
              isActionable: q['status']?.toString().toUpperCase() == 'OPEN',
              courseId: courseId,
              scrapedAt: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }
        
        if (flattenedTasks.isNotEmpty) {
          await PortalSyncService.updatePersistence(flattenedTasks);
        }
        
        PortalSyncService.notifyUpdate();
        widget.onSyncComplete?.call(flattenedTasks);
      } else if (data['type'] == 'portal_sync_tasks') {
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
          await PortalSyncService.updatePersistence(flattenedTasks);
          PortalSyncService.notifyUpdate();
          widget.onSyncComplete?.call(flattenedTasks);
        }
      }
      _completeSync();
    } catch (e) {
      debugPrint('Shadow Scraper Error: $e');
      _completeSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }
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
