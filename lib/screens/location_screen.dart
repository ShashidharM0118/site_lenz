import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  String _statusMessage = 'Please allow location access';
  Map<String, dynamic>? _locationData;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    _checkExistingLocation();
  }

  Future<void> _checkExistingLocation() async {
    final hasLocation = await _locationService.hasLocation();
    if (hasLocation && mounted) {
      // Location already exists, navigate directly to main screen
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Requesting location permission...';
    });

    try {
      // Get current position
      Position? position = await _locationService.getCurrentLocation();

      if (position == null) {
        setState(() {
          _statusMessage = 'Failed to get location. Please enable location services.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Getting your address...';
      });

      // Get address from coordinates
      Map<String, dynamic>? addressData =
          await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (addressData == null) {
        setState(() {
          _statusMessage = 'Failed to get address. Please try again.';
          _isLoading = false;
        });
        return;
      }

      // Save location
      await _locationService.saveLocation(addressData);

      setState(() {
        _locationData = addressData;
        _statusMessage = 'Location saved successfully!';
      });

      // Wait a moment to show success message
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        // Navigate to main screen
        Navigator.of(context).pushReplacementNamed('/main');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF5F259F),
              const Color(0xFF5F259F).withOpacity(0.8),
              const Color(0xFFB8E600).withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Location Icon
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Title
                    const Text(
                      'Enable Location',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      'We need your location to provide accurate cost estimates and local contractor recommendations based on your area',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Status Message
                    if (_isLoading || _locationData != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (_isLoading)
                              const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            const SizedBox(height: 12),
                            Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_locationData != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _locationData!['fullAddress'] ?? '',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    const SizedBox(height: 40),

                    // Get Location Button
                    if (!_isLoading && _locationData == null)
                      ElevatedButton(
                        onPressed: _getLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB8E600),
                          foregroundColor: const Color(0xFF5F259F),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: Colors.black.withOpacity(0.3),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'GET MY LOCATION',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Skip Button (optional)
                    if (!_isLoading && _locationData == null)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/main');
                        },
                        child: Text(
                          'Skip for now',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                    const Spacer(),

                    // Info text
                    Text(
                      'Your location is stored locally and used only for\ngenerating accurate cost estimates',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
