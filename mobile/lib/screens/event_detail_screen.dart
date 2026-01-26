import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/app_config.dart';
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

  // Map related
  GoogleMapController? _mapController;
  StreamSubscription? _liveLocationSubscription;
  BitmapDescriptor? _organizerMarkerIcon;

  @override
  void initState() {
    super.initState();
    _loadEvent();
    _checkBroadcastStatus();
    _checkBackgroundPermission();
    _listenToBackgroundUpdates();
    _listenToLiveLocation();
    _createOrganizerMarkerIcon();
  }

  Future<void> _createOrganizerMarkerIcon() async {
    final icon = await _createCustomMarkerBitmap();
    if (mounted) {
      setState(() {
        _organizerMarkerIcon = icon;
      });
    }
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap() async {
    const double width = 80;
    const double height = 100;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Pole
    final polePaint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(36, 30, 8, 70),
        const Radius.circular(2),
      ),
      polePaint,
    );

    // Flag background (orange gradient effect)
    final flagPaint = Paint()
      ..color = const Color(0xFFFF6B00)
      ..style = PaintingStyle.fill;
    final flagPath = Path()
      ..moveTo(44, 10)
      ..lineTo(80, 15)
      ..lineTo(80, 45)
      ..lineTo(44, 50)
      ..close();
    canvas.drawPath(flagPath, flagPaint);

    // Flag highlight
    final highlightPaint = Paint()
      ..color = const Color(0xFFFF9500)
      ..style = PaintingStyle.fill;
    final highlightPath = Path()
      ..moveTo(44, 10)
      ..lineTo(65, 12)
      ..lineTo(65, 32)
      ..lineTo(44, 35)
      ..close();
    canvas.drawPath(highlightPath, highlightPaint);

    // Walking emoji text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🚶',
        style: TextStyle(fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(52, 18));

    // Bottom dot (orange with white border)
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(40, 95), 12, dotBorderPaint);

    final dotPaint = Paint()
      ..color = const Color(0xFFFF6B00)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(40, 95), 9, dotPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(bytes);
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _locationSubscription?.cancel();
    _liveLocationSubscription?.cancel();
    _mapController?.dispose();
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

  void _listenToLiveLocation() {
    _liveLocationSubscription = FirebaseService.listenToLocation(widget.savedEvent.id).listen((location) {
      if (location != null && mounted) {
        setState(() {
          _lastPosition = Position(
            latitude: location.lat,
            longitude: location.lng,
            timestamp: DateTime.fromMillisecondsSinceEpoch(location.timestamp),
            accuracy: location.accuracy ?? 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
          _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(location.timestamp);
        });
      }
    });
  }

  void _centerOnOrganizer() {
    if (_mapController != null && _lastPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_lastPosition!.latitude, _lastPosition!.longitude),
          16,
        ),
      );
    }
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _fitBoundsToAll() {
    if (_mapController == null || _event == null) return;

    final route = _event!.route;
    if (route.isEmpty) return;

    double minLat = route.first['lat']!;
    double maxLat = route.first['lat']!;
    double minLng = route.first['lng']!;
    double maxLng = route.first['lng']!;

    for (final point in route) {
      minLat = minLat < point['lat']! ? minLat : point['lat']!;
      maxLat = maxLat > point['lat']! ? maxLat : point['lat']!;
      minLng = minLng < point['lng']! ? minLng : point['lng']!;
      maxLng = maxLng > point['lng']! ? maxLng : point['lng']!;
    }

    // Include organizer position if available
    if (_lastPosition != null) {
      minLat = minLat < _lastPosition!.latitude ? minLat : _lastPosition!.latitude;
      maxLat = maxLat > _lastPosition!.latitude ? maxLat : _lastPosition!.latitude;
      minLng = minLng < _lastPosition!.longitude ? minLng : _lastPosition!.longitude;
      maxLng = maxLng > _lastPosition!.longitude ? maxLng : _lastPosition!.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final route = _event?.route ?? [];

    if (route.isNotEmpty) {
      // Start marker (green)
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(route.first['lat']!, route.first['lng']!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start'),
      ));

      // End marker (red) if more than one point
      if (route.length > 1) {
        markers.add(Marker(
          markerId: const MarkerId('end'),
          position: LatLng(route.last['lat']!, route.last['lng']!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'End'),
        ));
      }
    }

    // Organizer location marker (custom orange flag) - only show when broadcasting
    if (_lastPosition != null && _isBroadcasting) {
      markers.add(Marker(
        markerId: const MarkerId('organizer'),
        position: LatLng(_lastPosition!.latitude, _lastPosition!.longitude),
        icon: _organizerMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        anchor: const Offset(0.5, 1.0), // Anchor at bottom center
        infoWindow: const InfoWindow(title: 'Organizer'),
      ));
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final route = _event?.route ?? [];
    if (route.length < 2) return {};

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: route.map((p) => LatLng(p['lat']!, p['lng']!)).toList(),
        color: const Color(0xFF16a34a), // green-600
        width: 4,
      ),
    };
  }

  LatLng _getInitialCameraPosition() {
    final route = _event?.route ?? [];
    if (route.isNotEmpty) {
      return LatLng(route.first['lat']!, route.first['lng']!);
    }
    // Default to San Francisco
    return const LatLng(37.7749, -122.4194);
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

    // Check notification permission (Android 13+)
    final hasNotificationPermission = await LocationService.hasNotificationPermission();
    if (!hasNotificationPermission) {
      final granted = await LocationService.requestNotificationPermission();
      if (!granted) {
        setState(() => _errorMessage = 'Notification permission is required to show broadcasting status. Please enable it in settings.');
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
    // Clear location from Firebase to protect privacy
    await FirebaseService.clearLocation(widget.savedEvent.id);
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

  void _shareEventLink() async {
    final eventUrl = AppConfig.getEventShareUrl(widget.savedEvent.id);
    final eventName = _event?.name ?? widget.savedEvent.name;

    try {
      await Share.share(
        'Join my walk event "$eventName"!\n\n$eventUrl',
        subject: 'Scenic Walk - $eventName',
      );
    } catch (e) {
      // Fallback to clipboard if share fails
      await Clipboard.setData(ClipboardData(text: eventUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _copyEventLink() {
    final link = AppConfig.getEventShareUrl(widget.savedEvent.id);
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Event link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Use local variable to avoid force unwraps after null check
    final event = _event!;
    final isActive = event.isActive;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.savedEvent.name),
        actions: [
          IconButton(
            onPressed: _shareEventLink,
            icon: const Icon(Icons.share),
            tooltip: 'Share event link',
          ),
          IconButton(
            onPressed: _loadEvent,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Map section
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _getInitialCameraPosition(),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    // Fit bounds after map is created
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) _fitBoundsToAll();
                    });
                  },
                  markers: _buildMarkers(),
                  polylines: _buildPolylines(),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
                // Map control buttons
                Positioned(
                  top: 12,
                  left: 12,
                  child: Column(
                    children: [
                      if (_lastPosition != null && _isBroadcasting)
                        _MapButton(
                          onPressed: _centerOnOrganizer,
                          icon: Icons.person_pin_circle,
                          label: 'Center on Organizer',
                          isPrimary: true,
                        ),
                      if (_lastPosition != null && _isBroadcasting)
                        const SizedBox(height: 8),
                      _MapButton(
                        onPressed: _fitBoundsToAll,
                        icon: Icons.zoom_out_map,
                        label: 'Show All',
                        isPrimary: false,
                      ),
                    ],
                  ),
                ),
                // Zoom controls
                Positioned(
                  bottom: 16,
                  right: 12,
                  child: Column(
                    children: [
                      _ZoomButton(
                        icon: Icons.add,
                        onTap: _zoomIn,
                      ),
                      const SizedBox(height: 8),
                      _ZoomButton(
                        icon: Icons.remove,
                        onTap: _zoomOut,
                      ),
                    ],
                  ),
                ),
                // Broadcasting status indicator overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isBroadcasting ? Colors.green : Colors.grey[700],
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isBroadcasting ? Icons.broadcast_on_personal : Icons.broadcast_on_personal_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isBroadcasting ? 'Broadcasting' : 'Not Broadcasting',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Controls section (scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: isDark ? Colors.red[300] : Colors.red),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _errorMessage = null),
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.red,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
                  height: 80,
                  child: ElevatedButton.icon(
                    onPressed: _stopBroadcasting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.stop, size: 28),
                    label: const Text(
                      'Stop Broadcasting',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ] else ...[
                // Start button
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: ElevatedButton.icon(
                    onPressed: _startBroadcasting,
                    icon: const Icon(Icons.play_arrow, size: 28),
                    label: const Text(
                      'Start Broadcasting',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],

            // Permission reminder
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'For broadcasting to work, allow Location (Always) and Notifications in your phone settings.',
                      style: TextStyle(
                        color: isDark ? Colors.blue[200] : Colors.blue[800],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Event info
            _InfoRow(
              label: 'Event ID',
              value: event.id,
              onCopy: () => _copyToClipboard(event.id, 'Event ID'),
              isDark: isDark,
            ),
            _InfoRow(
              label: 'Event Link',
              value: AppConfig.getEventShareUrl(event.id),
              onCopy: _copyEventLink,
              isDark: isDark,
              isLink: true,
            ),

            const SizedBox(height: 16),

            // Background permission info
            if (!_hasBackgroundPermission && isActive) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: isDark ? Colors.amber[300] : Colors.amber[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Background Location',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.amber[300] : Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Grant "Allow all the time" location permission for broadcasting to continue when your phone is locked.',
                      style: TextStyle(color: isDark ? Colors.amber[200] : Colors.amber[900], fontSize: 13),
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
              const SizedBox(height: 16),
            ],

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onCopy;
  final bool isDark;
  final bool isLink;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.onCopy,
    required this.isDark,
    this.isLink = false,
  });

  String _truncateLink(String link) {
    // Remove https:// prefix and truncate if too long
    String display = link.replaceFirst('https://', '');
    if (display.length > 28) {
      return '${display.substring(0, 25)}...';
    }
    return display;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    isLink ? _truncateLink(value) : value,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isLink ? Theme.of(context).colorScheme.primary : valueColor,
                      fontSize: isLink ? 13 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onCopy != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onCopy,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;

  const _MapButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? Colors.green : Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isPrimary ? Colors.white : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.grey[700], size: 22),
        ),
      ),
    );
  }
}
