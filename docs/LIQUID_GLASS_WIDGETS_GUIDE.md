# Liquid Glass Widgets Reference Guide & Code Cookbook

This guide provides production-ready code samples and architectural rules for using `liquid_glass_widgets` in **IRIS Enhanced**.

---

## 1. GlassMenu & GlassMenuItem (Context & Action Menus)

`GlassMenu` transforms a trigger widget into a floating liquid glass menu with true spring container morphing, liquid swoop physics, and viewport auto-alignment.

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
          // Action logic
        },
      ),
      const lgw.GlassMenuDivider(),
      lgw.GlassMenuItem(
        title: 'Academics Hub',
        icon: const Icon(Icons.auto_stories_rounded, color: Color(0xFF8B5CF6), size: 18),
        onTap: () {
          // Action logic
        },
      ),
    ],
  );
}
```

---

## 2. GlassSegmentedControl (Jelly Physics Sliding Pill)

Features organic squash-and-stretch velocity sliding pills and drag support.

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

## 3. GlassSwitch (3D Thumb Jump Toggle)

Provides Apple's signature 3D thumb jump elevation animation and haptic snaps.

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

## 4. GlassButton & GlassIconButton (Press Shrink & Specular Glare)

Includes -4% spring scale compression on touch and light glare sweeps across the glass border.

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

## 5. GlassModalSheet & GlassActionSheet (iOS Rubber-Band Sheets)

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
