import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventIdController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoading = false;
  bool _showPin = false;
  String? _errorMessage;

  @override
  void dispose() {
    _eventIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _addEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final eventId = _eventIdController.text.trim();
    final pin = _pinController.text.trim();

    try {
      // Fetch event from Firebase
      final event = await FirebaseService.getEvent(eventId);

      if (event == null) {
        setState(() {
          _errorMessage = 'Event not found. Please check the Event ID.';
          _isLoading = false;
        });
        return;
      }

      // Verify PIN
      if (event.organizerPin != pin) {
        setState(() {
          _errorMessage = 'Invalid PIN. Please check and try again.';
          _isLoading = false;
        });
        return;
      }

      // Save to local storage
      await StorageService.saveEvent(SavedEvent(
        id: event.id,
        name: event.name,
        pin: pin,
        createdAt: event.createdAt,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${event.name}" to your events'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Event'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter the Event ID and organizer PIN to add an event to your list.',
                        style: TextStyle(color: isDark ? Colors.blue[200] : Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Event ID field
              Text(
                'Event ID',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _eventIdController,
                decoration: const InputDecoration(
                  hintText: 'Enter event ID (e.g., abc123)',
                  prefixIcon: Icon(Icons.tag),
                ),
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the event ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // PIN field with visibility toggle
              Text(
                'Organizer PIN',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pinController,
                decoration: InputDecoration(
                  hintText: 'Enter 4-digit PIN',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_showPin ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showPin = !_showPin),
                    tooltip: _showPin ? 'Hide PIN' : 'Show PIN',
                  ),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 4,
                obscureText: !_showPin,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the PIN';
                  }
                  if (value.length != 4) {
                    return 'PIN must be 4 digits';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _addEvent(),
              ),
              const SizedBox(height: 8),

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

              // Add button
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addEvent,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add Event'),
                ),
              ),

              const SizedBox(height: 24),

              // Help text
              Text(
                'You can find the Event ID and PIN from the event organizer or from the web app after creating an event.',
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
