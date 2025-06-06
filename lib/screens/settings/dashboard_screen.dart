// Removed import for time_weather.dart
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/utils/ui_perfs.dart';
import 'package:agixt/utils/timezone_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for MethodChannel
// import 'package:shared_preferences/shared_preferences.dart'; // Removed import

class DashboardSettingsPage extends StatefulWidget {
  const DashboardSettingsPage({super.key});

  @override
  DashboardSettingsPageState createState() => DashboardSettingsPageState();
}

class DashboardSettingsPageState extends State<DashboardSettingsPage> {
  bool _is24HourFormat = UiPerfs.singleton.timeFormat == TimeFormat.TWENTY_FOUR_HOUR; // Corrected enum value
  String _selectedTimezone = UiPerfs.singleton.timezone;
  final BluetoothManager _bluetoothManager = BluetoothManager(); // Added BluetoothManager instance
  late List<String> _timezones;

  // Removed Weather Provider State variables

  @override
  void initState() {
    super.initState();
    _timezones = TimezoneHelper.getTimezones();
    _loadSettings();
  }

  // Load settings from UiPerfs
  void _loadSettings() {
    setState(() {
      _is24HourFormat = UiPerfs.singleton.timeFormat == TimeFormat.TWENTY_FOUR_HOUR; // Corrected enum value
      _selectedTimezone = UiPerfs.singleton.timezone;
      // Removed weather provider package name loading and validation
      // Removed _isCelsius update
    });
  }

  // Removed _fetchWeatherProviders method

  // Save settings to UiPerfs and trigger update
  Future<void> _saveSettingsAndTriggerUpdate() async {
    UiPerfs.singleton.timeFormat = _is24HourFormat
        ? TimeFormat.TWENTY_FOUR_HOUR // Corrected enum value
        : TimeFormat.TWELVE_HOUR; // Corrected enum value
    UiPerfs.singleton.timezone = _selectedTimezone;
  // Removed temperature unit saving
  // await UiPerfs.singleton.save(); // Removed explicit save call (assuming setters handle it)
  // Trigger dashboard update via Bluetooth
  _bluetoothManager.sync(); // Correct method is sync()
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Time Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: _is24HourFormat
                  ? Text('24-hour time format')
                  : Text('12-hour time format'),
              value: _is24HourFormat,
              onChanged: (bool value) {
                setState(() {
                  _is24HourFormat = value;
                });
                _saveSettingsAndTriggerUpdate(); // Call updated save function
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Time Zone',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedTimezone,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              isExpanded: true,
              items: _timezones.map((String timezone) {
                return DropdownMenuItem<String>(
                  value: timezone,
                  child: Text(
                    TimezoneHelper.getTimezoneDisplayName(timezone),
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedTimezone = newValue;
                  });
                  _saveSettingsAndTriggerUpdate();
                }
              },
            ),
            // Removed Weather Format (Celsius/Fahrenheit) SwitchListTile
            // Removed Weather Provider section and selector UI
          ],
        ),
      ),
    );
  }

  // Removed _buildWeatherProviderSelector method
}
