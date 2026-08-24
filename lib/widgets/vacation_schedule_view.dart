import 'package:flutter/material.dart';
import '../core/omni_brain.dart';
import '../core/models.dart';
import '../services/ui_feedback.dart';
import '../services/helpdesk_schedule_data_service.dart';
import '../widgets/glass_card.dart';

/// Full scrollable view containing Upcoming Semester Schedule, Milestones,
/// Enrolled Courses list, and Break Utilities.
class VacationScheduleView extends StatelessWidget {
  final String batch;
  final OmniBrain brain;
  final List<dynamic>? milestones;
  final VoidCallback? onOpenPortal;
  final VoidCallback? onOpenCgpa;

  const VacationScheduleView({
    super.key,
    required this.batch,
    required this.brain,
    this.milestones,
    this.onOpenPortal,
    this.onOpenCgpa,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final schedule = brain.scheduleFor(batch);

    // Extract unique courses for this batch
    final uniqueCourses = <String, ClassSession>{};
    for (final s in schedule) {
      if (!uniqueCourses.containsKey(s.subject)) {
        uniqueCourses[s.subject] = s;
      }
    }

    final coursesList = uniqueCourses.values.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: Color(0xFFF43F5E),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Upcoming Semester Schedule',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Milestone Timeline
          _buildMilestoneTimeline(context, isDark),

          const SizedBox(height: 24),

          // Enrolled / Projected Courses Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Color(0xFF0EA5E9),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Projected Courses ($batch)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Courses List
          if (coursesList.isEmpty)
            _buildEmptyCoursesCard(isDark)
          else
            ...coursesList.map((course) => _buildCourseCard(course, isDark)),

          const SizedBox(height: 24),

          // Quick Break Utilities
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Vacation Utilities',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildUtilitiesBento(context, isDark),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMilestoneTimeline(BuildContext context, bool isDark) {
    final List<Map<String, dynamic>> rawList;

    if (milestones != null && milestones!.isNotEmpty) {
      rawList = milestones!.map((m) {
        if (m is Map) {
          final title = m['title']?.toString() ?? '';
          final date = m['date']?.toString() ?? m['timeline']?.toString() ?? '';
          final desc = m['desc']?.toString() ?? '';
          final status = m['status']?.toString() ?? '';
          final category = m['category']?.toString() ?? '';
          final level = m['level']?.toString() ?? '';

          return {
            'date': date,
            'title': title,
            'desc': desc,
            'level': level,
            'status': status,
            'category': category,
            'icon': _iconForCategory(category, title),
          };
        }
        return <String, dynamic>{
          'date': '',
          'title': m.toString(),
          'desc': '',
          'level': '',
          'status': 'upcoming',
          'category': 'General',
          'icon': Icons.event_note_rounded,
        };
      }).toList();
    } else {
      rawList = [
        {
          'date': 'Aug 31 – Sep 4, 2026 (Mon–Fri)',
          'title': 'Registration Week',
          'level': 'Undergraduate & Graduate',
          'desc': 'Course enrollment & advisor approvals',
          'status': 'upcoming',
          'category': 'Registration',
          'icon': Icons.app_registration_rounded,
        },
        {
          'date': 'Sep 7, 2026 (Mon)',
          'title': 'Commencement of Classes',
          'level': 'Undergraduate & Graduate',
          'desc': 'First day of lectures for Fall 2026',
          'status': 'upcoming',
          'category': 'Classes',
          'icon': Icons.school_rounded,
        },
        {
          'date': 'Oct 2, 2026 (Fri)',
          'title': 'Last Date for Drop of Courses',
          'level': 'Undergraduate & Graduate',
          'desc': 'Official course drop deadline without penalty',
          'status': 'upcoming',
          'category': 'Classes',
          'icon': Icons.remove_circle_outline_rounded,
        },
        {
          'date': 'Oct 23, 2026 (Fri)',
          'title': 'Last Date for Withdrawal',
          'level': 'Undergraduate & Graduate',
          'desc': 'Final deadline for course withdrawal (W grade)',
          'status': 'upcoming',
          'category': 'Classes',
          'icon': Icons.block_rounded,
        },
        {
          'date': 'Nov 2, 2026 (Mon)',
          'title': 'Mid-Term Examination Start Date',
          'level': 'Undergraduate & Graduate',
          'desc': 'Official Mid-Semester Exams commencement',
          'status': 'upcoming',
          'category': 'Exams',
          'icon': Icons.edit_calendar_rounded,
        },
        {
          'date': 'Nov 9–14, 2026 (Mon–Sat)',
          'title': 'Student Week',
          'level': 'Undergraduate & Graduate',
          'desc': 'Annual sports, culture, and co-curricular gala',
          'status': 'upcoming',
          'category': 'Events',
          'icon': Icons.emoji_events_rounded,
        },
        {
          'date': 'Dec 28, 2026 (Mon)',
          'title': 'Final Year Project Submission',
          'level': 'Undergraduate',
          'desc': 'Undergraduate FYP final evaluation submission',
          'status': 'upcoming',
          'category': 'Classes',
          'icon': Icons.laptop_chromebook_rounded,
        },
        {
          'date': 'Dec 28, 2026 (Mon)',
          'title': 'MS Thesis Submission',
          'level': 'Graduate',
          'desc': 'Postgraduate thesis submission to department',
          'status': 'upcoming',
          'category': 'Classes',
          'icon': Icons.auto_stories_rounded,
        },
        {
          'date': 'Dec 28, 2026 (Mon)',
          'title': 'Last Day for Classes',
          'level': 'Undergraduate & Graduate',
          'desc': 'Conclusion of regular academic teaching',
          'status': 'upcoming',
          'category': 'Classes',
          'icon': Icons.stop_circle_rounded,
        },
        {
          'date': 'Dec 31, 2026 (Thu)',
          'title': 'Terminal Exam Start Date',
          'level': 'Undergraduate & Graduate',
          'desc': 'Fall 2026 Final Terminal Examinations',
          'status': 'upcoming',
          'category': 'Exams',
          'icon': Icons.history_edu_rounded,
        },
        {
          'date': 'Jan 28, 2027 (Thu)',
          'title': 'Declaration of Results',
          'level': 'Undergraduate & Graduate',
          'desc': 'Official portal result announcement',
          'status': 'upcoming',
          'category': 'Registration',
          'icon': Icons.analytics_rounded,
        },
        {
          'date': 'One week before Spring 2027',
          'title': 'PhD Thesis Submission',
          'level': 'Graduate',
          'desc': 'Doctoral thesis submission deadline',
          'status': 'upcoming',
          'category': 'Registration',
          'icon': Icons.workspace_premium_rounded,
        },
        {
          'date': 'Feb 15, 2027 (Mon)',
          'title': 'Final Result Notification',
          'level': 'Undergraduate & Graduate',
          'desc': 'Final notification and transcript processing',
          'status': 'upcoming',
          'category': 'Registration',
          'icon': Icons.verified_rounded,
        },
      ];
    }

    final items = rawList.map((m) {
      final dateStr = (m['date'] as String?) ?? '';
      final explicitStatus = (m['status'] as String?) ?? '';
      final dynamicStatus = SemesterMilestoneEvaluator.evaluateStatus(
        dateStr,
        explicitStatus: explicitStatus,
      );
      final isDone = dynamicStatus == 'completed';
      final isActive = dynamicStatus == 'active';

      return {
        ...m,
        'dynamicStatus': dynamicStatus,
        'isDone': isDone,
        'isActive': isActive,
      };
    }).toList();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20.0,
      child: Column(
        children: List.generate(items.length, (index) {
          final m = items[index];
          final isLast = index == items.length - 1;
          final isDone = m['isDone'] as bool;
          final isActive = m['isActive'] as bool;
          final level = (m['level'] as String?) ?? '';

          final Color circleColor;
          final Color borderColor;
          final IconData iconData;
          final Color iconColor;

          if (isDone) {
            circleColor = const Color(0xFF10B981);
            borderColor = const Color(0xFF6EE7B7);
            iconData = Icons.check;
            iconColor = Colors.white;
          } else if (isActive) {
            circleColor = const Color(0xFF06B6D4);
            borderColor = const Color(0xFF67E8F9);
            iconData = Icons.play_arrow_rounded;
            iconColor = Colors.white;
          } else {
            circleColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
            borderColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
            iconData = m['icon'] as IconData;
            iconColor = isDark ? Colors.white70 : Colors.black87;
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline indicator
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: circleColor,
                        border: Border.all(
                          color: borderColor,
                          width: isActive ? 2.0 : 1.5,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Icon(
                        iconData,
                        size: 13,
                        color: iconColor,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: isDone
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (level.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: (isDark ? const Color(0xFF06B6D4) : const Color(0xFF0891B2)).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: (isDark ? const Color(0xFF06B6D4) : const Color(0xFF0891B2)).withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  level,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                m['date'] as String,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDone
                                      ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
                                      : (isActive ? const Color(0xFF06B6D4) : const Color(0xFFF43F5E)),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isDone) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, size: 10, color: Color(0xFF10B981)),
                                    SizedBox(width: 3),
                                    Text(
                                      'COMPLETED',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'ACTIVE NOW',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF06B6D4),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          m['title'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            decorationColor: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            color: isDone
                                ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
                                : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                        if ((m['desc'] as String).isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            m['desc'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDone
                                  ? (isDark ? Colors.white24 : const Color(0xFFCBD5E1))
                                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  IconData _iconForCategory(String? category, String? title) {
    final cat = (category ?? '').toLowerCase();
    final t = (title ?? '').toLowerCase();
    if (cat.contains('exam') || t.contains('exam') || t.contains('mid') || t.contains('final')) {
      return Icons.edit_note_rounded;
    } else if (cat.contains('class') || t.contains('class') || t.contains('lecture')) {
      return Icons.school_rounded;
    } else if (cat.contains('reg') || t.contains('reg') || t.contains('enroll')) {
      return Icons.app_registration_rounded;
    } else if (cat.contains('event') || cat.contains('sport') || t.contains('sport') || t.contains('gala')) {
      return Icons.emoji_events_rounded;
    } else if (cat.contains('holiday') || t.contains('break') || t.contains('eid') || t.contains('vacation')) {
      return Icons.beach_access_rounded;
    } else if (t.contains('fee') || t.contains('pay') || t.contains('due')) {
      return Icons.payment_rounded;
    } else if (t.contains('orient') || t.contains('fair') || t.contains('club')) {
      return Icons.diversity_3_rounded;
    }
    return Icons.event_note_rounded;
  }

  Widget _buildCourseCard(ClassSession course, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 16.0,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF0EA5E9),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.subject,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    course.teacher.isNotEmpty ? course.teacher : 'Faculty Assigned',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                course.room.isNotEmpty ? course.room : 'Lab/Room',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCoursesCard(bool isDark) {
    return const GlassCard(
      padding: EdgeInsets.all(18),
      borderRadius: 16.0,
      child: Center(
        child: Text(
          'Course registrations will appear as the semester approaches',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildUtilitiesBento(BuildContext context, bool isDark) {
    return Row(
      children: [
        // Grade Portal
        Expanded(
          child: InkWell(
            onTap: () {
              IrisHaptics.chipSelect();
              onOpenPortal?.call();
            },
            borderRadius: BorderRadius.circular(16),
            child: const GlassCard(
              padding: EdgeInsets.all(14),
              borderRadius: 16.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.folder_shared_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Grade Portal',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'View Transcripts',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // CGPA Goal Simulator
        Expanded(
          child: InkWell(
            onTap: () {
              IrisHaptics.chipSelect();
              onOpenCgpa?.call();
            },
            borderRadius: BorderRadius.circular(16),
            child: const GlassCard(
              padding: EdgeInsets.all(14),
              borderRadius: 16.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.calculate_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'GPA Target',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Goal Simulator',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
