# OTA Timetable Update System Setup Guide

## Quick Start (Choose One)

### Option 1: Firebase Storage (Recommended - FREE)
**Best for:** Reliable, scalable, no backend needed

#### Setup:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create/select your project
3. Go to **Storage**
4. Update security rules:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**}/timetable*.json {
      allow read: if true;  // Public read access
    }
  }
}
```

5. Upload `timetable_seed.json` to root of storage
6. Copy the file URL and update in `timetable_ota_service.dart`:
```dart
static const String TIMETABLE_URL = 
  'https://firebasestorage.googleapis.com/v0/b/YOUR-PROJECT.appspot.com/o/timetable_seed.json?alt=media';
```

---

### Option 2: GitHub (FREE & Simple)
**Best for:** Open source projects, easy CI/CD integration

#### Setup:
1. Create a public GitHub repo
2. Add `timetable_seed.json` to main branch
3. Update URL in service:
```dart
static const String TIMETABLE_URL = 
  'https://raw.githubusercontent.com/sealevel/student-timetable/main/timetable_seed.json';
```

4. To update: Just push new JSON file to GitHub
   ```bash
   git add timetable_seed.json
   git commit -m "Update timetable"
   git push
   ```

---

### Option 3: Simple Cloud Function (Firebase)
**Best for:** Custom logic, metadata endpoints

#### Setup:
1. Go to Firebase Console → Cloud Functions
2. Create new function:

```python
from flask import Flask
from flask_cors import CORS
import json
from datetime import datetime

app = Flask(__name__)
CORS(app)

@app.route('/api/timetable_seed.json')
def get_timetable():
    with open('timetable_seed.json', 'r') as f:
        return f.read()

@app.route('/api/timetable_metadata.json')
def get_metadata():
    with open('timetable_seed.json', 'r') as f:
        data = json.load(f)
    
    return {
        'version': int(datetime.now().strftime('%Y%m%d')),
        'sessions': len(data.get('sessions', [])),
        'updated_at': datetime.now().isoformat(),
        'batches': len(set(s['batch'] for s in data.get('sessions', [])))
    }

if __name__ == '__main__':
    app.run()
```

---

## Integration in main.dart

Add to your app startup:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize OTA timetable updates
  await TimetableOTAService.initializeOTA();
  
  runApp(const MyApp());
}
```

Add "Refresh Timetable" button in settings:

```dart
ElevatedButton(
  onPressed: () async {
    final success = await TimetableOTAService.forceRefresh();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Timetable updated')),
      );
    }
  },
  child: const Text('Check for Timetable Updates'),
)
```

---

## Publishing Updates

### Using Python script (from your workflow):
```bash
# Update timetable
python tools/process_pdf_registry.py

# Deploy to Firebase Storage
gsutil cp assets/timetable_seed.json gs://your-project-bucket/

# Or deploy to GitHub
git add timetable_seed.json
git commit -m "Update timetable: $(date +%Y-%m-%d)"
git push
```

### Using curl:
```bash
# Upload to Firebase Storage
curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  --data-binary @timetable_seed.json \
  https://firebasestorage.googleapis.com/v0/b/your-project.appspot.com/o/timetable_seed.json?uploadType=media
```

---

## User Update Flow

1. **App starts** → OTA service checks for updates (once per day)
2. **Update available** → Downloads automatically in background
3. **Next restart** → App uses new timetable
4. **Manual check** → User taps "Refresh Timetable" button

---

## Benefits

✅ Push updates without app rebuild
✅ Instant delivery to all users
✅ Fallback to local version if download fails
✅ Rate-limited (once per day) to save bandwidth
✅ Works offline (uses cached version)
✅ Zero backend cost (Firebase/GitHub)

---

## Monitoring

Track which users have latest timetable:
- Add Firebase Analytics event: `timetable_updated`
- Log update checks: Already in `TimetableOTAService`
