import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import '../core/glass.dart';
import '../core/theme_signals.dart';
import '../services/ui_feedback.dart';
import 'spring_button.dart';
import 'vital_card.dart';

class DashboardDock extends StatefulWidget {
  final VoidCallback? onHome;
  final VoidCallback? onTeacher;
  final VoidCallback? onPortal;
  final VoidCallback? onClasses;
  final VoidCallback? onTools;
  final VoidCallback? onMakeup;
  final VoidCallback? onAbout;
  final bool showFacultySet;
  final bool showStudentSet;
  final int selectedIndex;
  final ValueNotifier<double>? visibility;
  final ScrollController? scrollController;

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
    this.showStudentSet = false,
    this.selectedIndex = 0,
    this.visibility,
    this.scrollController,
  });

  @override
  State<DashboardDock> createState() => _DashboardDockState();

  Widget _buildDock(BuildContext context, _DashboardDockState state) {
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
    final itemCount = showStudentSet ? 4 : (showFacultySet ? 3 : 6);
    final safeSelected = state.displaySelectedIndex(itemCount, selectedIndex);
    final activeColor = showFacultySet ? IrisTokens.purple : IrisTokens.brand;
    final pillAccent = IrisTokens.brand;
    final glassSettings = IrisGlass.settings(
      context,
      blur: 24,
      ambientStrength: 0.75,
      lightAngle: 0.15 * math.pi,
      thickness: 24,
      glassColor: isDark
          ? Colors.black.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.32),
    );

    final dockContent = ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useVitalTheme,
      builder: (context, useVital, _) {
        if (useVital) {
          return Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 10),
            child: VitalCard(
              borderRadius: radius,
              padding: EdgeInsets.zero,
              animate: false,
              backgroundColor: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.9),
              child: SizedBox(
                height: navHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (event) => state.beginTracking(event.localPosition, constraints.maxWidth, navHeight, itemCount, selectedIndex),
                      onPointerMove: (event) => state.updateTracking(event.localPosition, constraints.maxWidth, navHeight, itemCount),
                      onPointerUp: (_) => state.endTracking(context, itemCount),
                      onPointerCancel: (_) => state.cancelTracking(),
                      child: CustomPaint(
                        foregroundPainter: ChromaticBorderPainter(
                          radius: radius,
                          width: 1.2,
                          isDark: isDark,
                          color: activeColor.withValues(alpha: isDark ? 0.35 : 0.18),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedPositioned(
                                duration: state.isDragging
                                    ? Duration.zero
                                    : const Duration(milliseconds: 250),
                                curve: IrisMotion.spring,
                                top: 4,
                                bottom: 4,
                                left: state.interactionPosition(itemCount, selectedIndex) *
                                        (constraints.maxWidth / itemCount) +
                                    4,
                                width: (constraints.maxWidth / itemCount) - 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: activeColor.withValues(alpha: isDark ? 0.32 : 0.18),
                                    borderRadius: BorderRadius.circular(radius - 4),
                                    border: Border.all(
                                      color: activeColor.withValues(alpha: isDark ? 0.65 : 0.45),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: activeColor.withValues(alpha: isDark ? 0.35 : 0.15),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                children: _buildNavButtons(context, isDark, safeSelected, activeColor, state, itemCount),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: ThemeSignals.useMinimalTheme,
          builder: (context, useMinimal, _) {
            final content = Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: RepaintBoundary(
                  child: CustomPaint(
                    foregroundPainter: ChromaticBorderPainter(
                      radius: radius,
                      width: 1.0,
                      isDark: isDark,
                      color: activeColor.withValues(alpha: isDark ? 0.30 : 0.15),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 304),
                      curve: IrisMotion.standard,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                      ),
                      child: SizedBox(
                        height: navHeight,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (event) => state.beginTracking(
                                event.localPosition,
                                constraints.maxWidth,
                                navHeight,
                                itemCount,
                                selectedIndex,
                              ),
                              onPointerMove: (event) => state.updateTracking(
                                event.localPosition,
                                constraints.maxWidth,
                                navHeight,
                                itemCount,
                              ),
                              onPointerUp: (_) => state.endTracking(
                                context,
                                itemCount,
                              ),
                              onPointerCancel: (_) => state.cancelTracking(),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  veryCompact ? 3 : (compact ? 5 : 6),
                                  veryCompact ? 2 : (compact ? 3 : 4),
                                  veryCompact ? 3 : (compact ? 5 : 6),
                                  veryCompact ? 2 : (compact ? 3 : 4),
                                ),
                                child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      AnimatedPositioned(
                                        duration: state.isDragging
                                            ? Duration.zero
                                            : const Duration(milliseconds: 250),
                                        curve: IrisMotion.spring,
                                        top: 3,
                                        bottom: 3,
                                        left: state.interactionPosition(itemCount, selectedIndex) *
                                                (constraints.maxWidth / itemCount) +
                                            3,
                                        width: (constraints.maxWidth / itemCount) - 6,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: activeColor.withValues(alpha: isDark ? 0.28 : 0.15),
                                            borderRadius: BorderRadius.circular(radius - 4),
                                            border: Border.all(
                                              color: activeColor.withValues(alpha: isDark ? 0.55 : 0.35),
                                              width: 1.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: activeColor.withValues(alpha: isDark ? 0.20 : 0.08),
                                                blurRadius: 8,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: _buildNavButtons(context, isDark, safeSelected, activeColor, state, itemCount),
                                      ),
                                    ],
                                  ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            if (useMinimal) return content;

            return Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: RepaintBoundary(
                  child: GlassSurface(
                    settings: glassSettings,
                    radius: radius,
                    child: CustomPaint(
                      foregroundPainter: ChromaticBorderPainter(
                        radius: radius,
                        width: 1.5,
                        isDark: isDark,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 304),
                        curve: IrisMotion.standard,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? Colors.black : pillAccent)
                                  .withValues(alpha: isDark ? 0.35 : 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                              spreadRadius: -6,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          height: navHeight,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Listener(
                                behavior: HitTestBehavior.translucent,
                                onPointerDown: (event) => state.beginTracking(
                                  event.localPosition,
                                  constraints.maxWidth,
                                  navHeight,
                                  itemCount,
                                  selectedIndex,
                                ),
                                onPointerMove: (event) => state.updateTracking(
                                  event.localPosition,
                                  constraints.maxWidth,
                                  navHeight,
                                  itemCount,
                                ),
                                onPointerUp: (_) => state.endTracking(
                                  context,
                                  itemCount,
                                ),
                                onPointerCancel: (_) => state.cancelTracking(),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    veryCompact ? 3 : (compact ? 5 : 6),
                                    veryCompact ? 2 : (compact ? 3 : 4),
                                    veryCompact ? 3 : (compact ? 5 : 6),
                                    veryCompact ? 2 : (compact ? 3 : 4),
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      AnimatedPositioned(
                                        duration: state.isDragging
                                            ? Duration.zero
                                            : const Duration(milliseconds: 250),
                                        curve: IrisMotion.spring,
                                        top: 4,
                                        bottom: 4,
                                        left: state.interactionPosition(itemCount, selectedIndex) *
                                                (constraints.maxWidth / itemCount) +
                                            4,
                                        width: (constraints.maxWidth / itemCount) - 8,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: activeColor.withValues(alpha: isDark ? 0.32 : 0.18),
                                            borderRadius: BorderRadius.circular(radius - 4),
                                            border: Border.all(
                                              color: activeColor.withValues(alpha: isDark ? 0.65 : 0.45),
                                              width: 1.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: activeColor.withValues(alpha: isDark ? 0.35 : 0.15),
                                                blurRadius: 10,
                                                spreadRadius: 1,
                                                offset: const Offset(0, 1),
                                              ),
                                              BoxShadow(
                                                color: (showFacultySet ? IrisTokens.purple : IrisTokens.brand).withValues(alpha: isDark ? 0.25 : 0.12),
                                                blurRadius: 20,
                                                spreadRadius: -2,
                                                offset: const Offset(0, 4),
                                              ),
                                              BoxShadow(
                                                color: const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.25 : 0.15),
                                                blurRadius: 6,
                                                spreadRadius: -1,
                                                offset: const Offset(-2, 0),
                                              ),
                                              BoxShadow(
                                                color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.20 : 0.10),
                                                blurRadius: 6,
                                                spreadRadius: -1,
                                                offset: const Offset(2, 0),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: _buildNavButtons(context, isDark, safeSelected, activeColor, state, itemCount),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    final tiltedDock = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateX(state._tiltX)
        ..rotateY(state._tiltY),
      alignment: Alignment.center,
      child: dockContent,
    );

    return ValueListenableBuilder<double>(
      valueListenable: state._internalVisibility,
      builder: (context, v, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..multiply(Matrix4.translationValues(0.0, (1.0 - v) * 100, 0.0))
            ..multiply(Matrix4.diagonal3Values(0.8 + (v * 0.2), 0.8 + (v * 0.2), 1.0)),
          child: Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: tiltedDock,
    );
  }

  List<Widget> _buildNavButtons(
    BuildContext context,
    bool isDark,
    int safeSelected,
    Color activeColor,
    _DashboardDockState state,
    int itemCount,
  ) {
    return [
      _buildNavButton(0, Icons.home_filled, Icons.home_rounded, 'Home', onHome ?? () => Navigator.of(context).popUntil((route) => route.isFirst), isDark, safeSelected, activeColor, state, itemCount),
      if (showStudentSet) ...[
        _buildNavButton(1, Icons.school_rounded, Icons.school_outlined, 'Academics', onClasses ?? () {}, isDark, safeSelected, activeColor, state, itemCount),
        _buildNavButton(2, Icons.grid_view_rounded, Icons.grid_view_outlined, 'Tools', onTools ?? () {}, isDark, safeSelected, activeColor, state, itemCount),
        _buildNavButton(3, Icons.info_rounded, Icons.info_outline_rounded, 'About', onAbout ?? () {}, isDark, safeSelected, activeColor, state, itemCount),
      ] else if (showFacultySet) ...[
        _buildNavButton(1, Icons.badge_rounded, Icons.badge_outlined, 'Teacher', onTeacher ?? () {}, isDark, safeSelected, activeColor, state, itemCount),
        _buildNavButton(2, Icons.info_rounded, Icons.info_outline_rounded, 'About', onAbout ?? () {}, isDark, safeSelected, activeColor, state, itemCount),
      ] else ...[
        _buildNavButton(1, Icons.search_rounded, Icons.search_rounded, 'Teacher', onTeacher ?? () {}, isDark, safeSelected, activeColor, state, itemCount),
        _buildNavButton(2, Icons.school_rounded, Icons.school_outlined, 'Classes', onClasses ?? () {}, isDark, safeSelected, activeColor, state, itemCount),
        _buildNavButton(3, Icons.build_rounded, Icons.build_outlined, 'Tools', onTools ?? () {}, isDark, safeSelected, activeColor, state, itemCount),
        _buildNavButton(4, Icons.event_repeat_rounded, Icons.event_repeat_outlined, 'Makeup', onMakeup ?? () {}, isDark, safeSelected, activeColor, state, itemCount),
        _buildNavButton(5, Icons.info_rounded, Icons.info_outline_rounded, 'About', onAbout ?? () {}, isDark, safeSelected, activeColor, state, itemCount),
      ],
    ];
  }

  Widget _buildNavButton(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    VoidCallback onTap,
    bool isDark,
    int safeSelected,
    Color activeColor,
    _DashboardDockState state,
    int itemCount,
  ) {
    final isSelected = safeSelected == index;
    return Expanded(
      child: BouncyNavButton(
        icon: isSelected ? activeIcon : inactiveIcon,
        label: label,
        isDark: isDark,
        isSelected: isSelected,
        showSelectionBackground: false,
        activeColor: activeColor,
        onTap: onTap,
      ),
    );
  }
}

class _DashboardDockState extends State<DashboardDock> {
  double? _dragPosition;
  bool _isDragging = false;
  bool _hasMoved = false;
  late final ValueNotifier<double> _internalVisibility;
  double _lastOffset = 0;
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  @override
  void initState() {
    super.initState();
    _internalVisibility = widget.visibility ?? ValueNotifier<double>(1.0);
    widget.scrollController?.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(DashboardDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      oldWidget.scrollController?.removeListener(_handleScroll);
      widget.scrollController?.addListener(_handleScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_handleScroll);
    if (widget.visibility == null) _internalVisibility.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!mounted) return;
    final controller = widget.scrollController!;
    if (!controller.hasClients) return;

    final offset = controller.offset;
    final delta = offset - _lastOffset;

    if (offset <= 0) {
      _internalVisibility.value = 1.0;
    } else if (delta > 10 && _internalVisibility.value > 0) {
      _internalVisibility.value = 0.0;
    } else if (delta < -20 && _internalVisibility.value < 1.0) {
      _internalVisibility.value = 1.0;
    }

    _lastOffset = offset;
  }

  bool get isDragging => _isDragging;

  double interactionPosition(int itemCount, int selectedIndex) {
    final safeIndex = selectedIndex.clamp(0, itemCount - 1);
    if (_isDragging && _dragPosition != null) {
      return _dragPosition!.clamp(0.0, itemCount - 1.0);
    }
    return safeIndex.toDouble();
  }

  int displaySelectedIndex(int itemCount, int selectedIndex) {
    return interactionPosition(itemCount, selectedIndex).round().clamp(0, itemCount - 1);
  }

  void beginTracking(
    Offset localPosition,
    double width,
    double height,
    int itemCount,
    int selectedIndex,
  ) {
    if (width <= 0 || height <= 0) return;
    setState(() {
      _isDragging = true;
      _hasMoved = false;
      final slotWidth = width / itemCount;
      _dragPosition = (localPosition.dx / slotWidth).clamp(
        0.0,
        itemCount - 1.0,
      );
      _dragPosition ??= selectedIndex.toDouble();

      final centerX = width / 2;
      final centerY = height / 2;
      _tiltX = ((localPosition.dy - centerY) / centerY) * -0.06;
      _tiltY = ((localPosition.dx - centerX) / centerX) * 0.06;
    });
  }

  void updateTracking(
    Offset localPosition,
    double width,
    double height,
    int itemCount,
  ) {
    if (!_isDragging || width <= 0 || height <= 0) return;
    setState(() {
      _hasMoved = true;
      final slotWidth = width / itemCount;
      _dragPosition = (localPosition.dx / slotWidth).clamp(
        0.0,
        itemCount - 1.0,
      );

      final centerX = width / 2;
      final centerY = height / 2;
      _tiltX = ((localPosition.dy - centerY) / centerY) * -0.06;
      _tiltY = ((localPosition.dx - centerX) / centerX) * 0.06;
    });
  }

  void endTracking(BuildContext context, int itemCount) {
    if (!_isDragging) return;
    if (!_hasMoved) {
      cancelTracking();
      return;
    }
    final targetIndex = interactionPosition(itemCount, widget.selectedIndex)
        .round()
        .clamp(0, itemCount - 1);
    setState(() {
      _isDragging = false;
      _dragPosition = null;
      _hasMoved = false;
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
    IrisHaptics.chipSelect();
    _activateIndex(context, targetIndex);
  }

  void cancelTracking() {
    if (!_isDragging) return;
    setState(() {
      _isDragging = false;
      _dragPosition = null;
      _hasMoved = false;
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  void _activateIndex(BuildContext context, int index) {
    if (widget.showStudentSet) {
      switch (index) {
        case 0:
          (widget.onHome ?? () => Navigator.of(context).popUntil((route) => route.isFirst))();
          break;
        case 1:
          widget.onPortal?.call();
          break;
        case 2:
          widget.onClasses?.call(); // Academics
          break;
        case 3:
          widget.onTools?.call(); // Tools
          break;
        case 4:
          widget.onAbout?.call(); // About
          break;
      }
      return;
    }

    switch (index) {
      case 0:
        (widget.onHome ?? () => Navigator.of(context).popUntil((route) => route.isFirst))();
        break;
      case 1:
        if (widget.showStudentSet) {
          widget.onPortal?.call();
        } else {
          widget.onTeacher?.call();
        }
        break;
      case 2:
        if (widget.showStudentSet) {
          widget.onTools?.call();
        } else {
          widget.onPortal?.call();
        }
        break;
      case 3:
        if (widget.showStudentSet) {
          widget.onAbout?.call();
        } else if (widget.showFacultySet) {
          widget.onAbout?.call();
        } else {
          widget.onClasses?.call();
        }
        break;
      case 4:
        widget.onTools?.call();
        break;
      case 5:
        widget.onMakeup?.call();
        break;
      case 6:
        widget.onAbout?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget._buildDock(context, this);
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
                    widget.color.withValues(alpha: 0.22 + (t * 0.06)),
                    widget.color.withValues(alpha: 0.10 + (t * 0.03)),
                    widget.color.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ChromaticBorderPainter extends CustomPainter {
  final double radius;
  final double width;
  final bool isDark;
  final Color? color;

  ChromaticBorderPainter({
    required this.radius,
    this.width = 1.5,
    required this.isDark,
    this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final borderColor = color ?? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08));

    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant ChromaticBorderPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.width != width ||
      oldDelegate.isDark != isDark ||
      oldDelegate.color != color;
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
  final bool showSelectionBackground;
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
    this.showSelectionBackground = true,
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
      end: 1.08,
    ).animate(CurvedAnimation(parent: _selectCtrl, curve: IrisMotion.bouncy));
    _slideCurve = Tween<double>(
      begin: 0.0,
      end: -1.2,
    ).animate(CurvedAnimation(parent: _selectCtrl, curve: IrisMotion.bouncy));
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
            if (widget.isSelected)
              Positioned(
                left: -size * 0.6,
                top: -size * 0.6,
                right: -size * 0.6,
                bottom: -size * 0.6,
                child: Center(
                  child: NavActiveHalo(
                    size: size * 2.2,
                    color: widget.activeColor,
                  ),
                ),
              ),
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
                            width: 1.25,
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
                            width: 1.25,
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
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: widget.showLabelAlways
                    ? (veryCompact ? 2 : (compact ? 3 : 6))
                    : (veryCompact ? 3 : (compact ? 4 : (roomy ? 10 : 7))),
                vertical: widget.showLabelAlways
                    ? (veryCompact ? 4 : 5)
                    : (veryCompact ? 4 : (compact ? 5 : 7)),
              ),
                decoration: widget.isSelected && widget.showSelectionBackground
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
