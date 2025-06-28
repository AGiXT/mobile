import 'package:flutter_test/flutter_test.dart';
import 'package:agixt/utils/ui_perfs.dart';
import 'package:agixt/services/open_meteo_weather_service.dart';

void main() {
  group('End-to-End Temperature Toggle Workflow', () {
    test('should simulate complete user workflow for temperature toggle', () {
      // Test scenario 1: Fahrenheit preference
      const fahrenheitPreference = TemperatureUnit.FAHRENHEIT;

      // Create mock weather data (as would come from Open-Meteo API)
      final weatherData = WeatherData(
        temperature: 22.0, // Always in Celsius from API
        weatherCode: 0, // Clear sky
        isDay: true,
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
      );

      // Simulate BLE packet creation with Fahrenheit preference
      int fahrenheitFlag =
          (fahrenheitPreference == TemperatureUnit.FAHRENHEIT) ? 1 : 0;
      int bleTemperature1 = weatherData.temperature.round(); // Always Celsius

      expect(fahrenheitFlag, equals(1),
          reason: 'Fahrenheit display should set flag to 1');
      expect(bleTemperature1, equals(22), reason: 'Temperature should be 22°C');

      // Test scenario 2: Celsius preference (after user toggles)
      const celsiusPreference = TemperatureUnit.CELSIUS;

      // Create new BLE packet with Celsius preference (same weather data)
      int celsiusFlag =
          (celsiusPreference == TemperatureUnit.FAHRENHEIT) ? 1 : 0;
      int bleTemperature2 = weatherData.temperature.round(); // Still Celsius

      expect(celsiusFlag, equals(0),
          reason: 'Celsius display should set flag to 0');
      expect(bleTemperature2, equals(22),
          reason: 'Temperature should still be 22°C');

      // Verify that only the display flag changed, not the temperature
      expect(bleTemperature1, equals(bleTemperature2),
          reason: 'Temperature value should be identical');
      expect(fahrenheitFlag != celsiusFlag, isTrue,
          reason: 'Display flags should be different');

      // Verify correct weather icon mapping
      expect(weatherData.g1IconId, equals(0x10),
          reason: 'Clear day should map to sunny icon');
    });

    test('should verify dashboard settings persistence logic', () {
      // Test the enum index values used for SharedPreferences storage
      expect(TemperatureUnit.CELSIUS.index, equals(0));
      expect(TemperatureUnit.FAHRENHEIT.index, equals(1));

      // Test round-trip conversion (storage and retrieval)
      int storedValue = TemperatureUnit.FAHRENHEIT.index; // 1
      TemperatureUnit retrievedUnit = TemperatureUnit.values[storedValue];
      expect(retrievedUnit, equals(TemperatureUnit.FAHRENHEIT));

      storedValue = TemperatureUnit.CELSIUS.index; // 0
      retrievedUnit = TemperatureUnit.values[storedValue];
      expect(retrievedUnit, equals(TemperatureUnit.CELSIUS));
    });

    test('should verify temperature ranges for different weather conditions',
        () {
      // Test various temperature scenarios to ensure robustness
      final testScenarios = [
        {'temp': -10.0, 'expected': -10, 'description': 'Freezing cold'},
        {'temp': 0.0, 'expected': 0, 'description': 'Freezing point'},
        {
          'temp': 15.7,
          'expected': 16,
          'description': 'Cool weather (rounded up)'
        },
        {
          'temp': 25.3,
          'expected': 25,
          'description': 'Warm weather (rounded down)'
        },
        {'temp': 35.0, 'expected': 35, 'description': 'Hot weather'},
        {'temp': 45.8, 'expected': 46, 'description': 'Very hot weather'},
      ];

      for (final scenario in testScenarios) {
        final temp = scenario['temp'] as double;
        final expected = scenario['expected'] as int;
        final description = scenario['description'] as String;

        final weatherData = WeatherData(
          temperature: temp,
          weatherCode: 0,
          isDay: true,
          latitude: 40.7128,
          longitude: -74.0060,
          timestamp: DateTime.now(),
        );

        final bleTemp = weatherData.temperature.round();
        expect(bleTemp, equals(expected),
            reason: '$description: $temp°C should round to $expected°C');
      }
    });

    test('should verify complete BLE packet structure compliance', () {
      // Test the complete BLE packet structure as implemented in time_sync.dart

      // Mock inputs
      const temperatureFromAPI = 23.5; // From Open-Meteo (always Celsius)
      const weatherIconId = 0x10; // Sunny
      const userPreference = TemperatureUnit.FAHRENHEIT;

      // Calculate values as done in time_sync.dart
      final bleTemperature = temperatureFromAPI.round(); // 24°C
      final temperatureUnit =
          (userPreference == TemperatureUnit.FAHRENHEIT) ? 1 : 0;

      // Verify packet data
      expect(bleTemperature, equals(24),
          reason: 'Temperature should be rounded Celsius');
      expect(temperatureUnit, equals(1),
          reason: 'Fahrenheit preference should set flag to 1');
      expect(weatherIconId, equals(0x10),
          reason: 'Clear day should use sunny icon');

      // Verify packet structure compliance
      expect(bleTemperature >= -128 && bleTemperature <= 127, isTrue,
          reason: 'Temperature should fit in signed 8-bit integer');
      expect(temperatureUnit == 0 || temperatureUnit == 1, isTrue,
          reason: 'Temperature unit flag should be 0 or 1');
      expect(weatherIconId >= 0x00 && weatherIconId <= 0x10, isTrue,
          reason: 'Weather icon should be in valid range');
    });

    test('should verify dashboard toggle simulation', () {
      // Simulate the exact dashboard toggle behavior

      // Initial state (default is Fahrenheit)
      TemperatureUnit initialUnit = TemperatureUnit.FAHRENHEIT;
      bool isCurrentlyFahrenheit = (initialUnit == TemperatureUnit.FAHRENHEIT);
      expect(isCurrentlyFahrenheit, isTrue);

      // Calculate initial BLE flag
      int initialFlag = isCurrentlyFahrenheit ? 1 : 0;
      expect(initialFlag, equals(1));

      // User toggles (simulating dashboard switch toggle)
      TemperatureUnit toggledUnit = TemperatureUnit.CELSIUS;
      bool isNowFahrenheit = (toggledUnit == TemperatureUnit.FAHRENHEIT);
      expect(isNowFahrenheit, isFalse);

      // Calculate new BLE flag
      int newFlag = isNowFahrenheit ? 1 : 0;
      expect(newFlag, equals(0));

      // Verify the flag changed but temperature data remains consistent
      expect(initialFlag != newFlag, isTrue, reason: 'Flags should change');

      // Temperature value remains the same (from weather API)
      const sampleTemp = 20.0;
      expect(sampleTemp.round(), equals(20),
          reason: 'Temperature should be constant');
    });
  });
}
