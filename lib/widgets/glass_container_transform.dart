import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/ui_feedback.dart';

/// Ultra-Premium Liquid Glass Container Transform Route.
/// Mimics iOS 18 / Android 15 OS-level container morphing with specular edge glow,
/// elastic spring physics, backdrop blur scrim, and focal-point content expansion.
class GlassContainerTransformRoute<T> extends PageRouteBuilder<T> {
  final Widget destinationPage;
  final Widget? originWidget;
  final GlobalKey? originKey;
  final Rect? initialBounds;
  final double originRadius;
  final Color? accentColor;

  GlassContainerTransformRoute({
    required this.destinationPage,
    this.originWidget,
    this.originKey,
    this.initialBounds,
    this.originRadius = 24.0,
    this.accentColor,
  }) : super(
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          opaque: false,
          barrierDismissible: false,
          barrierColor: Colors.transparent,
          pageBuilder: (context, animation, secondaryAnimation) => destinationPage,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final screenSize = MediaQuery.of(context).size;
            final fullScreenRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

            // Compute exact origin start rect once
            Rect startRect = initialBounds ?? Rect.zero;
            if (startRect == Rect.zero) {
              if (originKey != null && originKey.currentContext != null) {
                final renderBox = originKey.currentContext!.findRenderObject() as RenderBox?;
                if (renderBox != null && renderBox.hasSize) {
                  final pos = renderBox.localToGlobal(Offset.zero);
                  startRect = pos & renderBox.size;
                }
              }
              if (startRect == Rect.zero) {
                startRect = Rect.fromCenter(
                  center: Offset(screenSize.width / 2, screenSize.height / 2),
                  width: screenSize.width * 0.55,
                  height: 120,
                );
              }
            }

            // Liquid OS Spring Curve (iOS 18 Elastic Glide Physics)
            final curve = CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.08, 0.95, 0.12, 1.0),
              reverseCurve: const Cubic(0.24, 0.0, 0.70, 0.20),
            );

            // Interpolated Rect, Radius, and Specular Glow
            final currentRect = Rect.lerp(startRect, fullScreenRect, curve.value) ?? fullScreenRect;
            final currentRadius = lerpDouble(originRadius, 0.0, curve.value) ?? 0.0;
            final scrimOpacity = (curve.value * 0.45).clamp(0.0, 0.45);
            final innerContentScale = lerpDouble(0.96, 1.0, curve.value) ?? 1.0;
            final edgeSpecularGlow = (math.sin(curve.value * math.pi) * 0.60).clamp(0.0, 0.60);

            // Dual-child opacity thresholds for seamless crossfade
            final startOpacity = (1.0 - (curve.value / 0.26)).clamp(0.0, 1.0);
            final endOpacity = ((curve.value - 0.05) / 0.95).clamp(0.0, 1.0);

            final glow = accentColor ?? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6));

            return Stack(
              children: [
                // 1. Backdrop Scrim & Blur Isolation
                if (scrimOpacity > 0.005)
                  Positioned.fill(
                    child: Opacity(
                      opacity: (curve.value * 2.2).clamp(0.0, 1.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 18.0 * curve.value,
                          sigmaY: 18.0 * curve.value,
                        ),
                        child: Container(
                          color: (isDark ? Colors.black : Colors.black87).withValues(alpha: scrimOpacity),
                        ),
                      ),
                    ),
                  ),

                // 2. Morphing Specular Glass Container
                Positioned.fromRect(
                  rect: currentRect,
                  child: PhysicalModel(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(currentRadius),
                    elevation: lerpDouble(8.0, 0.0, curve.value) ?? 0.0,
                    shadowColor: glow.withValues(alpha: 0.35),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(currentRadius),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Color.lerp(const Color(0xFF0F172A), const Color(0xFF030712), curve.value)
                              : Color.lerp(const Color(0xFFF1F5F9), const Color(0xFFF8FAFC), curve.value),
                          borderRadius: BorderRadius.circular(currentRadius),
                          border: Border.all(
                            color: glow.withValues(alpha: edgeSpecularGlow),
                            width: lerpDouble(2.0, 0.0, curve.value) ?? 0.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: glow.withValues(alpha: (0.35 * (1.0 - curve.value)).clamp(0.0, 0.35)),
                              blurRadius: lerpDouble(24.0, 0.0, curve.value) ?? 0.0,
                              spreadRadius: lerpDouble(2.0, 0.0, curve.value) ?? 0.0,
                            ),
                          ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Origin Card Preview (Fades Out)
                            if (originWidget != null && startOpacity > 0.01)
                              Opacity(
                                opacity: startOpacity,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: startRect.width,
                                    height: startRect.height,
                                    child: originWidget,
                                  ),
                                ),
                              ),

                            // Destination Page (Scales in & Fades In)
                            if (endOpacity > 0.01)
                              Opacity(
                                opacity: endOpacity,
                                child: Transform.scale(
                                  scale: innerContentScale,
                                  alignment: Alignment.topCenter,
                                  child: OverflowBox(
                                    minWidth: screenSize.width,
                                    maxWidth: screenSize.width,
                                    minHeight: screenSize.height,
                                    maxHeight: screenSize.height,
                                    alignment: Alignment.topLeft,
                                    child: child,
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
            );
          },
        );
}

/// Global helper function to launch True Specular Container Morphing
Future<T?> pushGlassContainerMorphRoute<T>(
  BuildContext context, {
  required Widget page,
  Widget? originWidget,
  GlobalKey? originKey,
  Rect? initialBounds,
  double originRadius = 24.0,
  Color? accentColor,
}) {
  IrisHaptics.actionMedium();

  Rect? bounds = initialBounds;
  if (bounds == null) {
    if (originKey != null && originKey.currentContext != null) {
      final renderBox = originKey.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final pos = renderBox.localToGlobal(Offset.zero);
        bounds = pos & renderBox.size;
      }
    } else {
      try {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final pos = renderBox.localToGlobal(Offset.zero);
          bounds = pos & renderBox.size;
        }
      } catch (_) {}
    }
  }

  return Navigator.of(context).push<T>(
    GlassContainerTransformRoute<T>(
      destinationPage: page,
      originWidget: originWidget,
      originKey: originKey,
      initialBounds: bounds,
      originRadius: originRadius,
      accentColor: accentColor,
    ),
  );
}
