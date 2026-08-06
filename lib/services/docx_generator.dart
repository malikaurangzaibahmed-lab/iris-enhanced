import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:iris/services/cover_page_generator.dart';

class DocxGenerator {
  static Future<File> generateDocx({
    required String filePath,
    required String markdownBody,
    CoverPageData? coverData,
  }) async {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    final contentTypesBytes = utf8.encode(contentTypesXml);
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesBytes.length, contentTypesBytes));

    // 2. _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    final relsBytes = utf8.encode(relsXml);
    archive.addFile(ArchiveFile('_rels/.rels', relsBytes.length, relsBytes));

    // 3. word/_rels/document.xml.rels
    const docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>''';
    final docRelsBytes = utf8.encode(docRelsXml);
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsBytes.length, docRelsBytes));

    // 4. word/document.xml
    final docXmlContent = _buildDocumentXml(markdownBody: markdownBody, coverData: coverData);
    final docXmlBytes = utf8.encode(docXmlContent);
    archive.addFile(ArchiveFile('word/document.xml', docXmlBytes.length, docXmlBytes));

    // Encode to ZIP Archive
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    final file = File(filePath);
    await file.writeAsBytes(zipBytes);
    return file;
  }

  static String _buildDocumentXml({
    required String markdownBody,
    CoverPageData? coverData,
  }) {
    final sb = StringBuffer();
    sb.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    sb.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n');
    sb.write('<w:body>\n');

    // Cover Page Header (Sahiwal Campus)
    if (coverData != null) {
      // University Title
      sb.write('''<w:p>
        <w:pPr><w:jc w:val="center"/><w:spacing w:after="60"/></w:pPr>
        <w:r><w:rPr><w:b/><w:sz w:val="32"/><w:color w:val="0F172A"/></w:rPr><w:t>COMSATS UNIVERSITY ISLAMABAD</w:t></w:r>
      </w:p>\n''');

      // Campus Title
      sb.write('''<w:p>
        <w:pPr><w:jc w:val="center"/><w:spacing w:after="60"/></w:pPr>
        <w:r><w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="1D4ED8"/></w:rPr><w:t>SAHIWAL CAMPUS</w:t></w:r>
      </w:p>\n''');

      // Department Title
      sb.write('''<w:p>
        <w:pPr><w:jc w:val="center"/><w:spacing w:after="200"/></w:pPr>
        <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="0F172A"/></w:rPr><w:t>${_xmlEscape(coverData.department.toUpperCase())}</w:t></w:r>
      </w:p>\n''');

      // Document Type
      sb.write('''<w:p>
        <w:pPr><w:jc w:val="center"/><w:spacing w:after="120"/></w:pPr>
        <w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="1D4ED8"/></w:rPr><w:t>${_xmlEscape(coverData.docType.toUpperCase())}</w:t></w:r>
      </w:p>\n''');

      // Document Title
      if (coverData.docTitle.isNotEmpty) {
        sb.write('''<w:p>
          <w:pPr><w:jc w:val="center"/><w:spacing w:after="140"/></w:pPr>
          <w:r><w:rPr><w:b/><w:sz w:val="36"/><w:color w:val="0F172A"/></w:rPr><w:t>${_xmlEscape(coverData.docTitle)}</w:t></w:r>
        </w:p>\n''');
      }

      // Course Title
      if (coverData.courseTitle.isNotEmpty) {
        sb.write('''<w:p>
          <w:pPr><w:jc w:val="center"/><w:spacing w:after="240"/></w:pPr>
          <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="0F172A"/></w:rPr><w:t>COURSE: ${_xmlEscape(coverData.courseTitle.toUpperCase())}</w:t></w:r>
        </w:p>\n''');
      }

      // Metadata Table Grid
      if (coverData.customFields.isNotEmpty) {
        sb.write('<w:tbl>\n');
        sb.write('''<w:tblPr>
          <w:tblW w:w="5000" w:type="pct"/>
          <w:tblBorders>
            <w:top w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
            <w:left w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
            <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
            <w:right w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
            <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
            <w:insideV w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
          </w:tblBorders>
        </w:tblPr>\n''');

        for (final field in coverData.customFields) {
          sb.write('<w:tr>\n');
          // Label Column
          sb.write('''<w:tc>
            <w:tcPr><w:tcW w:w="2000" w:type="pct"/></w:tcPr>
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="0F172A"/></w:rPr><w:t>${_xmlEscape(field.label)}</w:t></w:r></w:p>
          </w:tc>\n''');
          // Value Column
          sb.write('''<w:tc>
            <w:tcPr><w:tcW w:w="3000" w:type="pct"/></w:tcPr>
            <w:p><w:r><w:rPr><w:sz w:val="20"/><w:color w:val="334155"/></w:rPr><w:t>${_xmlEscape(field.value)}</w:t></w:r></w:p>
          </w:tc>\n''');
          sb.write('</w:tr>\n');
        }
        sb.write('</w:tbl>\n');
      }

      // Page Break after Cover Page
      sb.write('''<w:p>
        <w:r><w:br w:type="page"/></w:r>
      </w:p>\n''');
    }

    // Markdown Body Translation with Bold / Italics / Code Parsing
    final lines = markdownBody.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        sb.write('<w:p/>\n');
        continue;
      }

      if (trimmed.startsWith('# ')) {
        final headingText = trimmed.substring(2).trim();
        sb.write('''<w:p>
          <w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>
          <w:r><w:rPr><w:b/><w:sz w:val="32"/><w:color w:val="1D4ED8"/></w:rPr><w:t>${_xmlEscape(headingText)}</w:t></w:r>
        </w:p>\n''');
      } else if (trimmed.startsWith('## ')) {
        final headingText = trimmed.substring(3).trim();
        sb.write('''<w:p>
          <w:pPr><w:spacing w:before="180" w:after="100"/></w:pPr>
          <w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="0F172A"/></w:rPr><w:t>${_xmlEscape(headingText)}</w:t></w:r>
        </w:p>\n''');
      } else if (trimmed.startsWith('### ')) {
        final headingText = trimmed.substring(4).trim();
        sb.write('''<w:p>
          <w:pPr><w:spacing w:before="140" w:after="80"/></w:pPr>
          <w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="0F172A"/></w:rPr><w:t>${_xmlEscape(headingText)}</w:t></w:r>
        </w:p>\n''');
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final bulletText = trimmed.substring(2).trim();
        sb.write('<w:p><w:pPr><w:ind w:left="360"/><w:spacing w:after="60"/></w:pPr>');
        sb.write('<w:r><w:rPr><w:sz w:val="22"/><w:color w:val="1E293B"/></w:rPr><w:t>• </w:t></w:r>');
        sb.write(_parseInlineFormattedRuns(bulletText, fontSize: 22, color: "1E293B"));
        sb.write('</w:p>\n');
      } else {
        sb.write('<w:p><w:pPr><w:spacing w:after="100"/></w:pPr>');
        sb.write(_parseInlineFormattedRuns(trimmed, fontSize: 22, color: "1E293B"));
        sb.write('</w:p>\n');
      }
    }

    sb.write('</w:body>\n');
    sb.write('</w:document>');

    return sb.toString();
  }

  static String _parseInlineFormattedRuns(String text, {int fontSize = 22, String color = "1E293B"}) {
    final sb = StringBuffer();
    final regExp = RegExp(r'(\*\*\*(.*?)\*\*\*|\*\*(.*?)\*\*|\*(.*?)\*|`(.*?)`)');
    
    int lastMatchEnd = 0;
    for (final match in regExp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        final plain = text.substring(lastMatchEnd, match.start);
        sb.write('<w:r><w:rPr><w:sz w:val="$fontSize"/><w:color w:val="$color"/></w:rPr><w:t xml:space="preserve">${_xmlEscape(plain)}</w:t></w:r>');
      }

      final fullMatch = match.group(0)!;
      if (fullMatch.startsWith('***')) {
        final inner = match.group(2)!;
        sb.write('<w:r><w:rPr><w:b/><w:i/><w:sz w:val="$fontSize"/><w:color w:val="$color"/></w:rPr><w:t xml:space="preserve">${_xmlEscape(inner)}</w:t></w:r>');
      } else if (fullMatch.startsWith('**')) {
        final inner = match.group(3)!;
        sb.write('<w:r><w:rPr><w:b/><w:sz w:val="$fontSize"/><w:color w:val="$color"/></w:rPr><w:t xml:space="preserve">${_xmlEscape(inner)}</w:t></w:r>');
      } else if (fullMatch.startsWith('*')) {
        final inner = match.group(4)!;
        sb.write('<w:r><w:rPr><w:i/><w:sz w:val="$fontSize"/><w:color w:val="$color"/></w:rPr><w:t xml:space="preserve">${_xmlEscape(inner)}</w:t></w:r>');
      } else if (fullMatch.startsWith('`')) {
        final inner = match.group(5)!;
        sb.write('<w:r><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:sz w:val="$fontSize"/><w:color w:val="2563EB"/></w:rPr><w:t xml:space="preserve">${_xmlEscape(inner)}</w:t></w:r>');
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      final plain = text.substring(lastMatchEnd);
      sb.write('<w:r><w:rPr><w:sz w:val="$fontSize"/><w:color w:val="$color"/></w:rPr><w:t xml:space="preserve">${_xmlEscape(plain)}</w:t></w:r>');
    }

    return sb.toString();
  }

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
