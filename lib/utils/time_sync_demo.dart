import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Test utility to demonstrate the Even Realities G1 time sync packet format
class TimeSyncDemo {
  static void demonstratePacketFormat() {
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
    
    print('Local time: $now');
    print('UTC time: ${now.toUtc()}');
    print('Timezone offset: ${now.timeZoneOffset} (${timezoneOffsetSeconds}s)');
    print('Adjusted epoch seconds: $epochSeconds');
    print('Adjusted epoch milliseconds: $epochMilliseconds');
    print('Expected display time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
    
    // Create sequence number
    int sequenceNumber = 42; // Example sequence number
    
    // Create byte buffer for the packet (21 bytes total)
    final buffer = ByteData(21);
    
    // Header
    buffer.setUint8(0, 0x06); // Command: Set Dashboard Settings
    buffer.setUint8(1, 21);   // Length: total packet length
    buffer.setUint8(2, 0x00); // Pad
    buffer.setUint8(3, sequenceNumber); // Sequence number
    
    // Payload
    buffer.setUint8(4, 0x01); // Subcommand: Set Time and Weather
    
    // Epoch Time (32-bit seconds) - little-endian
    buffer.setUint32(5, epochSeconds, Endian.little);
    
    // Epoch Time (64-bit milliseconds) - little-endian
    buffer.setUint64(9, epochMilliseconds, Endian.little);
    
    // Weather settings (placeholders)
    buffer.setUint8(17, 0x10); // Weather Icon ID: Sunny (0x10)
    buffer.setUint8(18, 21);   // Temperature: 21°C
    buffer.setUint8(19, 0x00); // C/F: Celsius (0x00)
    buffer.setUint8(20, 0x01); // 24H/12H: 24-hour format (0x01)
    
    // Convert to List<int>
    final packet = buffer.buffer.asUint8List().toList();
    
    // Print demonstration
    debugPrint('=== Even Realities G1 Time Sync Packet Demo ===');
    debugPrint('Current Time: ${now.toIso8601String()}');
    debugPrint('Epoch Seconds (32-bit): $epochSeconds');
    debugPrint('Epoch Milliseconds (64-bit): $epochMilliseconds');
    debugPrint('Sequence Number: $sequenceNumber');
    debugPrint('');
    debugPrint('Packet Structure:');
    debugPrint('Byte 0    : 0x${packet[0].toRadixString(16).padLeft(2, '0')} (Command: Set Dashboard Settings)');
    debugPrint('Byte 1    : 0x${packet[1].toRadixString(16).padLeft(2, '0')} (Length: ${packet[1]} bytes)');
    debugPrint('Byte 2    : 0x${packet[2].toRadixString(16).padLeft(2, '0')} (Pad)');
    debugPrint('Byte 3    : 0x${packet[3].toRadixString(16).padLeft(2, '0')} (Sequence: $sequenceNumber)');
    debugPrint('Byte 4    : 0x${packet[4].toRadixString(16).padLeft(2, '0')} (Subcommand: Set Time and Weather)');
    debugPrint('Bytes 5-8 : ${packet.sublist(5, 9).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')} (32-bit seconds)');
    debugPrint('Bytes 9-16: ${packet.sublist(9, 17).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')} (64-bit milliseconds)');
    debugPrint('Byte 17   : 0x${packet[17].toRadixString(16).padLeft(2, '0')} (Weather: Sunny)');
    debugPrint('Byte 18   : 0x${packet[18].toRadixString(16).padLeft(2, '0')} (Temperature: ${packet[18]}°C)');
    debugPrint('Byte 19   : 0x${packet[19].toRadixString(16).padLeft(2, '0')} (Unit: Celsius)');
    debugPrint('Byte 20   : 0x${packet[20].toRadixString(16).padLeft(2, '0')} (Format: 24H)');
    debugPrint('');
    debugPrint('Complete Packet: ${packet.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    debugPrint('');
    debugPrint('Expected Format: [0x06, 21, 0x00, SEQ, 0x01, S1, S2, S3, S4, M1, M2, M3, M4, M5, M6, M7, M8, 0x10, 21, 0x00, 0x01]');
    debugPrint('=== End Demo ===');
  }
}
