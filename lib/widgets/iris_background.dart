import 'package:flutter/material.dart';

class IrisAppBackdrop extends StatelessWidget {
  final Widget child;

  const IrisAppBackdrop({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF000000), Color(0xFF0A0A0A), Color(0xFF111111)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2F2F7), Color(0xFFF9FBFF), Color(0xFFFFFFFF)],
          );

    final orbA = const Color(0xFFE0E7FF); // Soft Blue
    final orbB = const Color(0xFFF5F3FF); // Soft Purple
    final orbC = const Color(0xFFECFDF5); // Soft Green

    return DecoratedBox(
      decoration: BoxDecoration(gradient: background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -150,
            left: -120,
            child: _BackdropOrb(color: orbA, size: 320, intensity: 0.30),
          ),
          Positioned(
            top: 160,
            right: -110,
            child: _BackdropOrb(color: orbB, size: 260, intensity: 0.24),
          ),
          Positioned(
            bottom: -170,
            left: 26,
            child: _BackdropOrb(color: orbC, size: 330, intensity: 0.20),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double intensity;

  const _BackdropOrb({
    required this.color,
    required this.size,
    required this.intensity,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(intensity),
              color.withOpacity(0.06),
              Colors.transparent,
            ],
            stops: const [0.0, 0.48, 1.0],
          ),
        ),
      ),
    );
  }
}
