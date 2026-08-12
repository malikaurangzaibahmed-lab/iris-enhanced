# IRIS / Student Organizer - Project Brief for Stitch AI

This document is a compact but complete product and implementation brief for the IRIS app in this workspace. It is written so another AI system can understand the app structure, UI language, logic rules, and the OTA timetable data contract without reading the whole codebase first.

## 1. Product Summary

IRIS is a Flutter app for student and faculty timetable intelligence. It is not just a static timetable viewer. It combines live schedule awareness, teacher lookup, room availability, portal syncing, notifications, home widgets, and over-the-air timetable updates.

Core outcomes:

- Show the current class, next class, and daily timeline for a selected batch or teacher.
- Let users switch between student and faculty workflows.
- Search teachers with fuzzy matching and live schedule context.
- Find empty rooms and suggest makeup slots.
- Keep timetable data updated remotely without shipping a new APK.
- Surface schedule state in persistent notifications and Android home widgets.

## 2. Main User Modes

### Student mode

The student flow is centered on batch-based timetable tracking. The app loads the selected batch, shows the live class state, generates a timeline, and exposes portal, tools, and about surfaces through a bottom navigation style layout.

### Faculty mode

Faculty mode is a teacher-centric version of the schedule experience. It focuses on teacher selection, teacher schedule lookup, faculty profiles, reminder setup, and live status reporting for the chosen teacher.

### Utility mode

The app also includes support tools such as teacher locator, room finder, portal sync, and OTA refresh. These are not decorative extras. They are part of the core workflow.

## 3. App Structure

Top-level structure in the codebase:

- `lib/main.dart` - app bootstrap, role routing, theme persistence, startup initialization.
- `lib/core/` - data models, time parsing, theme tokens, motion, and domain logic.
- `lib/screens/` - dashboard, faculty dashboard, teacher locator, room finder, about, setup, login, splash, and related screens.
- `lib/services/` - OTA, notifications, portal sync, helpdesk integrations, storage, and analytics-style services.
- `lib/widgets/` - reusable UI building blocks such as glass cards, neural aura, smart pill overlay, portal sync card, batch selector, and navigation dock.

## 4. Screen Map

### Dashboard

The dashboard is the main student surface. It combines the timetable timeline, current class state, live progress, bottom navigation, portal entry, tools, and about section. It also handles makeup sessions, widget updates, and persistent notifications.

### Faculty dashboard

The faculty dashboard is a separate experience tailored for teachers. It loads the selected teacher from local storage, tracks live schedule state, and integrates reminders and teacher profile data.

### Teacher locator

This screen searches teachers by name, supports typo-tolerant fuzzy matching, and shows live/today/weekly schedule results. It also connects to faculty profile data when available.

### Room finder

This screen calculates room availability from the timetable, supports time and day filtering, and generates recommendations for available rooms and make-up placement.

### Portal screen

This is the in-app browser / portal sync surface. The codebase also persists portal sessions, downloads, uploads, and tasks extracted from the portal.

### About screen

The about screen doubles as a settings and system status page. It shows user profile data, notification controls, haptics/sounds preferences, widget settings, and OTA sync status.

### Setup, login, splash, and admin surfaces

These exist to support onboarding, role selection, and higher privilege workflows. The app has additional admin and debug-oriented surfaces in the codebase, but the main product flow is student/faculty timetable intelligence.

## 5. Core Domain Logic

### Timetable model

The main schedule model is `ClassSession` in `lib/core/models.dart`. Each session has:

- `id`
- `batchKey`
- `dayIndex`
- `startTime`
- `endTime`
- `subject`
- `teacher`
- `room`

The timetable is organized through `UniversityMemory`, which stores the session list and provides grouping by batch, program, semester, and section.

### Batch parsing

`BatchKey.parse()` splits batch IDs into:

- intake
- program
- semester
- section

This allows the app to build batch-aware navigation and filtering without manual batch metadata everywhere.

### Time parsing and guards

Time values are intentionally resilient. `FormatGuard.toDecimalTime()` accepts both `:` and `.` separators. It also treats university-style early-afternoon values like `1:00` to `4:30` as PM time.

Important behavior:

- Invalid time strings fall back safely instead of crashing.
- Days are normalized through `FormatGuard.dayIndex()` and `normalizeDay()`.
- Rooms are sanitized with `FormatGuard.sanitizeRoom()`.

### Current and next class logic

`OmniBrain` computes live schedule state:

- `getCurrentClass()` checks whether the current time falls within a session window.
- `getNextClass()` finds the next upcoming session today, then falls back to later days.
- Teacher-specific versions do the same against the teacher schedule.

### Session merging logic

The app can merge consecutive sessions that belong to the same lecture block.

- `getMergedConsecutiveSessions()` merges adjacent sessions in a batch schedule.
- `getMergedSession()` expands a single session into its full contiguous block.

This is important for real university timetables where a lecture may span multiple slots.

### One-hour lecture override

Some subjects include markers like `(1 hr)` or `(1Hr)`. Those are treated specially so the live window can be corrected even when the raw end time is not ideal.

### Teacher locator logic

Teacher lookup uses:

- direct substring matching
- normalized teacher names
- Levenshtein distance for fuzzy fallback

That means the app can recover from partial names and spelling mistakes.

### Room finder logic

Room availability is computed from timetable sessions. Rooms are discovered dynamically from actual session data rather than hardcoded lists. This is part of the app's architecture rule set.

## 6. OTA Timetable System

The OTA layer lives in `lib/services/timetable_ota_service.dart` and is designed to update timetable content without rebuilding the app.

### How it works

1. The app checks a remote JSON file on startup or on a rate-limited cadence.
2. If the remote data differs from the cached local content, the app downloads the new timetable.
3. The new JSON is cached in `SharedPreferences`.
4. The app uses the cached copy on later launches and falls back cleanly if the network fails.

### Supported OTA formats

The service accepts two timetable shapes:

#### Format A: direct array

```json
[
  {
    "department": "BBA",
    "batch": "FA22-BBA-B31",
    "day": "Monday",
    "start": "10:00",
    "end": "11:00",
    "subject": "CRM",
    "teacher": "Dr. Saqib Ali",
    "room": "B5"
  }
]
```

#### Format B: object with sessions array

```json
{
  "sessions": [
    {
      "batch": "FA22-BBA-B31",
      "day": "Monday",
      "start": "10:00",
      "end": "11:00",
      "subject": "CRM",
      "teacher": "Dr. Saqib Ali",
      "room": "B5"
    }
  ]
}
```

### Canonical session fields

Each timetable entry should include:

- `department` - optional but present in the seed file
- `batch` - batch identifier
- `day` - day name, such as Monday
- `start` - start time string
- `end` - end time string
- `subject` - subject title
- `teacher` - teacher name
- `room` - room or lab identifier

### Time format expectations

- Use `HH:MM` or similar human-readable values.
- The parser accepts `:` and `.` separators.
- The current app is tolerant of values like `1:00` for afternoon classes.

### OTA metadata

The OTA service can optionally use a metadata endpoint that exposes versioning. When metadata is absent, the app compares the downloaded JSON body directly against the cached copy.

### Local cache keys

Relevant preference keys used by the OTA service:

- `ota_timetable_version`
- `ota_last_check_time`
- `ota_cached_timetable`
- `ota_cached_metadata`

### Update policy

- Startup check can run immediately.
- Normal update checks are rate-limited to once per 24 hours.
- Manual refresh is available through the UI.

## 7. UI and UX Design Language

The design direction is a soft glass, premium, OS-like experience. The codebase uses a unified visual language rather than a generic Flutter look.

### Visual identity

- Primary accent color is a vivid blue brand tone.
- Backgrounds use dark or light surfaces with layered depth.
- Glass surfaces use opacity, blur, borders, and subtle shadows.
- Aural gradients and soft glows reinforce active states.

### Typography

The theme uses `SF Pro Display` as the main font family. Typography hierarchy is explicit and intentional, with separate styles for display, title, headline, body, label, caption, overline, greeting, insight, and setting text.

### Glass system

Reusable glass surfaces are built around `GlassCard` and liquid glass rendering. The system uses:

- backdrop blur
- translucent fills
- rounded continuous radii
- glow states for emphasis
- optional tilt and shimmer treatments

### Neural aura background

The `NeuralAura` widget provides animated background gradients that shift based on tone. This gives the app a cinematic backdrop without overpowering content.

### Motion system

The app uses a deliberate motion language:

- spring-like transitions
- fade and scale route animations
- buttery scroll physics
- motion-enabled entrance effects for cards and panels

### Navigation and hierarchy

The student dashboard uses a bottom navigation style layout with Portal, Tools, and About surfaces. The active item is emphasized through glow, scale, and animation rather than just a flat icon change.

### Feedback language

The app is built around gentle but constant feedback:

- haptics for navigation and actions
- frosted snackbars for status messages
- persistent notifications for live class state
- widget updates for glanceable status

### Layout behavior

The experience is built for mobile first, but the layout logic also tries to remain comfortable on larger screens. Content cards, segmented filters, horizontal chip rows, and stacked panels are common patterns.

## 8. Student Dashboard Behaviors

The dashboard is not a static timetable list. It performs multiple jobs:

- shows the current class and next class
- builds a timeline for the selected day
- tracks progress through the active class
- updates widgets and notifications when state changes
- supports makeup session insertion and removal
- persists the selected batch

It also maintains a 30-second refresh ticker. This is intentional so live data stays current without wasting battery.

### Makeup class logic

Makeup sessions are treated specially:

- duplicate prevention is enforced
- cross-batch insertion is blocked
- overlapping sessions are checked
- overlapping makeup slots can be replaced while preserving restore history

This makes the schedule editor feel safe instead of destructive.

## 9. Faculty Dashboard Behaviors

The faculty dashboard mirrors the student mode but is teacher-centric.

- selected teacher is stored locally
- reminders can be scheduled for the teacher's classes
- faculty profiles are loaded from the helpdesk service
- live class state drives widget and notification updates

This screen is designed for quick teaching-day awareness rather than broad timetable browsing.

## 10. Portal and Data Persistence

The portal layer has its own data model for sessions, downloads, uploads, and tasks.

### Portal session model

The app stores portal metadata such as:

- host
- title
- URL
- saved username
- timestamps
- cookie validity
- recent downloads
- recent uploads
- tasks
- last sync time

### Portal tasks

Portal tasks represent items like assignments or quizzes. They track:

- type
- title
- subject
- due date
- scraped time
- completion state
- status
- optional course ID

### Download records

Download data keeps track of:

- filename
- local file path
- source URL
- saved timestamp
- backend type
- download state

## 11. Room Finder Experience

The room finder screen is time-aware and occupancy-aware.

Key UX features:

- search by room or block
- pick a day
- pick a lecture slot or manual time
- filter by building
- show a recommended room when no manual time is chosen

Key logic details:

- room availability is computed from the timetable
- rooms are dynamically discovered from session data
- stored rooms are enriched and persisted locally
- recommendation logic looks for the best available room for a target capacity

## 12. Teacher Locator Experience

The teacher locator combines schedule intelligence and fuzzy search.

Key UX features:

- quick teacher search field
- smart suggestions while typing
- closest-match fallback when the exact search fails
- live, today, and weekly schedule views
- optional teacher profile integration

This screen is meant to answer the question, "Where is this teacher right now?" as quickly as possible.

## 13. About / Settings Experience

The about screen is a system control panel.

It includes:

- user display name editing
- student or teacher role toggle
- batch selection
- persistent notification toggle
- widget dark mode toggle
- UI haptics and sounds preferences
- feedback profile selection
- OTA status refresh and manual sync

This is where product-level preferences live, not just an informational about page.

## 14. State and Persistence

The app relies mainly on `SharedPreferences` for local persistence. It stores things like:

- theme mode
- user role
- selected batch
- faculty teacher
- OTA cache
- widget state
- notification settings
- UI feedback settings

The timetable itself is treated as the source of truth, while user edits and preferences are stored separately as local state.

## 15. External Services and Integrations

The codebase integrates with:

- HTTP for OTA and web services
- Firebase packages for future or existing backend support
- Flutter local notifications
- foreground tasks for persistent class notifications
- home_widget for Android widgets
- webview and file picker for portal flows
- Syncfusion PDF tools for timetable extraction
- URL launcher for phone, email, and web actions

## 16. Design Constraints That Should Be Preserved

If Stitch AI redesigns the UI, these are the strongest constraints to keep:

- Do not flatten the app into a generic Material template.
- Keep the glass / layered / aura identity.
- Keep live class state visually dominant.
- Keep teacher and room discovery highly searchable.
- Keep the bottom navigation and dashboard-first mental model.
- Keep OTA as a first-class product feature, not a hidden admin detail.
- Keep the student/faculty split clear.

## 17. What Stitch AI Should Build From This

The best output for Stitch would be a polished product UI that preserves the current information architecture:

- a high-contrast home dashboard for live schedule state
- a teacher finder with fuzzy search and profile cards
- a room finder with time-based filters and recommendations
- a portal sync surface with recent activity cards
- a settings/about panel with OTA and widget controls

## 18. Important Implementation Notes

- Time logic is decimal-hour based internally.
- The app relies on merged consecutive sessions to avoid duplicated lecture blocks.
- Current and next class calculations are central to almost every surface.
- The OTA service currently supports raw JSON comparison when no metadata endpoint is present.
- Home widget and notification updates are part of the live schedule loop.

## 19. Short JSON Reference for Stitch

If you only need the OTA payload contract, use this minimal shape:

```json
{
  "department": "BBA",
  "batch": "FA22-BBA-B31",
  "day": "Monday",
  "start": "10:00",
  "end": "11:00",
  "subject": "CRM",
  "teacher": "Dr. Saqib Ali",
  "room": "B5"
}
```

The app can ingest either a plain array of these objects or an object containing `sessions`.

## 20. Reference Files

- [lib/main.dart](lib/main.dart)
- [lib/core/models.dart](lib/core/models.dart)
- [lib/core/omni_brain.dart](lib/core/omni_brain.dart)
- [lib/core/format_guard.dart](lib/core/format_guard.dart)
- [lib/services/timetable_ota_service.dart](lib/services/timetable_ota_service.dart)
- [lib/screens/dashboard_screen.dart](lib/screens/dashboard_screen.dart)
- [lib/screens/faculty_dashboard_screen.dart](lib/screens/faculty_dashboard_screen.dart)
- [lib/screens/teacher_locator_screen.dart](lib/screens/teacher_locator_screen.dart)
- [lib/screens/room_finder_screen.dart](lib/screens/room_finder_screen.dart)
- [lib/screens/about_screen.dart](lib/screens/about_screen.dart)
- [lib/portal_screen.dart](lib/portal_screen.dart)
- [assets/timetable_seed.json](assets/timetable_seed.json)
