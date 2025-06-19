import 'package:flutter/foundation.dart';
import 'bluetooth_manager.dart';
import 'weather_service.dart';
import '../utils/ui_perfs.dart';

/// Utility class for synchronizing time with the Even Realities G1 glasses
class TimeSync {
  static int _sequenceNumber = 0;

  /// This function synchronizes the current system time with the glasses
  /// and sets current weather information.
  static Future<void> updateTimeAndWeather() async {
    final bluetoothManager = BluetoothManager.singleton;
    final weatherService = WeatherService();

    if (!bluetoothManager.isConnected) {
      debugPrint('Cannot update time and weather: Glasses not connected');
      return;
    }

    debugPrint('Updating time and weather on glasses');

    // Get current system time in local timezone
    final now = DateTime.now();

    // Calculate timezone offset and adjust the epoch time
    // Add the timezone offset to the UTC time to get the local time display
    final timezoneOffsetSeconds = now.timeZoneOffset.inSeconds;
    final utcSeconds = (now.toUtc().millisecondsSinceEpoch ~/ 1000);
    final utcMilliseconds = now.toUtc().millisecondsSinceEpoch;

    // Add offset to make glasses display local time
    final epochSeconds = utcSeconds + timezoneOffsetSeconds;
    final epochMilliseconds = utcMilliseconds + (timezoneOffsetSeconds * 1000);

    debugPrint('Local time: $now');
    debugPrint('UTC time: ${now.toUtc()}');
    debugPrint(
        'Timezone offset: ${now.timeZoneOffset} (${timezoneOffsetSeconds}s)');
    debugPrint('Adjusted epoch seconds: $epochSeconds');
    debugPrint('Adjusted epoch milliseconds: $epochMilliseconds');
    debugPrint(
        'Expected display time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');

    // Get current weather data
    int weatherIconId = 0x10; // Default to sunny
    int temperature = 21; // Default temperature (always in Celsius for BLE)
    int temperatureUnit = 0; // 0 = Celsius, 1 = Fahrenheit
    
    try {
      final weatherData = await weatherService.getCurrentWeather();
      if (weatherData != null) {
        weatherIconId = weatherService.getG1WeatherIconId(weatherData.main, weatherData.isDay);
        
        // Always send temperature in Celsius to glasses (as per protocol)
        // The C/F flag tells glasses how to display it
        temperature = weatherData.temperature.round();
        
        // Set display unit preference
        if (UiPerfs.singleton.temperatureUnit == TemperatureUnit.FAHRENHEIT) {
          temperatureUnit = 1; // Fahrenheit display
        } else {
          temperatureUnit = 0; // Celsius display
        }
        
        debugPrint('Weather data: ${weatherData.summary}, Icon ID: 0x${weatherIconId.toRadixString(16)}, Temp: ${temperature}°C (display as ${temperatureUnit == 0 ? 'C' : 'F'})');
      } else {
        debugPrint('No weather data available, using defaults');
      }
    } catch (e) {
      debugPrint('Error fetching weather data, using defaults: $e');
    }

    // Increment and manage sequence number
    _sequenceNumber = (_sequenceNumber + 1) % 256;

    // Create byte buffer for the packet (21 bytes total)
    final buffer = ByteData(21);

    // Header
    buffer.setUint8(0, 0x06); // Command: Set Dashboard Settings
    buffer.setUint8(1, 21); // Length: total packet length
    buffer.setUint8(2, 0x00); // Pad
    buffer.setUint8(3, _sequenceNumber); // Sequence number

    // Payload
    buffer.setUint8(4, 0x01); // Subcommand: Set Time and Weather

    // Epoch Time (32-bit seconds) - little-endian
    buffer.setUint32(5, epochSeconds, Endian.little);

    // Epoch Time (64-bit milliseconds) - little-endian
    buffer.setUint64(9, epochMilliseconds, Endian.little);

    // Weather settings (using real weather data)
    buffer.setUint8(17, weatherIconId); // Weather Icon ID from weather service
    buffer.setUint8(18, temperature); // Temperature in Celsius (protocol requirement)
    buffer.setUint8(19, temperatureUnit); // C/F display flag: 0=Celsius, 1=Fahrenheit

    // Use user's time format preference
    final is24HourFormat =
        UiPerfs.singleton.timeFormat == TimeFormat.TWENTY_FOUR_HOUR;
    buffer.setUint8(20, is24HourFormat ? 0x01 : 0x00); // 24H/12H format

    // Convert to List<int> for sendCommandToGlasses
    final packet = buffer.buffer.asUint8List().toList();

    debugPrint(
        'Sending time sync packet: ${packet.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');

    // Send to both glasses as per protocol requirements
    await bluetoothManager.sendCommandToGlasses(packet);

    debugPrint('Time and weather update sent successfully');
  }
}
