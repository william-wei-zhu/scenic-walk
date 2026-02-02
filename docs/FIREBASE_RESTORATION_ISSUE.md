# Firebase Project Restoration Issue

## Status: RESOLVED - Migrated to New Firebase Project

**Date Identified:** February 1, 2026
**Date Resolved:** February 1, 2026
**Original Project ID:** `scenic-walk-6cde3` (corrupted)
**New Project ID:** `scenic-walk-484001` (active)

## Problem Summary

After the Firebase project `scenic-walk-6cde3` was accidentally deleted and then restored via Google Cloud Console, the **Realtime Database** service was non-functional. The Firebase Realtime Database Management API returned a "Project has been deleted" error even though the project itself was active.

## Resolution

Instead of waiting for Firebase support to fix the corrupted project, we migrated to a new Firebase setup on the existing GCP project `scenic-walk-484001` (which also hosts the frontend deployment).

### Migration Steps Performed

1. **Added Firebase to existing GCP project:**
   ```bash
   firebase projects:addfirebase scenic-walk-484001
   ```

2. **Created Realtime Database instance:**
   ```bash
   # Via REST API with type: DEFAULT_DATABASE
   POST https://firebasedatabase.googleapis.com/v1beta/projects/scenic-walk-484001/locations/us-central1/instances?databaseId=scenic-walk-484001-default-rtdb
   ```

3. **Registered apps:**
   ```bash
   firebase apps:create WEB "scenic-walk-web" --project scenic-walk-484001
   firebase apps:create IOS "scenic-walk-ios" --bundle-id com.scenicwalk.scenicWalk --project scenic-walk-484001
   firebase apps:create ANDROID "scenic-walk-android" --package-name com.scenicwalk.scenic_walk --project scenic-walk-484001
   ```

4. **Updated configuration files:**
   - `/web/.env`
   - `/mobile/ios/Runner/GoogleService-Info.plist`
   - `/mobile/android/app/google-services.json`

5. **Applied security rules** via REST API

## New Configuration

| Parameter | Value |
|-----------|-------|
| Project ID | `scenic-walk-484001` |
| Project Number | `918419602814` |
| Database URL | `https://scenic-walk-484001-default-rtdb.firebaseio.com` |
| iOS Bundle ID | `com.scenicwalk.scenicWalk` |
| Android Package | `com.scenicwalk.scenic_walk` |

### App IDs
| Platform | App ID |
|----------|--------|
| Web | `1:918419602814:web:03e4031b311ff6cc49472f` |
| iOS | `1:918419602814:ios:392db5f292aad78c49472f` |
| Android | `1:918419602814:android:29d9099009de266d49472f` |

## Deployment Status

### Web App
- ✅ Updated `.env` file with new Firebase config
- ✅ Deployed via CI/CD with GitHub Secrets

### iOS App (App Store)
- ✅ Updated `GoogleService-Info.plist`
- ✅ Version 1.0.12 (build 14) submitted for App Store review on Feb 1, 2026

### Android App (Google Play)
- ✅ Updated `google-services.json`
- ✅ Version 1.0.12 (build 14) uploaded to Google Play

## Original Issue Details (For Reference)

### Error
```
FIREBASE WARNING: Firebase error. Please ensure that you have the URL of your
Firebase Realtime Database instance configured correctly.
(https://scenic-walk-6cde3-default-rtdb.firebaseio.com/)
```

### API Response
```json
{
  "error": {
    "code": 404,
    "message": "Project has been deleted.",
    "status": "NOT_FOUND"
  }
}
```

### Root Cause
When a Firebase project is restored from deletion:
1. The Google Cloud project container is restored (works correctly)
2. Individual Firebase services need to re-activate (partially working)
3. **Realtime Database metadata was corrupted** - the service still believed the project was deleted

## Lessons Learned

1. **Firebase project restoration is unreliable** - Realtime Database metadata can become corrupted
2. **Keep GCP and Firebase aligned** - Using the same project for hosting and Firebase simplifies management
3. **Enable automated backups** for Realtime Database before going to production
4. **Consider using Firestore** instead of Realtime Database for better restoration support
5. **Document recovery procedures** for Firebase services

## Updates

- **2026-02-01 (morning):** Issue identified, investigation completed, support ticket filed for `scenic-walk-6cde3`
- **2026-02-01 (afternoon):** Migrated to new Firebase setup on `scenic-walk-484001`, all config files updated
- **2026-02-01 (evening):** iOS v1.0.12 submitted for App Store review, Android v1.0.12 uploaded to Google Play, web app deployed

## TODO

- [ ] **2026-02-08:** Delete old Firebase project `scenic-walk-6cde3` after confirming all apps work correctly
