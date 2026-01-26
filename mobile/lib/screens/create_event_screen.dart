import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();

  GoogleMapController? _mapController;
  final List<LatLng> _routePoints = [];
  LatLng? _initialPosition;
  bool _isLoading = true;
  bool _isCreating = false;
  bool _showPin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    final permissionResult = await LocationService.checkPermissions();
    if (!permissionResult.granted) {
      // Default to San Francisco if no permission
      setState(() {
        _initialPosition = const LatLng(37.7749, -122.4194);
        _isLoading = false;
      });
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _initialPosition = const LatLng(37.7749, -122.4194);
        _isLoading = false;
      });
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _routePoints.add(position);
    });
  }

  void _undoLastPoint() {
    if (_routePoints.isNotEmpty) {
      setState(() {
        _routePoints.removeLast();
      });
    }
  }

  void _clearRoute() {
    setState(() {
      _routePoints.clear();
    });
  }

  Future<void> _goToCurrentLocation() async {
    final permissionResult = await LocationService.checkPermissions();
    if (!permissionResult.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(permissionResult.message ?? 'Location permission required')),
        );
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 16),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
      }
    }
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_routePoints.length < 2) {
      setState(() {
        _errorMessage = 'Please draw a route with at least 2 points';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    final eventId = const Uuid().v4().substring(0, 8);
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();

    // Convert route points to list of maps
    final route = _routePoints
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList();

    try {
      final success = await FirebaseService.createEvent(
        id: eventId,
        name: name,
        organizerPin: pin,
        route: route,
      );

      if (!success) {
        setState(() {
          _errorMessage = 'Failed to create event. Please try again.';
          _isCreating = false;
        });
        return;
      }

      // Save to local storage
      await StorageService.saveEvent(SavedEvent(
        id: eventId,
        name: name,
        pin: pin,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event "$name" created!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isCreating = false;
      });
    }
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_routePoints.isNotEmpty) {
      // Start marker (green)
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: _routePoints.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start'),
      ));

      // End marker (red) if more than one point
      if (_routePoints.length > 1) {
        markers.add(Marker(
          markerId: const MarkerId('end'),
          position: _routePoints.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'End'),
        ));
      }
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_routePoints.length < 2) return {};

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: const Color(0xFF16a34a), // green-600
        width: 4,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        actions: [
          if (_routePoints.isNotEmpty)
            IconButton(
              onPressed: _undoLastPoint,
              icon: const Icon(Icons.undo),
              tooltip: 'Undo last point',
            ),
          if (_routePoints.isNotEmpty)
            IconButton(
              onPressed: _clearRoute,
              icon: const Icon(Icons.clear),
              tooltip: 'Clear route',
            ),
        ],
      ),
      body: _isLoading || _initialPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Map
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _initialPosition!,  // Safe: null check above
                          zoom: 15,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        onTap: _onMapTap,
                        markers: _buildMarkers(),
                        polylines: _buildPolylines(),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                      // My Location button
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Material(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                          elevation: 4,
                          child: InkWell(
                            onTap: _goToCurrentLocation,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.my_location, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'My Location',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Zoom controls
                      Positioned(
                        bottom: 16,
                        right: 16,
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
                      // Instructions overlay
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.grey[900] : Colors.white)?.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.touch_app,
                                size: 20,
                                color: isDark ? Colors.grey[400] : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _routePoints.isEmpty
                                      ? 'Tap on map to draw your route'
                                      : '${_routePoints.length} points • Tap to add more',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Form
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
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

                          // Event name
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Event Name',
                              hintText: 'e.g., Morning Park Walk',
                              prefixIcon: Icon(Icons.event),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an event name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // PIN with visibility toggle
                          TextFormField(
                            controller: _pinController,
                            decoration: InputDecoration(
                              labelText: 'Organizer PIN',
                              hintText: '4-digit PIN',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_showPin ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _showPin = !_showPin),
                                tooltip: _showPin ? 'Hide PIN' : 'Show PIN',
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: !_showPin,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a PIN';
                              }
                              if (value.length != 4) {
                                return 'PIN must be 4 digits';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Create button
                          SizedBox(
                            width: double.infinity,
                            height: 80,
                            child: ElevatedButton(
                              onPressed: _isCreating ? null : _createEvent,
                              child: _isCreating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Create Event'),
                            ),
                          ),
                          // Bottom padding for Android navigation bar
                          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
