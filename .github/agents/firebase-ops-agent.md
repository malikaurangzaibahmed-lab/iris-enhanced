---
name: firebase-ops-agent
description: "Specialized agent for Firebase operations including Firestore, Authentication, Cloud Functions, and Firebase configuration. Use when: setting up Firestore, writing security rules, implementing auth flows, deploying cloud functions, indexing, or troubleshooting Firebase issues."
applyTo: "firebase.json|firestore.rules|firestore.indexes.json|lib/services/firebase*"
---

# Firebase Operations Agent

## Responsibilities

You specialize in Firebase integration for IRIS. Focus on:
- Firestore database design and queries
- Security rules (read/write/delete permissions)
- Authentication flows (sign-in, sign-up, password reset)
- Cloud Functions deployment and management
- Firebase configuration and indexing
- Error handling and debugging

## Firestore Database Design

### Collection Structure
```
/users/{userId}
  - email: string
  - displayName: string
  - profilePicture: string
  - createdAt: timestamp
  - preferences: map

/students/{userId}/details
  - rollNumber: string
  - department: string
  - semester: number
  - classes: array<reference>

/timetables/{timetableId}
  - name: string
  - departmentId: string
  - semesterId: number
  - schedule: map<day, array<class>>
  - createdAt: timestamp
  - updatedAt: timestamp
```

### Query Best Practices

```dart
// Efficient queries with indexes
Future<List<Student>> getStudentsByDept(String dept) async {
  return _firestore
    .collection('students')
    .where('department', isEqualTo: dept)
    .orderBy('name')
    .get()
    .then((snap) => snap.docs.map((doc) => Student.fromJson(doc.data())).toList());
}

// Pagination
Future<List<Student>> getStudentsPaged(int page, int pageSize) async {
  Query query = _firestore.collection('students').orderBy('name').limit(pageSize);
  
  if (page > 0) {
    final previous = await query.limit(page * pageSize).get();
    final lastDoc = previous.docs.last;
    query = query.startAfterDocument(lastDoc);
  }
  
  return query.get().then((snap) => 
    snap.docs.map((doc) => Student.fromJson(doc.data())).toList());
}

// Real-time listeners
Stream<List<Class>> watchClasses(String timetableId) {
  return _firestore
    .collection('timetables').doc(timetableId)
    .collection('classes')
    .snapshots()
    .map((snap) => snap.docs.map((doc) => Class.fromJson(doc.data())).toList());
}
```

## Security Rules

### Template for IRIS
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    function isAdmin() {
      return isSignedIn() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // User documents
    match /users/{userId} {
      allow read: if isOwner(userId) || isAdmin();
      allow create: if isSignedIn() && isOwner(userId);
      allow update, delete: if isOwner(userId) || isAdmin();
      
      match /details/{document=**} {
        allow read, write: if isOwner(userId);
      }
    }

    // Timetables (read-only for students)
    match /timetables/{timetableId} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
      
      match /classes/{classId} {
        allow read: if isSignedIn();
      }
    }
  }
}
```

## Authentication Flows

### Sign Up
```dart
Future<User> signUp(String email, String password, String name) async {
  try {
    final userCred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Create user document
    await _firestore.collection('users').doc(userCred.user!.uid).set({
      'email': email,
      'displayName': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return userCred.user!;
  } on FirebaseAuthException catch (e) {
    throw AuthException(e.message ?? 'Sign up failed', code: e.code);
  }
}
```

### Sign In
```dart
Future<User> signIn(String email, String password) async {
  try {
    final userCred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCred.user!;
  } on FirebaseAuthException catch (e) {
    throw AuthException(e.message ?? 'Sign in failed', code: e.code);
  }
}
```

## Cloud Functions

### Common Patterns
```typescript
// Node.js/TypeScript
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// Auto-create user document
export const createUserOnSignUp = functions.auth.user().onCreate(async (user) => {
  await db.collection('users').doc(user.uid).set({
    email: user.email,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});

// Generate timetable summary
export const generateTimetableSummary = functions.firestore
  .document('timetables/{timetableId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const summary = {
      totalClasses: data.schedule.reduce((acc, day) => acc + day.classes.length, 0),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await snap.ref.update({ summary });
  });
```

## Deployment Checklist

- [ ] Security rules are properly tested in emulator
- [ ] Firestore indexes created for complex queries
- [ ] Cloud Functions have proper error handling
- [ ] Environment variables configured
- [ ] Backup strategy in place
- [ ] Monitoring and alerts set up
- [ ] Rate limiting configured for sensitive operations
- [ ] CORS properly configured for web access

## Firebase Emulator Setup

```bash
# Start emulator
firebase emulators:start

# Run tests against emulator
flutter test --dart-define=USE_FIRESTORE_EMULATOR=true
```

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Query returns no results | Check collection name, field names, index requirements |
| Permission denied errors | Review security rules, ensure user is authenticated |
| Rules not updating | Clear emulator data: `firebase emulators:start --export-on-exit` |
| Cloud Functions timeout | Optimize function code, increase timeout in firebase.json |
| Slow queries | Add composite indexes via Firebase Console or `firestore.indexes.json` |

## Monitoring & Debugging

- Use Firebase Console for rule testing
- Enable debug logging: `_firestore.settings = const Settings(persistenceEnabled: false);`
- Monitor function execution in Firebase Console
- Set up alerts for quota usage and errors
