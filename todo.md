# Iris App Todo List

This file tracks outstanding engineering and visual tasks throughout the Iris codebase (Flutter Mobile Client & Web Admin Portal).

---

## 📱 Mobile App (Flutter & Native Android)

### 🎨 Visual, Environmental & Micro-Interactions (UI/UX)
- [ ] **Nav Bar Color & Polish**:
  - Overhaul the bottom navigation bar with a floating liquid-glass container.
  - Apply custom chromatic color borders, indicator glow rings, and micro-scale transition animations for tab states.
- [ ] **Environmental Atmosphere & Nature-Inspired Physics (Headers Only)**:
  - Integrate ambient weather/time-of-day dynamic shifts (simulated daylight, twilight, nature-like elements) inside top header cards.
  - Implement natural physical behaviors (wind ripples, gravity bounces, fluid sloshing driven by device gyroscope) applied specifically to header structures.
- [ ] **Responsive Beings & Objects inside Headers**:
  - Add responsive particle entities ("beings") within dashboard headers that react to touch (gathering at touch coordinates, scattering on click, floating organically like fireflies).
  - Polish header cards ("objects") to respond with physical weights, friction, inertia, and elastic boundary-springs.
- [ ] **Dynamic Glowing Text Borders**: Implement animating gradient color strips that grow and expand around text input fields when focused and active.
- [ ] **3D Onboarding Screens**: Rebuild onboarding with depth-parallax sliding layers, device screenshots, and perspective tilts.
- [ ] **System-Wide Liquid Glass Widgets**:
  - Extract and port the fluid physics and refraction from the `liquid_glass_widgets` demo repository.
  - Apply the liquid glass refractive container styling to cards and modules *throughout the entire app* (not just the main dashboard).
- [ ] **Global Smart Pill Status**:
  - Propagate the Smart Status Pill across all screens (Faculty portal, Scraper screen, Room finder, Settings).
  - Enable elastic spring scaling, interactive drag gestures, and unified status notification broadcasts.
- [ ] **Mode Change Transitions**: Add premium transition effects when shifting between active modes (Classes, Midterms, Finals, Sports).
- [ ] **Header Card Micro-Animations**: Refine home dashboard header cards with perspective tilts and dynamic particle/gradient backgrounds.
- [ ] **Custom Template Header Cards**: Create distinct visual themes for each mode card (e.g., sports badge theme, dark obsidian exam cards).

### ⚙️ Core Telemetry, Syncing & Download Engine
- [ ] **Complete Download System Re-engineering**:
  - The current download system is broken. Rebuild the file download and parsing pipelines from scratch with robust sync queues, timeout retries, local storage writing verification, and PDF parsing fail-safes.
- [ ] **Download Manager Screen Redesign**:
  - Rebuild the Download Manager screen entirely.
  - Add real-time visual telemetry, circular progress rings, download speed/size stats, cache deletion triggers, and manual offline file synchronization overrides.
- [ ] **Intelligent Name Casing & Parsing**: Refactor name displaying engine to handle complex initials, title prefixes, and clean truncations.
- [ ] **Room Finder Redesign**: Build a clean UX room search console with quick filters, occupancy status indicators, and offline index caching.
- [ ] **Global Code Polish**: Perform a repository-wide clean-up of unused files, redundant imports, and optimize heavy rebuild trees.

### 🤖 Android Native Integration (Performance Boosts)
- [ ] **Strict Scraper Isolation**: Ensure all scraping, networking, and JSON parsing run entirely inside isolated background Dart threads or native Kotlin Coroutines to prevent ColorOS/Android thread jank and frame drops.
- [ ] **Explicit 120Hz Refresh Rate Lock**: Configure native Android activity wrapper to vote for High Frame Rate Category (`REQUESTED_FRAME_RATE_CATEGORY_HIGH` / `120Hz`) in Android 15 to bypass ColorOS battery throttling.

---

## 🖥️ Web Admin Portal

- [ ] **Full Admin Portal Visual & Layout Redesign**:
  - Overhaul the layout structure to have a multi-column command console.
  - Add interactive live mockups (showing exactly what students see on their device in real-time).
  - Add telemetry/database operation dashboards with animated usage charts.
  - Refine Obsidian Glassmorphism card border chromatic aberration gradients and glass refract variables.
- [ ] **Telemetry Link Validation**: Add input sanitation and link verification checks to the Firebase Config setup console.