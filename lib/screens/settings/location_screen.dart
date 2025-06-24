import 'dart:async';
import 'package:agixt/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  final LocationService _locationService = LocationService();
  bool _isLocationEnabled = false;
  bool _isLoading = false;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  Map<String, dynamic> _lastKnownPosition = {};
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    // Load location enabled setting
    final isEnabled = await _locationService.isLocationEnabled();

    // Load last known position
    final lastPosition = await _locationService.getLastPosition();

    // Get current position if enabled
    Position? currentPosition;
    if (isEnabled) {
      currentPosition = await _locationService.getCurrentPosition();
      _subscribeToLocationUpdates();
    }

    setState(() {
      _isLocationEnabled = isEnabled;
      _lastKnownPosition = lastPosition;
      _currentPosition = currentPosition;
      _isLoading = false;
    });
  }

  void _subscribeToLocationUpdates() {
    _positionStreamSubscription?.cancel();
    final stream = _locationService.getLocationStream();
    if (stream != null) {
      _positionStreamSubscription = stream.listen((Position position) {
        setState(() {
          _currentPosition = position;
        });
      });
    }
  }

  Future<void> _toggleLocationEnabled(bool value) async {
    setState(() {
      _isLoading = true;
    });

    // Request permission if turning on
    if (value) {
      final hasPermission = await _locationService.requestLocationPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission denied')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    // Update the setting
    await _locationService.setLocationEnabled(value);

    if (value) {
      // Get current position and subscribe to updates
      final currentPosition = await _locationService.getCurrentPosition();
      _subscribeToLocationUpdates();
      setState(() {
        _currentPosition = currentPosition;
      });
    } else {
      // Cancel subscription
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;
    }

    setState(() {
      _isLocationEnabled = value;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location toggle
                  SwitchListTile(
                    title: const Text('Enable Location'),
                    subtitle: const Text(
                      'Allow the app to access your device location',
                    ),
                    value: _isLocationEnabled,
                    onChanged: _toggleLocationEnabled,
                  ),

                  const Divider(height: 24),

                  // Current location section
                  if (_isLocationEnabled) ...[
                    const Text(
                      'Current Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Show map icon and coordinates
                    if (_currentPosition != null) ...[
                      _buildLocationCard(_currentPosition!),
                    ] else ...[
                      const Center(
                        child: Text('Waiting for location data...'),
                      ),
                    ],

                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                        });
                        final position =
                            await _locationService.getCurrentPosition();
                        setState(() {
                          _currentPosition = position;
                          _isLoading = false;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Location'),
                    ),

                    const Divider(height: 24),
                  ],

                  // Last known location section
                  if (_lastKnownPosition.isNotEmpty) ...[
                    const Text(
                      'Last Known Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.history, size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    LocationService.formatCoordinates(
                                      _lastKnownPosition['latitude'],
                                      _lastKnownPosition['longitude'],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_lastKnownPosition['timestamp'] != null)
                              Text(
                                'Recorded: ${_dateFormat.format(_lastKnownPosition['timestamp'])}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            if (_lastKnownPosition['altitude'] != null)
                              Text(
                                'Altitude: ${_lastKnownPosition['altitude'].toStringAsFixed(1)} m',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            if (_lastKnownPosition['accuracy'] != null)
                              Text(
                                'Accuracy: ±${_lastKnownPosition['accuracy'].toStringAsFixed(1)} m',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (!_isLocationEnabled) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Enable location to view your coordinates',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildLocationCard(Position position) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    LocationService.formatCoordinates(
                      position.latitude,
                      position.longitude,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Latitude: ${position.latitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Longitude: ${position.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Altitude: ${position.altitude.toStringAsFixed(1)} m',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Accuracy: ±${position.accuracy.toStringAsFixed(1)} m',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Time: ${_dateFormat.format(position.timestamp)}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
