import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class IrisMotion {
  static const Duration fast = Duration(milliseconds: 240);
  static const Duration normal = Duration(milliseconds: 380);
  static const Duration medium = Duration(milliseconds: 540);
  static const Duration slow = Duration(milliseconds: 800);

  // Global performance toggles for low-jank rendering on large widget trees.
  static const bool reduceMotion = false;
  static const bool reduceBlur = false; // Enabled full blur for Liquid Glass

  // Hyper-fluid 144Hz optimized curves
  static const Curve entrance = Cubic(0.0, 0.0, 0.05, 1.0); // Ultra-fast start, long tail
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasized = Cubic(0.15, 0.0, 0.0, 1.0);
  static const Curve bouncy = Cubic(0.175, 0.885, 0.32, 1.275);
  static const Curve fluid = Cubic(0.4, 0.0, 0.2, 1.0);
  static const Curve spring = Cubic(0.175, 0.885, 0.32, 1.15); // Tighter physical snap
}

/// A premium route transition that mimics the "Icon Launch" feel of modern OSes.
Future<T?> pushIconLaunchRoute<T>(
  BuildContext context, {
  required Widget page,
  GlobalKey? originKey,
  bool lightweight = false,
  Duration? transitionDuration,
  Duration? reverseTransitionDuration,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: transitionDuration ?? IrisMotion.normal,
      reverseTransitionDuration:
          reverseTransitionDuration ?? const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: IrisMotion.emphasized,
          reverseCurve: Curves.easeInQuint, // Faster exit
        );

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: const Cubic(0.1, 0.0, 0.1, 1.0)),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: lightweight ? 0.96 : 0.88, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    ),
  );
}

/// A custom scroll physics that provides a "buttery smooth", high-momentum feel like premium OSes.
class ButterScrollPhysics extends BouncingScrollPhysics {
  const ButterScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  ButterScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ButterScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 1.2,
        stiffness: 140,
        damping: 18,
      );

  @override
  double get minFlingVelocity => 20.0;

  @override
  double get maxFlingVelocity => 15000.0;

  @override
  double get dragStartDistanceMotionThreshold => 1.0;
}

/// Premium frosted input decoration for tool sub-screens.
InputDecoration irisFrostedInputDecoration({
  required String label,
  required bool isDark,
  IconData? prefixIcon,
  String? hint,
}) {
  final fillColor = isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.04);
  final borderColor = isDark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.black.withValues(alpha: 0.10);
  final focusColor = isDark
      ? Colors.white.withValues(alpha: 0.24)
      : const Color(0xFF6366F1).withValues(alpha: 0.32);
  final labelColor = isDark
      ? Colors.white.withValues(alpha: 0.62)
      : Colors.black.withValues(alpha: 0.55);

  return InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: fillColor,
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, size: 18, color: labelColor)
        : null,
    labelStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: labelColor,
    ),
    hintStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: labelColor.withValues(alpha: 0.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: focusColor, width: 1.5),
    ),
  );
}

/// Premium frosted AppBar for tool sub-screens.
AppBar irisFrostedAppBar({
  required String title,
  required bool isDark,
  List<Widget>? actions,
}) {
  return AppBar(
    title: Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: isDark ? Colors.white : Colors.black,
      ),
    ),
    centerTitle: true,
    backgroundColor: Colors.transparent,
    forceMaterialTransparency: true,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    shadowColor: Colors.transparent,
    actions: actions,
  );
}

/// A smooth slide-and-fade entrance animation.
class MotionSlideFade extends StatelessWidget {
  final Widget child;
  final Offset beginOffset;
  final Duration duration;
  final Curve curve;

  const MotionSlideFade({
    required this.child,
    required this.beginOffset,
    this.duration = IrisMotion.medium,
    this.curve = IrisMotion.entrance,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (IrisMotion.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, _) => Transform.translate(
        offset: Offset(
          beginOffset.dx * (1 - value),
          beginOffset.dy * (1 - value),
        ),
        child: Opacity(opacity: value, child: child),
      ),
    );
  }
}

/// A smooth scale-and-fade entrance animation.
class MotionScaleFade extends StatelessWidget {
  final Widget child;
  final double beginScale;
  final Duration duration;
  final Curve curve;

  const MotionScaleFade({
    required this.child,
    this.beginScale = 0.9,
    this.duration = IrisMotion.medium,
    this.curve = IrisMotion.bouncy,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (IrisMotion.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, _) => Transform.scale(
        scale: beginScale + ((1 - beginScale) * value),
        child: Opacity(opacity: value, child: child),
      ),
    );
  }
}
