# In-App Update System Setup Guide

## Overview
The app checks for updates from a public GitHub repository (`iris-updates`) every time Dashboard loads. This keeps your main codebase private while distributing versioned APKs publicly.

---

## Step 1: GitHub Repository Structure

Clone or set up your `iris-updates` repo with this structure:

```
iris-updates/
├── update.json          (version info & changelog)
├── releases/            (folder or GitHub releases)
└── README.md
```

---

## Step 2: Create `update.json`

Push this file to the **main** branch:

```json
{
  "version": "1.1.0",
  "changelog": "- Fixed widget dark mode toggle\n- Improved temporal insight display\n- Performance optimizations",
  "apk_url": "https://github.com/malikaurangzaibahmed-lab/iris-updates/releases/download/v1.1.0/app-release.apk",
  "required": false
}
```

**Fields:**
- `version`: Semantic versioning (e.g., `1.0.0`)
- `changelog`: What's new (supports `\n` for line breaks)
- `apk_url`: Direct link to APK file (use GitHub releases download link)
- `required`: Set to `true` to force update (user can't skip)

---

## Step 3: Upload APK to Releases

1. Go to GitHub → iris-updates repo → **Releases** tab
2. Click **Create a new release**
3. Tag: `v1.1.0` (match `update.json` version)
4. Attach the APK: `app-release.apk`
5. Publish release
6. Copy the download link from the release assets

---

## Step 4: Update `update.json`

Replace the `apk_url` in `update.json` with the actual release download link:

```
https://github.com/malikaurangzaibahmed-lab/iris-updates/releases/download/v1.1.0/app-release.apk
```

Commit and push to `main` branch.

---

## Step 5: Version Bump in Main App

Update `pubspec.yaml` in your main project:

```yaml
version: 1.1.0+2  # major.minor.patch+buildNumber
```

This ensures `PackageInfo.fromPlatform().version` matches what UpdateService reads.

---

## How It Works

1. **App Startup** → Dashboard `initState` calls `UpdateService.checkForUpdates()`
2. **Fetch** → Gets `update.json` from GitHub raw content URL
3. **Compare** → Parses version numbers and compares with local app version
4. **Dialog** → If remote > local, shows update dialog with changelog
5. **Download** → User taps "Update Now" → APK downloads to app documents folder
6. **Install** → System intent opens APK installer
7. **User Confirms** → System handles installation (app restarts on next launch)

---

## URL Reference

The app fetches from:
```
https://raw.githubusercontent.com/malikaurangzaibahmed-lab/iris-updates/main/update.json
```

Keep this URL in sync with your GitHub username and repository name.

---

## Testing Locally (Optional)

To test without GitHub:

1. Modify `UpdateService._updateJsonUrl` to point to a local server or test URL
2. Create a mock `update.json` response
3. Run app and trigger Dashboard

---

## Security Notes

✅ **Advantages:**
- Main code repo stays private
- Only versioned APKs distributed publicly
- Easy rollback (just revert `update.json` version)
- Users always see changelog before updating

⚠️ **Considerations:**
- APK downloads are unencrypted (HTTPS only)
- Users can manually skip updates (unless `required: true`)
- Private repo protects source code, not APK binaries

---

## Creating New Updates

**Each time you release:**

1. Build release APK: `flutter build apk --release`
2. Bump version in `pubspec.yaml`
3. Upload APK to GitHub release
4. Update `update.json` with new version, changelog, APK URL
5. Commit and push to iris-updates `main` branch

Next app launch will detect and offer the new version.
