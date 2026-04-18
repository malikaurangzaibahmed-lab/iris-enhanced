import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Rect? _rectFromGlobalKey(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final renderObject = ctx.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  final origin = renderObject.localToGlobal(Offset.zero);
  return origin & renderObject.size;
}

bool _animationsDisabled(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  return mediaQuery?.disableAnimations ?? false;
}

Future<T?> pushIconLaunchRoute<T>(
  BuildContext context, {
  required Widget page,
  GlobalKey? originKey,
  bool lightweight = false,
  Duration? transitionDuration,
  Duration? reverseTransitionDuration,
}) {
  return Navigator.push<T>(
    context,
    IconLaunchPageRoute<T>(
      page: page,
      originRect: originKey == null ? null : _rectFromGlobalKey(originKey),
      lightweight: lightweight,
      transitionDurationOverride: transitionDuration,
      reverseTransitionDurationOverride: reverseTransitionDuration,
    ),
  );
}

// ============ CUSTOM PAGE TRANSITIONS ============

class _MotionSpec {
  static const Curve launchMoveCurve = Cubic(0.16, 0.84, 0.18, 1.0);
  static const Curve launchFadeCurve = Cubic(0.18, 0.82, 0.2, 1.0);
  static const Curve launchReverseCurve = Cubic(0.42, 0.0, 1.0, 1.0);
  static const Curve slideCurve = Cubic(0.18, 0.86, 0.18, 1.0);
  static const Curve slideReverseCurve = Cubic(0.38, 0.0, 1.0, 1.0);
  static const Curve settleCurve = Cubic(0.18, 1.0, 0.26, 1.0);
}

class IconLaunchPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Rect? originRect;
  final bool lightweight;
  final Duration? transitionDurationOverride;
  final Duration? reverseTransitionDurationOverride;

  IconLaunchPageRoute({
    required this.page,
    this.originRect,
    this.lightweight = false,
    this.transitionDurationOverride,
    this.reverseTransitionDurationOverride,
  }) : super(
      transitionDuration: transitionDurationOverride ?? const Duration(milliseconds: 500),
      reverseTransitionDuration: reverseTransitionDurationOverride ?? const Duration(milliseconds: 380),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (_animationsDisabled(context)) return child;
            final size = MediaQuery.of(context).size;
            final center = Offset(size.width / 2, size.height / 2);

            final sourceRect = originRect;
            final beginScale = sourceRect == null
              ? (lightweight ? 0.975 : 0.95)
                : (sourceRect.shortestSide / size.shortestSide).clamp(0.08, 0.30);
            final beginOffset = sourceRect == null
              ? (lightweight ? const Offset(0, 10) : const Offset(0, 16))
                : sourceRect.center - center;
            final beginRadius = sourceRect == null ? 22.0 : sourceRect.shortestSide / 2;

            final moveCurve = CurvedAnimation(
              parent: animation,
              curve: _MotionSpec.launchMoveCurve,
              reverseCurve: _MotionSpec.launchReverseCurve,
            );
            final fadeCurve = CurvedAnimation(
              parent: animation,
              curve: lightweight ? _MotionSpec.launchMoveCurve : _MotionSpec.launchFadeCurve,
              reverseCurve: _MotionSpec.launchReverseCurve,
            );

            final settleScale = Tween<double>(begin: 0.986, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.88, curve: _MotionSpec.settleCurve),
                reverseCurve: _MotionSpec.launchReverseCurve,
              ),
            );

            final offset = Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(moveCurve);
            final scale = Tween<double>(
              begin: beginScale,
              end: 1.0,
            ).animate(moveCurve);
            final radius = Tween<double>(
              begin: beginRadius,
              end: 0,
            ).animate(moveCurve);
            final fade = Tween<double>(
              begin: 0,
              end: 1,
            ).animate(fadeCurve);

            return FadeTransition(
              opacity: fade,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  Widget transformed = Transform.translate(
                    offset: offset.value,
                    child: Transform.scale(
                      scale: scale.value * settleScale.value,
                      child: child,
                    ),
                  );

                  // Clipping every frame is expensive on complex pages; skip for lightweight mode.
                  if (!lightweight && sourceRect != null) {
                    transformed = ClipRRect(
                      borderRadius: BorderRadius.circular(radius.value),
                      child: transformed,
                    );
                  }
                  return transformed;
                },
              ),
            );
          },
        );
}

class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Offset beginOffset;
  final Curve curve;

  SlidePageRoute({
    required this.page,
    this.beginOffset = const Offset(1.0, 0.0),
    this.curve = _MotionSpec.slideCurve,
  }) : super(
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 336),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (_animationsDisabled(context)) return child;
            // Primary transition - slide in from right
            final tween = Tween<Offset>(begin: beginOffset, end: Offset.zero);
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: curve,
              reverseCurve: _MotionSpec.slideReverseCurve,
            );
            final settleAnimation = Tween<double>(begin: 0.994, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.9, curve: _MotionSpec.settleCurve),
                reverseCurve: _MotionSpec.slideReverseCurve,
              ),
            );
            final slideTransition = SlideTransition(
              position: tween.animate(curvedAnimation),
              child: ScaleTransition(
                scale: settleAnimation,
                child: child,
              ),
            );
            
            // Handle reverse animation (pop) - fade out slightly
            final reverseFade = Tween<double>(begin: 1.0, end: 0.975).animate(
              CurvedAnimation(parent: secondaryAnimation, curve: _MotionSpec.slideReverseCurve),
            );
            
            return FadeTransition(
              opacity: reverseFade,
              child: slideTransition,
            );
          },
        );
}

class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeScalePageRoute({required this.page})
      : super(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 352),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (_animationsDisabled(context)) return child;
            // Forward animation - fade in and scale up
            final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: _MotionSpec.launchFadeCurve),
            );
            
            final scaleIn = Tween<double>(begin: 0.94, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: _MotionSpec.launchMoveCurve,
                reverseCurve: _MotionSpec.slideReverseCurve,
              ),
            );

            return FadeTransition(
              opacity: fadeIn,
              child: ScaleTransition(
                scale: scaleIn,
                child: child,
              ),
            );
          },
        );
}

// ============ STAGGERED LIST ANIMATIONS ============

class StaggeredListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 42),
    this.duration = const Duration(milliseconds: 448),
    this.curve = _MotionSpec.launchMoveCurve,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  bool _staggerStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 1.0, curve: _MotionSpec.launchFadeCurve),
      ),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.965, end: 1.0)
            .chain(CurveTween(curve: widget.curve)),
        weight: 84,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.997)
            .chain(CurveTween(curve: _MotionSpec.settleCurve)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.997, end: 1.0)
            .chain(CurveTween(curve: _MotionSpec.launchMoveCurve)),
        weight: 8,
      ),
    ]).animate(_controller);
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.065),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.92, curve: _MotionSpec.launchMoveCurve),
      ),
    );

  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationsDisabled(context)) {
      _controller.value = 1.0;
      return;
    }
    if (_staggerStarted) return;
    _staggerStarted = true;
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

// ============ SHIMMER LOADING EFFECT ============

class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration period;

  const ShimmerLoading({
    super.key,
    required this.child,
    Color? baseColor,
    Color? highlightColor,
    this.period = const Duration(milliseconds: 1472),
  })  : baseColor = baseColor ?? const Color(0xFFE0E0E0),
        highlightColor = highlightColor ?? const Color(0xFFF5F5F5);

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isRepeating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = _animationsDisabled(context);
    if (disableAnimations) {
      if (_isRepeating) {
        _controller.stop();
        _isRepeating = false;
      }
      return;
    }
    if (!_isRepeating) {
      _controller.repeat();
      _isRepeating = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animationsDisabled(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 - _controller.value * 2, 0.0),
              end: Alignment(1.0 - _controller.value * 2, 0.0),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      baseColor: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

// ============ ANIMATED BUTTON ============

class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final double? width;
  final double? height;
  final bool hapticFeedback;
  final Duration duration;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.width,
    this.height,
    this.hapticFeedback = true,
    this.duration = const Duration(milliseconds: 168),
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 216),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _controller,
        curve: _MotionSpec.slideCurve,
        reverseCurve: _MotionSpec.settleCurve,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  void _handleTap() {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
      onTap: widget.onPressed != null ? _handleTap : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ============ BOUNCE SCALE ANIMATION ============

class BounceScale extends StatefulWidget {
  final Widget child;
  final double scaleFactor;
  final Duration duration;

  const BounceScale({
    super.key,
    required this.child,
    this.scaleFactor = 1.05,
    this.duration = const Duration(milliseconds: 224),
  });

  @override
  State<BounceScale> createState() => _BounceScaleState();
}

class _BounceScaleState extends State<BounceScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: widget.scaleFactor)
            .chain(CurveTween(curve: _MotionSpec.slideCurve)),
        weight: 58,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.scaleFactor, end: 0.992)
            .chain(CurveTween(curve: _MotionSpec.settleCurve)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.992, end: 1.0)
            .chain(CurveTween(curve: _MotionSpec.settleCurve)),
        weight: 22,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void trigger() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

// ============ SLIDE REVEAL ANIMATION ============

class SlideReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  const SlideReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 512),
    this.beginOffset = const Offset(0, 0.085),
  });

  @override
  State<SlideReveal> createState() => _SlideRevealState();
}

class _SlideRevealState extends State<SlideReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: _MotionSpec.slideCurve),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.06, 1.0, curve: _MotionSpec.launchFadeCurve),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.985, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: _MotionSpec.settleCurve),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

// ============ RIPPLE EFFECT ============

class RippleEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color rippleColor;
  final double borderRadius;

  const RippleEffect({
    super.key,
    required this.child,
    this.onTap,
    Color? rippleColor,
    this.borderRadius = 12.0,
  }) : rippleColor = rippleColor ??const Color(0x20FFFFFF);

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap != null
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap?.call();
              }
            : null,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        splashColor: widget.rippleColor,
        highlightColor: widget.rippleColor.withValues(alpha: 0.1),
        child: widget.child,
      ),
    );
  }
}

// ============ PHYSICS-BASED SCROLL ============

/// Custom scroll physics for buttery smooth scrolling
class ButterScrollPhysics extends BouncingScrollPhysics {
  const ButterScrollPhysics({super.parent});

  @override
  ButterScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ButterScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 50.0;

  @override
  double get maxFlingVelocity => 8000.0;

  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 0.72, stiffness: 88.0, damping: 14.0);
}

// ============ NUMBER COUNTER ANIMATION ============

class AnimatedCounter extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? style;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 768),
    this.style,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: _MotionSpec.launchMoveCurve),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation = Tween<double>(
        begin: _previousValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(
        CurvedAnimation(parent: _controller, curve: _MotionSpec.launchMoveCurve),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          _animation.value.toInt().toString(),
          style: widget.style,
        );
      },
    );
  }
}

// ============ EXPANDABLE SECTION ============

class ExpandableSection extends StatefulWidget {
  final Widget child;
  final bool expand;
  final Duration duration;

  const ExpandableSection({
    super.key,
    required this.child,
    this.expand = false,
    this.duration = const Duration(milliseconds: 288),
  });

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: _MotionSpec.settleCurve,
    );
    
    if (widget.expand) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ExpandableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expand != oldWidget.expand) {
      if (widget.expand) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _animation,
      axisAlignment: -1.0,
      child: widget.child,
    );
  }
}

// ============ TAP SCALE WIDGET ============

/// Wraps a child with smooth tap scale feedback
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;
  final bool hapticFeedback;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.972,
    this.duration = const Duration(milliseconds: 140),
    this.hapticFeedback = true,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 208),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: _MotionSpec.slideCurve,
        reverseCurve: _MotionSpec.settleCurve,
      ),
    );
  }

  @override
  dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        if (widget.hapticFeedback) HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// ============ SMOOTH COLOR TRANSITION ============

/// Animated color transition widget
class SmoothColorTransition extends StatefulWidget {
  final Color color;
  final Widget Function(Color color) builder;
  final Duration duration;
  final Curve curve;

  const SmoothColorTransition({
    super.key,
    required this.color,
    required this.builder,
    this.duration = const Duration(milliseconds: 352),
    this.curve = _MotionSpec.launchFadeCurve,
  });

  @override
  State<SmoothColorTransition> createState() => _SmoothColorTransitionState();
}

class _SmoothColorTransitionState extends State<SmoothColorTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  Color? _previousColor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _previousColor = widget.color;
    _colorAnimation = ColorTween(
      begin: _previousColor,
      end: widget.color,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void didUpdateWidget(SmoothColorTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _previousColor = oldWidget.color;
      _colorAnimation = ColorTween(
        begin: _previousColor,
        end: widget.color,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return widget.builder(_colorAnimation.value ?? widget.color);
      },
    );
  }
}

// ============ PULSE ANIMATION ============

/// Continuous pulse/breathing animation
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;
  final bool autoStart;

  const PulseAnimation({
    super.key,
    required this.child,
    this.minScale = 0.965,
    this.maxScale = 1.03,
    this.duration = const Duration(milliseconds: 1400),
    this.autoStart = true,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.minScale, end: widget.maxScale)
            .chain(CurveTween(curve: _MotionSpec.slideCurve)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.maxScale, end: widget.minScale)
            .chain(CurveTween(curve: _MotionSpec.slideReverseCurve)),
        weight: 50,
      ),
    ]).animate(_controller);
    
    if (widget.autoStart) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

// ============ SMOOTH OPACITY TRANSITION ============

/// Animated opacity with smooth transitions
class SmoothOpacity extends StatefulWidget {
  final Widget child;
  final bool visible;
  final Duration duration;
  final Curve curve;

  const SmoothOpacity({
    super.key,
    required this.child,
    this.visible = true,
    this.duration = const Duration(milliseconds: 288),
    this.curve = _MotionSpec.launchFadeCurve,
  });

  @override
  State<SmoothOpacity> createState() => _SmoothOpacityState();
}

class _SmoothOpacityState extends State<SmoothOpacity>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    
    if (widget.visible) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(SmoothOpacity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: widget.child,
    );
  }
}
