# IRIS - Student Organizer

Intelligent timetable and schedule management app with OTA updates, PDF parsing, persistent notifications, and home widgets.

## 📋 Session Handoff & Context Recovery
**Starting a new session or lost context?** See **[docs/SESSION_SUMMARY_MAY_2026.md](docs/SESSION_SUMMARY_MAY_2026.md)** for:
- Recent dynamic transport integration summary
- Faculty UI refinement details
- Build results and release APK locations

## Core Features
- **Smart Timetable Scraper & Sync**: Background re-warming, math CAPTCHA regex solver, and headless session cookie restoration inside WebView.
- **Noticeboard Tab Caching**: Preserves student portal forms, scroll offsets, and active WebView sessions natively in memory using `IndexedStack`.
- **Timetable OTA Diff Alerts**: GlassCard-based warning dashboard displaying room swaps, cancellations, and timing shifts with dynamic dismiss.
- **Home widgets** for Android (OmniFlow, ClassTracker) showing live class status.
- **Teacher locator** for faculty schedule queries.
- **Dynamic Transport**: 30+ bus routes, driver contacts, and live timelines.

## Architecture

- **`lib/core/`**: Central models, OmniBrain block merging, UniversityMemory local fallback, and validation helpers.
- **`lib/services/`**: Timetable OTA, PDF parser, widget background service, foreground notifications, and headless session refresher.
- **`lib/screens/`**: Dashboard main shell, about screen, academics hub, room finder, teacher locator, portal WebView, and setup screens.
- **`lib/widgets/`**: ColorOS-inspired glass card, neural aura shader particles, capsule dashboard navigation dock, and smart overlays.
- **`docs/`**: Clean storage for project manuals, architecture design grids, setup guides, and system rules.
- **`tools/`**: Development scripts, scraper engines, timetable JSON databases, migration backups, and extraction seeds.
- **`design/`**: Conceptual UI mockups, diagrams, and preview screenshots.

For detailed architecture guidelines, see **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

## Project Rules
- Canonical project rules are maintained in **[docs/IRIS_RULES.md](docs/IRIS_RULES.md)**.
- Workflow rule: ask for explicit approval before running `flutter build apk --split-per-abi`.
- Terminology rule: refer to the top portal overlay as the **smart pill**.

## Build Instructions

### Quick Build (Workaround)
If workspace file permissions block Gradle outputs, run this cleanup script to mirror the build directory:
```powershell
$dest = Join-Path $env:USERPROFILE 'student_organizer_build'
if (Test-Path $dest) { Remove-Item -Path $dest -Recurse -Force }
New-Item -ItemType Directory -Path $dest | Out-Null
robocopy . $dest /E /NFL /NDL /NJH /NJS /NP /XD .git build .dart_tool .idea
Set-Location $dest
flutter clean
flutter pub get
flutter build apk --split-per-abi
```

## Documentation Index (Inside `docs/`)
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Design principles, glassmorphism, Z-axis hierarchy
- **[docs/IMPLEMENTATION_ROADMAP.md](docs/IMPLEMENTATION_ROADMAP.md)** - Feature status matrix
- **[docs/WIDGET_GUIDE.md](docs/WIDGET_GUIDE.md)** / **[docs/WIDGET_QUICK_REF.md](docs/WIDGET_QUICK_REF.md)** - Component library
- **[docs/OTA_SETUP_GUIDE.md](docs/docs/OTA_SETUP_GUIDE.md)** / **[docs/OTA_QUICK_START.md](docs/OTA_QUICK_START.md)** - OTA system docs
- **[docs/PDF_PARSER_DOCUMENTATION_INDEX.md](docs/PDF_PARSER_DOCUMENTATION_INDEX.md)** - Parser pipeline reference

## Getting Started (Development)
```bash
flutter pub get
flutter analyze  # Should show zero compilation errors!
flutter run
```

## Tech Stack
- **Framework**: Flutter / Dart
- **State**: setState + StatefulWidgets (no external state lib)
- **Storage**: SharedPreferences + local file overrides
- **PDF**: Syncfusion Flutter PDF
- **Notifications**: flutter_local_notifications + flutter_foreground_task
- **Widgets**: home_widget (Android native)
- **Network**: HTTP (OTA pulls)
