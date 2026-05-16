import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:html/parser.dart' as hp;
import 'package:html/dom.dart' as hdom;
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/ui_feedback.dart';
import 'services/portal_sync_service.dart';
import 'services/headless_portal_sync.dart';
import 'widgets/iris_background.dart';
import 'core/tokens.dart';
import 'core/animations.dart';
import 'core/theme_signals.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Portal session metadata persisted across app restarts
class DownloadRecord {
  final String filename;
  final String filePath;
  final String sourceUrl;
  final int savedAt;
  final String state;
  final String backend;
  final String downloadId;

  const DownloadRecord({
    required this.filename,
    required this.filePath,
    this.sourceUrl = '',
    required this.savedAt,
    this.state = 'completed',
    this.backend = 'native',
    this.downloadId = '',
  });

  factory DownloadRecord.fromJson(dynamic json) {
    if (json is String) {
      final fallbackName = json.split(RegExp(r'[\\/]')).last;
      return DownloadRecord(
        filename: fallbackName,
        filePath: json,
        sourceUrl: '',
        savedAt: DateTime.now().millisecondsSinceEpoch,
        state: 'completed',
        backend: 'legacy',
        downloadId: '',
      );
    }

    final data = (json is Map)
        ? Map<String, dynamic>.from(json)
        : <String, dynamic>{};
    final filePath = data['filePath']?.toString() ?? '';
    final filename =
        data['filename']?.toString() ?? filePath.split(RegExp(r'[\\/]')).last;
    return DownloadRecord(
      filename: filename.isEmpty ? 'download.bin' : filename,
      filePath: filePath,
      sourceUrl: data['sourceUrl']?.toString() ?? '',
      savedAt:
          (data['savedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      state: data['state']?.toString().isNotEmpty == true
          ? data['state'].toString()
          : 'completed',
      backend: data['backend']?.toString().isNotEmpty == true
          ? data['backend'].toString()
          : 'native',
      downloadId: data['downloadId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'filePath': filePath,
    'sourceUrl': sourceUrl,
    'savedAt': savedAt,
    'state': state,
    'backend': backend,
    'downloadId': downloadId,
  };

  String get displaySource {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || uri.host.isEmpty) return 'Saved file';
    return uri.host;
  }

  String get prettySavedAt {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - savedAt;
    if (diff < 60000) return 'Just now';
    final minutes = diff ~/ 60000;
    if (minutes < 60) return '$minutes min${minutes > 1 ? 's' : ''} ago';
    final hours = diff ~/ 3600000;
    if (hours < 24) return '$hours hour${hours > 1 ? 's' : ''} ago';
    final days = diff ~/ 86400000;
    return '$days day${days > 1 ? 's' : ''} ago';
  }

  bool get isPending =>
      state == 'queued' || state == 'running' || state == 'paused';

  String get statusLabel {
    if (state == 'queued') return 'Queued';
    if (state == 'running') return 'Downloading';
    if (state == 'paused') return 'Paused';
    if (state == 'failed') return 'Failed';
    return 'Saved';
  }
}

/// Represents a student task (Assignment or Quiz) from the portal
class PortalTask {
  final String type; // Assignment, Quiz, etc.
  final String title;
  final String subject;
  final String dueDate;
  final String startDate;
  final int scrapedAt;
  final bool isCompleted;
  final bool isActionable;
  final String status;
  final String? courseId;

  const PortalTask({
    required this.type,
    required this.title,
    required this.subject,
    required this.dueDate,
    this.startDate = "",
    required this.scrapedAt,
    this.isCompleted = false,
    this.isActionable = false,
    this.status = "",
    this.courseId,
  });

  factory PortalTask.fromJson(dynamic json) {
    final data = (json is Map) ? Map<String, dynamic>.from(json) : <String, dynamic>{};
    return PortalTask(
      type: data['type']?.toString() ?? 'Task',
      title: data['title']?.toString() ?? '',
      subject: data['subject']?.toString() ?? 'Unknown Subject',
      dueDate: data['dueDate']?.toString() ?? '',
      startDate: data['startDate']?.toString() ?? '',
      scrapedAt: (data['scrapedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      isCompleted: data['isCompleted'] == true,
      isActionable: data['isActionable'] == true,
      status: data['status']?.toString() ?? "",
      courseId: data['courseId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'subject': subject,
    'dueDate': dueDate,
    'startDate': startDate,
    'scrapedAt': scrapedAt,
    'isCompleted': isCompleted,
    'isActionable': isActionable,
    'status': status,
    'courseId': courseId,
  };

  bool get isUrgent {
    final diff = daysRemaining;
    return diff >= 0 && diff <= 2;
  }

  int get daysRemaining {
    try {
      // First try ISO parsing (New System)
      final isoDate = DateTime.tryParse(dueDate);
      if (isoDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final target = DateTime(isoDate.year, isoDate.month, isoDate.day);
        return target.difference(today).inDays;
      }

      // Fallback to manual parsing (Old System)
      final parts = dueDate.split(RegExp(r'[/\-]'));
      if (parts.length < 3) return 999;
      
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      
      if (month > 12) {
         final temp = day;
         day = month;
         month = temp;
      }
      
      final yearText = parts[2].split(' ').first;
      final year = int.parse(yearText.length == 2 ? '20$yearText' : yearText);
      
      final date = DateTime(year, month, day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return date.difference(today).inDays;
    } catch (_) {
      return 999;
    }
  }

  PortalTask copyWith({bool? isCompleted, bool? isActionable, String? status}) {
    return PortalTask(
      type: type,
      title: title,
      subject: subject,
      dueDate: dueDate,
      startDate: startDate,
      scrapedAt: scrapedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      isActionable: isActionable ?? this.isActionable,
      status: status ?? this.status,
      courseId: courseId,
    );
  }
}

class PortalSession {
  final String host;
  final String title;
  final String url;
  final String? savedUsername;
  final int createdAt;
  final int lastAccessedAt;
  final bool hasValidCookies;
  final List<DownloadRecord> recentDownloads;
  final List<String> recentUploads;

  PortalSession({
    required this.host,
    required this.title,
    required this.url,
    this.savedUsername,
    required this.createdAt,
    required this.lastAccessedAt,
    this.hasValidCookies = false,
    this.recentDownloads = const [],
    this.recentUploads = const [],
    this.tasks = const [],
    this.lastSyncAt,
  });

  final List<PortalTask> tasks;
  final int? lastSyncAt;

  factory PortalSession.fromJson(Map<String, dynamic> json) {
    return PortalSession(
      host: json['host'] ?? 'unknown',
      title: json['title'] ?? 'Portal',
      url: json['url'] ?? '',
      savedUsername: json['savedUsername'],
      createdAt: json['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      lastAccessedAt:
          json['lastAccessedAt'] ?? DateTime.now().millisecondsSinceEpoch,
      hasValidCookies: json['hasValidCookies'] ?? false,
      recentDownloads: (json['recentDownloads'] as List<dynamic>? ?? const [])
          .map(DownloadRecord.fromJson)
          .toList(),
      recentUploads: List<String>.from(json['recentUploads'] ?? []),
      tasks: (json['tasks'] as List<dynamic>? ?? const [])
          .map(PortalTask.fromJson)
          .toList(),
      lastSyncAt: json['lastSyncAt'],
    );
  }

  Map<String, dynamic> toJson() => {
    'host': host,
    'title': title,
    'url': url,
    'savedUsername': savedUsername,
    'createdAt': createdAt,
    'lastAccessedAt': lastAccessedAt,
    'hasValidCookies': hasValidCookies,
    'recentDownloads': recentDownloads.map((d) => d.toJson()).toList(),
    'recentUploads': recentUploads,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'lastSyncAt': lastSyncAt,
  };

  String get prettyLastAccessed {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - lastAccessedAt;
    final days = diff ~/ (24 * 60 * 60 * 1000);
    if (days > 0) return '$days day${days > 1 ? 's' : ''} ago';
    final hours = diff ~/ (60 * 60 * 1000);
    if (hours > 0) return '$hours hour${hours > 1 ? 's' : ''} ago';
    return 'Just now';
  }

  PortalSession copyWith({
    String? title,
    String? url,
    String? savedUsername,
    int? lastAccessedAt,
    bool? hasValidCookies,
    List<DownloadRecord>? recentDownloads,
    List<String>? recentUploads,
    List<PortalTask>? tasks,
    int? lastSyncAt,
  }) {
    return PortalSession(
      host: host,
      title: title ?? this.title,
      url: url ?? this.url,
      savedUsername: savedUsername ?? this.savedUsername,
      createdAt: createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      hasValidCookies: hasValidCookies ?? this.hasValidCookies,
      recentDownloads: recentDownloads ?? this.recentDownloads,
      recentUploads: recentUploads ?? this.recentUploads,
      tasks: tasks ?? this.tasks,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

class PortalScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool showBackButton;
  final String sessionScope;

  const PortalScreen({
    required this.url,
    required this.title,
    this.showBackButton = true,
    this.sessionScope = 'global',
    super.key,
  });

  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen>
    with SingleTickerProviderStateMixin {
  static const String _portalUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UD1A.230805.019) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.6422.165 Mobile Safari/537.36';
  static const MethodChannel _androidDownloadChannel = MethodChannel(
    'iris/download',
  );

  late final WebViewController _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isDownloading = false;
  double _downloadProgress = -1;
  bool _canGoBack = false;
  bool _canGoForward = false;
  int _progress = 0;
  String _currentUrl = '';
  late PortalSession _currentSession;

  // Smart feature detection
  bool _hasLoginForm = false;
  bool _hasFileUpload = false;
  bool _hasSavedLogin = false;
  int _lastDetectionTime = 0;
  bool _isOffline = false;
  bool _isPullRefreshing = false;
  bool _isHeaderCollapsed = true;
  bool _isPillPressed = false;
  bool _isEditingAddress = false;
  bool _showAutofillPrompt = false;
  List<String> _scraperLogs = [];
  Timer? _connectivityTimer;
  Timer? _loginFocusTimer;
  Timer? _pillRevertTimer;
  String? _pillMessage;
  IconData? _pillIcon;
  Color _pillTone = Colors.white;
  VoidCallback? _pillAction;
  String? _pillActionLabel;
  bool _pillActive = false;
  int _lastRenderedProgress = 0;
  String? _lastSnackMessage;
  int _lastSnackAtMs = 0;
  String? _lastDownloadUrl;
  int _lastDownloadAtMs = 0;
  final TextEditingController _addressController = TextEditingController();

  String get _scopeSanitized =>
      widget.sessionScope.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');

  String get _lastActiveSessionKey =>
      'iris_portal_${_scopeSanitized}_last_active_session';

  String _portalSessionKey(String host) =>
      'iris_portal_${_scopeSanitized}_session_${host.toLowerCase()}';

  String _loginUserKey(String host) =>
      'iris_login_${_scopeSanitized}_${host.toLowerCase()}_u';

  String _loginPassKey(String host) =>
      'iris_login_${_scopeSanitized}_${host.toLowerCase()}_p';

  String _displayFileName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    await _showMessage('Path copied: $path');
  }

  Future<void> _openFilePath(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        await _showMessage('File not found');
        return;
      }

      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        await _showMessage('Cannot open this file type here. Path copied.');
        await _copyPath(path);
      }
    } catch (_) {
      await _showMessage('Could not open file. Path copied.');
      await _copyPath(path);
    }
  }

  Future<void> _openSystemDownloads() async {
    if (Platform.isAndroid) {
      try {
        await _androidDownloadChannel.invokeMethod('openSystemDownloads');
      } catch (e) {
        await _showMessage('Cannot open system downloads');
      }
    } else {
      await _showMessage('System downloads only available on Android');
    }
  }

  Future<void> _openFolderPath(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await _showMessage('Folder not found');
        return;
      }

      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        final uri = Uri.directory(path);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          await _showMessage('Cannot open folder directly. Path copied.');
          await _copyPath(path);
        }
      }
    } catch (_) {
      await _showMessage('Could not open folder. Path copied.');
      await _copyPath(path);
    }
  }

  Future<void> _checkConnectivity() async {
    final url = _currentUrl.isEmpty ? widget.url : _currentUrl;
    final host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) return;

    bool online = true;
    try {
      final result = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 4));
      online = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }

    if (!mounted) return;
    if (_isOffline != !online) {
      setState(() => _isOffline = !online);
      if (online) {
        await _showMessage('Back online');
      } else {
        await _showMessage('You appear to be offline');
      }
    }
  }

  Future<void> _saveLastActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastActiveSessionKey,
      jsonEncode(_currentSession.toJson()),
    );
  }

  Future<PortalSession?> _loadLastActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastActiveSessionKey);
    if (raw == null) return null;
    try {
      return PortalSession.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshPage({bool fromPull = false}) async {
    if (_isPullRefreshing || _isLoading) return;
    if (_isOffline) {
      await _showMessage('You are offline. Retry when internet is back.');
      return;
    }

    if (!mounted) return;
    setState(() => _isPullRefreshing = true);
    await _controller.reload();
    if (fromPull) {
      await _showMessage('Refreshing page...');
    }
    if (mounted) {
      setState(() => _isPullRefreshing = false);
    }
  }

  String get _hostKey {
    final uri = Uri.tryParse(_currentUrl.isEmpty ? widget.url : _currentUrl);
    return (uri?.host.isNotEmpty ?? false) ? uri!.host.toLowerCase() : 'portal';
  }

  int _loginThresholdForHost(String host) {
    if (host.contains('lms') ||
        host.contains('moodle') ||
        host.contains('cms')) {
      return 5;
    }
    if (host.contains('comsats.edu.pk') || host.contains('portal')) {
      return 4;
    }
    if (host.contains('adfs') ||
        host.contains('sso') ||
        host.contains('auth')) {
      return 4;
    }
    return 5;
  }

  Future<void> _detectPageFeatures() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Only detect once per 2 seconds to avoid spam
    if (now - _lastDetectionTime < 2000) return;
    _lastDetectionTime = now;

    try {
      final script = '''
(() => {
  const url = window.location.href.toLowerCase();
  const title = (document.title || '').toLowerCase();
  const pwd = document.querySelector('input[type="password"]:not([disabled])');
  const scope = (pwd && pwd.form) ? pwd.form : document;
  const user = scope.querySelector(
    'input[type="email"], input[autocomplete="username"], input[name*="user" i], input[id*="user" i], input[name*="login" i], input[id*="login" i], input[name*="roll" i], input[name*="reg" i], input[type="text"]'
  );
  const hasUpload = document.querySelector('input[type="file"]') != null;
  const focusMatchesLogin = (element) => {
    if (!element) return false;
    return element === pwd || element === user;
  };

  const sendFocusState = () => {
    if (!window.IrisPortalChannel) return;
    const active = document.activeElement;
    if (!focusMatchesLogin(active)) return;
    window.IrisPortalChannel.postMessage(JSON.stringify({
      type: 'login_focus',
      focused: true,
    }));
  };
  const active = document.activeElement;
  const loginFocused = !!active && (active === pwd || active === user);

  let score = 0;
  if (pwd) score += 3;
  if (user) score += 2;
  if (/login|signin|sign-in|auth|account|portal/.test(url)) score += 1;
  if (/login|sign in|authentication|portal/.test(title)) score += 1;

  if (pwd && pwd.form) {
    const formMeta = [
      pwd.form.action || '',
      pwd.form.id || '',
      pwd.form.name || '',
      pwd.form.className || ''
    ].join(' ').toLowerCase();

    if (/login|signin|auth|session|account|portal/.test(formMeta)) score += 2;
    if (/upload|assignment|submit|feedback|quiz/.test(formMeta)) score -= 2;
  }

  if (focusMatchesLogin(document.activeElement)) {
    sendFocusState();
  } else {
    document.addEventListener('focusin', sendFocusState, true);
  }

  const hasLogin = score >= 4;
  return JSON.stringify({ hasLogin, hasUpload, loginFocused, score });
})();
''';
      final raw = await _controller.runJavaScriptReturningResult(script);
      final text = _normalizeJsResult(raw);
      final data = jsonDecode(text) as Map<String, dynamic>;
      final score = (data['score'] as num?)?.toInt() ?? 0;
      final host = _hostKey;
      final threshold = _loginThresholdForHost(host);
      // Hysteresis: once we confidently detect login, don't drop immediately.
      final hasLogin =
          score >= threshold || (_hasLoginForm && score >= (threshold - 1));
      final loginFocused = data['loginFocused'] == true;

      if (!mounted) return;
      setState(() {
        _hasLoginForm = hasLogin;
        _hasFileUpload = data['hasUpload'] ?? false;
        if (loginFocused && _hasSavedLogin) {
          _showAutofillPrompt = true;
        } else if (!hasLogin) {
          _showAutofillPrompt = false;
        }
      });

      // Check if we have saved login for this host
      final prefs = await SharedPreferences.getInstance();
      final savedU = prefs.getString(_loginUserKey(_hostKey));
      if (savedU != null) {
        try {
          utf8.decode(base64Decode(savedU));
          if (mounted) {
            setState(() {
              _hasSavedLogin = true;
            });
          }
        } catch (_) {}
      } else if (mounted) {
        setState(() {
          _hasSavedLogin = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _pollLoginFocus() async {
    if (!mounted || !_hasSavedLogin || !_hasLoginForm) return;
    try {
      final raw = await _controller.runJavaScriptReturningResult('''
(() => {
  const pwd = document.querySelector('input[type="password"]:not([disabled])');
  const scope = (pwd && pwd.form) ? pwd.form : document;
  const user = scope.querySelector(
    'input[type="email"], input[autocomplete="username"], input[name*="user" i], input[id*="user" i], input[name*="login" i], input[id*="login" i], input[name*="roll" i], input[name*="reg" i], input[type="text"]'
  );
  const active = document.activeElement;
  return !!active && (active === pwd || active === user);
})();
''');
      final focused = _normalizeJsResult(raw).toLowerCase() == 'true';
      if (!mounted) return;
      if (focused && !_showAutofillPrompt) {
        setState(() => _showAutofillPrompt = true);
      }
    } catch (_) {}
  }

  void _startLoginFocusWatch() {
    _loginFocusTimer?.cancel();
    _loginFocusTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      unawaited(_pollLoginFocus());
    });
  }

  void _stopLoginFocusWatch() {
    _loginFocusTimer?.cancel();
    _loginFocusTimer = null;
  }

  bool _looksDownloadableUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('download') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.pptx') ||
        lower.endsWith('.zip');
  }

  Future<void> _handlePrintDocument(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        await _showMessage('Invalid print link');
        return;
      }

      final jsUrl = jsonEncode(uri.toString());
      final rawResult = await _controller.runJavaScriptReturningResult('''
(() => {
  const targetUrl = $jsUrl;
  const normalize = (value) => {
    try {
      const parsed = new URL(value, window.location.href);
      return parsed.origin + parsed.pathname + parsed.search;
    } catch (_) {
      return String(value || '');
    }
  };

  const samePage = normalize(targetUrl) === normalize(window.location.href);
  if (samePage) {
    try {
      window.focus();
      window.print();
      return 'printed-current';
    } catch (_) {
      return 'print-failed';
    }
  }

  try {
    const popup = window.open(targetUrl, '_blank');
    if (popup) {
      setTimeout(() => {
        try {
          popup.focus();
          popup.print();
        } catch (_) {}
      }, 700);
      return 'opened-window';
    }
    return 'popup-blocked';
  } catch (_) {
    return 'open-failed';
  }
})();
''');

      final jsResult = _normalizeJsResult(rawResult).toLowerCase();
      if (jsResult.contains('printed-current') ||
          jsResult.contains('opened-window')) {
        await _showMessage('Print dialog requested');
        return;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        await _showMessage('Opened in browser for printing');
      } else {
        await _showMessage('Could not open print target');
      }
    } catch (e) {
      await _showMessage('Could not open print dialog');
    }
  }

  String _normalizeJsResult(Object? value) {
    if (value == null) return '';
    final raw = value.toString();
    if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
      return raw.substring(1, raw.length - 1).replaceAll(r'\"', '"');
    }
    return raw;
  }

  String _sessionCookieKeyForHost(String host) =>
      'iris_session_${_scopeSanitized}_${host.toLowerCase()}_cookies';

  // Session persistence method
  Future<void> _savePortalSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionKey = _portalSessionKey(_currentSession.host);
    final json = jsonEncode(_currentSession.toJson());
    await prefs.setString(sessionKey, json);
  }

  // Load session metadata
  Future<PortalSession?> _loadPortalSession(String host) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionKey = _portalSessionKey(host);
    final json = prefs.getString(sessionKey);
    if (json == null) return null;
    try {
      return PortalSession.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  // Update session timestamp and cookies validity
  Future<void> _updateSessionMetadata() async {
    _currentSession = _currentSession.copyWith(
      lastAccessedAt: DateTime.now().millisecondsSinceEpoch,
      hasValidCookies: true,
    );
    await _savePortalSession();
    await _saveLastActiveSession();
  }

  // Track file download
  Future<void> _trackDownload({
    required String filename,
    required String filePath,
    required String sourceUrl,
    String state = 'completed',
    String backend = 'native',
    String downloadId = '',
  }) async {
    final downloads = [..._currentSession.recentDownloads];
    final normalizedName = filename.trim().toLowerCase();
    final normalizedSource = sourceUrl.trim().toLowerCase();
    downloads.removeWhere((entry) {
      final samePath = filePath.isNotEmpty && entry.filePath == filePath;
      final sameSource =
          normalizedSource.isNotEmpty &&
          entry.sourceUrl.trim().toLowerCase() == normalizedSource;
      final sameNameFallback =
          normalizedName.isNotEmpty &&
          entry.filename.trim().toLowerCase() == normalizedName;
      return samePath ||
          sameSource ||
          (sameNameFallback && entry.state != 'queued');
    });
    downloads.insert(
      0,
      DownloadRecord(
        filename: filename,
        filePath: filePath,
        sourceUrl: sourceUrl,
        savedAt: DateTime.now().millisecondsSinceEpoch,
        state: state,
        backend: backend,
        downloadId: downloadId,
      ),
    );
    _currentSession = _currentSession.copyWith(
      recentDownloads: downloads.take(10).toList(),
    );
    await _savePortalSession();
  }

  Future<void> _removeStaleDownloads() async {
    final current = [..._currentSession.recentDownloads];
    if (current.isEmpty) return;

    final retained = <DownloadRecord>[];
    for (final item in current) {
      if (item.isPending) {
        retained.add(item);
        continue;
      }
      if (item.filePath.isEmpty) {
        retained.add(item);
        continue;
      }
      final exists = await File(item.filePath).exists();
      if (exists) retained.add(item);
    }

    if (retained.length == current.length) return;
    _currentSession = _currentSession.copyWith(recentDownloads: retained);
    await _savePortalSession();
  }

  Future<void> _syncSystemDownloadStates() async {
    if (!Platform.isAndroid) return;
    final current = [..._currentSession.recentDownloads];
    if (current.isEmpty) return;

    bool changed = false;
    final updated = <DownloadRecord>[];

    for (final item in current) {
      if (item.backend != 'system' || item.downloadId.isEmpty) {
        updated.add(item);
        continue;
      }

      final id = int.tryParse(item.downloadId);
      if (id == null) {
        updated.add(item);
        continue;
      }

      try {
        final resp = await _androidDownloadChannel
            .invokeMapMethod<String, dynamic>('querySystemDownload', {
              'downloadId': id,
            });
        if (resp == null) {
          updated.add(item);
          continue;
        }

        final exists = resp['exists'] == true;
        final status = (resp['status']?.toString() ?? '').trim();
        final title = (resp['title']?.toString() ?? '').trim();
        final localUriRaw = (resp['localUri']?.toString() ?? '').trim();

        if (!exists || status.isEmpty) {
          updated.add(item);
          continue;
        }

        var nextPath = item.filePath;
        if (localUriRaw.isNotEmpty) {
          final localUri = Uri.tryParse(localUriRaw);
          if (localUri != null && localUri.scheme == 'file') {
            nextPath = localUri.toFilePath();
          }
        }

        final nextFilename = title.isNotEmpty ? title : item.filename;
        if (status != item.state ||
            nextPath != item.filePath ||
            nextFilename != item.filename) {
          changed = true;
          updated.add(
            DownloadRecord(
              filename: nextFilename,
              filePath: nextPath,
              sourceUrl: item.sourceUrl,
              savedAt: item.savedAt,
              state: status,
              backend: item.backend,
              downloadId: item.downloadId,
            ),
          );
        } else {
          updated.add(item);
        }
      } catch (_) {
        updated.add(item);
      }
    }

    if (!changed) return;
    _currentSession = _currentSession.copyWith(
      recentDownloads: updated.take(10).toList(),
    );
    await _savePortalSession();
  }

  // Track file upload
  Future<void> _trackUpload(String filename) async {
    final uploads = [..._currentSession.recentUploads];
    uploads.removeWhere((f) => f == filename);
    uploads.insert(0, filename);
    _currentSession = _currentSession.copyWith(
      recentUploads: uploads.take(10).toList(),
    );
    await _savePortalSession();
  }

  // Clear session for this portal
  Future<void> _clearCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionKey = _portalSessionKey(_currentSession.host);
    await prefs.remove(sessionKey);
    await prefs.remove(_loginUserKey(_currentSession.host));
    await prefs.remove(_loginPassKey(_currentSession.host));
    final lastRaw = prefs.getString(_lastActiveSessionKey);
    if (lastRaw != null) {
      try {
        final last = PortalSession.fromJson(jsonDecode(lastRaw));
        if (last.host == _currentSession.host) {
          await prefs.remove(_lastActiveSessionKey);
        }
      } catch (_) {}
    }
    if (mounted) await _showMessage('Session and login cleared');
  }

  Future<void> _showDownloadManager() async {
    if (!mounted) return;
    await _syncSystemDownloadStates();
    await _removeStaleDownloads();
    final downloads = _currentSession.recentDownloads;
    final uploads = _currentSession.recentUploads;
    final downloadDir = await _resolveDownloadDirectory();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFFFE7A2C);

    Widget transferList(List<String> items, {required bool uploadsMode}) {
      if (items.isEmpty) {
        return Center(
          child: Text(
            uploadsMode ? 'No uploads yet' : 'No downloads yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.58,
              ),
            ),
          ),
        );
      }

      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          return Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.06,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.10,
                ),
              ),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                uploadsMode
                    ? Icons.upload_file_rounded
                    : Icons.download_done_rounded,
                color: accent,
              ),
              title: Text(
                _displayFileName(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async => _openFilePath(item),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Open',
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    onPressed: () async => _openFilePath(item),
                  ),
                  IconButton(
                    tooltip: 'Copy path',
                    icon: const Icon(Icons.content_copy_rounded, size: 18),
                    onPressed: () async => _copyPath(item),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    Widget downloadList(List<DownloadRecord> items) {
      if (items.isEmpty) {
        return Center(
          child: Text(
            'No downloads yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.58,
              ),
            ),
          ),
        );
      }

      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          return Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.06,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.10,
                ),
              ),
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.download_done_rounded, color: accent),
              title: Text(
                item.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${item.displaySource} · ${item.prettySavedAt} · ${item.statusLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                if (item.isPending && item.backend == 'system') {
                  await _openSystemDownloads();
                  return;
                }
                await _openFilePath(item.filePath);
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.sourceUrl.isNotEmpty)
                    IconButton(
                      tooltip: 'Retry download',
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      onPressed: () async {
                        IrisSfx.pillTap();
                        Navigator.of(context).pop();
                        await _downloadFile(item.sourceUrl);
                      },
                    ),
                  IconButton(
                    tooltip: item.isPending ? 'System downloads' : 'Open',
                    icon: Icon(
                      item.isPending
                          ? Icons.download_rounded
                          : Icons.open_in_new_rounded,
                      size: 18,
                    ),
                    onPressed: () async {
                      IrisSfx.pillTap();
                      if (item.isPending && item.backend == 'system') {
                        await _openSystemDownloads();
                        return;
                      }
                      await _openFilePath(item.filePath);
                    },
                  ),
                  IconButton(
                    tooltip: 'Copy path',
                    icon: const Icon(Icons.content_copy_rounded, size: 18),
                    onPressed: () async {
                      IrisSfx.tick();
                      await _copyPath(item.filePath);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DefaultTabController(
        length: 2,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF111827) : Colors.white)
                        .withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Download Manager',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${downloads.length} downloads',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        downloadDir.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed:
                                downloads.isEmpty ||
                                    downloads.first.sourceUrl.isEmpty
                                ? null
                                : () async {
                                    Navigator.of(context).pop();
                                    await _downloadFile(
                                      downloads.first.sourceUrl,
                                    );
                                  },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry Latest'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () async =>
                                _openFolderPath(downloadDir.path),
                            icon: const Icon(Icons.folder_open_rounded),
                            label: const Text('Folder'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () async => _openSystemDownloads(),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('System'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await _syncSystemDownloadStates();
                              await _removeStaleDownloads();
                              if (mounted) {
                                Navigator.of(context).pop();
                                await _showMessage(
                                  'Download statuses refreshed',
                                );
                              }
                            },
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text('Refresh'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: downloads.isEmpty
                                ? null
                                : () async =>
                                      _openFilePath(downloads.first.filePath),
                            icon: const Icon(Icons.file_open_rounded),
                            label: const Text('Latest'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await _removeStaleDownloads();
                              if (mounted) {
                                Navigator.of(context).pop();
                                await _showMessage(
                                  'Removed missing files from history',
                                );
                              }
                            },
                            icon: const Icon(Icons.cleaning_services_rounded),
                            label: const Text('Clean Missing'),
                          ),
                          TextButton.icon(
                            onPressed: () async => _copyPath(downloadDir.path),
                            icon: const Icon(Icons.content_copy_rounded),
                            label: const Text('Copy Path'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              _currentSession = _currentSession.copyWith(
                                recentDownloads: const [],
                                recentUploads: const [],
                              );
                              await _savePortalSession();
                              if (mounted) {
                                Navigator.of(context).pop();
                                await _showMessage('Transfer history cleared');
                              }
                            },
                            icon: const Icon(Icons.delete_sweep_rounded),
                            label: const Text('Clear'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TabBar(
                        indicator: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        labelColor: accent,
                        unselectedLabelColor:
                            (isDark ? Colors.white : Colors.black).withValues(
                              alpha: 0.6,
                            ),
                        tabs: const [
                          Tab(text: 'Downloads'),
                          Tab(text: 'Uploads'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          children: [
                            downloadList(downloads),
                            transferList(uploads, uploadsMode: true),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showClearLoginConfirm() async {
    if (!mounted) return;
    await _showMessage(
      'Clear saved login for $_hostKey?',
      duration: const Duration(seconds: 7),
      action: SnackBarAction(
        label: 'Clear',
        onPressed: () async {
          await _clearSavedLogin();
          if (!mounted) return;
          setState(() {
            _hasSavedLogin = false;
          });
        },
      ),
    );
  }

  Future<void> _showClearSessionConfirm() async {
    if (!mounted) return;
    await _showMessage(
      'Clear this portal session and data?',
      duration: const Duration(seconds: 7),
      action: SnackBarAction(
        label: 'Clear',
        onPressed: () async {
          await _clearCurrentSession();
        },
      ),
    );
  }

  Future<void> _persistSessionCookiesForUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    try {
      final host = uri.host;
      // Note: webview_flutter 4.x doesn't have a direct getCookies() that sees HttpOnly.
      // We use document.cookie for now as it captures the primary session identifiers.
      final raw = await _controller.runJavaScriptReturningResult('document.cookie');
      final cookieString = _normalizeJsResult(raw).trim();
      
      if (cookieString.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionCookieKeyForHost(host), cookieString);
        
        // Also update background service global key if this is student scope
        if (_scopeSanitized == 'student') {
           await prefs.setString('iris_session_student_${host.toLowerCase()}_cookies', cookieString);
        }
        
        print('🍪 Session cookies persisted for $host');
      }
    } catch (e) {
      print('⚠️ Cookie persistence failed: $e');
    }
  }

  Future<void> _restoreSessionCookiesForUri(Uri uri) async {
    if (uri.host.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final cookieHeader = prefs.getString(_sessionCookieKeyForHost(uri.host));
    if (cookieHeader == null || cookieHeader.trim().isEmpty) return;

    for (final part in cookieHeader.split(';')) {
      final entry = part.trim();
      if (entry.isEmpty) continue;
      final equalsAt = entry.indexOf('=');
      if (equalsAt <= 0) continue;

      final name = entry.substring(0, equalsAt).trim();
      final value = entry.substring(equalsAt + 1).trim();
      if (name.isEmpty) continue;

      try {
        await _cookieManager.setCookie(
          WebViewCookie(name: name, value: value, domain: uri.host, path: '/'),
        );
      } catch (_) {
        // Skip malformed/unsupported cookies.
      }
    }
  }

  void _clearTopPillOverlay() {
    _pillRevertTimer?.cancel();
    _pillRevertTimer = null;

    if (!mounted) return;
    setState(() {
      _pillActive = false;
      _pillMessage = null;
      _pillIcon = null;
      _pillAction = null;
      _pillActionLabel = null;
    });
  }

  void _showTopPill({
    required String text,
    required Color tone,
    required IconData icon,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;
    _pillRevertTimer?.cancel();
    if (!_isHeaderCollapsed) {
      setState(() => _isHeaderCollapsed = true);
    }

    setState(() {
      _pillActive = true;
      _pillMessage = text;
      _pillIcon = icon;
      _pillTone = tone;
      _pillAction = action?.onPressed;
      _pillActionLabel = action?.label;
    });

    final adaptiveHoldMs = (900 + (text.length * 22)).clamp(1200, 3400);
    final holdMs = math
        .min(duration.inMilliseconds, adaptiveHoldMs)
        .clamp(1100, 3400);
    _pillRevertTimer = Timer(Duration(milliseconds: holdMs), () {
      if (!mounted) return;
      setState(() {
        _pillActive = false;
        _pillMessage = null;
        _pillIcon = null;
        _pillAction = null;
        _pillActionLabel = null;
      });
    });
  }

  String _compactPillMessage(String message) {
    final raw = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.isEmpty) return 'Updated';

    final lower = raw.toLowerCase();

    if (lower.startsWith('autofilled')) return 'Autofill done';
    if (lower.startsWith('no saved login')) return 'No saved login';
    if (lower.startsWith('saved login removed')) return 'Login removed';
    if (lower.startsWith('download complete:')) {
      final name = raw.substring('download complete:'.length).trim();
      if (name.isEmpty) return 'Download complete';
      final shortName = name.length > 22 ? '${name.substring(0, 19)}...' : name;
      return 'Downloaded: $shortName';
    }
    if (lower.startsWith('downloading')) return 'Downloading file';
    if (lower.contains('download failed')) return 'Download failed';
    if (lower.contains('back online')) return 'Back online';
    if (lower.contains('offline')) return 'Offline';
    if (lower.startsWith('refreshing')) return 'Refreshing';
    if (lower.startsWith('path copied')) return 'Path copied';
    if (lower.contains('print dialog requested')) return 'Print requested';
    if (lower.contains('opened in browser for printing')) {
      return 'Opened in browser';
    }

    if (raw.length <= 44) return raw;
    return '${raw.substring(0, 41)}...';
  }

  Future<void> _showMessage(
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) async {
    if (!mounted) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastSnackMessage == message && nowMs - _lastSnackAtMs < 1500) {
      return;
    }
    if (nowMs - _lastSnackAtMs < 220) {
      return;
    }
    _lastSnackMessage = message;
    _lastSnackAtMs = nowMs;

    final compactMessage = _compactPillMessage(message);
    final lower = message.toLowerCase();
    final isError =
        lower.contains('error') ||
        lower.contains('failed') ||
        lower.contains('invalid');
    final isOffline = lower.contains('offline');
    final isDownload = lower.contains('download');
    final isPrint = lower.contains('print');
    final isAutofill =
        lower.contains('autofill') ||
        lower.contains('saved login') ||
        lower.contains('save login');
    final isUpload = lower.contains('upload');
    final isCopy = lower.contains('copied') || lower.contains('copy path');
    final isSuccess =
        lower.contains('saved') ||
        lower.contains('complete') ||
        lower.contains('success') ||
        lower.contains('back online');
    final isHint =
        lower.contains('refresh') ||
        lower.contains('loading') ||
        lower.contains('open') ||
        lower.contains('select');

    Color tone = const Color(0xFF7C8AA5);
    IconData icon = Icons.notifications_none_rounded;
    if (isError) {
      tone = const Color(0xFFEF4444);
      icon = Icons.error_outline_rounded;
    } else if (isOffline) {
      tone = const Color(0xFFF59E0B);
      icon = Icons.cloud_off_rounded;
    } else if (isDownload) {
      tone = const Color(0xFF22D3EE);
      icon = Icons.download_rounded;
    } else if (isPrint) {
      tone = const Color(0xFFA78BFA);
      icon = Icons.print_rounded;
    } else if (isAutofill) {
      tone = const Color(0xFF34D399);
      icon = Icons.vpn_key_rounded;
    } else if (isUpload) {
      tone = const Color(0xFF38BDF8);
      icon = Icons.cloud_upload_rounded;
    } else if (isCopy) {
      tone = const Color(0xFFF472B6);
      icon = Icons.content_copy_rounded;
    } else if (isSuccess) {
      tone = const Color(0xFF10B981);
      icon = Icons.check_circle_outline_rounded;
    } else if (isHint) {
      tone = const Color(0xFFFE7A2C);
      icon = Icons.info_outline_rounded;
    }
    _showTopPill(
      text: compactMessage,
      tone: tone,
      icon: icon,
      action: action,
      duration: duration,
    );
  }

  Future<void> _autofillSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final u = prefs.getString(_loginUserKey(_hostKey));
    final p = prefs.getString(_loginPassKey(_hostKey));
    if (u == null || p == null) {
      await _showMessage('No saved login found for $_hostKey');
      return;
    }

    final username = utf8.decode(base64Decode(u));
    final password = utf8.decode(base64Decode(p));

    final jsUser = jsonEncode(username);
    final jsPass = jsonEncode(password);
    final script =
        '''
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

  const isVisible = (element) => {
    const style = window.getComputedStyle(element);
    return !!element && style && style.display !== 'none' && style.visibility !== 'hidden' && element.getClientRects().length > 0;
  };

  const scoreField = (element) => {
    const meta = [element.name, element.id, element.placeholder, element.autocomplete, element.type].filter(Boolean).join(' ').toLowerCase();
    let score = 0;
    if (/email|user|username|login|roll|reg|id|student|account/.test(meta)) score += 3;
    if (/password/.test(meta)) score -= 8;
    if (element.type === 'text' || element.type === 'email' || element.type === 'tel' || element.type === 'number') score += 1;
    if (!isVisible(element)) score -= 4;
    return score;
  };

  const pwd = document.querySelector('input[type="password"]');
  const scope = (pwd && pwd.form) ? pwd.form : document;
  const candidates = Array.from(scope.querySelectorAll('input, textarea'))
    .filter((element) => element !== pwd)
    .filter((element) => {
      const type = (element.type || '').toLowerCase();
      return type !== 'hidden' && type !== 'password';
    })
    .sort((a, b) => scoreField(b) - scoreField(a));
  const user = candidates[0] || null;

  if (user) {
    user.focus();
    setNativeValue(user, $jsUser);
  }
  if (pwd) {
    pwd.focus();
    setNativeValue(pwd, $jsPass);
  }
})();
''';
    await _controller.runJavaScript(script);
    await _updateSessionMetadata();
    await _showMessage('Autofilled saved login');
  }

  Future<void> _clearSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginUserKey(_hostKey));
    await prefs.remove(_loginPassKey(_hostKey));
    await _showMessage('Saved login removed for $_hostKey');
  }

  Future<void> _triggerUploadPicker() async {
    const script = '''
(() => {
  const fileInput = document.querySelector('input[type="file"]');
  if (fileInput) {
    fileInput.click();
    return true;
  }
  return false;
})();
''';
    final raw = await _controller.runJavaScriptReturningResult(script);
    final ok = _normalizeJsResult(raw).toLowerCase().contains('true');
    await _showMessage(
      ok
          ? 'Select your assignment file from picker'
          : 'No upload field found on this page',
    );
  }

  String _sanitizeFileName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'download.bin' : cleaned;
  }

  String _extensionForMime(String mime) {
    final normalized = mime.toLowerCase().split(';').first.trim();
    return switch (normalized) {
      'application/pdf' => '.pdf',
      'application/zip' => '.zip',
      'application/x-zip-compressed' => '.zip',
      'application/msword' => '.doc',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
        '.docx',
      'application/vnd.ms-powerpoint' => '.ppt',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation' =>
        '.pptx',
      'application/vnd.ms-excel' => '.xls',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
        '.xlsx',
      'application/vnd.android.package-archive' => '.apk',
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'text/plain' => '.txt',
      _ => '',
    };
  }

  String _ensureFileExtension(String name, String mime) {
    final safe = _sanitizeFileName(name);
    if (RegExp(r'\.[a-zA-Z0-9]{1,6}$').hasMatch(safe)) return safe;
    final ext = _extensionForMime(mime);
    if (ext.isEmpty) return safe;
    return '$safe$ext';
  }

  Future<Directory> _resolveDownloadDirectory() async {
    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        return publicDownload;
      }

      final dirs = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (dirs != null && dirs.isNotEmpty) {
        return dirs.first;
      }
      return publicDownload;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<void> _saveDownloadData(
    String filename,
    String dataUrl, {
    String sourceUrl = '',
  }) async {
    try {
      final parts = dataUrl.split(',');
      if (parts.length < 2) {
        await _showMessage('Download failed: invalid file data');
        return;
      }

      final saveDir = await _resolveDownloadDirectory();
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final mime = parts.first
          .toLowerCase()
          .replaceFirst('data:', '')
          .split(';')
          .first
          .trim();
      final safeName = _ensureFileExtension(filename, mime);
      final bytes = base64Decode(parts.last);
      final file = File('${saveDir.path}/$safeName');
      await file.writeAsBytes(bytes, flush: true);

      // Track the download
      await _trackDownload(
        filename: safeName,
        filePath: file.path,
        sourceUrl: sourceUrl,
        state: 'completed',
        backend: 'js',
      );

      IrisSfx.downloadSuccess();

      if (!mounted) return;
      await _showMessage(
        'Download complete: $safeName',
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () async {
            await _openFilePath(file.path);
          },
        ),
      );
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 300), () async {
          if (!mounted) return;
          await _showMessage(
            'Open Download Manager for recent files',
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Manager',
              onPressed: () async => _showDownloadManager(),
            ),
          );
        }),
      );
    } catch (_) {
      await _showMessage('Download failed while saving file');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = -1;
        });
      }
    }
  }

  String _filenameFromResponse({
    required Uri uri,
    required HttpHeaders headers,
  }) {
    final disposition = headers.value('content-disposition') ?? '';
    final utf8Name = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    final plainName = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    final raw =
        utf8Name ??
        plainName ??
        (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download');
    final decoded = Uri.decodeComponent(raw);
    final contentType = headers.contentType?.mimeType ?? '';
    final baseName = decoded.isEmpty ? 'download' : decoded;
    return _ensureFileExtension(baseName, contentType);
  }

  Future<String> _readPortalCookieHeader() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      return _normalizeJsResult(raw).trim();
    } catch (_) {
      return '';
    }
  }

  String _fileNameFromUrl(Uri uri) {
    if (uri.pathSegments.isNotEmpty) {
      final raw = uri.pathSegments.last.trim();
      if (raw.isNotEmpty) {
        return _sanitizeFileName(Uri.decodeComponent(raw));
      }
    }
    return 'download';
  }

  bool _isSameHost(Uri a, Uri b) {
    return a.host == b.host ||
        a.host.endsWith('.${b.host}') ||
        b.host.endsWith('.${a.host}');
  }



  Future<void> _downloadFileFast(Uri uri) async {
    final saveDir = await _resolveDownloadDirectory();
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final cookieHeader = await _readPortalCookieHeader();
    final currentUri = Uri.tryParse(
      _currentUrl.isEmpty ? widget.url : _currentUrl,
    );
    final sameHost =
        currentUri != null &&
        (uri.host == currentUri.host ||
            uri.host.endsWith('.${currentUri.host}') ||
            currentUri.host.endsWith('.${uri.host}'));
    final referer = sameHost
        ? currentUri.toString()
        : '${uri.scheme}://${uri.host}/';

    // Robust client with SSL bypass for university portals
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 25)
      ..badCertificateCallback = (cert, host, port) => true;

    IOSink? sink;
    File? tempFile;
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.followRedirects = true;
      request.maxRedirects = 8;
      request.headers.set(HttpHeaders.userAgentHeader, _portalUserAgent);
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      request.headers.set(HttpHeaders.refererHeader, referer);
      request.headers.set('Connection', 'keep-alive');

      if (sameHost && cookieHeader.isNotEmpty) {
        request.headers.set(HttpHeaders.cookieHeader, cookieHeader);
      }

      final response = await request.close().timeout(
        const Duration(seconds: 120),
      );

      // Handle common portal status codes
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw HttpException('Access Denied (${response.statusCode})', uri: uri);
      }
      if (response.statusCode >= 400) {
        throw HttpException('Server Error (${response.statusCode})', uri: uri);
      }

      final safeName = _filenameFromResponse(
        uri: uri,
        headers: response.headers,
      );
      final finalFile = File('${saveDir.path}/$safeName');
      tempFile = File('${saveDir.path}/.$safeName.part');
      
      if (await tempFile.exists()) {
        try { await tempFile.delete(); } catch (_) {}
      }
      
      sink = tempFile.openWrite();

      final total = response.contentLength;
      int loaded = 0;
      int lastPercent = -1;

      await for (final chunk in response) {
        sink.add(chunk);
        loaded += chunk.length;
        if (!mounted) continue;
        if (total > 0) {
          final percent = ((loaded / total) * 100).clamp(0, 100).toInt();
          if (percent != lastPercent &&
              (percent == 100 || percent - lastPercent >= 2)) {
            lastPercent = percent;
            setState(() {
              _isDownloading = true;
              _downloadProgress = loaded / total;
            });
          }
        } else {
          // Indeterminate progress
          if (loaded % (100 * 1024) == 0) { // Every 100KB
            setState(() {
              _isDownloading = true;
              _downloadProgress = -1;
            });
          }
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (await finalFile.exists()) {
        try { await finalFile.delete(); } catch (_) {}
      }
      await tempFile.rename(finalFile.path);

      await _trackDownload(
        filename: safeName,
        filePath: finalFile.path,
        sourceUrl: uri.toString(),
        state: 'completed',
        backend: 'native',
      );

      IrisSfx.downloadSuccess();

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = -1;
        });
        await _showMessage(
          'Download complete: $safeName',
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () async => _openFilePath(finalFile.path),
          ),
        );
      }
    } catch (e) {
      try {
        await sink?.flush();
        await sink?.close();
      } catch (_) {}
      if (tempFile != null && await tempFile.exists()) {
        try { await tempFile.delete(); } catch (_) {}
      }
      rethrow;
    }
  }


  /// One-press reliable download flow
  Future<void> _downloadFile(String url) async {
    if (!mounted) return;
    
    // Normalize and validate URL
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (!uri.hasScheme && !url.startsWith('data:'))) {
      await _showMessage('Invalid download link');
      return;
    }

    // Debounce to prevent multiple triggers
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastDownloadUrl == url && (now - _lastDownloadAtMs) < 1500) return;
    _lastDownloadUrl = url;
    _lastDownloadAtMs = now;

    // Handle Data URLs directly
    if (url.startsWith('data:')) {
      setState(() => _isDownloading = true);
      await _showMessage('Saving generated file...');
      try {
        final commaIndex = url.indexOf(',');
        if (commaIndex == -1) throw 'Invalid data URL';
        final data = url.substring(commaIndex + 1);
        final filename = 'download_${now % 10000}.bin';
        await _saveDownloadData(filename, data, sourceUrl: 'data:...');
      } catch (e) {
        setState(() => _isDownloading = false);
        await _showMessage('Failed to save data URL');
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });
    await _showMessage('Starting download...');

    try {
      // Execute the robust native download
      await _downloadFileFast(uri);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadProgress = -1;
      });
      
      final errorMsg = e.toString().contains('HttpException') 
          ? e.toString().split(':').last.trim() 
          : 'Network error or access denied';
          
      await _trackDownload(
        filename: _fileNameFromUrl(uri),
        filePath: '',
        sourceUrl: uri.toString(),
        state: 'failed',
        backend: 'native',
      );
      
      IrisSfx.error();
      await _showMessage('Download failed: $errorMsg');
    }
  }

  Future<void> _processScrapedTasks(Map<String, dynamic> data) async {
    try {
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
        setState(() => _scraperLogs.add('[IRIS] Scrape successful! Saving ${flattenedTasks.length} tasks.'));
        await PortalSyncService.updatePersistence(flattenedTasks);
        PortalSyncService.notifyUpdate();
      } else {
        setState(() => _scraperLogs.add('[IRIS] Scrape completed, but no new tasks found.'));
      }
    } catch (e) {
      setState(() => _scraperLogs.add('[ERROR] Task processing failed: $e'));
    }
  }

  // Handles messages from the injected JS channel
  void _handleJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);
      if (data['type'] == 'log') {
        if (mounted) {
          setState(() {
            _scraperLogs.add(data['message']);
            // Limit log size to 100 entries
            if (_scraperLogs.length > 100) _scraperLogs.removeAt(0);
          });
        }
        return;
      }
      
      if (data['type'] == 'portal_sync_tasks') {
        _processScrapedTasks(data);
        return;
      }
      
      final type = data['type']?.toString() ?? '';
      if (type == 'login_submit') {
        _offerToSaveLogin(
          username: data['username']?.toString() ?? '',
          password: data['password']?.toString() ?? '',
        );
      } else if (type == 'login_focus') {
        if (mounted && _hasSavedLogin) {
          setState(() => _showAutofillPrompt = true);
        }
      } else if (type == 'download') {
        final url = data['url']?.toString() ?? '';
        if (url.isNotEmpty) _downloadFile(url);
      } else if (type == 'download_progress') {
        final loaded = (data['loaded'] as num?)?.toDouble() ?? 0;
        final total = (data['total'] as num?)?.toDouble() ?? 0;
        if (mounted) {
          if (total > 0) {
            final next = (loaded / total).clamp(0.0, 1.0);
            setState(() {
              _isDownloading = true;
              _downloadProgress = next;
            });
          } else {
            setState(() {
              _isDownloading = true;
              _downloadProgress = -1;
            });
          }
        }
      } else if (type == 'download_data') {
        final filename = data['filename']?.toString() ?? 'download';
        final dataUrl = data['data']?.toString() ?? '';
        final sourceUrl = data['sourceUrl']?.toString() ?? '';
        if (dataUrl.isNotEmpty) {
          if (mounted) {
            setState(() => _downloadProgress = 1);
          }
          _saveDownloadData(filename, dataUrl, sourceUrl: sourceUrl);
        } else if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadProgress = -1;
          });
        }
      } else if (type == 'download_error') {
        final sourceUrl =
            data['sourceUrl']?.toString() ?? data['url']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadProgress = -1;
          });
          IrisSfx.error();
          _showMessage('Download failed: ${data['error'] ?? 'unknown error'}');
        }
        final failedUri = Uri.tryParse(sourceUrl);
        if (failedUri != null) {
          _trackDownload(
            filename: _fileNameFromUrl(failedUri),
            filePath: '',
            sourceUrl: failedUri.toString(),
            state: 'failed',
            backend: 'js',
          );
        }
      } else if (type == 'download_retry') {
        if (mounted) {
          final attempt = (data['attempt'] as num?)?.toInt() ?? 0;
          if (attempt > 0) {
            setState(() => _isDownloading = true);
            _showMessage('Retrying download... attempt $attempt');
          }
        }
      } else if (type == 'portal_sync_tasks') {
        final List<dynamic> courseData = data['tasks'] as List<dynamic>? ?? [];
        final List<PortalTask> flattenedTasks = [];
        
        for (final course in courseData) {
          final courseName = course['courseName']?.toString() ?? 'Unknown';
          final courseId = course['courseId']?.toString();
          final tasks = course['tasks'] as List<dynamic>? ?? [];
          
          for (final t in tasks) {
            flattenedTasks.add(PortalTask(
              type: t['type']?.toString() ?? 'Assignment',
              title: t['title']?.toString() ?? 'Untitled',
              subject: courseName,
              dueDate: t['deadline']?.toString() ?? '',
              status: t['status']?.toString() ?? '',
              courseId: courseId,
              isCompleted: t['status']?.toString().toLowerCase().contains('submitted') ?? false,
              scrapedAt: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }

        if (mounted) {
          setState(() {
            _currentSession = _currentSession.copyWith(
              tasks: flattenedTasks,
              lastSyncAt: DateTime.now().millisecondsSinceEpoch,
            );
          });
          _savePortalSession();
          PortalSyncService.notifyUpdate();
          _showMessage('✓ Scoped ${flattenedTasks.length} portal tasks');
          IrisSfx.tick();
        }
      }
    } catch (_) {}
  }

  // Shows a browser-style "Save password?" banner after form submit
  void _offerToSaveLogin({required String username, required String password}) {
    if (!mounted || username.isEmpty || password.isEmpty) return;
    final host = _hostKey;
    _showMessage(
      'Save login for $host?',
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: 'Save',
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _loginUserKey(host),
            base64Encode(utf8.encode(username)),
          );
          await prefs.setString(
            _loginPassKey(host),
            base64Encode(utf8.encode(password)),
          );

          // Update session with saved username
          _currentSession = _currentSession.copyWith(savedUsername: username);
          await _savePortalSession();

          if (mounted) {
            _showMessage('✓ Login saved for $host');
            setState(() {
              _hasSavedLogin = true;
            });
          }
        },
      ),
    );
  }

  // Native file picker for WebView file inputs (Android)
  Future<List<String>> _handleFileSelector(FileSelectorParams params) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (result == null) return [];
      final paths = result.paths.whereType<String>().toList();
      // Track uploaded files
      for (final path in paths) {
        await _trackUpload(path);
      }
      return paths;
    } catch (_) {
      return [];
    }
  }

  String get addressLabelSafe => _currentUrl.isEmpty ? widget.url : _currentUrl;

  // Detects form submissions with a password field and offers to save credentials
  static const String _savePasswordScript = r'''
(() => {
  if (window._irisFormWatcher) return;
  window._irisFormWatcher = true;
  const watch = () => {
    document.querySelectorAll('form').forEach(form => {
      if (form._irisWatching) return;
      form._irisWatching = true;
      form.addEventListener('submit', () => {
        const pwd = form.querySelector('input[type="password"]');
        if (!pwd || !pwd.value) return;
        const user = form.querySelector(
          'input[type="email"], input[name*="user" i], input[id*="user" i], input[name*="roll" i], input[name*="reg" i], input[type="text"]'
        );
        if (window.IrisPortalChannel) {
          window.IrisPortalChannel.postMessage(JSON.stringify({
            type: 'login_submit',
            username: user ? user.value : '',
            password: pwd.value
          }));
        }
      }, true);
    });
  };
  watch();
  new MutationObserver(watch).observe(
    document.body || document.documentElement,
    { childList: true, subtree: true }
  );
})();
''';

  // Intercepts download link clicks and routes them to the native handler
  static const String _downloadInterceptScript = r'''
(() => {
  if (window._irisDownloadWatcher) return;
  window._irisDownloadWatcher = true;
  
  const isDownloadUrl = (url, anchor) => {
    if (!url) return false;
    const lower = url.toLowerCase();
    if (anchor && anchor.hasAttribute('download')) return true;
    
    // Common download patterns in portals
    const patterns = [
      /\.(pdf|doc|docx|ppt|pptx|xls|xlsx|zip|rar|7z|apk|png|jpg|jpeg|txt|csv)(\?|$)/i,
      /download/i, /getfile/i, /export/i, /attachment/i, /viewfile/i, /stream/i, /generate/i
    ];
    return patterns.some(p => p.test(lower));
  };

  document.addEventListener('click', function(e) {
    const a = e.target.closest ? e.target.closest('a[href]') : null;
    if (!a) return;
    
    const href = a.href || '';
    if (href.startsWith('javascript:') || href.startsWith('mailto:') || href.startsWith('tel:')) return;
    
    if (isDownloadUrl(href, a)) {
      if (window.IrisPortalChannel) {
        e.preventDefault();
        e.stopPropagation();
        window.IrisPortalChannel.postMessage(JSON.stringify({ type: 'download', url: href }));
      }
    }
  }, true);
})();
''';

  static const String _modernizeFormScript = '''
(() => {
  try {
    const styleId = 'iris-modern-form-style';
    if (!document.getElementById(styleId)) {
      const style = document.createElement('style');
      style.id = styleId;
      style.textContent = `
        input, select, textarea {
          min-height: 42px !important;
          font-size: 16px !important;
          border-radius: 10px !important;
        }
        input:focus, select:focus, textarea:focus, button:focus {
          outline: 2px solid rgba(91,127,255,0.25) !important;
          outline-offset: 1px !important;
        }
        button {
          min-height: 40px !important;
          border-radius: 10px !important;
        }
      `;
      document.head.appendChild(style);
    }
  } catch (_) {}
})();
''';

  /// Universal Extraction Engine for COMSATS Portal (Mobile Optimized)
  // Shared with HeadlessPortalSync

  Future<void> _updateNavState() async {
    final canBack = await _controller.canGoBack();
    final canForward = await _controller.canGoForward();
    final current = await _controller.currentUrl() ?? widget.url;
    if (!mounted) return;
    setState(() {
      _canGoBack = canBack;
      _canGoForward = canForward;
      _currentUrl = current;
    });
  }

  Future<void> _openAddressBar() async {
    if (!mounted) return;
    setState(() {
      _isEditingAddress = true;
      _addressController.text = addressLabelSafe;
      _addressController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _addressController.text.length,
      );
    });
  }

  void _cancelAddressEdit() {
    if (!mounted) return;
    setState(() {
      _isEditingAddress = false;
      _addressController.clear();
    });
  }

  Future<void> _submitAddressBar(String rawValue) async {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      _cancelAddressEdit();
      return;
    }
    final normalized =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) {
      await _showMessage('Invalid address');
      return;
    }

    await _controller.loadRequest(uri);
    await _updateNavState();
    _cancelAddressEdit();
  }

  Future<void> _syncPortalTasks({bool silent = false}) async {
    if (_isSyncing || _isLoading) return;
    if (!mounted) return;
    
    setState(() {
      _isSyncing = true;
      _scraperLogs = ['[IRIS] Initializing Deep Sync...', '[IRIS] Using Session: ${_currentSession.host}'];
    });

    if (!silent) {
      _showTopPill(
        text: 'Syncing assignments...',
        icon: Icons.sync_rounded,
        tone: IrisTokens.brand,
      );
      IrisSfx.pillTap();
      // Show the log sheet automatically when manual sync is triggered
      _showScraperLogs();
    }
    
    try {
      // Inject a script that overrides console.log to pipe back to IrisPortalChannel
      const logOverride = r'''
        (function() {
          const oldLog = console.log;
          const oldError = console.error;
          console.log = function(...args) {
            window.IrisPortalChannel.postMessage(JSON.stringify({ type: 'log', message: args.join(' ') }));
            oldLog.apply(console, args);
          };
          console.error = function(...args) {
            window.IrisPortalChannel.postMessage(JSON.stringify({ type: 'log', message: 'ERROR: ' + args.join(' ') }));
            oldError.apply(console, args);
          };
        })();
      ''';
      await _controller.runJavaScript(logOverride + HeadlessPortalSync.syncPortalScript);
    } catch (e) {
      setState(() => _scraperLogs.add('[ERROR] Sync failed: $e'));
      if (!silent) {
        _showTopPill(
          text: 'Sync failed',
          icon: Icons.error_outline_rounded,
          tone: IrisTokens.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _clearTopPillOverlay();
        });
      }
    }
  }

  void _showScraperLogs() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Listen to changes in logs
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scraper Engine Logs',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_isSyncing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _scraperLogs.length,
                    itemBuilder: (ctx, i) {
                      final log = _scraperLogs[i];
                      final isError = log.contains('ERROR');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isError ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _toggleHeaderCollapsed() {
    HapticFeedback.selectionClick();
    setState(() => _isHeaderCollapsed = !_isHeaderCollapsed);
  }

  Future<void> _showHeaderActionSheet({required String addressLabel}) async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Future<void> handle(String value) async {
      if (value == 'refresh') {
        await _refreshPage();
      }
      if (value == 'open-external') {
        final uri = Uri.tryParse(addressLabel);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      if (value == 'downloads') {
        await _showDownloadManager();
      }
      if (value == 'print-document') {
        await _handlePrintDocument(addressLabel);
      }
      if (value == 'copy-link') {
        await _copyPath(addressLabel);
      }
      if (value == 'clear-login') {
        await _showClearLoginConfirm();
      }
      if (value == 'clear-session') {
        await _showClearSessionConfirm();
      }
      await _updateNavState();
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        Widget item({
          required IconData icon,
          required String label,
          required String value,
          bool danger = false,
        }) {
          final color = danger
              ? const Color(0xFFEF4444)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.90)
                    : Colors.black.withValues(alpha: 0.82));
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await handle(value);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF111827) : Colors.white)
                        .withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 8),
                      item(
                        icon: Icons.refresh_rounded,
                        label: 'Reload Page',
                        value: 'refresh',
                      ),
                      item(
                        icon: Icons.open_in_browser_rounded,
                        label: 'Open in Browser',
                        value: 'open-external',
                      ),
                      item(
                        icon: Icons.print_rounded,
                        label: 'Print Page',
                        value: 'print-document',
                      ),
                      item(
                        icon: Icons.download_for_offline_rounded,
                        label: 'Download Manager',
                        value: 'downloads',
                      ),
                      item(
                        icon: Icons.link_rounded,
                        label: 'Copy Current Link',
                        value: 'copy-link',
                      ),
                      Divider(
                        height: 1,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.10),
                      ),
                      item(
                        icon: Icons.key_off_rounded,
                        label: 'Clear Saved Login',
                        value: 'clear-login',
                        danger: true,
                      ),
                      item(
                        icon: Icons.delete_sweep_rounded,
                        label: 'Clear Portal Data',
                        value: 'clear-session',
                        danger: true,
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Pause background sync while the user is actively in the portal
    PortalSyncService.isSyncPaused.value = true;

    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();

    _currentUrl = widget.url;

    // Initialize session (will be populated from prefs or created fresh)
    _currentSession = PortalSession(
      host: Uri.tryParse(widget.url)?.host ?? 'portal',
      title: widget.title,
      url: widget.url,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      lastAccessedAt: DateTime.now().millisecondsSinceEpoch,
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent(_portalUserAgent)
      ..addJavaScriptChannel(
        'IrisPortalChannel',
        onMessageReceived: _handleJsMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri != null) {
              await _restoreSessionCookiesForUri(uri);
            }
            if (_looksDownloadableUrl(request.url)) {
              _downloadFile(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onProgress: (value) {
            if (!mounted) return;
            final shouldUpdate =
                value == 100 ||
                value == 0 ||
                (value - _lastRenderedProgress).abs() >= 8;
            if (!shouldUpdate) return;
            _lastRenderedProgress = value;
            setState(() => _progress = value);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            _stopLoginFocusWatch();
            setState(() {
              _isLoading = true;
              _progress = 0;
              _hasLoginForm = false;
              _hasFileUpload = false;
              _showAutofillPrompt = false;
            });
            _checkConnectivity();
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            _currentUrl = url;
            await _controller.runJavaScript(_modernizeFormScript);
            await _controller.runJavaScript(_savePasswordScript);
            await _controller.runJavaScript(_downloadInterceptScript);
            
            // Sync cookies aggressively
            await _persistSessionCookiesForUrl(url);
            await _updateSessionMetadata();
            
            setState(() {
              _isLoading = false;
              _progress = 100;
            });
            
            await _updateNavState();
            _startLoginFocusWatch();
            await _checkConnectivity();

            // Detect features after page loads
            await Future.delayed(const Duration(milliseconds: 500));
            await _detectPageFeatures();
          },
          onWebResourceError: (error) async {
            if (!mounted) return;
            setState(() {
              _isOffline = true;
              _isLoading = false;
            });
            await _showMessage('You appear to be offline');
          },
        ),
      );

    // Enable native file picker for <input type="file"> on Android
    if (Platform.isAndroid) {
      final platform = _controller.platform;
      if (platform is AndroidWebViewController) {
        platform.setOnShowFileSelector(_handleFileSelector);
      }
    }

    final initialUri = Uri.parse(widget.url);
    Future.microtask(() async {
      // Restore last active session first, fallback to portal-specific session, then widget URL.
      final lastActive = await _loadLastActiveSession();
      Uri launchUri = initialUri;
      if (lastActive != null) {
        _currentSession = lastActive;
        final parsed = Uri.tryParse(lastActive.url);
        if (parsed != null) {
          launchUri = parsed;
          _currentUrl = launchUri.toString();
        }
      } else {
        final existingSession = await _loadPortalSession(initialUri.host);
        if (existingSession != null) {
          _currentSession = existingSession;
        }
      }

      await _restoreSessionCookiesForUri(launchUri);
      await _controller.loadRequest(launchUri);
      await _checkConnectivity();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateNavState();
    });

    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnectivity();
    });
  }

  @override
  void dispose() {
    // Resume background sync when the user leaves the portal
    PortalSyncService.isSyncPaused.value = false;
    _connectivityTimer?.cancel();
    _stopLoginFocusWatch();
    _clearTopPillOverlay();
    _addressController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Widget _buildHeaderQuickActionChip({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final accent = IrisTokens.brand;
    final textColor = isDark ? Colors.white : IrisTokens.surfaceDarkElevated;
    
    // Use IrisVibrancy for a more glassmorphic feel
    final opacity = primary ? 0.18 : 0.08;
    final chipColor = (isDark ? Colors.white : Colors.black).withValues(alpha: opacity);
    final borderColor = primary
        ? accent.withValues(alpha: 0.36)
        : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12);
    
    final radius = BorderRadius.circular(IrisTokens.radiusFull);

    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: 0.8),
          boxShadow: [
            if (primary)
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor.withValues(alpha: 0.88)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextAwareHeaderActions({
    required bool isDark,
    required String addressLabel,
  }) {
    final chips = <Widget>[];

    if (_isEditingAddress) {
      chips.add(
        _buildHeaderQuickActionChip(
          isDark: isDark,
          icon: Icons.arrow_forward_rounded,
          label: 'Go',
          primary: true,
          onTap: () async => _submitAddressBar(_addressController.text),
        ),
      );
      chips.add(
        _buildHeaderQuickActionChip(
          isDark: isDark,
          icon: Icons.close_rounded,
          label: 'Cancel',
          onTap: _cancelAddressEdit,
        ),
      );

      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }

    if (_showAutofillPrompt && _hasSavedLogin) {
      chips.add(
        _buildHeaderQuickActionChip(
          isDark: isDark,
          icon: Icons.vpn_key_rounded,
          label: 'Autofill',
          primary: true,
          onTap: () async {
            await _autofillSavedLogin();
          },
        ),
      );
    }

    // Smart Sync chip detection
    if (_currentUrl.contains('comsats.edu.pk')) {
      chips.add(
        _buildHeaderQuickActionChip(
          isDark: isDark,
          icon: _isSyncing ? Icons.sync_rounded : Icons.auto_awesome_rounded,
          label: _isSyncing ? 'Syncing...' : 'Deep Sync',
          primary: true,
          onTap: () => _syncPortalTasks(),
        ),
      );
    }

    if (_hasFileUpload) {
      chips.add(
        _buildHeaderQuickActionChip(
          isDark: isDark,
          icon: Icons.cloud_upload_rounded,
          label: 'Upload',
          primary: true,
          onTap: () async {
            await _triggerUploadPicker();
            if (!mounted) return;
            setState(() => _hasFileUpload = false);
          },
        ),
      );
    }

    if (_isOffline) {
      chips.add(
        _buildHeaderQuickActionChip(
          isDark: isDark,
          icon: Icons.wifi_find_rounded,
          label: 'Retry',
          primary: true,
          onTap: () async {
            await _checkConnectivity();
            if (!_isOffline) {
              await _controller.reload();
            }
          },
        ),
      );
    }

    if (_canGoBack) {
      chips.add(
        _buildHeaderQuickActionChip(
          isDark: isDark,
          icon: Icons.arrow_back_rounded,
          label: 'Back',
          onTap: () async {
            await _controller.goBack();
            await _updateNavState();
          },
        ),
      );
    }

    if (_canGoForward) {
      chips.add(
        _buildHeaderQuickActionChip(
          isDark: isDark,
          icon: Icons.arrow_forward_rounded,
          label: 'Forward',
          onTap: () async {
            await _controller.goForward();
            await _updateNavState();
          },
        ),
      );
    }

    chips.add(
      _buildHeaderQuickActionChip(
        isDark: isDark,
        icon: Icons.refresh_rounded,
        label: 'Refresh',
        onTap: () async {
          await _refreshPage();
          await _updateNavState();
        },
      ),
    );

    if (_currentSession.recentDownloads.isNotEmpty) {
      chips.add(
        _buildHeaderQuickActionChip(
          isDark: isDark,
          icon: Icons.download_for_offline_rounded,
          label: 'Downloads',
          onTap: () async => _showDownloadManager(),
        ),
      );
    }

    chips.add(
      _buildHeaderQuickActionChip(
        isDark: isDark,
        icon: Icons.open_in_new_rounded,
        label: 'Browser',
        onTap: () async {
          final uri = Uri.tryParse(addressLabel);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );

    chips.add(
      _buildHeaderQuickActionChip(
        isDark: isDark,
        icon: Icons.edit_rounded,
        label: 'Edit URL',
        onTap: _openAddressBar,
      ),
    );

    chips.add(
      _buildHeaderQuickActionChip(
        isDark: isDark,
        icon: Icons.tune_rounded,
        label: 'More',
        onTap: () => _showHeaderActionSheet(addressLabel: addressLabel),
      ),
    );

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final safeBottom = media.padding.bottom;
    final isTablet = screenSize.shortestSide >= 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addressLabel = addressLabelSafe;
    final compact = screenSize.width < 380;
    final accent = IrisTokens.brand;
    final edgeInset = isTablet ? 18.0 : 10.0;
    final headerInset = isTablet ? 18.0 : 14.0;
    final maxHeaderWidth = math.min(
      screenSize.width - (headerInset * 2),
      isTablet ? 720.0 : 620.0,
    );
    const idleTitle = 'COMSATS PORTAL';
    const fullTitle = 'COMSATS STUDENT PORTAL';
    final idleWidth = ((compact ? 112.0 : 126.0) + (idleTitle.length * 5.0))
        .clamp(compact ? 208.0 : 236.0, maxHeaderWidth);
    final popupText = (_pillMessage ?? widget.title)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final popupWidth =
        ((compact ? 118.0 : 138.0) +
                (popupText.length * 5.6) +
                (_pillActionLabel != null ? 44.0 : 0.0))
            .clamp(compact ? 244.0 : 280.0, maxHeaderWidth);
    final collapsedHeaderWidth = math.min(
      maxHeaderWidth,
      _pillActive ? popupWidth : idleWidth,
    );
    final targetHeaderWidth = _isHeaderCollapsed
        ? collapsedHeaderWidth
        : maxHeaderWidth;
    final bottomRailBottom = 6.0 + (safeBottom * 0.18);
    final enclosureBottomInset = (isTablet ? 18.0 : 14.0) + (safeBottom * 0.12);
    final headerToggleIcon = _isHeaderCollapsed
        ? Icons.unfold_more_rounded
        : Icons.unfold_less_rounded;
    final headerToggleLabel = _isHeaderCollapsed
        ? 'Expand header controls'
        : 'Collapse header controls';
    final panelBackground = isDark
        ? const Color(0xFF151D2C).withValues(alpha: 0.94)
        : const Color(0xFFFFFBF4).withValues(alpha: 0.92);
    final panelText = isDark ? Colors.white : const Color(0xFF3A2A1A);
    final panelMuted = panelText.withValues(alpha: isDark ? 0.78 : 0.72);
    final enclosureRadius = BorderRadius.circular(isTablet ? 24 : 20);
    final enclosureStroke = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.16 : 0.12,
    );
    final innerStroke = (isDark ? Colors.white : accent).withValues(
      alpha: isDark ? 0.07 : 0.10,
    );
    final topEdgeHighlight = (isDark ? Colors.white : accent).withValues(
      alpha: isDark ? 0.10 : 0.14,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
            SafeArea(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          edgeInset,
                          6,
                          edgeInset,
                          enclosureBottomInset,
                        ),
                        child: ClipRRect(
                          borderRadius: enclosureRadius,
                          child: Container(
                            decoration: BoxDecoration(
                              color: panelBackground,
                              borderRadius: enclosureRadius,
                              border: Border.all(
                                color: enclosureStroke,
                                width: 1.25,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isDark
                                              ? Colors.black
                                              : const Color(0xFF8A5E2D))
                                          .withValues(
                                            alpha: isDark ? 0.44 : 0.24,
                                          ),
                                  blurRadius: 22,
                                  spreadRadius: -8,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: WebViewWidget(
                                      controller: _controller,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 12,
                                  top: 12,
                                  child: Opacity(
                                    opacity: 0.92,
                                    child: GestureDetector(
                                      onTap: () async {
                                        try {
                                          debugPrint('Manual: triggering headless script from PortalScreen');
                                          await _controller.runJavaScript(HeadlessPortalSync.syncPortalScript);
                                          await _showMessage('Manual scraper triggered');
                                        } catch (e) {
                                          debugPrint('Manual scraper error: $e');
                                          await _showMessage('Scraper run failed');
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: accent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.18),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.bug_report,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: enclosureRadius,
                                        border: Border.all(
                                          color: innerStroke,
                                          width: 0.85,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      height: 26,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(
                                            isTablet ? 24 : 20,
                                          ),
                                          topRight: Radius.circular(
                                            isTablet ? 24 : 20,
                                          ),
                                        ),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            topEdgeHighlight,
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: edgeInset,
                                  right: edgeInset,
                                  bottom: bottomRailBottom,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [const SizedBox.shrink()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 10,
                      child: Center(
                        child: GestureDetector(
                          onTapDown: (_) => setState(() => _isPillPressed = true),
                          onTapUp: (_) {
                            setState(() => _isPillPressed = false);
                            if (_pillActive && _pillAction != null) {
                              _pillAction!();
                            } else {
                              _toggleHeaderCollapsed();
                            }
                          },
                          onTapCancel: () => setState(() => _isPillPressed = false),
                          child: AnimatedScale(
                            scale: _isPillPressed ? 0.96 : 1.0,
                            duration: const Duration(milliseconds: 160),
                            curve: _isPillPressed ? IrisMotion.emphasized : IrisMotion.spring,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: _isHeaderCollapsed ? 0.0 : 1.0,
                                end: _isHeaderCollapsed ? 0.0 : 1.0,
                              ),
                              duration: const Duration(milliseconds: 380),
                              curve: IrisMotion.fluid,
                              builder: (context, expansion, child) {
                                final currentWidth = collapsedHeaderWidth + (maxHeaderWidth - collapsedHeaderWidth) * expansion;
                                final currentRadius = 999.0 + (22.0 - 999.0) * expansion;
                                final currentVPadding = 8.0 + (10.0 - 8.0) * expansion;
                                final currentHPadding = 12.0 + (14.0 - 12.0) * expansion;
                                
                                return SizedBox(
                                  width: currentWidth,
                                  child: GlassSurface(
                                    settings: LiquidGlassSettings(
                                      blur: 16,
                                      ambientStrength: 0.65,
                                      lightAngle: 0.15 * math.pi,
                                      glassColor: (isDark ? IrisTokens.surfaceDarkElevated : Colors.white)
                                          .withValues(alpha: isDark ? 0.42 : 0.45),
                                      thickness: 20,
                                    ),
                                    radius: currentRadius,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: currentVPadding,
                                          horizontal: currentHPadding,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(currentRadius),
                                          border: Border.all(
                                            color: (isDark ? Colors.white : accent)
                                                .withValues(alpha: isDark ? 0.14 : 0.18),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isDark ? Colors.black : accent).withValues(alpha: isDark ? 0.35 : 0.12),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                              spreadRadius: -6,
                                            ),
                                            if (_pillActive)
                                              BoxShadow(
                                                color: _pillTone.withValues(alpha: 0.25),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                              ),
                                          ],
                                        ),
                                        child: child,
                                      ),
                                    ),
                                  ),
                                );
                              },
                                    child: AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 320,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      alignment: Alignment.topCenter,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              if (_pillActive)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    right: 8,
                                                  ),
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: _pillTone.withValues(
                                                      alpha: 0.14,
                                                    ),
                                                    border: Border.all(
                                                      color: _pillTone
                                                          .withValues(
                                                            alpha: 0.32,
                                                          ),
                                                      width: 0.9,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    _pillIcon ??
                                                        Icons
                                                            .notifications_none_rounded,
                                                    size: 14,
                                                    color: _pillTone,
                                                  ),
                                                ),
                                              Expanded(
                                                child: AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 180,
                                                  ),
                                                  switchInCurve:
                                                      Curves.easeOutCubic,
                                                  switchOutCurve:
                                                      Curves.easeInCubic,
                                                  child: Text(
                                                    _pillActive
                                                        ? (_pillMessage ??
                                                              widget.title)
                                                        : (_isHeaderCollapsed
                                                              ? idleTitle
                                                              : fullTitle),
                                                    key: ValueKey<String>(
                                                      _pillActive
                                                          ? (_pillMessage ??
                                                                'portal-message')
                                                          : (_isHeaderCollapsed
                                                                ? 'portal-title-idle'
                                                                : 'portal-title-full'),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 0.22,
                                                      color: panelText,
                                                      decoration:
                                                          TextDecoration.none,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (_pillActive &&
                                                  _pillActionLabel != null)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    left: 8,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (isDark
                                                                ? Colors.white
                                                                : accent)
                                                            .withValues(
                                                              alpha: isDark
                                                                  ? 0.12
                                                                  : 0.16,
                                                            ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          (isDark
                                                                  ? Colors.white
                                                                  : accent)
                                                              .withValues(
                                                                alpha: isDark
                                                                    ? 0.18
                                                                    : 0.28,
                                                              ),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _pillActionLabel!,
                                                    style: TextStyle(
                                                      color: panelText,
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 0.14,
                                                      decoration:
                                                          TextDecoration.none,
                                                    ),
                                                  ),
                                                ),
                                              if (!_pillActive &&
                                                  _showAutofillPrompt &&
                                                  _hasSavedLogin)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 8,
                                                      ),
                                                  child: _buildHeaderQuickActionChip(
                                                    isDark: isDark,
                                                    icon: Icons.vpn_key_rounded,
                                                    label: 'Autofill',
                                                    primary: true,
                                                    onTap: () async {
                                                      await _autofillSavedLogin();
                                                    },
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    AnimatedOpacity(
                                                      duration: const Duration(
                                                        milliseconds: 220,
                                                      ),
                                                      curve:
                                                          Curves.easeOutCubic,
                                                      opacity:
                                                          (_isLoading ||
                                                              _isDownloading ||
                                                              _isPullRefreshing)
                                                          ? 1
                                                          : 0,
                                                      child: AnimatedScale(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 220,
                                                            ),
                                                        curve:
                                                            Curves.easeOutCubic,
                                                        scale:
                                                            (_isLoading ||
                                                                _isDownloading ||
                                                                _isPullRefreshing)
                                                            ? 1
                                                            : 0.7,
                                                        child: SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2.2,
                                                            color:
                                                                _isDownloading
                                                                ? const Color(
                                                                    0xFF22D3EE,
                                                                  )
                                                                : accent,
                                                            value:
                                                                _isDownloading
                                                                ? (_downloadProgress >=
                                                                          0
                                                                      ? _downloadProgress.clamp(
                                                                          0.0,
                                                                          1.0,
                                                                        )
                                                                      : null)
                                                                : (_isPullRefreshing
                                                                      ? null
                                                                      : (_isLoading
                                                                            ? (_progress /
                                                                                      100)
                                                                                  .clamp(
                                                                                    0.05,
                                                                                    0.98,
                                                                                  )
                                                                            : null)),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    AnimatedOpacity(
                                                      duration: const Duration(
                                                        milliseconds: 220,
                                                      ),
                                                      curve:
                                                          Curves.easeOutCubic,
                                                      opacity:
                                                          (_isLoading ||
                                                              _isDownloading ||
                                                              _isPullRefreshing)
                                                          ? 0
                                                          : 1,
                                                      child: AnimatedScale(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 220,
                                                            ),
                                                        curve:
                                                            Curves.easeOutCubic,
                                                        scale:
                                                            (_isLoading ||
                                                                _isDownloading ||
                                                                _isPullRefreshing)
                                                            ? 0.7
                                                            : 1,
                                                        child: Icon(
                                                          headerToggleIcon,
                                                          size: 20,
                                                          color: panelText
                                                              .withValues(
                                                                alpha: 0.92,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 260,
                                            ),
                                            switchInCurve: Curves.easeOutQuart,
                                            switchOutCurve: Curves.easeOutQuart,
                                            transitionBuilder:
                                                (child, animation) {
                                                  final size = CurvedAnimation(
                                                    parent: animation,
                                                    curve: Curves.easeOutQuart,
                                                  );
                                                  return FadeTransition(
                                                    opacity: animation,
                                                    child: SizeTransition(
                                                      sizeFactor: size,
                                                      axisAlignment: -1,
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                            child:
                                                _isHeaderCollapsed ||
                                                    _pillActive
                                                ? const SizedBox.shrink(
                                                    key: ValueKey(
                                                      'header-collapsed',
                                                    ),
                                                  )
                                                : Column(
                                                    key: const ValueKey(
                                                      'header-expanded',
                                                    ),
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const SizedBox(height: 8),
                                                      Container(
                                                        height: 1,
                                                        color:
                                                            (isDark
                                                                    ? Colors
                                                                          .white
                                                                    : Colors
                                                                          .black)
                                                                .withValues(
                                                                  alpha: 0.10,
                                                                ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          if (widget
                                                              .showBackButton)
                                                            Container(
                                                              decoration: BoxDecoration(
                                                                color: accent
                                                                    .withValues(
                                                                      alpha:
                                                                          isDark
                                                                          ? 0.22
                                                                          : 0.14,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                              child: IconButton(
                                                                tooltip:
                                                                    'Back to app',
                                                                icon: const Icon(
                                                                  Icons
                                                                      .arrow_back_rounded,
                                                                ),
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                    ),
                                                              ),
                                                            ),
                                                          Expanded(
                                                            child: Text(
                                                              'Quick Controls',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontSize: 14,
                                                                color:
                                                                    panelText,
                                                                decoration:
                                                                    TextDecoration
                                                                        .none,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                          if (_hasSavedLogin)
                                                            Container(
                                                              margin:
                                                                  const EdgeInsets.only(
                                                                    right: 8,
                                                                  ),
                                                              width: 9,
                                                              height: 9,
                                                              decoration:
                                                                  BoxDecoration(
                                                                    color: IrisTokens.success,
                                                                    shape: BoxShape.circle,
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: IrisTokens.success.withValues(alpha: 0.4),
                                                                        blurRadius: 4,
                                                                      ),
                                                                    ],
                                                                  ),
                                                            ),
                                                          if (_isOffline)
                                                            Container(
                                                              margin:
                                                                  const EdgeInsets.only(
                                                                    right: 8,
                                                                  ),
                                                              width: 9,
                                                              height: 9,
                                                              decoration:
                                                                  const BoxDecoration(
                                                                    color: Color(
                                                                      0xFFEF4444,
                                                                    ),
                                                                    shape: BoxShape
                                                                        .circle,
                                                                  ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildContextAwareHeaderActions(
                                                        isDark: isDark,
                                                        addressLabel:
                                                            addressLabel,
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical: 8,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: (isDark ? Colors.white : Colors.black).withValues(
                                                                  alpha: 0.08,
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      IrisTokens.radius16,
                                                                    ),
                                                                border: Border.all(
                                                                  color: (isDark ? Colors.white : accent).withValues(
                                                                        alpha: 0.12,
                                                                      ),
                                                                ),
                                                              ),
                                                              child:
                                                                  _isEditingAddress
                                                                  ? Row(
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .link_rounded,
                                                                          size:
                                                                              15,
                                                                          color:
                                                                              panelMuted,
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              8,
                                                                        ),
                                                                        Expanded(
                                                                          child: TextField(
                                                                            controller:
                                                                                _addressController,
                                                                            autofocus:
                                                                                true,
                                                                            keyboardType:
                                                                                TextInputType.url,
                                                                            style: TextStyle(
                                                                              fontSize: 12,
                                                                              color: panelText.withValues(
                                                                                alpha: 0.96,
                                                                              ),
                                                                            ),
                                                                            decoration: InputDecoration(
                                                                              isDense: true,
                                                                              border: InputBorder.none,
                                                                              hintText: 'https://example.com',
                                                                              hintStyle: TextStyle(
                                                                                color: panelMuted.withValues(
                                                                                  alpha: 0.74,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            textInputAction:
                                                                                TextInputAction.go,
                                                                            onSubmitted:
                                                                                _submitAddressBar,
                                                                          ),
                                                                        ),
                                                                        GestureDetector(
                                                                          onTap: () => _submitAddressBar(
                                                                            _addressController.text,
                                                                          ),
                                                                          child: Icon(
                                                                            Icons.arrow_forward_rounded,
                                                                            size:
                                                                                16,
                                                                            color: accent.withValues(
                                                                              alpha: 0.92,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    )
                                                                  : InkWell(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            16,
                                                                          ),
                                                                      onTap:
                                                                          _openAddressBar,
                                                                      child: Row(
                                                                        children: [
                                                                          Icon(
                                                                            addressLabel.startsWith(
                                                                                  'https://',
                                                                                )
                                                                                ? Icons.lock_outline_rounded
                                                                                : Icons.public_rounded,
                                                                            size:
                                                                                15,
                                                                            color:
                                                                                panelMuted,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                8,
                                                                          ),
                                                                          Expanded(
                                                                            child: Text(
                                                                              addressLabel,
                                                                              maxLines: 1,
                                                                              overflow: TextOverflow.ellipsis,
                                                                              style: TextStyle(
                                                                                fontSize: 12,
                                                                                color: panelText.withValues(
                                                                                  alpha: 0.95,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          Icon(
                                                                            Icons.edit_rounded,
                                                                            size:
                                                                                15,
                                                                            color: panelMuted.withValues(
                                                                              alpha: 0.70,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                          ), // AnimatedSwitcher
                                        ], // Column children
                                      ), // Column
                                    ), // AnimatedSize
                                  ), // TweenAnimationBuilder
                                ), // AnimatedScale
                              ), // GestureDetector
                            ), // Center
                          ), // Positioned
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Semantics(
                              label: headerToggleLabel,
                              child: const SizedBox(width: 0, height: 0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }
}
