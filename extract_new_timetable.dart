import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  final pdfFile = File('assets/CS (1).pdf');
  
  if (!pdfFile.existsSync()) {
    print('❌ PDF file not found: ${pdfFile.path}');
    exit(1);
  }

  try {
    final bytes = await pdfFile.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();

    print('✅ PDF extracted: ${text.length} characters');
    print('\n=== First 2000 characters ===\n');
    print(text.substring(0, min(2000, text.length)));
    print('\n=== End of text ===\n');

    // Try to parse sessions - basic parsing, look for patterns
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    print('\nTotal lines: ${lines.length}');
    
    // Print some sample lines to understand structure
    print('\n=== Sample lines (1-20) ===');
    for (int i = 0; i < min(20, lines.length); i++) {
      print('Line $i: "${lines[i]}"');
    }

  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}

int min(int a, int b) => a < b ? a : b;
