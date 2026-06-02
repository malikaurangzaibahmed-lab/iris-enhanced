# Premium Features & Architecture TODO (Zero-Cost Focus)

## 1. Boot Sequence & Authentication
- [x] **Symphonic Boot Sequence**: Implement a dedicated `SplashScreen` widget.
  - [x] Animate the Liquid Glass gradient orb expanding and pulsing.
  - [x] Synchronize **Progressive Haptics** (`selectionClick` -> `lightImpact` -> `mediumImpact` -> `heavyImpact`) mapped to animation curves.
  - [x] Implement a Hero handoff animation seamlessly transitioning the orb into the login screen logo.
- [x] **Frictionless Login Screen**:
  - [x] ~~Implement primary Native Biometric Auth (`local_auth` for FaceID/Fingerprint) to skip forms entirely.~~ *(Decommissioned to avoid Gradle conflicts and package bloat; replaced by persistent Session Refresher).*
  - [x] Setup UI for Email/Password & Magic Links fallback.
  - [x] Design a glassmorphic pane (`BackdropFilter`) over drifting gradient blur orbs.
  - [x] Implement fluid in-pane transitions (no hard cuts) between "Login", "Sign-Up", and "Forgot Password" states.
- [x] **Auth Optimization**: Ensure auth strictly relies on `FirebaseAuth` without preemptive Firestore reads to protect free tier limits.

## 2. Main App Navigation & UI
- [x] **Smart Pill Integration**: Expand the "Smart Pill" capabilities for unified notifications.
  - [x] Implement animated pill expansion for incoming announcements instead of basic app bar bells.
- [x] **Command Center Drawer/Overlay**:
  - [x] Implement a gesture-based 3D blurred overlay for Profile and Settings (logout via `FirebaseAuth.signOut()`).
  - [x] Develop theme transitioning (color hue shifts) depending on logged-in user role (Student vs Admin).

## 3. Admin UI/UX (OmniFlow Command Center)
- [x] **Admin Dashboard / God Mode**: Ensure restricted access using Proof-of-Admin rules.
  - [x] Build a Bento-style UI overlay for admin controls.
- [x] **Local Audit Queuing**: 
  - [x] Save all admin actions (timetables overrides, user management) to local `SharedPreferences` as an offline cart first.
  - [x] Execute syncs as a single **Batch Write** to protect the 20k/day write quota constraint.
- [x] **Live Broadcasting (System Override)**:
  - [x] Connect admin broadcast inputs to trigger premium glassmorphic dropdown banners on student devices.

## 4. Architecture & Security (Zero-Cost Quota Shield)
- [x] **Proof-of-Admin Security Rule**: 
  - [x] Create a dedicated `admins/{uid}` collection.
  - [x] Update `firestore.rules` to strictly check `exists(/databases/$(database)/documents/admins/$(request.auth.uid))` instead of full user doc reads.
- [x] **Free Push Notifications (Cloudflare Worker Bridge)**:
  - [x] Write a Cloudflare Worker script to accept trusted admin POST requests.
  - [x] Broadcast push notifications via Firebase Cloud Messaging (FCM) topics (e.g., `/topics/all_students`) directly from the Cloudflare worker (Uses 0 Firestore reads).
- [x] **Pull-on-Boot Announcements**: 
  - [x] Remove any broadcast `.snapshots()` user streams if present. Replace with on-boot fetches via Cloudflare cached JSON or a single-time unified document read.
- [x] **Student Sandbox Mode**: 
  - [x] Write logic that enables admins to bypass their UI and load a specific offline View-State (mimicking a target student ID's perspective) for debugging without requiring extra database reads.
