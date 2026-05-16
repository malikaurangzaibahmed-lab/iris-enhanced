import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../core/theme_signals.dart';
import 'dart:math' as math;

const MethodChannel _uiSoundChannel = MethodChannel('iris/ui_sound_channel');

/// UI Sound Feedback - Playing tones for natural interactions
class IrisSfx {
  static bool _enabled = true;
  static String _profile = 'gentle';
  static int _lastSoundMs = 0;
  static final Map<String, int> _toneLastPlayedMs = <String, int>{};

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('ui_sounds_enabled') ?? true;
    _profile = prefs.getString('ui_feedback_profile') ?? 'gentle';
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ui_sounds_enabled', value);
  }

  static bool get enabled => _enabled;
  static String get profile => _profile;

  static Future<void> setProfile(String profile) async {
    final normalized = switch (profile) {
      'gentle' => 'gentle',
      'crisp' => 'crisp',
      'bubble' => 'bubble',
      _ => 'balanced',
    };
    _profile = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ui_feedback_profile', normalized);
  }

  static bool _throttle([int minGapMs = 60]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSoundMs < minGapMs) return true;
    _lastSoundMs = now;
    return false;
  }

  static bool _toneThrottle(String tone, [int minGapMs = 52]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _toneLastPlayedMs[tone] ?? 0;
    if (now - last < minGapMs) return true;
    _toneLastPlayedMs[tone] = now;
    return false;
  }

  static Future<void> _playPattern(
    List<({String tone, int delayMs})> pattern,
  ) async {
    for (final step in pattern) {
      if (!_enabled) return;
      if (step.delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: step.delayMs));
      }
      _play(step.tone);
    }
  }

  static void navTick({int distance = 1}) {
    if (!_enabled || _throttle(54)) return;
    if (distance <= 1) {
      _play(_toneForSoftTick());
      return;
    }

    unawaited(
      _playPattern([
        (tone: _toneForSoftTick(), delayMs: 0),
        (tone: _toneForClick(), delayMs: 52),
      ]),
    );
  }

  static void click() {
    if (!_enabled || _throttle(64)) return;
    _play(_toneForClick());
  }

  static void bubblePop() {
    if (!_enabled || _throttle(64)) return;
    _play('sfx_bubble_pop');
  }

  static void pillTap() {
    if (!_enabled || _throttle(88)) return;
    unawaited(
      _playPattern([
        (tone: _toneForPillBase(), delayMs: 0),
        (tone: _toneForPillAccent(), delayMs: 58),
      ]),
    );
  }

  static void tick() {
    if (!_enabled || _throttle(48)) return;
    _play(_toneForSoftTick());
  }

  static void confirm() {
    if (!_enabled || _throttle(98)) return;
    unawaited(
      _playPattern([
        (tone: _toneForSoftTick(), delayMs: 0),
        (tone: _toneForConfirmAccent(), delayMs: 72),
      ]),
    );
  }

  static void error() {
    if (!_enabled || _throttle(120)) return;
    unawaited(
      _playPattern([
        (tone: _toneForErrorBase(), delayMs: 0),
        (tone: _toneForErrorBase(), delayMs: 54),
      ]),
    );
  }

  static void downloadSuccess() {
    if (!_enabled || _throttle(140)) return;
    unawaited(
      _playPattern([
        (tone: _toneForSoftTick(), delayMs: 0),
        (tone: _toneForConfirmAccent(), delayMs: 68),
        (tone: _toneForClick(), delayMs: 64),
      ]),
    );
  }

  static void intelligentConfirmation() {
    if (!_enabled || _throttle(200)) return;
    unawaited(
      _playPattern([
        (tone: _toneForSoftTick(), delayMs: 0),
        (tone: _toneForClick(), delayMs: 60),
      ]),
    );
  }

  static String _toneForSoftTick() {
    return switch (_profile) {
      'bubble' => 'sfx_bubble_soft',
      'gentle' => 'sfx_nav_soft',
      _ => 'ui_tick_soft',
    };
  }

  static String _toneForClick() {
    return switch (_profile) {
      'bubble' => 'sfx_bubble_pop',
      'gentle' => 'sfx_nav_soft',
      _ => 'ui_tap_standard',
    };
  }

  static String _toneForConfirmAccent() {
    return switch (_profile) {
      'bubble' => 'sfx_bubble_confirm',
      'gentle' => 'sfx_confirm',
      _ => 'ui_confirm_balanced',
    };
  }

  static String _toneForPillBase() {
    return _profile == 'bubble' ? 'sfx_bubble_soft' : 'ui_tap_soft';
  }

  static String _toneForPillAccent() {
    return _profile == 'bubble' ? 'sfx_bubble_pop' : 'ui_tick_crisp';
  }

  static String _toneForErrorBase() {
    return switch (_profile) {
      'gentle' => 'ui_toggle_soft',
      'crisp' => 'ui_sfx_laser',
      _ => 'sfx_nav_soft',
    };
  }

  static void _play(String tone) {
    if (_toneThrottle(tone)) return;
    if (!Platform.isAndroid) {
      SystemSound.play(SystemSoundType.click);
      return;
    }

    _uiSoundChannel.invokeMethod('playTone', {'tone': tone}).then((_) {
      // Sound played successfully
    }).catchError((error) {
      debugPrint('Sound play failed for "$tone": $error');
      // Fallback to much softer system sound for professional feel
      try {
        if (Platform.isIOS) {
          HapticFeedback.selectionClick();
        } else {
          SystemSound.play(SystemSoundType.click);
        }
      } catch (_) {
        // Silent fallback
      }
    });
  }
}

/// UI Haptic Feedback
class IrisHaptics {
  static bool _enabled = true;
  static String _profile = 'balanced';
  static int _lastPulseMs = 0;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('ui_haptics_enabled') ?? true;
    _profile = prefs.getString('ui_feedback_profile') ?? 'balanced';
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ui_haptics_enabled', value);
  }

  static bool get enabled => _enabled;
  static String get profile => _profile;

  static Future<void> setProfile(String profile) async {
    final normalized = switch (profile) {
      'gentle' => 'gentle',
      'crisp' => 'crisp',
      _ => 'balanced',
    };
    _profile = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ui_feedback_profile', normalized);
  }

  static bool _throttle([int minGapMs = 40]) {
    if (!_enabled) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPulseMs < minGapMs) return true;
    _lastPulseMs = now;
    return false;
  }

  static Future<void> _safePulse(Future<void> Function() pulse) async {
    try {
      await pulse();
    } catch (_) {
      // Ignore unsupported haptic capabilities on some devices.
    }
  }

  static Future<void> navTransition({
    required int from,
    required int to,
  }) async {
    if (from == to) return;
    if (_throttle(26)) return;

    final distance = (to - from).abs();
    await _safePulse(HapticFeedback.selectionClick);
    IrisSfx.navTick(distance: distance);

    if (_profile == 'gentle') return;

    if (distance > 1) {
      await Future<void>.delayed(const Duration(milliseconds: 24));
      if (_throttle(24)) return;
      await _safePulse(
        _profile == 'crisp'
            ? HapticFeedback.mediumImpact
            : HapticFeedback.lightImpact,
      );
    }
  }

  static Future<void> destinationOpen({required int destination}) async {
    await Future<void>.delayed(const Duration(milliseconds: 34));
    if (_throttle(44)) return;
    await _safePulse(
      _profile == 'gentle'
          ? HapticFeedback.selectionClick
          : HapticFeedback.lightImpact,
    );

    if (destination == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (_throttle(20)) return;
      await _safePulse(HapticFeedback.selectionClick);
    }
  }

  static void chipSelect() {
    if (_throttle(24)) return;
    unawaited(_safePulse(HapticFeedback.selectionClick));
    IrisSfx.tick();
  }

  static void selectionClick() {
    if (_throttle(24)) return;
    unawaited(_safePulse(HapticFeedback.selectionClick));
  }

  static void refreshStart() {
    if (_throttle(36)) return;
    unawaited(_safePulse(HapticFeedback.lightImpact));
    IrisSfx.tick();
  }

  static void refreshSuccess() {
    if (_throttle(64)) return;
    unawaited(() async {
      await _safePulse(HapticFeedback.mediumImpact);
      await Future<void>.delayed(const Duration(milliseconds: 34));
      if (_throttle(24)) return;
      await _safePulse(HapticFeedback.selectionClick);
      IrisSfx.confirm();
    }());
  }

  static void actionSoft() {
    if (_throttle(26)) return;
    unawaited(
      _safePulse(
        _profile == 'gentle'
            ? HapticFeedback.selectionClick
            : HapticFeedback.lightImpact,
      ),
    );
    IrisSfx.tick();
  }

  static void actionMedium() {
    if (_throttle(44)) return;
    unawaited(
      _safePulse(
        _profile == 'gentle'
            ? HapticFeedback.lightImpact
            : HapticFeedback.mediumImpact,
      ),
    );
    IrisSfx.click();
  }

  static void actionHeavy() {
    if (_throttle(90)) return;
    unawaited(() async {
      if (_profile == 'gentle') {
        await _safePulse(HapticFeedback.lightImpact);
        IrisSfx.confirm();
        return;
      }
      
      // Layered Heavy Impact
      await _safePulse(HapticFeedback.heavyImpact);
      await Future<void>.delayed(const Duration(milliseconds: 32));
      await _safePulse(HapticFeedback.lightImpact);
      
      IrisSfx.confirm();
    }());
  }

  static void intelligencePulse() {
    if (_throttle(150)) return;
    unawaited(() async {
      await _safePulse(HapticFeedback.selectionClick);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await _safePulse(HapticFeedback.selectionClick);
    }());
  }
}

final Map<String, int> _irisSnackLastShownMs = <String, int>{};
OverlayEntry? _irisPillOverlayEntry;
Timer? _irisPillExpandTimer;
Timer? _irisPillContentTimer;
Timer? _irisPillCollapseTimer;
Timer? _irisPillDotTimer;
Timer? _irisPillDotPulseTimer;
Timer? _irisPillFadeTimer;
Timer? _irisPillDisposeTimer;

void _clearIrisPillOverlay() {
  _irisPillExpandTimer?.cancel();
  _irisPillContentTimer?.cancel();
  _irisPillCollapseTimer?.cancel();
  _irisPillDotTimer?.cancel();
  _irisPillDotPulseTimer?.cancel();
  _irisPillFadeTimer?.cancel();
  _irisPillDisposeTimer?.cancel();
  _irisPillExpandTimer = null;
  _irisPillContentTimer = null;
  _irisPillCollapseTimer = null;
  _irisPillDotTimer = null;
  _irisPillDotPulseTimer = null;
  _irisPillFadeTimer = null;
  _irisPillDisposeTimer = null;

  _irisPillOverlayEntry?.remove();
  _irisPillOverlayEntry = null;
}

String _extractIrisSnackText(Widget widget) {
  if (widget is Text) {
    return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }
  if (widget is RichText) {
    return widget.text.toPlainText();
  }
  if (widget is DefaultTextStyle) {
    return _extractIrisSnackText(widget.child);
  }
  if (widget is Expanded) {
    return _extractIrisSnackText(widget.child);
  }
  if (widget is Flexible) {
    return _extractIrisSnackText(widget.child);
  }
  if (widget is Padding) {
    final child = widget.child;
    if (child != null) {
      return _extractIrisSnackText(child);
    }
    return '';
  }
  if (widget is SizedBox && widget.child != null) {
    return _extractIrisSnackText(widget.child!);
  }
  if (widget is Row) {
    return widget.children
        .map(_extractIrisSnackText)
        .where((s) => s.isNotEmpty)
        .join(' ');
  }
  if (widget is Column) {
    return widget.children
        .map(_extractIrisSnackText)
        .where((s) => s.isNotEmpty)
        .join(' ');
  }
  if (widget is Wrap) {
    return widget.children
        .map(_extractIrisSnackText)
        .where((s) => s.isNotEmpty)
        .join(' ');
  }
  return '';
}

String _compactIrisSnackText(String raw) {
  final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return 'Updated';
  if (compact.length <= 62) return compact;
  return '${compact.substring(0, 59)}...';
}

void _showIrisTopPill(
  BuildContext context, {
  required String text,
  Duration duration = const Duration(seconds: 3),
  Color? tint,
  SnackBarAction? action,
  bool clearExisting = true,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      _showIrisTopPill(
        context,
        text: text,
        duration: duration,
        tint: tint,
        action: action,
        clearExisting: clearExisting,
      );
    });
    return;
  }

  if (clearExisting) {
    _clearIrisPillOverlay();
  }

  final tone = tint ?? Colors.white;

  bool expanded = false;
  bool contentVisible = false;
  bool collapsing = false;
  bool dotMode = false;
  bool dotPulse = false;
  bool visible = true;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) {
      final media = MediaQuery.of(overlayContext);
      final isDark = Theme.of(overlayContext).brightness == Brightness.dark;
      final availableWidth = media.size.width - 24;
      final targetWidth = math
          .min(
            346.0,
            math.max(152.0, 66.0 + (text.length * 6.0)),
          )
          .clamp(108.0, availableWidth);

      final width = dotMode ? 10.0 : (collapsing ? 44.0 : (expanded ? targetWidth.toDouble() : 30.0));
      final height = dotMode ? 10.0 : 40.0;
      final scale = dotMode ? (dotPulse ? 1.08 : 0.88) : (expanded ? 1.0 : 0.86);
      final cornerRadius = dotMode ? 999.0 : (collapsing ? 16.0 : 24.0);

      return Positioned(
        top: media.padding.top + 6,
        left: 12,
        right: 12,
        child: IgnorePointer(
          ignoring: dotMode,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOutCubic,
            opacity: visible ? 1 : 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              offset: visible ? Offset.zero : const Offset(0, -0.18),
              child: Center(
                child: GestureDetector(
                  onTap: action != null
                      ? () {
                          IrisSfx.pillTap();
                          action.onPressed();
                        }
                      : null,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.fastOutSlowIn,
                    scale: scale,
                    child: GlassSurface(
                      settings: LiquidGlassSettings(
                        blur: 15.0,
                        ambientStrength: 0.70,
                        lightAngle: 0.15 * math.pi,
                        glassColor: isDark
                            ? const Color(0xFF020617).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.28),
                        thickness: 12,
                      ),
                      radius: cornerRadius,
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.fastOutSlowIn,
                          width: width,
                          height: height,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(cornerRadius),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.08),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
                                spreadRadius: -4,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color:
                                    tone.withValues(alpha: dotMode ? 0.0 : 0.08),
                                blurRadius: 12,
                                spreadRadius: -6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: dotMode
                                ? const SizedBox.shrink(key: ValueKey('dot'))
                                : AnimatedOpacity(
                                    key: const ValueKey('pill'),
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    opacity:
                                        (contentVisible && !collapsing) ? 1 : 0,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: tone.withValues(alpha: 0.92),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    tone.withValues(alpha: 0.55),
                                                blurRadius: 8,
                                                spreadRadius: -1,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            text,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.18,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                        if (action != null)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.18),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              action.label,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.14,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
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

  _irisPillOverlayEntry = entry;
  overlay.insert(entry);

  void mark() {
    _irisPillOverlayEntry?.markNeedsBuild();
  }

  _irisPillExpandTimer = Timer(const Duration(milliseconds: 16), () {
    expanded = true;
    mark();
  });

  _irisPillContentTimer = Timer(const Duration(milliseconds: 120), () {
    contentVisible = true;
    mark();
  });

  final adaptiveHoldMs = (900 + (text.length * 22)).clamp(1200, 3400);
  final holdMs = math
      .min(duration.inMilliseconds, adaptiveHoldMs)
      .clamp(1100, 3400)
      .toInt();
  _irisPillCollapseTimer = Timer(Duration(milliseconds: holdMs), () {
    collapsing = true;
    contentVisible = false;
    mark();
  });

  _irisPillDotTimer = Timer(Duration(milliseconds: holdMs + 220), () {
    dotMode = true;
    mark();
  });

  _irisPillDotPulseTimer = Timer(Duration(milliseconds: holdMs + 280), () {
    dotPulse = true;
    mark();
  });

  _irisPillFadeTimer = Timer(Duration(milliseconds: holdMs + 340), () {
    visible = false;
    mark();
  });

  _irisPillDisposeTimer = Timer(Duration(milliseconds: holdMs + 460), () {
    if (_irisPillOverlayEntry == entry) {
      _clearIrisPillOverlay();
    }
  });
}

void showIrisFrostedSnackBar(
  BuildContext context, {
  required Widget content,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
  Color? tint,
  EdgeInsetsGeometry? margin,
  String? dedupeKey,
  Duration dedupeWindow = const Duration(milliseconds: 1400),
  bool clearExisting = true,
}) {
  if (!context.mounted) return;

  if (dedupeKey != null && dedupeKey.isNotEmpty) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastMs = _irisSnackLastShownMs[dedupeKey] ?? 0;
    if (nowMs - lastMs < dedupeWindow.inMilliseconds) {
      return;
    }
    _irisSnackLastShownMs[dedupeKey] = nowMs;
  }

  final text = _compactIrisSnackText(_extractIrisSnackText(content));
  _showIrisTopPill(
    context,
    text: text,
    duration: duration,
    tint: tint,
    action: action,
    clearExisting: clearExisting,
  );
}
