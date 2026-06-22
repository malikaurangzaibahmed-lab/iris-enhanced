import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassCard;
import '../services/ui_feedback.dart';

class SpringButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GlassButton.custom(
      onTap: () {
        if (isHeavy) {
          IrisHaptics.actionHeavy();
        } else {
          IrisHaptics.chipSelect();
        }
        onTap();
      },
      useOwnLayer: true,
      style: GlassButtonStyle.transparent,
      stretch: 0.3, // subtle stretch feel
      child: child,
    );
  }
}
