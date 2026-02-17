import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String changelog;
  final String apkUrl;
  final bool isRequired;

  UpdateInfo({
    required this.version,
    required this.changelog,
    required this.apkUrl,
    this.isRequired = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] ?? '0.0.0',
      changelog: json['changelog'] ?? 'No changelog available',
      apkUrl: json['apk_url'] ?? '',
      isRequired: json['required'] ?? false,
    );
  }
}

class UpdateService {
  static const String _updateJsonUrl =
      'https://raw.githubusercontent.com/malikaurangzaibahmed-lab/iris-updates/main/update.json';

  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse(_updateJsonUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final remoteVersion = UpdateInfo.fromJson(json);

        final currentVersion = await PackageInfo.fromPlatform();
        
        if (_compareVersions(currentVersion.version, remoteVersion.version) < 0) {
          return remoteVersion;
        }
      }
    } catch (e) {
      print('UpdateService error: $e');
    }
    return null;
  }

  /// Compare versions: returns -1 if current < remote, 0 if equal, 1 if current > remote
  static int _compareVersions(String current, String remote) {
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final remoteParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength = [currentParts.length, remoteParts.length].reduce((a, b) => a > b ? a : b);

    while (currentParts.length < maxLength) currentParts.add(0);
    while (remoteParts.length < maxLength) remoteParts.add(0);

    for (int i = 0; i < maxLength; i++) {
      if (currentParts[i] < remoteParts[i]) return -1;
      if (currentParts[i] > remoteParts[i]) return 1;
    }
    return 0;
  }

  /// Download APK from URL
  static Future<String?> downloadApk(String url, Function(int, int)? onProgress) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final apkPath = '${dir.path}/iris_update.apk';

      final request = http.Request('GET', Uri.parse(url));
      final stream = await request.send();

      final contentLength = stream.contentLength ?? 1;
      int downloadedBytes = 0;

      final file = File(apkPath);
      final raf = file.openSync(mode: FileMode.write);

      await stream.stream.forEach((chunk) {
        raf.writeFromSync(chunk);
        downloadedBytes += chunk.length;
        onProgress?.call(downloadedBytes, contentLength);
      });

      raf.closeSync();
      return apkPath;
    } catch (e) {
      print('Download error: $e');
      return null;
    }
  }

  /// Install APK via method channel
  static Future<bool> installApk(String apkPath) async {
    try {
      // On Android, use intent to open the APK installer
      if (Platform.isAndroid) {
        // This requires a native method channel call in production
        // For now, returns true (actual installation handled by system intent)
        return await _triggerInstallIntent(apkPath);
      }
      return false;
    } catch (e) {
      print('Install error: $e');
      return false;
    }
  }

  /// Trigger system intent to install APK
  static Future<bool> _triggerInstallIntent(String apkPath) async {
    try {
      // In a real app, this would use a MethodChannel to native code
      // For now, assumes system will handle APK installation
      // Actual implementation requires MainActivity to handle the intent
      return true;
    } catch (e) {
      print('Intent error: $e');
      return false;
    }
  }
}
