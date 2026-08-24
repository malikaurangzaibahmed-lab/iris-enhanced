import 'package:flutter/material.dart';
import '../services/ui_feedback.dart';

class ExamStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String batch;
  final String period; // 'midterms' or 'finals'
  final int daysToNextExam;
  final String? nextExamSubject;
  final int totalExams;
  final int completedExams;
  final int todayExams;
  final VoidCallback? onGuidelinesTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onRefresh;

  const ExamStickyHeaderDelegate({
    required this.batch,
    required this.period,
    required this.daysToNextExam,
    required this.nextExamSubject,
    required this.totalExams,
    required this.completedExams,
    required this.todayExams,
    this.onGuidelinesTap,
    this.onShareTap,
    this.onRefresh,
  });

  @override
  double get minExtent => 82.0;

  @override
  double get maxExtent => 130.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMidterms = period == 'midterms';
    final accentColor = isMidterms ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6);
    final periodTitle = isMidterms ? 'MIDTERM EXAMS' : 'FINAL EXAMS';

    String countdownBadge;
    if (totalExams == 0) {
      countdownBadge = 'NO EXAMS SCHEDULED';
    } else if (completedExams >= totalExams) {
      countdownBadge = 'ALL EXAMS COMPLETED 🎉';
    } else if (todayExams > 0) {
      countdownBadge = 'EXAM TODAY 🔥';
    } else if (daysToNextExam == 0) {
      countdownBadge = 'EXAM TODAY 🔥';
    } else if (daysToNextExam == 1) {
      countdownBadge = 'TOMORROW ⚡';
    } else if (daysToNextExam > 1) {
      countdownBadge = 'IN $daysToNextExam DAYS';
    } else {
      countdownBadge = 'UPCOMING';
    }

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF090D16).withValues(alpha: 0.94)
              : const Color(0xFFF8FAFC).withValues(alpha: 0.94),
          border: Border(
            bottom: BorderSide(
              color: accentColor.withValues(
                alpha: 0.12 + 0.18 * progress,
              ),
              width: 1.0,
            ),
          ),
          boxShadow: [
            if (shrinkOffset > 4)
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                blurRadius: 14 * progress,
                offset: Offset(0, 4 * progress),
              ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Main Top Bar
            Row(
              children: [
                // Glowing Mode Icon Capsule
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    isMidterms ? Icons.edit_note_rounded : Icons.workspace_premium_rounded,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Batch Capsule
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            periodTitle,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              batch,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextExamSubject != null && completedExams < totalExams
                            ? (todayExams > 0 ? 'Today: $nextExamSubject' : 'Next: $nextExamSubject')
                            : (completedExams >= totalExams && totalExams > 0
                                ? 'All $totalExams examinations completed'
                                : 'COMSATS Examination Hub'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5 - (1.5 * progress),
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Quick Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onShareTap != null)
                      IconButton(
                        tooltip: 'Share Date Sheet',
                        onPressed: () {
                          IrisHaptics.selectionClick();
                          onShareTap!();
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                            ),
                          ),
                          child: Icon(
                            Icons.share_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    if (onGuidelinesTap != null)
                      IconButton(
                        tooltip: 'Exam Hall Guidelines',
                        onPressed: () {
                          IrisHaptics.selectionClick();
                          onGuidelinesTap!();
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.fact_check_rounded,
                            size: 16,
                            color: accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Secondary Progress Banner (Collapsed dynamically on scroll)
            if (progress < 0.8)
              Opacity(
                opacity: (1.0 - (progress * 1.25)).clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Row(
                    children: [
                      // Countdown Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: (todayExams > 0
                              ? const Color(0xFFF43F5E)
                              : accentColor).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (todayExams > 0
                                ? const Color(0xFFF43F5E)
                                : accentColor).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          countdownBadge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: todayExams > 0 ? const Color(0xFFF43F5E) : accentColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Metric Pill
                      Text(
                        '$completedExams / $totalExams Done',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                        ),
                      ),
                      const Spacer(),

                      // Sync / Refresh
                      if (onRefresh != null)
                        InkWell(
                          onTap: onRefresh,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.sync_rounded,
                                  size: 12,
                                  color: (isDark ? Colors.white54 : Colors.black45),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Live Cloud',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: (isDark ? Colors.white54 : Colors.black45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant ExamStickyHeaderDelegate oldDelegate) {
    return oldDelegate.batch != batch ||
        oldDelegate.period != period ||
        oldDelegate.daysToNextExam != daysToNextExam ||
        oldDelegate.nextExamSubject != nextExamSubject ||
        oldDelegate.totalExams != totalExams ||
        oldDelegate.completedExams != completedExams ||
        oldDelegate.todayExams != todayExams;
  }
}
