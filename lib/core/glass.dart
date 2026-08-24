import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'package:shared_preferences/shared_preferences.dart';
import 'animations.dart';
import 'tokens.dart';
import 'theme_signals.dart';

class IrisGlass {
  static final ValueNotifier<bool> isFastScrolling = ValueNotifier<bool>(false);

  static bool reduceEffects(BuildContext context) {
    return ThemeSignals.useMinimalTheme.value;
  }

  static double adaptiveBlur(
    BuildContext context,
    double base, {
    double min = 8.0,
  }) {
    if (ThemeSignals.useMinimalTheme.value) {
      return 0.0;
    }
    return base;
  }

  static double adaptiveAmbient(BuildContext context, double base) {
    if (ThemeSignals.useMinimalTheme.value) return 0.5;
    return base;
  }

  static double adaptiveThickness(
    BuildContext context,
    double base, {
    double min = 10.0,
  }) {
    if (ThemeSignals.useMinimalTheme.value) return 0.0;
    return base;
  }

  static Color adaptiveGlassColor(
    BuildContext context, {
    Color? dark,
    Color? light,
    double darkAlpha = 0.0,
    double lightAlpha = 0.0,
  }) {
    if (darkAlpha == 0.0 && lightAlpha == 0.0 && dark == null && light == null) {
      return Colors.transparent;
    }
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
      glassColor: glassColor ?? Colors.transparent,
      thickness: adaptiveThickness(context, thickness, min: minThickness),
    );
  }

  static lgw.LiquidGlassSettings widgetsSettings(
    BuildContext context, {
    required double blur,
    required double ambientStrength,
    required double lightAngle,
    required double thickness,
    Color? glassColor,
    double minBlur = 8.0,
    double minThickness = 10.0,
  }) {
    final s = settings(
      context,
      blur: blur,
      ambientStrength: ambientStrength,
      lightAngle: lightAngle,
      thickness: thickness,
      glassColor: glassColor,
      minBlur: minBlur,
      minThickness: minThickness,
    );
    return lgw.LiquidGlassSettings(
      blur: s.blur,
      ambientStrength: s.ambientStrength,
      lightAngle: s.lightAngle,
      glassColor: s.glassColor,
      thickness: s.thickness,
    );
  }

  static LiquidRoundedSuperellipse shape(double radius) {
    return LiquidRoundedSuperellipse(
      borderRadius: Radius.circular(math.max(0, radius)),
    );
  }
}
