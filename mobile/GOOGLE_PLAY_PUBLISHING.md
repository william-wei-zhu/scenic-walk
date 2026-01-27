# Google Play Store Publishing Checklist

## Prerequisites (Completed)
- [x] Google Play Developer Account registered
- [x] $25 registration fee paid
- [x] Identity verification completed
- [x] Upload signing key created (`upload-keystore.jks`)
- [x] Release app bundle built (`app-release.aab`)

## Google Play Console Setup

### 1. Create New App
- [x] Go to https://play.google.com/console
- [x] Click "Create app"
- [x] App name: `Scenic Walk`
- [x] Default language: English (United States)
- [x] App type: App
- [x] Free or paid: Free
- [x] Accept declarations and create

### 2. Complete Dashboard Checklist

#### App Content
- [x] **App access**: Select "All functionality is available without special access"
- [x] **Ads declaration**: Select "No" (app does not contain ads)
- [x] **Advertising ID**: Select "No" (AD_ID permission removed from manifest)
- [x] **Content rating**: Complete the IARC questionnaire
- [x] **Target audience**: Select age groups (13+)
- [x] **News app**: Select "No"
- [x] **COVID-19 apps**: Select "No"
- [x] **Data safety**: Declare data collection practices
  - Location data is collected for broadcasting
  - Data is shared with other users (event participants)
- [x] **Government apps**: Select "No"

#### Store Listing (Grow → Store presence → Main store listing)
- [x] **App icon**: 512x512 PNG (high-res)
- [x] **Feature graphic**: 1024x500 PNG
- [x] **Screenshots**: At least 2 phone screenshots (16:9 or 9:16)
- [x] **Short description** (max 80 chars):
  ```
  Broadcast your live location to walking event participants in real-time.
  ```
- [x] **Full description** (max 4000 chars):
  ```
  Scenic Walk helps walking event organizers share their live GPS location
  with participants. Create events, draw routes, and broadcast your position
  so participants always know where you are.

  Features:
  • Real-time GPS location broadcasting
  • Background location updates (keeps working when app is minimized)
  • Directional arrows on routes showing walking direction
  • Create and manage multiple walking events
  • Share event links with participants
  • Works offline with automatic sync when back online

  Perfect for:
  • Group hikes and nature walks
  • City walking tours
  • Charity walks and fundraisers
  • School field trips
  • Any group outdoor activity

  Participants can follow along using the Scenic Walk web app - no download
  required for them!
  ```
- [x] **Privacy Policy URL**: Required (see section below)

### 3. Privacy Policy

You need a privacy policy URL. Create one that covers:
- [x] Location data collection and usage
- [x] How data is shared with event participants
- [x] Data retention policy
- [x] Contact information

Privacy policy is hosted and linked in the app listing.

### 4. Upload Release

1. [x] Go to "Release" → "Production" (or start with "Internal testing")
2. [x] Click "Create new release"
3. [x] Upload `build/app/outputs/bundle/release/app-release.aab`
4. [x] Add release notes
5. [x] Review and start rollout

### 5. Background Location Permission (Special Review)

Your app uses `ACCESS_BACKGROUND_LOCATION` which requires additional review:

- [x] Navigate to "Policy" → "App content" → "Sensitive app permissions"
- [x] Select "Location permissions"
- [x] Describe app purpose (max 500 chars):
  ```
  Scenic Walk helps organize group walking events with live GPS location sharing.
  Organizers create events by drawing walking routes on a map, then share a link
  with participants. During the walk, organizers broadcast their real-time location
  so participants can see where the group is and follow along. This is useful for
  guided tours, group hikes, and community walks where participants need to locate
  and stay with the organizer.
  ```
- [x] Describe background location feature (max 500 chars):
  ```
  Live Location Broadcasting: When an organizer starts broadcasting, their GPS
  location is continuously shared with all event participants. Background location
  access is required so broadcasting continues when the organizer's phone screen
  is locked or the app is minimized during the walk. Without background access,
  location updates would stop whenever the organizer checks another app or pockets
  their phone, causing participants to lose track of the group.
  ```
- [x] Provide YouTube video demonstrating the feature:
  - Video URL: https://www.youtube.com/watch?v=B1Pnah-UrSE
  - Video must show:
    1. Prominent disclosure before permission request
    2. The permission request flow
    3. The feature working in background

### 6. Foreground Service Permission

Your app uses `FOREGROUND_SERVICE_LOCATION` permission:

- [x] Select tasks that require this permission:
  - [x] Background location updates
  - [x] User-initiated location sharing
- [x] Provide the same YouTube video demonstrating the feature

**Note**: Apps requesting background location undergo additional review and may take longer to approve.

## After Submission

- [x] App submitted for review
- [ ] Monitor review status in Play Console
- [ ] Respond to any policy issues or requests from Google
- [ ] Once approved, app will be live on Google Play Store

## Current Version

- **Version**: 1.0.6+8
- **Features**: Directional arrows on routes, background location broadcasting

## App Bundle Location

```
mobile/build/app/outputs/bundle/release/app-release.aab
```

## Important Files (Do NOT commit to git)

These files are in `.gitignore` and must stay local:
- `android/upload-keystore.jks` - Your signing key
- `android/key.properties` - Keystore passwords

## Files That ARE Committed

- `android/app/google-services.json` - Firebase config (safe to be public, protected by Firebase rules)
