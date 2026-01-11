# Scenic Walk

**Scroll Less, Walk More** - Open-source community walking events with live GPS location sharing.

Create walking events, draw routes on a map, and share your live location with participants in real-time. Perfect for group walks, guided tours, hikes, and outdoor activities.

## Features

- **Live GPS Broadcasting** - Share your real-time location with participants
- **Custom Route Drawing** - Plan your walk by clicking points on the map
- **Easy Sharing** - Simple shareable links, no app downloads required
- **Organizer PIN** - Secure access for event organizers
- **Auto/Manual Mode** - Choose continuous or on-demand location updates
- **Dark Mode** - Full dark theme support
- **Mobile Responsive** - Works on phones, tablets, and desktops

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

Create a `.env` file from the example:

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
4. Choose broadcast mode (Auto or Manual)
5. Click "Create Event"
6. Share the participant link with your group
7. Keep your organizer link private

### Organizing a Walk

1. Open your organizer link
2. Enter your PIN
3. Click "Start Broadcasting" to share your location
4. Participants will see your position on the map
5. Click "End Event" when finished

### Joining a Walk

1. Open the participant link shared by the organizer
2. Wait for the organizer to start broadcasting
3. The orange flag shows the organizer's live location
4. Green = route start, Red = route end

## Project Structure

```
scenic-walk/
├── src/
│   ├── components/          # React components
│   │   ├── CreateWalkEvent.tsx
│   │   ├── WalkEventView.tsx
│   │   ├── WalkMapComponent.tsx
│   │   ├── LocationBroadcaster.tsx
│   │   ├── OrganizerPinModal.tsx
│   │   └── LoadingSpinner.tsx
│   ├── hooks/               # Custom React hooks
│   │   ├── useGeolocation.ts
│   │   └── useLiveLocation.ts
│   ├── services/            # Firebase integration
│   │   └── firebase.ts
│   ├── types/               # TypeScript types
│   │   └── index.ts
│   ├── App.tsx              # Main app with routing
│   ├── main.tsx             # Entry point
│   ├── main.css             # Tailwind imports
│   └── vite-env.d.ts        # Vite environment types
├── .env.example             # Environment variables template
├── package.json
├── vite.config.ts
├── tailwind.config.js
├── postcss.config.js
├── tsconfig.json
├── CLAUDE.md                # AI assistant context
└── CONTRIBUTING.md          # Contribution guidelines
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

### Build

```bash
npm run build
```

The output will be in the `dist/` directory.

### Deploy

Deploy the `dist/` folder to any static hosting:

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

- **React 19** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool
- **Tailwind CSS** - Styling
- **Firebase Realtime Database** - Real-time data sync
- **Google Maps JavaScript API** - Maps and markers

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

## Acknowledgments

Extracted from [Scenic Guide](https://github.com/william-wei-zhu/scenic-2), an AI-powered travel companion app.
