import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import '../core/vital_theme.dart';
import 'glowing_input_wrapper.dart';
import '../core/tokens.dart';
import '../core/glass.dart';
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
  String? intake;
  String? section;
  String rollNo = '';

  @override
  void initState() {
    super.initState();
    final seed = widget.selected.trim().isNotEmpty
        ? widget.selected.trim()
        : (widget.memory.allBatches.isNotEmpty ? widget.memory.allBatches.first : '');
    final key = BatchKey.parse(seed);
    program = key.program;
    intake = (key.intake.isNotEmpty && key.intake != 'UNKNOWN' && key.intake != 'NA')
        ? key.intake
        : null;
    section = key.section;
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          rollNo = prefs.getString('student_roll_no') ?? '';
        });
      }
    });
  }

  String? _resolveBatch() {
    if (program == null || section == null) {
      return null;
    }

    final progUpper = program!.toUpperCase().trim();
    final intakeUpper = intake?.toUpperCase().trim();
    final secUpper = section!.toUpperCase().trim();

    // 1. Exact match with program, intake, and section
    for (final batch in widget.memory.allBatches) {
      final key = BatchKey.parse(batch);
      if (key.program.toUpperCase().trim() == progUpper &&
          (intakeUpper == null || key.intake.toUpperCase().trim() == intakeUpper) &&
          key.section.toUpperCase().trim() == secUpper) {
        return batch;
      }
    }

    // 2. Program + section match (handles cohort batches like BBA-B21, BME-01)
    for (final batch in widget.memory.allBatches) {
      final key = BatchKey.parse(batch);
      if (key.program.toUpperCase().trim() == progUpper &&
          key.section.toUpperCase().trim() == secUpper) {
        return batch;
      }
    }

    // 3. Construct canonical batch string
    if (intakeUpper != null) {
      final sem = BatchKey.calculateSemester(intakeUpper);
      return '$progUpper-$sem$secUpper';
    }
    return '$progUpper-$secUpper';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final screenHeight = mediaQuery.size.height;

    // Filter out batch-like programs (FA##, SP##, etc.) - show only actual programs
    final programs = widget.memory
        .programs()
        .where((p) => !RegExp(r'^(FA|SP)\d{2}$').hasMatch(p))
        .toList();
    final intakes = program == null
        ? <String>[]
        : widget.memory.intakes(program!);
    final sections = (program != null && intake != null)
        ? widget.memory.sectionsForIntake(program!, intake!)
        : (program != null ? widget.memory.sectionsForIntake(program!, '') : <String>[]);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sheet Header Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [IrisTokens.brand, IrisTokens.brandLight],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: IrisTokens.brand.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Batch Resolver',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Configure your academic profile',
                    style: TextStyle(
                      fontSize: 13,
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Fields Layout: 2-column in Landscape, 1-column in Portrait
        if (isLandscape)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _HorizontalChipSelector(
                      label: 'Program',
                      selectedValue: program,
                      items: programs,
                      icon: Icons.school_rounded,
                      onSelected: (value) => setState(() {
                        program = value;
                        intake = null;
                        section = null;
                      }),
                    ),
                    const SizedBox(height: 14),
                    _HorizontalChipSelector(
                      label: 'Batch / Intake',
                      selectedValue: intake,
                      items: intakes,
                      itemLabelBuilder: (item) {
                        final sem = BatchKey.calculateSemester(item);
                        return '$item · Semester $sem';
                      },
                      icon: Icons.calendar_month_rounded,
                      placeholderText: program == null ? 'Select program first' : 'No batches found',
                      onSelected: (value) => setState(() {
                        intake = value;
                        section = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _HorizontalChipSelector(
                      label: 'Section',
                      selectedValue: section,
                      items: sections,
                      icon: Icons.group_rounded,
                      placeholderText: intake == null ? 'Select batch first' : 'No sections found',
                      onSelected: (value) => setState(() => section = value),
                    ),
                    const SizedBox(height: 14),
                    _RollNumberInputField(
                      rollNo: rollNo,
                      onChanged: (newRoll) {
                        setState(() => rollNo = newRoll);
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setString('student_roll_no', newRoll);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _HorizontalChipSelector(
            label: 'Program',
            selectedValue: program,
            items: programs,
            icon: Icons.school_rounded,
            onSelected: (value) => setState(() {
              program = value;
              intake = null;
              section = null;
            }),
          ),
          const SizedBox(height: 16),
          _HorizontalChipSelector(
            label: 'Batch / Intake',
            selectedValue: intake,
            items: intakes,
            itemLabelBuilder: (item) {
              final sem = BatchKey.calculateSemester(item);
              return '$item · Semester $sem';
            },
            icon: Icons.calendar_month_rounded,
            placeholderText: program == null ? 'Select program first' : 'No batches found',
            onSelected: (value) => setState(() {
              intake = value;
              section = null;
            }),
          ),
          const SizedBox(height: 16),
          _HorizontalChipSelector(
            label: 'Section',
            selectedValue: section,
            items: sections,
            icon: Icons.group_rounded,
            placeholderText: intake == null ? 'Select batch first' : 'No sections found',
            onSelected: (value) => setState(() => section = value),
          ),
          const SizedBox(height: 16),
          _RollNumberInputField(
            rollNo: rollNo,
            onChanged: (newRoll) {
              setState(() => rollNo = newRoll);
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('student_roll_no', newRoll);
              });
            },
          ),
        ],

        const SizedBox(height: 22),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
                  gradient: (program != null && intake != null && section != null)
                      ? const LinearGradient(
                          colors: [
                            IrisTokens.brand,
                            IrisTokens.brandLight,
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: (program != null && intake != null && section != null)
                      ? [
                          BoxShadow(
                            color: IrisTokens.brand.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: (program != null && intake != null && section != null)
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: mediaQuery.viewInsets.bottom + 16,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: screenHeight * (isLandscape ? 0.92 : 0.85),
            ),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.04),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.85),
                        Colors.white.withValues(alpha: 0.65),
                      ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.60),
                width: isDark ? 1.5 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: IrisTokens.brand.withValues(alpha: isDark ? 0.14 : 0.10),
                  blurRadius: 18,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizontalChipSelector extends StatelessWidget {
  final String label;
  final String? selectedValue;
  final List<String> items;
  final IconData icon;
  final String placeholderText;
  final ValueChanged<String> onSelected;
  final String Function(String item)? itemLabelBuilder;

  const _HorizontalChipSelector({
    required this.label,
    required this.selectedValue,
    required this.items,
    required this.icon,
    this.placeholderText = 'No options available',
    required this.onSelected,
    this.itemLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: IrisTokens.brand, size: 16),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
                letterSpacing: 1.5,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        items.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  placeholderText,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                ),
              )
            : lgw.GlassMenu(
                autoAdjustToScreen: true,
                menuPadding: const EdgeInsets.all(16),
                menuWidth: MediaQuery.sizeOf(context).width - 48,
                menuHeight: math.min(items.length * 52.0 + 16.0, 320.0),
                menuBorderRadius: 28.0,
                itemBorderRadius: 20.0,
                settings: IrisGlass.widgetsSettings(
                  context,
                  blur: 16.0,
                  ambientStrength: 0.7,
                  lightAngle: 0.15 * math.pi,
                  thickness: 18.0,
                ),
                triggerBuilder: (context, toggleMenu) {
                  final displayText = selectedValue != null
                      ? (itemLabelBuilder != null ? itemLabelBuilder!(selectedValue!) : selectedValue!)
                      : 'Select $label';
                  final hasValue = selectedValue != null;
                  return InkWell(
                    onTap: () {
                      IrisHaptics.actionSoft();
                      toggleMenu();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: hasValue
                            ? IrisTokens.brand.withValues(alpha: isDark ? 0.12 : 0.06)
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasValue
                              ? IrisTokens.brand.withValues(alpha: isDark ? 0.40 : 0.30)
                              : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08)),
                          width: hasValue ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: hasValue 
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark ? Colors.white38 : Colors.black38),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: hasValue ? IrisTokens.brand : (isDark ? Colors.white54 : Colors.black45),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                items: items.map((String val) {
                  final title = itemLabelBuilder != null ? itemLabelBuilder!(val) : val;
                  final isSelected = val == selectedValue;
                  return lgw.GlassMenuItem(
                    title: title,
                    titleStyle: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                      color: isSelected ? IrisTokens.brand : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
                    ),
                    isSelected: isSelected,
                    icon: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: isSelected ? IrisTokens.brand : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    onTap: () {
                      IrisHaptics.chipSelect();
                      onSelected(val);
                    },
                  );
                }).toList(),
              ),
      ],
    );
  }
}

class _RollNumberInputField extends StatefulWidget {
  final String rollNo;
  final ValueChanged<String> onChanged;

  const _RollNumberInputField({
    required this.rollNo,
    required this.onChanged,
  });

  @override
  State<_RollNumberInputField> createState() => _RollNumberInputFieldState();
}

class _RollNumberInputFieldState extends State<_RollNumberInputField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.rollNo);
  }

  @override
  void didUpdateWidget(covariant _RollNumberInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rollNo != oldWidget.rollNo && widget.rollNo != _controller.text) {
      _controller.text = widget.rollNo;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.badge_rounded, color: IrisTokens.brand, size: 16),
            const SizedBox(width: 8),
            Text(
              'ROLL NUMBER (3 DIGITS)',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
                letterSpacing: 1.5,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        IrisGlowingInputWrapper(
          borderRadius: 16.0,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 3,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'e.g. 042',
              hintStyle: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
              border: InputBorder.none,
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel_rounded, size: 18),
                      color: isDark ? Colors.white54 : Colors.black45,
                      onPressed: () {
                        IrisHaptics.actionSoft();
                        _controller.clear();
                        widget.onChanged('');
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              final numericVal = val.replaceAll(RegExp(r'\D'), '');
              if (numericVal != val) {
                _controller.value = TextEditingValue(
                  text: numericVal,
                  selection: TextSelection.collapsed(offset: numericVal.length),
                );
              }
              widget.onChanged(numericVal);
            },
          ),
        ),
      ],
    );
  }
}
