# IRIS - Student Organizer

Intelligent timetable and schedule management app with OTA updates, PDF parsing, persistent notifications, and home widgets.

## 📋 Session Handoff & Context Recovery
**Starting a new session or lost context?** See **[HANDOFF_INDEX.md](HANDOFF_INDEX.md)** for:
- Quick resume guide (QUICK_RESUME.md)
- Recent redesign summary (MARCH_2026_REDESIGN_SUMMARY.md)
- Build workaround + commands (SESSION_HANDOFF.md)

## What This App Does
- **Smart schedule tracking** for students and faculty
- **Temporal intelligence** (current class, next class, time-aware insights)
- **PDF timetable parsing** with batch/teacher/subject extraction
- **OTA updates** via Cloudflare Workers (cache merge, versioning)
- **Persistent notifications** showing live class status
- **Home widgets** for Android (OmniFlow, ClassTracker)
- **Teacher locator** for faculty schedule queries

## Architecture
- **Core**: `lib/core/` (models, OmniBrain, UniversityMemory, format guards)
- **Services**: `lib/services/` (OTA, PDF parser, storage, notifications)
- **UI**: `lib/main.dart` + `lib/screens/` (dashboard, faculty views)
- **Design system**: ColorOS-inspired soft glass hierarchy with motion tokens

For detailed architecture, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Project Rules
- Canonical project rules are maintained in [IRIS_RULES.md](IRIS_RULES.md).
- Workflow rule: ask for explicit approval before running `flutter build apk --split-per-abi`.
- Terminology rule: refer to the top portal overlay as the **smart pill**.
- Process rule: keep rules updated in [IRIS_RULES.md](IRIS_RULES.md) as new constraints are added.

## Build Instructions

### ⚠️ Known Issue: ACL Restriction
The main workspace folder has restrictive ACL permissions blocking Gradle writes.  
Use the **mirror-build workaround** documented in [SESSION_HANDOFF.md](SESSION_HANDOFF.md).

### Quick Build (Workaround)
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

### Fix Permissions (Alternative)
```powershell
icacls C:\student_organizer /grant:r ${env:USERNAME}:(OI)(CI)M /T
flutter clean
flutter build apk --split-per-abi
```

## Documentation Index
- **ARCHITECTURE.md** - Design principles, glassmorphism, Z-axis hierarchy
- **IMPLEMENTATION_ROADMAP.md** - Feature status matrix
- **WIDGET_GUIDE.md** / **WIDGET_QUICK_REF.md** - Component library
- **OTA_SETUP_GUIDE.md** / **OTA_QUICK_START.md** - OTA system docs
- **PDF_PARSER_DOCUMENTATION_INDEX.md** - Parser pipeline reference
- **MARCH_2026_REDESIGN_SUMMARY.md** - Recent UI modernization work

## Getting Started (Development)
```bash
flutter pub get
flutter analyze  # Should show: No issues found!
flutter run
```

## Tech Stack
- **Framework**: Flutter / Dart
- **State**: setState + StatefulWidgets (no external state lib)
- **Storage**: SharedPreferences + file overrides
- **PDF**: Syncfusion Flutter PDF
- **Notifications**: flutter_local_notifications + flutter_foreground_task
- **Widgets**: home_widget (Android native)
- **Network**: HTTP (OTA pulls)
