import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../widgets/glass_card.dart';
import '../services/ui_feedback.dart';
import '../services/remote_config_service.dart';
import '../screens/portal_screen.dart';
import '../screens/room_finder_screen.dart';
import '../core/omni_brain.dart';

// ============================================================================
// 1. FACULTY VACATION & RECESS VIEW (USES REAL REMOTE CONFIG DATA)
// ============================================================================

class FacultyVacationView extends StatelessWidget {
  final String teacherName;
  final VoidCallback? onRefresh;

  const FacultyVacationView({
    required this.teacherName,
    this.onRefresh,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFFF43F5E);
    final vacationSchedule = RemoteConfigService.vacationSchedule.value;
    final resumptionDateStr = vacationSchedule?['resumption_date']?.toString() ?? '2026-09-01';
    final targetSemester = vacationSchedule?['target_semester']?.toString() ?? 'Fall 2026';

    int daysLeft = 0;
    try {
      final targetDate = DateTime.parse(resumptionDateStr);
      final today = DateTime.now();
      daysLeft = targetDate.difference(DateTime(today.year, today.month, today.day)).inDays;
    } catch (_) {
      daysLeft = 7;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Academic Recess Status Card
          GlassCard(
            borderRadius: 24,
            accentColor: accentColor,
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.35 : 0.2),
              width: 1.2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.beach_access_rounded,
                        color: accentColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SEMESTER BREAK / RECESS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            daysLeft > 0
                                ? '$daysLeft days until $targetSemester classes resume'
                                : '$targetSemester preparation active',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Regular lectures are on recess. Faculty members can access the CUOnline portal for grade submissions, attendance finalization, and academic planning.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Faculty Quick Actions
          Text(
            'FACULTY TOOLS & PORTAL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white60 : Colors.black54,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildShortcutCard(
                  context,
                  isDark: isDark,
                  icon: Icons.grade_rounded,
                  title: 'Faculty Portal',
                  subtitle: 'Marks & Grades',
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    IrisHaptics.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PortalScreen(
                          url: 'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
                          title: 'CUOnline Faculty Portal',
                          sessionScope: 'faculty',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildShortcutCard(
                  context,
                  isDark: isDark,
                  icon: Icons.fact_check_rounded,
                  title: 'Attendance',
                  subtitle: 'Register Submission',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    IrisHaptics.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PortalScreen(
                          url: 'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
                          title: 'Attendance Submission',
                          sessionScope: 'faculty',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildShortcutCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: GlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2. FACULTY EXAM PERIOD VIEW (REAL DATA & EXAM TOOLS)
// ============================================================================

class FacultyExamPeriodView extends StatelessWidget {
  final String teacherName;
  final String period; // 'midterms' or 'finals'
  final OmniBrain brain;

  const FacultyExamPeriodView({
    required this.teacherName,
    required this.period,
    required this.brain,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMidterms = period == 'midterms';
    final accentColor = isMidterms ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6);
    final periodTitle = isMidterms ? 'MIDTERM EXAMINATIONS' : 'FINAL EXAMINATIONS';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Examination Active Card
          GlassCard(
            borderRadius: 24,
            accentColor: accentColor,
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.35 : 0.2),
              width: 1.2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isMidterms ? Icons.edit_note_rounded : Icons.workspace_premium_rounded,
                        color: accentColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$periodTitle ACTIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Regular Lecture Timetable Paused',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Regular academic lectures and laboratory sessions are suspended across campus during examination weeks for official examination sessions.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Faculty Examination Tools
          Text(
            'EXAMINATION TOOLS & HALL NAVIGATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white60 : Colors.black54,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    IrisHaptics.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomFinderScreen(
                          brain: brain,
                          memory: brain.memory,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: GlassCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.meeting_room_rounded,
                            color: Color(0xFF0EA5E9),
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Exam Rooms & Halls',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Campus Hall Finder',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    IrisHaptics.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PortalScreen(
                          url: 'https://faculty.comsats.edu.pk/Home/login?returnUrl=https://faculty.comsats.edu.pk/',
                          title: 'CUOnline Faculty Portal',
                          sessionScope: 'faculty',
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: GlassCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.cloud_done_rounded,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Faculty Portal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Exam Submissions',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
