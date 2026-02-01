# Firebase Project Restoration Issue

## Status: Pending Firebase Support Response

**Date Identified:** February 1, 2026
**Support Ticket Filed:** February 1, 2026
**Project ID:** `scenic-walk-6cde3`
**Project Number:** `399286268646`

## Problem Summary

After the Firebase project `scenic-walk-6cde3` was accidentally deleted and then restored via Google Cloud Console, the **Realtime Database** service is non-functional. The Firebase Realtime Database Management API returns a "Project has been deleted" error even though the project itself is active.

## Error Details

**User-facing Error (Web App):**
```
FIREBASE WARNING: Firebase error. Please ensure that you have the URL of your
Firebase Realtime Database instance configured correctly.
(https://scenic-walk-6cde3-default-rtdb.firebaseio.com/)
```

**API-level Error:**
```json
{
  "error": {
    "code": 404,
    "message": "Project has been deleted.",
    "status": "NOT_FOUND"
  }
}
```

**API Endpoint:**
```
GET https://firebasedatabase.googleapis.com/v1beta/projects/scenic-walk-6cde3/locations/-/instances
```

## Investigation Results

| Check | Result |
|-------|--------|
| Google Cloud Project Status | ACTIVE |
| Firebase project visible in `firebase projects:list` | Yes |
| Firebase APIs enabled | All enabled |
| `gcloud services enable firebasedatabase.googleapis.com` | Succeeded |
| `firebase database:instances:list` | Failed (404) |
| `firebase database:instances:create` | Failed (404) |
| Firebase Console "Create Database" button | JavaScript error |

### Console Error (Firebase Console UI)
When attempting to create a Realtime Database via the Firebase Console:
```
An error has occurred
Cannot read properties of undefined (reading '0')
```

## Root Cause

When a Firebase project is restored from deletion:
1. The Google Cloud project container is restored (works correctly)
2. Individual Firebase services need to re-activate (partially working)
3. **Realtime Database metadata is corrupted** - the service still believes the project is deleted

This is a known issue where Firebase service-level metadata can become inconsistent after project restoration.

## Impact

- **Web App:** Cannot connect to Realtime Database, events cannot be created or viewed
- **iOS App:** Cannot fetch or create events (App Store version affected)
- **Android App:** Cannot fetch or create events

## Resolution Path

### Option 1: Wait for Firebase Support (CHOSEN)
Firebase support ticket has been filed requesting they repair the Realtime Database service metadata.

**Information provided to support:**
- Project ID: `scenic-walk-6cde3`
- Project Number: `399286268646`
- API response showing 404 "Project has been deleted" error
- Evidence that project is ACTIVE in Google Cloud

**Expected timeline:** 1-3 business days for initial response

### Option 2: Create New Firebase Project (NOT CHOSEN)
Creating a new project would require:
- New Firebase configuration files
- Update web `.env` file
- Update iOS `GoogleService-Info.plist` (requires App Store resubmission)
- Update Android `google-services.json`

**Reason not chosen:** iOS app was just approved for App Store. Creating a new project would require resubmitting the app for review.

## Configuration Files (For Reference)

These files contain the Firebase configuration that should work once the project is fixed:

| Platform | File | Database URL |
|----------|------|--------------|
| Web | `/web/.env` | `https://scenic-walk-6cde3-default-rtdb.firebaseio.com` |
| iOS | `/mobile/ios/Runner/GoogleService-Info.plist` | `https://scenic-walk-6cde3-default-rtdb.firebaseio.com` |
| Android | `/mobile/android/app/google-services.json` | `https://scenic-walk-6cde3-default-rtdb.firebaseio.com` |

## Once Firebase Support Resolves the Issue

1. **Re-create Realtime Database:**
   ```bash
   firebase database:instances:create scenic-walk-6cde3-default-rtdb \
     --project scenic-walk-6cde3 \
     --location us-central1
   ```
   Or use Firebase Console: Build > Realtime Database > Create Database

2. **Apply Security Rules:**
   - Go to Firebase Console > Realtime Database > Rules
   - Copy rules from `/docs/FIREBASE_SECURITY_RULES.md`
   - Click Publish

3. **Test Connectivity:**
   ```bash
   cd /Users/williamzhu/Desktop/working-folder/scenic-walk/web
   npm run dev
   ```
   - Verify no Firebase errors in browser console
   - Test creating an event

4. **Update this document** with resolution details

## Lessons Learned

1. **Enable automated backups** for Realtime Database before going to production
2. **Document recovery procedures** for Firebase services
3. **Consider using Firestore** instead of Realtime Database for better restoration support
4. **Test project restoration** in a staging environment before relying on it for production

## Updates

- **2026-02-01:** Issue identified, investigation completed, support ticket filed
