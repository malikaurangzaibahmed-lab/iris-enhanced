import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static String _toneForSoftTick() {
    return switch (_profile) {
      'gentle' => 'sfx_nav_soft',
      'crisp' => 'ui_sfx_laser',
      _ => 'ui_toggle_soft',
    };
  }

  static String _toneForClick() {
    return switch (_profile) {
      'gentle' => 'sfx_nav_soft',
      'crisp' => 'ui_sfx_coins',
      _ => 'sfx_nav_click',
    };
  }

  static String _toneForConfirmAccent() {
    return switch (_profile) {
      'gentle' => 'sfx_confirm',
      'crisp' => 'ui_sfx_coins',
      _ => 'sfx_confirm',
    };
  }

  static String _toneForPillBase() {
    return switch (_profile) {
      'gentle' => 'ui_toggle_click',
      'crisp' => 'ui_sfx_coins',
      _ => 'ui_toggle_click',
    };
  }

  static String _toneForPillAccent() {
    return switch (_profile) {
      'gentle' => 'ui_toggle_confirm',
      'crisp' => 'ui_sfx_laser',
      _ => 'ui_toggle_confirm',
    };
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
      // Fallback to system sound
      try {
        SystemSound.play(SystemSoundType.click);
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
      if (Platform.isAndroid) {
        await _safePulse(HapticFeedback.mediumImpact);
        await Future<void>.delayed(const Duration(milliseconds: 22));
        if (_throttle(22)) return;
        await _safePulse(
          _profile == 'crisp'
              ? HapticFeedback.mediumImpact
              : HapticFeedback.lightImpact,
        );
      } else {
        await _safePulse(HapticFeedback.heavyImpact);
      }
      IrisSfx.confirm();
    }());
  }
}
