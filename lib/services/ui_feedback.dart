import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/tokens.dart';
import 'system_broadcast_service.dart';

/// UI Sound Feedback - Playing tones for natural interactions
class IrisSfx {
  static bool _enabled = false;
  static String _profile = 'gentle';

  static Future<void> init() async {
    _enabled = false;
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = false;
  }

  static bool get enabled => false;
  static String get profile => _profile;

  static Future<void> setProfile(String profile) async {
    _profile = profile;
  }

  static bool _throttle([int minGapMs = 60]) {
    return true;
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
    // Disabled completely
  }
}

/// UI Haptic Feedback
class IrisHaptics {
  static bool _enabled = false;
  static String _profile = 'gentle';
  static int _lastPulseMs = 0;

  static Future<void> init() async {
    _enabled = false;
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = false;
  }

  static bool get enabled => false;
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
    // Disabled completely
  }

  static Future<void> navTransition({
    required int from,
    required int to,
  }) async {
    if (!_enabled) return;
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
    if (!_enabled) return;
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
    if (child != null) return _extractIrisSnackText(child);
    return '';
  }
  if (widget is Container) {
    final child = widget.child;
    if (child != null) return _extractIrisSnackText(child);
    return '';
  }
  if (widget is Center) {
    final child = widget.child;
    if (child != null) return _extractIrisSnackText(child);
    return '';
  }
  if (widget is Align) {
    final child = widget.child;
    if (child != null) return _extractIrisSnackText(child);
    return '';
  }
  if (widget is DecoratedBox) {
    final child = widget.child;
    if (child != null) return _extractIrisSnackText(child);
    return '';
  }
  if (widget is ClipRRect) {
    final child = widget.child;
    if (child != null) return _extractIrisSnackText(child);
    return '';
  }
  if (widget is Material) {
    final child = widget.child;
    if (child != null) return _extractIrisSnackText(child);
    return '';
  }
  if (widget is InkWell) {
    final child = widget.child;
    if (child != null) return _extractIrisSnackText(child);
    return '';
  }
  if (widget is GestureDetector) {
    final child = widget.child;
    if (child != null) return _extractIrisSnackText(child);
    return '';
  }
  if (widget is Opacity) {
    final child = widget.child;
    if (child != null) return _extractIrisSnackText(child);
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
  SystemBroadcastService().triggerLocalOverride(
    text,
    '',
    isUrgent: tint == IrisTokens.error,
    duration: duration,
  );
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
