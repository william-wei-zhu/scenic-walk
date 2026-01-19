import 'dart:async';
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

  /// Request background location permission (Android only)
  static Future<bool> requestBackgroundPermission() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Check if background location is granted
  static Future<bool> hasBackgroundPermission() async {
    final status = await Permission.locationAlways.status;
    return status.isGranted;
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
