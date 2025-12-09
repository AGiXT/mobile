import 'dart:async';
import 'package:agixt/services/location_service.dart';
import 'package:agixt/services/bluetooth_background_service.dart';
import 'package:agixt/utils/app_events.dart';
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
      if (!mounted) {
        return;
      }
      if (!hasPermission) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location permission denied')));
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
      if (!mounted) {
        return;
      }
      setState(() {
        _currentPosition = currentPosition;
      });
    } else {
      // Cancel subscription
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;
    }

    // Ensure background service continues to work with location changes
    await _handleBackgroundServiceLocationChange(value);

    // Notify other screens (like HomeScreen) that location settings changed
    AppEvents.notifyLocationSettingsChanged(value);

    if (!mounted) {
      return;
    }
    setState(() {
      _isLocationEnabled = value;
      _isLoading = false;
    });
  }

  /// Handle background service when location setting changes
  Future<void> _handleBackgroundServiceLocationChange(
    bool locationEnabled,
  ) async {
    try {
      debugPrint(
        'LocationSettingsScreen: Location setting changed to $locationEnabled',
      );

      // If location is now enabled, ensure background service is optimized for it
      if (locationEnabled) {
        debugPrint(
          'LocationSettingsScreen: Location enabled, ensuring background service is optimized',
        );

        // Request battery optimization exemption when location is enabled
        await BluetoothBackgroundService.requestBatteryOptimizationExemption();

        // Restart background service to ensure it handles location properly
        if (await BluetoothBackgroundService.isRunning()) {
          await BluetoothBackgroundService.stop();
          await Future.delayed(
            Duration(seconds: 2),
          ); // Wait a bit for service to stop
          await BluetoothBackgroundService.start();
        } else {
          await BluetoothBackgroundService.start();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location enabled. Background service optimized for location usage.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint(
          'LocationSettingsScreen: Location disabled, background service should continue normally',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location disabled. Background service continues normally.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint(
        'LocationSettingsScreen: Error handling background service location change: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Settings')),
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

                  // Information about location usage with AI and weather
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    margin: const EdgeInsets.only(top: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Privacy & Usage Information',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'When location is enabled, your precise coordinates are shared with the AI system to provide:',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Real-time weather data for your Even Realities G1 glasses',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Location-aware AI responses and recommendations',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your location is used to fetch current weather conditions from the Open-Meteo weather service and enhance AI interactions with location-specific context.',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_off,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Location Disabled',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Without location access, these features are unavailable:',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Real-time weather display on your Even Realities G1 glasses',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Location-based AI responses and recommendations',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Enable location to share your coordinates with the AI and access these features.',
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
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
