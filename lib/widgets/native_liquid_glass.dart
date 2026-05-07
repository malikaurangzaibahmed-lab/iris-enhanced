import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    Key? key, 
    this.child,
    this.radius = 30.0,
    this.blurRadius = 4.0, // Increased default for better visibility
    this.color,
    this.refractionHeight = 45.0,
    this.refractionAmount = 35.0,
    this.tintAlpha = 0.08,
  }) : super(key: key);

  @override
  State<NativeLiquidGlass> createState() => _NativeLiquidGlassState();
}

class _NativeLiquidGlassState extends State<NativeLiquidGlass> {
  @override
  Widget build(BuildContext context) {
    // Only Android 13+ supports the AGSL RenderEffect pipeline
    final isSupported = defaultTargetPlatform == TargetPlatform.android;

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
              'blurRadius': widget.blurRadius,
              'color': widget.color?.value,
              'refractionHeight': widget.refractionHeight,
              'refractionAmount': widget.refractionAmount,
              'tintAlpha': widget.tintAlpha,
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
