import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring network connectivity status
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static bool _isConnected = true;
  static final _connectivityController = StreamController<bool>.broadcast();

  /// Stream of connectivity status changes
  static Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  /// Current connectivity status
  static bool get isConnected => _isConnected;

  /// Initialize connectivity monitoring
  static Future<void> initialize() async {
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _isConnected = _hasConnection(results);

    // Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final connected = _hasConnection(results);
      if (connected != _isConnected) {
        _isConnected = connected;
        _connectivityController.add(_isConnected);
      }
    });
  }

  /// Check if the device has an active network connection
  static Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isConnected = _hasConnection(results);
    return _isConnected;
  }

  /// Determine if the connectivity results indicate a connection
  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);
  }

  /// Clean up resources
  static void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
  }
}
