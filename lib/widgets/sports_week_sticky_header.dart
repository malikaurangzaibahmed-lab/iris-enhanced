import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/ui_feedback.dart';

/// Delegate for the Grand Collapsing Sticky Hero Card during Students' Week & Sports Gala.
/// Smoothly compresses from a grand 340dp vertical card with full high-res background artwork
/// into a sleek, frosted 88dp sticky header on scroll.
class SportsWeekStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String userName;
  final String batch;
  final VoidCallback? onFixturesTap;
  final VoidCallback? onRefresh;

  const SportsWeekStickyHeaderDelegate({
    required this.userName,
    required this.batch,
    this.onFixturesTap,
    this.onRefresh,
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
    const accentColor = Color(0xFF10B981);
    const galaTitle = "STUDENTS' GALA";

    // Progress from 0.0 (fully expanded) to 1.0 (fully collapsed)
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - (progress * 1.8)).clamp(0.0, 1.0);
    final collapsedOpacity = ((progress - 0.5) * 2.0).clamp(0.0, 1.0);

    return Container(
      height: maxExtent - shrinkOffset,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF041E15) : const Color(0xFFECFDF5),
        boxShadow: progress > 0.8
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Expansive Hero Notice Card (Visible when expanded)
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
                      // High-Res Sports Gala Background Artwork Image
                      Image.asset(
                        'assets/headers/header_sports_gala.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),

                      // Vignette Scrim Gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.78),
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
                            color: accentColor.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                      ),

                      // Top Row: Gala Badge + Batch + Fixtures Button
                      Positioned(
                        top: 14,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.emoji_events_rounded,
                                        size: 14,
                                        color: accentColor,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        '🏆 SPORTS WEEK ACTIVE',
                                        style: TextStyle(
                                          color: accentColor,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                batch,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (onFixturesTap != null)
                              InkWell(
                                onTap: () {
                                  IrisHaptics.selectionClick();
                                  onFixturesTap!();
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.sports_soccer_rounded,
                                    size: 15,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Floating Frosted Glass Gala Box in Center-Bottom
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 14,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.55)
                                    : Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isDark
                                      ? accentColor.withValues(alpha: 0.45)
                                      : Colors.white.withValues(alpha: 0.9),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(
                                        alpha: isDark ? 0.25 : 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: accentColor.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      'STUDENTS\' GALA ${DateTime.now().year}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: accentColor,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Unleash the Athletic Spirit',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                      height: 1.15,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Zero Regular Classes',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        '•',
                                        style: TextStyle(
                                          color: accentColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tournament Fixtures Active',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
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
                                  accentColor.withValues(alpha: 0.92),
                                  const Color(0xFF047857).withValues(alpha: 0.95),
                                ]
                              : [
                                  accentColor,
                                  const Color(0xFF059669),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.3),
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
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  galaTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  '$batch • Sports Week In Session',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onRefresh != null)
                            InkWell(
                              onTap: () {
                                IrisHaptics.chipSelect();
                                onRefresh?.call();
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
                                    Icon(Icons.sync_rounded, size: 13, color: Colors.white),
                                    SizedBox(width: 5),
                                    Text(
                                      'Sync',
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
  bool shouldRebuild(covariant SportsWeekStickyHeaderDelegate oldDelegate) {
    return oldDelegate.userName != userName || oldDelegate.batch != batch;
  }
}
