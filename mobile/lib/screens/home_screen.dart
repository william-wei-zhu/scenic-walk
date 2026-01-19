import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../services/background_service.dart';
import 'add_event_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadEvents();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadEvents,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      // Logo placeholder - using icon for now
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.directions_walk,
                          size: 64,
                          color: Color(0xFF059669),
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
                              color: Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _navigateToAddEvent,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Event'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Events list
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_events.isEmpty)
                SliverFillRemaining(
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
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add an event to start broadcasting your location.',
                            style: TextStyle(color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        );
                      },
                      childCount: _events.length,
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

class _EventCard extends StatelessWidget {
  final SavedEvent event;
  final WalkEvent? details;
  final bool isBroadcasting;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _EventCard({
    required this.event,
    required this.details,
    required this.isBroadcasting,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = details?.isActive ?? false;
    final eventNotFound = details == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: eventNotFound ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
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
                    Text(
                      event.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatusBadge(
                          label: isBroadcasting
                              ? 'Broadcasting'
                              : eventNotFound
                                  ? 'Not Found'
                                  : isActive
                                      ? 'Active'
                                      : 'Ended',
                          color: isBroadcasting
                              ? Colors.green
                              : eventNotFound
                                  ? Colors.red
                                  : isActive
                                      ? Colors.blue
                                      : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ID: ${event.id}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 20),
                color: Colors.grey[400],
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
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
