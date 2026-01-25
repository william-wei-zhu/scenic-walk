# Scenic Walk - Mobile App

Flutter Android app for event organizers to broadcast their live GPS location to participants.

Features the cute hiking goat mascot as the app icon.

## Features

- **Create Events** - Draw routes on an interactive map with tap-to-add points
- **Add Existing Events** - Join events by entering Event ID + PIN
- **Live GPS Broadcasting** - Continuous background location sharing
- **Custom Organizer Marker** - Orange flag with walking emoji (matches web)
- **Map Controls** - Zoom in/out, center on location, show all
- **Background Service** - Location updates continue when app is backgrounded or screen is locked
- **Dark Mode** - Full dark theme support
- **Share Event Links** - Easy sharing to participants

## Requirements

- Flutter 3.32+
- Android SDK 35+
- Java 17
- Google Maps API key with "Maps SDK for Android" enabled

## Setup

### 1. Clone and Install Dependencies

```bash
cd mobile
flutter pub get
```

### 2. Configure Google Maps API Key

Create `android/local.properties`:

```properties
sdk.dir=/path/to/android/sdk
MAPS_API_KEY=your_google_maps_api_key
```

Make sure your API key has:
- **Maps SDK for Android** enabled
- Your debug SHA-1 fingerprint added (for development)
- Your release SHA-1 fingerprint added (for production)

Get your debug SHA-1:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -storepass android | grep SHA1
```

### 3. Firebase Configuration

The `google-services.json` file is already configured. If you need to use your own Firebase project:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Add an Android app with package name `com.scenicwalk.scenic_walk`
3. Download `google-services.json` to `android/app/`

### 4. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                    # App entry, Firebase init, theme
├── config/
│   └── app_config.dart          # App configuration (URLs, colors, etc.)
├── screens/
│   ├── home_screen.dart         # Event list, navigation
│   ├── create_event_screen.dart # Create event with route drawing
│   ├── add_event_screen.dart    # Add existing event by ID + PIN
│   └── event_detail_screen.dart # Event view with map + broadcast controls
└── services/
    ├── firebase_service.dart    # Firebase CRUD operations
    ├── storage_service.dart     # SharedPreferences for saved events
    ├── location_service.dart    # Foreground location + permissions
    └── background_service.dart  # Background location service
```

## Building for Release

### Debug APK
```bash
flutter build apk
```

### Release APK
```bash
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

### Release Signing

For production releases, create `android/key.properties`:

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=/path/to/your/keystore.jks
```

## Permissions

The app requires the following permissions:

- **Location** (fine + coarse) - For GPS broadcasting
- **Background Location** - For broadcasting when app is backgrounded
- **Foreground Service** - For persistent location updates
- **Notifications** - For foreground service notification (Android 13+)
- **Internet** - For Firebase sync

## CI/CD

GitHub Actions workflow (`.github/workflows/build-android.yml`) automatically builds the APK when changes are pushed to `mobile/`.

## Production URL

Share links use the production domain: `https://scenic-walk.com/#/{eventId}`

To change this, edit `lib/config/app_config.dart`:

```dart
static const String webAppBaseUrl = 'https://your-domain.com';
```
