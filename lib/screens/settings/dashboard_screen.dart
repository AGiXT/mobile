import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/services/time_sync.dart';
import 'package:agixt/utils/ui_perfs.dart';
import 'package:flutter/material.dart';

class DashboardSettingsPage extends StatefulWidget {
  const DashboardSettingsPage({super.key});

  @override
  DashboardSettingsPageState createState() => DashboardSettingsPageState();
}

class DashboardSettingsPageState extends State<DashboardSettingsPage> {
  bool _is24HourFormat =
      UiPerfs.singleton.timeFormat == TimeFormat.TWENTY_FOUR_HOUR;
  bool _isFahrenheit = 
      UiPerfs.singleton.temperatureUnit == TemperatureUnit.FAHRENHEIT;
  final BluetoothManager _bluetoothManager = BluetoothManager.singleton;
  bool _isUpdatingTime = false;
  bool _isUpdatingTemperature = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _is24HourFormat =
          UiPerfs.singleton.timeFormat == TimeFormat.TWENTY_FOUR_HOUR;
      _isFahrenheit = 
          UiPerfs.singleton.temperatureUnit == TemperatureUnit.FAHRENHEIT;
    });
  }

  Future<void> _saveSettingsAndTriggerUpdate() async {
    setState(() {
      _isUpdatingTime = true;
    });

    UiPerfs.singleton.timeFormat =
        _is24HourFormat ? TimeFormat.TWENTY_FOUR_HOUR : TimeFormat.TWELVE_HOUR;

    // Immediately update time format on glasses if connected
    if (_bluetoothManager.isConnected) {
      try {
        await TimeSync.updateTimeAndWeather();
        debugPrint('Time format updated on glasses instantly');

        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_is24HourFormat
                  ? 'Switched to 24-hour format on glasses'
                  : 'Switched to 12-hour format on glasses'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error updating time format on glasses: $e');

        // Show error feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update glasses time format'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Show glasses not connected message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Glasses not connected - format will be updated when connected'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    setState(() {
      _isUpdatingTime = false;
    });

    // Trigger full dashboard sync
    _bluetoothManager.sync();
  }

  Future<void> _saveTemperatureSettingsAndTriggerUpdate() async {
    setState(() {
      _isUpdatingTemperature = true;
    });

    UiPerfs.singleton.temperatureUnit =
        _isFahrenheit ? TemperatureUnit.FAHRENHEIT : TemperatureUnit.CELSIUS;

    // Immediately update temperature unit on glasses if connected
    if (_bluetoothManager.isConnected) {
      try {
        await TimeSync.updateTimeAndWeather();
        debugPrint('Temperature unit updated on glasses instantly');

        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isFahrenheit
                  ? 'Switched to Fahrenheit on glasses'
                  : 'Switched to Celsius on glasses'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error updating temperature unit on glasses: $e');

        // Show error feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update glasses temperature unit'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Show glasses not connected message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Glasses not connected - unit will be updated when connected'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    setState(() {
      _isUpdatingTemperature = false;
    });

    // Trigger full dashboard sync
    _bluetoothManager.sync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text(_is24HourFormat
                  ? '12-Hour Time Format'
                  : '24-Hour Time Format'),
              subtitle: _isUpdatingTime
                  ? const Row(
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Updating glasses...'),
                      ],
                    )
                  : null,
              value: _is24HourFormat,
              onChanged: _isUpdatingTime
                  ? null
                  : (bool value) {
                      setState(() {
                        _is24HourFormat = value;
                      });
                      _saveSettingsAndTriggerUpdate();
                    },
            ),
            SwitchListTile(
              title: Text(_isFahrenheit ? 'Fahrenheit' : 'Celsius'),
              subtitle: _isUpdatingTemperature
                  ? const Row(
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Updating glasses...'),
                      ],
                    )
                  : null,
              value: _isFahrenheit,
              onChanged: _isUpdatingTemperature
                  ? null
                  : (bool value) {
                      setState(() {
                        _isFahrenheit = value;
                      });
                      _saveTemperatureSettingsAndTriggerUpdate();
                    },
            ),
          ],
        ),
      ),
    );
  }
}
