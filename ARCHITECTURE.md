# OMNI-FLOW OS - Architectural Documentation

## 🏛️ Core Principles

This document defines the **Sacred Rules** that govern the OMNI-FLOW OS codebase. These principles ensure the system maintains its intelligence, performance, and premium user experience.

## 📌 Project Workflow Addendum

The canonical operational rules are tracked in [IRIS_RULES.md](IRIS_RULES.md).

**Always apply these cross-cutting constraints while implementing architecture changes:**
- Ask for explicit approval before running `flutter build apk --split-per-abi`.
- Use the term **smart pill** for the top portal feedback overlay.
- Keep [IRIS_RULES.md](IRIS_RULES.md) updated as new implementation constraints are introduced.

---

## 📜 THE FIVE SACRED RULES

### 1️⃣ THE IMMUTABLE DATA RULE

**Purpose**: Protect the integrity of the university's official timetable.

**Rules**:
- `OmniBrain.universe` is the **Source of Truth**
- `startTime` and `endTime` are **FIXED university slots**
- These times are **NEVER editable** through the UI
- Only `Teacher` names and `Room` numbers can be modified
- All user modifications must be saved as **local overrides**, never by directly editing the core data map

**Implementation**:
```dart
// ✅ CORRECT: Data is immutable
static Map<String, List<ClassSession>> get universe => { ... };

// ❌ WRONG: Don't allow UI to modify time slots
void updateClassTime(String id, String newTime) { /* FORBIDDEN */ }

// ✅ CORRECT: Local overrides only
void overrideTeacherName(String id, String newTeacher) {
  // Save to SharedPreferences as override
}
```

**Why**:
- University schedules are official documents
- Time slot changes require administrative approval
- Prevents data corruption from accidental edits
- Maintains single source of truth for auditing

---

### 2️⃣ THE REGEX PARSING STANDARD

**Purpose**: Handle human typos in data entry without crashes.

**Rules**:
- When adding new class data, **ALWAYS** use `HH:MM` format (e.g., `"08:30"`, `"14:25"`)
- The parser uses `RegExp(r'[:.]')` to accept both `:` and `.` separators
- This handles PDF/Excel import errors gracefully
- Invalid times default to `0.0` (midnight) rather than crashing

**Implementation**:
```dart
// ✅ CORRECT: Flexible parsing
double get safeStartVal { 
  try { 
    var p = startTime.replaceAll(" ", "").split(RegExp(r'[:.]')); 
    return int.parse(p[0]) + (int.parse(p[1])/60.0); 
  } catch(_) { return 0.0; } 
}

// Handles all these formats:
// "08:30" ✅
// "08.30" ✅
// "8:30"  ✅
// "8.30"  ✅
```

**Why**:
- PDF-to-text extraction often introduces formatting errors
- Manual data entry is error-prone
- Better to handle edge cases than crash
- Converts to decimal hours for precise comparisons (8:30 → 8.5)

---

### 3️⃣ THE DYNAMIC DISCOVERY PROTOCOL

**Purpose**: Keep the system intelligent as the university grows.

**Rules**:
- `findEmptyRooms()` **MUST** iterate through the entire `universe` map
- **NEVER** use hardcoded room lists
- The system discovers rooms by scanning all class sessions
- Works automatically when new buildings/rooms are added

**Implementation**:
```dart
// ✅ CORRECT: Dynamic discovery
static List<String> findEmptyRooms() {
  Set<String> allDiscoveredRooms = {};
  for (var sessions in universe.values) {
    for (var s in sessions) {
      allDiscoveredRooms.add(s.room); // Auto-discovery
    }
  }
  // ... calculate free rooms
}

// ❌ WRONG: Hardcoded list
static final List<String> ALL_ROOMS = ["B7", "D7", "C5"]; // FORBIDDEN
```

**Why**:
- Universities constantly add new buildings
- No need to update code when physical infrastructure changes
- Demonstrates true "smart system" capabilities
- Reduces maintenance burden

---

### 4️⃣ STATE MANAGEMENT & THE TICKER

**Purpose**: Balance real-time accuracy with battery/CPU efficiency.

**Rules**:
- `_omniTicker` refreshes every **30 seconds** (NOT 1 second)
- This is an **intentional performance trade-off**
- Keeps Live Progress Bar and Aura accurate without draining battery
- **DO NOT** increase frequency without explicit performance testing
- **DO NOT** remove the ticker (breaks live features)

**Implementation**:
```dart
// ✅ CORRECT: 30-second interval
_omniTicker = Timer.periodic(const Duration(seconds: 30), (timer) {
  if (mounted) setState(() {});
});

// ❌ WRONG: Too frequent, kills battery
_omniTicker = Timer.periodic(const Duration(seconds: 1), ...); // FORBIDDEN
```

**Why**:
- Class sessions are 85 minutes long; 30-second precision is sufficient
- Reduces CPU wake-ups from 3,600/hour to 120/hour (30× improvement)
- Modern Flutter rebuilds are cheap, but timers have overhead
- Progress bar smoothness comes from animation, not refresh rate

---

### 5️⃣ THE Z-AXIS UI ARCHITECTURE (Glassmorphism)

**Purpose**: Maintain the premium "Zenith Aesthetic" visual hierarchy.

**Rules**:
- All glass widgets **MUST** use `BackdropFilter` with `blur: 20-30`
- Live class cards have **highest visual priority**:
  - Border color: `Colors.indigoAccent`
  - Shadow with glow effect
  - Opacity: `0.9` (vs `0.45` for normal cards)
- Layer hierarchy: `Aura (background) → Glass Cards → Live Indicators (top)`
- **DO NOT** reduce blur below 20 (breaks glassmorphism)

**Implementation**:
```dart
// ✅ CORRECT: Proper glassmorphism
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // 20-30 range
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(isLive ? 0.9 : 0.45),
      border: Border.all(color: isLive ? Colors.indigoAccent : Colors.white10),
      boxShadow: isLive ? [BoxShadow(...)] : null, // Aura only for live
    ),
  ),
)

// ❌ WRONG: Blur too low
BackdropFilter(filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5)) // BAD
```

**Why**:
- Glassmorphism requires significant blur to work (iOS design standard)
- Visual hierarchy guides user attention to important information
- Live class must stand out immediately (emergency design)
- Creates depth perception through opacity + blur + shadow stacking

---

## 🏗️ System Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     OMNI-FLOW OS                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐  │
│  │  PRESENTATION LAYER (Z-Axis Glassmorphism)     │  │
│  │  - Dashboard UI                                │  │
│  │  - Bouncing Physics (_BouncyCard)             │  │
│  │  - Staggered Animations                        │  │
│  │  - Neural Aura Gradient                        │  │
│  └─────────────────────────────────────────────────┘  │
│                        ⬇️                               │
│  ┌─────────────────────────────────────────────────┐  │
│  │  LOGIC LAYER (OmniBrain)                       │  │
│  │  - getCurrentClass()                           │  │
│  │  - getNextClass()                              │  │
│  │  - locateTeacher()                             │  │
│  │  - findEmptyRooms() [Dynamic Discovery]       │  │
│  └─────────────────────────────────────────────────┘  │
│                        ⬇️                               │
│  ┌─────────────────────────────────────────────────┐  │
│  │  DATA LAYER (Immutable Source of Truth)        │  │
│  │  - OmniBrain.universe [PROTECTED]             │  │
│  │  - ClassSession models                         │  │
│  └─────────────────────────────────────────────────┘  │
│                        ⬇️                               │
│  ┌─────────────────────────────────────────────────┐  │
│  │  SAFETY LAYER (RegEx Time Parser)              │  │
│  │  - safeStartVal / safeEndVal                   │  │
│  │  - Handles HH:MM and HH.MM formats            │  │
│  │  - Failsafe: defaults to 0.0 on error         │  │
│  └─────────────────────────────────────────────────┘  │
│                        ⬇️                               │
│  ┌─────────────────────────────────────────────────┐  │
│  │  PERSISTENCE LAYER (SharedPreferences)         │  │
│  │  - Batch selection                             │  │
│  │  - Theme preference (dark/light)               │  │
│  │  - Future: Local teacher/room overrides       │  │
│  └─────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🔐 Code Modification Guidelines

### ✅ SAFE Modifications:
- Adding new batches to `OmniBrain.universe`
- Adding new UI components (must follow glassmorphism rules)
- Enhancing teacher search with fuzzy matching
- Adding animations (must maintain 30s ticker)
- Creating local override system (must not modify core data)

### ⚠️ CAUTION Required:
- Modifying `ClassSession` model (affects parsing)
- Changing ticker interval (requires performance testing)
- Adjusting glassmorphism blur values (visual regression risk)
- Adding new time-based logic (must use safeStartVal/safeEndVal)

### ❌ FORBIDDEN:
- Making `universe` mutable or allowing direct edits
- Adding UI controls to edit time slots
- Hardcoding room lists anywhere
- Increasing ticker frequency without approval
- Removing BackdropFilter or reducing blur below 20
- Using alternative time parsing (bypassing RegEx)

---

## 🧪 Testing Checklist

Before merging any changes, verify:

- [ ] `OmniBrain.universe` remains a getter (immutable)
- [ ] No UI elements allow editing startTime/endTime
- [ ] All time parsing uses the RegEx-based getters
- [ ] `findEmptyRooms()` scans the universe dynamically
- [ ] Ticker remains at 30-second interval
- [ ] All glass widgets use BackdropFilter with blur ≥ 20
- [ ] Live cards maintain highest visual priority
- [ ] No hardcoded room/building lists exist
- [ ] SharedPreferences only stores user preferences, not data
- [ ] All new times follow HH:MM format

---

## 📚 Further Reading

- **Material Design 3**: [m3.material.io](https://m3.material.io)
- **iOS Glassmorphism**: Apple HIG - Materials & Blur
- **Flutter Performance**: [flutter.dev/docs/perf](https://flutter.dev/docs/perf)
- **State Management**: Timer-based vs Stream-based approaches

---

## 🆘 Troubleshooting

### "Empty Rooms Not Showing"
→ Check that new rooms are actually in `OmniBrain.universe`. The system auto-discovers them.

### "Live Progress Bar Not Updating"
→ Verify the 30-second ticker is running. Check `_omniTicker` initialization.

### "Times Not Parsing Correctly"
→ Ensure `safeStartVal` uses `RegExp(r'[:.]')`. Test with both "08:30" and "08.30" formats.

### "Glassmorphism Looks Flat"
→ Increase `BackdropFilter` blur to 25-30. Ensure parent widget has visual content behind it.

---

**Last Updated**: February 11, 2026  
**Version**: 2.0 (Neural Edition)  
**Maintainer**: OMNI-FLOW OS Team
