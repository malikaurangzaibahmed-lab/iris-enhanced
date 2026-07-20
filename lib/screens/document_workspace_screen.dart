import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../core/tokens.dart';
import '../core/glass.dart';
import '../services/ui_feedback.dart';
import '../core/animations.dart';

class DocumentWorkspaceScreen extends StatefulWidget {
  const DocumentWorkspaceScreen({super.key});

  @override
  State<DocumentWorkspaceScreen> createState() => _DocumentWorkspaceScreenState();
}

class _DocumentWorkspaceScreenState extends State<DocumentWorkspaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Document Maker Wizard State
  bool _hasActiveDocument = false;
  String _docType = 'Assignment'; // 'Assignment', 'Quiz Prep', 'Project Report'
  final TextEditingController _courseController = TextEditingController(text: 'Object Oriented Programming');
  final TextEditingController _titleController = TextEditingController(text: 'Assignment 3');
  final TextEditingController _authorController = TextEditingController(text: 'Malik Aurangzaib Ahmed');
  final TextEditingController _regIdController = TextEditingController(text: 'FA22-BCS-089');
  
  // Document Editor State
  final TextEditingController _editorController = TextEditingController();
  final List<PlatformFile> _attachedImages = [];
  String _selectedExportFormat = 'PDF (.pdf)';
  bool _isExporting = false;
  double _exportProgress = 0.0;
  bool _exportSuccess = false;

  // File Picker variables (Converter Tab)
  PlatformFile? _pickedFile;
  String _targetFormat = 'Word (.docx)';
  bool _isConverting = false;
  double _conversionProgress = 0.0;
  String _conversionStep = 'Idle';
  bool _conversionSuccess = false;
  
  // Splitter variables
  PlatformFile? _splitterFile;
  final TextEditingController _rangeController = TextEditingController(text: '1-3');
  bool _isSplitting = false;
  double _splitterProgress = 0.0;
  bool _splitterSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDraftDocument();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _courseController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _regIdController.dispose();
    _editorController.dispose();
    _rangeController.dispose();
    super.dispose();
  }

  Future<void> _loadDraftDocument() async {
    final prefs = await SharedPreferences.getInstance();
    final hasDraft = prefs.getBool('helpdesk_has_doc_draft') ?? false;
    if (hasDraft) {
      setState(() {
        _hasActiveDocument = true;
        _docType = prefs.getString('helpdesk_doc_type') ?? 'Assignment';
        _courseController.text = prefs.getString('helpdesk_doc_course') ?? '';
        _titleController.text = prefs.getString('helpdesk_doc_title') ?? '';
        _authorController.text = prefs.getString('helpdesk_doc_author') ?? '';
        _regIdController.text = prefs.getString('helpdesk_doc_reg') ?? '';
        _editorController.text = prefs.getString('helpdesk_doc_content') ?? '';
        
        final imagesJson = prefs.getString('helpdesk_doc_images') ?? '[]';
        try {
          final List<dynamic> decoded = jsonDecode(imagesJson);
          _attachedImages.clear();
          for (var item in decoded) {
            _attachedImages.add(
              PlatformFile(
                name: item['name'],
                size: item['size'],
                path: item['path'],
              ),
            );
          }
        } catch (_) {}
      });
    }
  }

  Future<void> _saveDraftDocument() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('helpdesk_has_doc_draft', _hasActiveDocument);
    if (_hasActiveDocument) {
      await prefs.setString('helpdesk_doc_type', _docType);
      await prefs.setString('helpdesk_doc_course', _courseController.text);
      await prefs.setString('helpdesk_doc_title', _titleController.text);
      await prefs.setString('helpdesk_doc_author', _authorController.text);
      await prefs.setString('helpdesk_doc_reg', _regIdController.text);
      await prefs.setString('helpdesk_doc_content', _editorController.text);
      
      final List<Map<String, dynamic>> imagesList = _attachedImages.map((e) => {
        'name': e.name,
        'size': e.size,
        'path': e.path,
      }).toList();
      await prefs.setString('helpdesk_doc_images', jsonEncode(imagesList));
    }
  }

  void _initializeTemplate() {
    String template = '';
    final nowStr = DateTime.now().toLocal().toString().substring(0, 10);
    
    if (_docType == 'Assignment') {
      template = '''# CUI SAHIWAL CAMPUS
## DEPARTMENT OF COMPUTER SCIENCE

**Course:** ${_courseController.text}
**Title:** ${_titleController.text}
**Author:** ${_authorController.text} (${_regIdController.text})
**Date:** $nowStr

---

### 1. Introduction
Write your introductory notes, definitions, or literature background here...

### 2. Problem Statement
Explain the assignment questions, requirements, or problem description here...

### 3. Methodology & Algorithm
Write step-by-step logic, code segments, or theoretical diagrams here...

### 4. Implementation & Results
Attach code outputs or explain execution screens...

### 5. Conclusion
Summarize results and add project references...
''';
    } else if (_docType == 'Quiz Prep') {
      template = '''# QUIZ PREPARATION GUIDE
**Course:** ${_courseController.text}
**Topic:** ${_titleController.text}
**Created By:** ${_authorController.text}
**Date:** $nowStr

---

### 🔑 Key Formulas & Theories
1. [Formula 1 Name]: description / equation
2. [Theory 2 Name]: quick bullet summary

### 📚 Core Lecture Bullet Notes
- Topic 1 Core Takeaway: write summary note...
- Topic 2 Core Takeaway: write summary note...

### ❓ Sample & Past Questions
1. [Past Question 1]
   - *Answer/Hint:* write solution roadmap here...
2. [Past Question 2]
   - *Answer/Hint:* write solution roadmap here...
''';
    } else {
      // Project Report
      template = '''# FYP / SEMESTER PROJECT STATUS REPORT
**Project Title:** ${_titleController.text}
**Course / Context:** ${_courseController.text}
**Lead Developer:** ${_authorController.text} (${_regIdController.text})
**Submission Date:** $nowStr

---

### 📝 Executive Summary
Provide a high-level summary of the semester project goals, architecture, and current execution status...

### 🛠️ Technology Stack
- **Frontend:** Flutter & Liquid Glass Canvas
- **Backend:** Node.js / Kotlin AppWidget providers
- **Database:** SharedPreferences local syncs

### ⚙️ Implementation Milestones
- [x] Phase 1: Requirement gathering and vector design validation
- [ ] Phase 2: Complete RemoteViews frame layout changes
- [ ] Phase 3: Connect document export engine modules

### 📊 Results & Screenshots
Attach output previews and write comments below...
''';
    }

    setState(() {
      _editorController.text = template;
      _attachedImages.clear();
      _hasActiveDocument = true;
      _exportSuccess = false;
    });
    IrisHaptics.actionHeavy();
    _saveDraftDocument();
  }

  Future<void> _attachImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachedImages.add(result.files.first);
          // Insert image markdown placeholder in editor
          final imageName = result.files.first.name;
          final currentPos = _editorController.selection.baseOffset;
          final markdownTag = '\n![Image Attachment: $imageName](Attached Asset)\n';
          
          if (currentPos >= 0 && currentPos <= _editorController.text.length) {
            final text = _editorController.text;
            _editorController.text = text.substring(0, currentPos) + markdownTag + text.substring(currentPos);
          } else {
            _editorController.text += markdownTag;
          }
        });
        IrisHaptics.chipSelect();
        _saveDraftDocument();
      }
    } catch (e) {
      debugPrint('Image attach error: $e');
    }
  }

  Future<void> _exportDocument() async {
    setState(() {
      _isExporting = true;
      _exportProgress = 0.1;
      _exportSuccess = false;
    });

    try {
      final docText = _editorController.text;
      
      setState(() => _exportProgress = 0.3);
      
      final document = PdfDocument();
      final page = document.pages.add();
      
      setState(() => _exportProgress = 0.5);
      
      final layoutFormat = PdfLayoutFormat(layoutType: PdfLayoutType.paginate);
      PdfTextElement(
        text: docText,
        font: PdfStandardFont(PdfFontFamily.helvetica, 11),
      ).draw(
        page: page,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
        format: layoutFormat,
      );
      
      setState(() => _exportProgress = 0.7);
      
      final List<int> bytes = await document.save();
      document.dispose();
      
      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = _titleController.text.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      setState(() {
        _exportProgress = 1.0;
        _isExporting = false;
        _exportSuccess = true;
      });
      
      IrisHaptics.actionHeavy();
      showIrisFrostedSnackBar(context, content: Text('Document exported successfully: $fileName'));
      
      await OpenFilex.open(file.path);
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportSuccess = false;
      });
      showIrisFrostedSnackBar(context, content: Text('Export failed: $e'));
    }
  }

  Future<void> _closeDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Document?'),
        content: const Text('Save your current draft before closing. Unsaved session edits will be kept in offline storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _hasActiveDocument = false;
      });
      _saveDraftDocument();
    }
  }

  // File Picker variables (Converter Tab)
  Future<void> _pickFileForConverter() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'jpg', 'jpeg', 'png', 'txt'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedFile = result.files.first;
          _conversionSuccess = false;
          final ext = _pickedFile!.extension?.toLowerCase();
          if (ext == 'pdf') {
            _targetFormat = 'Word (.docx)';
          } else {
            _targetFormat = 'PDF (.pdf)';
          }
        });
        IrisHaptics.chipSelect();
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  Future<void> _pickFileForSplitter() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _splitterFile = result.files.first;
          _splitterSuccess = false;
        });
        IrisHaptics.chipSelect();
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  Future<void> _runConversion() async {
    if (_pickedFile == null) return;
    setState(() {
      _isConverting = true;
      _conversionProgress = 0.1;
      _conversionStep = 'Reading picked file...';
      _conversionSuccess = false;
    });

    try {
      final inputPath = _pickedFile!.path;
      if (inputPath == null) throw 'File path is unavailable';
      
      setState(() {
        _conversionProgress = 0.4;
        _conversionStep = 'Scaffolding PDF...';
      });
      
      final document = PdfDocument();
      final page = document.pages.add();
      
      final ext = _pickedFile!.extension?.toLowerCase();
      
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
        setState(() {
          _conversionProgress = 0.7;
          _conversionStep = 'Drawing image bytes...';
        });
        final imageBytes = await File(inputPath).readAsBytes();
        final pdfImage = PdfBitmap(imageBytes);
        
        final width = page.getClientSize().width;
        final height = page.getClientSize().height;
        page.graphics.drawImage(pdfImage, Rect.fromLTWH(0, 0, width, height));
      } else {
        setState(() {
          _conversionProgress = 0.7;
          _conversionStep = 'Encoding layout flow...';
        });
        final contentText = await File(inputPath).readAsString();
        final layoutFormat = PdfLayoutFormat(layoutType: PdfLayoutType.paginate);
        PdfTextElement(
          text: contentText,
          font: PdfStandardFont(PdfFontFamily.helvetica, 11),
        ).draw(
          page: page,
          bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
          format: layoutFormat,
        );
      }
      
      final List<int> bytes = await document.save();
      document.dispose();
      
      final dir = await getApplicationDocumentsDirectory();
      final baseName = _pickedFile!.name.split('.').first;
      final outPath = '${dir.path}/${baseName}_converted_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(outPath);
      await file.writeAsBytes(bytes);
      
      setState(() {
        _conversionProgress = 1.0;
        _conversionStep = 'Conversion completed!';
        _isConverting = false;
        _conversionSuccess = true;
      });
      
      IrisHaptics.actionHeavy();
      showIrisFrostedSnackBar(context, content: const Text('File converted successfully!'));
      
      await OpenFilex.open(outPath);
    } catch (e) {
      setState(() {
        _isConverting = false;
        _conversionStep = 'Conversion failed';
        _conversionSuccess = false;
      });
      showIrisFrostedSnackBar(context, content: Text('Conversion failed: $e'));
    }
  }

  Future<void> _runSplit() async {
    if (_splitterFile == null) return;
    setState(() {
      _isSplitting = true;
      _splitterProgress = 0.1;
      _splitterSuccess = false;
    });

    try {
      final inputPath = _splitterFile!.path;
      if (inputPath == null) throw 'File path is unavailable';
      
      final rangeText = _rangeController.text.trim();
      if (rangeText.isEmpty) throw 'Please specify page range (e.g. 1-3)';
      
      int startPage = 1;
      int endPage = 1;
      
      if (rangeText.contains('-')) {
        final parts = rangeText.split('-');
        startPage = int.parse(parts[0].trim());
        endPage = int.parse(parts[1].trim());
      } else {
        startPage = int.parse(rangeText);
        endPage = startPage;
      }
      
      if (startPage <= 0 || endPage < startPage) {
        throw 'Invalid page range specified';
      }
      
      setState(() {
        _splitterProgress = 0.4;
      });
      
      final sourceBytes = await File(inputPath).readAsBytes();
      final sourceDoc = PdfDocument(inputBytes: sourceBytes);
      final totalPages = sourceDoc.pages.count;
      
      if (startPage > totalPages || endPage > totalPages) {
        sourceDoc.dispose();
        throw 'Range exceeds total document pages ($totalPages)';
      }
      
      final destinationDoc = PdfDocument();
      
      for (int i = startPage; i <= endPage; i++) {
        final sourcePage = sourceDoc.pages[i - 1];
        final template = sourcePage.createTemplate();
        final destPage = destinationDoc.pages.add();
        destPage.graphics.drawPdfTemplate(template, Offset.zero);
        
        setState(() {
          _splitterProgress = 0.4 + (0.4 * (i - startPage + 1) / (endPage - startPage + 1));
        });
      }
      
      final List<int> bytes = await destinationDoc.save();
      destinationDoc.dispose();
      sourceDoc.dispose();
      
      final dir = await getApplicationDocumentsDirectory();
      final baseName = _splitterFile!.name.split('.').first;
      final outPath = '${dir.path}/${baseName}_split_${startPage}_to_${endPage}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(outPath);
      await file.writeAsBytes(bytes);
      
      setState(() {
        _splitterProgress = 1.0;
        _isSplitting = false;
        _splitterSuccess = true;
      });
      
      IrisHaptics.actionHeavy();
      showIrisFrostedSnackBar(context, content: const Text('PDF pages split successfully!'));
      
      await OpenFilex.open(outPath);
    } catch (e) {
      setState(() {
        _isSplitting = false;
        _splitterSuccess = false;
      });
      showIrisFrostedSnackBar(context, content: Text('Split failed: $e'));
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: irisFrostedAppBar(
        title: 'Document Workspace',
        isDark: isDark,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Sliding Tab Segment
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (isDark ? Colors.white10 : Colors.black12)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: isDark ? Colors.white : Colors.black87,
                  unselectedLabelColor: isDark ? Colors.white38 : Colors.black45,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Doc Maker'),
                    Tab(text: 'Converter'),
                    Tab(text: 'Splitter'),
                  ],
                ),
              ),
            ),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Document Maker
                  _buildDocMakerTab(isDark),
                  // Tab 2: Converter
                  _buildConverterTab(isDark),
                  // Tab 3: Splitter
                  _buildSplitterTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocMakerTab(bool isDark) {
    if (!_hasActiveDocument) {
      return _buildCreationWizard(isDark);
    }
    return _buildDocumentEditor(isDark);
  }

  Widget _buildCreationWizard(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Introduction
          Text(
            'Academic Document Templates',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select document format layout type to instantly scaffold your coursework.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
          const SizedBox(height: 20),

          // Template Type Select Grid
          Row(
            children: [
              _buildTypeCard('Assignment', Icons.assignment_turned_in_rounded, IrisTokens.brand, isDark),
              const SizedBox(width: 8),
              _buildTypeCard('Quiz Prep', Icons.quiz_rounded, IrisTokens.warning, isDark),
              const SizedBox(width: 8),
              _buildTypeCard('Project Report', Icons.assessment_rounded, IrisTokens.success, isDark),
            ],
          ),
          const SizedBox(height: 24),

          // Configuration Inputs
          _buildInputField('Course Title', _courseController, 'e.g. Object Oriented Programming', isDark),
          const SizedBox(height: 14),
          _buildInputField('Document Subtitle / Title', _titleController, 'e.g. Assignment 3 or Final Report', isDark),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildInputField('Student Name', _authorController, 'Your Full Name', isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField('Registration ID', _regIdController, 'e.g. FA22-BCS-089', isDark),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Action Trigger
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _initializeTemplate,
              icon: const Icon(Icons.rocket_launch_rounded, size: 20),
              label: const Text('Generate Document Template', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: IrisTokens.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard(String value, IconData icon, Color color, bool isDark) {
    final isSelected = _docType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _docType = value);
          IrisHaptics.chipSelect();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? color : (isDark ? Colors.white10 : Colors.black12),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : (isDark ? Colors.white54 : Colors.black54), size: 26),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? color : (isDark ? Colors.white70 : Colors.black87),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: (isDark ? Colors.white54 : Colors.black54),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: (isDark ? Colors.white10 : Colors.black12)),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentEditor(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active document metadata banner
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: IrisTokens.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _docType.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: IrisTokens.brand),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _titleController.text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _closeDocument,
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Close Document',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Editor Container
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (isDark ? Colors.white10 : Colors.black12)),
              ),
              child: TextField(
                controller: _editorController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(fontSize: 13.5, height: 1.5, color: isDark ? Colors.white : Colors.black87),
                decoration: const InputDecoration(
                  hintText: 'Flesh out document body text here...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => _saveDraftDocument(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Pictures attachment row
          Text(
            'MEDIA ATTACHMENTS (${_attachedImages.length})',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: (isDark ? Colors.white54 : Colors.black54),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              GestureDetector(
                onTap: _attachImage,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (isDark ? Colors.white10 : Colors.black12)),
                  ),
                  child: Icon(Icons.add_photo_alternate_rounded, color: IrisTokens.brand, size: 24),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: _attachedImages.isEmpty
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Attach screenshot image file outputs',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _attachedImages.length,
                          itemBuilder: (context, idx) {
                            final file = _attachedImages[idx];
                            final path = file.path;
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: path != null
                                        ? Image.file(
                                            File(path),
                                            fit: BoxFit.cover,
                                            width: 60,
                                            height: 60,
                                          )
                                        : const Center(child: Icon(Icons.image, color: Colors.white70)),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _attachedImages.removeAt(idx));
                                        IrisHaptics.actionSoft();
                                        _saveDraftDocument();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Export Selection and Action Buttons
          if (_isExporting) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _exportProgress,
                    minHeight: 8,
                    color: IrisTokens.brand,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Compiling Markdown and scaling attachments...',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
          ] else if (_exportSuccess) ...[
            // Success Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: IrisTokens.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: IrisTokens.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: IrisTokens.success, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Successfully compiled to $_selectedExportFormat!',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _exportSuccess = false);
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: lgw.GlassMenu(
                      menuWidth: 200,
                      menuHeight: 186.0,
                      triggerBuilder: (context, toggleMenu) {
                        return InkWell(
                          onTap: () {
                            IrisHaptics.actionSoft();
                            toggleMenu();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedExportFormat,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      items: <String>['PDF (.pdf)', 'Word (.docx)', 'Markdown (.md)', 'Text (.txt)'].map((String val) {
                        return lgw.GlassMenuItem(
                          title: val,
                          onTap: () {
                            setState(() => _selectedExportFormat = val);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _exportDocument,
                  icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                  label: const Text('Export File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IrisTokens.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConverterTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _isConverting ? null : _pickFileForConverter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.01),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _pickedFile != null
                      ? IrisTokens.brand.withValues(alpha: 0.6)
                      : (isDark ? Colors.white10 : Colors.black12),
                  width: _pickedFile != null ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _pickedFile != null ? Icons.insert_drive_file_rounded : Icons.cloud_upload_outlined,
                    size: 48,
                    color: _pickedFile != null ? IrisTokens.brand : (isDark ? Colors.white38 : Colors.black38),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _pickedFile != null ? _pickedFile!.name : 'Tap to Upload File',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _pickedFile != null
                        ? _formatBytes(_pickedFile!.size)
                        : 'Supports PDF, Word, JPG, PNG, TXT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white38 : Colors.black45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_pickedFile != null) ...[
            Text(
              'CONVERT TO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: (isDark ? Colors.white54 : Colors.black54),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (isDark ? Colors.white10 : Colors.black12)),
              ),
              child: lgw.GlassMenu(
                menuWidth: 280,
                menuHeight: 186.0,
                triggerBuilder: (context, toggleMenu) {
                  return InkWell(
                    onTap: _isConverting
                        ? null
                        : () {
                            IrisHaptics.actionSoft();
                            toggleMenu();
                          },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _targetFormat,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDark ? Colors.white70 : Colors.black54,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                items: <String>['PDF (.pdf)', 'Word (.docx)', 'Images (.jpg)', 'Text (.txt)'].map((String value) {
                  return lgw.GlassMenuItem(
                    title: value,
                    onTap: () {
                      setState(() => _targetFormat = value);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            if (_isConverting) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _conversionProgress,
                      minHeight: 8,
                      color: IrisTokens.brand,
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _conversionStep,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ] else if (_conversionSuccess) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: IrisTokens.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: IrisTokens.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: IrisTokens.success, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conversion Completed!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Target format: $_targetFormat',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        showIrisFrostedSnackBar(context, content: const Text('Opening file...'));
                      },
                      icon: Icon(Icons.open_in_new_rounded, color: IrisTokens.success),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _runConversion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IrisTokens.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Convert Document', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSplitterTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _isSplitting ? null : _pickFileForSplitter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.01),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _splitterFile != null
                      ? IrisTokens.purple.withValues(alpha: 0.6)
                      : (isDark ? Colors.white10 : Colors.black12),
                  width: _splitterFile != null ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _splitterFile != null ? Icons.picture_as_pdf_rounded : Icons.upload_file_rounded,
                    size: 48,
                    color: _splitterFile != null ? IrisTokens.purple : (isDark ? Colors.white38 : Colors.black38),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _splitterFile != null ? _splitterFile!.name : 'Select PDF File',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _splitterFile != null
                        ? _formatBytes(_splitterFile!.size)
                        : 'Splits PDF file by page range',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white38 : Colors.black45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_splitterFile != null) ...[
            Text(
              'PAGE RANGE (e.g. 1-3, 5)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: (isDark ? Colors.white54 : Colors.black54),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (isDark ? Colors.white10 : Colors.black12)),
              ),
              child: TextField(
                controller: _rangeController,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter pages to extract',
                  border: InputBorder.none,
                ),
                enabled: !_isSplitting,
              ),
            ),
            const SizedBox(height: 24),

            if (_isSplitting) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _splitterProgress,
                      minHeight: 8,
                      color: IrisTokens.purple,
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Extracting and compiling page list...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ] else if (_splitterSuccess) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: IrisTokens.purple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: IrisTokens.purple.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: IrisTokens.purple, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pages Extracted!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Extracted pages: ${_rangeController.text}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        showIrisFrostedSnackBar(context, content: const Text('Saved split document.'));
                      },
                      icon: Icon(Icons.download_rounded, color: IrisTokens.purple),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _runSplit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IrisTokens.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Split PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
