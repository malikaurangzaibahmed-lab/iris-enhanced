import 'dart:ui';
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

/// A premium route transition that morphs origin container bounds into full screen with modern OS container morphing physics.
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
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: transitionDuration ?? const Duration(milliseconds: 380),
      reverseTransitionDuration:
          reverseTransitionDuration ?? const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (animation.isCompleted) {
          return child;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final screenSize = MediaQuery.of(context).size;
        final fullScreenRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

        Rect startRect = Rect.fromCenter(
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

        final curve = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.05, 0.90, 0.10, 1.0),
          reverseCurve: const Cubic(0.30, 0.0, 0.80, 0.15),
        );

        final currentRect = Rect.lerp(startRect, fullScreenRect, curve.value) ?? fullScreenRect;
        final currentRadius = lerpDouble(24.0, 0.0, curve.value) ?? 0.0;
        final scrimOpacity = (curve.value * 0.40).clamp(0.0, 0.40);
        final innerContentScale = lerpDouble(0.94, 1.0, curve.value) ?? 1.0;
        final edgeSpecularGlow = ((1.0 - (curve.value - 0.5).abs() * 2.0) * 0.40).clamp(0.0, 0.40);
        final endOpacity = ((curve.value - 0.12) / 0.88).clamp(0.0, 1.0);

        final glow = isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

        return Stack(
          children: [
            // Backdrop Scrim Isolation with Dynamic Blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: lerpDouble(0.0, 10.0, curve.value) ?? 0.0,
                  sigmaY: lerpDouble(0.0, 10.0, curve.value) ?? 0.0,
                ),
                child: Container(
                  color: (isDark ? Colors.black : Colors.black87).withValues(alpha: scrimOpacity),
                ),
              ),
            ),

            // Morphing Glass Container with Specular Highlight
            Positioned.fromRect(
              rect: currentRect,
              child: PhysicalModel(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(currentRadius),
                elevation: lerpDouble(8.0, 0.0, curve.value) ?? 0.0,
                shadowColor: glow.withValues(alpha: 0.30),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(currentRadius),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(currentRadius),
                      border: Border.all(
                        color: glow.withValues(alpha: edgeSpecularGlow),
                        width: lerpDouble(2.0, 0.0, curve.value) ?? 0.0,
                      ),
                    ),
                    child: Transform.scale(
                      scale: innerContentScale,
                      alignment: Alignment.center,
                      child: OverflowBox(
                        minWidth: screenSize.width,
                        maxWidth: screenSize.width,
                        minHeight: screenSize.height,
                        maxHeight: screenSize.height,
                        alignment: Alignment.topLeft,
                        child: Opacity(
                          opacity: endOpacity,
                          child: child,
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
  String? label,
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
PreferredSizeWidget irisFrostedAppBar({
  required String title,
  required bool isDark,
  List<Widget>? actions,
}) {
  final bgColor = isDark 
      ? const Color(0x600A0A0C) // Sleek dark frosted
      : const Color(0x90FFFFFF); // Sleek white frosted
  final borderColor = isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.08);

  return PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight),
    child: ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: AppBar(
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
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: actions,
          ),
        ),
      ),
    ),
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
