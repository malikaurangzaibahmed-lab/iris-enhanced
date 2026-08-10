# IRIS Enhanced Agent Development Rules & Design System Guidelines

## 1. Liquid Glass Component Selection Rules

- **Context & Popup Menus**: Always use `lgw.GlassMenu` from `package:liquid_glass_widgets/liquid_glass_widgets.dart` with `lgw.GlassMenuItem`.
  - **Icons**: Pass distinct icons directly to `icon:` parameter (e.g. `Icons.school_rounded`, `Icons.auto_stories_rounded`). Do NOT put duplicate emoji characters inside the `title:` string.
  - **Triggers**: Use `triggerBuilder` with `GestureDetector(onTap: toggleMenu)` to ensure tap events cleanly toggle the glass morph controller.
- **Segmented Toggles**: Use `lgw.GlassSegmentedControl` for multi-option filters (e.g. Daily / Weekly / Monthly).
- **Toggle Switches**: Use `lgw.GlassSwitch` for binary settings.
- **Modals & Action Sheets**: Use `lgw.GlassModalSheet` / `lgw.GlassActionSheet` for bottom sheets.

## 2. Performance & Smoothness Standards (60-120 FPS)

- **Adaptive Blur Levels**: Always wrap glass settings in `IrisGlass.widgetsSettings(context, blur: 16.0)` or `IrisGlass.settings(...)` so blur levels scale adaptively down to 12.0–16.0. Avoid hardcoding `blur > 25.0` on frequently rebuilt widgets.
- **Import Collisions**: Always import `package:liquid_glass_widgets/liquid_glass_widgets.dart hide GlassCard;` alongside `import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;` to prevent symbol collisions with `lib/widgets/glass_card.dart`.
- **Over-The-Air Patch Safety**: Never modify the `pubspec.yaml` version number (`1.0.3+4`). All over-the-air patches must be published via `shorebird patch android --release-version=1.0.3+4 --allow-asset-diffs`.
