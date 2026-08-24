import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../widgets/glass_card.dart';
import '../services/ui_feedback.dart';
import '../services/remote_config_service.dart';

/// Clean, honest Sports Gala Notice Card using only real system context.
/// Avoids fabricated mock fixtures or fake scores.
class StudentsWeekInfoCard extends StatelessWidget {
  final bool isFaculty;
  final VoidCallback? onExploreGrounds;

  const StudentsWeekInfoCard({
    this.isFaculty = false,
    this.onExploreGrounds,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF10B981);
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Sports Gala Status Card
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
                        Icons.emoji_events_rounded,
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
                            isFaculty
                                ? 'FACULTY SUPERVISION & RECREATION'
                                : 'ACADEMIC CLASSES SUSPENDED',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "Students' Week ${now.year} In Session",
                            style: TextStyle(
                              fontSize: 15,
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
                  isFaculty
                      ? "Normal teaching timetable is suspended across campus for Students' Week. Faculty members are invited to participate in campus sports activities, match officiating, and student event supervision."
                      : "Regular lectures and laboratory sessions are suspended across all departments for Students' Week. Campus athletic, cultural, and sports gala competitions are active.",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: accentColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Normal classes resume immediately following Students' Week.",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
