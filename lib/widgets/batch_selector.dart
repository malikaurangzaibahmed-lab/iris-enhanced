import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../services/ui_feedback.dart';

class BatchSelectorSheet extends StatefulWidget {
  final UniversityMemory memory;
  final String selected;

  const BatchSelectorSheet({
    required this.memory,
    required this.selected,
    super.key,
  });

  @override
  State<BatchSelectorSheet> createState() => _BatchSelectorSheetState();
}

class _BatchSelectorSheetState extends State<BatchSelectorSheet> {
  String? program;
  int? semester;
  String? section;

  @override
  void initState() {
    super.initState();
    final seed = widget.selected.trim().isNotEmpty
        ? widget.selected.trim()
        : (widget.memory.allBatches.isNotEmpty ? widget.memory.allBatches.first : '');
    final key = BatchKey.parse(seed);
    program = key.program;
    semester = key.semester;
    section = key.section;
  }

  String? _resolveBatch() {
    if (program == null || semester == null || section == null) {
      return null;
    }

    for (final batch in widget.memory.allBatches) {
      final key = BatchKey.parse(batch);
      if (key.program == program &&
          key.semester == semester &&
          key.section == section) {
        return batch;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Filter out batch-like programs (FA##, SP##, etc.) - show only actual programs
    final programs = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toList();
    final semesters = program == null
        ? <int>[]
        : widget.memory.semesters(program!);
    final sections = (program != null && semester != null)
        ? widget.memory.sections(program!, semester!)
        : <String>[];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.07),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.80),
                      Colors.white.withValues(alpha: 0.60),
                    ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.70),
              width: isDark ? 1.5 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: IrisTokens.brand.withValues(alpha: isDark ? 0.14 : 0.10),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: (isDark ? Colors.black : Colors.black.withValues(alpha: 0.5))
                    .withValues(alpha: 0.18),
                blurRadius: 28,
                spreadRadius: -10,
                offset: const Offset(0, 16),
              ),
              if (isDark)
                BoxShadow(
                  color: IrisTokens.brand.withValues(alpha: 0.06),
                  blurRadius: 20,
                  spreadRadius: -8,
                ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -12,
                left: -12,
                child: IgnorePointer(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.16 : 0.24),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -16,
                right: -16,
                child: IgnorePointer(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.14 : 0.20),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [IrisTokens.brand, IrisTokens.brandLight],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: IrisTokens.brand.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Batch Resolver',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Configure your academic profile',
                              style: TextStyle(
                                fontSize: 14,
                                letterSpacing: 0.3,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _EnhancedDropDownRow(
                    label: 'Program',
                    value: program,
                    items: programs,
                    icon: Icons.school_rounded,
                    onChanged: (value) => setState(() {
                      program = value;
                      semester = null;
                      section = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _EnhancedDropDownRow(
                    label: 'Semester',
                    value: semester?.toString(),
                    items: semesters.map((e) => e.toString()).toList(),
                    icon: Icons.calendar_month_rounded,
                    onChanged: (value) => setState(() {
                      semester = int.tryParse(value ?? '');
                      section = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _EnhancedDropDownRow(
                    label: 'Section',
                    value: section,
                    items: sections,
                    icon: Icons.group_rounded,
                    onChanged: (value) => setState(() => section = value),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient:
                                (program != null &&
                                    semester != null &&
                                    section != null)
                                ? const LinearGradient(
                                    colors: [
                                      IrisTokens.brand,
                                      IrisTokens.brandLight,
                                    ],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow:
                                (program != null &&
                                    semester != null &&
                                    section != null)
                                ? [
                                    BoxShadow(
                                      color: IrisTokens.brand.withValues(alpha: 0.4),
                                      blurRadius: 5,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed:
                                (program != null &&
                                    semester != null &&
                                    section != null)
                                ? () {
                                    final batch = _resolveBatch();
                                    if (batch == null) return;
                                    IrisHaptics.chipSelect();
                                    Navigator.pop(context, batch);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.08),
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Apply Changes',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnhancedDropDownRow extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _EnhancedDropDownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.10),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black.withValues(alpha: 0.5))
                .withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: IrisTokens.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: IrisTokens.brand, size: 20),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                hint: Text(
                  'Select',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                dropdownColor: isDark
                    ? IrisTokens.surfaceDarkElevated
                    : Colors.white,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
