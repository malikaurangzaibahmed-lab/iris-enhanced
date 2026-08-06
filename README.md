# 🌌 IRIS - Next-Gen Student Companion

> **The Ultimate Intelligent Campus Companion & Student Organizer**  
> *Built with Flutter, Office Open XML Native Exporter, Liquid Glass UI Engine, Shorebird OTA Code Push, and Ground-Up Responsive Android HomeScreen Widgets.*

---

## 🌟 Key Highlights & Features

### 📅 Ground-Up Redesigned Android HomeScreen Widgets
- **Celestial Indigo & Obsidian Onyx Dual Glass Themes**:
  - **Light Mode**: Celestial indigo frosted glass (`#EEF2FF` to `#F1F5F9`) with 1.5dp pure white border (`#FFFFFF`).
  - **Dark Mode**: Deep obsidian onyx glass (`#090D16` to `#1E1B4B`) with glowing slate border (`#334155`).
- **Density-Independent DP Responsive Breakpoints**:
  - **Compact Bar Mode (`heightDp < 105dp`)**: Sleek single-row bar (`[ LIVE ] CS-301 • Room C1.2 | 45m left`) for short 2x1 grid heights with **zero clipping**.
  - **Standard Mode (`105dp <= heightDp < 145dp`)**: Full hero layout with automatic card scaling and zero text truncation.
  - **Hero Mode (`heightDp >= 145dp`)**: Complete status pill + course headline + location capsule + instructor subcard + live progress bar + countdown clock.
- **Fail-Safe Fallback RemoteViews Inflation**: Guarantees Android Launcher **NEVER displays "Error loading widget"**, gracefully falling back to a clean safe view if any custom OS anomaly occurs.

### 📄 Document Workspace & Native Office Open XML Engine
- **Native `.docx` Exporter (`DocxGenerator`)**: Generates 100% specification-compliant Word `.docx` ZIP packages containing native XML runs for headers (`#`, `##`), bullet lists (`- `, `* `), and markdown inline formatting (`**bold**`, `*italic*`, `***bold italic***`, `` `code` ``).
- **Raw Pointer Image Gesture Engine**: Uses hardware pointer event listeners (`Listener.onPointerMove`) to allow unrestricted 360° image dragging and resizing on canvas without touch arena competition.
- **COMSATS Sahiwal Campus Locking**: Default institutional settings locked to `COMSATS UNIVERSITY ISLAMABAD - SAHIWAL CAMPUS`.

### ⚡ Dual-Engine Update System (OTA + In-App Installer)
- **Shorebird Instant Over-The-Air Code Push**:
  - Pushes Flutter Dart UI features, bug fixes, and layout tweaks **silently in ~10 seconds** without requiring users to download an APK or reinstall anything.
- **In-App GitHub Auto-Installer (`UpdateService`)**:
  - Real-time download progress stream (`0% ➔ 100%`) with liquid glass progress modal.
  - Automatically triggers 1-tap package installation (`OpenFilex.open()`) with zero data/login loss.

---

## 🏗️ Architecture & Project Structure

```
IRIS Base Directory
 ├── android/                         # Native Android Project & Kotlin AppWidget Providers
 │    └── app/src/main/
 │         ├── kotlin/com/example/student_organizer/
 │         │    ├── ClassTrackerWidget.kt        # Responsive DP Live Class Widget Provider
 │         │    ├── PortalTasksWidget.kt         # Responsive Portal Tasks Widget Provider
 │         │    └── PortalTasksWidgetService.kt  # RemoteViews ListView Adapter Service
 │         └── res/
 │              ├── drawable/                    # Frosted Glass XML Drawables (v2)
 │              └── layout/                      # Compact & Full Widget XML Layouts
 │
 ├── lib/                             # Core Flutter Application Code
 │    ├── core/                       # Design tokens, color system, typography
 │    ├── models/                     # Timetable, assignment, and student data models
 │    ├── screens/                    # Document workspace, academics, timetable shell
 │    ├── services/                   # UpdateService, DocxGenerator, CoverPageGenerator
 │    └── widgets/                    # Liquid Glass UI components & animated docks
 │
 ├── DEPLOYMENT_OPS_MANUAL.md         # Deployment & Update Operations Manual
 └── pubspec.yaml                     # Dependencies & Version Configuration
```

---

## 🛠️ Build & Installation Guide

### Prerequisites
- **Flutter SDK**: `^3.22.0` (Dart 3.4+)
- **Android SDK**: API level 34 (Android 14) / Min SDK 21 (Android 5.0)
- **Gradle**: `8.14`

### Quick Start
```bash
# 1. Clone repository
git clone https://github.com/malikaurangzaibahmed-lab/iris-enhanced.git
cd iris-enhanced

# 2. Install dependencies
flutter pub get

# 3. Analyze code (0 lint errors)
flutter analyze

# 4. Run application
flutter run
```

### Production Release Build
```bash
# Build standalone Release APK
cd android
.\gradlew assembleRelease
```
*Output Release APK Path*: `build\app\outputs\flutter-apk\app-release.apk`

---

## 🚀 Publishing Updates (Admin Cheat Sheet)

### 1. Instant Over-The-Air (OTA) Dart Patch
```bash
# Pushes instant UI/feature patch to all users over-the-air
shorebird patch android
```

### 2. Major Native Release (Kotlin / Permissions)
```bash
# 1. Increment version in pubspec.yaml (e.g. 1.0.2+3)
# 2. Build base Shorebird release
shorebird release android

# 3. Push to GitHub
git add .
git commit -m "Release v1.0.2 with enhanced HomeScreen Widget"
git push origin main
```

*For full operational details, refer to the [Deployment Operations Manual](DEPLOYMENT_OPS_MANUAL.md).*

---

## 🔒 Security & Privacy
- **Zero Secrets in Repository**: Signing keys and passwords are excluded via `.gitignore`.
- **Protected Push Access**: Repository branch protection enabled on `main`. Only authorized maintainers can push commits.

---

## 📄 License & Credits
Developed with ❤️ by **Google DeepMind Team & Malik Aurangzaib Ahmed**. All rights reserved.
