import 'package:flutter/material.dart';

class VitalMotion {
  // Durations - slightly longer for "calm" feel
  static const Duration fast = Duration(milliseconds: 300);
  static const Duration normal = Duration(milliseconds: 450);
  static const Duration slow = Duration(milliseconds: 700);

  // Curves - High-inertia, damped curves
  // Similar to iOS/Oppo health transitions
  static const Curve smoothEntrance = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve smoothExit = Cubic(0.5, 0.0, 1.0, 1.0);
  static const Curve fluid = Cubic(0.4, 0.0, 0.1, 1.0);
  static const Curve dampedSpring = Cubic(0.15, 0.85, 0.35, 1.0); // No overshoot, just soft snap

  // Physics for lists
  static const ScrollPhysics scrollPhysics = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );
}

/// A wrapper for smooth, non-jumpy entrance animations
class VitalEntrance extends StatelessWidget {
  final Widget child;
  final int index;
  final Offset offset;

  const VitalEntrance({
    required this.child,
    this.index = 0,
    this.offset = const Offset(0, 30),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: VitalMotion.normal,
      curve: VitalMotion.smoothEntrance,
      // Delay based on index to create a "wave" effect
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: offset * (1 - value),
            child: child,
          ),
        );
      },
    );
  }
}
