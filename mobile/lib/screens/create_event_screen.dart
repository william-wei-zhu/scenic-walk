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
      body: _isLoading
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
                          target: _initialPosition!,
                          zoom: 15,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        onTap: _onMapTap,
                        markers: _buildMarkers(),
                        polylines: _buildPolylines(),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
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
                            color: Colors.white.withOpacity(0.9),
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
                              const Icon(Icons.touch_app,
                                  size: 20, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _routePoints.isEmpty
                                      ? 'Tap on map to draw your route'
                                      : '${_routePoints.length} points • Tap to add more',
                                  style: const TextStyle(fontSize: 13),
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
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red, size: 20),
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

                          // PIN
                          TextFormField(
                            controller: _pinController,
                            decoration: const InputDecoration(
                              labelText: 'Organizer PIN',
                              hintText: '4-digit PIN',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: true,
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
                            height: 48,
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
