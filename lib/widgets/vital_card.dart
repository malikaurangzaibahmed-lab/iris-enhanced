import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import '../core/vital_theme.dart';
import '../core/vital_motion.dart';
import '../core/theme_signals.dart';
import '../services/ui_feedback.dart';

class VitalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final bool animate;
  final int index;

  const VitalCard({
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.backgroundColor,
    this.border,
    this.animate = true,
    this.index = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMinimal = ThemeSignals.useMinimalTheme.value;
    final effectiveRadius = borderRadius ?? VitalTokens.radius24;
    final cardBg = backgroundColor ?? (isDark ? (isMinimal ? const Color(0xFF0F1218) : const Color(0xFF161618)) : Colors.white);
    
    Widget content = Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: border ?? Border.all(
          color: isDark 
              ? (isMinimal ? const Color(0xFF1E2433) : Colors.white.withValues(alpha: 0.08))
              : (isMinimal ? const Color(0xFFE2E8F0) : Colors.black.withValues(alpha: 0.05)),
          width: 1.0,
        ),
        boxShadow: isMinimal
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(VitalTokens.space20),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(effectiveRadius),
          onTap: () {
            IrisHaptics.actionSoft();
            onTap!();
          },
          child: content,
        ),
      );
    }

    if (!animate) return content;

    return VitalEntrance(
      index: index,
      child: content,
    );
  }
}
