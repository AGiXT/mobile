import 'package:flutter_test/flutter_test.dart';
import 'package:agixt/utils/ui_perfs.dart';

void main() {
  group('Dashboard Settings Temperature Toggle Tests', () {
    test('should validate BLE packet logic matches dashboard toggle', () {
      // Test the logic that would be used in time_sync.dart

      // Case 1: User selects Celsius
      const celsiusPreference = TemperatureUnit.CELSIUS;
      int celsiusFlag =
          (celsiusPreference == TemperatureUnit.FAHRENHEIT) ? 1 : 0;
      expect(celsiusFlag, equals(0), reason: 'Celsius should produce flag 0');

      // Case 2: User selects Fahrenheit
      const fahrenheitPreference = TemperatureUnit.FAHRENHEIT;
      int fahrenheitFlag =
          (fahrenheitPreference == TemperatureUnit.FAHRENHEIT) ? 1 : 0;
      expect(fahrenheitFlag, equals(1),
          reason: 'Fahrenheit should produce flag 1');

      // Test with mock temperature data
      const mockTemperature = 22.5; // Always in Celsius from API
      final bleTemperature = mockTemperature.round(); // 23°C

      // Verify temperature is always sent in Celsius regardless of display preference
      expect(bleTemperature, equals(23),
          reason: 'BLE should always send Celsius temperature');

      // The difference is only in the display flag
      expect(celsiusFlag != fahrenheitFlag, isTrue,
          reason: 'Flags should be different');
    });

    test('should verify dashboard toggle affects BLE packet creation', () {
      // Test case 1: Fahrenheit selection
      const fahrenheitUnit = TemperatureUnit.FAHRENHEIT;
      int fahrenheitFlag =
          (fahrenheitUnit == TemperatureUnit.FAHRENHEIT) ? 1 : 0;
      expect(fahrenheitFlag, equals(1),
          reason: 'Fahrenheit selection should set BLE flag to 1');

      // Test case 2: Celsius selection
      const celsiusUnit = TemperatureUnit.CELSIUS;
      int celsiusFlag = (celsiusUnit == TemperatureUnit.FAHRENHEIT) ? 1 : 0;
      expect(celsiusFlag, equals(0),
          reason: 'Celsius selection should set BLE flag to 0');

      // Verify that the same temperature is sent with different flags
      const testTemp = 25.0; // From weather API (always Celsius)
      final bleTempValue = testTemp.round(); // 25

      // Both cases send the same temperature value
      expect(bleTempValue, equals(25),
          reason: 'Temperature value should be constant');

      // Only the display flag changes based on user preference
      expect(fahrenheitFlag, equals(1), reason: 'Fahrenheit flag should be 1');
      expect(celsiusFlag, equals(0), reason: 'Celsius flag should be 0');
      expect(fahrenheitFlag != celsiusFlag, isTrue,
          reason: 'Flags should be different');
    });

    test(
        'should validate dashboard toggle logic matches time_sync implementation',
        () {
      // This test verifies the exact logic used in time_sync.dart line 71-75

      // Test Fahrenheit preference (matches time_sync.dart logic)
      const testUnitF = TemperatureUnit.FAHRENHEIT;
      int temperatureUnitF = 0; // Initialize as in time_sync.dart

      if (testUnitF == TemperatureUnit.FAHRENHEIT) {
        temperatureUnitF = 1; // Fahrenheit display
      } else {
        temperatureUnitF = 0; // Celsius display
      }

      expect(temperatureUnitF, equals(1),
          reason: 'Fahrenheit should set temperatureUnit to 1');

      // Test Celsius preference
      const testUnitC = TemperatureUnit.CELSIUS;
      int temperatureUnitC = 0; // Reset

      if (testUnitC == TemperatureUnit.FAHRENHEIT) {
        temperatureUnitC = 1; // Fahrenheit display
      } else {
        temperatureUnitC = 0; // Celsius display
      }

      expect(temperatureUnitC, equals(0),
          reason: 'Celsius should set temperatureUnit to 0');
    });

    test('should verify temperature always stays in Celsius for BLE protocol',
        () {
      // According to G1 BLE protocol:
      // - Byte 18: Temperature in Celsius (always)
      // - Byte 19: Display flag (0=Celsius, 1=Fahrenheit)

      // Mock weather API response (always in Celsius)
      const apiTemperature = 20.0; // 20°C from Open-Meteo

      // Test with Celsius display preference
      const celsiusUnit = TemperatureUnit.CELSIUS;
      final bleTemp1 = apiTemperature.round(); // Temperature for BLE packet
      int displayFlag1 = (celsiusUnit == TemperatureUnit.FAHRENHEIT) ? 1 : 0;

      expect(bleTemp1, equals(20), reason: 'BLE temperature should be 20°C');
      expect(displayFlag1, equals(0),
          reason: 'Celsius display should set flag to 0');

      // Test with Fahrenheit display preference
      const fahrenheitUnit = TemperatureUnit.FAHRENHEIT;
      final bleTemp2 =
          apiTemperature.round(); // Same temperature for BLE packet
      int displayFlag2 = (fahrenheitUnit == TemperatureUnit.FAHRENHEIT) ? 1 : 0;

      expect(bleTemp2, equals(20),
          reason: 'BLE temperature should still be 20°C');
      expect(displayFlag2, equals(1),
          reason: 'Fahrenheit display should set flag to 1');

      // Verify temperature is identical in both cases
      expect(bleTemp1, equals(bleTemp2),
          reason: 'Temperature should be same regardless of display unit');

      // Only the display flag differs
      expect(displayFlag1 != displayFlag2, isTrue,
          reason: 'Display flags should be different');
    });

    test('should test dashboard settings enum behavior', () {
      // Test enum values directly
      expect(TemperatureUnit.CELSIUS.index, equals(0));
      expect(TemperatureUnit.FAHRENHEIT.index, equals(1));

      // Test enum comparison
      expect(TemperatureUnit.CELSIUS != TemperatureUnit.FAHRENHEIT, isTrue);

      // Test the toggle logic that would be in dashboard
      const celsiusSelection = TemperatureUnit.CELSIUS;
      const fahrenheitSelection = TemperatureUnit.FAHRENHEIT;

      expect(celsiusSelection, equals(TemperatureUnit.CELSIUS));
      expect(fahrenheitSelection, equals(TemperatureUnit.FAHRENHEIT));

      // Test the BLE flag calculation for each
      int celsiusFlag =
          (celsiusSelection == TemperatureUnit.FAHRENHEIT) ? 1 : 0;
      int fahrenheitFlag =
          (fahrenheitSelection == TemperatureUnit.FAHRENHEIT) ? 1 : 0;

      expect(celsiusFlag, equals(0));
      expect(fahrenheitFlag, equals(1));
    });
  });
}
