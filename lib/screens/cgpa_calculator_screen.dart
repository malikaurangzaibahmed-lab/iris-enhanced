import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import '../core/tokens.dart';
import '../widgets/glass_card.dart';
import '../services/ui_feedback.dart';
import '../core/vital_theme.dart';
import 'students_week_screen.dart'; // For CgpaCalculatorAnimationWidget

class CgpaCalculatorScreen extends StatefulWidget {
  const CgpaCalculatorScreen({super.key});

  @override
  State<CgpaCalculatorScreen> createState() => _CgpaCalculatorScreenState();
}

class _CgpaCalculatorScreenState extends State<CgpaCalculatorScreen> {
  final List<CgpaCourseRow> _rows = [
    CgpaCourseRow(),
    CgpaCourseRow(),
    CgpaCourseRow(),
  ];

  double _semesterGpa = 0.0;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _recalculate() {
    double qualityPoints = 0;
    double totalCredits = 0;

    for (final row in _rows) {
      final credits = double.tryParse(row.creditsController.text) ?? 0;
      if (credits <= 0) {
        continue;
      }
      qualityPoints += credits * row.gradePoint;
      totalCredits += credits;
    }

    setState(() {
      _semesterGpa = totalCredits > 0 ? qualityPoints / totalCredits : 0.0;
    });
  }

  void _addRow() {
    setState(() {
      _rows.add(CgpaCourseRow());
    });
    _recalculate();
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
    _recalculate();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('CGPA Calculator'),
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          ObsidianPulse(isDark: isDark),
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
              20,
              36,
            ),
            children: [
              CgpaCalculatorAnimationWidget(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: IrisTokens.brandGradient),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CGPA Calculator',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black)),
                          const SizedBox(height: 4),
                          Text('Estimate GPA and keep your semester plan visible.',
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.64))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: IrisTokens.brand.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: IrisTokens.brand,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Semester GPA',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.68),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _semesterGpa.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add your courses below',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.72,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(_rows.length, (index) {
                final row = _rows[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CgpaRowCard(
                    index: index,
                    row: row,
                    onChanged: _recalculate,
                    onDelete: () => _removeRow(index),
                  ),
                );
              }),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Course'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _recalculate,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Recalculate'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CgpaCourseRow {
  CgpaCourseRow();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController creditsController = TextEditingController();
  String grade = 'A';

  static const Map<String, double> gradePoints = {
    'A': 4.0,
    'A-': 3.67,
    'B+': 3.33,
    'B': 3.00,
    'B-': 2.67,
    'C+': 2.33,
    'C': 2.00,
    'C-': 1.67,
    'D+': 1.33,
    'D': 1.00,
    'F': 0.0,
  };

  double get gradePoint => gradePoints[grade] ?? 0.0;

  List<String> get gradeOptions => gradePoints.keys.toList();

  void dispose() {
    nameController.dispose();
    creditsController.dispose();
  }
}

class CgpaRowCard extends StatelessWidget {
  final int index;
  final CgpaCourseRow row;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const CgpaRowCard({
    super.key,
    required this.index,
    required this.row,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Course ${index + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: row.nameController,
              decoration: const InputDecoration(
                labelText: 'Course Name (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.creditsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Credit Hours',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: lgw.GlassMenu(
                    menuWidth: 180,
                    menuHeight: 280.0,
                    triggerBuilder: (context, toggleMenu) {
                      return InkWell(
                        onTap: () {
                          IrisHaptics.actionSoft();
                          toggleMenu();
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? Colors.white30 : Colors.black26,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Grade',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    row.grade,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    items: row.gradeOptions.map((g) {
                      return lgw.GlassMenuItem(
                        title: '$g (${CgpaCourseRow.gradePoints[g]})',
                        onTap: () {
                          row.grade = g;
                          onChanged();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
