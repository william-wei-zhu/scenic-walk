# CLAUDE.md

## Project Overview

Scenic Walk is an open-source (AGPL-3.0) community walking events app with live GPS location sharing. Organizers create events with drawn routes and broadcast their real-time location to participants.

## Development Commands

```bash
npm run dev      # Start dev server on http://localhost:3000
npm run build    # Build for production (outputs to dist/)
npm run preview  # Preview production build
npm run lint     # Run ESLint
```

## Architecture

### Tech Stack
- React 19 + TypeScript + Vite
- Tailwind CSS (dark mode via class strategy)
- Firebase Realtime Database (no custom backend)
- Google Maps JavaScript API with Advanced Markers

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

### Component Structure
```
src/
├── components/
│   ├── CreateWalkEvent.tsx     # Event creation with route drawing + PIN confirmation
│   ├── WalkEventView.tsx       # Main event view (participant/organizer)
│   ├── WalkMapComponent.tsx    # Google Maps with markers + polylines
│   ├── LocationBroadcaster.tsx # GPS broadcast controls
│   ├── OrganizerPinModal.tsx   # PIN entry modal
│   ├── Toast.tsx               # Toast notifications + useToast hook
│   └── LoadingSpinner.tsx      # Loading indicator
├── hooks/
│   ├── useGeolocation.ts       # Browser Geolocation API wrapper
│   └── useLiveLocation.ts      # Firebase location subscription
├── services/
│   ├── firebase.ts             # Firebase config + CRUD operations
│   └── organizerStorage.ts     # localStorage for organizer's events
└── types/
    └── index.ts                # TypeScript interfaces
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

Required in `.env`:
```
VITE_FIREBASE_API_KEY=
VITE_FIREBASE_AUTH_DOMAIN=
VITE_FIREBASE_PROJECT_ID=
VITE_FIREBASE_STORAGE_BUCKET=
VITE_FIREBASE_MESSAGING_SENDER_ID=
VITE_FIREBASE_APP_ID=
VITE_FIREBASE_DATABASE_URL=
VITE_GOOGLE_MAPS_API_KEY=
```

## Deployment

**CI/CD via GitHub Actions** - Pushing to `main` automatically deploys to Google Cloud Run.

### GCP Project
- Project ID: `scenic-walk-484001`
- Region: `us-west1`
- Service: `scenic-walk`

### Infrastructure
- **Cloud Run**: Hosts the containerized frontend
- **Artifact Registry**: Stores Docker images at `us-west1-docker.pkg.dev/scenic-walk-484001/scenic-walk`
- **Workload Identity Federation**: Keyless GitHub → GCP authentication (no service account keys)

### Deployment Files
- `Dockerfile`: Multi-stage build (node:20 → nginx:alpine)
- `nginx.conf`: SPA routing + security headers
- `.github/workflows/deploy.yml`: GitHub Actions workflow

### Manual Deployment (emergency only)
```bash
gcloud run deploy scenic-walk \
  --source . \
  --region us-west1 \
  --project scenic-walk-484001 \
  --allow-unauthenticated
```

### View Logs
```bash
gcloud run services logs read scenic-walk --region us-west1 --project scenic-walk-484001 --limit 50
```

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
