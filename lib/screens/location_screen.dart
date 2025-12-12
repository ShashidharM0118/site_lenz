import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class LocationScreen extends StatefulWidget {
  final VoidCallback onNext;
  
  const LocationScreen({
    Key? key,
    required this.onNext,
  }) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  bool _locationFetched = false;
  String _displayAddress = '';
  String _errorMessage = '';
  Map<String, dynamic>? _locationData;

  @override
  void initState() {
    super.initState();
    _checkExistingLocation();
  }

  Future<void> _checkExistingLocation() async {
    final existingLocation = await _locationService.getSavedLocation();
    if (existingLocation != null && mounted) {
      setState(() {
        _locationData = existingLocation;
        _displayAddress = existingLocation['fullAddress'] ?? 'Location saved';
        _locationFetched = true;
      });
    }
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Step 1: Get current position (GPS coordinates)
      final position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        setState(() {
          _errorMessage = 'Unable to get location. Check permissions and GPS.';
          _isLoading = false;
        });
        return;
      }

      // Step 2: Convert coordinates to address
      final locationData = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (locationData != null) {
        // Step 3: Save location
        await _locationService.saveLocation(locationData);
        
        if (mounted) {
          setState(() {
            _locationData = locationData;
            _displayAddress = locationData['fullAddress'] ?? 
                             '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
            _locationFetched = true;
            _isLoading = false;
          });
        }
      } else {
        // Coordinates fetched but address lookup failed - still save coordinates
        final basicLocation = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'fullAddress': '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
          'region': 'Unknown',
        };
        await _locationService.saveLocation(basicLocation);
        
        if (mounted) {
          setState(() {
            _locationData = basicLocation;
            _displayAddress = basicLocation['fullAddress'] as String;
            _locationFetched = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _handleNext() {
    if (_locationFetched) {
      widget.onNext();
    } else {
      setState(() {
        _errorMessage = 'Please fetch location before proceeding';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Location'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon
              Icon(
                Icons.location_on_outlined,
                size: 80,
                color: AppTheme.primaryPurple,
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Set Property Location',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Description
              Text(
                'Fetch the current location to adjust cost estimates for your region',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textGrey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Fetch Location Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchLocation,
                icon: _isLoading 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textDark),
                        ),
                      )
                    : const Icon(Icons.my_location, size: 24),
                label: Text(
                  _isLoading ? 'Fetching Location...' : 'Fetch Current Location',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: AppTheme.textDark,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Location Display Card
              if (_locationFetched) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryPurple, width: 2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Location Captured',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, color: AppTheme.primaryPurple, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _displayAddress,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_locationData != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Coordinates: ${_locationData!['latitude']?.toStringAsFixed(6)}, ${_locationData!['longitude']?.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Error Message
              if (_errorMessage.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              const Spacer(),
              
              // Next Button
              ElevatedButton(
                onPressed: _locationFetched ? _handleNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _locationFetched ? AppTheme.primaryPurple : AppTheme.borderGrey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: _locationFetched ? 4 : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Skip Button
              TextButton(
                onPressed: widget.onNext,
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
