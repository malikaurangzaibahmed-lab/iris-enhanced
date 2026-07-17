import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/glass.dart';

/// NativeLiquidGlass 
/// =================
/// This version bridges directly to the Android Native LiquidGlassView library.
/// It utilizes the hardware-accelerated AGSL shader pipeline from the repo.
class NativeLiquidGlass extends StatefulWidget {
  final Widget? child;
  final double radius;
  final double blurRadius;
  final Color? color;
  final double refractionHeight;
  final double refractionAmount;
  final double tintAlpha;

  const NativeLiquidGlass({
    super.key, 
    this.child,
    this.radius = 30.0,
    this.blurRadius = 4.0, // Increased default for better visibility
    this.color,
    this.refractionHeight = 45.0,
    this.refractionAmount = 35.0,
    this.tintAlpha = 0.08,
  });

  @override
  State<NativeLiquidGlass> createState() => _NativeLiquidGlassState();
}

class _NativeLiquidGlassState extends State<NativeLiquidGlass> {
  @override
  Widget build(BuildContext context) {
    // Only Android 13+ supports the AGSL RenderEffect pipeline
    final isSupported = defaultTargetPlatform == TargetPlatform.android;

    final reduceEffects = IrisGlass.reduceEffects(context);
    final effectiveBlur = IrisGlass.adaptiveBlur(
      context,
      widget.blurRadius,
      min: 2.0,
    );
    final effectiveRefractionHeight =
        reduceEffects ? widget.refractionHeight * 0.9 : widget.refractionHeight;
    final effectiveRefractionAmount =
        reduceEffects ? widget.refractionAmount * 0.9 : widget.refractionAmount;
    final effectiveTintAlpha =
        reduceEffects ? widget.tintAlpha * 0.85 : widget.tintAlpha;

    if (!isSupported) {
      return widget.child ?? const SizedBox();
    }

    return Stack(
      children: [
        // The Native Bridge Layer (The actual AGSL Shader from res/raw)
        Positioned.fill(
          child: AndroidView(
            viewType: 'android_liquid_glass',
            creationParams: {
              'radius': widget.radius,
              'blurRadius': effectiveBlur,
              'color': widget.color?.toARGB32(),
              'refractionHeight': effectiveRefractionHeight,
              'refractionAmount': effectiveRefractionAmount,
              'tintAlpha': effectiveTintAlpha,
            },
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),
        // The Content Overlay
        if (widget.child != null) 
          IgnorePointer(
            ignoring: false, // Allow interactions with content inside the glass
            child: widget.child!,
          ),
      ],
    );
  }
}
