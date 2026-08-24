# IRIS Beta & Staging Multi-Channel Architecture Guide

This guide details how to manage the **Beta & Staging Channel** in IRIS Enhanced alongside the public production release.

---

## 1. Overview of Multi-Channel Architecture

IRIS employs a three-tier channel segregation system:

```
                      ┌─────────────────────────────────────────┐
                      │             IRIS App Core               │
                      └────────────────────┬────────────────────┘
                                           │
                    ┌──────────────────────┴──────────────────────┐
                    ▼                                             ▼
       ┌─────────────────────────┐                   ┌─────────────────────────┐
       │     STABLE CHANNEL      │                   │      BETA CHANNEL       │
       │    (10,000+ Students)   │                   │ (Staging / CRs / Team)  │
       ├─────────────────────────┤                   ├─────────────────────────┤
       │ • Shorebird: `stable`   │                   │ • Shorebird: `beta`     │
       │ • Firestore: `global`   │                   │ • Firestore: `beta`     │
       │ • Badge: "STABLE"       │                   │ • Badge: "BETA TRACK"   │
       └─────────────────────────┘                   └─────────────────────────┘
```

---

## 2. In-App Beta Channel Switcher

Beta testers and developers can switch between release channels at runtime without uninstalling the app or reinstalling APKs.

### How to Switch Channels on Device:
1. Open IRIS $\rightarrow$ Navigate to **Settings / About Screen** (`AboutScreen`).
2. Scroll to the bottom **System Update & Version** card.
3. **Tap the Version row 7 times**.
4. A glass modal sheet opens: **"Release Channel & Staging"**.
5. Select **"Beta Staging Channel"** or **"Production Stable Channel"**.
6. The app instantly switches the Firestore listener (`config/beta` vs `config/global`) and updates the active track.

---

## 3. Shorebird Code Push Multi-Track Deployment

### A. Publishing an Over-the-Air Patch to the Beta Track
When testing a new feature or UI enhancement before general release:
```bash
shorebird patch android --release-version=1.0.3+4 --track=beta --allow-asset-diffs
```
> Only devices with the app set to `beta` track will receive and download this patch.

### B. Promoting a Verified Patch to Production (Stable)
Once verified by beta testers:
```bash
shorebird patch android --release-version=1.0.3+4 --track=stable --allow-asset-diffs
```
> All 10,000+ student devices will automatically download the patch in the background.

---

## 4. Firestore Remote Config & Timetable Staging

In Firebase Firestore, IRIS maintains two root documents under the `config` collection:

1. **`config/global`** *(Production)*:
   - Used by all standard student devices.
   - Contains live `academic_period`, `active_timetable_version`, and live announcement banners.
2. **`config/beta`** *(Staging)*:
   - Used by beta testers.
   - Allows administrators to upload and verify new Midterm/Final date sheets, vacation resumption dates, or emergency notices before broadcasting to the university.

---

## 5. APK Build Guidelines (Split vs. Universal)

| Distribution Method | Build Command | Shorebird Code Push Support |
| :--- | :--- | :--- |
| **Direct APK Sharing** *(WhatsApp / Portal)* | `shorebird release android --artifact=apk` | ✅ Universal APK (~94 MB); all OTA patches are micro-diffs (~150 KB – 1.8 MB). |
| **Google Play Store** | `shorebird release android` | ✅ Android App Bundle (.aab); Google Play automatically delivers split APKs per CPU. |
| **Split APKs** *(Architecture Specific)* | `shorebird release android --artifact=apk --split-per-abi` | ✅ Patch via `shorebird patch android --artifact=apk --target-arch=arm64-v8a`. |
