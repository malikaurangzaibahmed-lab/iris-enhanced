import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final bool glow;
  final bool shimmer;
  final bool enableBlur;
  final bool enableShadow;
  final bool enableOverlay;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final int elevation;
  final Color? accentColor;
  final bool tilt;
  final VoidCallback? onTap;

  const GlassCard({
    required this.child,
    this.glow = false,
    this.shimmer = false,
    this.enableBlur = true,
    this.enableShadow = true,
    this.enableOverlay = false,
    this.padding,
    this.borderRadius,
    this.elevation = 2,
    this.accentColor,
    this.tilt = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectivePadding =
        padding ?? const EdgeInsets.all(IrisTokens.space24);
    final effectiveRadius = borderRadius ?? 24.0;
    final tintColor =
        accentColor ?? (isDark ? IrisTokens.brandDark : IrisTokens.brand);

    // Ultra-glass transparency with dark tint in dark mode
    final glassColor = isDark
        ? const Color(0xFF020617).withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.48);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    final tiltAngle = tilt ? 0.006 : 0.0;
    final blurSigma = enableBlur ? (IrisMotion.reduceBlur ? 15.0 : 28.0) : 0.0;

    final cardBody = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        boxShadow: enableShadow
            ? [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    offset: const Offset(0, 10),
                    blurRadius: 30,
                    spreadRadius: -6,
                  ),
                if (glow)
                  BoxShadow(
                    color: tintColor.withValues(alpha: isDark ? 0.08 : 0.06),
                    blurRadius: 20,
                    spreadRadius: -10,
                  ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap != null ? () {
              IrisHaptics.actionSoft();
              IrisSfx.tick();
              onTap!();
            } : null,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                padding: effectivePadding,
                decoration: BoxDecoration(
                  color: glassColor,
                  borderRadius: BorderRadius.circular(effectiveRadius),
                  border: Border.all(color: borderColor, width: 1.2),
                  // Subtle highlight gradient for premium depth
                  gradient: glow ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.04 : 0.12),
                      Colors.transparent,
                    ],
                  ) : null,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    if (IrisMotion.reduceMotion) {
      return Transform.rotate(angle: tiltAngle, child: cardBody);
    }

    return Transform.rotate(
      angle: tiltAngle,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: IrisMotion.medium,
        curve: IrisMotion.entrance,
        builder: (context, animValue, child) =>
            Transform.scale(scale: 0.97 + (animValue * 0.03), child: child),
        child: cardBody,
      ),
    );
  }
}
