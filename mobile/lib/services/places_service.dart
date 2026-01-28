import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Service for Google Places API autocomplete and place details
class PlacesService {
  static String? _apiKey;
  static String? _sessionToken;
  static DateTime? _sessionExpiry;

  /// Get the Google Maps API key from native resources
  static Future<String?> _getApiKey() async {
    if (_apiKey != null) return _apiKey;

    try {
      const platform = MethodChannel('com.scenicwalk.scenic_walk/api_keys');
      _apiKey = await platform.invokeMethod<String>('getMapsApiKey');
      print('PlacesService: Got API key via MethodChannel: ${_apiKey?.substring(0, 10)}...');
      return _apiKey;
    } catch (e) {
      print('PlacesService: MethodChannel error: $e');
      // Fallback: try to read from bundle
      try {
        final data = await rootBundle.loadString('assets/config.json');
        final config = json.decode(data) as Map<String, dynamic>;
        _apiKey = config['mapsApiKey'] as String?;
        return _apiKey;
      } catch (e2) {
        print('PlacesService: Fallback error: $e2');
        return null;
      }
    }
  }

  /// Generate or reuse a session token for Places API
  /// Session tokens group autocomplete requests to reduce billing
  static String _getSessionToken() {
    final now = DateTime.now();

    // Create new session if none exists or expired (sessions last ~3 minutes)
    if (_sessionToken == null ||
        _sessionExpiry == null ||
        now.isAfter(_sessionExpiry!)) {
      _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionExpiry = now.add(const Duration(minutes: 3));
    }

    return _sessionToken!;
  }

  /// Clear the session token (call after a place is selected)
  static void clearSession() {
    _sessionToken = null;
    _sessionExpiry = null;
  }

  /// Search for places matching the input text
  /// Returns a list of place predictions with id, description, and main text
  static Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.isEmpty) return [];

    print('PlacesService: autocomplete called with input: $input');

    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      print('PlacesService: API key is null or empty');
      throw Exception('Google Maps API key not configured');
    }

    final sessionToken = _getSessionToken();

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input)}'
      '&key=$apiKey'
      '&sessiontoken=$sessionToken',
    );

    print('PlacesService: Making request to Places API');
    final response = await http.get(url);
    print('PlacesService: Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Places API error: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String?;
    print('PlacesService: API status: $status');

    if (status != 'OK' && status != 'ZERO_RESULTS') {
      print('PlacesService: Error message: ${data['error_message']}');
      throw Exception('Places API error: $status');
    }

    final predictions = data['predictions'] as List<dynamic>? ?? [];
    print('PlacesService: Got ${predictions.length} predictions');

    return predictions.map((p) {
      final prediction = p as Map<String, dynamic>;
      final structuredFormatting =
          prediction['structured_formatting'] as Map<String, dynamic>?;

      return PlacePrediction(
        placeId: prediction['place_id'] as String,
        description: prediction['description'] as String,
        mainText: structuredFormatting?['main_text'] as String? ??
            prediction['description'] as String,
        secondaryText: structuredFormatting?['secondary_text'] as String?,
      );
    }).toList();
  }

  /// Get place details (location) for a place ID
  /// Call this when a place is selected from autocomplete
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Google Maps API key not configured');
    }

    final sessionToken = _getSessionToken();

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=geometry'
      '&key=$apiKey'
      '&sessiontoken=$sessionToken',
    );

    final response = await http.get(url);

    // Clear session after place details are fetched (completes the session)
    clearSession();

    if (response.statusCode != 200) {
      throw Exception('Places API error: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String?;

    if (status != 'OK') {
      throw Exception('Places API error: $status');
    }

    final result = data['result'] as Map<String, dynamic>?;
    final geometry = result?['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    if (location == null) return null;

    return PlaceDetails(
      lat: (location['lat'] as num).toDouble(),
      lng: (location['lng'] as num).toDouble(),
    );
  }
}

/// A place prediction from autocomplete
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String? secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    this.secondaryText,
  });
}

/// Place details with location
class PlaceDetails {
  final double lat;
  final double lng;

  PlaceDetails({required this.lat, required this.lng});
}
