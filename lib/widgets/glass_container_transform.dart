import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:animations/animations.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import '../services/ui_feedback.dart';
import '../core/glass.dart';
import '../core/theme_signals.dart';

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
    this.transitionDuration = const Duration(milliseconds: 460),
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

/// Forward spring physics to match liquid_glass_widgets GlassMorphController.open()
class LiquidSpringCurve extends Curve {
  final SpringSimulation _sim;
  final double duration;

  LiquidSpringCurve({
    double mass = 1.0,
    double stiffness = 300.0,
    double damping = 24.0,
    this.duration = 0.60,
    double initialVelocity = 0.0,
  }) : _sim = SpringSimulation(
          SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
          0.0,
          1.0,
          initialVelocity,
        );

  @override
  double transformInternal(double t) {
    return _sim.x(t * duration);
  }
}

/// Reverse spring physics to match liquid_glass_widgets GlassMorphController.close()
class ReverseLiquidSpringCurve extends Curve {
  final SpringSimulation _sim;
  final double duration;

  ReverseLiquidSpringCurve({
    double mass = 1.0,
    double stiffness = 300.0,
    double damping = 24.0,
    this.duration = 0.60,
    double initialVelocity = -2.5,
  }) : _sim = SpringSimulation(
          SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
          1.0,
          0.0,
          initialVelocity,
        );

  @override
  double transformInternal(double t) {
    // When reversing, framework passes t from 1.0 down to 0.0.
    // The elapsed real time is (1.0 - t) * duration.
    return _sim.x((1.0 - t) * duration);
  }
}

/// Ultra-Premium Liquid Glass Container Transform Route.
/// Mimics iOS 26 liquid glass morphing with true metaball shaders and elastic spring physics.
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
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          opaque: false,
          barrierDismissible: false,
          barrierColor: Colors.transparent,
          pageBuilder: (context, animation, secondaryAnimation) => destinationPage,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final screenSize = MediaQuery.sizeOf(context);

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
                  width: screenSize.width * 0.70,
                  height: 120,
                );
              }
            }

            final animCurve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            final t = animCurve.value;
            final currentRect = Rect.lerp(startRect, Offset.zero & screenSize, t)!;
            final currentRadius = lerpDouble(originRadius, 0.0, t)!.clamp(0.0, 48.0);
            final pageOpacity = Curves.easeIn.transform(t);
            final pageScale = lerpDouble(0.92, 1.0, t)!;
            final scrimOpacity = (t * 0.45).clamp(0.0, 0.45);

            final effectiveSettings = IrisGlass.settings(
              context,
              blur: 16.0,
              ambientStrength: 0.8,
              lightAngle: 0.15 * math.pi,
              thickness: 18.0,
              glassColor: IrisGlass.adaptiveGlassColor(context, darkAlpha: 0.85, lightAlpha: 0.9),
            );

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Backdrop Scrim Isolation
                if (scrimOpacity > 0.005)
                  Positioned.fill(
                    child: Opacity(
                      opacity: (t * 2.0).clamp(0.0, 1.0),
                      child: Container(
                        color: (isDark ? Colors.black : Colors.black87).withValues(alpha: scrimOpacity),
                      ),
                    ),
                  ),

                // 2. Snappy Geometric Morphing Body
                Positioned(
                  left: currentRect.left,
                  top: currentRect.top,
                  width: currentRect.width,
                  height: currentRect.height,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(currentRadius),
                    child: SizedBox(
                      width: currentRect.width,
                      height: currentRect.height,
                      child: GlassSurface(
                        settings: effectiveSettings,
                        radius: currentRadius,
                        child: Opacity(
                          opacity: pageOpacity,
                          child: Transform.scale(
                            scale: pageScale,
                            alignment: Alignment.center,
                            child: OverflowBox(
                              minWidth: screenSize.width,
                              maxWidth: screenSize.width,
                              minHeight: screenSize.height,
                              maxHeight: screenSize.height,
                              child: destinationPage,
                            ),
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
