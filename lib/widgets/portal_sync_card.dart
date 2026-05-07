import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/portal_sync_service.dart';
import '../portal_screen.dart';
import '../core/tokens.dart';
import 'glass_card.dart';

class PortalSyncCard extends StatefulWidget {
  final bool isDark;

  const PortalSyncCard({super.key, required this.isDark});

  @override
  State<PortalSyncCard> createState() => _PortalSyncCardState();
}

class _PortalSyncCardState extends State<PortalSyncCard> {
  PortalSession? _session;
  bool _isLoading = true;
  String _syncStatus = 'success'; // 'success' or 'failed'
  bool _isSyncing = false;

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

    if (raw != null) {
      try {
        final sessionData = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _session = PortalSession.fromJson(sessionData);
          _syncStatus = status;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _syncStatus = status;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _syncStatus = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const SizedBox.shrink();
    }

    final tasks = _session?.tasks.where((t) => !t.isCompleted).toList() ?? [];
    final displayTasks = tasks.take(3).toList();
    final isFailed = _syncStatus == 'failed';
    final accentColor = isFailed ? IrisTokens.error : IrisTokens.brand;
    final statusLabel = isFailed ? 'Connection Lost' : (tasks.isEmpty ? 'Synced' : 'Active Updates');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                        style: const TextStyle(
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
                            style: TextStyle(
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
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
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
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 0.2,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark 
                                  ? Colors.white.withValues(alpha: 0.9) 
                                  : Colors.black.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${task.subject} • Due: ${task.dueDate}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark 
                                  ? Colors.white.withValues(alpha: 0.5) 
                                  : Colors.black.withValues(alpha: 0.45),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Everything up to date.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                ),
              ),
            ],
          ],
        ),
      ),
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
