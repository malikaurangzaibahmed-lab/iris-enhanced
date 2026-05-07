# IRIS Intelligence Suite: System Report

## Executive Summary
IRIS (Intelligent Resource Information System) has been transformed into a fully autonomous, invisible, and high-fidelity synchronization engine. The system now features a "Shadow Scraper" architecture that allows for background portal synchronization without user interruption, unified with a premium "Liquid Glass" design language.

---

## 1. UI/UX Architecture: "Liquid Glass"
We achieved full visual parity between the Portal Screen and the core Vitality OS design system.

- **Liquid Glass Layer**: Implemented physically accurate refraction using `LiquidGlassLayer` with ambient strength (0.65) and light refraction (0.18π).
- **Sync Capsule**: Redesigned the portal header into a dynamic capsule that provides real-time, refractive visual feedback during background tasks.
- **IrisTokens Integration**: All UI components (Address bar, Action chips, Status pills) now utilize official Brand Blue, SurfaceElevated, and Vibrancy tokens.

## 2. Sync Engine: "The Precise Hunter"
The scraping logic was overhauled to ensure zero-noise, high-fidelity task retrieval.

- **Stealth Scraper**: A robust JavaScript engine that handles Cloudflare bypass by utilizing a 10-second hydration delay and human-like interaction timing.
- **Shadow Scraper (Headless WebView)**: A hidden 1x1 pixel WebView that performs context switching (`SetCourse`) and extraction in the background. This prevents the user's manual session from being interrupted.
- **Precise Column Targeting**:
    - **Assignments**: Specifically targets columns 6 & 7 for "Download" and "Upload" actions.
    - **Quizzes**: Intelligently filters for "Not Attempted" status using innerText pattern matching.
- **Context Locking**: Implemented explicit server-side course context switching before extraction to guarantee task availability.

## 3. Real-Time Data Flow: "Lighthouse Notifier"
We bridged the gap between the background scraper and the Home Screen cards.

- **PortalSyncService Notifier**: A global `ValueNotifier` acts as a lighthouse, blinking every time new data is scraped.
- **Dashboard Listener**: The main Dashboard now has "ears"—it listens for the lighthouse pulse and instantly refreshes Home Screen cards without a page reload.
- **Flattening Logic**: A sophisticated data bridge that takes nested Course > Task data and flattens it for a clean, unified view in the app's "Deadlines" card.

## 4. Stealth & Security
- **Cloudflare Resilience**: The system waits for full DOM hydration before triggering background fetches.
- **Session Persistence**: Cookies are shared between the visible and hidden WebViews, ensuring that once a user logs in, the background engine has full access.
- **Invisible Execution**: The background sync is triggered on focus and on page navigation, making it completely "Autonomous."

## 5. Build & Optimization
- **Split APKs**: Generated architecture-specific binaries (`arm64-v8a`, `armeabi-v7a`, `x86_64`) to minimize install size (average ~28MB).
- **Tree-Shaking**: Optimized icon and font assets to reduce footprint.
- **Performance**: Used `Offstage` and tiny-scale WebViews to ensure the background engine consumes minimal CPU/RAM.

---
**Status**: PRODUCTION READY
**Engine Version**: 2.0.0 (Precise Hunter)
**Design System**: Vitality OS (Liquid Glass v2)
