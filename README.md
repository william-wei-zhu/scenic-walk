# Scenic Walk

**Never lose your walking group again.** Open-source community walking events with live GPS location sharing.

Create walking events, draw routes on a map, and share your live location with participants in real-time. Perfect for group walks, guided tours, hikes, and outdoor activities.

## Features

### Web App (Participants + Organizers)
- **Live GPS Broadcasting** - Share your real-time location with participants
- **Custom Route Drawing** - Plan your walk by clicking points on the map
- **Directional Arrows** - See which way to walk with arrows along the route
- **Easy Sharing** - Simple shareable links, no app downloads required
- **Organizer PIN** - Secure access for event organizers
- **My Events** - Return to your events anytime (saved locally on device)
- **Delete Events** - Permanently delete events from the database
- **Dark Mode** - Full dark theme support
- **Mobile Responsive** - Works on phones, tablets, and desktops
- **Advanced Markers** - Custom orange flag marker with walking emoji for organizer location

### Android App (Organizers)
- **Create Events** - Draw routes directly on an interactive map
- **Directional Arrows** - See which way to walk with arrows along the route
- **Background Broadcasting** - Location updates continue when app is backgrounded or screen locked
- **Delete Events** - Permanently delete events from the database
- **Custom Organizer Marker** - Orange flag with walking emoji (matches web)
- **Map Controls** - Zoom in/out, center on location, show all
- **My Location Button** - Quick navigation to current position
- **Dark Mode** - Full dark theme support
- **Share Links** - Easy sharing to participants via `scenic-walk.com`

## Quick Start

### Prerequisites

- Node.js 18+ and npm
- A Google Cloud account (for Maps API)
- A Firebase account (for Realtime Database)

### 1. Clone the Repository

```bash
git clone https://github.com/william-wei-zhu/scenic-walk.git
cd scenic-walk
```

### 2. Install Dependencies

```bash
cd web
npm install
```

### 3. Set Up Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use an existing one
3. Enable **Realtime Database** (not Firestore)
4. Set database rules for development:

```json
{
  "rules": {
    "events": {
      ".read": true,
      ".write": true
    },
    "locations": {
      ".read": true,
      ".write": true
    }
  }
}
```

5. Copy your Firebase config from Project Settings > General > Your Apps > Firebase SDK snippet

### 4. Set Up Google Maps API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Enable the **Maps JavaScript API**
4. Create an API key under APIs & Services > Credentials
5. Restrict the key to your domains for production

### 5. Configure Environment Variables

Create a `.env` file from the example (inside the `web/` folder):

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```env
# Firebase Configuration
VITE_FIREBASE_API_KEY=your_api_key
VITE_FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=your_project_id
VITE_FIREBASE_STORAGE_BUCKET=your_project.appspot.com
VITE_FIREBASE_MESSAGING_SENDER_ID=your_sender_id
VITE_FIREBASE_APP_ID=your_app_id
VITE_FIREBASE_DATABASE_URL=https://your_project-default-rtdb.firebaseio.com

# Google Maps
VITE_GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

### 6. Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Usage

### Creating an Event

1. Click "Create Walk Event" on the home page
2. Draw your route by clicking on the map
3. Enter an event name and 4-digit PIN
4. Click "Create Event"
5. Share the participant link with your group
6. Your event is saved to "My Events" for easy access later

### Organizing a Walk

1. Open your organizer link
2. Enter your PIN
3. Click "Start Broadcasting" to share your location
4. Participants will see your position on the map
5. Click "End Event" when finished

### Joining a Walk

1. Open the participant link shared by the organizer
2. Wait for the organizer to start broadcasting
3. The orange flag with walking emoji (🚶) shows the organizer's live location
4. Green marker = route start, Red marker = route end
5. Green line with arrows = planned walking route (arrows show direction)

## Project Structure

```
scenic-walk/
├── web/                     # React web app
│   ├── src/
│   │   ├── components/      # React components
│   │   ├── hooks/           # Custom React hooks
│   │   ├── services/        # Firebase + local storage
│   │   └── types/           # TypeScript types
│   ├── package.json
│   ├── Dockerfile
│   └── ...
├── mobile/                  # Flutter Android app (organizers)
│   ├── lib/
│   │   ├── screens/         # Home, Add Event, Event Detail
│   │   └── services/        # Firebase, Location, Storage
│   ├── android/
│   └── pubspec.yaml
├── .github/workflows/       # CI/CD
│   ├── deploy-web.yml       # Web app deployment
│   └── build-android.yml    # Android APK build
├── CLAUDE.md                # AI assistant context
├── README.md
└── LICENSE
```

## URL Routes

| Route | Description |
|-------|-------------|
| `/#/` | Home page |
| `/#/create` | Create new event |
| `/#/:eventId` | Participant view |
| `/#/:eventId?organizer=true` | Organizer view |

## Firebase Data Structure

```
├── events/
│   └── {eventId}/
│       ├── id: string
│       ├── name: string
│       ├── createdAt: number
│       ├── organizerPin: string
│       ├── route: [{lat, lng}, ...]
│       ├── status: 'active' | 'ended'
│       └── broadcastMode: 'continuous' | 'manual'
└── locations/
    └── {eventId}/
        ├── lat: number
        ├── lng: number
        ├── timestamp: number
        └── accuracy?: number
```

## Production Deployment

### Web App (Automatic CI/CD)

Pushing changes to `web/` on `main` branch automatically deploys to **Google Cloud Run**.

```bash
git push origin main
```

The workflow (`.github/workflows/deploy-web.yml`) will:
1. Build a Docker image with the Vite frontend
2. Push to Google Artifact Registry
3. Deploy to Cloud Run

### Manual Build

```bash
cd web
npm run build
```

The output will be in the `web/dist/` directory.

### Mobile App (Android APK)

The Flutter Android app allows organizers to create events and broadcast their location even when the phone is locked.

**Setup:**
```bash
cd mobile
flutter pub get
```

Create `android/local.properties` with your Google Maps API key:
```properties
sdk.dir=/path/to/android/sdk
MAPS_API_KEY=your_google_maps_api_key
```

**Build locally:**
```bash
flutter build apk --release
```

**CI/CD:** Pushing changes to `mobile/` triggers GitHub Actions to build the APK, which is available as a workflow artifact.

See [mobile/README.md](mobile/README.md) for detailed setup instructions.

### Alternative Hosting

You can also deploy the `dist/` folder to any static hosting:

- **Firebase Hosting**: `firebase deploy`
- **Vercel**: `vercel`
- **Netlify**: Drag and drop to Netlify
- **GitHub Pages**: Use GitHub Actions

### Production Security

1. **Restrict Google Maps API Key** - Set HTTP referrer restrictions in Google Cloud Console

2. **Tighten Firebase Rules** - Use more secure rules for production:

```json
{
  "rules": {
    "events": {
      ".read": true,
      "$eventId": {
        ".write": "!data.exists() || data.child('organizerPin').val() === newData.child('organizerPin').val()"
      }
    },
    "locations": {
      ".read": true,
      ".write": true
    }
  }
}
```

## Tech Stack

### Web
- **React 19** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool
- **Tailwind CSS** - Styling
- **Firebase Realtime Database** - Real-time data sync
- **Google Maps JavaScript API** - Maps and markers

### Mobile (Android)
- **Flutter** - Cross-platform framework
- **Firebase Realtime Database** - Same backend as web
- **Geolocator** - Location services
- **Flutter Background Service** - Background location broadcasting

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the **AGPL-3.0 License** - see the [LICENSE](LICENSE) file for details.

This means:
- You can use, modify, and distribute this software
- If you modify and distribute it, you must:
  - Release your modifications under AGPL-3.0
  - Provide access to the source code
  - Preserve copyright notices
