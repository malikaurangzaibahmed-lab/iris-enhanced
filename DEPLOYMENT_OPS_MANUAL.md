# 🚀 IRIS Deployment & Update Operations Manual

This document is the authoritative operations manual for publishing updates to **IRIS**, managing Over-The-Air (OTA) patches, and delivering major native releases seamlessly to your users.

---

## 🏗️ 1. Architecture Overview: The Dual-Engine System

IRIS uses a **Hybrid Update Architecture** to give users the fastest, most frictionless update experience possible while giving you complete control as the Admin.

```
                           ┌──────────────────────────────────────────────┐
                           │            IRIS Project Codebase             │
                           └──────────────────────┬───────────────────────┘
                                                  │
                             Is this a Dart update or a Native Kotlin update?
                                                  │
                 ┌────────────────────────────────┴────────────────────────────────┐
                 ▼                                                                 ▼
      [ Dart Code & UI Updates ]                                      [ Native Android / Kotlin ]
                 │                                                                 │
    ⚡ Shorebird Code Push (OTA)                                      📦 In-App GitHub Auto-Installer
                 │                                                                 │
  • Size: ~50 KB patch                                           • Size: Full APK (~30 MB)
  • User Action: ZERO (Silent)                                    • User Action: 1-Tap Apply
  • Speed: Instant on next app launch                             • Speed: 2-Second In-Place Update
  • Preserves user data & logins                                  • Preserves user data & logins
```

---

## ⚡ 2. Admin Guide: Daily Workflow & Command Cheat Sheet

### A. Publishing an Instant Over-The-Air (OTA) Patch (Dart Code)
Use this whenever you edit Flutter screens, fix UI bugs, tweak logic, or add Dart features:

```bash
# 1. Ensure code is committed
git add .
git commit -m "Fix layout spacing on document screen"

# 2. Push instant OTA patch
shorebird patch android
```
> **User Experience**: The patch deploys in ~10 seconds. When users open IRIS, the update loads **silently in the background** with zero prompts or APK downloads.

---

### B. Publishing a Major Native Release (Kotlin / Android Manifest)
Use this whenever you edit `ClassTrackerWidget.kt`, update native Android permissions in `AndroidManifest.xml`, or change Gradle dependencies:

```bash
# 1. Update version in pubspec.yaml (Increment build number)
#    version: 1.0.1+2  ->  version: 1.0.2+3

# 2. Create base Shorebird Release & APK
shorebird release android

# 3. Push code to GitHub
git add .
git commit -m "Release v1.0.2 with enhanced HomeScreen Widget"
git push origin main
```
> **User Experience**: IRIS detects the new release on GitHub via `UpdateService`. A frosted liquid glass banner pops up with your release notes. Clicking **"Update Now"** streams the APK in the background and triggers Android's 1-tap in-place installer.

---

## 📲 3. User Experience Matrix

| Update Type | Trigger Cause | User Experience | Data Preservation |
| :--- | :--- | :--- | :--- |
| **Silent OTA Patch** | UI redesign, Dart bug fix, new screen | **100% Invisible**: New feature appears instantly on app restart. | **100% Intact** (Database, logins, timetable preserved). |
| **Major Release** | Kotlin widget update, new Android permission | **Liquid Glass Modal**: Progress bar fills during download ➔ 1-tap native install prompt. | **100% Intact** (Database, logins, timetable preserved). |

---

## 🔒 4. Repository & Code Security Policies

1. **Access Control**:
   * Repository Visibility: **Public**
   * Commit & Push Rights: **Restricted to Repository Owner ONLY**.
   * Outsider Contributions: Require manual Pull Request review and approval by Admin.

2. **Secrets Protection**:
   * `.gitignore` protects `key.properties`, signing `.jks` keys, and local environment secrets.
   * `UpdateService` only uses public REST endpoints (`https://api.github.com/...`).

3. **Recommended GitHub Branch Protection**:
   * Navigate to `Repository Settings` ➔ `Branches` ➔ Add rule for `main`:
     * Check: `Require a pull request before merging`.
     * Check: `Require status checks to pass before merging`.
