# IRIS UI Sound Feedback Rules

Natural UI sound placement—only where feedback enhances the experience, never for passive UI elements.

## Sound Profiles

Three named profiles with profile-specific tone overrides:

- **Gentle** (default): Soft, unobtrusive feedback
  - soft_tick: `sfx_nav_soft`
  - click: `sfx_nav_soft`
  - confirm: `sfx_confirm`
  - error: `ui_toggle_soft`

- **Balanced**: Medium feedback intensity
  - soft_tick: `ui_toggle_soft`
  - click: `sfx_nav_click`
  - confirm: `sfx_confirm`
  - error: `sfx_nav_soft`

- **Crisp** (pro/precise): Distinct, game-like feedback
  - soft_tick: `ui_sfx_laser`
  - click: `ui_sfx_coins`
  - confirm: `ui_sfx_coins`
  - error: `ui_sfx_laser`

## Sound Feedback Map

### `IrisSfx` Methods

| Method | Use Case | Throttle (ms) | Pattern |
|--------|----------|---------------|---------|
| `tick()` | Soft, passive feedback (hover, focus, state change) | 48ms | Single soft tone |
| `click()` | Active toggle/selection | 64ms | Single click tone |
| `confirm()` | Destructive action completion, download success, save | 98ms | Soft → Accent (72ms gap) |
| `error()` | Download failure, network error, validation fail | 120ms | Error base × 2 (54ms gap) |
| `downloadSuccess()` | Heavy confirmation for download completion | 140ms | Soft → Accent → Click (68ms + 64ms gaps) |
| `navTick(distance)` | Navigation depth feedback | 54ms | Single soft tone, multi-tone if distance > 1 |

### Current Implementation

**✅ Implemented (Wired)**

- **Theme Toggle** → `IrisSfx.tick()` - soft notification of mode switch
  - File: `lib/main.dart`, `_setThemeMode()`
  - Trigger: User taps theme mode button

- **Download Success (JS)** → `IrisSfx.downloadSuccess()` - 3-phase success
  - File: `lib/portal_screen.dart`, line ~1543
  - Trigger: Base64 data URL file write completes
  - Pattern: soft → confirm accent → click

- **Download Success (Native)** → `IrisSfx.downloadSuccess()` - 3-phase success
  - File: `lib/portal_screen.dart`, line ~1759
  - Trigger: HTTP stream download completes
  - Pattern: soft → confirm accent → click

- **Download Failure (Fallback)** → `IrisSfx.error()` - double error
  - File: `lib/portal_screen.dart`, line ~1956
  - Trigger: All download methods exhausted
  - Pattern: error base × 2

- **Download Failure (JS Error)** → `IrisSfx.error()` - double error
  - File: `lib/portal_screen.dart`, line ~2017
  - Trigger: JavaScript download error handler
  - Pattern: error base × 2

## Sound Placement Principles

### DO Add Sound

✅ **Confirmations** - Save, submit, confirm, delete (soft confirm pair)  
✅ **Completion** - Download done, upload done, sync complete (success pattern)  
✅ **Error/Failure** - Network errors, validation failures, timeouts (error double-tap)  
✅ **Mode Switches** - Theme toggle, profile change (gentle tick)  
✅ **Destructive Actions** - Delete file, clear history, logout (confirm pattern after dialog)  

### DO NOT Add Sound

❌ **Passive Updates** - Loading bars, progress indicators  
❌ **Hover States** - Mouse hover on desktop, don't play per-frame  
❌ **Scrolling** - Too repetitive, annoys on rapid scroll  
❌ **List Item Selection** (view-only) - Just selection, not action  
❌ **Text Input Focus** - Too frequent  
❌ **Background Tasks** - Silent unless completion callback  

## Asset Pack Structure

```
assets/
└── ui_sfx_pack/
    ├── sfx_nav_soft_1.ogg
    ├── sfx_nav_soft_2.ogg
    ├── sfx_nav_click_1.ogg
    ├── sfx_nav_click_2.ogg
    ├── sfx_confirm_1.ogg
    ├── sfx_confirm_2.ogg
    ├── ui_sfx_laser_1.ogg
    ├── ui_sfx_coins_1.ogg
    ├── ui_toggle_soft_1.ogg
    └── README.txt  (authoring guide + free-source asset suggestions)
```

Variant suffix naming (_1, _2, _3, etc.) enables random selection to avoid repetition.

## Throttling Strategy

Each sound method has built-in throttle window to prevent rapid re-trigger:

- `tick()`: 48ms (safe for repeated UI updates)
- `click()`: 64ms (menu navigation, list selection)
- `confirm()`: 98ms (destructive actions, slow user actions)
- `error()`: 120ms (errors should feel distinct, less frequent)
- `downloadSuccess()`: 140ms (completion, rare event)

Per-tone throttle: 52ms (prevents same tone in rapid succession)

## Profile Customization

Users can select feedback profile in Settings:

```dart
IrisSfx.setProfile('gentle');   // Soft, unobtrusive
IrisSfx.setProfile('balanced');  // Default medium
IrisSfx.setProfile('crisp');     // Game-like, precise
```

Profiles swap underlying tones while keeping placement consistent.

## Error Handling

All `IrisSfx` calls are wrapped in throttle guards and fallback to system click on:

- Non-Android platform (iOS falls back to SystemSound)
- Missing tone file (graceful degradation to legacy sound)
- Disabled UI sounds in settings (silent, no error)
- Audio playback permission denied (catch + system sound)

This ensures sounds never break the app or block UI updates.
