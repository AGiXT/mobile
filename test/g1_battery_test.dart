import 'package:flutter_test/flutter_test.dart';
import 'package:agixt/models/g1/battery.dart';
import 'package:agixt/models/g1/glass.dart';

void main() {
  group('G1 Battery Tests', () {
    test('Battery info parsing from protocol data', () {
      // Test data based on the protocol documentation
      // Response: [0x2C, 0x66, batteryPercentage, voltage, charging, ...]
      List<int> leftBatteryData = [0x2C, 0x66, 85, 0xe6, 0x01]; // 85%, charging
      List<int> rightBatteryData = [
        0x2C,
        0x66,
        64,
        0xef,
        0x00
      ]; // 64%, not charging

      // Parse left battery
      final leftBattery =
          G1BatteryInfo.fromResponse(leftBatteryData, GlassSide.left);
      expect(leftBattery, isNotNull);
      expect(leftBattery!.percentage, equals(85));
      expect(leftBattery.voltage, equals(0xe6));
      expect(leftBattery.isCharging, isTrue);
      expect(leftBattery.side, equals(GlassSide.left));

      // Parse right battery
      final rightBattery =
          G1BatteryInfo.fromResponse(rightBatteryData, GlassSide.right);
      expect(rightBattery, isNotNull);
      expect(rightBattery!.percentage, equals(64));
      expect(rightBattery.voltage, equals(0xef));
      expect(rightBattery.isCharging, isFalse);
      expect(rightBattery.side, equals(GlassSide.right));
    });

    test('Battery status text generation', () {
      final highBattery = G1BatteryInfo(
        percentage: 85,
        voltage: 230,
        isCharging: false,
        side: GlassSide.left,
        timestamp: DateTime.now(),
      );

      final lowBattery = G1BatteryInfo(
        percentage: 15,
        voltage: 200,
        isCharging: false,
        side: GlassSide.right,
        timestamp: DateTime.now(),
      );

      final criticalBattery = G1BatteryInfo(
        percentage: 5,
        voltage: 180,
        isCharging: true,
        side: GlassSide.left,
        timestamp: DateTime.now(),
      );

      expect(highBattery.statusText, equals('Very Good'));
      expect(lowBattery.statusText, equals('Very Low'));
      expect(criticalBattery.statusText, equals('Charging'));
    });

    test('Battery status aggregation', () {
      final leftBattery = G1BatteryInfo(
        percentage: 85,
        voltage: 230,
        isCharging: false,
        side: GlassSide.left,
        timestamp: DateTime.now(),
      );

      final rightBattery = G1BatteryInfo(
        percentage: 64,
        voltage: 220,
        isCharging: true,
        side: GlassSide.right,
        timestamp: DateTime.now(),
      );

      final status = G1BatteryStatus(
        leftBattery: leftBattery,
        rightBattery: rightBattery,
        lastUpdated: DateTime.now(),
      );

      expect(status.hasData, isTrue);
      expect(status.lowestBatteryPercentage, equals(64));
      expect(status.isAnyCharging, isTrue);
    });

    test('Invalid battery data handling', () {
      // Test with insufficient data
      List<int> shortData = [0x2C, 0x66];
      final result = G1BatteryInfo.fromResponse(shortData, GlassSide.left);
      expect(result, isNull);

      // Test with wrong command
      List<int> wrongCommand = [0x25, 0x66, 85, 0xe6, 0x01];
      final result2 = G1BatteryInfo.fromResponse(wrongCommand, GlassSide.left);
      expect(result2, isNull);
    });

    test('Battery status with single glass', () {
      final leftOnly = G1BatteryStatus(
        leftBattery: G1BatteryInfo(
          percentage: 75,
          voltage: 225,
          isCharging: false,
          side: GlassSide.left,
          timestamp: DateTime.now(),
        ),
        rightBattery: null,
        lastUpdated: DateTime.now(),
      );

      expect(leftOnly.hasData, isTrue);
      expect(leftOnly.lowestBatteryPercentage, equals(75));
      expect(leftOnly.isAnyCharging, isFalse);
    });

    test('Battery percentage accuracy from 0 to 100', () {
      // Test all possible battery percentages to ensure accuracy
      for (int i = 0; i <= 100; i++) {
        final response = [0x2C, 0x66, i, 200, 0x00]; // battery response with i%
        final batteryInfo =
            G1BatteryInfo.fromResponse(response, GlassSide.left);

        expect(batteryInfo, isNotNull);
        expect(batteryInfo!.percentage, equals(i));
      }
    });

    test('Battery percentage clamping for invalid values', () {
      // Test that values over 100 are clamped to 100
      final highResponse = [0x2C, 0x66, 150, 200, 0x00];
      final highBattery =
          G1BatteryInfo.fromResponse(highResponse, GlassSide.left);
      expect(highBattery!.percentage, equals(100));

      // Test that negative values (represented as unsigned bytes > 127) are handled
      final negativeResponse = [0x2C, 0x66, 255, 200, 0x00];
      final negativeBattery =
          G1BatteryInfo.fromResponse(negativeResponse, GlassSide.left);
      expect(negativeBattery!.percentage,
          equals(100)); // 255 will be clamped to 100
    });
  });
}
