import 'dart:io';
import 'package:flutter/material.dart';
import 'services/pdf_debug_parser.dart';
import 'widgets/liquid_glass_effect.dart';

/// Debug screen for testing PDF parser
class PDFDebugScreen extends StatefulWidget {
  const PDFDebugScreen({Key? key}) : super(key: key);

  @override
  State<PDFDebugScreen> createState() => _PDFDebugScreenState();
}

class _PDFDebugScreenState extends State<PDFDebugScreen> {
  final pdfTests = [
    ('assets/ME (9).pdf', 'ME-2022'),
    ('assets/CVE.pdf', 'CVE-2022'),
    ('assets/EE (4).pdf', 'EE-2022'),
  ];

  Map<String, PDFDebugResult?> results = {};
  Map<String, bool> loading = {};
  Map<String, String?> errors = {};

  @override
  void initState() {
    super.initState();
    for (final (path, _) in pdfTests) {
      loading[path] = false;
      results[path] = null;
      errors[path] = null;
    }
  }

  Future<void> _runTest(String pdfPath, String batch) async {
    setState(() {
      loading[pdfPath] = true;
      errors[pdfPath] = null;
    });

    try {
      final file = File(pdfPath);
      if (!file.existsSync()) {
        setState(() {
          errors[pdfPath] = 'File not found: $pdfPath';
          loading[pdfPath] = false;
        });
        return;
      }

      final result = await PDFDebugParser.parseWithDebug(
        file,
        currentBatch: batch,
      );

      if (result == null) {
        setState(() {
          errors[pdfPath] = 'Parser returned null';
          loading[pdfPath] = false;
        });
        return;
      }

      setState(() {
        results[pdfPath] = result;
        loading[pdfPath] = false;
      });
    } catch (e, st) {
      setState(() {
        errors[pdfPath] = 'Error: $e\n$st';
        loading[pdfPath] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassEffect(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PDF Parser Debug'),
          backgroundColor: Colors.deepPurple,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Run parser tests against actual PDFs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ...pdfTests.map((test) {
                final (path, batch) = test;
                final result = results[path];
                final isLoading = loading[path] ?? false;
                final error = errors[path];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      path.split('/').last,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Batch: $batch',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLoading)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                ElevatedButton(
                                  onPressed: () => _runTest(path, batch),
                                  child: const Text('Run'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (error != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                border: Border.all(color: Colors.red),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                error,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          else if (result != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    border: Border.all(color: Colors.green),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '✅ Success: ${result.sessions.length} sessions parsed',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildStats(result),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Sessions:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...result.rows.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final row = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      border: Border.all(
                                        color: _confidenceColor(row.confidence),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '[${idx + 1}/Conf ${row.confidence}%] ${row.day} ${row.timeRange}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '📚 ${row.subject}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        Text(
                                          '👨‍🏫 ${row.teacher}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        Text(
                                          '🏛️ ${row.room}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        if (row.subject == 'Unknown' ||
                                            row.teacher == 'Unknown' ||
                                            row.room == 'TBD')
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.orange[200],
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                              child: const Text(
                                                '⚠️ Contains missing data',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.orangeAccent,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats(PDFDebugResult result) {
    final avgConf = result.rows.isEmpty
        ? 0
        : result.rows.map((r) => r.confidence).reduce((a, b) => a + b) ~/ result.rows.length;
    final unknownCount = result.rows
        .where((r) => r.subject == 'Unknown' || r.teacher == 'Unknown' || r.room == 'TBD')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Avg Confidence: $avgConf%', style: const TextStyle(fontSize: 10)),
        Text('Sessions with "Unknown": $unknownCount/${result.rows.length}', 
             style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Color _confidenceColor(int confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }
}
