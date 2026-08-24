import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

/// A premium input wrapper that adds an animating gradient border
/// and a soft breathing shadow glow when its child (e.g. TextField) is focused.
class IrisGlowingInputWrapper extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final List<Color>? gradientColors;
  final double borderWidth;
  final double glowRadius;

  const IrisGlowingInputWrapper({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.gradientColors,
    this.borderWidth = 1.2,
    this.glowRadius = 6.0,
  });

  @override
  State<IrisGlowingInputWrapper> createState() => _IrisGlowingInputWrapperState();
}

class _IrisGlowingInputWrapperState extends State<IrisGlowingInputWrapper>
    with TickerProviderStateMixin {
  late final AnimationController _focusController;
  late final AnimationController _rotateController;
  
  late final Animation<double> _focusAnimation;
  late final Animation<double> _rotationAnimation;

  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    // Smooth transition between unfocused and focused states
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _focusAnimation = CurvedAnimation(
      parent: _focusController,
      curve: IrisMotion.standard,
    );

    // Continuous rotation of the gradient border when active
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_rotateController);
  }

  @override
  void dispose() {
    _focusController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  void _onFocusChanged(bool hasFocus) {
    if (mounted) {
      setState(() {
        _isFocused = hasFocus;
      });
      if (hasFocus) {
        _focusController.forward();
        _rotateController.repeat();
      } else {
        _focusController.reverse();
        _rotateController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Futuristic glowing gradients from the Iris theme palette
    final defaultColors = [
      IrisTokens.brand,
      IrisTokens.purple,
      IrisTokens.blue,
      IrisTokens.brand,
    ];
    final colors = widget.gradientColors ?? defaultColors;

    return Focus(
      onFocusChange: _onFocusChanged,
      child: AnimatedBuilder(
        animation: Listenable.merge([_focusAnimation, _rotationAnimation]),
        builder: (context, child) {
          final focusVal = _focusAnimation.value;
          final rotationVal = _rotationAnimation.value;

          return RepaintBoundary(
            child: CustomPaint(
              painter: _GlowingBorderPainter(
                isFocused: _isFocused,
                focusValue: focusVal,
                rotationValue: rotationVal,
                borderRadius: widget.borderRadius,
                colors: colors,
                borderWidth: widget.borderWidth,
                glowRadius: widget.glowRadius,
                isDark: isDark,
              ),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(widget.borderWidth * 0.5),
          child: widget.child,
        ),
      ),
    );
  }
}

class _GlowingBorderPainter extends CustomPainter {
  final bool isFocused;
  final double focusValue;
  final double rotationValue;
  final double borderRadius;
  final List<Color> colors;
  final double borderWidth;
  final double glowRadius;
  final bool isDark;

  _GlowingBorderPainter({
    required this.isFocused,
    required this.focusValue,
    required this.rotationValue,
    required this.borderRadius,
    required this.colors,
    required this.borderWidth,
    required this.glowRadius,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = lgw.LiquidRoundedSuperellipse(borderRadius: borderRadius).getOuterPath(rect);

    // 1. Draw standard background glass border when unfocused
    if (focusValue < 1.0) {
      final baseBorderPaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08 * (1.0 - focusValue))
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawPath(path, baseBorderPaint);
    }

    // 2. Draw glowing shadow and border when focused
    if (focusValue > 0.0) {
      // Draw shadow glow
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + (glowRadius * focusValue)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, (glowRadius * 0.4 * focusValue).clamp(1.0, 20.0));

      final glowShader = SweepGradient(
        colors: colors.map((c) => c.withValues(alpha: c.a * 0.15 * focusValue)).toList(),
        transform: GradientRotation(rotationValue * 2 * math.pi),
      ).createShader(rect);

      glowPaint.shader = glowShader;
      canvas.drawPath(path, glowPaint);

      // Draw sharp focused inner border
      final activeBorderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + (0.5 * focusValue)
        ..shader = SweepGradient(
          colors: colors.map((c) => c.withValues(alpha: c.a * focusValue)).toList(),
          transform: GradientRotation(rotationValue * 2 * math.pi),
        ).createShader(rect);
      
      canvas.drawPath(path, activeBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowingBorderPainter oldDelegate) {
    return oldDelegate.isFocused != isFocused ||
        oldDelegate.focusValue != focusValue ||
        oldDelegate.rotationValue != rotationValue ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isDark != isDark;
  }
}

/// A helper that copies the standard irisFrostedInputDecoration style
/// but removes standard borders to allow the custom glowing border to display.
InputDecoration irisGlowingInputDecoration({
  String? label,
  required bool isDark,
  IconData? prefixIcon,
  String? hint,
}) {
  return irisFrostedInputDecoration(
    label: label,
    isDark: isDark,
    prefixIcon: prefixIcon,
    hint: hint,
  ).copyWith(
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

/// A global drop-in replacement for standard [TextField]s that applies the
/// glowing J-curve squircle wrapper and custom decoration automatically.
class IrisTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final bool isDark;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final List<TextInputFormatter>? inputFormatters;

  const IrisTextField({
    super.key,
    this.label,
    required this.isDark,
    this.hint,
    this.prefixIcon,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.onEditingComplete,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return IrisGlowingInputWrapper(
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        autofocus: autofocus,
        textInputAction: textInputAction,
        maxLines: maxLines,
        minLines: minLines,
        inputFormatters: inputFormatters,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: irisGlowingInputDecoration(
          label: label,
          isDark: isDark,
          prefixIcon: prefixIcon,
          hint: hint,
        ),
      ),
    );
  }
}

