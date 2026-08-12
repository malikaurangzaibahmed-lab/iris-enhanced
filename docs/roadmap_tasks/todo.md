# Iris App Todo List

This file tracks outstanding engineering and visual tasks throughout the Iris codebase (Flutter Mobile Client & Web Admin Portal).

---

## 📱 Mobile App (Flutter & Native Android)

### 🎨 Visual, Environmental & Micro-Interactions (UI/UX)
- [x] **Nav Bar Color & Polish**:
  - Overhaul the bottom navigation bar with a floating liquid-glass container.
  - Apply custom chromatic color borders, indicator glow rings, and micro-scale transition animations for tab states.
- [x] **Environmental Atmosphere & Nature-Inspired Physics (Headers Only)**:
  - Integrate ambient weather/time-of-day dynamic shifts (simulated daylight, twilight, nature-like elements) inside top header cards.
  - Implement natural physical behaviors (wind ripples, gravity bounces, fluid sloshing driven by device gyroscope) applied specifically to header structures.
- [x] **Responsive Beings & Objects inside Headers**:
  - Add responsive particle entities ("beings") within dashboard headers that react to touch (gathering at touch coordinates, scattering on click, floating organically like fireflies).
  - Polish header cards ("objects") to respond with physical weights, friction, inertia, and elastic boundary-springs.
- [x] **Dynamic Glowing Text Borders**: Implement animating gradient color strips that grow and expand around text input fields when focused and active.
- [x] **3D Onboarding Screens**: Rebuild onboarding with depth-parallax sliding layers, device screenshots, and perspective tilts.
- [x] **System-Wide Liquid Glass Widgets**:
  - Extract and port the fluid physics and refraction from the `liquid_glass_widgets` demo repository.
  - Apply the liquid glass refractive container styling to cards and modules *throughout the entire app* (not just the main dashboard).
- [x] **Global Smart Pill Status**:
  - Propagate the Smart Status Pill across all screens (Faculty portal, Scraper screen, Room finder, Settings).
  - Enable elastic spring scaling, interactive drag gestures, and unified status notification broadcasts.

- [x] **Mode Change Transitions**: Add premium transition effects when shifting between active modes (Classes, Midterms, Finals, Sports).
- [x] **Header Card Micro-Animations**: Refine home dashboard header cards with perspective tilts and dynamic particle/gradient backgrounds.
- [x] **Custom Template Header Cards**: Create distinct visual themes for each mode card (e.g., sports badge theme, dark obsidian exam cards).
- [x] **Debug & Fix Broken Widget**: Investigate and debug rendering/functional issues causing the home screen widgets to be broken on the launcher.

- [x] **Complete Download System Re-engineering**:
  - The current download system is broken. Rebuild the file download and parsing pipelines from scratch with robust sync queues, timeout retries, local storage writing verification, and PDF parsing fail-safes.
- [x] **Download Manager Screen Redesign**:
  - Rebuild the Download Manager screen entirely.
  - Add real-time visual telemetry, circular progress rings, download speed/size stats, cache deletion triggers, and manual offline file synchronization overrides.
- [x] **Intelligent Name Casing & Parsing**: Refactor name displaying engine to handle complex initials, title prefixes, and clean truncations.
- [x] **Room Finder Redesign**: Build a clean UX room search console with quick filters, occupancy status indicators, and offline index caching.
- [x] **Global Code Polish**: Perform a repository-wide clean-up of unused files, redundant imports, and optimize heavy rebuild trees.

### 🤖 Android Native Integration (Performance Boosts)
- [x] **Strict Scraper Isolation**: Ensure all scraping, networking, and JSON parsing run entirely inside isolated background Dart threads or native Kotlin Coroutines to prevent ColorOS/Android thread jank and frame drops.
- [x] **Explicit 120Hz Refresh Rate Lock**: Configure native Android activity wrapper to vote for High Frame Rate Category (`REQUESTED_FRAME_RATE_CATEGORY_HIGH` / `120Hz`) in Android 15 to bypass ColorOS battery throttling.

---

## 🖥️ Web Admin Portal

- [x] **Full Admin Portal Visual & Layout Redesign**:
  - Overhaul the layout structure to have a multi-column command console.
  - Add interactive live mockups (showing exactly what students see on their device in real-time).
  - Add telemetry/database operation dashboards with animated usage charts.
  - Refine Obsidian Glassmorphism card border chromatic aberration gradients and glass refract variables.
- [x] **Telemetry Link Validation**: Add input sanitation and link verification checks to the Firebase Config setup console.

---

## 🚀 Upcoming UI/UX Overhauls & Optimizations
- [ ] **In-App User Feedback System**: Build a dedicated Feedback & Ratings sheet/screen in the Flutter mobile app that allows users to submit bugs, feature requests, and star ratings directly to Firebase Firestore (`feedback` collection).
- [ ] **Web Platform Redesign & Feedback Center**: Complete ground-up redesign of the IRIS Web Platform with multi-page navigation, performance optimizations, and user feedback submission portal.

- [x] **Batch Selection Screen & Modal Sheet UI/UX Overhaul**
  - Redesign `BatchSelectorSheet` in [batch_selector.dart](file:///d:/Iris%20Working%20backup/MOST%20RECENT/IRIS/lib/widgets/batch_selector.dart) and onboarding setup dropdowns in [setup_screens.dart](file:///d:/Iris%20Working%20backup/MOST%20RECENT/IRIS/lib/screens/setup_screens.dart) to use a premium, glassmorphic select deck with animated transitions.
  - Simplify selections to be more visual, responsive, and seamless, replacing standard list menus with smooth-expanding list containers.
- [x] **Settings Screen (About Screen) Visual Overhaul**
  - Re-conceptualize [about_screen.dart](file:///d:/Iris%20Working%20backup/MOST%20RECENT/IRIS/lib/screens/about_screen.dart) into a unified settings/about center with premium bento grid configurations, smoother micro-actions, and cohesive layouts.
- [x] **Header Animations & Gyro/Physics Overhaul**
  - Remove all floating yellow fireflies (`NatureBeingsPainter` beings list) from [nature_particles.dart](file:///d:/Iris%20Working%20backup/MOST%20RECENT/IRIS/lib/widgets/nature_particles.dart) while preserving interactive touch sparkles for a cleaner look.
  - Redesign mode-specific header animations in `StudentsWeekPainter` inside [students_week_screen.dart](file:///d:/Iris%20Working%20backup/MOST%20RECENT/IRIS/lib/screens/students_week_screen.dart) to cycle and loop seamlessly with custom easing, preventing jarring jumps or resets.
- [x] **Room Finder Screen Complete Overhaul**
  - Redesign [room_finder_screen.dart](file:///d:/Iris%20Working%20backup/MOST%20RECENT/IRIS/lib/screens/room_finder_screen.dart) to use a modern, dual-pane search dashboard.
  - Add quick-search tags, visual room occupancy timeline blocks, and a clean card style layout.
- [x] **Resources/Tools Screen (Tools Screen Part) Complete Overhaul**
  - Overhaul [tools_screen_part.dart](file:///d:/Iris%20Working%20backup/MOST%20RECENT/IRIS/lib/screens/tools_screen_part.dart) layout to feature a premium category card system, glass-molded action tiles, and a floating smart recommendation bar.