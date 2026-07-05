import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/tokens.dart';
import '../core/models.dart';
import '../core/glass.dart';
import '../core/omni_brain.dart';
import '../screens/room_finder_screen.dart';
import '../screens/teacher_locator_screen.dart';

class LiveClassHubSheet extends StatefulWidget {
  final OmniBrain brain;
  final dynamic memory;
  final String batch;
  final List<ClassSession> sessions;

  const LiveClassHubSheet({
    required this.brain,
    required this.memory,
    required this.batch,
    required this.sessions,
    super.key,
  });

  @override
  State<LiveClassHubSheet> createState() => _LiveClassHubSheetState();
}

class _LiveClassHubSheetState extends State<LiveClassHubSheet> {
  bool _muteAlerts = false;

  @override
  void initState() {
    super.initState();
    _loadMuteSettings();
  }

  Future<void> _loadMuteSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _muteAlerts = prefs.getBool('mute_class_alerts') ?? false;
    });
  }

  Future<void> _toggleMuteAlerts(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mute_class_alerts', val);
    setState(() {
      _muteAlerts = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final currentClass = widget.brain.getCurrentClass(widget.batch, now);

    // Calculate current class progress details
    double progress = 0.0;
    String progressLabel = 'No active class';
    if (currentClass != null) {
      try {
        final currentTime = now.hour + (now.minute / 60.0);
        final duration = (currentClass.safeEndVal - currentClass.safeStartVal).abs();
        progress = ((currentTime - currentClass.safeStartVal) / (duration > 0 ? duration : 1.0)).clamp(0.0, 1.0);
        final remainingHours = currentClass.safeEndVal - currentTime;
        final remainingMins = (remainingHours * 60).round().clamp(0, 90);
        progressLabel = '$remainingMins mins remaining (${(progress * 100).round()}% complete)';
      } catch (_) {
        progressLabel = 'Active now';
      }
    }

    // Filter remaining schedule for today
    final currentHourVal = now.hour + (now.minute / 60.0);
    final upcomingSessions = widget.sessions.where((s) {
      return s.safeStartVal > currentHourVal;
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag indicator bar (handle)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white30 : Colors.black12),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          
          // Sheet Title
          Row(
            children: [
              Icon(
                Icons.hub_rounded,
                color: isDark ? Colors.white : IrisTokens.brand,
                size: 26,
              ),
              const SizedBox(width: 10),
              Text(
                'Class Tracker Hub',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Active Class Details Section
          if (currentClass != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: IrisTokens.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'ONGOING LECTURE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: IrisTokens.success,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${currentClass.startTime} - ${currentClass.endTime}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentClass.subject.toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        'Room: ${currentClass.room}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.person_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          currentClass.teacher,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: IrisTokens.brand,
                      backgroundColor: (isDark ? Colors.white10 : Colors.black12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progressLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Empty Class State
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '🎉 Enjoy your free time!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No ongoing lecture slots found right now.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Shortcut Tools Action Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Dismiss sheet first
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomFinderScreen(memory: widget.memory, brain: widget.brain),
                      ),
                    );
                  },
                  icon: const Icon(Icons.meeting_room_rounded, size: 18),
                  label: const Text('Find Room'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IrisTokens.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Dismiss sheet first
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeacherLocatorScreen(
                          brain: widget.brain,
                          memory: widget.memory,
                          currentBatch: widget.batch,
                          initialTeacherQuery: currentClass?.teacher,
                          autoSearchInitial: currentClass != null,
                          showBackButton: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_search_rounded, size: 18),
                  label: const Text('Locate Teacher'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IrisTokens.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quiet Mode Class Alerts Settings Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_paused_rounded,
                  color: _muteAlerts ? IrisTokens.warning : (isDark ? Colors.white60 : Colors.black54),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiet Class Alerts',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Mute notification alerts during live slots',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
                lgw.GlassSwitch(
                  useOwnLayer: true,
                  settings: IrisGlass.widgetsSettings(
                    context,
                    blur: 16.0,
                    thickness: 12.0,
                    ambientStrength: isDark ? 0.65 : 0.72,
                    lightAngle: 1.5,
                  ),
                  value: _muteAlerts,
                  onChanged: _toggleMuteAlerts,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Upcoming Timeline Title
          Text(
            'TODAY\'S REMAINING LECTURES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: (isDark ? Colors.white54 : Colors.black54),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),

          // Upcoming lectures list
          if (upcomingSessions.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upcomingSessions.length,
              itemBuilder: (context, index) {
                final session = upcomingSessions[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.black.withValues(alpha: 0.01),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 32,
                        decoration: BoxDecoration(
                          color: IrisTokens.brand.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.subject,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Room ${session.room}  •  ${session.teacher}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white54 : Colors.black54),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        session.startTime,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: Text(
                'No remaining lectures scheduled for today. ✨',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white30 : Colors.black38),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
