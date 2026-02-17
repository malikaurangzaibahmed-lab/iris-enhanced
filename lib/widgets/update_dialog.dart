import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo update;
  final VoidCallback onDismiss;

  const UpdateDialog({
    required this.update,
    required this.onDismiss,
    Key? key,
  }) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.system_update, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update Available',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Version ${widget.update.version}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Changelog',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.update.changelog,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 16),
              if (_isDownloading) ...[
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(Colors.blue.shade400),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
              Row(
                children: [
                  if (!widget.update.isRequired)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isDownloading ? null : widget.onDismiss,
                        child: const Text('Later'),
                      ),
                    ),
                  if (!widget.update.isRequired) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isDownloading ? null : _handleUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade400,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isDownloading ? 'Downloading...' : 'Update Now'),
                    ),
                  ),
                ],
              ),
              if (widget.update.isRequired)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'This update is required and cannot be skipped.',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    setState(() => _isDownloading = true);

    try {
      final apkPath = await UpdateService.downloadApk(
        widget.update.apkUrl,
        (downloaded, total) {
          setState(() => _downloadProgress = downloaded / total);
        },
      );

      if (apkPath != null && mounted) {
        final installed = await UpdateService.installApk(apkPath);
        if (installed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Update installing...')),
          );
          if (mounted) Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to install update')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }
}
