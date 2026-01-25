import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_service.dart';
import 'storage_service.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static const String _notificationChannelId = 'scenic_walk_location';
  static const String _notificationChannelName = 'Location Broadcasting';
  static const int _notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'Shows notification when broadcasting location',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'Scenic Walk',
        initialNotificationContent: 'Broadcasting location...',
        foregroundServiceNotificationId: _notificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Initialize Firebase in the background isolate
    await Firebase.initializeApp();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    StreamSubscription<Position>? positionSubscription;
    String? currentEventId;
    String? currentEventName;

    // Listen for start/stop commands
    service.on('start').listen((event) async {
      currentEventId = event?['eventId'] as String?;
      currentEventName = event?['eventName'] as String?;

      // Fallback: read from storage if not provided
      currentEventId ??= await StorageService.getBroadcastingEvent();
      currentEventName ??= await StorageService.getEventName();

      if (currentEventId == null) return;

      // Update notification
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Scenic Walk',
          content: 'Broadcasting: $currentEventName',
        );
      }

      // Start location tracking
      final LocationSettings locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Broadcasting your location",
          notificationTitle: "Scenic Walk",
          enableWakeLock: true,
        ),
      );

      // Get initial position first
      try {
        final initialPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );

        // Send initial position to Firebase
        await FirebaseService.updateLocation(
          currentEventId!,
          LocationData(
            lat: initialPosition.latitude,
            lng: initialPosition.longitude,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            accuracy: initialPosition.accuracy,
          ),
        );
      } catch (e) {
        print('Error getting initial position: $e');
      }

      positionSubscription?.cancel();
      positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          if (currentEventId == null) return;

          // Send to Firebase
          await FirebaseService.updateLocation(
            currentEventId!,
            LocationData(
              lat: position.latitude,
              lng: position.longitude,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              accuracy: position.accuracy,
            ),
          );

          // Update notification with last update time
          if (service is AndroidServiceInstance) {
            final now = DateTime.now();
            final timeStr =
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
            service.setForegroundNotificationInfo(
              title: 'Broadcasting: $currentEventName',
              content: 'Last update: $timeStr',
            );
          }

          // Send update to main isolate
          service.invoke('update', {
            'lat': position.latitude,
            'lng': position.longitude,
            'accuracy': position.accuracy,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        },
        onError: (error) {
          print('Background location error: $error');
        },
      );
    });

    service.on('stop').listen((event) async {
      positionSubscription?.cancel();
      positionSubscription = null;
      currentEventId = null;
      currentEventName = null;

      // Clear broadcasting state
      await StorageService.setBroadcastingEvent(null);

      service.stopSelf();
    });

    // Handle service stop
    service.on('stopService').listen((event) async {
      positionSubscription?.cancel();
      await StorageService.setBroadcastingEvent(null);
      service.stopSelf();
    });
  }

  static Future<void> startService(String eventId, String eventName) async {
    final service = FlutterBackgroundService();

    // Save broadcasting state and event info for background service to read
    await StorageService.setBroadcastingEvent(eventId);
    await StorageService.setEventName(eventName);

    // Start the service
    await service.startService();

    // Wait for service to be ready, then send start command
    await Future.delayed(const Duration(milliseconds: 500));

    service.invoke('start', {
      'eventId': eventId,
      'eventName': eventName,
    });
  }

  static Future<void> stopService() async {
    final service = FlutterBackgroundService();

    // Clear broadcasting state
    await StorageService.setBroadcastingEvent(null);

    // Stop the service
    service.invoke('stop');
  }

  static Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  /// Listen to location updates from the background service
  static Stream<Map<String, dynamic>?> get onLocationUpdate {
    final service = FlutterBackgroundService();
    return service.on('update');
  }
}
