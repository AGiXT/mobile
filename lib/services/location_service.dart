import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agixt/services/secure_storage_service.dart';

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
  static const String _lastLocationKey = 'last_location_payload_v1';
  static const String _legacyLastLatitudeKey = 'last_latitude';
  static const String _legacyLastLongitudeKey = 'last_longitude';
  static const String _legacyLastAltitudeKey = 'last_altitude';
  static const String _legacyLastAccuracyKey = 'last_accuracy';
  static const String _legacyLastTimestampKey = 'last_timestamp';

  static final SecureStorageService _secureStorage = SecureStorageService();

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
    try {
      final timestamp = position.timestamp;
      final payload = jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'altitude': position.altitude,
        'accuracy': position.accuracy,
        'timestamp': timestamp.millisecondsSinceEpoch,
      });

      await _secureStorage.write(key: _lastLocationKey, value: payload);

      // Remove legacy plaintext keys once we successfully persisted the secure payload.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyLastLatitudeKey);
      await prefs.remove(_legacyLastLongitudeKey);
      await prefs.remove(_legacyLastAltitudeKey);
      await prefs.remove(_legacyLastAccuracyKey);
      await prefs.remove(_legacyLastTimestampKey);
    } catch (e) {
      debugPrint('Error saving last position: $e');
    }
  }

  // Get last known position
  Future<Map<String, dynamic>> getLastPosition() async {
    try {
      final stored = await _secureStorage.read(key: _lastLocationKey);
      Map<String, dynamic>? data;

      if (stored != null && stored.isNotEmpty) {
        data = jsonDecode(stored) as Map<String, dynamic>;
      } else {
        // Migrate legacy plaintext records if present.
        final prefs = await SharedPreferences.getInstance();
        final latitude = prefs.getDouble(_legacyLastLatitudeKey);
        final longitude = prefs.getDouble(_legacyLastLongitudeKey);
        if (latitude != null && longitude != null) {
          data = {
            'latitude': latitude,
            'longitude': longitude,
            'altitude': prefs.getDouble(_legacyLastAltitudeKey),
            'accuracy': prefs.getDouble(_legacyLastAccuracyKey),
            'timestamp': prefs.getInt(_legacyLastTimestampKey),
          };

          await _secureStorage.write(
            key: _lastLocationKey,
            value: jsonEncode(data),
          );

          await prefs.remove(_legacyLastLatitudeKey);
          await prefs.remove(_legacyLastLongitudeKey);
          await prefs.remove(_legacyLastAltitudeKey);
          await prefs.remove(_legacyLastAccuracyKey);
          await prefs.remove(_legacyLastTimestampKey);
        }
      }

      if (data == null) {
        return {};
      }

      final latitude = (data['latitude'] as num?)?.toDouble();
      final longitude = (data['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        return {};
      }

      final altitude = (data['altitude'] as num?)?.toDouble();
      final accuracy = (data['accuracy'] as num?)?.toDouble();
      final timestampRaw = data['timestamp'];
      DateTime? timestamp;
      if (timestampRaw is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(timestampRaw);
      } else if (timestampRaw is String) {
        timestamp = DateTime.tryParse(timestampRaw);
      }

      return {
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'accuracy': accuracy,
        'timestamp': timestamp,
      };
    } catch (e) {
      debugPrint('Error retrieving last location: $e');
      return {};
    }
  }

  // Start location updates
  Future<void> startLocationUpdates() async {
    try {
      if (!await requestLocationPermission()) {
        return;
      }

      _locationController ??= StreamController<Position>.broadcast();
      _locationStream ??= _locationController?.stream;

      await _locationSubscription?.cancel();
      _locationSubscription = null;

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _locationSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
        (Position position) {
          _locationController?.add(position);
          unawaited(saveLastPosition(position));
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Location stream error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting location updates: $e');
    }
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
