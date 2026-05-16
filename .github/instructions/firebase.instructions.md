---
description: "Use when modifying Firestore rules, indexes, or Firebase configuration. Ensure security and performance."
applyTo: "firestore.rules|firestore.indexes.json|firebase.json|lib/services/firebase*"
---

# Firebase Configuration Instructions

## Firestore Security Rules

### Requirements

1. **Every rule must be tested**
   - Write security rule tests in `test/firestore_rules_test.dart`
   - Test both allowed and denied cases
   - Test edge cases (null values, missing fields)

2. **Documentation in rules**
   ```firestore
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Helper functions with documentation
       
       /// Returns true if user is authenticated
       function isSignedIn() {
         return request.auth != null;
       }
       
       /// Returns true if user is the document owner
       function isOwner(userId) {
         return isSignedIn() && request.auth.uid == userId;
       }
       
       /// Returns true if user is admin
       function isAdmin() {
         return isSignedIn() && 
           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
       }
       
       // Collection rules
       match /users/{userId} {
         // Only user can read own profile
         allow read: if isOwner(userId);
         // Only user can write own profile
         allow write: if isOwner(userId) || isAdmin();
       }
     }
   }
   ```

3. **Rules must be audit-safe**
   - No overly permissive rules (avoid `allow read: if true`)
   - Document why each rule exists
   - Consider data sensitivity

### Common Patterns

```firestore
// Public read, authenticated write
match /timetables/{timetableId} {
  allow read: if true;
  allow write: if request.auth != null;
}

// Owner only
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}

// Admin only
match /admin/{document=**} {
  allow read, write: if isAdmin();
}

// Public read, admin write
match /courses/{courseId} {
  allow read: if true;
  allow write: if isAdmin();
}
```

## Firestore Indexes

### Requirements

1. **Complex queries need indexes**
   ```json
   // firestore.indexes.json
   {
     "indexes": [
       {
         "collectionGroup": "classes",
         "queryScope": "Collection",
         "fields": [
           {"fieldPath": "timetableId", "order": "ASCENDING"},
           {"fieldPath": "startTime", "order": "ASCENDING"}
         ]
       }
     ]
   }
   ```

2. **Document index requirement**
   ```dart
   /// Gets classes for a timetable, ordered by start time.
   /// 
   /// REQUIRES: Composite index in Firestore:
   /// - timetableId: ASCENDING
   /// - startTime: ASCENDING
   /// 
   /// See firestore.indexes.json
   Future<List<Class>> getClassesForTimetable(String timetableId) async {
     return _firestore.collection('classes')
       .where('timetableId', isEqualTo: timetableId)
       .orderBy('startTime')
       .get()
       .then((snap) => snap.docs.map((doc) => Class.fromJson(doc.data())).toList());
   }
   ```

3. **Verify in Firebase Console**
   - After deploying, check Firestore Console
   - Ensure indexes show "Enabled" status
   - Monitor query performance

## Firebase Configuration (firebase.json)

```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*"],
    "redirects": [],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  },
  "functions": {
    "source": "functions",
    "runtime": "nodejs18"
  }
}
```

## Cloud Functions Deployment

### Requirements

1. **Document all functions**
   ```typescript
   /**
    * Creates a user document when new user signs up.
    * Triggered: Firebase Auth onCreate
    * Side effects: Creates /users/{uid} document
    */
   export const createUserOnSignUp = functions.auth.user().onCreate(async (user) => {
     // Implementation
   });
   ```

2. **Error handling in functions**
   ```typescript
   export const updateTimetable = functions.firestore
     .document('timetables/{timetableId}')
     .onUpdate(async (change, context) => {
       try {
         const after = change.after.data();
         // Validate before updating
         if (!after.departmentId) {
           throw new Error('departmentId required');
         }
         // Update operation
       } catch (error) {
         console.error('Error updating timetable:', error);
         // Send alert or notify admin
         throw error;
       }
     });
   ```

3. **Test locally before deploying**
   ```bash
   firebase emulators:start
   # In another terminal
   firebase deploy --only functions
   ```

## Deployment Checklist

- [ ] All security rules tested
- [ ] Complex queries have corresponding indexes
- [ ] firestore.indexes.json updated
- [ ] firebase.json reviewed for accuracy
- [ ] Cloud Functions have proper error handling
- [ ] Environment variables set in Firebase Console
- [ ] Rate limiting configured if needed
- [ ] Monitoring/alerts set up
- [ ] Backup strategy documented
- [ ] Rules follow least-privilege principle

## Testing Security Rules

```dart
// test/firestore_rules_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  group('Firestore Security Rules', () {
    test('User can read own profile', () async {
      // Create user
      // Verify read succeeds
    });
    
    test('User cannot read other profiles', () async {
      // Create other user
      // Verify read fails
    });
    
    test('Unauthenticated user cannot write', () async {
      // Attempt write without auth
      // Verify fails
    });
  });
}
```

## Performance & Security Audit

Run periodically (monthly):
- [ ] Review security rules for over-permissions
- [ ] Analyze Firestore query patterns
- [ ] Check for missing indexes
- [ ] Monitor function cold start times
- [ ] Review user quota consumption
- [ ] Check for security vulnerabilities (OWASP Top 10)
