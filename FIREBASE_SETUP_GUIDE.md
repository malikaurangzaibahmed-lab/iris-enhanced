# Firebase Storage Setup for OTA - Copy & Paste Guide

## Step-by-Step (Takes 10 Minutes)

### Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Name: `student-organizer`
4. Click Create

### Step 2: Enable Storage
1. Left sidebar → Storage
2. Click "Get Started"
3. Keep security rules as shown, click Next
4. Select location (nearest to you), click Done

### Step 3: Update Security Rules
1. Go to Storage → Rules tab
2. Replace everything with:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow public read access to timetable files
    match /{allPaths=**}/timetable*.json {
      allow read: if true;  // ← Public access
      allow write: if false; // ← No one can write
    }
    // Deny everything else
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

3. Click Publish
4. Wait for deploy ✅

### Step 4: Get Your Project Info
1. Go to Project Settings (⚙️ icon, top left)
2. Copy your **Project ID** (e.g., `student-organizer-abc123`)

### Step 5: Update Code in App
Edit `lib/services/timetable_ota_service.dart` line 18:

```dart
// Replace YOUR-PROJECT with your Firebase Project ID
static const String TIMETABLE_URL = 
  'https://firebasestorage.googleapis.com/v0/b/YOUR-PROJECT.appspot.com/o/timetable_seed.json?alt=media';
```

Example (if your project ID is `student-organizer-f4c2a`):
```dart
static const String TIMETABLE_URL = 
  'https://firebasestorage.googleapis.com/v0/b/student-organizer-f4c2a.appspot.com/o/timetable_seed.json?alt=media';
```

### Step 6: Upload Timetable
1. In Firebase Console → Storage
2. Click Upload file
3. Select `assets/timetable_seed.json`
4. Wait for upload ✅

### Step 7: Test in App
Add to `main.dart`:

```dart
import 'package:iris/services/timetable_ota_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Test OTA
  try {
    await TimetableOTAService.checkForUpdatesIfNeeded();
    print('✅ OTA initialized');
  } catch (e) {
    print('⚠️ OTA init warning: $e');
  }
  
  runApp(const MyApp());
}
```

### Step 8: Deploy to Users
Just rebuild APK:
```bash
flutter build apk --release
```

**Done!** ✅

---

## Deploying New Timetables

### When New PDF Arrives:
```bash
# 1. Parse it
python tools/process_pdf_registry.py

# 2. Upload to Firebase
#    Method A: Firebase Console (Web UI)
#      Go to Storage, delete old file, upload new one
#
#    Method B: gsutil CLI (advanced)
#      gsutil cp assets/timetable_seed.json gs://your-project-bucket/
```

### Option: Automate with GitHub Actions
Create `.github/workflows/deploy-timetable.yml`:

```yaml
name: Deploy Timetable to Firebase

on:
  push:
    paths:
      - 'assets/CS-12*.pdf'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      
      - name: Install dependencies
        run: pip install pdfplumber
      
      - name: Parse PDF
        run: python tools/process_pdf_registry.py
      
      - name: Deploy to Firebase
        run: |
          npm install -g firebase-tools
          firebase deploy --only storage --token ${{ secrets.FIREBASE_TOKEN }}
```

Then users get updated timetable automatically when you push PDF! 🚀

---

## Monitoring (Optional)

### See How Many Users Are Updating:
1. Firebase Console → Storage → Download analytics
2. Check bandwidth usage
3. Monitor file access patterns

### Set Up Alerts (Free):
Go to Project Settings → Notifications
Enable storage alerts

---

## Troubleshooting

### "URL returns 403 Forbidden"
- Check security rules are updated
- Make sure rules are published (blue loading bar complete)
- Wait 2-3 minutes for Firebase to deploy

### "Downloaded file is corrupted"
- Delete old file
- Re-upload `timetable_seed.json`
- Check file size matches (should be ~150KB)

### "App doesn't download update"
- Check network is working
- Look at console logs: `TimetableOTAService`
- Make sure URL is correct (copy-paste from Firebase)
- Check app has internet permission in AndroidManifest.xml

### "Firebase project won't create"
- Try different project name
- Check you're logged into correct Google account
- Enable billing (free tier should show up anyway)

---

## Cost Estimate

After setup, you pay ONLY if you exceed:
```
Free tier:
  - 1GB storage (plenty for JSON)
  - 1GB downloads/month

Breakdown for different user counts:
  
  100 users:      0 MB/month  → $0
  500 users:    450 MB/month  → $0
  1,000 users:  900 MB/month  → $0
  5,000 users: 4.5 GB/month   → $0.54
  10,000 users: 9 GB/month    → $0.96
```

The `.getActualDuration()` call in notifications keeps file small.

---

## Security Checklist

✅ Public read access (timetable is public anyway)
✅ Write disabled (only you can update via Console)
✅ No authentication required (simpler for users)
✅ HTTPS only (encrypted in transit)
✅ Automatic backups (Firebase handles it)

---

## Summary

```
┌──────────────────────────────────┐
│ Setup Time     : 10 minutes      │
│ Cost           : FREE tier       │
│ Users Supported: 500+ for free   │
│ Scalability    : 10,000+ with $$ │
│ Reliability    : 99.99% uptime   │
│ Maintenance    : ~0 hours/month  │
└──────────────────────────────────┘
```

You're all set! 🎉 Users will get timetable updates automatically.
