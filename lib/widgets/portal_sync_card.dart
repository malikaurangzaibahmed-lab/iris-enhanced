import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/portal_sync_service.dart';
import '../screens/portal_screen.dart';
import '../core/tokens.dart';
import '../core/theme_signals.dart';
import '../core/vital_theme.dart';
import 'glass_card.dart';
import 'vital_card.dart';

class PortalSyncCard extends StatefulWidget {
  final bool isDark;

  const PortalSyncCard({super.key, required this.isDark});

  @override
  State<PortalSyncCard> createState() => _PortalSyncCardState();
}

class _PortalSyncCardState extends State<PortalSyncCard> {
  PortalSession? _session;
  List<PortalTask> _cachedTasks = [];
  String _syncStatus = 'success'; // 'success' or 'failed'

  @override
  void initState() {
    super.initState();
    _loadSession();
    PortalSyncService.syncNotifier.addListener(_loadSession);
  }

  @override
  void dispose() {
    PortalSyncService.syncNotifier.removeListener(_loadSession);
    super.dispose();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    const host = 'swl-sis.comsats.edu.pk';
    const scope = 'student';
    final sessionKey = 'iris_portal_${scope}_session_$host';
    final raw = prefs.getString(sessionKey);
    
    final status = prefs.getString('portal_last_bg_sync_status') ?? 'success';

    // Load independent cached tasks
    final tasks = await PortalSyncService.getCachedTasks();

    PortalSession? session;
    if (raw != null) {
      try {
        final sessionData = jsonDecode(raw) as Map<String, dynamic>;
        session = PortalSession.fromJson(sessionData);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _session = session;
        _cachedTasks = tasks;
        _syncStatus = status;
      });
    }
  }

  void _openPortal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PortalScreen(
          url: 'https://swl-sis.comsats.edu.pk/Login.aspx',
          title: 'COMSATS Student Portal',
          sessionScope: 'student',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedTasks.isEmpty && _session == null) {
      return const SizedBox.shrink();
    }

    final tasks = _cachedTasks.where((t) => !t.isCompleted).toList();
    final displayTasks = tasks.take(10).toList();
    final isFailed = _session == null || !_session!.hasValidCookies || _syncStatus == 'failed';
    final accentColor = isFailed ? IrisTokens.error : IrisTokens.brand;
    final statusLabel = isFailed 
        ? (_session == null || !_session!.hasValidCookies ? 'Session Expired' : 'Connection Lost')
        : (tasks.isEmpty ? 'Synced' : 'Active Updates');

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useVitalTheme,
      builder: (context, useVital, _) {
        if (useVital) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: GestureDetector(
              onTap: _openPortal,
              child: VitalCard(
                backgroundColor: isFailed ? VitalTokens.orange.withValues(alpha: widget.isDark ? 0.15 : 0.08) : null,
                border: isFailed ? Border.all(color: VitalTokens.orange.withValues(alpha: 0.3), width: 1.5) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFailed ? Icons.cloud_off_rounded : Icons.sync_rounded,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Portal Intelligence',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: widget.isDark ? Colors.white : Colors.black,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                statusLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: accentColor,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (tasks.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ...displayTasks.map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: task.isUrgent ? VitalTokens.orange : VitalTokens.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: widget.isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    '${task.subject} • ${task.dueDate}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: GestureDetector(
            onTap: _openPortal,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _StatusPulse(color: accentColor),
                            Icon(
                              isFailed ? Icons.cloud_off_rounded : Icons.sync_rounded,
                              color: accentColor,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Portal Sync',
                              style: IrisTextStyles.label(context).copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 0.3,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  statusLabel,
                                  style: IrisTextStyles.badgeText(context).copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (!isFailed && tasks.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      '•',
                                      style: TextStyle(
                                        color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${tasks.length} items',
                                    style: IrisTextStyles.metaInfo(context).copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (tasks.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...displayTasks.map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 3,
                            height: 18,
                            margin: const EdgeInsets.only(top: 2, right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: (task.isUrgent ? IrisTokens.error : IrisTokens.brand)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: IrisTextStyles.label(context).copyWith(
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${task.subject} • Due: ${task.dueDate}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: IrisTextStyles.metaInfo(context).copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ] else if (isFailed) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Background sync failed. Open portal to re-authenticate.',
                      style: IrisTextStyles.caption(context),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Everything up to date.',
                      style: IrisTextStyles.caption(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusPulse extends StatefulWidget {
  final Color color;

  const _StatusPulse({required this.color});

  @override
  State<_StatusPulse> createState() => _StatusPulseState();
}

class _StatusPulseState extends State<_StatusPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _scale = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _opacity.value),
            border: Border.all(
              color: widget.color.withValues(alpha: _opacity.value),
              width: 2,
            ),
          ),
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: _opacity.value * 0.5),
              ),
            ),
          ),
        );
      },
    );
  }
}
