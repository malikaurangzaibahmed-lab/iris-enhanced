import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';
import '../core/theme_signals.dart';
import '../core/glass.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

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
  final BoxBorder? border;
  final bool tilt;
  final bool animate;
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
    this.animate = false,
    this.onTap,
    this.border,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectivePadding =
        padding ?? const EdgeInsets.all(IrisTokens.space24);
    final effectiveRadius = borderRadius ?? 32.0;
    final tintColor =
        accentColor ?? (isDark ? IrisTokens.brandDark : IrisTokens.brand);

    // Ultra-glass transparency with dark tint in dark mode
    final glassColor = backgroundColor ?? (isDark
        ? const Color(0xFF020617).withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.48));

    final tiltAngle = tilt ? 0.006 : 0.0;

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useMinimalTheme,
      builder: (context, useMinimal, _) {
        final reduceBlur = IrisMotion.reduceBlur || useMinimal || MediaQuery.of(context).disableAnimations;
        final blurSigma = enableBlur ? (reduceBlur ? 6.0 : 12.0) : 0.0;

        final settings = IrisGlass.settings(
          context,
          blur: blurSigma,
          ambientStrength: 0.72,
          lightAngle: 1.5,
          thickness: 12.0,
          glassColor: glassColor,
        );

        final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(effectiveRadius));

        final cardBody = Container(
          decoration: ShapeDecoration(
            shape: shape,
            shadows: enableShadow
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
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: GlassSurface(
              settings: settings,
              radius: effectiveRadius,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap != null ? () {
                    IrisHaptics.actionSoft();
                    IrisSfx.tick();
                    onTap!();
                  } : null,
                  child: Padding(
                    padding: effectivePadding,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );

        Widget result = cardBody;
        if (tilt) {
          result = Transform.rotate(angle: tiltAngle, child: result);
        }

        if (animate && !IrisMotion.reduceMotion && !useMinimal) {
          result = TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: IrisMotion.medium,
            curve: IrisMotion.entrance,
            builder: (context, animValue, child) =>
                Transform.scale(scale: 0.97 + (animValue * 0.03), child: child),
            child: result,
          );
        }

        return result;
      },
    );
  }
}

