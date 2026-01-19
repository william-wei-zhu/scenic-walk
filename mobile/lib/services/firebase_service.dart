import 'package:firebase_database/firebase_database.dart';

class WalkEvent {
  final String id;
  final String name;
  final String organizerPin;
  final int createdAt;
  final String status;
  final String broadcastMode;
  final List<Map<String, double>> route;

  WalkEvent({
    required this.id,
    required this.name,
    required this.organizerPin,
    required this.createdAt,
    required this.status,
    required this.broadcastMode,
    required this.route,
  });

  factory WalkEvent.fromSnapshot(DataSnapshot snapshot) {
    final data = snapshot.value as Map<dynamic, dynamic>;

    List<Map<String, double>> parseRoute(dynamic routeData) {
      if (routeData == null) return [];
      if (routeData is List) {
        return routeData.map((point) {
          if (point is Map) {
            return {
              'lat': (point['lat'] as num).toDouble(),
              'lng': (point['lng'] as num).toDouble(),
            };
          }
          return {'lat': 0.0, 'lng': 0.0};
        }).toList();
      }
      return [];
    }

    return WalkEvent(
      id: data['id'] as String? ?? snapshot.key ?? '',
      name: data['name'] as String? ?? 'Unnamed Event',
      organizerPin: data['organizerPin'] as String? ?? '',
      createdAt: data['createdAt'] as int? ?? 0,
      status: data['status'] as String? ?? 'active',
      broadcastMode: data['broadcastMode'] as String? ?? 'continuous',
      route: parseRoute(data['route']),
    );
  }

  bool get isActive => status == 'active';
}

class LocationData {
  final double lat;
  final double lng;
  final int timestamp;
  final double? accuracy;

  LocationData({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.accuracy,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'timestamp': timestamp,
        if (accuracy != null) 'accuracy': accuracy,
      };
}

class FirebaseService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  /// Fetch an event by ID
  static Future<WalkEvent?> getEvent(String eventId) async {
    try {
      final snapshot = await _database.child('events/$eventId').get();
      if (!snapshot.exists) return null;
      return WalkEvent.fromSnapshot(snapshot);
    } catch (e) {
      print('Error fetching event: $e');
      return null;
    }
  }

  /// Verify PIN for an event
  static Future<bool> verifyPin(String eventId, String pin) async {
    try {
      final event = await getEvent(eventId);
      if (event == null) return false;
      return event.organizerPin == pin;
    } catch (e) {
      print('Error verifying PIN: $e');
      return false;
    }
  }

  /// Update location for an event
  static Future<bool> updateLocation(String eventId, LocationData location) async {
    try {
      await _database.child('locations/$eventId').set(location.toJson());
      return true;
    } catch (e) {
      print('Error updating location: $e');
      return false;
    }
  }

  /// Listen to location updates for an event
  static Stream<LocationData?> listenToLocation(String eventId) {
    return _database.child('locations/$eventId').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return LocationData(
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        timestamp: data['timestamp'] as int? ?? 0,
        accuracy: data['accuracy'] != null
            ? (data['accuracy'] as num).toDouble()
            : null,
      );
    });
  }

  /// Listen to event status changes
  static Stream<WalkEvent?> listenToEvent(String eventId) {
    return _database.child('events/$eventId').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return WalkEvent.fromSnapshot(event.snapshot);
    });
  }
}
