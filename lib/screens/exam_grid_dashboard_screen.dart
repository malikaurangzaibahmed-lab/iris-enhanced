import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../core/format_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';
import '../widgets/glowing_input_wrapper.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';
import '../services/remote_config_service.dart';
import 'students_week_screen.dart';
import 'room_finder_screen.dart';

enum ExamFilterType { all, upcoming, today, completed }

class ExamGridDashboard extends StatefulWidget {
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
  State<ExamGridDashboard> createState() => _ExamGridDashboardState();
}

class _ExamGridDashboardState extends State<ExamGridDashboard> {
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
        if (h >= 1 && h <= 8) {
          h += 12;
        }
        final ampm = h >= 12 ? 'PM' : 'AM';
        if (h > 12) h -= 12;
        if (h == 0) h = 12;
        final minStr = min.padLeft(2, '0');
        return '$h:$minStr $ampm';
      }
      return '${formatPart(match.group(1)!, match.group(2)!)} - ${formatPart(match.group(3)!, match.group(4)!)}';
    }
    return rawTime;
  }

  void _copyFullDateSheet(List<Map<String, dynamic>> exams, String titleText) {
    IrisHaptics.actionSoft();
    if (exams.isEmpty) {
      showIrisFrostedSnackBar(context, content: const Text('No exams to copy'));
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('📅 *IRIS $titleText - ${widget.batch}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    for (int i = 0; i < exams.length; i++) {
      final e = exams[i];
      final date = _formatExamDate((e['date'] ?? '').toString());
      final time = _formatExamTime((e['time'] ?? '').toString());
      final rooms = (e['rooms'] as List?)?.join(', ') ?? 'TBD';
      buffer.writeln('${i + 1}. *${e['subject']}*');
      buffer.writeln('   📆 $date');
      buffer.writeln('   ⏰ $time');
      buffer.writeln('   🏛️ Hall: $rooms');
      buffer.writeln('');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Generated via IRIS Campus Intelligence');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    showIrisFrostedSnackBar(
      context,
      content: Text('Copied ${exams.length} exams to clipboard for sharing!'),
      tint: widget.period == 'midterms' ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6),
    );
  }

  void _showExamGuidelinesSheet(BuildContext context, bool isDark, Color accentColor) {
    IrisHaptics.actionSoft();
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Understood, Good Luck!',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuidelineItem(IconData icon, String title, String desc, bool isDark, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 16),
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
                  desc,
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
    IrisHaptics.actionSoft();
    final subject = exam['subject']?.toString() ?? 'Exam';
    final dateStr = (exam['date'] ?? '').toString();
    final timeStr = (exam['time'] ?? '').toString();
    final roomsList = List<String>.from(exam['rooms'] ?? []);
    final parsedDate = _parseExamDate(dateStr);
    final status = _getExamStatus(parsedDate);

    final displayDate = _formatExamDate(dateStr);
    final displayTime = _formatExamTime(timeStr);
    final displayRooms = roomsList.isEmpty ? 'TBD' : roomsList.join(', ');

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
                            builder: (_) => RoomFinderScreen(
                              brain: widget.period == 'midterms'
                                  ? (RemoteConfigService.midtermExams.value.isNotEmpty
                                      ? null
                                      : null)
                                  : null,
                              onToggleTheme: widget.onToggleTheme,
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
                  widget.period == 'midterms' ? 'Midterm Examination' : 'Final Terminal Examination',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: widget.onToggleTheme,
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 19,
                color: isDark ? Colors.white70 : IrisTokens.brand,
              ),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 16),
      Divider(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08), height: 1),
      const SizedBox(height: 16),
      
      // Circular Progress & Stats Group
      Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  value: totalExams > 0 ? completedExams / totalExams : 0.0,
                  strokeWidth: 5.5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              Text(
                totalExams > 0 ? '${((completedExams / totalExams) * 100).round()}%' : '0%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completedExams of $totalExams Papers Completed',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (todayExams > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$todayExams TODAY 🔥',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF43F5E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '$upcomingExams upcoming exam${upcomingExams == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),

      // Next Exam Countdown Indicator / Completed Celebration State
      if (nextExam != null) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.alarm_rounded, color: accentColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      daysToNextExam == 0
                          ? 'NEXT EXAM IS TODAY 🔥'
                          : daysToNextExam == 1
                              ? 'NEXT EXAM IS TOMORROW 📚'
                              : 'NEXT EXAM IN $daysToNextExam DAYS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextExam['subject']?.toString() ?? 'Exam',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ] else if (totalExams > 0 && completedExams == totalExams) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_rounded, color: Color(0xFF10B981), size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ALL EXAMS COMPLETED! 🎉',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Enjoy your well-deserved break! You did it.",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.period == 'midterms' ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6);
    final titleText = widget.period == 'midterms' ? 'MIDTERM EXAMS' : 'FINAL EXAMS';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ValueListenableBuilder<List<dynamic>>(
          valueListenable: widget.period == 'midterms'
              ? RemoteConfigService.midtermExams
              : RemoteConfigService.finalExams,
          builder: (context, rawExams, _) {
            final matchedExams = rawExams.where((exam) {
              final examBatchRaw = (exam['batch'] ?? '').toString();
              return BatchKey.isBatchMatch(widget.batch, examBatchRaw);
            }).toList();

            final Map<String, Map<String, dynamic>> grouped = {};
            for (final exam in matchedExams) {
              final date = (exam['date'] ?? '').toString();
              final time = (exam['time'] ?? '').toString();
              final subject = (exam['subject'] ?? '').toString();
              final room = (exam['room'] ?? '').toString();
              
              final key = '${date}_${time}_$subject';
              if (grouped.containsKey(key)) {
                final existingRooms = grouped[key]!['rooms'] as List<String>;
                if (!existingRooms.contains(room)) {
                  existingRooms.add(room);
                }
              } else {
                grouped[key] = {
                  'date': date,
                  'time': time,
                  'subject': subject,
                  'rooms': [room],
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

            // Calculate status metrics across all exams
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

            // Apply Active Tab Filter
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
                default:
                  return true;
              }
            }).toList();

            // Apply Search Query
            if (_searchQuery.isNotEmpty) {
              filteredExams = filteredExams.where((ex) {
                final sub = (ex['subject'] ?? '').toString().toLowerCase();
                final rooms = (ex['rooms'] as List?)?.join(' ').toLowerCase() ?? '';
                final date = (ex['date'] ?? '').toString().toLowerCase();
                final query = _searchQuery.toLowerCase();
                return sub.contains(query) || rooms.contains(query) || date.contains(query);
              }).toList();
            }

            // Group filtered exams by date
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
                        totalExams, completedExams, upcomingExams, todayExams, nextExam, daysToNextExam
                      ),
                    ),
                  )
                : FinalsAnimationWidget(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildHeaderCardContent(
                        context, titleText, accentColor, isDark,
                        totalExams, completedExams, upcomingExams, todayExams, nextExam, daysToNextExam
                      ),
                    ),
                  );

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top App Bar / Back Button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                        const Spacer(),
                        // Action Buttons: Share & Guidelines
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: accentColor.withValues(alpha: 0.1),
                            foregroundColor: accentColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _copyFullDateSheet(allExamsList, titleText),
                          icon: const Icon(Icons.share_rounded, size: 15),
                          label: const Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _showExamGuidelinesSheet(context, isDark, accentColor),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.help_outline_rounded,
                              size: 18,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Hero Artwork Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: headerWidget,
                  ),
                ),
                
                // Search Input Box
                SliverToBoxAdapter(
                  child: Padding(
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
                ),

                // Segmented Filter Control Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
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
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 6)),
                
                filteredExams.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
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
                                          : 'No exams found'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Try searching with a different keyword.'
                                      : 'All exams for batch ${widget.batch} will appear here.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, groupIdx) {
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
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date Ribbon Header
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
                                  
                                  // Grouped cards with timeline vertical connector
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
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: groupExams.length,
                                        separatorBuilder: (context, _) => const SizedBox(height: 12),
                                        itemBuilder: (context, examIdx) {
                                          final exam = groupExams[examIdx];
                                          final subject = exam['subject']?.toString() ?? 'Unknown Exam';
                                          final timeStr = exam['time']?.toString() ?? 'TBD';
                                          final roomsList = List<String>.from(exam['rooms'] ?? []);
                                          final status = _getExamStatus(parsedDate);
                                          
                                          return StaggeredListItem(
                                            index: groupIdx * 10 + examIdx,
                                            child: ExamCard(
                                              subject: subject,
                                              rawDate: dateStr,
                                              parsedDate: parsedDate,
                                              rawTime: timeStr,
                                              rooms: roomsList,
                                              status: status,
                                              accentThemeColor: accentColor,
                                              onTap: () => _showExamDetailsModal(context, exam, isDark, accentColor),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            );
                          },
                          childCount: dateGroups.length,
                        ),
                      ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(ExamFilterType type, String label, int count, bool isDark, Color accentColor) {
    final isSelected = _activeFilter == type;
    return GestureDetector(
      onTap: () {
        IrisHaptics.selection();
        setState(() {
          _activeFilter = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
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

class ExamCard extends StatefulWidget {
  final String subject;
  final String rawDate;
  final DateTime? parsedDate;
  final String rawTime;
  final List<String> rooms;
  final String status;
  final Color accentThemeColor;
  final VoidCallback? onTap;

  const ExamCard({
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

  @override
  State<ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<ExamCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      value: 0.5,
    );
    _glowAnimation = Tween<double>(begin: 0.12, end: 0.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.status == 'TODAY') {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ExamCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == 'TODAY' && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (widget.status != 'TODAY' && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color statusColor;
    String badgeText = widget.status;
    final isCompleted = widget.status == 'COMPLETED';
    final isToday = widget.status == 'TODAY';

    if (isCompleted) {
      statusColor = const Color(0xFF10B981);
      badgeText = 'COMPLETED ✓';
    } else if (isToday) {
      statusColor = const Color(0xFFF43F5E);
      badgeText = 'TODAY 🔥';
    } else {
      statusColor = widget.accentThemeColor;
      if (widget.parsedDate != null) {
        final diff = DateTime(widget.parsedDate!.year, widget.parsedDate!.month, widget.parsedDate!.day)
            .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
            .inDays;
        badgeText = diff == 1 ? 'TOMORROW ⚡' : 'IN $diff DAYS';
      }
    }

    final displayDate = _formatExamDate(widget.rawDate);
    final displayTime = _formatExamTime(widget.rawTime);
    final displayRooms = widget.rooms.isEmpty ? 'TBD' : widget.rooms.join('  •  ');

    final cardContent = InkWell(
      onTap: widget.onTap ?? () {
        IrisHaptics.actionSoft();
        Clipboard.setData(ClipboardData(text: '${widget.subject} | Hall: $displayRooms | $displayDate ($displayTime)'));
        showIrisFrostedSnackBar(
          context,
          content: Text('Copied venue details: $displayRooms'),
          tint: statusColor,
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Accent Status Bar
            Container(
              width: 5.5,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                boxShadow: isToday ? [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
            ),
            
            // Card Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'EXAM PAPER',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: (isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: isDark ? 0.16 : 0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: statusColor.withValues(alpha: isDark ? 0.35 : 0.25),
                              width: 1,
                            ),
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
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    Text(
                      widget.subject,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: isCompleted
                            ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        decorationColor: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 14),
                    // Room allocation capsules
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.meeting_room_rounded,
                          size: 15,
                          color: isCompleted
                              ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
                              : statusColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: widget.rooms.isEmpty
                                ? [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'TBD',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        ),
                                      ),
                                    )
                                  ]
                                : widget.rooms.map((room) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isCompleted
                                            ? (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9))
                                            : statusColor.withValues(alpha: isDark ? 0.12 : 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isCompleted
                                              ? (isDark ? Colors.white12 : const Color(0xFFE2E8F0))
                                              : statusColor.withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        room,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: isCompleted
                                              ? (isDark ? Colors.white54 : const Color(0xFF64748B))
                                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$displayDate  •  $displayTime',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final borderGlow = isToday ? _glowAnimation.value : (isDark ? 0.12 : 0.08);
        return Opacity(
          opacity: isCompleted ? 0.65 : 1.0,
          child: GlassCard(
            padding: EdgeInsets.zero,
            borderRadius: 20,
            glow: isToday,
            accentColor: statusColor,
            border: Border.all(
              color: statusColor.withValues(alpha: borderGlow),
              width: isToday ? 1.5 : 1.0,
            ),
            child: child!,
          ),
        );
      },
      child: cardContent,
    );
  }
}
