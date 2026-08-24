import 'package:flutter/material.dart';
import '../widgets/exam_schedule_view.dart';
import '../services/ui_feedback.dart';

class ExamGridDashboard extends StatelessWidget {
  final String period;
  final String batch;
  final VoidCallback onToggleTheme;

  const ExamGridDashboard({
    required this.period,
    required this.batch,
    required this.onToggleTheme,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Back Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      period == 'midterms' ? 'Midterm Examinations' : 'Final Examinations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        IrisHaptics.selectionClick();
                        onToggleTheme();
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          size: 16,
                          color: isDark ? Colors.amber : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Embedded High-Performance Exam Schedule View
              ExamScheduleView(
                period: period,
                batch: batch,
                showHeroBanner: true,
                onToggleTheme: onToggleTheme,
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
