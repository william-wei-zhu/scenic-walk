import 'dart:async';
import 'package:flutter/material.dart';
import '../services/places_service.dart';

/// A search field widget with autocomplete dropdown for Google Places
class PlaceSearchField extends StatefulWidget {
  /// Called when a place is selected from the dropdown
  final void Function(double lat, double lng) onPlaceSelected;

  const PlaceSearchField({
    super.key,
    required this.onPlaceSelected,
  });

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  bool _showDropdown = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay hiding to allow tap on dropdown item
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() => _showDropdown = false);
        }
      });
    }
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();

    if (value.isEmpty) {
      setState(() {
        _predictions = [];
        _showDropdown = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchPlaces(value);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      print('PlaceSearchField: Searching for "$query"');
      final predictions = await PlacesService.autocomplete(query);
      print('PlaceSearchField: Got ${predictions.length} predictions');

      if (!mounted) return;

      setState(() {
        _predictions = predictions;
        _isLoading = false;
        _showDropdown = predictions.isNotEmpty;
      });
    } catch (e) {
      print('PlaceSearchField: Error searching: $e');
      if (!mounted) return;

      setState(() {
        _predictions = [];
        _isLoading = false;
        _showDropdown = false;
      });
    }
  }

  Future<void> _onPredictionSelected(PlacePrediction prediction) async {
    _focusNode.unfocus();

    setState(() {
      _controller.text = prediction.mainText;
      _predictions = [];
      _showDropdown = false;
      _isLoading = true;
    });

    try {
      final details = await PlacesService.getPlaceDetails(prediction.placeId);

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (details != null) {
        widget.onPlaceSelected(details.lat, details.lng);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search TextField
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onTextChanged,
          decoration: InputDecoration(
            hintText: 'Search for a location...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _predictions = [];
                            _showDropdown = false;
                          });
                        },
                      )
                    : null,
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF16a34a), width: 2),
            ),
          ),
          style: const TextStyle(fontSize: 14),
        ),

        // Dropdown suggestions
        if (_showDropdown && _predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return InkWell(
                  onTap: () => _onPredictionSelected(prediction),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prediction.mainText,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (prediction.secondaryText != null)
                                Text(
                                  prediction.secondaryText!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
