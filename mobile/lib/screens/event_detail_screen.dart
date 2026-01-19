import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/background_service.dart';

class EventDetailScreen extends StatefulWidget {
  final SavedEvent savedEvent;

  const EventDetailScreen({super.key, required this.savedEvent});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  WalkEvent? _event;
  bool _isLoading = true;
  bool _isBroadcasting = false;
  bool _hasBackgroundPermission = false;
  String? _errorMessage;
  Position? _lastPosition;
  DateTime? _lastUpdateTime;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _loadEvent();
    _checkBroadcastStatus();
    _checkBackgroundPermission();
    _listenToBackgroundUpdates();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _listenToBackgroundUpdates() {
    _locationSubscription = BackgroundService.onLocationUpdate.listen((data) {
      if (data != null && mounted) {
        setState(() {
          _lastPosition = Position(
            latitude: data['lat'] as double,
            longitude: data['lng'] as double,
            timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
            accuracy: data['accuracy'] as double? ?? 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
          _lastUpdateTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);

    final event = await FirebaseService.getEvent(widget.savedEvent.id);
    setState(() {
      _event = event;
      _isLoading = false;
    });

    // Subscribe to event changes
    _eventSubscription?.cancel();
    _eventSubscription = FirebaseService.listenToEvent(widget.savedEvent.id).listen((event) {
      if (mounted) {
        setState(() => _event = event);
      }
    });
  }

  Future<void> _checkBroadcastStatus() async {
    final broadcastingId = await StorageService.getBroadcastingEvent();
    final isRunning = await BackgroundService.isRunning();
    if (mounted) {
      setState(() {
        _isBroadcasting = broadcastingId == widget.savedEvent.id && isRunning;
      });
    }
  }

  Future<void> _checkBackgroundPermission() async {
    final hasPermission = await LocationService.hasBackgroundPermission();
    if (mounted) {
      setState(() => _hasBackgroundPermission = hasPermission);
    }
  }

  Future<void> _requestBackgroundPermission() async {
    final granted = await LocationService.requestBackgroundPermission();
    if (mounted) {
      setState(() => _hasBackgroundPermission = granted);
      if (!granted) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Background Location'),
        content: const Text(
          'To broadcast your location when the app is in the background or your phone is locked, '
          'please allow "Allow all the time" in location settings.\n\n'
          'This is required for continuous location broadcasting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startBroadcasting() async {
    setState(() => _errorMessage = null);

    // Check location permissions
    final permissionResult = await LocationService.checkPermissions();
    if (!permissionResult.granted) {
      setState(() => _errorMessage = permissionResult.message);
      return;
    }

    // Check background permission
    if (!_hasBackgroundPermission) {
      await _requestBackgroundPermission();
      if (!_hasBackgroundPermission) {
        setState(() => _errorMessage = 'Background location permission required for continuous broadcasting.');
        return;
      }
    }

    // Start background service
    await BackgroundService.startService(
      widget.savedEvent.id,
      widget.savedEvent.name,
    );

    setState(() => _isBroadcasting = true);
  }

  Future<void> _stopBroadcasting() async {
    await BackgroundService.stopService();
    setState(() {
      _isBroadcasting = false;
      _lastPosition = null;
      _lastUpdateTime = null;
    });
  }

  void _onLocationUpdate(Position position) async {
    if (!mounted) return;

    setState(() {
      _lastPosition = position;
      _lastUpdateTime = DateTime.now();
    });

    // Send to Firebase
    await FirebaseService.updateLocation(
      widget.savedEvent.id,
      LocationData(
        lat: position.latitude,
        lng: position.longitude,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        accuracy: position.accuracy,
      ),
    );
  }

  Future<void> _sendSingleUpdate() async {
    setState(() => _errorMessage = null);

    final permissionResult = await LocationService.checkPermissions();
    if (!permissionResult.granted) {
      setState(() => _errorMessage = permissionResult.message);
      return;
    }

    final position = await LocationService.getCurrentPosition();
    if (position != null) {
      _onLocationUpdate(position);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      setState(() => _errorMessage = 'Could not get current location');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.savedEvent.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_event == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.savedEvent.name)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                const Text(
                  'Event not found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'This event may have been deleted or the ID is incorrect.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isActive = _event!.isActive;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.savedEvent.name),
        actions: [
          IconButton(
            onPressed: _loadEvent,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isBroadcasting
                    ? Colors.green.withOpacity(0.1)
                    : isActive
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isBroadcasting
                      ? Colors.green.withOpacity(0.3)
                      : isActive
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isBroadcasting
                        ? Icons.broadcast_on_personal
                        : isActive
                            ? Icons.event_available
                            : Icons.event_busy,
                    size: 48,
                    color: _isBroadcasting
                        ? Colors.green
                        : isActive
                            ? Colors.blue
                            : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isBroadcasting
                        ? 'Broadcasting'
                        : isActive
                            ? 'Event Active'
                            : 'Event Ended',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _isBroadcasting
                          ? Colors.green[700]
                          : isActive
                              ? Colors.blue[700]
                              : Colors.grey[700],
                    ),
                  ),
                  if (_isBroadcasting && _lastUpdateTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last update: ${_formatTime(_lastUpdateTime!)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Broadcasting controls
            if (isActive) ...[
              if (_isBroadcasting) ...[
                // Stop button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _stopBroadcasting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.stop),
                    label: const Text(
                      'Stop Broadcasting',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ] else ...[
                // Start button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _startBroadcasting,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      'Start Broadcasting',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Single update button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _sendSingleUpdate,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Send Single Update'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],

            // Event info
            Text(
              'Event Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Event ID', value: _event!.id),
            _InfoRow(
              label: 'Status',
              value: isActive ? 'Active' : 'Ended',
              valueColor: isActive ? Colors.green : Colors.grey,
            ),
            _InfoRow(
              label: 'Created',
              value: _formatDate(DateTime.fromMillisecondsSinceEpoch(_event!.createdAt)),
            ),
            if (_event!.route.isNotEmpty)
              _InfoRow(
                label: 'Route',
                value: '${_event!.route.length} points',
              ),

            const SizedBox(height: 24),

            // Background permission info
            if (!_hasBackgroundPermission && isActive) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.amber[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Background Location',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Grant "Allow all the time" location permission for broadcasting to continue when your phone is locked.',
                      style: TextStyle(color: Colors.amber[900], fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _requestBackgroundPermission,
                        child: const Text('Grant Permission'),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Last known position
            if (_lastPosition != null) ...[
              const SizedBox(height: 24),
              Text(
                'Last Known Position',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Latitude',
                value: _lastPosition!.latitude.toStringAsFixed(6),
              ),
              _InfoRow(
                label: 'Longitude',
                value: _lastPosition!.longitude.toStringAsFixed(6),
              ),
              _InfoRow(
                label: 'Accuracy',
                value: '${_lastPosition!.accuracy.toStringAsFixed(1)} m',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
