import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedEvent {
  final String id;
  final String name;
  final String pin;
  final int createdAt;

  SavedEvent({
    required this.id,
    required this.name,
    required this.pin,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pin': pin,
        'createdAt': createdAt,
      };

  factory SavedEvent.fromJson(Map<String, dynamic> json) => SavedEvent(
        id: json['id'] as String,
        name: json['name'] as String,
        pin: json['pin'] as String,
        createdAt: json['createdAt'] as int,
      );
}

class StorageService {
  static const String _eventsKey = 'scenic-walk-organizer-events';
  static const String _broadcastingKey = 'scenic-walk-broadcasting-event';
  static const String _eventNameKey = 'scenic-walk-broadcasting-event-name';

  static Future<List<SavedEvent>> getEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = prefs.getString(_eventsKey);
    if (eventsJson == null) return [];

    try {
      final List<dynamic> eventsList = jsonDecode(eventsJson);
      return eventsList
          .map((e) => SavedEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveEvent(SavedEvent event) async {
    final events = await getEvents();
    // Remove existing event with same ID if exists
    events.removeWhere((e) => e.id == event.id);
    events.insert(0, event); // Add to beginning
    await _saveEvents(events);
  }

  static Future<void> removeEvent(String eventId) async {
    final events = await getEvents();
    events.removeWhere((e) => e.id == eventId);
    await _saveEvents(events);
  }

  static Future<void> _saveEvents(List<SavedEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_eventsKey, eventsJson);
  }

  static Future<String?> getStoredPin(String eventId) async {
    final events = await getEvents();
    try {
      final event = events.firstWhere((e) => e.id == eventId);
      return event.pin;
    } catch (e) {
      return null;
    }
  }

  // Track which event is currently broadcasting
  static Future<void> setBroadcastingEvent(String? eventId) async {
    final prefs = await SharedPreferences.getInstance();
    if (eventId == null) {
      await prefs.remove(_broadcastingKey);
    } else {
      await prefs.setString(_broadcastingKey, eventId);
    }
  }

  static Future<String?> getBroadcastingEvent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_broadcastingKey);
  }

  // Store event name for background service
  static Future<void> setEventName(String? eventName) async {
    final prefs = await SharedPreferences.getInstance();
    if (eventName == null) {
      await prefs.remove(_eventNameKey);
    } else {
      await prefs.setString(_eventNameKey, eventName);
    }
  }

  static Future<String?> getEventName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_eventNameKey);
  }
}
