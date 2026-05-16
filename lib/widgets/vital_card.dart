import 'package:flutter/material.dart';
import '../core/vital_theme.dart';
import '../core/vital_motion.dart';
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
    final effectiveRadius = borderRadius ?? VitalTokens.radius24;
    final theme = Theme.of(context);
    
    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(VitalTokens.space20),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardTheme.color,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: border ?? Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          width: 1.0,
        ),
        boxShadow: VitalTokens.softShadow(isDark),
      ),
      child: child,
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
