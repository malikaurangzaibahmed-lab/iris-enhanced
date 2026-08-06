import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../core/tokens.dart';
import '../services/ui_feedback.dart';

class UpdateReleaseInfo {
  final String tagName;
  final String releaseNotes;
  final String downloadUrl;
  final int fileSize;

  UpdateReleaseInfo({
    required this.tagName,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.fileSize,
  });
}

class UpdateService {
  static const String githubApiUrl =
      'https://api.github.com/repos/malikaurangzaibahmed-lab/iris-enhanced/releases/latest';

  static Future<UpdateReleaseInfo?> checkLatestRelease(String currentVersion) async {
    try {
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'User-Agent': 'IRIS-App/1.0'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tag = data['tag_name'] as String? ?? '';
        final body = data['body'] as String? ?? 'Bug fixes & performance improvements';
        final assets = data['assets'] as List<dynamic>? ?? [];

        String downloadUrl = '';
        int fileSize = 0;

        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String? ?? '';
            fileSize = asset['size'] as int? ?? 0;
            break;
          }
        }

        if (tag.isNotEmpty && downloadUrl.isNotEmpty && _isNewerVersion(currentVersion, tag)) {
          return UpdateReleaseInfo(
            tagName: tag,
            releaseNotes: body,
            downloadUrl: downloadUrl,
            fileSize: fileSize,
          );
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
    return null;
  }

  static bool _isNewerVersion(String current, String latest) {
    try {
      final curClean = current.replaceAll('v', '').split('+').first.trim();
      final latClean = latest.replaceAll('v', '').split('+').first.trim();

      final curParts = curClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latParts = latClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < curParts.length ? curParts[i] : 0;
        final l = i < latParts.length ? latParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      debugPrint('Version parse error: $e');
    }
    return false;
  }

  static void showUpdateModal(BuildContext context, UpdateReleaseInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDialogContent(info: info),
    );
  }
}

class _UpdateDialogContent extends StatefulWidget {
  final UpdateReleaseInfo info;
  const _UpdateDialogContent({required this.info});

  @override
  State<_UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = 'A new version of IRIS is ready!';

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusMessage = 'Connecting to download server...';
    });

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/iris_update_${widget.info.tagName}.apk');
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }

      final ioClient = HttpClient();
      ioClient.autoUncompress = true;
      ioClient.connectionTimeout = const Duration(seconds: 15);

      final req = await ioClient.getUrl(Uri.parse(widget.info.downloadUrl));
      req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Android; Mobile; IRIS-App)');
      req.followRedirects = true;
      req.maxRedirects = 10;

      final resp = await req.close();

      if (resp.statusCode != 200) {
        throw 'Server returned status ${resp.statusCode}';
      }

      final totalBytes = resp.contentLength > 0 ? resp.contentLength : widget.info.fileSize;
      final sink = file.openWrite();
      int downloadedBytes = 0;

      await for (final chunk in resp) {
        downloadedBytes += chunk.length;
        sink.add(chunk);
        if (totalBytes > 0 && mounted) {
          setState(() {
            _progress = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
            _statusMessage = 'Downloading: ${(_progress * 100).toStringAsFixed(1)}%';
          });
        }
      }

      await sink.flush();
      await sink.close();
      ioClient.close();

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusMessage = 'Download complete! Launching package installer...';
        });
      }

      IrisHaptics.actionHeavy();
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.of(context).pop();

      await OpenFilex.open(
        file.path,
        type: "application/vnd.android.package-archive",
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Download interrupted. Tap to retry.';
        });
        showIrisFrostedSnackBar(
          context,
          content: const Text('Download interrupted. Please check network connection and try again.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.white.withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: IrisTokens.brand.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.system_update_rounded, color: IrisTokens.brand, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'IRIS Upgrade Available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Version ${widget.info.tagName}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: IrisTokens.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'What\'s New:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.info.releaseNotes,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_isDownloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(IrisTokens.brand),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.67),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Later',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _startDownloadAndInstall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: IrisTokens.brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Update Now',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
