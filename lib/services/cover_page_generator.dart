import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart';

class CoverPageField {
  String label;
  String value;

  CoverPageField(this.label, this.value);
}

class CoverPageData {
  final String docType; // 'Assignment', 'Lab Report', 'Project Report', 'Quiz Prep'
  final String courseTitle;
  final String courseCode;
  final String docTitle;
  final String studentName;
  final String registrationId;
  final String batch;
  final String instructorName;
  final String department;
  final String campus;
  final String submissionDate;
  List<CoverPageField> customFields;

  CoverPageData({
    required this.docType,
    required this.courseTitle,
    required this.courseCode,
    required this.docTitle,
    required this.studentName,
    required this.registrationId,
    required this.batch,
    required this.instructorName,
    required this.department,
    required this.campus,
    required this.submissionDate,
    this.customFields = const [],
  });

  static Future<CoverPageData> resolveDefaults({
    String? course,
    String? title,
    String? teacher,
    String? type,
    List<CoverPageField>? fields,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final studentName = prefs.getString('student_user_name')?.trim().isNotEmpty == true
        ? prefs.getString('student_user_name')!.trim()
        : (prefs.getString('faculty_user_name')?.trim().isNotEmpty == true
            ? prefs.getString('faculty_user_name')!.trim()
            : 'Student Profile');

    final rawBatch = prefs.getString('student_batch') ?? prefs.getString('user_batch') ?? prefs.getString('current_batch') ?? 'SP22-BSE-B';
    final savedRoll = prefs.getString('student_roll_no') ?? prefs.getString('roll_no') ?? '042';

    final key = BatchKey.parse(rawBatch);
    final term = key.intake.isNotEmpty ? key.intake : 'SP22';
    final program = key.program.isNotEmpty ? key.program : 'BSE';
    final rollFormatted = savedRoll.padLeft(3, '0');
    final formattedRegId = '$term-$program-$rollFormatted';

    final dateStr = DateTime.now().toLocal().toString().substring(0, 10);

    return CoverPageData(
      docType: type ?? 'Assignment',
      courseTitle: course ?? 'Object Oriented Programming',
      courseCode: 'CSC-211',
      docTitle: title ?? 'Assignment 1',
      studentName: studentName,
      registrationId: formattedRegId,
      batch: rawBatch,
      instructorName: teacher ?? 'Dr. Wasim',
      department: 'Department of Computer Science',
      campus: 'COMSATS University Islamabad, Sahiwal Campus',
      submissionDate: dateStr,
      customFields: fields ?? [],
    );
  }
}

class CoverPageGenerator {
  static Future<File> generateOfficialCoverPdf(CoverPageData data) async {
    final document = PdfDocument();
    document.pageSettings.margins.all = 36.0; // Standard 0.5 in margins
    document.pageSettings.size = PdfPageSize.a4; // Standard A4 (595.28 x 841.89 pt)

    await drawCoverPageOnDocument(document, data);

    // Save File
    final bytes = await document.save();
    document.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final safeReg = data.registrationId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final fileName = 'Official_CoverPage_${safeReg}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    return file;
  }

  static Future<PdfPage> drawCoverPageOnDocument(PdfDocument document, CoverPageData data) async {
    final page = document.pages.add();
    final graphics = page.graphics;
    final pageSize = page.getClientSize();

    // Color Palette
    final navyColor = PdfColor(15, 23, 42); // #0F172A
    final brandBlue = PdfColor(29, 78, 216); // #1D4ED8
    final borderPen = PdfPen(navyColor, width: 2.0);
    final innerBorderPen = PdfPen(brandBlue, width: 0.8);

    // 1. Draw Double Outer Frame Border (A4 Bound)
    graphics.drawRectangle(pen: borderPen, bounds: Rect.fromLTWH(0, 0, pageSize.width, pageSize.height));
    graphics.drawRectangle(
      pen: innerBorderPen,
      bounds: Rect.fromLTWH(4, 4, pageSize.width - 8, pageSize.height - 8),
    );

    // Typography
    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 17, style: PdfFontStyle.bold);
    final subHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold);
    final sectionFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final boldBodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);

    double currentY = 28.0;

    // 2. Official COMSATS Logo Image & Crest Banner
    try {
      final logoBytes = await rootBundle.load('assets/comsats_logo.png');
      final logoBitmap = PdfBitmap(logoBytes.buffer.asUint8List());
      graphics.drawImage(logoBitmap, Rect.fromLTWH((pageSize.width - 70) / 2, currentY, 70, 70));
      currentY += 78;
    } catch (_) {
      try {
        final logoBytes = await rootBundle.load('assets/comsats_logo.jpg');
        final logoBitmap = PdfBitmap(logoBytes.buffer.asUint8List());
        graphics.drawImage(logoBitmap, Rect.fromLTWH((pageSize.width - 65) / 2, currentY, 65, 65));
        currentY += 72;
      } catch (_) {
        // Draw Vector Emblem Badge
        graphics.drawEllipse(
          Rect.fromLTWH((pageSize.width - 50) / 2, currentY, 50, 50),
          pen: PdfPen(brandBlue, width: 2.0),
          brush: PdfSolidBrush(PdfColor(241, 245, 249)),
        );
        currentY += 56;
      }
    }

    final headerFormat = PdfStringFormat(alignment: PdfTextAlignment.center);
    
    graphics.drawString('COMSATS UNIVERSITY ISLAMABAD', headerFont,
        brush: PdfSolidBrush(navyColor), bounds: Rect.fromLTWH(0, currentY, pageSize.width, 24), format: headerFormat);
    currentY += 24;

    graphics.drawString(data.campus.toUpperCase(), subHeaderFont,
        brush: PdfSolidBrush(brandBlue), bounds: Rect.fromLTWH(0, currentY, pageSize.width, 18), format: headerFormat);
    currentY += 20;

    graphics.drawString(data.department.toUpperCase(), subHeaderFont,
        brush: PdfSolidBrush(navyColor), bounds: Rect.fromLTWH(0, currentY, pageSize.width, 18), format: headerFormat);
    currentY += 28;

    // Horizontal Divider Rule
    graphics.drawLine(PdfPen(brandBlue, width: 1.5), Offset(36, currentY), Offset(pageSize.width - 36, currentY));
    currentY += 40;

    // 3. Document Type & Title Box
    graphics.drawString(data.docType.toUpperCase(), sectionFont,
        brush: PdfSolidBrush(brandBlue), bounds: Rect.fromLTWH(0, currentY, pageSize.width, 18), format: headerFormat);
    currentY += 22;

    graphics.drawString(data.docTitle, titleFont,
        brush: PdfSolidBrush(navyColor), bounds: Rect.fromLTWH(0, currentY, pageSize.width, 32), format: headerFormat);
    currentY += 48;

    // 4. Course Title Header Card Frame
    final courseCardBounds = Rect.fromLTWH(36, currentY, pageSize.width - 72, 54);
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(241, 245, 249)),
      pen: PdfPen(PdfColor(203, 213, 225), width: 1.2),
      bounds: courseCardBounds,
    );

    final courseFormat = PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle);
    graphics.drawString(
      'COURSE: ${data.courseTitle.toUpperCase()}',
      boldBodyFont,
      brush: PdfSolidBrush(navyColor),
      bounds: courseCardBounds,
      format: courseFormat,
    );
    currentY += 76;

    // 5. Clean Metadata Table for Student & Submission Data
    final grid = PdfGrid();
    grid.columns.add(count: 2);
    grid.columns[0].width = (pageSize.width - 72) * 0.38;
    grid.columns[1].width = (pageSize.width - 72) * 0.62;

    void addGridRow(String label, String value) {
      final row = grid.rows.add();
      row.cells[0].value = label;
      row.cells[0].style.font = boldBodyFont;
      row.cells[0].stringFormat = PdfStringFormat(alignment: PdfTextAlignment.left, lineAlignment: PdfVerticalAlignment.middle);
      row.cells[0].style.cellPadding = PdfPaddings(left: 12, right: 8, top: 10, bottom: 10);

      row.cells[1].value = value;
      row.cells[1].style.font = bodyFont;
      row.cells[1].stringFormat = PdfStringFormat(alignment: PdfTextAlignment.left, lineAlignment: PdfVerticalAlignment.middle);
      row.cells[1].style.cellPadding = PdfPaddings(left: 12, right: 8, top: 10, bottom: 10);
    }

    final fieldsToDraw = data.customFields.isNotEmpty
        ? data.customFields
        : [
            CoverPageField('Student Name:', data.studentName),
            CoverPageField('Registration ID:', data.registrationId),
            CoverPageField('Program & Batch:', data.batch),
            CoverPageField('Submitted To:', data.instructorName),
            CoverPageField('Submission Date:', data.submissionDate),
          ];

    for (final field in fieldsToDraw) {
      final formattedLabel = field.label.trim().endsWith(':') ? field.label.trim() : '${field.label.trim()}:';
      addGridRow(formattedLabel, field.value.trim());
    }

    grid.draw(page: page, bounds: Rect.fromLTWH(36, currentY, pageSize.width - 72, 0));
    return page;
  }
}

class RichMarkdownPdfRenderer {
  /// Strips duplicate cover page headers from the document body text
  static String stripHeaderMetadata(String text, {String docTitle = ''}) {
    final lines = text.split('\n');
    int startIdx = 0;
    final lowerTitle = docTitle.trim().toLowerCase();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final cleanHeading = line.replaceAll('#', '').replaceAll('*', '').trim().toLowerCase();

      if (line.startsWith('---') || line.startsWith('***')) {
        startIdx = i + 1;
        break;
      }

      if (cleanHeading.isEmpty ||
          cleanHeading.startsWith('cui') ||
          cleanHeading.startsWith('comsats') ||
          cleanHeading.startsWith('department') ||
          cleanHeading == 'assignment' ||
          cleanHeading == 'quiz prep' ||
          cleanHeading == 'project report' ||
          (lowerTitle.isNotEmpty && (cleanHeading == lowerTitle || cleanHeading.contains(lowerTitle))) ||
          cleanHeading.startsWith('course:') ||
          cleanHeading.startsWith('title:') ||
          cleanHeading.startsWith('author:') ||
          cleanHeading.startsWith('student:') ||
          cleanHeading.startsWith('date:')) {
        startIdx = i + 1;
        continue;
      }
      break;
    }
    return lines.sublist(startIdx).join('\n').trim();
  }

  /// Removes raw image markdown tags because images are rendered as vector figure pages
  static String cleanMarkdownTags(String text) {
    return text.replaceAll(RegExp(r'!\[Image Attachment:[^\]]*\]\([^\)]*\)'), '').trim();
  }

  /// Renders rich formatted Markdown text onto Syncfusion PdfDocument pages
  static void renderMarkdownToDocument({
    required PdfDocument document,
    required String markdownText,
    required bool hasCoverPage,
    String docTitle = '',
  }) {
    String cleanText = cleanMarkdownTags(markdownText);
    if (hasCoverPage) {
      cleanText = stripHeaderMetadata(cleanText, docTitle: docTitle);
    }

    if (cleanText.isEmpty) return;

    PdfPage page = document.pages.add();
    final double margin = 36.0;
    final double pageWidth = page.getClientSize().width;
    final double pageHeight = page.getClientSize().height;

    // Palette & Fonts
    final navyColor = PdfColor(15, 23, 42);
    final brandBlue = PdfColor(29, 78, 216);
    final darkSlate = PdfColor(51, 65, 85);
    final textDark = PdfColor(15, 23, 42);

    final h1Font = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final h2Font = PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold);
    final h3Font = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final boldFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);

    double currentY = margin;

    PdfPage checkY(double requiredHeight) {
      if (currentY + requiredHeight > pageHeight - margin) {
        page = document.pages.add();
        currentY = margin;
      }
      return page;
    }

    final lines = cleanText.split('\n');
    int i = 0;

    while (i < lines.length) {
      String line = lines[i].trimRight();

      if (line.trim().isEmpty) {
        currentY += 8;
        i++;
        continue;
      }

      // 1. Horizontal Divider
      if (line.trim() == '---' || line.trim() == '***' || line.trim() == '___') {
        checkY(16);
        page.graphics.drawLine(
          PdfPen(PdfColor(203, 213, 225), width: 1.0),
          Offset(margin, currentY + 6),
          Offset(pageWidth - margin, currentY + 6),
        );
        currentY += 16;
        i++;
        continue;
      }

      // 2. Markdown Table Detection (lines starting with |)
      if (line.trim().startsWith('|')) {
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          tableLines.add(lines[i].trim());
          i++;
        }

        if (tableLines.length >= 2) {
          final headers = tableLines[0]
              .split('|')
              .where((s) => s.trim().isNotEmpty)
              .map((s) => _cleanInlineFormatting(s.trim()))
              .toList();

          final dataRows = <List<String>>[];
          for (int r = 1; r < tableLines.length; r++) {
            final rowLine = tableLines[r];
            if (rowLine.contains('---')) continue; // Skip separator line
            final cells = rowLine
                .split('|')
                .where((s) => s.trim().isNotEmpty)
                .map((s) => _cleanInlineFormatting(s.trim()))
                .toList();
            if (cells.isNotEmpty) dataRows.add(cells);
          }

          if (headers.isNotEmpty) {
            final grid = PdfGrid();
            grid.columns.add(count: headers.length);
            for (int c = 0; c < headers.length; c++) {
              grid.columns[c].width = (pageWidth - margin * 2) / headers.length;
            }

            final headerRow = grid.headers.add(1)[0];
            for (int c = 0; c < headers.length && c < headerRow.cells.count; c++) {
              headerRow.cells[c].value = headers[c];
              headerRow.cells[c].style.font = boldFont;
              headerRow.cells[c].style.backgroundBrush = PdfSolidBrush(brandBlue);
              headerRow.cells[c].style.textBrush = PdfSolidBrush(PdfColor(255, 255, 255));
              headerRow.cells[c].style.cellPadding = PdfPaddings(left: 8, right: 8, top: 6, bottom: 6);
            }

            for (final rData in dataRows) {
              final gRow = grid.rows.add();
              for (int c = 0; c < rData.length && c < gRow.cells.count; c++) {
                gRow.cells[c].value = rData[c];
                gRow.cells[c].style.font = bodyFont;
                gRow.cells[c].style.textBrush = PdfSolidBrush(textDark);
                gRow.cells[c].style.cellPadding = PdfPaddings(left: 8, right: 8, top: 6, bottom: 6);
              }
            }

            final gridHeight = (dataRows.length + 1) * 24.0 + 10;
            checkY(gridHeight);
            grid.draw(page: page, bounds: Rect.fromLTWH(margin, currentY, pageWidth - margin * 2, 0));
            currentY += gridHeight + 12;
          }
        }
        continue;
      }

      // 3. Headings (#, ##, ###)
      if (line.trim().startsWith('#')) {
        int level = 0;
        while (level < line.length && line[level] == '#') {
          level++;
        }
        final headingText = _cleanInlineFormatting(line.substring(level).trim());
        
        PdfStandardFont font = h3Font;
        PdfColor color = darkSlate;
        double height = 20;

        if (level == 1) {
          font = h1Font;
          color = navyColor;
          height = 28;
        } else if (level == 2) {
          font = h2Font;
          color = brandBlue;
          height = 24;
        }

        checkY(height + 10);
        page.graphics.drawString(
          headingText,
          font,
          brush: PdfSolidBrush(color),
          bounds: Rect.fromLTWH(margin, currentY, pageWidth - margin * 2, height),
        );
        currentY += height + 6;
        i++;
        continue;
      }

      // 4. Bullet Points (*, -, +)
      if (line.trim().startsWith('* ') || line.trim().startsWith('- ') || line.trim().startsWith('+ ')) {
        final bulletText = _cleanInlineFormatting(line.trim().substring(2));
        checkY(18);
        page.graphics.drawString(
          '•  $bulletText',
          bodyFont,
          brush: PdfSolidBrush(textDark),
          bounds: Rect.fromLTWH(margin + 12, currentY, pageWidth - margin * 2 - 12, 18),
        );
        currentY += 18;
        i++;
        continue;
      }

      // 5. Standard Body Text Line
      final lineAdv = _drawFormattedInlineTextLine(
        page: page,
        text: line,
        startX: margin,
        startY: currentY,
        maxWidth: pageWidth - margin * 2,
        defaultColor: textDark,
      );

      currentY += lineAdv;
      i++;
    }

    // Automatically add vector running headers & Page X of Y footers to all document pages
    addPageHeadersAndFooters(
      document: document,
      documentTitle: 'COMSATS ACADEMIC DOCUMENT',
      hasCoverPage: hasCoverPage,
    );
  }

  /// Adds running headers and vector page numbers (Page X of Y) to document pages
  static void addPageHeadersAndFooters({
    required PdfDocument document,
    required String documentTitle,
    required bool hasCoverPage,
  }) {
    final totalPages = document.pages.count;
    final startPageIdx = hasCoverPage ? 1 : 0;
    final bodyPageCount = hasCoverPage ? totalPages - 1 : totalPages;

    final footerFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.italic);
    final grayBrush = PdfSolidBrush(PdfColor(100, 116, 139));
    final pen = PdfPen(PdfColor(226, 232, 240), width: 0.8);

    for (int i = startPageIdx; i < totalPages; i++) {
      final page = document.pages[i];
      final pageSize = page.getClientSize();
      final bodyPageNum = (i - startPageIdx) + 1;

      // 1. Running Header
      page.graphics.drawString(
        documentTitle.toUpperCase(),
        headerFont,
        brush: grayBrush,
        bounds: Rect.fromLTWH(36, 14, pageSize.width - 72, 14),
      );

      page.graphics.drawString(
        'COMSATS UNIVERSITY',
        headerFont,
        brush: grayBrush,
        bounds: Rect.fromLTWH(36, 14, pageSize.width - 72, 14),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );

      page.graphics.drawLine(pen, const Offset(36, 30), Offset(pageSize.width - 36, 30));

      // 2. Vector Page Number Footer (Page X of Y)
      final footerText = 'Page $bodyPageNum of $bodyPageCount';
      page.graphics.drawLine(pen, Offset(36, pageSize.height - 30), Offset(pageSize.width - 36, pageSize.height - 30));

      page.graphics.drawString(
        footerText,
        footerFont,
        brush: grayBrush,
        bounds: Rect.fromLTWH(0, pageSize.height - 24, pageSize.width, 14),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
    }
  }

  static double _drawFormattedInlineTextLine({
    required PdfPage page,
    required String text,
    required double startX,
    required double startY,
    required double maxWidth,
    required PdfColor defaultColor,
  }) {
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final boldFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final italicFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.italic);
    final boldItalicFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);

    final spanRegex = RegExp(r'(\*\*\*.*?\*\*\*|\*\*.*?\*\*|\*.*?\*|`.*?`|[^\*`]+)');
    final matches = spanRegex.allMatches(text);

    double currentX = startX;
    double currentY = startY;
    final double lineHeight = 16.0;

    for (final match in matches) {
      final token = match.group(0)!;
      PdfStandardFont font = bodyFont;
      String cleanToken = token;

      if (token.startsWith('***') && token.endsWith('***') && token.length >= 6) {
        font = boldItalicFont;
        cleanToken = token.substring(3, token.length - 3);
      } else if (token.startsWith('**') && token.endsWith('**') && token.length >= 4) {
        font = boldFont;
        cleanToken = token.substring(2, token.length - 2);
      } else if (token.startsWith('*') && token.endsWith('*') && token.length >= 2) {
        font = italicFont;
        cleanToken = token.substring(1, token.length - 1);
      } else if (token.startsWith('`') && token.endsWith('`') && token.length >= 2) {
        font = boldFont;
        cleanToken = token.substring(1, token.length - 1);
      }

      final words = cleanToken.split(RegExp(r'(?<=\s)|(?=\s)'));
      for (final word in words) {
        if (word.isEmpty) continue;

        final wordSize = font.measureString(word);
        if (currentX + wordSize.width > startX + maxWidth && currentX > startX) {
          currentX = startX;
          currentY += lineHeight;
        }

        page.graphics.drawString(
          word,
          font,
          brush: PdfSolidBrush(defaultColor),
          bounds: Rect.fromLTWH(currentX, currentY, wordSize.width + 2, wordSize.height + 2),
        );

        currentX += wordSize.width;
      }
    }

    return math.max(18.0, (currentY - startY) + lineHeight);
  }

  static String _cleanInlineFormatting(String text) {
    return text
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'\1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'\1')
        .trim();
  }
}
