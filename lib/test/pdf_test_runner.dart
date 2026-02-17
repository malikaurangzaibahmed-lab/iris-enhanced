/// Console-based PDF parser test runner
/// Run with: dart run lib/test/pdf_test_runner.dart
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  print('🔍 PDF Parser Test Runner\n');

  final pdfFiles = [
    ('assets/ME (9).pdf', 'ME-2022'),
    ('assets/CVE.pdf', 'CVE-2022'),
    ('assets/EE (4).pdf', 'EE-2022'),
  ];

  for (final (path, _) in pdfFiles) {
    print('📄 Testing: $path');
    print('-' * 80);

    final file = File(path);
    if (!file.existsSync()) {
      print('❌ File not found: $path\n');
      continue;
    }

    try {
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();

      print('✅ Text extracted: ${text.length} characters');
      
      // Count lines
      final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
      print('   Lines found: ${lines.length}');
      
      // Find day mentions
      final dayMatches = RegExp(
        r'\b(Mon|Monday|Tue|Tuesday|Wed|Wednesday|Thu|Thursday|Fri|Friday|Sat|Saturday|Sun|Sunday)\b',
        caseSensitive: false,
      ).allMatches(text);
      print('   Day mentions: ${dayMatches.length}');

      // Find time patterns
      final timeMatches = RegExp(
        r'\d{1,2}(?:[:.]?\d{2})?\s*-\s*\d{1,2}(?:[:.]?\d{2})?',
      ).allMatches(text);
      print('   Time patterns found: ${timeMatches.length}');

      // Show first 10 lines
      print('\n   First 10 lines:');
      for (int i = 0; i < (lines.length > 10 ? 10 : lines.length); i++) {
        print('   [${i + 1}] ${lines[i].substring(0, (lines[i].length > 70 ? 70 : lines[i].length))}...');
      }

      print('\n');
    } catch (e) {
      print('❌ Error: $e\n');
    }
  }
}
