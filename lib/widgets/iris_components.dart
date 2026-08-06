import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassCard;
import '../services/ui_feedback.dart';
import '../core/tokens.dart';
import '../core/animations.dart';
import '../core/models.dart';
import 'glass_card.dart';
import 'smart_widgets.dart';
import '../core/minimal_theme.dart';
import '../core/theme_signals.dart';
import 'vital_card.dart';
import '../core/vital_theme.dart';

class IrisComponents {
  /// Build a status badge (LIVE, NEXT, etc.)
  static Widget statusBadge({
    required String label,
    required Color color,
    required bool isDark,
    bool pulse = false,
  }) {
    final widget = ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useMinimalTheme,
      builder: (context, useMinimal, _) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: IrisTokens.space12,
            vertical: IrisTokens.space8 - 2,
          ),
          decoration: useMinimal
              ? BoxDecoration(
                  color: MinimalTokens.primary,
                  borderRadius: BorderRadius.circular(IrisTokens.radius12),
                )
              : BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.85)],
                  ),
                  borderRadius: BorderRadius.circular(IrisTokens.radius12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        );
      },
    );

    if (pulse) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1.05),
        duration: const Duration(milliseconds: 768),
        curve: IrisMotion.standard,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        onEnd: () {},
        child: widget,
      );
    }

    return widget;
  }

  /// Build a time badge
  static Widget timeBadge({required String time, required bool isDark}) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useMinimalTheme,
      builder: (context, useMinimal, _) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: IrisTokens.space12,
            vertical: IrisTokens.space8 - 2,
          ),
          decoration: useMinimal
              ? BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(IrisTokens.radius12),
                )
              : BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(IrisTokens.radius12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.24)
                        : Colors.black.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
          child: Text(
            time,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.86),
            ),
          ),
        );
      },
    );
  }

  /// Build an icon badge
  static Widget iconBadge({
    required IconData icon,
    required Color color,
    required bool isDark,
    double size = 32,
  }) {
    return Container(
      padding: EdgeInsets.all(size * 0.25),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.32 : 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Icon(icon, size: size * 0.65, color: color),
    );
  }

  /// Build a gender-aware faculty avatar with offline fallbacks
  static Widget facultyAvatar({
    required String? imageUrl,
    required String gender,
    required String name,
    double radius = 24,
    bool isDark = true,
  }) {
    final isFemale = gender.toLowerCase() == 'female';
    final accentColor = isFemale ? IrisTokens.purple : IrisTokens.blue;
    final fallbackIcon = isFemale ? Icons.face_3_rounded : Icons.face_rounded;
    
    // Create a deterministic background color based on name if no image
    final bgColor = accentColor.withValues(alpha: isDark ? 0.2 : 0.1);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? (imageUrl.startsWith('assets/')
                ? Image.asset(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildAvatarPlaceholder(fallbackIcon, accentColor, isDark),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildAvatarPlaceholder(fallbackIcon, accentColor, isDark),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildAvatarPlaceholder(fallbackIcon, accentColor, isDark);
                    },
                  ))
            : _buildAvatarPlaceholder(fallbackIcon, accentColor, isDark),
      ),
    );
  }

  static Widget _buildAvatarPlaceholder(IconData icon, Color color, bool isDark) {
    return Center(
      child: Icon(
        icon,
        color: color.withValues(alpha: 0.8),
        size: 24,
      ),
    );
  }

  /// Build a loading spinner
  static Widget loadingSpinner({
    Color? color,
    double size = 24,
    double strokeWidth = 2.0,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: color != null ? AlwaysStoppedAnimation<Color>(color) : null,
      ),
    );
  }

  /// Build a Quick Action Button for the iOS 18 style grid
  static Widget quickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return AnimatedButton(
      onPressed: onTap,
      child: ValueListenableBuilder<bool>(
        valueListenable: ThemeSignals.useMinimalTheme,
        builder: (context, useMinimal, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: useMinimal ? Colors.transparent : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.95)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.9),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Canonical settings tile used across the app
  static Widget settingsTile({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useMinimalTheme,
      builder: (context, useMinimal, _) {
        return ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: useMinimal ? Colors.transparent : IrisTokens.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: IrisTokens.brand, size: 24),
          ),
          title: Text(title, style: IrisTextStyles.settingTitle(context)),
          subtitle: Text(subtitle, style: IrisTextStyles.settingSubtitle(context)),
          trailing: onTap != null ? Icon(Icons.chevron_right_rounded, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2)) : null,
        );
      },
    );
  }

  /// Canonical settings toggle tile used across the app
  static Widget settingsToggle({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useMinimalTheme,
      builder: (context, useMinimal, _) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: useMinimal ? Colors.transparent : IrisTokens.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: IrisTokens.brand, size: 24),
          ),
          title: Text(title, style: IrisTextStyles.settingTitle(context)),
          subtitle: Text(subtitle, style: IrisTextStyles.settingSubtitle(context)),
          trailing: IrisGlassSwitch(
            value: value,
            onChanged: (v) {
              IrisHaptics.chipSelect();
              onChanged(v);
            },
            activeColor: IrisTokens.brand,
          ),
        );
      },
    );
  }
}

class RippleEffect extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? rippleColor;
  final BorderRadius? borderRadius;

  const RippleEffect({
    required this.child,
    this.onTap,
    this.rippleColor,
    this.borderRadius,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: rippleColor ?? IrisTokens.brand.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        borderRadius: borderRadius ?? BorderRadius.circular(IrisTokens.radius16),
        child: child,
      ),
    );
  }
}

class AnimatedButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Duration duration;

  const AnimatedButton({
    required this.child,
    this.onPressed,
    this.duration = const Duration(milliseconds: 150),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GlassButton.custom(
      onTap: () {
        IrisSfx.click();
        onPressed?.call();
      },
      useOwnLayer: true,
      style: GlassButtonStyle.transparent,
      stretch: 0.25, // subtle stretch feel
      child: child,
    );
  }
}

class StaggeredListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration? delay;

  const StaggeredListItem({
    required this.index,
    required this.child,
    this.delay,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedListItem(index: index, child: child);
  }
}

class AppBackButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onPressed;

  const AppBackButton({required this.isDark, this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: IconButton(
        onPressed: onPressed ?? () => Navigator.of(context).pop(),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class NavActiveHalo extends StatefulWidget {
  final double size;
  final Color color;

  const NavActiveHalo({required this.size, required this.color, super.key});

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
          child: GestureDetector(
            onTap: () {
              if (widget.enabled) {
                IrisHaptics.selectionClick();
                widget.onTap();
              }
            },
            child: Container(
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
                          widget.activeColor.withValues(alpha: 0.28),
                          widget.activeColor.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: widget.activeColor.withValues(alpha: 0.20),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.activeColor.withValues(alpha: 0.18),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ],
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildIcon(
                    veryCompact ? 18 : (compact ? 20 : (roomy ? 24 : 22)),
                    veryCompact,
                  ),
                  if (showLabel) ...[
                    SizedBox(width: veryCompact ? 4 : (compact ? 6 : 10)),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: veryCompact ? 10 : (compact ? 11 : 13),
                          fontWeight: widget.isSelected
                              ? FontWeight.w900
                              : FontWeight.w700,
                          letterSpacing: widget.isSelected ? 0.3 : 0.1,
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

class DaySwitcher extends StatelessWidget {
  final int? selectedDayIndex;
  final ValueChanged<int?> onSelected;

  const DaySwitcher({
    required this.selectedDayIndex,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday; // 1=Mon
    final autoSelected = selectedDayIndex == null;
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useVitalTheme,
      builder: (context, useVital, _) {
        if (useVital) {
          return SizedBox(
            width: double.infinity,
            child: VitalCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              backgroundColor: Colors.transparent,
              border: Border.all(color: Colors.transparent),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const ButterScrollPhysics(),
                  children: [
                    const SizedBox(width: 6),
                    _buildAutoChip(context, autoSelected, isDark),
                    const SizedBox(width: 8),
                    ...List.generate(days.length, (index) {
                      final dayIndex = index + 1;
                      return _buildDayChip(context, dayIndex, days[index], selectedDayIndex == dayIndex, dayIndex == today, isDark);
                    }),
                  ],
                ),
              ),
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: GlassCard(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const ButterScrollPhysics(),
                children: [
                  const SizedBox(width: 6),
                  AnimatedSlide(
                    duration: IrisMotion.fast,
                    curve: IrisMotion.standard,
                    offset: autoSelected ? const Offset(0, -0.02) : Offset.zero,
                    child: AnimatedScale(
                      duration: IrisMotion.fast,
                      curve: IrisMotion.standard,
                      scale: autoSelected ? 1.025 : 1.0,
                      child: AnimatedContainer(
                        duration: IrisMotion.fast,
                        curve: IrisMotion.standard,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [],
                        ),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 13,
                                color: autoSelected
                                    ? IrisTokens.brand
                                    : isDark
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Colors.black.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Auto',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          selected: autoSelected,
                          onSelected: (_) {
                            IrisHaptics.chipSelect();
                            onSelected(null);
                          },
                          selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          side: BorderSide(
                            color: autoSelected
                                ? IrisTokens.brand.withValues(alpha: 0.56)
                                : isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.10),
                            width: autoSelected ? 1.4 : 1.0,
                          ),
                          labelStyle: TextStyle(
                            color: autoSelected
                                ? IrisTokens.brand
                                : isDark
                                ? Colors.white.withValues(alpha: 0.8)
                                : Colors.black.withValues(alpha: 0.65),
                          ),
                          elevation: autoSelected ? 0.6 : 0,
                          pressElevation: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(days.length, (index) {
                    final dayIndex = index + 1;
                    final isSelected = selectedDayIndex == dayIndex;
                    final isToday = dayIndex == today;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnimatedSlide(
                        duration: IrisMotion.fast,
                        curve: IrisMotion.standard,
                        offset: isSelected ? const Offset(0, -0.02) : Offset.zero,
                        child: AnimatedScale(
                          duration: IrisMotion.fast,
                          curve: IrisMotion.standard,
                          scale: isSelected ? 1.03 : 1.0,
                          child: AnimatedContainer(
                            duration: IrisMotion.fast,
                            curve: IrisMotion.standard,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [],
                            ),
                            child: ChoiceChip(
                              avatar: isToday && !isSelected
                                  ? Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: IrisTokens.success,
                                      ),
                                    )
                                  : null,
                              label: Text(
                                days[index],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (_) {
                                IrisHaptics.chipSelect();
                                onSelected(dayIndex == today ? null : dayIndex);
                              },
                              selectedColor: IrisTokens.brand.withValues(alpha: 0.20),
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              side: BorderSide(
                                color: isSelected
                                    ? IrisTokens.brand.withValues(alpha: 0.56)
                                    : isToday
                                    ? IrisTokens.success.withValues(alpha: 0.28)
                                    : isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.10),
                                width: isSelected ? 1.4 : 1.0,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? IrisTokens.brand
                                    : isDark
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.black.withValues(alpha: 0.65),
                              ),
                              elevation: isSelected ? 0.6 : 0,
                              pressElevation: 1,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutoChip(BuildContext context, bool selected, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 14, color: selected ? Colors.white : (isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(width: 4),
            const Text('Auto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
        selected: selected,
        onSelected: (_) => onSelected(null),
        selectedColor: VitalTokens.blue,
        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        labelStyle: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VitalTokens.radiusFull)),
      ),
    );
  }

  Widget _buildDayChip(BuildContext context, int index, String label, bool selected, bool isToday, bool isDark) {
    final color = isToday ? VitalTokens.green : VitalTokens.blue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        selected: selected,
        onSelected: (_) => onSelected(index),
        selectedColor: color,
        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        labelStyle: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
        side: isToday && !selected ? BorderSide(color: color.withValues(alpha: 0.4), width: 1.5) : BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VitalTokens.radiusFull)),
      ),
    );
  }
}

class ClassCard extends StatefulWidget {
  final ClassSession session;
  final ClassSession? nextSession;
  final bool isFacultyView;
  final VoidCallback? onRemoveMakeup;

  const ClassCard({
    super.key,
    required this.session,
    this.nextSession,
    this.isFacultyView = false,
    this.onRemoveMakeup,
  });

  @override
  State<ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<ClassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _pulseRunning = false;

  void _syncPulse(bool shouldPulse) {
    if (shouldPulse && !_pulseRunning) {
      _pulseController.repeat(reverse: true);
      _pulseRunning = true;
    } else if (!shouldPulse && _pulseRunning) {
      _pulseController.stop();
      _pulseController.value = 0.0;
      _pulseRunning = false;
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final isLive = widget.session.isLive(now);

    _pulseController = AnimationController(
      duration: IrisMotion.slow,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: IrisMotion.standard),
    );

    _syncPulse(isLive);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildVitalProgress(bool isDark) {
    final now = DateTime.now();
    final currentTime = now.hour + (now.minute / 60.0);
    final duration = LectureDuration.getActualDuration(widget.session);
    final actualEndTime = LectureDuration.getActualEndTime(widget.session);
    final progress = ((currentTime - widget.session.safeStartVal) / duration).clamp(0.0, 1.0);
    final minutesLeft = ((actualEndTime - currentTime) * 60).toInt().clamp(0, (duration * 60).toInt());

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [VitalTokens.green, Color(0xFF2E7D32)],
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).toInt()}% COMPLETED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${minutesLeft}M LEFT',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: VitalTokens.green,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final live = widget.session.isLive(now);
    final currentTime = now.hour + (now.minute / 60.0);
    final isUpcoming =
        !live &&
        widget.session.dayIndex == now.weekday &&
        widget.session.safeStartVal > currentTime &&
        widget.session.safeStartVal - currentTime <= 0.75;
    final isCompleted =
        widget.session.dayIndex < now.weekday ||
        (widget.session.dayIndex == now.weekday && currentTime > LectureDuration.getActualEndTime(widget.session));

    _syncPulse(live || isUpcoming);

    final timeLabel = '${widget.session.startTime} - ${widget.session.endTime}';

    final accentColor = live
        ? IrisTokens.success
        : isUpcoming
        ? IrisTokens.brand
        : IrisTokens.purple;
    final textPrimary = isDark ? Colors.white : IrisTokens.surfaceDark;
    final textSecondary = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.68,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useVitalTheme,
      builder: (context, useVital, _) {
        if (useVital) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Opacity(
              opacity: isCompleted ? 0.55 : 1.0,
              child: VitalCard(
                animate: false, // Handled by StaggeredListItem
                backgroundColor: live
                    ? VitalTokens.green.withValues(alpha: isDark ? 0.15 : 0.08)
                    : isUpcoming
                        ? IrisTokens.brand.withValues(alpha: isDark ? 0.15 : 0.08)
                        : null,
                border: live
                    ? Border.all(color: VitalTokens.green.withValues(alpha: 0.3), width: 1.5)
                    : isUpcoming
                        ? Border.all(color: IrisTokens.brand.withValues(alpha: 0.3), width: 1.2)
                        : null,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isCompleted) ...[
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: VitalTokens.green,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            widget.session.subject,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: live
                                  ? VitalTokens.green
                                  : isUpcoming
                                      ? IrisTokens.brand
                                      : textPrimary,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (live) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: VitalTokens.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: VitalTokens.green.withValues(alpha: 0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: VitalTokens.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: VitalTokens.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ] else if (isUpcoming) ...[
                          Builder(
                            builder: (context) {
                              final mins = ((widget.session.safeStartVal - currentTime) * 60).toInt();
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: IrisTokens.brand.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.3), width: 1),
                                ),
                                child: Text(
                                  'IN ${mins}M',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: IrisTokens.brand,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: live
                                ? VitalTokens.green
                                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(VitalTokens.radiusFull),
                          ),
                          child: Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: live ? Colors.white : textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 16, color: accentColor.withValues(alpha: 0.6)),
                            const SizedBox(width: 6),
                            Text(
                              widget.session.room,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                            ),
                          ],
                        ),
                        Text(
                          widget.isFacultyView ? widget.session.batchKey.batch : widget.session.teacher,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary),
                        ),
                      ],
                    ),
                    if (live) ...[
                      const SizedBox(height: 20),
                      _buildVitalProgress(isDark),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        // Legacy GlassCard
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scaleVal = (live || isUpcoming) ? _pulseAnimation.value : 1.0;
              return Transform.scale(
                scale: scaleVal,
                child: Opacity(
                  opacity: isCompleted ? 0.55 : 1.0,
                  child: GlassCard(
                    glow: live,
                    shimmer: false,
                    enableBlur: true,
                    enableShadow: true,
                    enableOverlay: true,
                    padding: const EdgeInsets.all(22),
                    borderRadius: 32.0,
                    elevation: live ? 4 : (isUpcoming ? 3 : 2),
                    accentColor: accentColor,
                    tilt: live,
                    border: live
                        ? Border.all(
                            color: IrisTokens.success.withValues(alpha: 0.4 + (math.sin(_pulseController.value * math.pi) * 0.2)),
                            width: 1.5,
                          )
                        : isUpcoming
                            ? Border.all(
                                color: IrisTokens.brand.withValues(alpha: 0.3),
                                width: 1.2,
                              )
                            : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (isCompleted) ...[
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: IrisTokens.success.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      widget.session.subject.replaceAll('[EXAM]', '').trim(),
                                      style: IrisTextStyles.classSubject(context).copyWith(
                                        color: widget.session.subject.contains('[EXAM]')
                                            ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                            : (live ? IrisTokens.success : textPrimary),
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (widget.session.subject.contains('[EXAM]')) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1),
                                ),
                                child: const Text(
                                  '✍️ EXAM PAPER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFD97706),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ] else if (live) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: IrisTokens.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: IrisTokens.success.withValues(alpha: 0.3), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: IrisTokens.success,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'LIVE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: IrisTokens.success,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ] else if (isUpcoming) ...[
                              Builder(
                                builder: (context) {
                                  final mins = ((widget.session.safeStartVal - currentTime) * 60).toInt();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: IrisTokens.brand.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(color: IrisTokens.brand.withValues(alpha: 0.3), width: 1),
                                    ),
                                    child: Text(
                                      'IN ${mins}M',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: IrisTokens.brand,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: live
                                    ? IrisTokens.brand.withValues(alpha: 0.85)
                                    : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                timeLabel,
                                style: IrisTextStyles.badgeText(context).copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: live ? Colors.white : textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  widget.session.subject.contains('[EXAM]')
                                      ? Icons.account_balance_rounded
                                      : Icons.location_on_rounded,
                                  size: 16,
                                  color: widget.session.subject.contains('[EXAM]')
                                      ? const Color(0xFFF59E0B)
                                      : (live ? IrisTokens.success : textSecondary.withValues(alpha: 0.6)),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.session.subject.contains('[EXAM]')
                                      ? 'Hall: ${widget.session.room}'
                                      : widget.session.room,
                                  style: IrisTextStyles.classSessionMeta(context).copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              widget.isFacultyView
                                  ? widget.session.batchKey.batch
                                  : (widget.session.subject.contains('[EXAM]')
                                      ? 'Invigilator: ${widget.session.teacher}'
                                      : widget.session.teacher),
                              style: IrisTextStyles.metaInfo(context).copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: widget.session.subject.contains('[EXAM]')
                                    ? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))
                                    : textSecondary.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),

                        if (live &&
                            widget.nextSession != null &&
                            widget.nextSession!.dayIndex ==
                                widget.session.dayIndex) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.keyboard_arrow_right_rounded,
                                  size: 16,
                                  color: textSecondary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Next: ${widget.nextSession!.room}',
                                  style: IrisTextStyles.badgeText(context).copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                    color: textSecondary.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (live) ...[
                          const SizedBox(height: 22),
                          Builder(
                            builder: (context) {
                              final currentTime = now.hour + (now.minute / 60.0);
                              final duration = LectureDuration.getActualDuration(widget.session);
                              final actualEndTime = LectureDuration.getActualEndTime(widget.session);
                              final progress = ((currentTime - widget.session.safeStartVal) / duration).clamp(0.0, 1.0);
                              final minutesLeft = ((actualEndTime - currentTime) * 60).toInt().clamp(0, (duration * 60).toInt());

                              return Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: Container(
                                      height: 8,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: progress,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [IrisTokens.success, IrisTokens.successDark],
                                            ),
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${(progress * 100).toInt()}% Done',
                                        style: IrisTextStyles.classProgress(context).copyWith(
                                          color: textSecondary.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      Text(
                                        '${minutesLeft}m left',
                                        style: IrisTextStyles.classProgress(context).copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: IrisTokens.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class GlassShimmer extends StatefulWidget {
  const GlassShimmer({super.key});

  @override
  State<GlassShimmer> createState() => _GlassShimmerState();
}

class _GlassShimmerState extends State<GlassShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3456),
    )..repeat();
    _curve = CurvedAnimation(parent: _controller, curve: IrisMotion.standard);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final shift = (_curve.value * 2) - 1;
            return FractionalTranslation(
              translation: Offset(shift, 0),
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color statusIndicator;

  const SectionHeader({
    required this.title,
    required this.subtitle,
    required this.statusIndicator,
    super.key,
  });

  @override
  State<SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<SectionHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: IrisMotion.slow,
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: IrisMotion.standard),
    );
    _glowAnimation = Tween<double>(begin: 0.05, end: 0.09).animate(
      CurvedAnimation(parent: _bounceController, curve: IrisMotion.standard),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeSignals.useVitalTheme,
      builder: (context, useVital, _) {
        if (useVital) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: VitalCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: widget.statusIndicator.withValues(alpha: isDark ? 0.08 : 0.04),
              border: Border.all(color: widget.statusIndicator.withValues(alpha: 0.15), width: 1.5),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: widget.statusIndicator,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.statusIndicator.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            fontSize: 10,
                            color: widget.statusIndicator.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: IrisMotion.medium,
            curve: IrisMotion.bouncy,
            builder: (context, animValue, child) => Transform.translate(
              offset: Offset(-36 * (1 - animValue), 8 * (1 - animValue)),
              child: Transform.scale(
                scale: 0.96 + (0.04 * animValue),
                child: Opacity(opacity: animValue, child: child),
              ),
            ),
            child: AnimatedBuilder(
              animation: _bounceController,
              builder: (context, _) {
                return Container(
                  padding: const EdgeInsets.all(IrisTokens.space20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.statusIndicator.withValues(
                          alpha: isDark ? 0.26 : 0.18,
                        ),
                        widget.statusIndicator.withValues(
                          alpha: isDark ? 0.14 : 0.10,
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(IrisTokens.radius24),
                    border: Border.all(
                      color: widget.statusIndicator.withValues(
                        alpha: isDark ? 0.34 : 0.24,
                      ),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.statusIndicator.withValues(
                          alpha: _glowAnimation.value,
                        ),
                        offset: const Offset(0, 8),
                        blurRadius: 20,
                        spreadRadius: -14,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
                        offset: const Offset(0, 3),
                        blurRadius: 12,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 304),
                        switchInCurve: IrisMotion.entrance,
                        switchOutCurve: IrisMotion.standard,
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: animation,
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: Transform.translate(
                          key: ValueKey(widget.statusIndicator.toARGB32()),
                          offset: Offset(0, _bounceAnimation.value),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: widget.statusIndicator.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.statusIndicator.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 6,
                                  spreadRadius: -3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8,
                                fontSize: 10,
                                height: 1.4,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.66),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.90),
                                height: 1.22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class IrisGlassSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const IrisGlassSwitch({
    required this.value,
    required this.onChanged,
    this.activeColor,
    super.key,
  });

  @override
  State<IrisGlassSwitch> createState() => _IrisGlassSwitchState();
}

class _IrisGlassSwitchState extends State<IrisGlassSwitch> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _thumbPosAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _thumbPosAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant IrisGlassSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCol = widget.activeColor ?? IrisTokens.brand;

    return GestureDetector(
      onTap: () {
        IrisHaptics.selectionClick();
        widget.onChanged(!widget.value);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final val = _thumbPosAnim.value;
          return Container(
            width: 48,
            height: 28,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: Color.lerp(
                (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                activeCol.withOpacity(0.18),
                val,
              ),
              border: Border.all(
                color: Color.lerp(
                  (isDark ? Colors.white : Colors.black).withOpacity(0.12),
                  activeCol.withOpacity(0.4),
                  val,
                )!,
                width: 1.0,
              ),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.lerp(Alignment.centerLeft, Alignment.centerRight, val)!,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        isDark ? Colors.white70 : Colors.black54,
                        isDark ? Colors.white : activeCol,
                        val,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color.lerp(
                            Colors.black.withOpacity(0.1),
                            activeCol.withOpacity(0.3),
                            val,
                          )!,
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
