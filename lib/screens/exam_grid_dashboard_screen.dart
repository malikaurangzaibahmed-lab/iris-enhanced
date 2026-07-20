import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../widgets/glass_card.dart';
import '../widgets/iris_components.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';
import '../services/remote_config_service.dart';
import 'students_week_screen.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _parseExamDate(String dateStr) {
    final parts = dateStr.split(' ');
    if (parts.length < 2) return null;
    final datePart = parts[1];
    
    final dmyRegex = RegExp(r'(\d{2})-(\d{2})-(\d{4})');
    var match = dmyRegex.firstMatch(datePart);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    }
    
    final dmyShortRegex = RegExp(r'(\d{2})-(\d{2})-(\d{2})');
    match = dmyShortRegex.firstMatch(datePart);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final shortYear = int.parse(match.group(3)!);
      final year = 2000 + shortYear;
      return DateTime(year, month, day);
    }
    return null;
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

  List<Widget> _buildHeaderCardContent(
    BuildContext context,
    String titleText,
    Color accentColor,
    bool isDark,
    int totalExams,
    int completedExams,
    int upcomingExams,
    Map<String, dynamic>? nextExam,
    int daysToNextExam,
  ) {
    return [
      Row(
        children: [
          Icon(
            widget.period == 'midterms' ? Icons.menu_book_rounded : Icons.school_rounded,
            color: accentColor,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Exam Schedule',
                  style: IrisTextStyles.headline(context).copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 80),
          Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : IrisTokens.brand).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: widget.onToggleTheme,
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 20,
                color: isDark ? Colors.white70 : IrisTokens.brand,
              ),
              padding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 20),
      Divider(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08), height: 1),
      const SizedBox(height: 20),
      
      // Circular Progress & Stats Group
      Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: CircularProgressIndicator(
                  value: totalExams > 0 ? completedExams / totalExams : 0.0,
                  strokeWidth: 5.5,
                  backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              Text(
                totalExams > 0 ? '${((completedExams / totalExams) * 100).round()}%' : '0%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completedExams / $totalExams Completed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.batch,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$upcomingExams exams remaining',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
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
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.event_note_rounded, color: accentColor, size: 20),
              ),
              const SizedBox(width: 14),
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
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      nextExam['subject']?.toString() ?? 'Exam',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
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
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ALL EXAMS COMPLETED! 🎉',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Enjoy your break! You've done an amazing job.",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
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
    final accentColor = widget.period == 'midterms' ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E);
    final titleText = widget.period == 'midterms' ? 'MIDTERM EXAMS' : 'FINAL EXAMS';

    return SafeArea(
      child: ValueListenableBuilder<List<dynamic>>(
        valueListenable: widget.period == 'midterms'
            ? RemoteConfigService.midtermExams
            : RemoteConfigService.finalExams,
        builder: (context, rawExams, _) {
          final matchedExams = rawExams.where((exam) {
            final examBatch = (exam['batch'] ?? '').toString();
            if (examBatch.isEmpty || widget.batch.isEmpty) return false;
            
            final studentBatch = widget.batch.trim().toLowerCase();
            final examBatchLower = examBatch.trim().toLowerCase();
            if (examBatchLower == studentBatch) return true;
            
            final studentKey = BatchKey.parse(widget.batch);
            final examKey = BatchKey.parse(examBatch);
            
            final examParts = examBatchLower.split('-');
            if (examParts.length == 2) {
              return studentKey.intake.toLowerCase() == examKey.intake.toLowerCase() &&
                     studentKey.program.toLowerCase() == examKey.program.toLowerCase();
            }
            
            return studentKey.intake.toLowerCase() == examKey.intake.toLowerCase() &&
                   studentKey.program.toLowerCase() == examKey.program.toLowerCase() &&
                   studentKey.section.toLowerCase() == examKey.section.toLowerCase();
          }).toList();

          final Map<String, Map<String, dynamic>> grouped = {};
          for (final exam in matchedExams) {
            final date = (exam['date'] ?? '').toString();
            final time = (exam['time'] ?? '').toString();
            final subject = (exam['subject'] ?? '').toString();
            final room = (exam['room'] ?? '').toString();
            
            final key = '${date}_${time}_${subject}';
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

          var examsList = grouped.values.toList();

          examsList.sort((a, b) {
            final dateA = _parseExamDate(a['date'] ?? '') ?? DateTime(3000);
            final dateB = _parseExamDate(b['date'] ?? '') ?? DateTime(3000);
            if (dateA != dateB) {
              return dateA.compareTo(dateB);
            }
            final timeA = (a['time'] ?? '').toString();
            final timeB = (b['time'] ?? '').toString();
            return timeA.compareTo(timeB);
          });

          if (_searchQuery.isNotEmpty) {
            examsList = examsList.where((ex) {
              final sub = (ex['subject'] ?? '').toString().toLowerCase();
              return sub.contains(_searchQuery.toLowerCase());
            }).toList();
          }

          // Calculate stats and next exam
          final totalExams = examsList.length;
          int completedExams = 0;
          int upcomingExams = 0;
          Map<String, dynamic>? nextExam;
          int daysToNextExam = -1;

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          for (final exam in examsList) {
            final parsedDate = _parseExamDate(exam['date'] ?? '');
            final status = _getExamStatus(parsedDate);
            if (status == 'COMPLETED') {
              completedExams++;
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

          // Group by Date for vertical timeline grouping
          final List<Map<String, dynamic>> dateGroups = [];
          for (final exam in examsList) {
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
                      totalExams, completedExams, upcomingExams, nextExam, daysToNextExam
                    ),
                  ),
                )
              : FinalsAnimationWidget(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildHeaderCardContent(
                      context, titleText, accentColor, isDark,
                      totalExams, completedExams, upcomingExams, nextExam, daysToNextExam
                    ),
                  ),
                );

          return CustomScrollView(
            physics: const ButterScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: headerWidget,
                ),
              ),
              
              // Search Input Box
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    borderRadius: 20,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        icon: Icon(Icons.search_rounded, color: (isDark ? Colors.white54 : Colors.black54)),
                        hintText: 'Search exams by subject...',
                        hintStyle: TextStyle(
                          color: (isDark ? Colors.white38 : Colors.black38),
                          fontSize: 14,
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
              
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              
              examsList.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: GlassCard(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accentColor.withValues(alpha: 0.15),
                                      accentColor.withValues(alpha: 0.05),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.calendar_today_rounded,
                                  size: 38,
                                  color: accentColor.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _searchQuery.isNotEmpty ? 'No matching exams' : 'No exams scheduled',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 0.2,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty 
                                    ? 'Try looking for another subject.' 
                                    : 'There are no exams listed for batch ${widget.batch} yet.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
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
                              ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
                              : (isTodayDate ? const Color(0xFF4F46E5) : accentColor).withValues(alpha: 0.35);
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Beautiful sticky-style date header with timeline bullet
                                Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: (isTodayDate ? const Color(0xFF4F46E5) : accentColor).withValues(alpha: 0.15),
                                        border: Border.all(
                                          color: (isTodayDate ? const Color(0xFF4F46E5) : accentColor).withValues(alpha: 0.4),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isTodayDate ? const Color(0xFF4F46E5) : accentColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _formatExamDate(dateStr),
                                      style: IrisTextStyles.headline(context).copyWith(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        color: isTodayDate 
                                            ? const Color(0xFF4F46E5) 
                                            : (isDark ? Colors.white : Colors.black87),
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    if (isTodayDate) ...[
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Text(
                                          'TODAY 🔥',
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF4F46E5),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                // Grouped cards with timeline vertical connector
                                Padding(
                                  padding: const EdgeInsets.only(left: 7.5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: timelineColor,
                                          width: 1.8,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
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
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          );
        },
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

  const ExamCard({
    required this.subject,
    required this.rawDate,
    required this.parsedDate,
    required this.rawTime,
    required this.rooms,
    required this.status,
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
    );
    _glowAnimation = Tween<double>(begin: 0.12, end: 0.40).animate(
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
        return '$h:$min $ampm';
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
    if (widget.status == 'COMPLETED') {
      statusColor = isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.35);
      badgeText = 'COMPLETED';
    } else if (widget.status == 'TODAY') {
      statusColor = const Color(0xFF4F46E5); // Deep Indigo
      badgeText = 'TODAY 🔥';
    } else {
      statusColor = const Color(0xFF10B981); // Emerald Green
      if (widget.parsedDate != null) {
        final diff = DateTime(widget.parsedDate!.year, widget.parsedDate!.month, widget.parsedDate!.day)
            .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
            .inDays;
        badgeText = diff == 1 ? 'TOMORROW' : 'IN $diff DAYS';
      }
    }

    final displayDate = _formatExamDate(widget.rawDate);
    final displayTime = _formatExamTime(widget.rawTime);
    final displayRooms = widget.rooms.isEmpty ? 'TBD' : widget.rooms.join(' // ');
    final isToday = widget.status == 'TODAY';

    final cardContent = InkWell(
      onTap: () {
        IrisHaptics.actionSoft();
        Clipboard.setData(ClipboardData(text: '${widget.subject} - Rooms: $displayRooms, Date: $displayDate, Time: $displayTime'));
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
            // Left Indicator Accent Bar
            Container(
              width: 6,
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
            
            // Card Details Pane
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'VENUE ALLOCATION',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: (isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.55)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.20), width: 1),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    Text(
                      widget.subject,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Icon(
                            Icons.meeting_room_rounded,
                            size: 14,
                            color: statusColor.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: widget.rooms.isEmpty
                                ? [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'TBD',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    )
                                  ]
                                : widget.rooms.map((room) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: statusColor.withValues(alpha: 0.15),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        room,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.87)
                                              : Colors.black.withValues(alpha: 0.87),
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
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$displayDate  |  $displayTime',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
        final borderGlow = isToday ? _glowAnimation.value : 0.08;
        return Opacity(
          opacity: widget.status == 'COMPLETED' ? 0.55 : 1.0,
          child: GlassCard(
            padding: EdgeInsets.zero,
            borderRadius: 20,
            glow: isToday,
            accentColor: statusColor,
            border: isToday
                ? Border.all(
                    color: statusColor.withValues(alpha: borderGlow),
                    width: 1.5,
                  )
                : null,
            child: child!,
          ),
        );
      },
      child: cardContent,
    );
  }
}
