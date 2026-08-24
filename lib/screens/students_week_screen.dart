import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import '../widgets/nature_particles.dart';
import '../core/tokens.dart';

// ==========================================================================
// STUDENTS WEEK HEADER CARD WITH STATIC COMIC ARTWORK (0% IDLE CPU)
// ==========================================================================

class StudentsWeekHeaderCard extends StatelessWidget {
  final String userName;
  final String batch;
  final VoidCallback onToggleTheme;

  const StudentsWeekHeaderCard({
    required this.userName,
    required this.batch,
    required this.onToggleTheme,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StudentsWeekAnimationWidget(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF10B981).withValues(alpha: 0.16)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.35)
                          : const Color(0xFF10B981).withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "🏆 STUDENTS' GALA ${DateTime.now().year}",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDark ? const Color(0xFF10B981) : const Color(0xFF047857),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unleash the\nAthletic Brain',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Sports gala events active across campus! Timetables and scheduled classes running smoothly.",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.70)
                        : const Color(0xFF334155).withValues(alpha: 0.90),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}

// ==========================================================================
// STATIC COMIC HEADER CARD BASE COMPONENT (0% CPU, RIGID, SCRIM GRADIENT)
// ==========================================================================

class HeaderImageCard extends StatelessWidget {
  final String imageAsset;
  final Widget child;
  final Color accentColor;
  final double borderRadius;
  final double minHeight;

  const HeaderImageCard({
    required this.imageAsset,
    required this.child,
    required this.accentColor,
    this.borderRadius = 32.0,
    this.minHeight = 130.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HeaderAtmosphereWrapper(
      radius: borderRadius,
      themeColor: accentColor,
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: borderRadius,
        accentColor: accentColor,
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.25 : 0.35),
          width: 1.2,
        ),
        glow: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            children: [
              // 1. Comic Widescreen Background Artwork
              Positioned.fill(
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: isDark ? const Color(0xFF0B101E) : const Color(0xFFF1F5F9),
                  ),
                ),
              ),
              // 2. High-legibility Contrast Scrim (Left-to-Right)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        (isDark ? const Color(0xFF030712) : Colors.white)
                            .withValues(alpha: isDark ? 0.92 : 0.96),
                        (isDark ? const Color(0xFF030712) : Colors.white)
                            .withValues(alpha: isDark ? 0.78 : 0.88),
                        (isDark ? const Color(0xFF030712) : Colors.white)
                            .withValues(alpha: isDark ? 0.25 : 0.35),
                      ],
                      stops: const [0.0, 0.58, 1.0],
                    ),
                  ),
                ),
              ),
              // 3. Foreground Content
              Padding(
                padding: const EdgeInsets.all(22),
                child: Container(
                  constraints: BoxConstraints(minHeight: minHeight),
                  alignment: Alignment.centerLeft,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum StudentsWeekAnimationMode { cricket, football, animals, singers }

class StudentsWeekAnimationWidget extends StatelessWidget {
  final Widget child;
  const StudentsWeekAnimationWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderImageCard(
      imageAsset: 'assets/headers/header_sports_gala.jpg',
      accentColor: const Color(0xFF10B981),
      borderRadius: 36.0,
      child: child,
    );
  }
}

// ==========================================================================
// CLASSES (NORMAL PERIOD) HEADER: DAY & NIGHT COMIC ARTWORK
// ==========================================================================

enum DayPeriod { morning, day, night }

class ClassesAnimationWidget extends StatelessWidget {
  final Widget child;
  const ClassesAnimationWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final isNight = hour < 6 || hour >= 18;
    final imageAsset = isNight
        ? 'assets/headers/header_classes_night.jpg'
        : 'assets/headers/header_classes_day.jpg';

    return HeaderImageCard(
      imageAsset: imageAsset,
      accentColor: IrisTokens.brand,
      borderRadius: 36.0,
      child: child,
    );
  }
}

// ==========================================================================
// MIDTERMS HEADER: STOPWATCH, GRAPH & CALC COMIC ARTWORK
// ==========================================================================

class MidtermsAnimationWidget extends StatelessWidget {
  final Widget child;
  const MidtermsAnimationWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderImageCard(
      imageAsset: 'assets/headers/header_midterms_mode.jpg',
      accentColor: const Color(0xFFF59E0B),
      borderRadius: 32.0,
      child: child,
    );
  }
}

// ==========================================================================
// RAMADAN MODE HEADER: FANCOUS LANTERN & COURTYARD COMIC ARTWORK
// ==========================================================================

class RamadanAnimationWidget extends StatelessWidget {
  final Widget child;
  const RamadanAnimationWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderImageCard(
      imageAsset: 'assets/headers/header_ramadan_mode.jpg',
      accentColor: const Color(0xFF10B981),
      borderRadius: 36.0,
      child: child,
    );
  }
}

// ==========================================================================
// FINALS WEEK HEADER: GRADUATION CAP & HALL COMIC ARTWORK
// ==========================================================================

class FinalsAnimationWidget extends StatelessWidget {
  final Widget child;
  const FinalsAnimationWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderImageCard(
      imageAsset: 'assets/headers/header_finals_week.jpg',
      accentColor: const Color(0xFF8B5CF6),
      borderRadius: 32.0,
      child: child,
    );
  }
}

// ==========================================================================
// TEACHER LOCATOR HEADER: BLUEPRINT & COMPASS COMIC ARTWORK
// ==========================================================================

class TeacherLocatorAnimationWidget extends StatelessWidget {
  final Widget child;
  const TeacherLocatorAnimationWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderImageCard(
      imageAsset: 'assets/headers/header_room_finder.jpg',
      accentColor: const Color(0xFF0EA5E9),
      borderRadius: 32.0,
      child: child,
    );
  }
}

// ==========================================================================
// ROOM FINDER HEADER: BLUEPRINT & CAMPUS MAP COMIC ARTWORK
// ==========================================================================

class RoomFinderAnimationWidget extends StatelessWidget {
  final Widget child;
  const RoomFinderAnimationWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderImageCard(
      imageAsset: 'assets/headers/header_room_finder.jpg',
      accentColor: const Color(0xFF0EA5E9),
      borderRadius: 32.0,
      child: child,
    );
  }
}

// ==========================================================================
// ACADEMICS / CGPA CALCULATOR HEADER: CGPA GAUGE COMIC ARTWORK
// ==========================================================================

class CgpaCalculatorAnimationWidget extends StatelessWidget {
  final Widget child;
  const CgpaCalculatorAnimationWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderImageCard(
      imageAsset: 'assets/headers/header_academics_hub.jpg',
      accentColor: IrisTokens.brand,
      borderRadius: 32.0,
      child: child,
    );
  }
}

// ==========================================================================
// FACULTY DIRECTORY & DEPARTMENT HUB HEADER: AUDITORIUM COMIC ARTWORK
// ==========================================================================

class DirectoryAnimationWidget extends StatelessWidget {
  final Widget child;
  const DirectoryAnimationWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderImageCard(
      imageAsset: 'assets/headers/header_faculty_hub.jpg',
      accentColor: const Color(0xFF6366F1),
      borderRadius: 32.0,
      child: child,
    );
  }
}

class DirectoryBackgroundWidget extends StatelessWidget {
  const DirectoryBackgroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/headers/header_faculty_hub.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: isDark ? const Color(0xFF0B101E) : const Color(0xFFF1F5F9),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  (isDark ? Colors.black : Colors.white).withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// IRIS HUB HEADER: HIGH-TECH COMMAND LAB COMIC ARTWORK
// ==========================================================================

class IrisHubAnimationWidget extends StatelessWidget {
  final Widget child;
  const IrisHubAnimationWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderImageCard(
      imageAsset: 'assets/headers/header_iris_hub.jpg',
      accentColor: const Color(0xFF6366F1),
      borderRadius: 32.0,
      child: child,
    );
  }
}
