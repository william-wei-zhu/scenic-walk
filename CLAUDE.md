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
- **Route Line**: Green (#16a34a) on map

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

### Mobile App Map Features
- **Create Event Screen**: Interactive map for drawing routes by tapping
  - "My Location" button to center on current position
  - Zoom in/out controls
  - Route polyline (green) with start (green) and end (red) markers
- **Event Detail Screen**: Map showing route + organizer location
  - Custom orange flag marker with walking emoji (🚶) for organizer
  - "Center on Organizer" button
  - "Show All" button to fit route + organizer in view
  - Zoom in/out controls
  - Live location updates from Firebase

### Mobile App API Keys
- **Google Maps**: Configured via `android/local.properties` (gitignored)
  - Requires "Maps SDK for Android" enabled
  - Add both debug and release SHA-1 fingerprints for API key restrictions
- **Firebase**: `google-services.json` in `android/app/`

### Mobile App Production URL
Share links use `https://scenic-walk.com` (configured in `lib/config/app_config.dart`)
