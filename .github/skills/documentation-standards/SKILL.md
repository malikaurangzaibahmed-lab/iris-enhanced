---
name: documentation-standards
description: "Standards for documenting IRIS codebase and keeping documentation in sync. Use when: writing code comments, updating README, maintaining architecture docs, creating API documentation, or standardizing documentation across the project."
---

# IRIS Documentation Standards

Your main pain point is **documentation**, so this skill covers best practices for keeping docs and code synchronized.

## Documentation Structure

```
IRIS/
├── README.md                      # Project overview, setup instructions
├── ARCHITECTURE.md                # System design and data flow
├── IMPLEMENTATION_ROADMAP.md      # Planned features and progress
├── FEATURES_TODO.md               # Feature backlog
├── OTA_SETUP_GUIDE.md             # OTA (Over-the-Air) widget setup
├── FIREBASE_SETUP_GUIDE.md        # Firebase configuration guide
├── PERFORMANCE_OPTIMIZATION.md    # Optimization strategies
├── PDF_PARSER_TESTING_GUIDE.md    # PDF parsing documentation
├── WIDGET_GUIDE.md                # Widget implementation guide
├── WIDGET_IMPLEMENTATION.md       # Detailed widget specs
├── IRIS_SYSTEM_REPORT.md          # System analysis reports
├── .github/
│   ├── AGENTS.md                  # Custom agents documentation
│   ├── agents/                    # Individual agent docs
│   ├── skills/                    # Domain skills
│   └── instructions/              # File-specific instructions
└── lib/                           # In-code documentation
    └── [dartdoc comments]         # API documentation
```

## Code Documentation Guidelines

### Dartdoc Comments

**Every public API should have dartdoc comments:**

```dart
/// Fetches the current user's timetable from Firestore.
///
/// This method queries the Firestore database for the timetable
/// associated with the current user's department and semester.
///
/// Returns a [Timetable] object containing the schedule data.
///
/// Throws [FirestoreException] if the query fails.
///
/// Example:
/// ```dart
/// final timetable = await timetableService.getTimetable();
/// print(timetable.classes); // List<Class>
/// ```
Future<Timetable> getTimetable() async {
  try {
    final doc = await _firestore.collection('timetables')
      .doc(_currentUserDept)
      .get();
    return Timetable.fromJson(doc.data() ?? {});
  } catch (e) {
    throw FirestoreException('Failed to fetch timetable: $e');
  }
}
```

### Comment Styles

#### 1. **Complex Algorithm Comments**
```dart
/// Parses a PDF timetable using OCR and pattern matching.
///
/// Algorithm:
/// 1. Extract text from PDF using pdf_render plugin
/// 2. Split text into lines and identify headers (days, times)
/// 3. Use regex to match class patterns: "TIME - SUBJECT (CODE) - ROOM"
/// 4. Validate against known department structure
/// 5. Return structured [Timetable] object
///
/// Returns null if PDF format is unrecognized.
Timetable? parseTimetablePDF(File pdfFile) {
  // Implementation...
}
```

#### 2. **Non-obvious Implementation Comments**
```dart
// IMPORTANT: We use microsecondsSinceEpoch instead of DateTime.now()
// because DateTime.now() has lower precision on some Android devices.
// This ensures accurate scheduling for class reminders.
final timestamp = DateTime.now().microsecondsSinceEpoch;
```

#### 3. **Workaround/Hack Comments**
```dart
// TODO: Remove this workaround once Firestore composite index auto-creation is fixed
// See: https://github.com/firebase/firebase-js-sdk/issues/XXXX
final query = firestore.collection('classes')
  .where('timetableId', isEqualTo: timetableId)
  .where('startTime', isGreaterThan: now)
  .orderBy('startTime')
  .orderBy('name'); // This requires a composite index
```

#### 4. **Why, Not What Comments**
```dart
// ✅ Good: Explains why, not what the code does
// We cache timetable locally to minimize Firestore reads
// and provide instant access when user opens the app offline.
if (_cache.containsKey(key)) {
  return _cache[key];
}

// ❌ Bad: Just explains what the code does
// Check if key exists in cache
if (_cache.containsKey(key)) {
  return _cache[key];
}
```

## README.md Structure

```markdown
# IRIS - Student Organizer

## Overview
Brief description of what IRIS does.

## Features
- List of main features
- Platform support
- Key differentiators

## Quick Start
### Prerequisites
- Flutter 3.x
- Dart 3.x
- Firebase CLI

### Installation
Step-by-step setup instructions.

### First Run
How to run the app locally.

## Project Structure
High-level folder overview.

## Architecture
Link to detailed ARCHITECTURE.md.

## Development

### Building
Commands for debug/release builds.

### Testing
How to run tests.

### Debugging
Tips for debugging issues.

## Firebase Setup
Refer to FIREBASE_SETUP_GUIDE.md.

## Performance
Link to PERFORMANCE_OPTIMIZATION.md.

## Contributing
How to contribute (branching, commits, PRs).

## Documentation
- ARCHITECTURE.md - System design
- IMPLEMENTATION_ROADMAP.md - Roadmap
- [Other docs...]

## License
License information.
```

## ARCHITECTURE.md Template

```markdown
# IRIS Architecture

## System Overview
[High-level diagram/description]

## Core Components
1. **Authentication**: Firebase Auth flow
2. **Timetable Management**: Parsing and storage
3. **Notifications**: Reminders and alerts
4. **Android Widgets**: Homescreen integration
5. **State Management**: Provider pattern

## Data Flow
[Sequence diagrams showing key flows]

## Tech Stack
- Frontend: Flutter/Dart
- Backend: Firestore, Firebase Auth
- Native: Kotlin (Android)

## Security
- Authentication: Firebase Auth
- Data: Firestore Security Rules
- Network: HTTPS, signed requests

## Performance
- Caching strategy
- Query optimization
- Memory management

## Deployment
- CI/CD pipeline
- Build process
- Release strategy
```

## IMPLEMENTATION_ROADMAP.md Template

```markdown
# Implementation Roadmap

## Current Phase: [Name]
**Duration**: [Dates]
**Status**: [In Progress/Completed/Planned]

### Features
- [ ] Feature A - [Status: In Progress/Done/Pending]
  - Task 1: [Description]
  - Task 2: [Description]
- [ ] Feature B
- [ ] Feature C

## Completed Phases
### Phase 1: Core Features
- [x] Authentication
- [x] Basic timetable display
- [x] Local storage

## Upcoming Phases
### Phase 2: Advanced Features
- [ ] PDF parsing
- [ ] Cloud sync
- [ ] Notifications

### Phase 3: Optimization
- [ ] Performance tuning
- [ ] UI polish
- [ ] Android widget

## Timeline
[Month/Quarter breakdown with expected features]

## Known Issues
- Issue 1: [Description] - ETA fix
- Issue 2: [Description] - Workaround available
```

## Documentation Update Checklist

### When Implementing New Feature
- [ ] Add dartdoc to all public APIs
- [ ] Update IMPLEMENTATION_ROADMAP.md with progress
- [ ] Add example code if applicable
- [ ] Update ARCHITECTURE.md if structure changes
- [ ] Add file-specific .instructions.md if needed
- [ ] Update README if feature affects setup
- [ ] Create integration test or usage example
- [ ] Link related docs from code comments

### When Making Breaking Changes
- [ ] Document migration path in comments
- [ ] Update all affected documentation
- [ ] Add deprecation notice with timeline
- [ ] Create upgrade guide if needed
- [ ] Note in FEATURES_TODO.md or changelog

### When Optimizing Performance
- [ ] Document optimization strategy
- [ ] Add benchmarks/measurements
- [ ] Update PERFORMANCE_OPTIMIZATION.md
- [ ] Note tradeoffs (complexity, maintainability)
- [ ] Add profiling instructions if needed

### When Fixing Bugs
- [ ] Document root cause in commit message
- [ ] Add comment linking to issue tracker
- [ ] Note workarounds if applicable
- [ ] Add test case to prevent regression
- [ ] Update docs if behavior changes

## Code Example Documentation

### Include Real Examples
```dart
/// Example: Fetching and displaying timetable
/// 
/// The typical flow is:
/// 1. User opens app → TimetableScreen widget
/// 2. TimetableScreen watches timetableProvider
/// 3. Provider fetches from TimetableService
/// 4. Service queries Firestore
/// 5. Data flows back and UI updates
///
/// ```dart
/// @override
/// Widget build(BuildContext context, WidgetRef ref) {
///   final timetableAsync = ref.watch(timetableProvider);
///   
///   return timetableAsync.when(
///     data: (timetable) => TimetableWidget(timetable: timetable),
///     loading: () => const Loading(),
///     error: (err, st) => ErrorWidget(error: err),
///   );
/// }
/// ```
```

## In-Code Documentation Standards

### File Header
```dart
/// IRIS Timetable Service
///
/// This service manages all timetable operations including:
/// - Fetching timetables from Firestore
/// - Parsing PDF timetables
/// - Caching locally for offline access
/// - Synchronizing with server
///
/// Security: Requires authentication.
/// Performance: Locally caches results, queries indexed in Firestore.
library timetable_service;

// Implementation...
```

### Class Documentation
```dart
/// Represents a single class/course in the timetable.
///
/// A [Class] contains all relevant information about a scheduled
/// class session, including timing, location, and instructor.
///
/// The [startTime] and [endTime] are in local timezone.
/// Location is queried from building/room database at display time.
///
/// Serializable to/from Firestore via [toJson]/[fromJson].
@JsonSerializable()
class Class {
  // Properties...
}
```

### Method Documentation
```dart
/// Updates the user's class reminder settings.
///
/// [classId] - ID of the class to configure
/// [minutesBefore] - How many minutes before class to notify (0 to disable)
///
/// Returns the updated [ClassReminder] configuration.
/// 
/// Throws [AuthException] if user not authenticated.
/// Throws [FirestoreException] if update fails.
///
/// Example:
/// ```dart
/// await reminderService.updateReminder('class123', minutesBefore: 30);
/// ```
Future<ClassReminder> updateReminder(
  String classId,
  {required int minutesBefore}
) async {
  // Implementation...
}
```

## Sync Documentation with Code

### Automation Tools
```bash
# Generate dartdoc locally
dart doc

# Check coverage
dart pub global activate dartdoc_coverage
dartdoc_coverage --no-fatal-warnings

# Generate markdown from code
# (Manual process or use custom scripts)
```

### Regular Audits
- Monthly: Check README for staleness
- Per feature: Verify dartdoc accuracy
- Per quarter: Audit ARCHITECTURE.md
- Per release: Update IMPLEMENTATION_ROADMAP.md

## Documentation Anti-Patterns

### ❌ Avoid These

1. **Outdated comments**: "This was slow" (without context)
2. **Misleading comments**: "Always returns a list" (when sometimes null)
3. **Redundant comments**: `var count = 0; // Set count to 0`
4. **Dead code with docs**: Commented code with explanations (use git history)
5. **Separated docs**: Docs in files that don't link to code
6. **Vague examples**: "Like this:" followed by incomplete code

### ✅ Do These Instead

1. **Contextual comments**: "Was slow due to N+1 queries, now cached"
2. **Accurate types**: Document actual behavior with edge cases
3. **Why comments**: Explain intent, not implementation
4. **Version control**: Use git history, remove commented code
5. **Linked docs**: Every code comment should point to docs
6. **Complete examples**: Full, runnable code samples

## Tools & Scripts

### Generate Documentation Summary
```bash
# Find all public APIs without dartdoc
grep -r "^[[:space:]]*\(class\|function\|Future\|Stream\)" lib/ | grep -v "///"

# Generate dartdoc
dart doc lib/ --output docs/
```

### Update Docs Checklist Script
```bash
#!/bin/bash
# Remind to update docs during code review
echo "📋 Documentation Checklist:"
echo "[ ] README updated if needed"
echo "[ ] Dartdoc added to public APIs"
echo "[ ] ARCHITECTURE.md updated if structure changed"
echo "[ ] IMPLEMENTATION_ROADMAP.md progress updated"
echo "[ ] Comments explain WHY, not WHAT"
echo "[ ] Related docs linked in comments"
```

## Documentation Review Criteria

When reviewing PRs, verify:
- [ ] All public functions have dartdoc comments
- [ ] Comments explain intent and usage
- [ ] Code examples are complete and accurate
- [ ] Architecture docs reflect changes
- [ ] Roadmap/TODO items updated
- [ ] No contradictions between code and docs
- [ ] Links between related docs work
- [ ] Examples can be copy-pasted and work
