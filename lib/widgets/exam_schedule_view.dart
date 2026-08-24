import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models.dart';
import '../core/format_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/glowing_input_wrapper.dart';
import '../services/ui_feedback.dart';
import '../services/remote_config_service.dart';
import '../screens/students_week_screen.dart';
import '../screens/room_finder_screen.dart';

enum ExamFilterType { all, upcoming, today, completed }

/// High-Performance 120 FPS Exam Timeline & Dashboard View
/// Used seamlessly on both the Home Screen during Exam Modes
/// and inside the standalone Date Sheet screen.
class ExamScheduleView extends StatefulWidget {
  final String period; // 'midterms' or 'finals'
  final String batch;
  final bool showHeroBanner;
  final VoidCallback? onToggleTheme;

  const ExamScheduleView({
    required this.period,
    required this.batch,
    this.showHeroBanner = true,
    this.onToggleTheme,
    super.key,
  });

  @override
  State<ExamScheduleView> createState() => _ExamScheduleViewState();
}

class _ExamScheduleViewState extends State<ExamScheduleView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ExamFilterType _activeFilter = ExamFilterType.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _parseExamDate(String dateStr) {
    return FormatGuard.parseDate(dateStr);
  }

  String _getExamStatus(DateTime? examDate) {
    if (examDate == null) return 'UPCOMING';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);

    if (examDay.isBefore(today)) {
      return 'COMPLETED';
    } else if (examDay.isAtSameMomentAs(today)) {
      return 'TODAY';
    } else {
      return 'UPCOMING';
    }
  }

  String _formatExamDate(String rawDate) {
    final parts = rawDate.split(' ');
    if (parts.length < 2) return rawDate;
    final weekday = parts[0];
    final datePart = parts[1];
    final dmyRegex = RegExp(r'(\d{2})-(\d{2})-(\d{4})');
    final match = dmyRegex.firstMatch(datePart);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '$weekday, ${months[month - 1]} $day, $year';
    }
    final dmyShortRegex = RegExp(r'(\d{2})-(\d{2})-(\d{2})');
    final matchShort = dmyShortRegex.firstMatch(datePart);
    if (matchShort != null) {
      final day = int.parse(matchShort.group(1)!);
      final month = int.parse(matchShort.group(2)!);
      final shortYear = int.parse(matchShort.group(3)!);
      final year = 2000 + shortYear;
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '$weekday, ${months[month - 1]} $day, $year';
    }
    return rawDate;
  }

  String _formatExamTime(String rawTime) {
    final timeRegex = RegExp(r'(\d{1,2}):?(\d{2})\s*-\s*(\d{1,2}):?(\d{2})');
    final match = timeRegex.firstMatch(rawTime);
    if (match != null) {
      String formatPart(String hr, String min) {
        int h = int.parse(hr);
        if (h >= 1 && h <= 8) h += 12;
        final ampm = h >= 12 ? 'PM' : 'AM';
        if (h > 12) h -= 12;
        if (h == 0) h = 12;
        return '$h:${min.padLeft(2, '0')} $ampm';
      }
      return '${formatPart(match.group(1)!, match.group(2)!)} - ${formatPart(match.group(3)!, match.group(4)!)}';
    }
    return rawTime;
  }

  void _copyFullDateSheet(List<Map<String, dynamic>> allExams, String titleText) {
    if (allExams.isEmpty) {
      showIrisFrostedSnackBar(context, content: const Text('No exams to share'));
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('📅 *COMSATS UNIVERSITY ISLAMABAD - SWL*');
    buffer.writeln('🎓 *$titleText DATE SHEET - ${widget.batch}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');

    for (int i = 0; i < allExams.length; i++) {
      final e = allExams[i];
      final date = _formatExamDate(e['date'] ?? '');
      final time = _formatExamTime(e['time'] ?? '');
      final subject = e['subject'] ?? 'Exam';
      final rooms = (e['rooms'] as List?)?.join(', ') ?? '';

      buffer.writeln('${i + 1}. *$subject*');
      buffer.writeln('   📆 Date: $date');
      buffer.writeln('   ⏰ Time: $time');
      if (rooms.isNotEmpty) buffer.writeln('   🏛️ Hall: $rooms');
      if (i < allExams.length - 1) buffer.writeln('────────────────────');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('✨ Shared via IRIS Assistant');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    IrisHaptics.actionSoft();
    showIrisFrostedSnackBar(
      context,
      content: const Text('Date sheet copied! Ready to paste on WhatsApp / Telegram.'),
      tint: widget.period == 'midterms' ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6),
    );
  }

  void _showExamGuidelinesSheet(BuildContext context, bool isDark, Color accentColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.fact_check_rounded, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Examination Hall Guidelines',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'COMSATS University Examination Protocol',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildGuidelineItem(
                Icons.badge_rounded,
                'Physical Student ID & Roll Slip Required',
                'Carry your original University ID card and stamped roll number slip to all examinations.',
                isDark,
                accentColor,
              ),
              _buildGuidelineItem(
                Icons.alarm_on_rounded,
                'Arrive 15 Minutes Prior',
                'Doors close strictly 10 minutes before the start time. Late entry is not permitted.',
                isDark,
                accentColor,
              ),
              _buildGuidelineItem(
                Icons.phonelink_erase_rounded,
                'Smartphones & Smartwatches Prohibited',
                'All electronic devices must be powered down and kept in bags at the front.',
                isDark,
                accentColor,
              ),
              _buildGuidelineItem(
                Icons.edit_note_rounded,
                'Stationery & Non-Programmable Calculators Only',
                'Borrowing stationery or calculators during examinations is strictly disallowed.',
                isDark,
                accentColor,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Understood & Acknowledged', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuidelineItem(IconData icon, String title, String subtitle, bool isDark, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    fontSize: 11.5,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExamDetailsModal(BuildContext context, Map<String, dynamic> exam, bool isDark, Color accentColor) {
    IrisHaptics.selectionClick();
    final subject = exam['subject']?.toString() ?? 'Exam';
    final dateStr = exam['date']?.toString() ?? '';
    final timeStr = exam['time']?.toString() ?? '';
    final roomsList = List<String>.from(exam['rooms'] ?? []);
    final parsedDate = _parseExamDate(dateStr);
    final status = _getExamStatus(parsedDate);

    final displayDate = _formatExamDate(dateStr);
    final displayTime = _formatExamTime(timeStr);
    final displayRooms = roomsList.join(', ');

    String countdownBadge = status;
    if (status == 'COMPLETED') {
      countdownBadge = 'EXAM CONCLUDED ✓';
    } else if (status == 'TODAY') {
      countdownBadge = 'HAPPENING TODAY 🔥';
    } else if (parsedDate != null) {
      final diff = DateTime(parsedDate.year, parsedDate.month, parsedDate.day)
          .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
          .inDays;
      countdownBadge = diff == 1 ? 'TOMORROW ⚡' : 'STARTS IN $diff DAYS';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text(
                      countdownBadge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                subject,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.calendar_month_rounded, 'Date & Day', displayDate, isDark, accentColor),
                    const Divider(height: 18),
                    _buildDetailRow(Icons.schedule_rounded, 'Time Slot', displayTime, isDark, accentColor),
                    const Divider(height: 18),
                    _buildDetailRow(Icons.meeting_room_rounded, 'Allocated Halls', displayRooms, isDark, accentColor),
                    if (roomsList.length > 1) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Split Seating: ${widget.batch} is divided across ${roomsList.length} halls. Check roll number list at entrance.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 18),
                    _buildDetailRow(Icons.groups_rounded, 'Batch Code', widget.batch, isDark, accentColor),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: displayRooms));
                        showIrisFrostedSnackBar(ctx, content: Text('Copied venue: $displayRooms'));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Venue', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RoomFinderScreen(
                              memory: null,
                              brain: null,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: const Text('Room Finder', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark, Color accentColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHeaderCardContent(
    BuildContext context,
    String titleText,
    Color accentColor,
    bool isDark,
    int totalExams,
    int completedExams,
    int upcomingExams,
    int todayExams,
    Map<String, dynamic>? nextExam,
    int daysToNextExam,
  ) {
    return [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Icon(
              widget.period == 'midterms' ? Icons.edit_note_rounded : Icons.workspace_premium_rounded,
              color: accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      titleText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.batch,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'COMSATS Examination Dashboard',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '$totalExams',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'TOTAL EXAMS',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.3 : 0.2),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '$completedExams',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'COMPLETED',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: isDark ? 0.3 : 0.2),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '$upcomingExams',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'REMAINING',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.period == 'midterms' ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6);
    final titleText = widget.period == 'midterms' ? 'MIDTERM EXAMS' : 'FINAL EXAMS';

    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: widget.period == 'midterms'
          ? RemoteConfigService.midtermExams
          : RemoteConfigService.finalExams,
      builder: (context, rawExams, _) {
        final matchedExams = rawExams.where((exam) {
          final examBatchRaw = (exam['batch'] ?? '').toString();
          return BatchKey.isBatchMatch(widget.batch, examBatchRaw);
        }).toList();

        List<String> extractRooms(dynamic roomData) {
          if (roomData == null) return [];
          final List<String> result = [];
          if (roomData is List) {
            for (final item in roomData) {
              final s = item?.toString().trim() ?? '';
              if (s.isNotEmpty) {
                final parts = s.split(RegExp(r'[,/&+;\n]'));
                for (final p in parts) {
                  final clean = p.trim();
                  if (clean.isNotEmpty && !result.contains(clean)) {
                    result.add(clean);
                  }
                }
              }
            }
          } else {
            final s = roomData.toString().trim();
            if (s.isNotEmpty) {
              final parts = s.split(RegExp(r'[,/&+;\n]'));
              for (final p in parts) {
                final clean = p.trim();
                if (clean.isNotEmpty && !result.contains(clean)) {
                  result.add(clean);
                }
              }
            }
          }
          return result;
        }

        final Map<String, Map<String, dynamic>> grouped = {};
        for (final exam in matchedExams) {
          final date = (exam['date'] ?? '').toString().trim();
          final time = (exam['time'] ?? '').toString().trim();
          final subject = (exam['subject'] ?? '').toString().trim();
          final extracted = extractRooms(exam['rooms'] ?? exam['room']);

          final key = '${date}_${time}_$subject';
          if (grouped.containsKey(key)) {
            final existingRooms = grouped[key]!['rooms'] as List<String>;
            for (final r in extracted) {
              if (!existingRooms.contains(r)) {
                existingRooms.add(r);
              }
            }
          } else {
            grouped[key] = {
              'date': date,
              'time': time,
              'subject': subject,
              'rooms': extracted.isEmpty ? ['TBD'] : extracted,
            };
          }
        }

        var allExamsList = grouped.values.toList();

        allExamsList.sort((a, b) {
          final dateA = _parseExamDate(a['date'] ?? '') ?? DateTime(3000);
          final dateB = _parseExamDate(b['date'] ?? '') ?? DateTime(3000);
          if (dateA != dateB) {
            return dateA.compareTo(dateB);
          }
          final timeA = (a['time'] ?? '').toString();
          final timeB = (b['time'] ?? '').toString();
          return timeA.compareTo(timeB);
        });

        final totalExams = allExamsList.length;
        int completedExams = 0;
        int upcomingExams = 0;
        int todayExams = 0;
        Map<String, dynamic>? nextExam;
        int daysToNextExam = -1;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        for (final exam in allExamsList) {
          final parsedDate = _parseExamDate(exam['date'] ?? '');
          final status = _getExamStatus(parsedDate);
          if (status == 'COMPLETED') {
            completedExams++;
          } else if (status == 'TODAY') {
            todayExams++;
            upcomingExams++;
            if (nextExam == null && parsedDate != null) {
              nextExam = exam;
              daysToNextExam = 0;
            }
          } else {
            upcomingExams++;
            if (nextExam == null && parsedDate != null) {
              nextExam = exam;
              daysToNextExam = DateTime(parsedDate.year, parsedDate.month, parsedDate.day)
                  .difference(today)
                  .inDays;
            }
          }
        }

        var filteredExams = allExamsList.where((ex) {
          final parsedDate = _parseExamDate(ex['date'] ?? '');
          final status = _getExamStatus(parsedDate);
          switch (_activeFilter) {
            case ExamFilterType.upcoming:
              return status == 'UPCOMING' || status == 'TODAY';
            case ExamFilterType.today:
              return status == 'TODAY';
            case ExamFilterType.completed:
              return status == 'COMPLETED';
            case ExamFilterType.all:
              return true;
          }
        }).toList();

        if (_searchQuery.isNotEmpty) {
          filteredExams = filteredExams.where((ex) {
            final sub = (ex['subject'] ?? '').toString().toLowerCase();
            final rooms = (ex['rooms'] as List?)?.join(' ').toLowerCase() ?? '';
            final date = (ex['date'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return sub.contains(query) || rooms.contains(query) || date.contains(query);
          }).toList();
        }

        final List<Map<String, dynamic>> dateGroups = [];
        for (final exam in filteredExams) {
          final date = (exam['date'] ?? '').toString();
          final lastGroup = dateGroups.isNotEmpty ? dateGroups.last : null;
          if (lastGroup != null && lastGroup['date'] == date) {
            (lastGroup['exams'] as List).add(exam);
          } else {
            dateGroups.add({
              'date': date,
              'exams': [exam],
            });
          }
        }

        final headerWidget = widget.period == 'midterms'
            ? MidtermsAnimationWidget(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildHeaderCardContent(
                    context, titleText, accentColor, isDark,
                    totalExams, completedExams, upcomingExams, todayExams, nextExam, daysToNextExam,
                  ),
                ),
              )
            : FinalsAnimationWidget(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildHeaderCardContent(
                    context, titleText, accentColor, isDark,
                    totalExams, completedExams, upcomingExams, todayExams, nextExam, daysToNextExam,
                  ),
                ),
              );

        return RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Artwork Banner (if enabled)
              if (widget.showHeroBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: headerWidget,
                ),

              // Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: IrisGlowingInputWrapper(
                  borderRadius: 18,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search_rounded, color: (isDark ? Colors.white54 : Colors.black45)),
                      hintText: 'Search exams by subject, hall or date...',
                      hintStyle: TextStyle(
                        color: (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
              ),

              // Segmented Filter Control Bar + Quick Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip(ExamFilterType.all, 'All', totalExams, isDark, accentColor),
                      const SizedBox(width: 8),
                      _buildFilterChip(ExamFilterType.upcoming, 'Upcoming', upcomingExams, isDark, accentColor),
                      const SizedBox(width: 8),
                      if (todayExams > 0) ...[
                        _buildFilterChip(ExamFilterType.today, 'Today', todayExams, isDark, const Color(0xFFF43F5E)),
                        const SizedBox(width: 8),
                      ],
                      _buildFilterChip(ExamFilterType.completed, 'Completed', completedExams, isDark, const Color(0xFF10B981)),
                      const SizedBox(width: 12),
                      // Quick Share Button
                      InkWell(
                        onTap: () => _copyFullDateSheet(allExamsList, titleText),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.share_rounded, size: 13, color: accentColor),
                              const SizedBox(width: 5),
                              Text(
                                'Share',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Guidelines Button
                      InkWell(
                        onTap: () => _showExamGuidelinesSheet(context, isDark, accentColor),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.help_outline_rounded, size: 13, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                              const SizedBox(width: 5),
                              Text(
                                'Rules',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
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

              // Exam Timeline List
              if (filteredExams.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 20,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accentColor.withValues(alpha: 0.18),
                                accentColor.withValues(alpha: 0.05),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_busy_rounded,
                            size: 34,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No matching exams found'
                              : (_activeFilter == ExamFilterType.today
                                  ? 'No exams scheduled today'
                                  : 'No exams found for ${widget.batch}'),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try searching with a different keyword or hall.'
                              : 'All examinations synchronized from cloud will appear here.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Flat High-Performance List (Zero layout passes, 120 FPS)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: dateGroups.length,
                  itemBuilder: (context, groupIdx) {
                    final group = dateGroups[groupIdx];
                    final dateStr = group['date'] as String;
                    final groupExams = group['exams'] as List;
                    final parsedDate = _parseExamDate(dateStr);
                    final examStatus = _getExamStatus(parsedDate);
                    final isTodayDate = examStatus == 'TODAY';
                    final isCompletedDate = examStatus == 'COMPLETED';

                    final timelineColor = isCompletedDate
                        ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
                        : (isTodayDate ? const Color(0xFFF43F5E) : accentColor).withValues(alpha: 0.35);

                    return RepaintBoundary(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Header Ribbon
                            Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (isTodayDate ? const Color(0xFFF43F5E) : accentColor).withValues(alpha: 0.15),
                                    border: Border.all(
                                      color: (isTodayDate ? const Color(0xFFF43F5E) : accentColor).withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isTodayDate ? const Color(0xFFF43F5E) : accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatExamDate(dateStr),
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: isTodayDate
                                        ? const Color(0xFFF43F5E)
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                if (isTodayDate) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Text(
                                      'TODAY 🔥',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFF43F5E),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ] else if (isCompletedDate) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PASSED ✓',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Grouped Cards with vertical timeline connector
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: timelineColor,
                                      width: 1.8,
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.only(left: 18, top: 4, bottom: 4),
                                child: Column(
                                  children: groupExams.map((exam) {
                                    final subject = exam['subject']?.toString() ?? 'Unknown Exam';
                                    final timeStr = exam['time']?.toString() ?? '';
                                    final roomsList = List<String>.from(exam['rooms'] ?? []);
                                    final status = _getExamStatus(parsedDate);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: RepaintBoundary(
                                        child: ExamTimelineCard(
                                          subject: subject,
                                          rawDate: dateStr,
                                          parsedDate: parsedDate,
                                          rawTime: timeStr,
                                          rooms: roomsList,
                                          status: status,
                                          accentThemeColor: accentColor,
                                          onTap: () => _showExamDetailsModal(context, exam, isDark, accentColor),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(ExamFilterType type, String label, int count, bool isDark, Color accentColor) {
    final isSelected = _activeFilter == type;
    return GestureDetector(
      onTap: () {
        IrisHaptics.selectionClick();
        setState(() {
          _activeFilter = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ultra Lightweight, 120 FPS Exam Timeline Card
class ExamTimelineCard extends StatelessWidget {
  final String subject;
  final String rawDate;
  final DateTime? parsedDate;
  final String rawTime;
  final List<String> rooms;
  final String status;
  final Color accentThemeColor;
  final VoidCallback? onTap;

  const ExamTimelineCard({
    required this.subject,
    required this.rawDate,
    required this.parsedDate,
    required this.rawTime,
    required this.rooms,
    required this.status,
    required this.accentThemeColor,
    this.onTap,
    super.key,
  });

  String _formatExamTime(String rawTime) {
    final timeRegex = RegExp(r'(\d{1,2}):?(\d{2})\s*-\s*(\d{1,2}):?(\d{2})');
    final match = timeRegex.firstMatch(rawTime);
    if (match != null) {
      String formatPart(String hr, String min) {
        int h = int.parse(hr);
        if (h >= 1 && h <= 8) h += 12;
        final ampm = h >= 12 ? 'PM' : 'AM';
        if (h > 12) h -= 12;
        if (h == 0) h = 12;
        return '$h:${min.padLeft(2, '0')} $ampm';
      }
      return '${formatPart(match.group(1)!, match.group(2)!)} - ${formatPart(match.group(3)!, match.group(4)!)}';
    }
    return rawTime;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color statusColor;
    String badgeText = status;
    final isCompleted = status == 'COMPLETED';
    final isToday = status == 'TODAY';

    if (isCompleted) {
      statusColor = const Color(0xFF10B981);
      badgeText = 'COMPLETED ✓';
    } else if (isToday) {
      statusColor = const Color(0xFFF43F5E);
      badgeText = 'TODAY 🔥';
    } else {
      statusColor = accentThemeColor;
      if (parsedDate != null) {
        final diff = DateTime(parsedDate!.year, parsedDate!.month, parsedDate!.day)
            .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
            .inDays;
        badgeText = diff == 1 ? 'TOMORROW ⚡' : 'IN $diff DAYS';
      }
    }

    final displayTime = _formatExamTime(rawTime);
    final displayRooms = rooms.join('  •  ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isToday
                ? const Color(0xFFF43F5E).withValues(alpha: 0.5)
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
            width: isToday ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isToday
                  ? const Color(0xFFF43F5E).withValues(alpha: isDark ? 0.25 : 0.12)
                  : Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
              blurRadius: isToday ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Status Stripe
              Container(
                width: 5.0,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),

              // Main Info Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),

                          // Time Capsule
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: (isDark ? Colors.white54 : Colors.black45),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                displayTime,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Subject Title
                      Text(
                        subject,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: isCompleted
                              ? (isDark ? Colors.white60 : const Color(0xFF64748B))
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          letterSpacing: -0.2,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Rooms Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: rooms.length > 1
                              ? statusColor.withValues(alpha: isDark ? 0.14 : 0.08)
                              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: rooms.length > 1
                                ? statusColor.withValues(alpha: 0.35)
                                : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.meeting_room_rounded,
                              size: 13,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            if (rooms.length > 1) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${rooms.length} Halls',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                            Flexible(
                              child: Text(
                                displayRooms,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
    );
  }
}
