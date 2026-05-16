---
name: dart-backend-agent
description: "Specialized agent for Dart business logic, service layer, models, state management, and utilities. Use when: implementing services, creating data models, handling state with Provider, writing utility functions, parsing data, or managing application logic."
applyTo: "lib/(services|models|providers|utils)/**/*.dart"
---

# Dart Backend Development Agent

## Responsibilities

You specialize in Dart backend logic for IRIS. Focus on:
- Service layer design (Firebase, parsing, data processing)
- Data model creation and serialization
- State management with Provider
- Utility functions and extensions
- Error handling and logging
- Business logic implementation

## Service Architecture

### Service Pattern
```dart
class StudentService {
  final FirebaseFirestore _firestore;
  
  StudentService(this._firestore);
  
  Future<List<Student>> getStudents() async {
    try {
      final snapshot = await _firestore.collection('students').get();
      return snapshot.docs.map((doc) => Student.fromJson(doc.data())).toList();
    } catch (e) {
      // Log error, return empty or rethrow
      throw StudentServiceException('Failed to fetch students: $e');
    }
  }
}
```

### Provider Setup
```dart
final studentServiceProvider = Provider((ref) => StudentService(FirebaseFirestore.instance));

final studentsProvider = FutureProvider((ref) async {
  final service = ref.watch(studentServiceProvider);
  return service.getStudents();
});
```

## Data Models Best Practices

### Serialization Pattern
```dart
@JsonSerializable()
class Student {
  final String id;
  final String name;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) => 
    _$StudentFromJson(json);
  
  Map<String, dynamic> toJson() => _$StudentToJson(this);
}
```

### Firestore Models
- Add `@JsonSerializable()` for auto-serialization
- Include `createdAt` and `updatedAt` timestamps
- Use `DocumentReference` for relationships
- Document field structure in comments

## Error Handling

```dart
class ServiceException implements Exception {
  final String message;
  final String? code;
  
  ServiceException(this.message, {this.code});
  
  @override
  String toString() => message;
}

// Specific exceptions
class AuthException extends ServiceException {}
class FirestoreException extends ServiceException {}
class ParseException extends ServiceException {}
```

## Utilities & Extensions

### Common Extensions
```dart
extension StringExtensions on String {
  bool get isValidEmail => RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  String get capitalized => '${this[0].toUpperCase()}${substring(1)}';
}

extension DateTimeExtensions on DateTime {
  bool get isToday => DateTime.now().difference(this).inDays == 0;
  String get formattedDate => DateFormat('MMM d, yyyy').format(this);
}
```

## Testing Requirements

- Unit test all services: `test/services/`
- Mock Firestore for service tests
- Test model serialization/deserialization
- Test error scenarios and edge cases
- Aim for >80% code coverage in services

## Integration Checklist

- [ ] Service is properly documented with dartdoc
- [ ] Error handling covers all failure scenarios
- [ ] Models serialize/deserialize correctly
- [ ] Firestore queries are efficient (indexed if needed)
- [ ] Services use dependency injection
- [ ] Unit tests cover main paths and edge cases
- [ ] Logging includes actionable information
- [ ] Type safety: use proper types, avoid dynamic

## Key Patterns

1. **Repository Pattern**: Service acts as data gateway
2. **Dependency Injection**: Inject dependencies, don't create them
3. **Error Wrapping**: Wrap platform errors in domain exceptions
4. **Logging**: Use consistent logging for debugging
5. **Testing**: Every service method should be testable

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Firestore queries slow | Add composite indexes, use pagination |
| Model serialization fails | Verify `json_serializable` annotation, run `build_runner` |
| Provider state not updating | Check that StateNotifier correctly notifies listeners |
| Memory leaks in services | Ensure resources (streams, timers) are properly cleaned up |
| Race conditions | Use proper async/await, consider Future caching |
