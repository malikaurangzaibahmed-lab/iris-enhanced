import 'package:flutter/foundation.dart';

/// App-wide lightweight signals for cross-widget events.
/// Use `AppSignals.roleNotifier.value = 'faculty'` to request a role switch.
class AppSignals {
  static final ValueNotifier<String?> roleNotifier = ValueNotifier(null);
}
