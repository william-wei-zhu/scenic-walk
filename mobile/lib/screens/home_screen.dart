import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../main.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../services/background_service.dart';
import '../services/connectivity_service.dart';
import 'add_event_screen.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SavedEvent> _events = [];
  Map<String, WalkEvent?> _eventDetails = {};
  String? _broadcastingEventId;
  bool _isLoading = true;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _isOffline = !ConnectivityService.isConnected;
    _connectivitySubscription = ConnectivityService.onConnectivityChanged.listen((isConnected) {
      if (mounted) {
        setState(() => _isOffline = !isConnected);
        if (isConnected) {
          _loadEvents(); // Refresh when back online
        }
      }
    });
    _loadEvents();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    final events = await StorageService.getEvents();
    final broadcastingId = await StorageService.getBroadcastingEvent();
    final isServiceRunning = await BackgroundService.isRunning();

    // Fetch details for each event from Firebase
    final details = <String, WalkEvent?>{};
    for (final event in events) {
      details[event.id] = await FirebaseService.getEvent(event.id);
    }

    setState(() {
      _events = events;
      _eventDetails = details;
      // Only show as broadcasting if the service is actually running
      _broadcastingEventId = isServiceRunning ? broadcastingId : null;
      _isLoading = false;
    });
  }

  Future<void> _removeEvent(String eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Event'),
        content: const Text(
          'Are you sure you want to remove this event from your list? '
          'This will not delete the event itself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.removeEvent(eventId);
      _loadEvents();
    }
  }

  void _copyEventId(String eventId) {
    Clipboard.setData(ClipboardData(text: eventId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Event ID copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToCreateEvent() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CreateEventScreen()),
    );
    if (result == true) {
      _loadEvents();
    }
  }

  void _navigateToAddEvent() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddEventScreen()),
    );
    if (result == true) {
      _loadEvents();
    }
  }

  void _navigateToEventDetail(SavedEvent event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(savedEvent: event),
      ),
    );
    _loadEvents(); // Refresh on return
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadEvents,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Offline banner
              if (_isOffline)
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'You\'re offline. Some features may not work.',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final isConnected = await ConnectivityService.checkConnectivity();
                            if (isConnected) {
                              _loadEvents();
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Header with dark mode toggle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Dark mode toggle
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => themeService.toggleTheme(),
                          icon: Icon(
                            isDark ? Icons.light_mode : Icons.dark_mode,
                            color: isDark ? Colors.amber : Colors.grey[700],
                          ),
                          tooltip: isDark ? 'Light mode' : 'Dark mode',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Logo and title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Logo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SvgPicture.asset(
                          'assets/logo.svg',
                          width: 120,
                          height: 120,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Scenic Walk',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Never lose your walking group again.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Create Event button (primary)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _navigateToCreateEvent,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Event'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Add existing event button (secondary)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _navigateToAddEvent,
                          icon: const Icon(Icons.link),
                          label: const Text('Add Existing Event'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // My Events header
              if (_events.isNotEmpty || _isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'My Events',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                    ),
                  ),
                ),

              // Events list
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _SkeletonEventCard(isDark: isDark),
                      childCount: 2,
                    ),
                  ),
                )
              else if (_events.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_note,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No events yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create a new event or add an existing one to start broadcasting your location.',
                            style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final event = _events[index];
                        final details = _eventDetails[event.id];
                        final isBroadcasting = _broadcastingEventId == event.id;

                        return _EventCard(
                          event: event,
                          details: details,
                          isBroadcasting: isBroadcasting,
                          onTap: () => _navigateToEventDetail(event),
                          onRemove: () => _removeEvent(event.id),
                          onCopyId: () => _copyEventId(event.id),
                          formatDate: _formatDate,
                        );
                      },
                      childCount: _events.length,
                    ),
                  ),
                ),

              // Footer note
              if (_events.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Events are saved on this device only',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonEventCard extends StatelessWidget {
  final bool isDark;

  const _SkeletonEventCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final shimmerColor = isDark ? Colors.grey[700] : Colors.grey[300];
    final baseColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            // Content placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final SavedEvent event;
  final WalkEvent? details;
  final bool isBroadcasting;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onCopyId;
  final String Function(int) formatDate;

  const _EventCard({
    required this.event,
    required this.details,
    required this.isBroadcasting,
    required this.onTap,
    required this.onRemove,
    required this.onCopyId,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = details?.isActive ?? false;
    final eventNotFound = details == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: eventNotFound ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status indicator with icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isBroadcasting
                          ? Colors.green.withOpacity(0.1)
                          : eventNotFound
                              ? Colors.red.withOpacity(0.1)
                              : isActive
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isBroadcasting
                          ? Icons.broadcast_on_personal
                          : eventNotFound
                              ? Icons.error_outline
                              : isActive
                                  ? Icons.event_available
                                  : Icons.event_busy,
                      color: isBroadcasting
                          ? Colors.green
                          : eventNotFound
                              ? Colors.red
                              : isActive
                                  ? Colors.blue
                                  : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Event info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Created date
                            Text(
                              formatDate(event.createdAt),
                              style: TextStyle(
                                color: isDark ? Colors.grey[500] : Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Status badge with icon (colorblind accessible)
                        _StatusBadge(
                          label: isBroadcasting
                              ? 'Broadcasting'
                              : eventNotFound
                                  ? 'Not Found'
                                  : isActive
                                      ? 'Active'
                                      : 'Ended',
                          icon: isBroadcasting
                              ? Icons.sensors
                              : eventNotFound
                                  ? Icons.error
                                  : isActive
                                      ? Icons.check_circle
                                      : Icons.flag,
                          color: isBroadcasting
                              ? Colors.green
                              : eventNotFound
                                  ? Colors.red
                                  : isActive
                                      ? Colors.blue
                                      : Colors.grey,
                        ),
                      ],
                    ),
                  ),

                  // Remove button
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 20),
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ],
              ),

              // Event ID row with copy button
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800]?.withOpacity(0.5) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tag,
                      size: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.id,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onCopyId,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
