import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocationService {
  static const String _locationKey = 'user_location';

  // Check if location permission is granted
  Future<bool> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkPermission();
      if (!hasPermission) {
        return null;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Get address from coordinates using Google Geocoding API
  Future<Map<String, dynamic>?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      // Use geocoding package
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        String city = place.locality ?? place.subAdministrativeArea ?? '';
        String state = place.administrativeArea ?? '';
        String country = place.country ?? '';
        String postalCode = place.postalCode ?? '';
        String street = place.street ?? '';
        String subLocality = place.subLocality ?? '';

        String fullAddress = '';
        if (street.isNotEmpty) fullAddress += '$street, ';
        if (subLocality.isNotEmpty) fullAddress += '$subLocality, ';
        if (city.isNotEmpty) fullAddress += '$city, ';
        if (state.isNotEmpty) fullAddress += '$state ';
        if (postalCode.isNotEmpty) fullAddress += '$postalCode, ';
        if (country.isNotEmpty) fullAddress += country;

        return {
          'latitude': latitude,
          'longitude': longitude,
          'city': city,
          'state': state,
          'country': country,
          'postalCode': postalCode,
          'street': street,
          'subLocality': subLocality,
          'fullAddress': fullAddress.trim(),
          'region': '$city, $state',
        };
      }
      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  // Save location to shared preferences
  Future<void> saveLocation(Map<String, dynamic> locationData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_locationKey, json.encode(locationData));
    } catch (e) {
      print('Error saving location: $e');
    }
  }

  // Get saved location
  Future<Map<String, dynamic>?> getSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? locationString = prefs.getString(_locationKey);
      if (locationString != null) {
        return json.decode(locationString);
      }
      return null;
    } catch (e) {
      print('Error getting saved location: $e');
      return null;
    }
  }

  // Check if location is already saved
  Future<bool> hasLocation() async {
    final location = await getSavedLocation();
    return location != null;
  }

  // Clear saved location
  Future<void> clearLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_locationKey);
    } catch (e) {
      print('Error clearing location: $e');
    }
  }

  // Get region-specific cost multiplier
  double getCostMultiplier(String? region) {
    if (region == null) return 1.0;

    String regionLower = region.toLowerCase();

    // USA regions with higher costs
    if (regionLower.contains('california') ||
        regionLower.contains('new york') ||
        regionLower.contains('san francisco') ||
        regionLower.contains('los angeles') ||
        regionLower.contains('seattle') ||
        regionLower.contains('boston') ||
        regionLower.contains('washington')) {
      return 1.5; // 50% higher
    }

    // European major cities
    if (regionLower.contains('london') ||
        regionLower.contains('paris') ||
        regionLower.contains('zurich') ||
        regionLower.contains('geneva') ||
        regionLower.contains('oslo')) {
      return 1.6; // 60% higher
    }

    // Asian major cities
    if (regionLower.contains('tokyo') ||
        regionLower.contains('singapore') ||
        regionLower.contains('hong kong') ||
        regionLower.contains('seoul')) {
      return 1.4; // 40% higher
    }

    // Australian cities
    if (regionLower.contains('sydney') ||
        regionLower.contains('melbourne')) {
      return 1.3; // 30% higher
    }

    // Indian metro cities
    if (regionLower.contains('mumbai') ||
        regionLower.contains('delhi') ||
        regionLower.contains('bangalore') ||
        regionLower.contains('bengaluru') ||
        regionLower.contains('chennai') ||
        regionLower.contains('hyderabad') ||
        regionLower.contains('pune')) {
      return 0.3; // Lower cost (30% of base)
    }

    // Indian tier 2 cities
    if (regionLower.contains('india') ||
        regionLower.contains('karnataka') ||
        regionLower.contains('maharashtra') ||
        regionLower.contains('tamil nadu')) {
      return 0.25; // Even lower (25% of base)
    }

    // Default multiplier
    return 1.0;
  }

  // Get region-specific labor rates
  String getLaborRateInfo(String? region) {
    if (region == null) return 'Standard rates apply';

    String regionLower = region.toLowerCase();

    if (regionLower.contains('india')) {
      return 'Indian market rates (₹500-1500/day per worker)';
    } else if (regionLower.contains('united states') ||
        regionLower.contains('usa') ||
        regionLower.contains('california') ||
        regionLower.contains('new york')) {
      return 'US market rates (\$150-300/day per worker)';
    } else if (regionLower.contains('united kingdom') ||
        regionLower.contains('london')) {
      return 'UK market rates (£120-250/day per worker)';
    } else if (regionLower.contains('australia')) {
      return 'Australian market rates (A\$200-350/day per worker)';
    }

    return 'Local market rates apply';
  }
}
