---
name: iris-architecture
description: "Guide to IRIS project architecture, data flow, and design patterns. Use when: understanding how components interact, learning the overall structure, planning new features that affect architecture, or documenting system design."
---

# IRIS Architecture Guide

## System Overview

IRIS is a comprehensive student organizer built with Flutter and Dart, featuring intelligent timetable management, PDF parsing, and cloud synchronization.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│         Flutter UI Layer (Screens & Widgets)        │
├─────────────────────────────────────────────────────┤
│  State Management Layer (Provider Pattern)          │
├─────────────────────────────────────────────────────┤
│    Service Layer (Firebase, Parsing, Utils)         │
├─────────────────────────────────────────────────────┤
│     Data Access Layer (Firestore, Local Storage)    │
├─────────────────────────────────────────────────────┤
│   Android Native Layer (Widgets, Platform Channels) │
└─────────────────────────────────────────────────────┘
```

## Directory Structure

```
lib/
├── main.dart                    # App entry point
├── screens/                     # UI screens
│   ├── dashboard_screen.dart
│   ├── timetable_screen.dart
│   ├── settings_screen.dart
│   └── ...
├── widgets/                     # Reusable UI components
│   ├── timetable_widget.dart
│   ├── class_card.dart
│   └── ...
├── services/                    # Business logic & external integrations
│   ├── firebase_service.dart
│   ├── pdf_parser_service.dart
│   ├── timetable_service.dart
│   └── notification_service.dart
├── models/                      # Data models & entities
│   ├── student.dart
│   ├── class.dart
│   ├── timetable.dart
│   └── user.dart
├── providers/                   # State management
│   ├── student_provider.dart
│   ├── timetable_provider.dart
│   └── auth_provider.dart
├── utils/                       # Helpers & utilities
│   ├── constants.dart
│   ├── extensions.dart
│   ├── validators.dart
│   └── formatters.dart
├── themes/                      # UI theming
│   ├── app_theme.dart
│   └── colors.dart
└── config/                      # Configuration
    ├── firebase_config.dart
    └── env_config.dart
```

## Data Flow Architecture

### Typical User Action Flow

```
User Action (Tap Button)
    ↓
UI Event (onPressed callback)
    ↓
Provider notifies change
    ↓
Service layer processes business logic
    ↓
Firestore/Local storage update
    ↓
Provider updates state
    ↓
UI rebuilds with new data
```

### Example: Fetching Timetable

```dart
// 1. UI layer
TimetableScreen
  ├─ watches: timetableProvider
  └─ calls: ref.refresh(timetableProvider)

// 2. Provider layer
timetableProvider = FutureProvider
  └─ calls: timetableService.getTimetable()

// 3. Service layer
TimetableService
  ├─ queries: Firestore
  └─ caches: local storage

// 4. Data layer
Firestore
  └─ returns: Timetable documents
```

## Core Components

### 1. Authentication & Users
- **Flow**: Sign up → Firestore user doc → Provider auth state
- **Services**: AuthService (handles Firebase Auth)
- **Providers**: authProvider (current user), isAuthenticatedProvider
- **Models**: User, AuthCredentials

### 2. Timetable Management
- **Flow**: Parse PDF → Firestore timetable → Cache locally
- **Services**: TimetableService (Firestore ops), PDFParserService (parsing)
- **Providers**: timetableProvider, selectedDayProvider
- **Models**: Timetable, Class, TimeSlot
- **Storage**: Firestore (source of truth), SharedPreferences (cache)

### 3. Notifications & Reminders
- **Flow**: Class scheduled → Firebase notification → Local notification
- **Services**: NotificationService, ReminderService
- **Integration**: Firebase Cloud Messaging (FCM), flutter_local_notifications
- **Models**: Reminder, Notification

### 4. Android Widgets
- **Flow**: Update timetable → Service notifies Android → Widget updates
- **Implementation**: AppWidget + BroadcastReceiver
- **Communication**: MethodChannel (Flutter ↔ Android)
- **Data**: SharedPreferences (widget data cache)

## State Management Strategy

### Provider Pattern Rules

1. **For simple state**: Use `StateNotifier<T>`
   ```dart
   final selectedDayProvider = StateNotifierProvider((ref) => 
     StateNotifier<String>('Monday'));
   ```

2. **For async data**: Use `FutureProvider<T>` or `StreamProvider<T>`
   ```dart
   final timetableProvider = FutureProvider<Timetable>((ref) async =>
     ref.watch(timetableServiceProvider).getTimetable());
   ```

3. **For computed values**: Use `Provider<T>`
   ```dart
   final todaysClassesProvider = Provider<List<Class>>((ref) {
     final timetable = ref.watch(timetableProvider);
     return timetable.value?.getClassesForDay('Monday') ?? [];
   });
   ```

### Dependency Injection

```dart
// Services
final timetableServiceProvider = Provider((ref) => 
  TimetableService(FirebaseFirestore.instance));

// Used in other providers
final timetableProvider = FutureProvider((ref) =>
  ref.watch(timetableServiceProvider).getTimetable());
```

## Error Handling Strategy

### Exception Hierarchy
```
Exception
├── ServiceException (base for service errors)
│   ├── AuthException
│   ├── FirestoreException
│   ├── ParseException
│   └── NotificationException
└── UIException (for display errors)
```

### Error Propagation
- Services throw specific exceptions
- Providers catch and optionally wrap exceptions
- UI displays user-friendly error messages

```dart
final timetableProvider = FutureProvider<Timetable>((ref) async {
  try {
    return await ref.watch(timetableServiceProvider).getTimetable();
  } catch (e) {
    // Log, potentially transform error
    rethrow; // Let UI handle display
  }
});
```

## Performance Considerations

### Memory Management
- Use `const` constructors for widgets
- Cache timetable data locally
- Limit Firestore listeners (use onetime reads when possible)
- Clean up streams in dispose methods

### Query Optimization
- Use composite indexes for complex queries
- Implement pagination for large lists
- Filter before mapping/sorting
- Avoid fetching entire collections

### UI Optimization
- Use `ListView.builder` for dynamic lists
- Implement `shouldRebuild` in inherited widgets
- Use `RepaintBoundary` for expensive animations
- Profile with DevTools before optimizing

## Integration Points

### Firestore Integration
```
Firestore Collections:
- users/{userId} → User profile, preferences
- students/{userId}/details → Student info
- timetables/{timetableId} → Timetable data
- classes/{classId} → Class information
```

### Firebase Auth
```
Auth Flow:
- Sign Up → Create user → Create Firestore doc
- Sign In → Update last login
- Sign Out → Clear local cache
- Password Reset → Email verification
```

### Android Platform Channel
```
Channel: com.iris.native/widget
Methods:
- updateWidget(data) → Update homescreen widget
- getWidgetData() → Fetch current widget data
```

## Deployment Strategy

### Build Variants
- **Debug**: Full logging, slower builds, code not optimized
- **Release**: Optimized, ProGuard enabled, size split per ABI

### Version Management
- Follow semantic versioning (MAJOR.MINOR.PATCH)
- Update pubspec.yaml before each release
- Tag releases in git

### Rollout Process
- Test on Firebase Emulator
- Internal testing on physical devices
- Beta release to limited users
- Monitor crash/error rates
- Full release when stable

## Testing Architecture

### Test Pyramid
```
                  /\
                 /  \  E2E Tests (Integration)
                /────\
               /      \  Widget Tests
              /────────\
             /          \  Unit Tests
            /────────────\
```

### Test Locations
- `test/` - Unit tests for services, models, utils
- `test/widget/` - Widget tests for UI components
- `integration_test/` - End-to-end scenarios
- Firebase Emulator - Firestore/Auth testing

## Documentation Requirements

### Code Documentation
- Add dartdoc comments to public APIs
- Document complex algorithms
- Include usage examples for services
- Keep README updated with setup steps

### Architecture Documentation
- Update ARCHITECTURE.md when structure changes
- Maintain dependency diagrams
- Document design decisions in ADR format

## Key Principles

1. **Separation of Concerns**: UI, business logic, data access layers
2. **Single Responsibility**: Each service/widget has one purpose
3. **Dependency Injection**: Pass dependencies, don't create them
4. **Error Transparency**: Clear error messages and logging
5. **Performance First**: Profile before optimizing
6. **Testing Critical Paths**: Essential features have tests
7. **Documentation as Code**: Keep docs in sync with code
