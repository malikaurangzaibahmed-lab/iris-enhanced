import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';
import '../core/theme_signals.dart';

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
  final Color? backgroundColor;
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
    this.backgroundColor,
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
    final glassColor = backgroundColor ?? (isDark
        ? const Color(0xFF020617).withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.48));
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    final tiltAngle = tilt ? 0.006 : 0.0;

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useMinimalTheme,
      builder: (context, useMinimal, _) {
        final reduceBlur = IrisMotion.reduceBlur || useMinimal || MediaQuery.of(context).disableAnimations;
        final blurSigma = enableBlur ? (reduceBlur ? 6.0 : 12.0) : 0.0;

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
            child: _buildGlassSurface(
              blurSigma: blurSigma,
              padding: effectivePadding,
              glassColor: glassColor,
              borderColor: borderColor,
              radius: effectiveRadius,
              glow: glow,
              isDark: isDark,
              child: child,
            ),
          ),
        ),
      ),
    );

        if (IrisMotion.reduceMotion || useMinimal) {
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
      },
    );
  }

  Widget _buildGlassSurface({
    required double blurSigma,
    required EdgeInsetsGeometry padding,
    required Color glassColor,
    required Color borderColor,
    required double radius,
    required bool glow,
    required bool isDark,
    required Widget child,
  }) {
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: glassColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1.2),
        // Subtle highlight gradient for premium depth
        gradient: glow
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.04 : 0.12),
                  Colors.transparent,
                ],
              )
            : null,
      ),
      child: child,
    );

    if (blurSigma <= 0.0) {
      return surface;
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: surface,
    );
  }
}
