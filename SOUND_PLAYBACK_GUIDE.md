# IRIS UI Sound System - Troubleshooting Guide

## Ensuring Sounds Actually Play

### What was fixed:

1. **Better Fallback Chain**
   - If tone asset not found → use system sound (Android AudioManager.FX_KEY_CLICK)
   - If system sound fails → silent (no crash or error)

2. **Error Logging**
   - Dart side now logs sound failures with `debugPrint()`
   - Watch logcat or VS Code output for: `Sound play failed for "tone_name"`

3. **Audio System Setup**
   - Uses `USAGE_ASSISTANCE_SONIFICATION` (UI feedback category)
   - Proper audio routing for system sounds

### Audio Files Included

Located in `assets/`:
- `sfx_nav_soft.ogg` - soft navigation tick
- `sfx_nav_click.ogg` - click feedback
- `sfx_confirm.ogg` - confirmation tone
- `ui_toggle_soft.wav/.mp3` - toggle switch soft
- `ui_toggle_click.wav/.mp3` - toggle switch click  
- `ui_sfx/laser.wav` - crisp profile laser sound
- `ui_sfx/coins.wav` - crisp profile coin sound
- `ui_sfx/nasa_on_a_mission.mp3` - mission tone

### Testing Sounds

To verify sounds work on your device:

#### Method 1: Check Device Settings
```
Android Settings → Sound & Vibration → Volume
  - Make sure Media/System volume is not muted
  - Make sure "Do Not Disturb" is off
```

#### Method 2: Watch Console Output
```powershell
# In terminal, run during app testing:
adb logcat | findstr "Sound play failed"

# If you see messages like:
# Sound play failed for "sfx_nav_soft": ...
# This means the asset lookup is failing
```

#### Method 3: Trigger Sounds Manually
Add this test code to any screen (e.g., in portrait_screen.dart):

```dart
import 'package:iris/services/ui_feedback.dart';

// In your build method or a test button:
ElevatedButton(
  onPressed: () {
    IrisSfx.click(); // Should hear click
  },
  child: const Text('Test Click'),
),
ElevatedButton(
  onPressed: () {
    IrisSfx.confirm(); // Should hear 2-note confirm
  },
  child: const Text('Test Confirm'),
),
ElevatedButton(
  onPressed: () {
    IrisSfx.error(); // Should hear 2 error tones
  },
  child: const Text('Test Error'),
),
```

### Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| **No sound at all** | Check device volume isn't muted; check "Do Not Disturb" mode |
| **Logcat shows "Sound play failed"** | Asset file missing → system sound should fallback (should still hear click) |
| **Logcat shows exception errors** | Check MainActivity.kt sound channel is properly registered |
| **Sound only on some actions** | Throttling might be active (48-140ms between sounds); wait between interactions |
| **Sound crackling/distorted** | Volume levels too high; check `volume` values in playUiTone (target 0.06-0.12) |

### Asset Resolution Order

When a sound is requested (e.g., "sfx_nav_soft"):

1. **Pro Pack** (variants): 
   - `assets/ui_sfx_pack/nav_soft.ogg`
   - `assets/ui_sfx_pack/nav_soft_1.ogg` (random selection)
   - `assets/ui_sfx_pack/nav_soft_2.ogg`, etc.

2. **Legacy Assets** (fallback):
   - `assets/sfx_nav_soft.ogg` ✓ (exists)
   - `assets/ui_toggle_soft.wav` (alternate)

3. **System Sound** (final fallback):
   - Android `AudioManager.FX_KEY_CLICK`

4. **Silent**:
   - If all above fail, no sound (no crash)

### Audio Profiles

Users can select in Settings:
- **Gentle** (default): Soft, non-intrusive feedback
- **Balanced**: Medium intensity, natural feel
- **Crisp**: Game-like, distinct feedback

Each profile uses different underlying tones while keeping interaction points consistent.

### Performance Notes

- MediaPlayer instances are properly released after playback
- Asset caching reduces file I/O on repeated sounds
- Throttling prevents callback spam (48-140ms gaps based on sound type)
- Humanized playback rate (±2% drift) makes sounds feel natural, not robotic

### Enabling/Disabling Sounds

In Settings or programmatically:

```dart
// Disable all sounds
await IrisSfx.setEnabled(false);

// Re-enable
await IrisSfx.setEnabled(true);

// Change profile
await IrisSfx.setProfile('crisp');
```
