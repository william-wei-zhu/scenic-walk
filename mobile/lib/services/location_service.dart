import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static StreamSubscription<Position>? _positionSubscription;
  static bool _isTracking = false;

  /// Check if location services are enabled and permissions granted
  static Future<LocationPermissionResult> checkPermissions() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionResult(
        granted: false,
        message: 'Location services are disabled. Please enable them in settings.',
      );
    }

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionResult(
          granted: false,
          message: 'Location permission denied. Please grant permission to broadcast your location.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult(
        granted: false,
        message: 'Location permission permanently denied. Please enable it in app settings.',
      );
    }

    return LocationPermissionResult(granted: true);
  }

  /// Request background location permission
  /// On iOS, avoids re-requesting if user has already responded to the "Always" prompt
  static Future<bool> requestBackgroundPermission() async {
    if (Platform.isIOS) {
      // On iOS, check current status first
      final status = await Permission.locationAlways.status;

      // If already granted, we're done
      if (status.isGranted) {
        return true;
      }

      // If permanently denied or restricted, can't request again
      if (status.isPermanentlyDenied || status.isRestricted) {
        return false;
      }

      // Check if user has "while in use" - if so, they've seen the prompt
      // and chose not to grant "always". Don't re-request, guide to settings.
      final whileInUse = await Permission.locationWhenInUse.status;
      if (whileInUse.isGranted && status.isDenied) {
        // User has foreground permission but denied/skipped "always"
        // On iOS, re-requesting will show the dialog again which is annoying
        // Return false and let the UI guide them to Settings
        return false;
      }

      // First time requesting - go ahead
      final result = await Permission.locationAlways.request();
      return result.isGranted;
    } else {
      // Android - original behavior
      final status = await Permission.locationAlways.request();
      return status.isGranted;
    }
  }

  /// Check if background location is granted
  static Future<bool> hasBackgroundPermission() async {
    final status = await Permission.locationAlways.status;
    return status.isGranted;
  }

  /// Check if notification permission is granted (Android 13+)
  static Future<bool> hasNotificationPermission() async {
    // Only needed for Android 13+ (API 33+)
    if (!Platform.isAndroid) return true;

    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Request notification permission (Android 13+)
  /// Returns true if granted, false otherwise
  static Future<bool> requestNotificationPermission() async {
    // Only needed for Android 13+ (API 33+)
    if (!Platform.isAndroid) return true;

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Check all permissions needed for broadcasting
  /// Returns a result indicating if all permissions are granted
  static Future<BroadcastPermissionResult> checkBroadcastPermissions() async {
    final locationResult = await checkPermissions();
    if (!locationResult.granted) {
      return BroadcastPermissionResult(
        granted: false,
        message: locationResult.message,
        missingPermission: 'location',
      );
    }

    final hasBackground = await hasBackgroundPermission();
    if (!hasBackground) {
      return BroadcastPermissionResult(
        granted: false,
        message: 'Background location permission is required for continuous broadcasting.',
        missingPermission: 'backgroundLocation',
      );
    }

    final hasNotification = await hasNotificationPermission();
    if (!hasNotification) {
      return BroadcastPermissionResult(
        granted: false,
        message: 'Notification permission is required to show broadcasting status.',
        missingPermission: 'notification',
      );
    }

    return BroadcastPermissionResult(granted: true);
  }

  /// Get current position once
  static Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  /// Start continuous location tracking
  static void startTracking({
    required void Function(Position position) onLocationUpdate,
    void Function(Object error)? onError,
  }) {
    if (_isTracking) return;
    _isTracking = true;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Minimum distance (in meters) to trigger update
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      onLocationUpdate,
      onError: (error) {
        print('Location tracking error: $error');
        onError?.call(error);
      },
    );
  }

  /// Stop location tracking
  static void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
  }

  /// Check if currently tracking
  static bool get isTracking => _isTracking;

  /// Calculate distance between two points in meters
  static double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}

class LocationPermissionResult {
  final bool granted;
  final String? message;

  LocationPermissionResult({
    required this.granted,
    this.message,
  });
}

class BroadcastPermissionResult {
  final bool granted;
  final String? message;
  final String? missingPermission;

  BroadcastPermissionResult({
    required this.granted,
    this.message,
    this.missingPermission,
  });
}
