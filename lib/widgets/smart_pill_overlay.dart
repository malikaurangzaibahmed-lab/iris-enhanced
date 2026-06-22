import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../core/theme_signals.dart';
import '../services/system_broadcast_service.dart';
import '../core/tokens.dart';

/// A global wrapper widget that listens to the SystemBroadcastService.
/// Wrap this around your MaterialApp's home route, or your dashboard Scaffold,
/// and it will automatically pop the "Smart Pill" whenever an announcement drops.
class SmartPillOverlay extends StatefulWidget {
  final Widget child; // The main screen content

  const SmartPillOverlay({super.key, required this.child});

  @override
  State<SmartPillOverlay> createState() => _SmartPillOverlayState();
}

class _SmartPillOverlayState extends State<SmartPillOverlay> with TickerProviderStateMixin {
  late StreamSubscription _sub;
  String _title = "";
  String _body = "";
  bool _isUrgent = false;
  bool _isVisible = false;
  bool _isPersistent = false;
  Timer? _hideTimer;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late AnimationController _liquidController;
  late AnimationController _shimmerController;
  Offset _targetTilt = Offset.zero;

  @override
  void initState() {
    super.initState();
    // Glassmorphic Spring Animation
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack)
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut)
    );

    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // Listen to the Unified Broadcast Stream
    _sub = SystemBroadcastService().stream.listen((payload) {
      if (payload['dismiss'] == true) {
        _hide();
      } else {
        _show(
          payload['title'], 
          payload['body'], 
          payload['isUrgent'],
          isPersistent: payload['isPersistent'] == true,
        );
      }
    });
  }

  void _show(String title, String body, bool isUrgent, {bool isPersistent = false}) {
    setState(() {
      _title = title;
      _body = body;
      _isUrgent = isUrgent;
      _isPersistent = isPersistent;
      _isVisible = true;
    });
    
    // Fire the animation
    _animController.forward(from: 0.0);
    
    _hideTimer?.cancel();
    if (!isPersistent) {
      _hideTimer = Timer(const Duration(seconds: 6), () {
        _hide();
      });
    }
  }

  void _hide() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _isVisible = false);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _hideTimer?.cancel();
    _animController.dispose();
    _liquidController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Stack(
      children: [
        // The background app
        widget.child,
        
        // The Smart Pill Override
        if (_isVisible)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10, // Notch-aware floating offset
            left: 16,
            right: 16,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                 return Opacity(
                   opacity: _fadeAnim.value,
                   child: Transform.scale(
                     scale: _scaleAnim.value,
                     child: child,
                   ),
                 );
              },
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    final nextY = (_targetTilt.dx + details.delta.dx * 0.0018).clamp(-0.12, 0.12);
                    final nextX = (_targetTilt.dy - details.delta.dy * 0.0018).clamp(-0.12, 0.12);
                    _targetTilt = Offset(nextY, nextX);
                  });
                },
                onPanEnd: (details) {
                  if (_targetTilt.dy > 0.06 || details.velocity.pixelsPerSecond.dy < -200) {
                    _hide();
                  }
                  setState(() {
                    _targetTilt = Offset.zero;
                  });
                },
                child: TweenAnimationBuilder<Offset>(
                  tween: Tween<Offset>(begin: Offset.zero, end: _targetTilt),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  builder: (context, tilt, child) {
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002) // Perspective factor
                        ..rotateX(tilt.dy)
                        ..rotateY(tilt.dx),
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                  child: Material(
                    color: Colors.transparent,
                    elevation: 0,
                    child: GlassSurface(
                      settings: LiquidGlassSettings(
                        blur: 12.0,
                        ambientStrength: 0.70,
                        lightAngle: 0.15 * math.pi,
                        glassColor: _isUrgent 
                            ? IrisTokens.warning.withValues(alpha: 0.28)
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.45)),
                        thickness: 12,
                      ),
                      radius: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                        children: [
                          // Liquid Blobs Background
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _liquidController,
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _SmartPillLiquidPainter(
                                    progress: _liquidController.value,
                                    color: _isUrgent
                                        ? IrisTokens.warning.withValues(alpha: 0.10)
                                        : IrisTokens.brand.withValues(alpha: 0.08),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Diagonal Shimmer Sweep Effect
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: AnimatedBuilder(
                                animation: _shimmerController,
                                builder: (context, child) {
                                  final slideVal = _shimmerController.value;
                                  return FractionallySizedBox(
                                    widthFactor: 1.5,
                                    heightFactor: 1.0,
                                    child: Transform.translate(
                                      offset: Offset((slideVal * 2.0 - 1.0) * 420.0, 0),
                                      child: Transform.rotate(
                                        angle: -0.4,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                Colors.white.withValues(alpha: 0.0),
                                                Colors.white.withValues(alpha: 0.14),
                                                Colors.white.withValues(alpha: 0.0),
                                                Colors.transparent,
                                              ],
                                              stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isUrgent ? IrisTokens.warning : IrisTokens.brand).withValues(alpha: 0.12),
                                  blurRadius: 25,
                                  offset: const Offset(0, 8),
                                )
                              ]
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (_isUrgent ? IrisTokens.warning : IrisTokens.brand).withValues(alpha: 0.1)
                                  ),
                                  child: _title.toLowerCase().contains("sync") && _isPersistent
                                    ? SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(IrisTokens.brand),
                                        ),
                                      )
                                    : Icon(
                                        _getSmartIcon(),
                                        color: _isUrgent ? IrisTokens.warning : IrisTokens.brand,
                                        size: 28,
                                      ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _title.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900, 
                                          color: (isDark ? Colors.white : Colors.black87), 
                                          fontSize: 10,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _body,
                                        style: TextStyle(
                                          color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.8), 
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getSmartIcon() {
    final t = _title.toLowerCase();
    if (t.contains("auth") || t.contains("login") || t.contains("identity")) return Icons.fingerprint_rounded;
    if (t.contains("room") || t.contains("locate") || t.contains("find")) return Icons.location_on_rounded;
    if (t.contains("class") || t.contains("timetable") || t.contains("session")) return Icons.auto_awesome_rounded;
    if (t.contains("update") || t.contains("sync")) return Icons.sync_rounded;
    return _isUrgent ? Icons.warning_rounded : Icons.campaign_rounded;
  }
}

class _SmartPillLiquidPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SmartPillLiquidPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.2;

    for (int i = 0; i < 3; i++) {
      final angle = (progress * 2 * 3.14) + (i * 2.0);
      final x = center.dx + 40 * math.sin(angle) * 0.2; // Fixed: using math.sin
      final y = center.dy + 15 * math.cos(angle) * 0.2; // Fixed: using math.cos
      
      canvas.drawCircle(Offset(x, y), radius + (i * 5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SmartPillLiquidPainter oldDelegate) => true;
}
