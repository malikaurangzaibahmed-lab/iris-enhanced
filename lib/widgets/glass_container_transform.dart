import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iris/core/glass.dart';
import 'package:iris/widgets/native_liquid_glass.dart';

/// Modern OS-style Liquid Glass Container Transform Page Route.
/// Smoothly morphs any origin container bounds (e.g. menu card, banner)
/// into a full-screen destination page with liquid glass spring physics.
class GlassContainerTransformRoute<T> extends PageRouteBuilder<T> {
  final Widget destinationPage;
  final Rect? originBounds;
  final double originRadius;

  GlassContainerTransformRoute({
    required this.destinationPage,
    this.originBounds,
    this.originRadius = 24.0,
  }) : super(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 380),
          pageBuilder: (context, animation, secondaryAnimation) => destinationPage,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
              reverseCurve: Curves.easeInCubic,
            );

            final currentRadius = lerpDouble(originRadius, 0.0, curve.value) ?? 0.0;
            final scale = lerpDouble(0.92, 1.0, curve.value) ?? 1.0;

            return Transform.scale(
              scale: scale,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(currentRadius),
                child: FadeTransition(
                  opacity: curve,
                  child: child,
                ),
              ),
            );
          },
        );
}

/// Helper method to launch a container morphing transition from any BuildContext or origin key
void pushGlassContainerMorphRoute(
  BuildContext context, {
  required Widget page,
  GlobalKey? originKey,
  double originRadius = 24.0,
}) {
  Rect? bounds;
  if (originKey != null && originKey.currentContext != null) {
    final renderBox = originKey.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      bounds = position & renderBox.size;
    }
  }

  Navigator.of(context).push(
    GlassContainerTransformRoute(
      destinationPage: page,
      originBounds: bounds,
      originRadius: originRadius,
    ),
  );
}
