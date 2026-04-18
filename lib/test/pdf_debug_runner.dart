import 'dart:io';
import 'package:iris/services/pdf_debug_parser.dart';

/// Test runner for PDF debug parser
/// Run from: dart run lib/test/pdf_debug_runner.dart
void main() async {
  final pdfFiles = [
    ('assets/ME (9).pdf', 'ME'),
    ('assets/CVE.pdf', 'CVE'),
    ('assets/EE (4).pdf', 'EE'),
  ];

  print('🔍 Testing PDF Parser on Actual Files\n');
  print('=' * 80);

  for (final (path, dept) in pdfFiles) {
    final file = File(path);
    if (!file.existsSync()) {
      print('❌ File not found: $path\n');
      continue;
    }

    print('\n📄 Testing: $path');
    print('-' * 80);

    try {
      final result = await PDFDebugParser.parseWithDebug(
        file,
        currentBatch: '$dept-2022',
      );

      if (result == null) {
        print('❌ Parser returned null\n');
        continue;
      }

      print(result.logsAsString());

      print('\n📊 Session Summary:');
      for (final row in result.rows) {
        print('  ${row.toString()}');
      }

      final avg = result.rows.isEmpty
          ? 0
          : result.rows.map((r) => r.confidence).reduce((a, b) => a + b) ~/ result.rows.length;
      print('\n✅ Average Confidence: $avg%');
      print('   Total Sessions: ${result.sessions.length}');
      print('   Fields with "Unknown": ${result.rows.where((r) => r.subject == 'Unknown' || r.teacher == 'Unknown' || r.room == 'TBD').length}');

      print('\n' + '=' * 80);
    } catch (e) {
      print('❌ Error parsing $path: $e\n');
    }
  }
}
