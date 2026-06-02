# IRIS Project Copilot Instructions

You are helping develop **IRIS**, a comprehensive Flutter/Dart student organizer application with advanced features including:
- PDF parsing and timetable extraction
- Firestore integration with Firebase Auth
- Custom Android homescreen widgets
- Performance optimization and liquid glass UI effects
- Sound feedback systems

## Core Principles

1. **Multi-platform Focus**: Always consider Flutter (iOS/Android), Web, and potentially desktop implications
2. **User Experience**: Prioritize smooth animations, sound feedback, and intuitive navigation
3. **Data Integrity**: Handle Firestore operations carefully with proper error handling
4. **Performance**: Minimize rebuilds, optimize asset loading, consider battery/memory constraints
5. **Testing**: Every significant feature should be testable and include test cases

## Project Structure

```
lib/
  screens/          # UI screens and pages
  widgets/          # Reusable UI components
  services/         # Firebase, parsing, data services
  models/           # Data models and entities
  providers/        # State management (likely Provider pattern)
  utils/            # Helpers, extensions, constants
  themes/           # UI theming
```

## Key Technologies

- **Frontend**: Flutter/Dart
- **Backend**: Firestore, Firebase Auth, Cloud Functions
- **Native**: Kotlin (Android widgets)
- **Data Processing**: Python (PDF parsing, batch analysis)
- **State Management**: Provider pattern likely

## Common Tasks

### When working with Flutter widgets:
- Use responsive design principles
- Consider dark/light theme support
- Test with various screen sizes
- Follow Material Design guidelines

### When integrating Firebase:
- Write proper Firestore security rules
- Handle auth errors gracefully
- Optimize queries (indexes for complex queries)
- Use proper error handling and retry logic

### When optimizing performance:
- Profile before optimizing
- Consider lazy loading for lists
- Minimize widget rebuilds
- Use const constructors where possible

### When updating documentation:
- Keep README.md current with setup steps
- Document Firebase schema in comments
- Maintain ARCHITECTURE.md with high-level design
- Update FEATURES_TODO.md as work progresses

## Use Specialized Agents

For better results, use these domain-specific agents:
- **/flutter-ui** - For widget development and UI work
- **/dart-backend** - For service layer, models, and business logic
- **/firebase-ops** - For Firestore, Auth, and cloud functions
- **/android-native** - For Kotlin integration and widgets

## Documentation First

Always consider documentation as part of the implementation:
- Update relevant docs when making architectural changes
- Keep IMPLEMENTATION_ROADMAP.md in sync
- Document complex algorithms (e.g., PDF parsing logic)
- Add code comments for non-obvious decisions
