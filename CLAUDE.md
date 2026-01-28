# CLAUDE.md

## Project Overview

Scenic Walk is an open-source (AGPL-3.0) community walking events app with live GPS location sharing. Organizers create events with drawn routes and broadcast their real-time location to participants.

## Repository Structure (Monorepo)

```
scenic-walk/
├── web/                    # React web app (participants + organizers)
│   ├── src/
│   ├── package.json
│   └── ...
├── mobile/                 # Flutter app (organizers only)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   └── services/
│   ├── android/
│   └── pubspec.yaml
├── .github/workflows/
│   ├── deploy-web.yml      # Web app CI/CD
│   └── build-android.yml   # Android APK CI/CD
├── CLAUDE.md
├── README.md
└── LICENSE
```

## Web App Development

```bash
cd web
npm install
npm run dev      # Start dev server on http://localhost:3000
npm run build    # Build for production (outputs to dist/)
npm run preview  # Preview production build
npm run lint     # Run ESLint
```

## Architecture

### Tech Stack (Web)
- React 19 + TypeScript + Vite
- Tailwind CSS (dark mode via class strategy)
- Firebase Realtime Database (shared with mobile app)
- Google Maps JavaScript API with Advanced Markers

### Tech Stack (Mobile)
- Flutter 3.32+ (Android, iOS coming later)
- Firebase Realtime Database (same as web)
- Android Foreground Service for background location
- Key packages: `geolocator`, `flutter_background_service`, `permission_handler`

### Design System
- **Primary Color**: Green (`green-600` / #16a34a) - nature-inspired theme
- **Font**: Nunito (rounded, friendly style matching the hiking goat logo)
- **Logo**: Cute hiking goat mascot with backpack
- **Route Line**: Green (#16a34a) on map with directional arrows

### Routing (Hash-based)
Routes are handled manually in `src/App.tsx` using `window.location.hash`:
- `/#/` → HomePage (event list + create button)
- `/#/create` → CreateWalkEvent (draw route, set name/PIN)
- `/#/:eventId` → WalkEventView (participant view)
- `/#/:eventId?organizer=true` → WalkEventView (organizer view with PIN)

### Web App Structure
```
web/
├── src/
│   ├── components/
│   │   ├── CreateWalkEvent.tsx     # Event creation with route drawing + PIN
│   │   ├── WalkEventView.tsx       # Main event view (participant/organizer)
│   │   ├── WalkMapComponent.tsx    # Google Maps with markers + polylines
│   │   ├── LocationBroadcaster.tsx # GPS broadcast controls
│   │   ├── OrganizerPinModal.tsx   # PIN entry modal
│   │   ├── Toast.tsx               # Toast notifications + useToast hook
│   │   └── LoadingSpinner.tsx      # Loading indicator
│   ├── hooks/
│   │   ├── useGeolocation.ts       # Browser Geolocation API wrapper
│   │   └── useLiveLocation.ts      # Firebase location subscription
│   ├── services/
│   │   ├── firebase.ts             # Firebase config + CRUD operations
│   │   └── organizerStorage.ts     # localStorage for organizer's events
│   └── types/
│       └── index.ts                # TypeScript interfaces
├── Dockerfile
├── nginx.conf
└── package.json
```

### Mobile App Structure
```
mobile/
├── lib/
│   ├── main.dart                    # App entry, Firebase init, theme
│   ├── config/
│   │   └── app_config.dart          # App configuration (URLs, colors)
│   ├── screens/
│   │   ├── home_screen.dart         # Event list, navigation
│   │   ├── create_event_screen.dart # Create event with route drawing on map
│   │   ├── add_event_screen.dart    # Enter event ID + PIN
│   │   └── event_detail_screen.dart # Map view + broadcast controls
│   └── services/
│       ├── firebase_service.dart    # Firebase read/write + live location stream
│       ├── storage_service.dart     # SharedPreferences for events
│       ├── location_service.dart    # Foreground location + permissions
│       └── background_service.dart  # Background location service
├── android/
│   ├── app/
│   │   ├── build.gradle.kts
│   │   ├── google-services.json     # Firebase config
│   │   └── src/main/AndroidManifest.xml
│   ├── local.properties             # API keys (gitignored)
│   └── build.gradle.kts
└── pubspec.yaml
```

### Firebase Data Structure
```
├── events/{eventId}/
│   ├── id: string
│   ├── name: string
│   ├── createdAt: number (timestamp)
│   ├── organizerPin: string (4 digits)
│   ├── route: [{lat, lng}, ...]
│   ├── status: 'active' | 'ended'
│   └── broadcastMode: 'continuous' | 'manual'
└── locations/{eventId}/
    ├── lat: number
    ├── lng: number
    ├── timestamp: number
    └── accuracy?: number
```

## Environment Variables

Required in `web/.env`:
```
VITE_FIREBASE_API_KEY=
VITE_FIREBASE_AUTH_DOMAIN=
VITE_FIREBASE_PROJECT_ID=
VITE_FIREBASE_STORAGE_BUCKET=
VITE_FIREBASE_MESSAGING_SENDER_ID=
VITE_FIREBASE_APP_ID=
VITE_FIREBASE_DATABASE_URL=
VITE_GOOGLE_MAPS_API_KEY=
VITE_GOOGLE_MAPS_MAP_ID=
```

### Google Maps Setup
1. Create API key at https://console.cloud.google.com/apis/credentials
2. Enable Maps JavaScript API for the key
3. Create Map ID at https://console.cloud.google.com/google/maps-apis/studio/maps
   - Choose **JavaScript** as map type
   - Choose **Vector** (recommended)
   - Disable tilt/rotation for simpler UX
4. Add allowed referrers to API key (e.g., `http://localhost:*`, your production domain)

## Deployment

### Web App (Cloud Run)

**CI/CD via GitHub Actions** - Pushing changes to `web/` automatically deploys to Google Cloud Run.

- Project ID: `scenic-walk-484001`
- Region: `us-west1`
- Service: `scenic-walk`
- Workflow: `.github/workflows/deploy-web.yml`

**Manual Deployment:**
```bash
cd web
gcloud run deploy scenic-walk \
  --source . \
  --region us-west1 \
  --project scenic-walk-484001 \
  --allow-unauthenticated
```

**View Logs:**
```bash
gcloud run services logs read scenic-walk --region us-west1 --project scenic-walk-484001 --limit 50
```

### Mobile App (Android)

**CI/CD via GitHub Actions** - Pushing changes to `mobile/` triggers APK build.

- Workflow: `.github/workflows/build-android.yml`
- APK artifact uploaded to GitHub Actions
- Release APK attached to GitHub releases when tagged

**Local Development:**
```bash
cd mobile
flutter pub get
flutter run              # Run on connected device/emulator
flutter build apk        # Build debug APK
flutter build apk --release  # Build release APK
```

**Requirements:**
- Flutter 3.32+
- Java 17
- Android SDK 35+

**APK Location:** `mobile/build/app/outputs/flutter-apk/app-release.apk`

## Key Patterns

### Google Maps Loading
Maps API loaded via script tag in `App.tsx` with callback to `window.initMap`. Components check `window.google?.maps` before rendering.

### Dark Mode
Toggle stored in localStorage (`scenic-walk-dark-mode`). Applied via `document.documentElement.classList.add('dark')`.

### My Events (Organizer Persistence)
Organizers can return to their events after closing the browser:
- Events saved to localStorage (`scenic-walk-organizer-events`) after creation
- Homepage shows "My Events" list with status badges (Active/Ended)
- Clicking an event auto-verifies PIN (skips modal) using stored PIN
- Events are device-specific (not synced across devices)
- **Delete button** (trash icon) permanently deletes event from database with confirmation

```typescript
// organizerStorage.ts
interface SavedEvent {
  id: string;
  name: string;
  pin: string;      // For auto-verification
  createdAt: number;
}

getOrganizerEvents(): SavedEvent[]
saveOrganizerEvent(event: SavedEvent): void
removeOrganizerEvent(eventId: string): void
getStoredPin(eventId: string): string | null
```

### Event Deletion
- **Permanent deletion**: Organizers can delete events from the database (not just remove from local list)
- **Delete button**: Red trash icon on event cards (replaces the old X button)
- **Confirmation dialog**: Simple "Are you sure?" prompt (no PIN required)
- **Deletes both**: Event data and associated location data from Firebase
- **Available on**: Both web and mobile apps

### Location Broadcasting
- **Continuous mode**: Auto-updates location every ~10 seconds while broadcasting
- **Manual mode** (On-Demand): Single location update per button press
- Uses `navigator.geolocation.watchPosition()` in useGeolocation hook

### Toast Notifications
```tsx
import { Toast, useToast } from './Toast';
const { toast, showToast, hideToast } = useToast();
showToast('Link copied!', 'success'); // types: 'success' | 'error' | 'info'
```

### Status Indicators (Colorblind-Accessible)
All status indicators use icons + text labels alongside colors:
- Active: ✓ green icon + "Active" label
- Stale: ⏱ amber icon + "Stale" label
- Waiting: ○ gray icon + "Waiting" label
- Broadcasting: 📡 animated pulse icon

### Form Patterns
- Minimal forms: Name + PIN + Create (no confirmation, no mode selection)
- Broadcast mode defaults to continuous (no user choice needed)

### Layout
- Maps use full-width layout (no max-w constraints)
- Mobile map height: 65vh, Desktop: flex-1
- Homepage: Logo + tagline + CTA button + My Events list (if any)

### Route Directional Arrows
Both web and mobile display directional arrows along walking routes to show walking direction:
- **Base spacing**: 150 meters between arrows
- **Minimum arrows**: 3 (for short routes)
- **Maximum arrows**: 20 (for long routes)
- **First arrow offset**: 30% of first interval
- **Visual style**: Green (#16a34a) filled chevron with white outline

**Web implementation**: Uses Google Maps polyline `icons` property with `FORWARD_CLOSED_ARROW` symbol
**Mobile implementation**: Custom arrow markers created with Canvas, cached by rotation (rounded to 10°)

### Mobile App Map Features
- **Create Event Screen**: Interactive map for drawing routes by tapping
  - "My Location" button to center on current position
  - Zoom in/out controls
  - Route polyline (green) with start (green) and end (red) markers
  - Directional arrows showing walking direction (updates as route is drawn)
- **Event Detail Screen**: Map showing route + organizer location (55% screen height)
  - Custom orange flag marker with walking emoji (🚶) for organizer
  - "Center on Organizer" button
  - "Show All" button to fit route + organizer in view
  - Zoom in/out controls
  - Live location updates from Firebase
  - Broadcasting status indicator overlay
  - Organizer marker hidden when not broadcasting (privacy protection)
  - Directional arrows along route
  - Large "Share Event Link" button below broadcasting controls

### Mobile App Accessibility
- **Large Font Sizes**: All text uses minimum 20-24px for readability
  - Body text: 24px
  - Labels and secondary text: 20px
  - Button text: 24px with 80px minimum button height
  - Status badges: 20px with icons

### Mobile App API Keys
- **Google Maps**: Configured via `android/local.properties` (gitignored)
  - Requires "Maps SDK for Android" enabled
  - Add these SHA-1 fingerprints to API key restrictions:
    - Debug: `66:F8:64:8D:40:B9:F3:D9:85:FC:AC:67:33:5F:DC:2B:19:E4:CF:BB`
    - Release (upload key): `19:26:93:0D:C6:C2:DF:C7:A5:35:D0:64:B2:72:89:4E:F3:1B:7C:59`
    - Google Play signing: `28:FA:B5:8E:D7:79:19:17:DB:DE:5E:59:B0:6F:3A:0C:BB:A0:48:B1`
- **Firebase**: `google-services.json` in `android/app/`

### Google Play Store
- **Package name**: `com.scenicwalk.scenic_walk`
- **App signing**: Google Play re-signs the app; get SHA-1 from Play Console → Setup → App integrity
- **Store assets**: `mobile/store_assets/`
- **Privacy policy**: `PRIVACY_POLICY.md` (also at repo root)

### Mobile App Production URL
Share links use `https://scenic-walk.com` (configured in `lib/config/app_config.dart`)
