/// App configuration constants
///
/// This file contains all configurable values for the app.
/// Update these values when deploying to different environments.
class AppConfig {
  // Prevent instantiation
  AppConfig._();

  /// The base URL for the web app (used for sharing event links)
  /// Update this if you deploy to a custom domain
  static const String webAppBaseUrl = 'https://scenic-walk.com';

  /// App name displayed throughout the UI
  static const String appName = 'Scenic Walk';

  /// App tagline
  static const String tagline = 'Never lose your walking group again.';

  /// Primary brand color (green-600 from Tailwind)
  static const int primaryColorValue = 0xFF16a34a;

  /// Location update settings
  static const int locationDistanceFilterMeters = 5;
  static const int locationUpdateIntervalSeconds = 10;
  static const int locationMaxAccuracyMeters = 100;

  /// Event ID length (UUID truncated)
  static const int eventIdLength = 8;

  /// PIN length
  static const int pinLength = 4;

  /// Stale location threshold (seconds without update)
  static const int staleLocationThresholdSeconds = 60;

  /// Build event share URL
  static String getEventShareUrl(String eventId) {
    return '$webAppBaseUrl/#/$eventId';
  }

  /// Build organizer event URL
  static String getOrganizerEventUrl(String eventId) {
    return '$webAppBaseUrl/#/$eventId?organizer=true';
  }
}
