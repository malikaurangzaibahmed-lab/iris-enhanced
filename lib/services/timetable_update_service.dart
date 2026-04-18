import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:iris/core/models.dart';
import 'package:iris/services/pdf_timetable_parser.dart';

class TimetableUpdateService {
  static const String serverEndpoint = '';
  static const Duration serverTimeout = Duration(seconds: 30);
  static const int minOnDeviceSessions = 3;

  static Future<List<ClassSession>> parseWithFallback({
    required File pdfFile,
    required String currentBatch,
  }) async {
    final onDevice = await PDFTimetableParser.parsePDFTimetable(
      pdfFile,
      currentBatch: currentBatch,
    );

    if (onDevice.length >= minOnDeviceSessions) {
      return onDevice;
    }

    if (serverEndpoint.isEmpty) {
      if (onDevice.isNotEmpty) {
        return onDevice;
      }
      throw Exception('Server parsing not configured');
    }

    return _parseWithServer(
      pdfFile: pdfFile,
      currentBatch: currentBatch,
    );
  }

  static Future<List<ClassSession>> _parseWithServer({
    required File pdfFile,
    required String currentBatch,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(serverEndpoint));
    request.files.add(await http.MultipartFile.fromPath('file', pdfFile.path));
    request.fields['batch'] = currentBatch;

    final streamed = await request.send().timeout(serverTimeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server parsing failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final sessionsJson = decoded is Map<String, dynamic>
        ? (decoded['sessions'] as List<dynamic>? ?? [])
        : (decoded as List<dynamic>);

    return sessionsJson
        .whereType<Map<String, dynamic>>()
        .map((item) => _normalizeServerSession(item, currentBatch))
        .map((item) => ClassSession.fromJson(item))
        .toList();
  }

  static Map<String, dynamic> _normalizeServerSession(
    Map<String, dynamic> item,
    String currentBatch,
  ) {
    if (item['batch'] == null || (item['batch'] as String).isEmpty) {
      return {
        ...item,
        'batch': currentBatch,
      };
    }
    return item;
  }
}
