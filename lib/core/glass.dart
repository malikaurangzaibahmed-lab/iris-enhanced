import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'animations.dart';
import 'tokens.dart';

class IrisGlass {
  static bool reduceEffects(BuildContext context) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return IrisMotion.reduceBlur || disableAnimations;
  }

  static double adaptiveBlur(
    BuildContext context,
    double base, {
    double min = 8.0,
  }) {
    if (!reduceEffects(context)) return base;
    final reduced = base * 0.7;
    return reduced.clamp(min, base);
  }

  static double adaptiveAmbient(BuildContext context, double base) {
    if (!reduceEffects(context)) return base;
    return (base * 0.88).clamp(0.35, 0.9);
  }

  static double adaptiveThickness(
    BuildContext context,
    double base, {
    double min = 10.0,
  }) {
    if (!reduceEffects(context)) return base;
    final reduced = base * 0.85;
    return reduced.clamp(min, base);
  }

  static Color adaptiveGlassColor(
    BuildContext context, {
    Color? dark,
    Color? light,
    double darkAlpha = 0.42,
    double lightAlpha = 0.45,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? (dark ?? IrisTokens.surfaceDarkElevated)
        : (light ?? Colors.white);
    return base.withValues(alpha: isDark ? darkAlpha : lightAlpha);
  }

  static LiquidGlassSettings settings(
    BuildContext context, {
    required double blur,
    required double ambientStrength,
    required double lightAngle,
    required double thickness,
    Color? glassColor,
    double minBlur = 8.0,
    double minThickness = 10.0,
  }) {
    return LiquidGlassSettings(
      blur: adaptiveBlur(context, blur, min: minBlur),
      ambientStrength: adaptiveAmbient(context, ambientStrength),
      lightAngle: lightAngle,
      glassColor: glassColor ?? adaptiveGlassColor(context),
      thickness: adaptiveThickness(context, thickness, min: minThickness),
    );
  }

  static LiquidRoundedSuperellipse shape(double radius) {
    return LiquidRoundedSuperellipse(
      borderRadius: Radius.circular(math.max(0, radius)),
    );
  }
}
