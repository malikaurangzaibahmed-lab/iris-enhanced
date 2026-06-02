# OTA Timetable Updates - Quick Implementation Guide

## What You Get

Push timetable updates to users **without rebuilding the APK**. When a new timetable arrives:
1. Parse it locally with your Python script
2. Upload JSON file to public URL
3. App automatically downloads on next startup
4. Users see updated schedule instantly ✅

---

## Fastest Setup (5 Minutes)

### Step 1: Choose Hosting
Pick one - all are free:
- **GitHub** (easiest for beginners)
- **Firebase Storage** (production-ready)
- **Simple HTTP server** (your own infrastructure)

### Step 2: Update Code
Add to `lib/main.dart` in `main()` function:

```dart
import 'package:iris/services/timetable_ota_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Add this line:
  await TimetableOTAService.initializeOTA();
  
  runApp(const MyApp());
}
```

### Step 3: Configure URL
Edit `lib/services/timetable_ota_service.dart` line 18:

```dart
// Pick ONE option:

// Option 1: GitHub
static const String TIMETABLE_URL = 
  'https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/timetable_seed.json';

// Option 2: Firebase Storage
static const String TIMETABLE_URL = 
  'https://firebasestorage.googleapis.com/v0/b/YOUR-PROJECT.appspot.com/o/timetable_seed.json?alt=media';

// Option 3: Your Server
static const String TIMETABLE_URL = 
  'https://your-domain.com/api/timetable_seed.json';
```

### Step 4: Deploy Timetable
```bash
# Generate new timetable
python tools/process_pdf_registry.py

# Deploy (choose one)
# Option 1: GitHub
git add assets/timetable_seed.json
git commit -m "Update timetable"
git push

# Option 2: Firebase Storage
gsutil cp assets/timetable_seed.json gs://your-bucket/

# Option 3: Your Server
scp assets/timetable_seed.json user@server:/var/www/api/
```

**Done!** Users get the update on next app restart. 🎉

---

## Add "Refresh" Button in Settings

```dart
// In your settings screen
ElevatedButton.icon(
  icon: const Icon(Icons.refresh),
  label: const Text('Check for Timetable Updates'),
  onPressed: () async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Checking for updates...'),
            ],
          ),
        ),
      );
      
      final hasUpdate = await TimetableOTAService.isUpdateAvailable();
      
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      
      if (hasUpdate) {
        await TimetableOTAService.downloadTimetableUpdate();
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Timetable updated! Please restart the app.'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Timetable is already up-to-date'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  },
)
```

---

## GitHub Setup (Easiest)

1. Create public GitHub repo (or use existing)
2. Make sure `main` branch is your default
3. Add `timetable_seed.json` to root or folder
4. Update URL in code:
   ```dart
   static const String TIMETABLE_URL = 
     'https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/timetable_seed.json';
   ```
5. To update: Push new file
   ```bash
   git add timetable_seed.json
   git commit -m "Update timetable: $(date +%Y-%m-%d)"
   git push
   ```

That's it! No infrastructure needed.

---

## Firebase Storage Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Storage**
4. Update rules to allow public read:
   ```
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /{allPaths=**}/timetable*.json {
         allow read: if true;
       }
     }
   }
   ```
5. Upload `timetable_seed.json`
6. Copy file URL and use in code

---

## How It Works

### Behind the Scenes
```
App Starts
    ↓
Check metadata.json for version
    ↓
Compare with local version
    ↓
If newer available: Download timetable_seed.json
    ↓
Cache locally with SharedPreferences
    ↓
On next data load: Use cached version
    ↓
User sees updated schedule ✅
```

### Rate Limiting
- Checks once per **24 hours** (saves bandwidth)
- Can force refresh with button
- Uses cached version if download fails (offline-safe)

---

## Troubleshooting

**Q: Update not appearing?**
- Check URL is correct and accessible
- Look at logs: `TimetableOTAService`
- Try force refresh button

**Q: App crashes on update?**
- JSON validation failed - check format
- SharedPreferences issue - clear app data

**Q: How to rollback?**
- Upload previous `timetable_seed.json`
- Increment version number in metadata
- App will re-download on next check

---

## Advanced: Automatic CI/CD

Use GitHub Actions to auto-deploy:

```yaml
# .github/workflows/deploy-timetable.yml
name: Deploy Timetable

on:
  push:
    paths:
      - 'assets/CS-12*.pdf'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      
      - name: Parse PDF
        run: python tools/process_pdf_registry.py
      
      - name: Deploy to GitHub
        run: |
          git config user.name "Bot"
          git config user.email "bot@example.com"
          git add assets/timetable_seed.json
          git commit -m "Auto-update timetable"
          git push
```

Then just push new PDF → Auto-deployed to users! 🚀

---

## Summary

✅ **Zero backend required** (GitHub/Firebase)
✅ **Automatic on app startup**
✅ **No rebuild needed**
✅ **Offline fallback**
✅ **Rate-limited (24h)**
✅ **Takes 5 minutes to setup**

Users get instant updates whenever timetable changes! 🎉
