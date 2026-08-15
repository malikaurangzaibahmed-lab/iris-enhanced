import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '../services/ui_feedback.dart';

/// Ultra-Premium Liquid Glass OpenContainer Widget.
/// Uses the canonical Flutter animations ContainerTransform with Liquid Glass styling,
/// specular border glow, and elastic spring curves.
class GlassOpenContainer extends StatelessWidget {
  final OpenContainerBuilder closedBuilder;
  final OpenContainerBuilder openBuilder;
  final double closedRadius;
  final double openRadius;
  final Color? closedColor;
  final Color? openColor;
  final Color? accentColor;
  final Duration transitionDuration;
  final bool tappable;

  const GlassOpenContainer({
    super.key,
    required this.closedBuilder,
    required this.openBuilder,
    this.closedRadius = 24.0,
    this.openRadius = 0.0,
    this.closedColor,
    this.openColor,
    this.accentColor,
    this.transitionDuration = const Duration(milliseconds: 450),
    this.tappable = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: transitionDuration,
      closedElevation: 0,
      openElevation: 0,
      tappable: tappable,
      closedColor: closedColor ?? Colors.transparent,
      openColor: openColor ?? defaultBg,
      middleColor: closedColor ?? defaultBg,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(closedRadius),
      ),
      openShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(openRadius),
      ),
      onClosed: (_) => IrisHaptics.actionSoft(),
      closedBuilder: (ctx, action) => closedBuilder(ctx, ({returnValue}) {
        IrisHaptics.actionMedium();
        action();
      }),
      openBuilder: openBuilder,
    );
  }
}

/// Ultra-Premium Liquid Glass Container Transform Route.
/// Mimics iOS 18 / Android 15 OS-level container morphing with specular edge glow,
/// true physical geometric scaling, backdrop blur scrim, and zero-jump pop collapse.
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
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 340),
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
                  width: screenSize.width * 0.60,
                  height: 140,
                );
              }
            }

            // Liquid OS Spring Curve (iOS 18 Elastic Glide Physics)
            final curve = CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.08, 0.95, 0.12, 1.0),
              reverseCurve: const Cubic(0.24, 0.0, 0.70, 0.20),
            );

            // True Geometric Rect, Corner Radius, and Continuous Specular Glow
            final currentRect = Rect.lerp(startRect, fullScreenRect, curve.value) ?? fullScreenRect;
            final currentRadius = lerpDouble(originRadius, 0.0, curve.value) ?? 0.0;
            final scrimOpacity = (curve.value * 0.50).clamp(0.0, 0.50);
            final edgeSpecularGlow = (math.sin(curve.value * math.pi) * 0.70).clamp(0.0, 0.70);

            // Continuous physical scale factor from origin card dimensions to fullscreen
            final widthScale = startRect.width / math.max(1.0, fullScreenRect.width);
            final heightScale = startRect.height / math.max(1.0, fullScreenRect.height);
            final baseScale = math.min(widthScale, heightScale).clamp(0.2, 1.0);
            final innerContentScale = lerpDouble(baseScale, 1.0, curve.value) ?? 1.0;

            // Seamless crossfade thresholds
            final startOpacity = (1.0 - (curve.value / 0.25)).clamp(0.0, 1.0);
            final endOpacity = ((curve.value - 0.04) / 0.96).clamp(0.0, 1.0);

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
                          sigmaX: 20.0 * curve.value,
                          sigmaY: 20.0 * curve.value,
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
                            // Origin Card Preview (Physically morphs outward)
                            if (originWidget != null && startOpacity > 0.01)
                              Opacity(
                                opacity: startOpacity,
                                child: Transform.scale(
                                  scale: lerpDouble(1.0, 1.25, curve.value) ?? 1.0,
                                  alignment: Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: startRect.width,
                                      height: startRect.height,
                                      child: originWidget,
                                    ),
                                  ),
                                ),
                              ),

                            // Destination Page (Physically blooms from center of morphing bounds)
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
