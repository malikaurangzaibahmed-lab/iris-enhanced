import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../services/ui_feedback.dart';

class SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isHeavy;

  const SpringButton({
    super.key,
    required this.child,
    required this.onTap,
    this.isHeavy = false,
  });

  @override
  State<SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<SpringButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final SpringDescription _spring = const SpringDescription(
    mass: 0.9,
    stiffness: 150.0,
    damping: 16.0,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, upperBound: 1.0)
      ..value = 0.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runAnimation(double target) {
    final simulation = SpringSimulation(
      _spring,
      _controller.value,
      target,
      0.0,
    );
    _controller.animateWith(simulation);
  }

  void _onTapDown(TapDownDetails details) {
    _runAnimation(0.15);
    IrisHaptics.actionSoft();
  }

  void _onTapUp(TapUpDetails details) {
    _runAnimation(0.0);
    if (widget.isHeavy) {
      IrisHaptics.actionHeavy();
    } else {
      IrisHaptics.chipSelect();
    }
    widget.onTap();
  }

  void _onTapCancel() {
    _runAnimation(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          return Transform.scale(scale: 1.0 - _controller.value, child: child);
        },
      ),
    );
  }
}
