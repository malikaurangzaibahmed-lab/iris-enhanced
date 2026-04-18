# Features & Issues Tracker

---

## 🔴 Bug Fixes / Critical Issues

- ✅ Sometimes double notifications — **FIXED**
  - Added reminder scheduling dedupe signature to prevent re-scheduling identical sets
  - Switched class reminder notification IDs to stable deterministic IDs
  - Added in-flight scheduling guard and signature reset on cancel
- ✅ Option for alarm type reminder for classes (exact time alarm) — **FIXED**
  - Added exact alarms permission request in notification init
  - Switched reminder scheduling to next-weekly-occurrence logic for reliability
  - Uses AndroidScheduleMode.exactAllowWhileIdle for reliable scheduling
- ✅ In-app notifications (darood reminder, etc.) block access to bottom nav bar — **FIXED**
  - Darood snackbar now uses dynamic bottom-safe margin above floating nav
- ✅ Some lectures confused with break time periods — **FIXED**
  - Current/live class detection now uses actual lecture end-times (including 1-hour markers)
  - Break windows now calculate from actual previous class end, not raw slot end

---

## 🟡 UX/Navigation Improvements

- ✅ Bottom nav bar scroll functionality (works) → **page switching smoothness improved**
  - Added transition input lock during tab animation to prevent rapid-tap jitter
  - Prevented drag-based tab switching while transition is active

---

## 🟢 New Features — Calculators & Tools (Universal)

**Basic Calculators (All Departments):**
- ✅ Unit converter
- ✅ Word counter
- ✅ Universal calculator (unit conversions, markup, scientific ops)
- ✅ CGPA calculator
- ✅ Base converter

**Advanced Calculators:**
- ✅ Equation Solver (advanced algebra & calculus)
- ✅ Molecular Weight Calculator (molar mass from chemical formulas)
- ✅ Offline Formula Library & Constants (thermodynamics, circuits, structures)

**Department-Specific Tools:**
- ✅ **CS Students:** Built-in compiler + related dev tools
- ✅ **CS & Related:** Compiler suite with accessories/tools
- ✅ **Health Departments:** Health calculators (BMI, vitals, etc.) + Periodic Table
- ✅ **MEC:** Resistor Color Code Decoder
- ✅ **Other Departments:** Department-relative accessories & calculators

---

## 🔵 Infrastructure & UI

- ✅ **Tools screen infrastructure** (hosts all calculators/utilities) — **COMPLETED 04/02/2026**
  - Student Dashboard only (index 4, before Makeup and About)
  - 13 universal tools (Unit Converter, Word Counter, Universal Calculator, CGPA Calculator, Base Converter, Equation Solver, Molecular Weight Calculator, Offline Formula Library, Schedule Export, Room Finder, Teacher Directory, Print Timetable, Class Analytics)
  - Department-specific tools for BCS, BBA, RHND (with extension points for others)
  - Live CS module implemented: Code Lab (smart checks, templates, complexity scoring, resource hints)
  - Live CS suite accessories implemented: Snippet Vault, Algorithm Templates, Dry-run Helper
  - Live Health module implemented: BMI assistant, hydration estimator, vitals checker, searchable mini periodic table
  - Live MEC module implemented: 4-band resistor color decoder with tolerance/range output
  - Live Other Departments module implemented: adaptive department smart kit with workload and target-grade planners
  - Live tools implemented: Unit Converter, Word Counter, Universal Calculator, CGPA Calculator, Base Converter, Equation Solver, Molecular Weight Calculator, Offline Formula Library, Class Analytics
  - Smart Tools Assistant added (context-aware recommendation based on live/next class and department)
- ✅ Department-aware visibility (show tools based on user's selected department)
- ✅ Print service implementation to mobile print system
  - Implemented actual PDF generation using syncfusion_flutter_pdf
  - Automatic PDF document creation with formatted timetable layout (headers, columns, day sections)
  - Native Android print dialog integration via Intent-based print system
  - FileProvider configuration for secure file sharing with system print services
  - Fallback UI for PDF fallback scenarios (open PDF in external viewer if print fails)
  - Organized timetable displaying all classes by day of week with time, subject, teacher, and room

---

## Progress Summary

**Total:** 23 items  
**Categories:**
- 🔴 Bugs: 4
- 🟡 UX: 1  
- 🟢 Tools/Calculators: 14
- 🔵 Infrastructure: 4

**Completed:** 21 ✅  
**In Progress:** 0 🔧  
**Remaining:** 2 ⏳

