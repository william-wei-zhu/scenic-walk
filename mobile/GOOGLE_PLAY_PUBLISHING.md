# Google Play Store Publishing Checklist

## Prerequisites (Completed)
- [x] Google Play Developer Account registered
- [x] $25 registration fee paid
- [x] Identity verification completed
- [x] Upload signing key created (`upload-keystore.jks`)
- [x] Release app bundle built (`app-release.aab`)

## Google Play Console Setup

### 1. Create New App
- [ ] Go to https://play.google.com/console
- [ ] Click "Create app"
- [ ] App name: `Scenic Walk`
- [ ] Default language: English (United States)
- [ ] App type: App
- [ ] Free or paid: Free
- [ ] Accept declarations and create

### 2. Complete Dashboard Checklist

#### App Content
- [ ] **App access**: Select "All functionality is available without special access"
- [ ] **Ads declaration**: Select whether app contains ads (likely "No")
- [ ] **Content rating**: Complete the IARC questionnaire
- [ ] **Target audience**: Select age groups (recommend 13+)
- [ ] **News app**: Select "No"
- [ ] **COVID-19 apps**: Select "No"
- [ ] **Data safety**: Declare data collection practices
  - Location data is collected for broadcasting
  - Data is shared with other users (event participants)
- [ ] **Government apps**: Select "No"

#### Store Listing (Grow → Store presence → Main store listing)
- [ ] **App icon**: 512x512 PNG (high-res)
- [ ] **Feature graphic**: 1024x500 PNG
- [ ] **Screenshots**: At least 2 phone screenshots (16:9 or 9:16)
- [ ] **Short description** (max 80 chars):
  ```
  Broadcast your live location to walking event participants in real-time.
  ```
- [ ] **Full description** (max 4000 chars):
  ```
  Scenic Walk helps walking event organizers share their live GPS location
  with participants. Create events, draw routes, and broadcast your position
  so participants always know where you are.

  Features:
  • Real-time GPS location broadcasting
  • Background location updates (keeps working when app is minimized)
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
- [ ] **Privacy Policy URL**: Required (see section below)

### 3. Privacy Policy

You need a privacy policy URL. Create one that covers:
- [ ] Location data collection and usage
- [ ] How data is shared with event participants
- [ ] Data retention policy
- [ ] Contact information

Host it on your website or use a free service like:
- GitHub Pages
- Google Sites
- Notion (public page)

### 4. Upload Release

1. [ ] Go to "Release" → "Production" (or start with "Internal testing")
2. [ ] Click "Create new release"
3. [ ] Upload `build/app/outputs/bundle/release/app-release.aab`
4. [ ] Add release notes:
   ```
   Initial release of Scenic Walk organizer app.

   Features:
   - Create and manage walking events
   - Real-time GPS location broadcasting
   - Background location updates
   - Event sharing with participants
   ```
5. [ ] Review and start rollout

### 5. Background Location Permission (Special Review)

Your app uses `ACCESS_BACKGROUND_LOCATION` which requires additional review:

- [ ] Navigate to "Policy" → "App content" → "Sensitive app permissions"
- [ ] Select "Location permissions"
- [ ] Provide justification for background location access:
  ```
  Background location is required so event organizers can broadcast their
  GPS position to participants even when the app is minimized. This is the
  core functionality of the app - allowing walking event participants to
  track the organizer's location in real-time.
  ```
- [ ] Upload a short video demonstrating the feature (optional but recommended)

**Note**: Apps requesting background location undergo additional review and may take longer to approve.

## After Submission

- [ ] Monitor review status in Play Console
- [ ] Respond to any policy issues or requests from Google
- [ ] Once approved, app will be live on Google Play Store

## App Bundle Location

```
/Users/williamzhu/Desktop/github/working-folder/scenic-walk/mobile/build/app/outputs/bundle/release/app-release.aab
```

## Important Files (Do NOT commit to git)

These files are in `.gitignore` and must stay local:
- `android/upload-keystore.jks` - Your signing key
- `android/key.properties` - Keystore passwords
- `android/app/google-services.json` - Firebase config
