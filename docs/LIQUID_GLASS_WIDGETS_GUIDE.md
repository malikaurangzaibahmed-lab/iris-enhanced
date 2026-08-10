# Liquid Glass Widgets Reference Guide & Animation Physics Manual

This comprehensive reference manual documents the physical animation mechanics, design system rules, and code cookbook for using `liquid_glass_widgets` in **IRIS Enhanced**.

---

# 🧬 Part 1: Core Physical Animation Mechanics

### 1. 🔄 True Container Morphing
* **What it is**: Instead of rendering a separate overlay widget on top of the screen, the actual boundary box, padding, elevation, and border radius of the trigger widget continuously deform into the target layout.
* **Under the Hood**: Uses `GlassMorphController` to drive smooth geometric interpolation between two states (e.g. static button ➔ context menu).

### 2. 💧 Liquid Swoop Parabola
* **What it is**: A subtle 5px parabolic displacement curve added to the vertical movement vector during container expansion.
* **Under the Hood**: Simulates fluid surface tension — as the container expands, it slightly dips down and snaps up like a liquid droplet.

### 3. 🍮 Jelly Stretch & Velocity Inertia
* **What it is**: Dynamic horizontal or vertical aspect-ratio distortion applied to sliding indicators during gesture drags or state transitions.
* **Under the Hood**: The widget stretches proportionally to velocity (faster movement = wider stretch) and snaps back to original proportions upon arrival.

### 4. 🦘 3D Elevation Thumb Jump
* **What it is**: A parabolic z-axis lift animation that raises a control knob (like a switch thumb) into 3D space during state toggles.
* **Under the Hood**: Combines z-translation, shadow expansion, and scale expansion before landing on the target track position.

### 5. 🪢 Rubber-Band Logarithmic Dampening
* **What it is**: Non-linear drag resistance applied when pulling modal sheets or scroll views beyond their natural boundaries.
* **Under the Hood**: Uses logarithmic decay formulas so the further the user drags, the heavier the resistance feels.

### 6. ✨ Specular Rim Glare Sweeping
* **What it is**: Real-time light reflection beams that follow touch gestures across the glass border highlights.
* **Under the Hood**: Interpolates specular light angles (`lightAngle`) dynamically across the perimeter outline.

---

# 🧩 Part 2: Detailed Component Catalog & Code Cookbook

---

## 1. `GlassMenu` & `GlassMenuItem` (Context & Action Menus)

* **Primary Animation**: True Container Morphing & Liquid Swoop (`stiffness: 300`, `damping: 24`).
* **Key Features**: 95% threshold crossfade, +2% container swell on touch, -3% item press scale, auto-alignment.

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'package:iris/core/glass.dart';

Widget buildGlassMenu(BuildContext context, GlobalKey navKey) {
  return lgw.GlassMenu(
    menuWidth: 240,
    menuBorderRadius: 28.0,
    itemBorderRadius: 20.0,
    settings: IrisGlass.widgetsSettings(
      context,
      blur: 16.0,
      thickness: 18.0,
      ambientStrength: 0.75,
    ),
    triggerBuilder: (context, toggleMenu) {
      return GestureDetector(
        onTap: toggleMenu,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          child: const Icon(Icons.public_rounded, key: navKey),
        ),
      );
    },
    items: [
      lgw.GlassMenuItem(
        title: 'Student Portal',
        icon: const Icon(Icons.school_rounded, color: Color(0xFF3B82F6), size: 18),
        onTap: () {
          // Open Student Portal
        },
      ),
      const lgw.GlassMenuDivider(),
      lgw.GlassMenuItem(
        title: 'Academics Hub',
        icon: const Icon(Icons.auto_stories_rounded, color: Color(0xFF8B5CF6), size: 18),
        onTap: () {
          // Open Academics Hub
        },
      ),
    ],
  );
}
```

---

## 2. `GlassSegmentedControl` (Sliding Pill Filters)

* **Primary Animation**: Jelly Stretch & Velocity Drag Snapping.
* **Key Features**: Velocity-deformable glass pill, drag gesture support, sharp text compositing.

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

Widget buildSegmentedControl(int selectedIndex, ValueChanged<int> onSelected) {
  return lgw.GlassSegmentedControl(
    segments: const ['Daily', 'Weekly', 'Monthly'],
    selectedIndex: selectedIndex,
    onSegmentSelected: onSelected,
    height: 42,
    borderRadius: 21,
    enableHaptics: true,
  );
}
```

---

## 3. `GlassSwitch` (Toggle Switches)

* **Primary Animation**: 3D Elevation Jump & Haptic Track Fade.
* **Key Features**: Parabolic 3D thumb arc, spring momentum track color fade, light impact haptics.

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

Widget buildGlassSwitch(bool isEnabled, ValueChanged<bool> onChanged) {
  return lgw.GlassSwitch(
    value: isEnabled,
    onChanged: onChanged,
    width: 58,
    height: 28,
    activeColor: const Color(0xFF10B981),
    enableHaptics: true,
  );
}
```

---

## 4. `GlassButton` & `GlassIconButton` (Action Buttons)

* **Primary Animation**: Tactile Press Scale (`scale: 0.96`, `stiffness: 400`) & Glare Pulse.

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

Widget buildGlassButton(VoidCallback onPressed) {
  return lgw.GlassButton(
    onTap: onPressed,
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
        SizedBox(width: 8),
        Text('Quick Action', style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
```

---

## 5. `GlassModalSheet` & `GlassActionSheet` (Bottom Sheets)

* **Primary Animation**: Rubber-Band Logarithmic Overscroll & 35% Velocity Dismiss Threshold.

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

void showGlassSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return lgw.GlassModalSheet(
        title: const Text('Options'),
        child: Column(
          children: [
            ListTile(title: const Text('Share'), onTap: () {}),
            ListTile(title: const Text('Delete'), onTap: () {}),
          ],
        ),
      );
    },
  );
}
```

---

# ⚡ Part 3: Performance & Smoothness Standards (60–120 FPS)

1. **Adaptive Blur Scaling**: Always wrap `LiquidGlassSettings` in `IrisGlass.widgetsSettings(context, blur: 16.0)` or `IrisGlass.settings(...)` so blur levels adaptively cap between 12.0–16.0 for continuous 60–120 FPS performance.
2. **Icon Hygiene**: Always pass distinct `Icon` widgets directly to `icon:`. Never embed duplicate emoji characters in `title:` strings.
3. **Symbol Collision Protection**: Always use `import 'package:liquid_glass_widgets/liquid_glass_widgets.dart hide GlassCard;'` alongside `import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;`.
