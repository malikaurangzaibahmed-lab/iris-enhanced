import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'glass.dart';
import 'tokens.dart';
import '../widgets/vital_card.dart';

/// Global signals used to toggle the minimal visual language at runtime.
class ThemeSignals {
  /// When true, app should use the minimal theme instead of the legacy liquid theme.
  static final ValueNotifier<bool> useMinimalTheme = ValueNotifier<bool>(false);

  /// When true, app should use the high-performance "Vital" health-style theme.
  static final ValueNotifier<bool> useVitalTheme = ValueNotifier<bool>(true);
}

/// A small wrapper that renders a low-cost boxed surface when the minimal UI
/// is enabled, otherwise renders the provided `LiquidGlass` layer.
class GlassSurface extends StatelessWidget {
  final LiquidGlassSettings settings;
  final double radius;
  final Widget child;
  final bool applyInLayer;

  const GlassSurface({
    super.key,
    required this.settings,
    required this.radius,
    required this.child,
    this.applyInLayer = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useVitalTheme,
      builder: (context, useVital, _) {
        if (useVital) {
          return VitalCard(
            borderRadius: radius,
            animate: false,
            padding: EdgeInsets.zero,
            child: child,
          );
        }
        return ValueListenableBuilder<bool>(
          valueListenable: ThemeSignals.useMinimalTheme,
          builder: (context, useMinimal, _) {
            if (useMinimal) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? IrisTokens.surfaceDarkElevated.withValues(alpha: 0.02)
                      : Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: isDark ? 0.04 : 0.04),
                    width: 1.0,
                  ),
                ),
                child: child,
              );
            }

            // Legacy glass rendering
            if (applyInLayer) {
              return LiquidGlassLayer(
                settings: settings,
                child: LiquidGlass.inLayer(
                  shape: IrisGlass.shape(radius),
                  glassContainsChild: false,
                  child: child,
                ),
              );
            }

            return LiquidGlass(
              settings: settings,
              shape: IrisGlass.shape(radius),
              child: child,
            );
          },
        );
      },
    );
  }
}
