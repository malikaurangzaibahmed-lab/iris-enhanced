import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/ui_feedback.dart';

/// Delegate for the Huge Collapsing Sticky Notice Card during Vacation Mode.
/// Smoothly compresses from a grand 340dp vertical card into a sleek 88dp sticky header.
class VacationStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String batch;
  final int daysLeft;
  final String targetSemester;
  final VoidCallback? onNoticeTap;

  VacationStickyHeaderDelegate({
    required this.batch,
    this.daysLeft = 42,
    this.targetSemester = 'Next Semester',
    this.onNoticeTap,
  });

  @override
  double get minExtent => 88.0;

  @override
  double get maxExtent => 340.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    // Progress from 0.0 (fully expanded) to 1.0 (fully collapsed)
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - (progress * 1.8)).clamp(0.0, 1.0);
    final collapsedOpacity = ((progress - 0.5) * 2.0).clamp(0.0, 1.0);

    return Container(
      height: maxExtent - shrinkOffset,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C050D) : const Color(0xFFFFF1F2),
        boxShadow: progress > 0.8
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Expansive Notice Card (Visible when expanded)
          if (expandedOpacity > 0.01)
            Opacity(
              opacity: expandedOpacity,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16 * (1.0 - progress),
                  topPadding + 8,
                  16 * (1.0 - progress),
                  12,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    lerpDouble(28.0, 16.0, progress) ?? 24.0,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Vacation Artwork Image
                      Image.asset(
                        'assets/headers/header_vacation_mode.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFF43F5E), Color(0xFFFB923C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),

                      // Gentle Sunset Vignette Gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),

                      // Glowing Top Rim Border
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFF43F5E).withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                      ),

                      // Card Top Badge
                      Positioned(
                        top: 14,
                        left: 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '🏖️ VACATION NOTICE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Floating Frosted Glass Countdown Box in Center-Bottom
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.45)
                                    : Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFFFB7185).withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.9),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    daysLeft > 1
                                        ? '$daysLeft DAYS'
                                        : (daysLeft == 1
                                            ? '1 DAY'
                                            : (daysLeft == 0
                                                ? 'RESUMES TODAY!'
                                                : (daysLeft < 0 && daysLeft != -1
                                                    ? 'SEMESTER ACTIVE'
                                                    : 'RECESS ACTIVE'))),
                                    style: TextStyle(
                                      fontSize: daysLeft == 0 || daysLeft < 0 || daysLeft == -1 ? 24 : 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      height: 1.05,
                                      color: isDark
                                          ? const Color(0xFFFFF1F2)
                                          : const Color(0xFF9F1239),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    daysLeft >= 0
                                        ? 'Until $targetSemester Resumes'
                                        : 'Campus in Recess • Enjoy Your Break',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : const Color(0xFF4C0519),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF43F5E).withValues(
                                        alpha: isDark ? 0.25 : 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFF43F5E)
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      '$batch • Academic Break Active',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? const Color(0xFFFDA4AF)
                                            : const Color(0xFFE11D48),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Compact Sticky Top Header Bar (Visible when scrolled)
          if (collapsedOpacity > 0.01)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: minExtent,
              child: Opacity(
                opacity: collapsedOpacity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: EdgeInsets.only(
                        top: topPadding + 4,
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFFE11D48).withValues(alpha: 0.92),
                                  const Color(0xFF9F1239).withValues(alpha: 0.95),
                                ]
                              : [
                                  const Color(0xFFFB7185),
                                  const Color(0xFFF43F5E),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Text('🌴', style: TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  daysLeft > 1
                                      ? 'Break • $daysLeft Days Left'
                                      : (daysLeft == 1
                                          ? 'Break • 1 Day Left'
                                          : (daysLeft == 0
                                              ? 'Break • Resumes Today!'
                                              : (daysLeft < 0 && daysLeft != -1
                                                  ? 'Semester Active'
                                                  : 'Semester Break'))),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  '$batch • $targetSemester',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              IrisHaptics.chipSelect();
                              onNoticeTap?.call();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 13, color: Colors.white),
                                  SizedBox(width: 5),
                                  Text(
                                    'Schedule',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
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
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant VacationStickyHeaderDelegate oldDelegate) {
    return oldDelegate.batch != batch ||
        oldDelegate.daysLeft != daysLeft ||
        oldDelegate.targetSemester != targetSemester;
  }
}
