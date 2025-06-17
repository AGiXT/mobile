import 'package:flutter/foundation.dart';
import 'bluetooth_manager.dart';
import '../utils/ui_perfs.dart';

/// Utility class for synchronizing time with the Even Realities G1 glasses
class TimeSync {
  static int _sequenceNumber = 0;

  /// This function synchronizes the current system time with the glasses
  /// and sets placeholder weather information.
  static Future<void> updateTimeAndWeather() async {
    final bluetoothManager = BluetoothManager.singleton;

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

    // Weather settings (placeholders)
    buffer.setUint8(17, 0x10); // Weather Icon ID: Sunny (0x10)
    buffer.setUint8(18, 21); // Temperature: 21°C
    buffer.setUint8(19, 0x00); // C/F: Celsius (0x00)

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
