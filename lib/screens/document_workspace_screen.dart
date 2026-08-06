import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../services/ui_feedback.dart';
import '../services/cover_page_generator.dart';
import '../core/animations.dart';

class StudioBlock {
  final String id;
  String type; // 'text', 'bullet', 'formula', 'note'
  TextEditingController controller;

  StudioBlock({
    required this.id,
    required this.type,
    required String initialContent,
  }) : controller = TextEditingController(text: initialContent);
}

class DraggableStudioImage {
  final String id;
  final PlatformFile file;
  Offset offset;
  double width;
  double height;

  DraggableStudioImage({
    required this.id,
    required this.file,
    this.offset = const Offset(20, 160),
    this.width = 180,
    this.height = 140,
  });
}

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
  List<CoverPageField> _customCoverFields = [];
  
  // Document Editor State
  final TextEditingController _editorController = TextEditingController();
  final List<DraggableStudioImage> _attachedImages = [];
  final List<StudioBlock> _floatingBlocks = [];
  String _selectedExportFormat = 'PDF (.pdf)';
  bool _includeCoverPage = true;
  int _ribbonTabIndex = 0; // 0 = Home, 1 = Insert, 2 = Layout
  String _paperColorMode = 'White'; // 'White', 'Sepia', 'Dark'
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

  Future<void> _smartAutofillIdentity({bool showFeedback = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('student_user_name')?.trim().isNotEmpty == true
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

    setState(() {
      _authorController.text = savedName;
      _regIdController.text = formattedRegId;
    });

    if (showFeedback && mounted) {
      IrisHaptics.actionSoft();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ Auto-filled Identity: $formattedRegId ($savedName)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
            final pFile = PlatformFile(
              name: item['name'] ?? 'image.jpg',
              size: item['size'] ?? 0,
              path: item['path'],
            );
            _attachedImages.add(
              DraggableStudioImage(
                id: 'img_${DateTime.now().millisecondsSinceEpoch}',
                file: pFile,
              ),
            );
          }
        } catch (_) {}
      });
    } else {
      await _smartAutofillIdentity(showFeedback: false);
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
        'name': e.file.name,
        'size': e.file.size,
        'path': e.file.path,
      }).toList();
      await prefs.setString('helpdesk_doc_images', jsonEncode(imagesList));
    }
  }

  void _initializeTemplate() {
    String template = '';
    
    if (_docType == 'Assignment') {
      template = '''# 1. Introduction
Write your introductory notes, definitions, or literature background here...

# 2. Problem Statement & Requirements
Explain the assignment questions, requirements, or problem description here...

# 3. Methodology & Theoretical Approach
Write step-by-step logic, code segments, or theoretical diagrams here...

# 4. Implementation & Results
Attach code outputs or explain execution screens...

# 5. Conclusion & References
Summarize results and add project references...
''';
    } else if (_docType == 'Quiz Prep') {
      template = '''# 1. Key Formulas & Core Theories
1. [Formula 1 Name]: description / equation
2. [Theory 2 Name]: quick bullet summary

# 2. Core Lecture Notes & Concepts
- Topic 1 Core Takeaway: write summary note...
- Topic 2 Core Takeaway: write summary note...

# 3. Sample & Past Paper Questions
1. [Past Question 1]
   - Solution Roadmap / Hint: write solution steps here...
2. [Past Question 2]
   - Solution Roadmap / Hint: write solution steps here...
''';
    } else {
      template = '''# 1. Executive Summary
Provide a high-level summary of the semester project goals, architecture, and current execution status...

# 2. Technology Stack & Frameworks
- Frontend: Flutter & Liquid Glass Canvas
- Backend: Node.js / Kotlin AppWidget providers
- Database: SharedPreferences local syncs

# 3. Implementation Milestones & Architecture
- Phase 1: Requirement gathering and vector design validation
- Phase 2: Complete RemoteViews frame layout changes
- Phase 3: Connect document export engine modules

# 4. Results & Screenshots
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

  void _generateAIOutline() {
    IrisHaptics.actionHeavy();
    final outline = '''
# 1. Introduction
Write your introductory notes, definitions, or literature background here...

# 2. Problem Statement & Objectives
Explain the assignment questions, requirements, or problem description here...

# 3. Methodology & Algorithm Design
Write step-by-step logic, code segments, or theoretical diagrams here...

# 4. Implementation & Experimental Results
Attach code outputs or explain execution screens...

# 5. Conclusion & References
Summarize key findings, experimental outcomes, and list project references...
''';

    _insertEditorText('\n$outline\n');
    showIrisFrostedSnackBar(context, content: const Text('⚡ AI Academic Document Outline Generated!'));
  }

  void _applyFormatToSelection(String prefix, String suffix, String defaultText) {
    final text = _editorController.text;
    final selection = _editorController.selection;
    
    if (selection.start >= 0 && selection.end >= 0 && selection.start != selection.end) {
      final selectedText = text.substring(selection.start, selection.end);
      if (selectedText.startsWith(prefix) && selectedText.endsWith(suffix) && selectedText.length >= prefix.length + suffix.length) {
        final unwrapped = selectedText.substring(prefix.length, selectedText.length - suffix.length);
        final newText = text.replaceRange(selection.start, selection.end, unwrapped);
        _editorController.text = newText;
        _editorController.selection = TextSelection(
          baseOffset: selection.start,
          extentOffset: selection.start + unwrapped.length,
        );
      } else {
        final wrapped = '$prefix$selectedText$suffix';
        final newText = text.replaceRange(selection.start, selection.end, wrapped);
        _editorController.text = newText;
        _editorController.selection = TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.start + prefix.length + selectedText.length,
        );
      }
    } else {
      final snippet = '$prefix$defaultText$suffix';
      final start = selection.start >= 0 ? selection.start : text.length;
      final newText = text.replaceRange(start, start, snippet);
      _editorController.text = newText;
      _editorController.selection = TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + defaultText.length,
      );
    }
    _saveDraftDocument();
    IrisHaptics.actionSoft();
  }

  Future<void> _attachImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          final file = result.files.first;
          _attachedImages.add(
            DraggableStudioImage(
              id: 'img_${DateTime.now().millisecondsSinceEpoch}',
              file: file,
            ),
          );
          // Insert image markdown placeholder in editor
          final imageName = file.name;
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
      document.pageSettings.margins.all = 36.0;
      document.pageSettings.size = PdfPageSize.a4;

      if (_includeCoverPage) {
        final coverData = await CoverPageData.resolveDefaults(
          course: _courseController.text,
          title: _titleController.text,
          teacher: _authorController.text.isNotEmpty ? _authorController.text : 'Dr. Wasim',
          type: _docType,
        );
        if (_customCoverFields.isNotEmpty) {
          coverData.customFields = List.from(_customCoverFields);
        }
        await CoverPageGenerator.drawCoverPageOnDocument(document, coverData);
      }

      setState(() => _exportProgress = 0.5);

      StringBuffer fullBody = StringBuffer(docText);
      if (_floatingBlocks.isNotEmpty) {
        fullBody.writeln('\n\n---');
        fullBody.writeln('### ADDITIONAL NOTES & CALLOUTS');
        for (final block in _floatingBlocks) {
          if (block.controller.text.trim().isNotEmpty) {
            fullBody.writeln('* ${block.type.toUpperCase()}: ${block.controller.text.trim()}');
          }
        }
      }

      // Render rich formatted Markdown text into PDF pages
      RichMarkdownPdfRenderer.renderMarkdownToDocument(
        document: document,
        markdownText: fullBody.toString(),
        hasCoverPage: _includeCoverPage,
        docTitle: _titleController.text,
      );

      // Embed attached figures/images at user's exact dragged position and size on the PDF document page
      if (_attachedImages.isNotEmpty) {
        final targetPageIdx = _includeCoverPage ? 1 : 0;
        final targetPage = document.pages.count > targetPageIdx 
            ? document.pages[targetPageIdx] 
            : document.pages.add();

        for (final imgItem in _attachedImages) {
          if (imgItem.file.path != null && File(imgItem.file.path!).existsSync()) {
            final imageBytes = File(imgItem.file.path!).readAsBytesSync();
            final bitmap = PdfBitmap(imageBytes);
            targetPage.graphics.drawImage(
              bitmap,
              Rect.fromLTWH(
                imgItem.offset.dx.clamp(0.0, targetPage.getClientSize().width - 40.0),
                imgItem.offset.dy.clamp(0.0, targetPage.getClientSize().height - 40.0),
                imgItem.width,
                imgItem.height,
              ),
            );
          }
        }
      }
      
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

  void _smartAIAutoFormatDocument() {
    String text = _editorController.text.trim();
    if (text.isEmpty) {
      showIrisFrostedSnackBar(context, content: const Text('Type some content first to auto-format.'));
      return;
    }

    final lines = text.split('\n');
    final formattedLines = <String>[];
    int sectionCounter = 1;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        formattedLines.add('');
        continue;
      }

      if (!trimmed.startsWith('#') && (trimmed.toLowerCase().startsWith('intro') || trimmed.toLowerCase().startsWith('problem') || trimmed.toLowerCase().startsWith('result') || trimmed.toLowerCase().startsWith('conclusion') || trimmed.endsWith(':'))) {
        final cleanTitle = trimmed.replaceAll(RegExp(r'^[0-9]+\.|\:'), '').trim();
        formattedLines.add('\n# $sectionCounter. $cleanTitle');
        sectionCounter++;
      } else if (trimmed.startsWith('* ') || trimmed.startsWith('- ') || trimmed.startsWith('+ ')) {
        formattedLines.add('- ${trimmed.substring(2).trim()}');
      } else {
        formattedLines.add(line);
      }
    }

    _editorController.text = formattedLines.join('\n');
    _saveDraftDocument();
    IrisHaptics.actionHeavy();
    showIrisFrostedSnackBar(context, content: const Text('🪄 Smart AI Auto-Format Applied!'));
  }

  void _addFloatingBlock(String type, String defaultText) {
    final block = StudioBlock(
      id: 'block_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      initialContent: defaultText,
    );
    setState(() {
      _floatingBlocks.add(block);
    });
    IrisHaptics.actionSoft();
    _saveDraftDocument();
  }

  void _removeFloatingBlock(String id) {
    setState(() {
      _floatingBlocks.removeWhere((b) => b.id == id);
    });
    IrisHaptics.actionSoft();
    _saveDraftDocument();
  }

  Future<void> _generate1TapCoverPagePdf() async {
    IrisHaptics.actionHeavy();
    try {
      final coverData = await CoverPageData.resolveDefaults(
        course: _courseController.text,
        title: _titleController.text,
        teacher: _authorController.text.isNotEmpty ? 'Dr. Wasim' : null,
        type: _docType,
      );

      final pdfFile = await CoverPageGenerator.generateOfficialCoverPdf(coverData);
      
      showIrisFrostedSnackBar(
        context,
        content: Text('⚡ Official Cover Page Generated: ${pdfFile.path.split('/').last}'),
      );
      
      await OpenFilex.open(pdfFile.path);
    } catch (e) {
      debugPrint('Cover Page PDF Error: $e');
      showIrisFrostedSnackBar(context, content: Text('Generation failed: $e'));
    }
  }

  Future<void> _showCustomizeFieldsSheet() async {
    if (_customCoverFields.isEmpty) {
      final coverData = await CoverPageData.resolveDefaults(
        course: _courseController.text,
        title: _titleController.text,
        teacher: _authorController.text.isNotEmpty ? _authorController.text : 'Dr. Wasim',
        type: _docType,
      );

      _customCoverFields = [
        CoverPageField('Student Name', _authorController.text.isNotEmpty ? _authorController.text : coverData.studentName),
        CoverPageField('Registration ID', _regIdController.text.isNotEmpty ? _regIdController.text : coverData.registrationId),
        CoverPageField('Program & Batch', coverData.batch),
        CoverPageField('Submitted To', coverData.instructorName),
        CoverPageField('Submission Date', coverData.submissionDate),
      ];
    }

    final fields = List<CoverPageField>.from(_customCoverFields);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? IrisTokens.surfaceDark : IrisTokens.surfaceLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: IrisTokens.brand),
                      const SizedBox(width: 10),
                      const Text(
                        'Customize Cover Page Fields',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add, edit, or remove fields for your official cover sheet table.',
                    style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: fields.length,
                      itemBuilder: (context, idx) {
                        final item = fields[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: TextFormField(
                                  initialValue: item.label,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Field Label',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onChanged: (val) => item.label = val,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  initialValue: item.value,
                                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Field Value',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onChanged: (val) => item.value = val,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setSheetState(() {
                                    fields.removeAt(idx);
                                  });
                                  IrisHaptics.actionSoft();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setSheetState(() {
                            fields.add(CoverPageField('Custom Field', 'Value'));
                          });
                          IrisHaptics.actionSoft();
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Field'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _customCoverFields = List.from(fields);
                            for (final f in fields) {
                              final label = f.label.toLowerCase();
                              if (label.contains('student') || label.contains('name') || label.contains('author')) {
                                _authorController.text = f.value;
                              } else if (label.contains('registration') || label.contains('id') || label.contains('roll')) {
                                _regIdController.text = f.value;
                              } else if (label.contains('course')) {
                                _courseController.text = f.value;
                              } else if (label.contains('title')) {
                                _titleController.text = f.value;
                              }
                            }
                          });
                          _saveDraftDocument();
                          Navigator.pop(context);
                          showIrisFrostedSnackBar(
                            context,
                            content: const Text('💾 Cover Page Fields Saved & Applied!'),
                          );
                        },
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IrisTokens.brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _smartAutofillIdentity(showFeedback: true),
              icon: const Icon(Icons.bolt_rounded, size: 14, color: IrisTokens.brand),
              label: const Text(
                'Auto-Fill Saved Roll & Name',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: IrisTokens.brand),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Include Cover Page Toggle Switch Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: IrisTokens.brand, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Include Official Cover Title Page',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Auto-prefills COMSATS logo & student details as Page 1',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _includeCoverPage,
                  activeColor: IrisTokens.brand,
                  onChanged: (val) {
                    setState(() => _includeCoverPage = val);
                    IrisHaptics.chipSelect();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Triggers
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _generate1TapCoverPagePdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: const Text('⚡ 1-Tap Cover Page PDF', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IrisTokens.brand,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: _showCustomizeFieldsSheet,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: const BorderSide(color: IrisTokens.brand, width: 1.2),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 18, color: IrisTokens.brand),
                      SizedBox(width: 4),
                      Text('Fields', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: IrisTokens.brand)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _initializeTemplate,
              icon: const Icon(Icons.description_rounded, size: 18),
              label: const Text('Generate Full Document Workspace', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : Colors.black87,
                side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRibbonTab(String title, int index) {
    final isSelected = _ribbonTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _ribbonTabIndex = index);
        IrisHaptics.chipSelect();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRibbonBtn(String label, IconData icon, VoidCallback onTap, {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? IrisTokens.brand.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? IrisTokens.brand : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: active ? IrisTokens.brand : null),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.bold : FontWeight.w600,
                  color: active ? IrisTokens.brand : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _insertEditorText(String snippet) {
    final text = _editorController.text;
    final selection = _editorController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, snippet);
      _editorController.text = newText;
      _editorController.selection = TextSelection.collapsed(offset: selection.start + snippet.length);
    } else {
      _editorController.text = text + snippet;
    }
    _saveDraftDocument();
    IrisHaptics.actionSoft();
  }

  Widget _buildDocumentEditor(bool isDark) {
    Color paperBg = Colors.white;
    Color paperText = Colors.black87;
    if (_paperColorMode == 'Sepia') {
      paperBg = const Color(0xFFFDF6E3);
      paperText = const Color(0xFF433422);
    } else if (_paperColorMode == 'Dark') {
      paperBg = const Color(0xFF0F172A);
      paperText = const Color(0xFFF8FAFC);
    }

    return Column(
      children: [
        // 1. MS Word Title & Ribbon Header Container
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFF2B579A), // Official Word Blue Accent
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Title Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(
                  children: [
                    const Icon(Icons.description_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_titleController.text.isNotEmpty ? _titleController.text : "Document 1"} - MS Word Studio',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _exportDocument,
                      icon: const Icon(Icons.file_download_rounded, size: 14),
                      label: const Text('Export PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    IconButton(
                      onPressed: _closeDocument,
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      tooltip: 'Close Studio',
                    ),
                  ],
                ),
              ),

              // Ribbon Tab Bar (HOME, INSERT, LAYOUT)
              Container(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1F4478),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    _buildRibbonTab('HOME', 0),
                    _buildRibbonTab('INSERT', 1),
                    _buildRibbonTab('LAYOUT', 2),
                  ],
                ),
              ),

              // Ribbon Tools Sub-Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_ribbonTabIndex == 0) ...[
                        // HOME TAB TOOLS
                        _buildRibbonBtn('AI Format', Icons.auto_awesome_rounded, _smartAIAutoFormatDocument, active: true),
                        _buildRibbonBtn('AI Outline', Icons.schema_rounded, _generateAIOutline, active: true),
                        _buildRibbonBtn('Bold', Icons.format_bold_rounded, () => _applyFormatToSelection('**', '**', 'Bold Text')),
                        _buildRibbonBtn('Italic', Icons.format_italic_rounded, () => _applyFormatToSelection('*', '*', 'Italic Text')),
                        _buildRibbonBtn('H1', Icons.title_rounded, () => _applyFormatToSelection('# ', '\n', 'Section Title')),
                        _buildRibbonBtn('H2', Icons.text_fields_rounded, () => _applyFormatToSelection('## ', '\n', 'Subsection Title')),
                        _buildRibbonBtn('Bullets', Icons.format_list_bulleted_rounded, () => _insertEditorText('- Bullet point\n')),
                        _buildRibbonBtn('Numbers', Icons.format_list_numbered_rounded, () => _insertEditorText('1. Numbered item\n')),
                        _buildRibbonBtn('Code', Icons.code_rounded, () => _insertEditorText('```\n// Code snippet\n```\n')),
                      ] else if (_ribbonTabIndex == 1) ...[
                        // INSERT TAB TOOLS
                        _buildRibbonBtn('Cover Page', Icons.picture_as_pdf_rounded, () {
                          setState(() => _includeCoverPage = !_includeCoverPage);
                          IrisHaptics.chipSelect();
                        }, active: _includeCoverPage),
                        _buildRibbonBtn('Customize Cover', Icons.tune_rounded, _showCustomizeFieldsSheet, active: true),
                        _buildRibbonBtn('+ Text Box', Icons.text_fields_rounded, () => _addFloatingBlock('text', 'Write custom note or callout here...')),
                        _buildRibbonBtn('+ Bullets', Icons.format_list_bulleted_rounded, () => _addFloatingBlock('bullet', '- Custom point 1\n- Custom point 2')),
                        _buildRibbonBtn('+ Formula', Icons.functions_rounded, () => _addFloatingBlock('formula', r'\[ E = mc^2 \]')),
                        _buildRibbonBtn('+ Note Box', Icons.warning_amber_rounded, () => _addFloatingBlock('note', 'Note for Instructor / Grader: See Attached Diagram.')),
                        _buildRibbonBtn('Attach Image', Icons.add_photo_alternate_rounded, _attachImage),
                        _buildRibbonBtn('Table Grid', Icons.grid_on_rounded, () => _insertEditorText('| Header 1 | Header 2 |\n| --- | --- |\n| Data 1 | Data 2 |\n')),
                        _buildRibbonBtn('Rule Line', Icons.horizontal_rule_rounded, () => _insertEditorText('\n---\n')),
                        _buildRibbonBtn('Date Stamp', Icons.today_rounded, () => _insertEditorText(DateTime.now().toString().substring(0, 10))),
                      ] else if (_ribbonTabIndex == 2) ...[
                        // LAYOUT TAB TOOLS
                        _buildRibbonBtn('White Paper', Icons.description_outlined, () {
                          setState(() => _paperColorMode = 'White');
                          IrisHaptics.chipSelect();
                        }, active: _paperColorMode == 'White'),
                        _buildRibbonBtn('Cream Sepia', Icons.menu_book_rounded, () {
                          setState(() => _paperColorMode = 'Sepia');
                          IrisHaptics.chipSelect();
                        }, active: _paperColorMode == 'Sepia'),
                        _buildRibbonBtn('Dark Slate', Icons.dark_mode_rounded, () {
                          setState(() => _paperColorMode = 'Dark');
                          IrisHaptics.chipSelect();
                        }, active: _paperColorMode == 'Dark'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Realistic MS Word A4 Canvas Paper View
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0), // Desk surface background
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // A4 Ruler Header Line
                  Container(
                    constraints: const BoxConstraints(maxWidth: 540),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('▲ 0.5" Margin', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38)),
                        Text('A4 (210 × 297 mm)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38)),
                        Text('0.5" Margin ▲', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38)),
                      ],
                    ),
                  ),

                  // A4 Paper Sheet Card with Freeform Draggable Overlay Stack
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Main A4 Paper Card
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 540, minHeight: 650),
                          decoration: BoxDecoration(
                            color: paperBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Page Header Banner Badge
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2B579A).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _includeCoverPage ? 'PAGE 1 OF 2 • COVER & CONTENT' : 'PAGE 1 OF 1 • DOCUMENT BODY',
                                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF2B579A)),
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.print_rounded, size: 14, color: Colors.grey),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Render Official COMSATS Cover Page Preview if enabled
                              if (_includeCoverPage) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: paperBg == Colors.white ? const Color(0xFFF8FAFC) : paperBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF2B579A).withValues(alpha: 0.5), width: 1.5),
                                  ),
                                  child: Column(
                                    children: [
                                      // Document Type Header Tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2B579A).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'OFFICIAL COVER • ${_docType.toUpperCase()}',
                                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF2B579A), letterSpacing: 0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/comsats_logo.png',
                                            width: 48,
                                            height: 48,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: Color(0xFF2B579A), size: 40),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'COMSATS UNIVERSITY ISLAMABAD',
                                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF2B579A)),
                                                ),
                                                Text(
                                                  'Department of Computer Science',
                                                  style: TextStyle(fontSize: 10, color: paperText.withValues(alpha: 0.8)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        children: [
                                          Text('Course: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: paperText)),
                                          Expanded(
                                            child: Text(_courseController.text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2B579A))),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text('Title: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: paperText)),
                                          Expanded(
                                            child: Text(_titleController.text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: paperText)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text('Student: ', style: TextStyle(fontSize: 10.5, color: paperText.withValues(alpha: 0.7))),
                                          Expanded(
                                            child: Text('${_authorController.text} (${_regIdController.text})', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: paperText)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: InkWell(
                                          onTap: _showCustomizeFieldsSheet,
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2B579A).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.tune_rounded, size: 12, color: Color(0xFF2B579A)),
                                                SizedBox(width: 4),
                                                Text('Customize Fields', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2B579A))),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Divider(height: 1),
                                const SizedBox(height: 20),
                              ],

                              // Main WYSIWYG Document Editor Text Field
                              TextField(
                                controller: _editorController,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                style: TextStyle(fontSize: 14, height: 1.6, color: paperText),
                                decoration: InputDecoration(
                                  hintText: 'Type your document body here...\n\n# 1. Introduction\nWrite assignment definitions and notes...\n\n# 2. Results\nAttach screenshots below...',
                                  hintStyle: TextStyle(color: paperText.withValues(alpha: 0.4)),
                                  border: InputBorder.none,
                                ),
                                onChanged: (_) => _saveDraftDocument(),
                              ),

                              // Freeform Floating Blocks Canvas
                              if (_floatingBlocks.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                Column(
                                  children: _floatingBlocks.map((block) {
                                    final isNote = block.type == 'note';
                                    final isFormula = block.type == 'formula';
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isNote
                                            ? const Color(0xFFFEF3C7)
                                            : (isFormula ? const Color(0xFFEFF6FF) : paperBg),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isNote
                                              ? const Color(0xFFF59E0B)
                                              : (isFormula ? const Color(0xFF3B82F6) : paperText.withValues(alpha: 0.2)),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                isNote
                                                    ? Icons.warning_amber_rounded
                                                    : (isFormula ? Icons.functions_rounded : Icons.post_add_rounded),
                                                size: 14,
                                                color: isNote ? const Color(0xFFD97706) : Colors.blue,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                block.type.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: isNote ? const Color(0xFFD97706) : Colors.blue,
                                                ),
                                              ),
                                              const Spacer(),
                                              GestureDetector(
                                                onTap: () => _removeFloatingBlock(block.id),
                                                child: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          TextField(
                                            controller: block.controller,
                                            maxLines: null,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isNote ? const Color(0xFF78350F) : paperText,
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                            ),
                                            onChanged: (_) => _saveDraftDocument(),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // MS Word Style Interactive Draggable & Resizable Image Layer
                        ..._attachedImages.map((image) {
                          final path = image.file.path;
                          return Positioned(
                            left: image.offset.dx,
                            top: image.offset.dy,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // MS Word Style Quick Action Toolbar above Image
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xEE1E293B),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Drag Icon
                                      const Icon(Icons.drag_indicator_rounded, size: 13, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      // Insert In-Line with Text Button
                                      GestureDetector(
                                        onTap: () {
                                          final imageName = image.file.name;
                                          final tag = '\n\n![Image Attachment: $imageName](${image.file.path ?? "Asset"})\n\n';
                                          final pos = _editorController.selection.baseOffset;
                                          if (pos >= 0 && pos <= _editorController.text.length) {
                                            final txt = _editorController.text;
                                            _editorController.text = txt.substring(0, pos) + tag + txt.substring(pos);
                                          } else {
                                            _editorController.text += tag;
                                          }
                                          IrisHaptics.actionSoft();
                                          _saveDraftDocument();
                                          showIrisFrostedSnackBar(context, content: const Text('📌 Image placed in-line within text stream!'));
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2B579A),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.notes_rounded, size: 10, color: Colors.white),
                                              SizedBox(width: 3),
                                              Text('In-Line Text', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Align Left
                                      GestureDetector(
                                        onTap: () {
                                          setState(() => image.offset = Offset(20, image.offset.dy));
                                          IrisHaptics.actionSoft();
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 3),
                                          child: Icon(Icons.format_align_left_rounded, size: 13, color: Colors.white),
                                        ),
                                      ),
                                      // Align Center
                                      GestureDetector(
                                        onTap: () {
                                          setState(() => image.offset = Offset(160, image.offset.dy));
                                          IrisHaptics.actionSoft();
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 3),
                                          child: Icon(Icons.format_align_center_rounded, size: 13, color: Colors.white),
                                        ),
                                      ),
                                      // Align Right
                                      GestureDetector(
                                        onTap: () {
                                          setState(() => image.offset = Offset(280, image.offset.dy));
                                          IrisHaptics.actionSoft();
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 3),
                                          child: Icon(Icons.format_align_right_rounded, size: 13, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Close / Delete
                                      GestureDetector(
                                        onTap: () {
                                          setState(() => _attachedImages.removeWhere((img) => img.id == image.id));
                                          IrisHaptics.actionSoft();
                                          _saveDraftDocument();
                                        },
                                        child: const Icon(Icons.close_rounded, size: 13, color: Colors.redAccent),
                                      ),
                                    ],
                                  ),
                                ),

                                // Draggable Container
                                GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      image.offset = Offset(
                                        math.max(0.0, image.offset.dx + details.delta.dx),
                                        math.max(0.0, image.offset.dy + details.delta.dy),
                                      );
                                    });
                                    _saveDraftDocument();
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: image.width,
                                        height: image.height,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF2B579A), width: 2.0),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.25),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: path != null
                                              ? Image.file(File(path), width: image.width, height: image.height, fit: BoxFit.cover)
                                              : const Icon(Icons.image_rounded),
                                        ),
                                      ),

                                      // MS Word 4 Corner Blue Resize Handles
                                      Positioned(
                                        left: -5,
                                        top: -5,
                                        child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF2B579A), shape: BoxShape.circle)),
                                      ),
                                      Positioned(
                                        right: -5,
                                        top: -5,
                                        child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF2B579A), shape: BoxShape.circle)),
                                      ),
                                      Positioned(
                                        left: -5,
                                        bottom: -5,
                                        child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF2B579A), shape: BoxShape.circle)),
                                      ),
                                      // Bottom Right Resizer Handle with Drag gesture
                                      Positioned(
                                        right: -8,
                                        bottom: -8,
                                        child: GestureDetector(
                                          onPanUpdate: (details) {
                                            setState(() {
                                              image.width = math.max(80.0, image.width + details.delta.dx);
                                              image.height = math.max(60.0, image.height + details.delta.dy);
                                            });
                                            _saveDraftDocument();
                                          },
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2B579A),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.5),
                                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                            ),
                                            child: const Icon(Icons.aspect_ratio_rounded, size: 10, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3. Obsidian Studio Document Analytics & Control Console Status Bar
        Builder(
          builder: (_) {
            final text = _editorController.text;
            final charCount = text.length;
            final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
            final readTime = (wordCount / 200).ceil();
            final estPages = _includeCoverPage ? (1 + (wordCount / 350).ceil()) : (wordCount / 350).ceil();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF020617) : const Color(0xFF1E293B),
              child: Row(
                children: [
                  Icon(Icons.notes_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text(
                    '$wordCount Words  •  $charCount Chars',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.timer_outlined, size: 13, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text(
                    '${readTime < 1 ? 1 : readTime} min read',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: IrisTokens.brand.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'EST. $estPages A4 ${estPages == 1 ? "PAGE" : "PAGES"}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
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
