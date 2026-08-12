# OMNI-FLOW OS - Home Widget Implementation Guide

## 🏠 Overview

The OMNI-FLOW OS Home Widget displays real-time class information with a premium glassmorphic design. It updates intelligently to minimize battery drain while keeping information current.

---

## 🏗️ Architecture

### Component Structure

```
┌─────────────────────────────────────────────────────┐
│            Flutter Main App (Dart)                  │
│  - _DashboardState._updateWidgetIfNeeded()         │
│  - Detects class changes every 30 seconds          │
│  - Triggers widget updates via WidgetService       │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│         WidgetService (Dart Bridge)                 │
│  - Communicates with Home Widget package            │
│  - Saves data to SharedPreferences                  │
│  - Sends broadcast intents to Android widget       │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│     SharedPreferences (Persistent Storage)          │
│  - flutter.current_class_subject                   │
│  - flutter.current_class_room                      │
│  - flutter.progress_percentage                     │
│  - ... (8 total keys)                              │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│      Android Widget Layer                           │
│  - OmniFlowWidgetProvider.kt                        │
│  - Reads SharedPreferences                          │
│  - Updates RemoteViews based on data                │
│  - Displays in home screen                          │
└─────────────────────────────────────────────────────┘
```

---

## 🔌 Integration Points

### 1. Flutter → Android Communication

**File**: `lib/widget_service.dart`

```dart
// Widget updates ONLY when class status changes
await WidgetService.updateWidget(
  isLive: true,
  subject: "OOP Theory",
  room: "B7",
  teacher: "Mr. Hamza Arif",
  endTime: "09:55",
  progressPercentage: 45,
  nextClassSubject: "",
  nextClassStartTime: "",
);
```

### 2. SharedPreferences Keys

**Location**: Both Flutter and Kotlin must use identical keys

```dart
static const String _prefCurrentClassSubject = 'flutter.current_class_subject';
static const String _prefCurrentClassRoom = 'flutter.current_class_room';
static const String _prefCurrentClassTeacher = 'flutter.current_class_teacher';
static const String _prefCurrentClassEndTime = 'flutter.current_class_end_time';
static const String _prefNextClassSubject = 'flutter.next_class_subject';
static const String _prefNextClassStartTime = 'flutter.next_class_start_time';
static const String _prefProgressPercentage = 'flutter.progress_percentage';
static const String _prefIsClassLive = 'flutter.is_class_live';
```

### 3. Android Widget Provider

**File**: `android/app/src/main/kotlin/OmniFlowWidgetProvider.kt`

Reads SharedPreferences and updates RemoteViews:

```kotlin
// Update subject text
views.setTextViewText(R.id.widget_subject, subject)

// Show aura indicator if live
views.setViewVisibility(R.id.aura_indicator, auraVisibility)

// Update progress bar
views.setProgressBar(R.id.widget_progress, 100, progressPercentage, false)
```

---

## 📱 UI Components

### Layout File: `widget_layout.xml`

```xml
<LinearLayout> (Vertical)
  ├── Main Glass Container (FrameLayout)
  │   ├── Aura Indicator (Live dot)
  │   ├── Subject/Status Text
  │   ├── Room Info
  │   └── Teacher Info
  └── Progress Bar at Bottom
```

### Drawable Resources

| File | Purpose |
|------|---------|
| `widget_glass_container.xml` | Semi-transparent white (10%) with rounded corners |
| `widget_aura_dot.xml` | Red indicator dot (pulsing indicator) |
| `widget_progress_background.xml` | Gray background for progress bar |
| `widget_progress_fill.xml` | Indigo progress bar fill |
| `widget_background.xml` | Dark background for widget area |

---

## ⚡ Performance Optimization

### The Battery Efficiency Rule

**❌ WRONG: Update every second**
```kotlin
updatePeriodMillis="1000"  // FORBIDDEN - kills battery
```

**✅ CORRECT: 30-minute fallback + smart event-based updates**
```kotlin
updatePeriodMillis="1800000"  // 30 minutes as fallback
```

**Smart updates trigger ONLY when:**
1. Class status changes (detected by 30-second ticker)
2. User manually refreshes
3. System periodic update (30 minutes) - fallback

### Implementation Details

**Flutter Side** (`_DashboardState._updateWidgetIfNeeded`):
```dart
// Only update if class changed
if (currentClass != _previousClass) {
  _previousClass = currentClass;
  await WidgetService.updateWidget(...);
}
```

**Android Side** (`OmniFlowWidgetProvider.kt`):
```kotlin
// Update triggered only when:
// 1. ACTION_WIDGET_UPDATE broadcast received
// 2. onUpdate() called (every 30 minutes)
override fun onUpdate(...) {
  // Read fresh data and update UI
}
```

---

## 🔄 Update Flow

### Scenario 1: Class Starts

```
🕒 8:30 AM - OOP class begins
   ↓
_omniTicker fires (30-second interval)
   ↓
_updateWidgetIfNeeded() runs
   ↓
currentClass is now "OOP Theory" (was null)
   ↓
Class changed! Send update to widget
   ↓
WidgetService.updateWidget(isLive=true, ...)
   ↓
Data written to SharedPreferences
   ↓
HomeWidget.updateWidget() called
   ↓
Android receives broadcast
   ↓
OmniFlowWidgetProvider.onReceive() fired
   ↓
OmniFlowWidgetProvider.updateAppWidget()
   ↓
RemoteViews updated with subject, room, progress, aura
   ↓
Home screen widget refreshes immediately
```

### Scenario 2: No Class Change

```
_omniTicker fires
   ↓
_updateWidgetIfNeeded() runs
   ↓
currentClass unchanged (still "OOP Theory")
   ↓
No update sent (battery saved ✅)
   ↓
Widget keeps displaying old info (still correct)
```

### Scenario 3: User Manual Refresh

```
User taps refresh button
   ↓
WidgetService.refreshWidget() called
   ↓
HomeWidget.updateWidget() triggered
   ↓
Widget updates even if class hasn't changed
```

---

## 🔧 Maintenance Guide

### Adding New Class Data

**Remember**: New data automatically appears in the widget!

```dart
// OmniBrain.universe is auto-discovered
static Map<String, List<ClassSession>> get universe => {
  "FA25-BCS-2-C": [
    ClassSession('c1', 1, "OOP (Theory)", "B7", "Mr. Hamza Arif", "08:30", "09:55"),
    // New class here will appear in widget automatically
    ClassSession('c9', 1, "NEW CLASS", "NEW ROOM", "New Teacher", "10:30", "11:55"),
  ],
};
```

### Common Issues

#### 1. Widget Not Updating

**Check**:
- [ ] `WidgetService.initialize()` called in `main()`
- [ ] SharedPreferences keys match between Dart and Kotlin
- [ ] `OmniFlowWidgetProvider` registered in `AndroidManifest.xml`
- [ ] Widget provider configuration in `widget_provider_info.xml`

**Solution**:
```dart
// Force manual update
await WidgetService.refreshWidget();
```

#### 2. Widget Always Shows "System Idle"

**Check**:
- [ ] `_updateWidgetIfNeeded()` is being called
- [ ] `OmniBrain.getCurrentClass()` returns non-null when class is live
- [ ] Time parsing works correctly (check safeStartVal/safeEndVal)

**Debug**:
```dart
// Add logging in _updateWidgetIfNeeded
print('Current class: ${OmniBrain.getCurrentClass(myBatch)}');
print('Next class: ${OmniBrain.getNextClass(myBatch)}');
```

#### 3. Battery Drain (Widget Updates Too Frequently)

**Check**:
- [ ] `updatePeriodMillis` is at least 1800000 (30 minutes)
- [ ] Smart update logic works (only update on class change)
- [ ] No background services constantly updating widget

**Solution**: Widget only updates when class changes, not on timer.

---

## 🎨 Design Details

### Glassmorphism Implementation

```xml
<!-- Glass effect achieved through: -->
<shape android:shape="rectangle">
    <solid android:color="#1AFFFFFF" />      <!-- 10% white opacity -->
    <corners android:radius="20dp" />         <!-- Rounded corners -->
    <stroke
        android:width="1dp"
        android:color="#33FFFFFF" />          <!-- Subtle border -->
</shape>
```

### Color Scheme

| Element | Color | Hex | Purpose |
|---------|-------|-----|---------|
| Background | Dark | #020617 | System dark mode |
| Glass Container | Light White | #1AFFFFFF (10%) | Glassmorphic card |
| Progress Bar | Indigo | #6366F1 | Theme accent |
| Aura Indicator | Red | #EF4444 | Live status |
| Text | White | #FFFFFF | Primary text |
| Secondary | Light White | #FFFFFFCC | Secondary info |

### Progress Bar Animation

The progress bar fills as the class progresses. Implemented in Kotlin:

```kotlin
// Calculate progress 0-100
val progress = ((currentT - startTime) / (endTime - startTime) * 100).toInt()

// Set progress bar width
views.setProgressBar(R.id.widget_progress, 100, progress, false)
```

---

## 🧪 Testing Checklist

- [ ] Widget displays "System Idle" when no class is live
- [ ] Widget shows subject, room, teacher when class is live
- [ ] Progress bar fills correctly (0-100%)
- [ ] Aura indicator shows only for live classes
- [ ] Widget updates when tapping via pending intent
- [ ] Battery drain is minimal (no updates when class unchanged)
- [ ] Manual refresh works
- [ ] Widget survives app restart
- [ ] Works in dark and light launcher themes

---

## 📚 Related Files

| File | Purpose |
|------|---------|
| `lib/widget_service.dart` | Dart-side widget communication |
| `lib/main.dart` | Integration with Dashboard (_updateWidgetIfNeeded) |
| `android/app/src/main/kotlin/OmniFlowWidgetProvider.kt` | Kotlin widget provider |
| `android/app/src/main/res/layout/widget_layout.xml` | Widget UI layout |
| `android/app/src/main/res/xml/widget_provider_info.xml` | Widget metadata |
| `android/app/src/main/AndroidManifest.xml` | Widget registration |
| `android/app/src/main/res/drawable/widget_*.xml` | Widget drawable resources |

---

## 🚀 Future Enhancements

1. **iOS Widget Support** (via home_widget's iOS implementation)
2. **Tap to Open Specific Class** (deep linking)
3. **Widget Configuration Screen** (user preferences)
4. **Multiple Widget Sizes** (1x1, 2x2, 4x4)
5. **Custom Colors** (theme sync with app)
6. **Next 3 Classes** (scrollable widget)
7. **Room Availability** (empty rooms preview)

---

**Last Updated**: February 11, 2026  
**Version**: 1.0  
**Status**: Production Ready
