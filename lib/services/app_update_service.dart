import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import '../core/tokens.dart';
import '../services/ui_feedback.dart';

/// Seamless In-App APK Downloader and Silent Installer Engine for IRIS.
class AppUpdateService {
  static Future<void> showUpdateDialog(
    BuildContext context, {
    required Map<String, dynamic> updateInfo,
  }) async {
    final versionName = updateInfo['version_name'] ?? '1.0.2';
    final apkUrl = updateInfo['apk_url'] ?? updateInfo['download_url'] ?? '';
    final releaseNotes = updateInfo['release_notes'] ?? 'Performance improvements & feature upgrades.';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (apkUrl.isEmpty) {
      showIrisFrostedSnackBar(context, content: const Text('Update URL not available'));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SeamlessUpdateDialog(
        versionName: versionName,
        apkUrl: apkUrl,
        releaseNotes: releaseNotes,
        isDark: isDark,
      ),
    );
  }
}

class _SeamlessUpdateDialog extends StatefulWidget {
  final String versionName;
  final String apkUrl;
  final String releaseNotes;
  final bool isDark;

  const _SeamlessUpdateDialog({
    required this.versionName,
    required this.apkUrl,
    required this.releaseNotes,
    required this.isDark,
  });

  @override
  State<_SeamlessUpdateDialog> createState() => _SeamlessUpdateDialogState();
}

class _SeamlessUpdateDialogState extends State<_SeamlessUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = 'Ready to update';
  String? _errorMsg;

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = 'Downloading IRIS v${widget.versionName}...';
      _errorMsg = null;
    });

    IrisHaptics.actionMedium();

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/iris_update_${widget.versionName}.apk';
      final file = File(savePath);

      if (await file.exists()) {
        await file.delete();
      }

      final request = http.Request('GET', Uri.parse(widget.apkUrl));
      final response = await http.Client().send(request);

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final sink = file.openWrite();

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (mounted && totalBytes > 0) {
          setState(() {
            _progress = receivedBytes / totalBytes;
            final receivedMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
            final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
            _statusText = 'Downloading: $receivedMb MB / $totalMb MB (${(_progress * 100).toInt()}%)';
          });
        }
      });

      await sink.flush();
      await sink.close();

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _progress = 1.0;
        _statusText = 'Download complete! Opening package installer...';
      });

      IrisHaptics.actionHeavy();
      final result = await OpenFilex.open(savePath, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _errorMsg = 'Installation trigger complete. Target path: $savePath';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMsg = 'Download failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isDark
                    ? [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.05),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.85),
                        Colors.white.withValues(alpha: 0.60),
                      ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.70),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [IrisTokens.brand, IrisTokens.brandLight],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'IRIS v${widget.versionName} Available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Seamless In-App Upgrade Engine',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: IrisTokens.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WHAT\'S NEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.releaseNotes,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_isDownloading) ...[
                  LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                    color: IrisTokens.brand,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                if (_errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMsg!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: IrisTokens.error,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!_isDownloading)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Later'),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isDownloading ? null : _startDownloadAndInstall,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(_isDownloading ? 'Downloading...' : '1-Tap Update'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
