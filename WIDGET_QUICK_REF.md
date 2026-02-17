# OMNI-FLOW OS Widget - Quick Reference

## 🎯 One-Page Developer Guide

### What It Does
Displays live class info on home screen with glassmorphic design. Updates only when class changes (battery efficient).

### Files You Need to Know

| File | What It Does |
|------|--------------|
| `lib/widget_service.dart` | Dart ↔ Android bridge |
| `lib/main.dart` | Call `_updateWidgetIfNeeded()` in ticker |
| `OmniFlowWidgetProvider.kt` | Reads SharedPreferences, updates Android widget |
| `widget_layout.xml` | Widget UI definition |
| `widget_provider_info.xml` | Widget metadata (30-min refresh fallback) |
| Drawable XML files | Glassmorphic styling |

### SharedPreferences Keys
```
flutter.current_class_subject       → "OOP Theory"
flutter.current_class_room          → "B7"
flutter.current_class_teacher       → "Mr. Hamza Arif"
flutter.current_class_end_time      → "09:55"
flutter.progress_percentage         → 45
flutter.is_class_live               → true
flutter.next_class_subject          → "Physics Lab"
flutter.next_class_start_time       → "09:55"
```

### Update Flow (Simplified)

```
1. Every 30 seconds, _updateWidgetIfNeeded() checks:
   "Has the current class changed?"
   
2a. If YES → Send update
   await WidgetService.updateWidget(isLive: true, ...)
   Data → SharedPreferences
   Android notification → Widget reads prefs
   Widget UI updates

2b. If NO → Skip update (saves battery)
```

### Adding New Data
New class data is auto-discovered. Just add to `OmniBrain.universe`:

```dart
ClassSession('new_id', 1, "Subject", "Room", "Teacher", "08:00", "09:30")
// Widget will show it automatically
```

### Testing
```bash
# 1. Build
flutter run

# 2. Verify widget appears in launcher widget list
#    (Long-press home → Widgets → OMNI-FLOW OS)

# 3. Add widget to home screen (1x2 or larger)

# 4. Open app during a class time
#    Widget should display class info

# 5. Wait 30 seconds, check progress bar updates

# 6. Check battery: Settings → Battery → OMNI-FLOW OS
#    Should be <1% per day
```

### Common Mistakes

| ❌ Don't | ✅ Do |
|---------|-----|
| Update widget every second | Update only on class change |
| Hardcode room list | Scan universe.values dynamically |
| Modify SharedPrefs outside of WidgetService | Always use WidgetService methods |
| Use different key names in Kotlin vs Dart | Copy-paste keys to ensure match |
| Increase updatePeriodMillis to 1000ms | Leave at 1800000 (30 min fallback) |

### Debugging

```dart
// Add to _updateWidgetIfNeeded()
print('Current: ${OmniBrain.getCurrentClass(myBatch)}');
print('Previous: $_previousClass');
// If they're different, widget should have updated
```

```kotlin
// Add to OmniFlowWidgetProvider.updateAppWidget()
Log.d("WidgetProvider", "Subject: $subject, Room: $room")
// Check logcat: adb logcat | grep WidgetProvider
```

### Performance
- 30-second detection cycle = 120 checks/hour (minimal CPU)
- Updates only on class change (~10/day typical) = minimal battery
- Total impact: <1% battery degradation per day

### Design Consistency
- 🎨 Colors match app theme (Indigo #6366F1)
- ❄️ Glassmorphism effect (20-30dp blur)
- 📍 Icons for room/teacher (emoji)
- 🔴 Red aura when class is live

---

## If Something Breaks

1. **Widget not visible in launcher**: 
   - Check `AndroidManifest.xml` has `<receiver>`
   - Verify `@xml/widget_provider_info.xml` exists
   - Run `flutter clean && flutter pub get`

2. **Widget never updates**:
   - Check `_updateWidgetIfNeeded()` is in ticker
   - Add debug prints to verify it's called
   - Check SharedPreferences keys match Kotlin

3. **Battery drains fast**:
   - Check `updatePeriodMillis` is 1800000 (30 min)
   - Verify updates only happen on class change
   - Check no background services exist

4. **Progress bar stuck**:
   - Progress is recalculated fresh each tick
   - If class hasn't changed, progress appears static
   - This is correct behavior

---

## That's It!

The widget system is automated. Just make sure:
1. ✅ Files are in correct locations
2. ✅ SharedPreferences keys match
3. ✅ AndroidManifest.xml registered
4. ✅ `_updateWidgetIfNeeded()` called every 30s
5. ✅ No hardcoded lists or frequent updates

Everything else handles itself.

---

**Need More Info?**
- Full guide: See `WIDGET_GUIDE.md`
- Architecture rules: See `ARCHITECTURE.md`
- Implementation details: See `WIDGET_IMPLEMENTATION.md`
