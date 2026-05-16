---
description: "Use when working on service files. Focus on error handling, documentation, and testability."
applyTo: "lib/services/**/*.dart"
---

# Service Development Instructions

## Requirements for Service Files

Every service file must:

1. **Use dependency injection**
   ```dart
   class StudentService {
     final FirebaseFirestore _firestore;
     
     StudentService(this._firestore);
   }
   ```

2. **Have comprehensive dartdoc**
   ```dart
   /// Service for managing timetable operations.
   ///
   /// Handles:
   /// - Fetching timetables from Firestore
   /// - Parsing PDF timetables  
   /// - Caching locally for offline access
   ///
   /// Security: Requires authentication
   /// Performance: Uses local caching
   class TimetableService {
   }
   ```

3. **Handle errors with typed exceptions**
   ```dart
   Future<List<Class>> getClasses() async {
     try {
       return await _firestore.collection('classes').get()
         .then((snap) => snap.docs.map((doc) => Class.fromJson(doc.data())).toList());
     } catch (e) {
       throw FirestoreException('Failed to fetch classes: $e');
     }
   }
   ```

4. **Be fully testable**
   - Accept dependencies in constructor (no singletons)
   - No `print()` statements, use logging
   - Return typed data, not `dynamic`

5. **Document complex operations**
   ```dart
   /// Syncs timetable changes with Firestore.
   ///
   /// Algorithm:
   /// 1. Get local changes since last sync
   /// 2. Send updates to Firestore in batch
   /// 3. Merge remote changes with local data
   /// 4. Update local cache
   ///
   /// Returns [SyncResult] with statistics.
   /// Throws [SyncException] on failure.
   Future<SyncResult> syncTimetable() async {
   }
   ```

## Service Checklist

- [ ] Constructor accepts all dependencies
- [ ] Dartdoc comment explains purpose
- [ ] All public methods documented
- [ ] Custom exceptions for error handling
- [ ] No global state or singletons
- [ ] Unit tests exist
- [ ] Performance implications noted in docs
- [ ] Security requirements documented
- [ ] Firestore queries optimized
- [ ] Memory leaks prevented (streams cleaned up)

## Service Patterns

### Caching Pattern
```dart
class CachedTimetableService {
  final TimetableService _service;
  Map<String, Timetable> _cache = {};
  
  Future<Timetable> getTimetable(String id) async {
    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }
    
    final timetable = await _service.getTimetable(id);
    _cache[id] = timetable;
    return timetable;
  }
  
  void invalidateCache(String id) {
    _cache.remove(id);
  }
}
```

### Error Handling Pattern
```dart
class StudentService {
  Future<Student> getStudent(String id) async {
    try {
      final doc = await _firestore.collection('students').doc(id).get();
      if (!doc.exists) {
        throw StudentException('Student not found', code: 'NOT_FOUND');
      }
      return Student.fromJson(doc.data()!);
    } on FirebaseException catch (e) {
      throw StudentException('Firestore error: ${e.message}', code: e.code);
    } catch (e) {
      throw StudentException('Unexpected error: $e', code: 'UNKNOWN');
    }
  }
}
```

### Provider Setup
```dart
// Define the service provider
final studentServiceProvider = Provider((ref) => 
  StudentService(FirebaseFirestore.instance));

// Use in other providers
final studentProvider = FutureProvider<Student>((ref) {
  final service = ref.watch(studentServiceProvider);
  return service.getStudent('current_user_id');
});
```

## Testing Requirements

```dart
// test/services/student_service_test.dart

test('getStudent returns student when exists', () async {
  final mockFirestore = MockFirebaseFirestore();
  final service = StudentService(mockFirestore);
  
  // Mock Firestore response
  // Call service
  // Verify result
});

test('getStudent throws StudentException when not found', () async {
  final service = StudentService(mockFirestore);
  
  expect(
    () => service.getStudent('nonexistent'),
    throwsA(isA<StudentException>()),
  );
});
```
