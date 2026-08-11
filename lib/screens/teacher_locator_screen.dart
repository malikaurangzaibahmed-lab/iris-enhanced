import 'package:flutter/material.dart';
import '../core/omni_brain.dart';
import '../core/models.dart';
import 'faculty_directory_screen.dart';

/// Unified Teacher Locator Screen
/// Delegates directly to [FacultyDirectoryScreen] so all existing navigation calls,
/// deep links, and tool shortcuts continue working 100% seamlessly.
class TeacherLocatorScreen extends StatelessWidget {
  final OmniBrain brain;
  final ValueChanged<String>? onTeacherSelected;
  final ValueChanged<String>? onRoleChanged;
  final ValueChanged<String>? onBatchChanged;
  final UniversityMemory? memory;
  final String? currentBatch;
  final String? initialTeacherQuery;
  final bool autoSearchInitial;
  final bool showDock;
  final bool showBackButton;
  final bool closeOnTeacherSelect;

  const TeacherLocatorScreen({
    required this.brain,
    this.onTeacherSelected,
    this.onRoleChanged,
    this.onBatchChanged,
    this.memory,
    this.currentBatch,
    this.initialTeacherQuery,
    this.autoSearchInitial = false,
    this.showDock = true,
    this.showBackButton = true,
    this.closeOnTeacherSelect = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FacultyDirectoryScreen(
      brain: brain,
      onTeacherSelected: (teacher) {
        if (onTeacherSelected != null) {
          onTeacherSelected!(teacher);
        }
        if (closeOnTeacherSelect) {
          Navigator.maybePop(context);
        }
      },
      onRoleChanged: onRoleChanged,
      onBatchChanged: onBatchChanged,
      memory: memory,
      currentBatch: currentBatch,
      initialTeacherQuery: initialTeacherQuery,
    );
  }
}
