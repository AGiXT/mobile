import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Stream controller for location updates
  StreamController<Position>? _locationController;
  Stream<Position>? _locationStream;
  StreamSubscription<Position>? _locationSubscription;

  // Keys for shared preferences
  static const String _locationEnabledKey = 'location_enabled';
  static const String _lastLatitudeKey = 'last_latitude';
  static const String _lastLongitudeKey = 'last_longitude';
  static const String _lastAltitudeKey = 'last_altitude';
  static const String _lastAccuracyKey = 'last_accuracy';
  static const String _lastTimestampKey = 'last_timestamp';

  // Check if location is enabled
  Future<bool> isLocationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_locationEnabledKey) ?? false;
  }

  // Set location enabled state
  Future<void> setLocationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationEnabledKey, enabled);

    if (enabled) {
      await startLocationUpdates();
    } else {
      await stopLocationUpdates();
    }
  }

  // Request location permission
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      return false;
    }

    // Permissions are granted
    return true;
  }

  // Get current position
  Future<Position?> getCurrentPosition(
      {Duration timeout = const Duration(seconds: 5)}) async {
    if (!await isLocationEnabled()) {
      return null;
    }

    if (!await requestLocationPermission()) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  // Save last known position
  Future<void> saveLastPosition(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lastLatitudeKey, position.latitude);
    await prefs.setDouble(_lastLongitudeKey, position.longitude);
    await prefs.setDouble(_lastAltitudeKey, position.altitude);
    await prefs.setDouble(_lastAccuracyKey, position.accuracy);
    await prefs.setInt(
        _lastTimestampKey, position.timestamp.millisecondsSinceEpoch);
  }

  // Get last known position
  Future<Map<String, dynamic>> getLastPosition() async {
    final prefs = await SharedPreferences.getInstance();

    final latitude = prefs.getDouble(_lastLatitudeKey);
    final longitude = prefs.getDouble(_lastLongitudeKey);
    final altitude = prefs.getDouble(_lastAltitudeKey);
    final accuracy = prefs.getDouble(_lastAccuracyKey);
    final timestamp = prefs.getInt(_lastTimestampKey);

    if (latitude == null || longitude == null) {
      return {};
    }

    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'timestamp': timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null,
    };
  }

  // Start location updates
  Future<void> startLocationUpdates() async {
    if (!await requestLocationPermission()) {
      return;
    }

    _locationController = StreamController<Position>.broadcast();
    _locationStream = _locationController?.stream;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      _locationController?.add(position);
      saveLastPosition(position);
    });
  }

  // Stop location updates
  Future<void> stopLocationUpdates() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await _locationController?.close();
    _locationController = null;
    _locationStream = null;
  }

  // Get location stream
  Stream<Position>? getLocationStream() {
    return _locationStream;
  }

  // Format coordinates as a readable string
  static String formatCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'Unknown';
    }

    String latDirection = latitude >= 0 ? 'N' : 'S';
    String lonDirection = longitude >= 0 ? 'E' : 'W';

    return '${latitude.abs().toStringAsFixed(6)}° $latDirection, ${longitude.abs().toStringAsFixed(6)}° $lonDirection';
  }
}
