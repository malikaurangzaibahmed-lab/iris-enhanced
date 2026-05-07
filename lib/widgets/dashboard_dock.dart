import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import '../services/ui_feedback.dart';
import 'iris_components.dart';
import 'spring_button.dart';

class DashboardDock extends StatelessWidget {
  final VoidCallback? onHome;
  final VoidCallback? onTeacher;
  final VoidCallback? onPortal;
  final VoidCallback? onClasses;
  final VoidCallback? onTools;
  final VoidCallback? onMakeup;
  final VoidCallback? onAbout;
  final bool showFacultySet;
  final int selectedIndex;

  const DashboardDock({
    super.key,
    this.onHome,
    this.onTeacher,
    this.onPortal,
    this.onClasses,
    this.onTools,
    this.onMakeup,
    this.onAbout,
    this.showFacultySet = false,
    this.selectedIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final compact = width < (showFacultySet ? 420 : 470);
    final veryCompact = width < (showFacultySet ? 360 : 400);
    final navHeight = showFacultySet
        ? (veryCompact ? 48.0 : (compact ? 52.0 : 56.0))
        : (veryCompact ? 54.0 : (compact ? 58.0 : 62.0));
    final horizontalPadding = showFacultySet
        ? (veryCompact ? 10.0 : (compact ? 12.0 : 20.0))
        : (veryCompact ? 8.0 : (compact ? 10.0 : 14.0));
    final radius = showFacultySet
        ? (veryCompact ? 18.0 : (compact ? 22.0 : 28.0))
        : (veryCompact ? 18.0 : (compact ? 20.0 : 24.0));
    final itemCount = showFacultySet ? 4 : 7;
    final safeSelected = selectedIndex.clamp(0, itemCount - 1);
    final activeColor = showFacultySet ? IrisTokens.purple : IrisTokens.brand;
    final navActive = safeSelected != 0;
    final activeGlow = safeSelected == 0
        ? Colors.transparent
        : activeColor.withValues(alpha: isDark ? 0.18 : 0.13);

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: LiquidGlassLayer(
          settings: LiquidGlassSettings(
            blur: 12.0,
            ambientStrength: 0.65,
            lightAngle: 0.15 * math.pi,
            glassColor: (isDark ? IrisTokens.surfaceDarkElevated : Colors.white)
                .withValues(alpha: 0.38),
            thickness: 20,
          ),
          child: LiquidGlass.inLayer(
            shape: LiquidRoundedSuperellipse(
              borderRadius: Radius.circular(radius),
            ),
            glassContainsChild: false,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 304),
              curve: IrisMotion.standard,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: (isDark ? Colors.white : activeColor).withValues(
                    alpha: navActive ? 0.14 : 0.08,
                  ),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: activeGlow,
                    blurRadius: 18,
                    spreadRadius: -4,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SizedBox(
                height: navHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / itemCount;
                    final ultraDense = itemWidth < 48;
                    final dense = itemWidth < 56;
                    final trailWidth = showFacultySet
                        ? (veryCompact ? 16.0 : (compact ? 20.0 : 26.0))
                        : (ultraDense
                            ? 9.0
                            : (dense ? 12.0 : (veryCompact ? 14.0 : 18.0)));
                    final haloSize = showFacultySet
                        ? (veryCompact ? 30.0 : (compact ? 38.0 : 46.0))
                        : (ultraDense
                            ? 20.0
                            : (dense ? 24.0 : (veryCompact ? 28.0 : 34.0)));
                    final left = (itemWidth * safeSelected) +
                        ((itemWidth - trailWidth) / 2);
                    final haloLeft = (itemWidth * safeSelected) +
                        ((itemWidth - haloSize) / 2);
                    final trailColor = isDark
                        ? Colors.white.withValues(alpha: 0.70)
                        : activeColor.withValues(alpha: 0.80);

                    return Stack(
                      children: [
                        Positioned(
                          left: haloLeft,
                          top: ultraDense
                              ? 11
                              : (veryCompact ? 9 : (compact ? 8 : 7)),
                          child: IgnorePointer(
                            child: NavActiveHalo(
                              size: haloSize,
                              color: trailColor,
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 360),
                          curve: IrisMotion.standard,
                          left: left,
                          top: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 360),
                            curve: IrisMotion.standard,
                            width: trailWidth,
                            height: 4,
                            decoration: BoxDecoration(
                              color: trailColor,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: trailColor.withValues(alpha: 0.20),
                                  blurRadius: 8,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            ultraDense
                                ? 1
                                : (veryCompact ? 3 : (compact ? 5 : 6)),
                            ultraDense
                                ? 1
                                : (veryCompact ? 2 : (compact ? 3 : 4)),
                            ultraDense
                                ? 1
                                : (veryCompact ? 3 : (compact ? 5 : 6)),
                            ultraDense
                                ? 1
                                : (veryCompact ? 2 : (compact ? 3 : 4)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: BouncyNavButton(
                                  icon: safeSelected == 0
                                      ? Icons.home_filled
                                      : Icons.home_rounded,
                                  label: 'Home',
                                  isDark: isDark,
                                  isSelected: safeSelected == 0,
                                  activeColor: activeColor,
                                  onTap: onHome ??
                                      () => Navigator.of(
                                            context,
                                          ).popUntil((route) => route.isFirst),
                                ),
                              ),
                              Expanded(
                                child: BouncyNavButton(
                                  icon: showFacultySet
                                      ? (safeSelected == 1
                                          ? Icons.badge_rounded
                                          : Icons.badge_outlined)
                                      : Icons.search_rounded,
                                  label: 'Teacher',
                                  isDark: isDark,
                                  isSelected: safeSelected == 1,
                                  activeColor: activeColor,
                                  onTap: onTeacher ?? () {},
                                ),
                              ),
                              Expanded(
                                child: BouncyNavButton(
                                  icon: Icons.public_rounded,
                                  label: 'Portal',
                                  isDark: isDark,
                                  isSelected: safeSelected == 2,
                                  activeColor: activeColor,
                                  onTap: onPortal ?? () {},
                                ),
                              ),
                              if (showFacultySet)
                                Expanded(
                                  child: BouncyNavButton(
                                    icon: safeSelected == 3
                                        ? Icons.info_rounded
                                        : Icons.info_outline_rounded,
                                    label: 'About',
                                    isDark: isDark,
                                    isSelected: safeSelected == 3,
                                    activeColor: activeColor,
                                    onTap: onAbout ?? () {},
                                  ),
                                )
                              else ...[
                                Expanded(
                                  child: BouncyNavButton(
                                    icon: safeSelected == 3
                                        ? Icons.school_rounded
                                        : Icons.school_outlined,
                                    label: 'Classes',
                                    isDark: isDark,
                                    isSelected: safeSelected == 3,
                                    activeColor: activeColor,
                                    onTap: onClasses ?? () {},
                                  ),
                                ),
                                Expanded(
                                  child: BouncyNavButton(
                                    icon: safeSelected == 4
                                        ? Icons.build_rounded
                                        : Icons.build_outlined,
                                    label: 'Tools',
                                    isDark: isDark,
                                    isSelected: safeSelected == 4,
                                    activeColor: activeColor,
                                    onTap: onTools ??
                                        () {
                                          showIrisFrostedSnackBar(
                                            context,
                                            dedupeKey:
                                                'tools_unavailable_from_screen',
                                            content: const Text(
                                              'Tools are unavailable from this screen.',
                                            ),
                                          );
                                        },
                                  ),
                                ),
                                Expanded(
                                  child: BouncyNavButton(
                                    icon: safeSelected == 5
                                        ? Icons.event_repeat_rounded
                                        : Icons.event_repeat_outlined,
                                    label: 'Makeup',
                                    isDark: isDark,
                                    isSelected: safeSelected == 5,
                                    activeColor: activeColor,
                                    onTap: onMakeup ?? () {},
                                  ),
                                ),
                                Expanded(
                                  child: BouncyNavButton(
                                    icon: safeSelected == 6
                                        ? Icons.info_rounded
                                        : Icons.info_outline_rounded,
                                    label: 'About',
                                    isDark: isDark,
                                    isSelected: safeSelected == 6,
                                    activeColor: activeColor,
                                    onTap: onAbout ?? () {},
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NavActiveHalo extends StatefulWidget {
  final double size;
  final Color color;

  const NavActiveHalo({super.key, required this.size, required this.color});

  @override
  State<NavActiveHalo> createState() => _NavActiveHaloState();
}

class _NavActiveHaloState extends State<NavActiveHalo>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entrance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1536),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: IrisMotion.standard);

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 576),
    );
    _entrance = CurvedAnimation(
      parent: _entranceCtrl,
      curve: IrisMotion.entrance,
    );
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _entrance]),
      builder: (context, _) {
        final t = _pulse.value;
        final e = _entrance.value;
        return Transform.scale(
          scale: e * (0.97 + (t * 0.04)),
          child: Opacity(
            opacity: e.clamp(0.0, 1.0),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color.withValues(alpha: 0.14 + (t * 0.05)),
                    widget.color.withValues(alpha: 0.05 + (t * 0.02)),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.72, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BouncyNavButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool isSelected;
  final bool enabled;
  final bool showLabelAlways;
  final bool showIndicator;
  final int? indicatorCount;
  final Color? indicatorColor;
  final Color activeColor;
  final VoidCallback onTap;
  final GlobalKey? launchIconKey;

  const BouncyNavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isDark,
    required this.isSelected,
    this.enabled = true,
    this.showLabelAlways = false,
    this.showIndicator = false,
    this.indicatorCount,
    this.indicatorColor,
    required this.activeColor,
    required this.onTap,
    this.launchIconKey,
  });

  @override
  State<BouncyNavButton> createState() => _BouncyNavButtonState();
}

class _BouncyNavButtonState extends State<BouncyNavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selectCtrl;
  late final Animation<double> _scaleCurve;
  late final Animation<double> _slideCurve;

  @override
  void initState() {
    super.initState();
    _selectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleCurve = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _selectCtrl, curve: IrisMotion.entrance));
    _slideCurve = Tween<double>(
      begin: 0.0,
      end: -0.85,
    ).animate(CurvedAnimation(parent: _selectCtrl, curve: IrisMotion.entrance));
    if (widget.isSelected) _selectCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(BouncyNavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _selectCtrl.forward(from: 0.0);
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _selectCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _selectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isSelected
        ? widget.activeColor
        : (widget.isDark ? Colors.white38 : Colors.black38);
    final color = widget.enabled
        ? baseColor
        : baseColor.withValues(alpha: widget.isDark ? 0.48 : 0.42);
    final showLabel = widget.isSelected || widget.showLabelAlways;
    final indicatorColor = widget.indicatorColor ?? widget.activeColor;
    final badgeCount = widget.indicatorCount ?? 0;
    final showCountBadge = badgeCount > 0 && !widget.isSelected;
    final badgeText = badgeCount > 9 ? '9+' : '$badgeCount';

    Widget buildIcon(double size, bool veryCompact) {
      return Container(
        key: widget.launchIconKey,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 192),
              switchInCurve: IrisMotion.entrance,
              switchOutCurve: IrisMotion.standard,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                widget.icon,
                key: ValueKey('${widget.icon.codePoint}_${widget.isSelected}'),
                color: color,
                size: size,
              ),
            ),
            if (widget.showIndicator && !widget.isSelected)
              Positioned(
                right: showCountBadge ? -8 : -2,
                top: showCountBadge ? -6 : -1,
                child: showCountBadge
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 14),
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: widget.isDark
                                ? IrisTokens.surfaceDarkElevated
                                : Colors.white,
                            width: 1.1,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            letterSpacing: 0.1,
                          ),
                        ),
                      )
                    : Container(
                        width: veryCompact ? 7 : 8,
                        height: veryCompact ? 7 : 8,
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isDark
                                ? IrisTokens.surfaceDarkElevated
                                : Colors.white,
                            width: 1.1,
                          ),
                        ),
                      ),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth;
        final veryCompact = slotWidth < 56;
        final compact = slotWidth < 74;
        final roomy = slotWidth > 108;

        return AnimatedBuilder(
          animation: _selectCtrl,
          builder: (context, child) {
            final yOffset = widget.showLabelAlways
                ? (_slideCurve.value * 0.32)
                : _slideCurve.value;
            final scale = widget.showLabelAlways
                ? (1.0 + ((_scaleCurve.value - 1.0) * 0.32))
                : _scaleCurve.value;
            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: SpringButton(
            onTap: widget.enabled ? widget.onTap : () {},
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.showLabelAlways
                    ? (veryCompact ? 2 : (compact ? 3 : 6))
                    : (veryCompact ? 3 : (compact ? 4 : (roomy ? 10 : 7))),
                vertical: widget.showLabelAlways
                    ? (veryCompact ? 4 : 5)
                    : (veryCompact ? 4 : (compact ? 5 : 7)),
              ),
              decoration: widget.isSelected
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.activeColor.withValues(alpha: 0.24),
                          widget.activeColor.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                          veryCompact ? 16 : (compact ? 20 : 24)),
                      border: Border.all(
                        color: widget.activeColor.withValues(alpha: 0.20),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.activeColor.withValues(alpha: 0.16),
                          blurRadius: 16,
                          spreadRadius: -8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    )
                  : const BoxDecoration(color: Colors.transparent),
              child: widget.showLabelAlways
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildIcon(veryCompact ? 16 : (compact ? 17 : 19),
                            veryCompact),
                        const SizedBox(height: 2),
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.isSelected
                                ? color
                                : (widget.isDark
                                    ? Colors.white.withValues(alpha: 0.72)
                                    : Colors.black.withValues(alpha: 0.62)),
                            fontWeight: widget.isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: veryCompact ? 8 : (compact ? 9 : 10),
                            height: 1.0,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildIcon(veryCompact ? 16 : (compact ? 18 : 21),
                            veryCompact),
                        if (showLabel) ...[
                          SizedBox(
                              width: veryCompact
                                  ? 3
                                  : (compact ? 4 : (roomy ? 8 : 6))),
                          Flexible(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 192),
                              curve: IrisMotion.standard,
                              style: TextStyle(
                                color: widget.isSelected
                                    ? color
                                    : (widget.isDark
                                        ? Colors.white.withValues(alpha: 0.62)
                                        : Colors.black.withValues(alpha: 0.55)),
                                fontWeight: widget.isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: veryCompact ? 8 : (compact ? 9 : 12),
                              ),
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
