import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:iris/core/glass.dart';
import 'package:iris/core/theme_signals.dart';
import 'package:iris/core/animations.dart';
import 'package:iris/services/ui_feedback.dart';

/// Ultra-Premium Liquid Glass Container Transform Route.
/// Mimics iOS 18 / Android 15 OS-level container morphing with specular edge glow,
/// spring physics, backdrop blur scrim, and focal-point content expansion.
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
          transitionDuration: const Duration(milliseconds: 460),
          reverseTransitionDuration: const Duration(milliseconds: 380),
          opaque: false,
          barrierDismissible: false,
          barrierColor: Colors.transparent,
          pageBuilder: (context, animation, secondaryAnimation) => destinationPage,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final screenSize = MediaQuery.of(context).size;
            final fullScreenRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

            // Compute exact origin start rect
            Rect startRect = initialBounds ??
                Rect.fromCenter(
                  center: Offset(screenSize.width / 2, screenSize.height / 2),
                  width: screenSize.width * 0.45,
                  height: 100,
                );

            if (originKey != null && originKey.currentContext != null) {
              final renderBox = originKey.currentContext!.findRenderObject() as RenderBox?;
              if (renderBox != null && renderBox.hasSize) {
                final pos = renderBox.localToGlobal(Offset.zero);
                startRect = pos & renderBox.size;
              }
            }

            // Liquid OS Spring Curve
            final curve = CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.16, 1.0, 0.30, 1.0), // Fast launch with smooth spring landing
              reverseCurve: Curves.easeInCubic,
            );

            // Interpolated Rect, Radius, and Specular Glow
            final currentRect = Rect.lerp(startRect, fullScreenRect, curve.value) ?? fullScreenRect;
            final currentRadius = lerpDouble(originRadius, 0.0, curve.value) ?? 0.0;
            final scrimOpacity = (curve.value * 0.40).clamp(0.0, 0.40);
            final innerContentScale = lerpDouble(0.94, 1.0, curve.value) ?? 1.0;
            final edgeSpecularGlow = ((1.0 - (curve.value - 0.5).abs() * 2.0) * 0.45).clamp(0.0, 0.45);

            // Dual-child opacity thresholds
            final startOpacity = (1.0 - (curve.value / 0.35)).clamp(0.0, 1.0);
            final endOpacity = ((curve.value - 0.12) / 0.88).clamp(0.0, 1.0);

            final glow = accentColor ?? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6));

            return Stack(
              children: [
                // 1. Backdrop Scrim & Blur Isolation
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: lerpDouble(0.0, 12.0, curve.value) ?? 0.0,
                      sigmaY: lerpDouble(0.0, 12.0, curve.value) ?? 0.0,
                    ),
                    child: Container(
                      color: (isDark ? Colors.black : Colors.black87).withValues(alpha: scrimOpacity),
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
                      child: GlassSurface(
                        settings: IrisGlass.settings(
                          context,
                          blur: lerpDouble(20.0, 0.0, curve.value) ?? 0.0,
                          ambientStrength: 0.85,
                          lightAngle: 0.15 * math.pi,
                          thickness: lerpDouble(20.0, 0.0, curve.value) ?? 0.0,
                          glassColor: isDark 
                              ? Colors.black.withValues(alpha: lerpDouble(0.70, 1.0, curve.value) ?? 1.0)
                              : Colors.white.withValues(alpha: lerpDouble(0.88, 1.0, curve.value) ?? 1.0),
                        ),
                        radius: currentRadius,
                        child: AnimatedContainer(
                          duration: Duration.zero,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(currentRadius),
                            border: Border.all(
                              color: glow.withValues(alpha: edgeSpecularGlow),
                              width: lerpDouble(2.0, 0.0, curve.value) ?? 0.0,
                            ),
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
                                    alignment: Alignment.center,
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
  return Navigator.of(context).push<T>(
    GlassContainerTransformRoute<T>(
      destinationPage: page,
      originWidget: originWidget,
      originKey: originKey,
      initialBounds: initialBounds,
      originRadius: originRadius,
      accentColor: accentColor,
    ),
  );
}
