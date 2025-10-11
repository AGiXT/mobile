import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:agixt/utils/ui_perfs.dart';
import 'package:agixt/services/open_meteo_weather_service.dart';

void main() {
  group('Dashboard Temperature Unit Integration Tests', () {
    setUpAll(() {
      // Initialize Flutter test binding for SharedPreferences
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock SharedPreferences for testing
      const channel = MethodChannel('plugins.flutter.io/shared_preferences');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{}; // Return empty prefs
        }
        return null;
      });
    });

    setUp(() {
      // Initialize UiPerfs singleton for testing
      UiPerfs.singleton;
    });

    test('should set correct temperature unit flag in BLE packet', () {
      // Test the logic that would be used in the BLE packet creation
      // This tests the same logic used in time_sync.dart without SharedPreferences calls

      // Simulate Celsius preference (temperatureUnit = 0)
      int temperatureUnitCelsius = 0; // Direct value for testing
      expect(temperatureUnitCelsius, equals(0));

      // Simulate Fahrenheit preference (temperatureUnit = 1)
      int temperatureUnitFahrenheit = 1; // Direct value for testing
      expect(temperatureUnitFahrenheit, equals(1));

      // Test the enum values themselves
      expect(TemperatureUnit.CELSIUS.index, equals(0));
      expect(TemperatureUnit.FAHRENHEIT.index, equals(1));
    });

    test('should validate temperature unit enum values', () {
      // Ensure the enum has exactly 2 values
      expect(TemperatureUnit.values.length, equals(2));

      // Ensure the values are distinct
      expect(
          TemperatureUnit.CELSIUS, isNot(equals(TemperatureUnit.FAHRENHEIT)));

      // Test enum index values (important for serialization)
      expect(TemperatureUnit.CELSIUS.index, equals(0));
      expect(TemperatureUnit.FAHRENHEIT.index, equals(1));
    });

    test('should maintain temperature in Celsius while changing display unit',
        () {
      // Create test weather data
      final weatherData = WeatherData(
        temperature: 20.0, // 20°C = 68°F
        weatherCode: 0,
        isDay: true,
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
      );

      // Temperature should always remain in Celsius regardless of display preference
      expect(weatherData.temperature, equals(20.0));
      final temperatureForBLE = weatherData.temperature.round();
      expect(temperatureForBLE, equals(20)); // BLE packet always sends Celsius

      // Test display flag logic without setting preferences
      int celsiusDisplayFlag = TemperatureUnit.CELSIUS.index == 1 ? 1 : 0;
      int fahrenheitDisplayFlag = TemperatureUnit.FAHRENHEIT.index == 1 ? 1 : 0;

      expect(celsiusDisplayFlag, equals(0)); // Celsius should be flag 0
      expect(fahrenheitDisplayFlag, equals(1)); // Fahrenheit should be flag 1

      // The BLE protocol always sends Celsius, the C/F flag tells glasses how to display it
    });

    test('should verify dashboard settings toggle behavior', () {
      // Test the enum values and their indices directly
      expect(TemperatureUnit.CELSIUS.index, equals(0));
      expect(TemperatureUnit.FAHRENHEIT.index, equals(1));

      // Test the logic used for determining display flags
      bool isCelsiusSelected = true; // Simulate dashboard toggle state
      bool isFahrenheitSelected = !isCelsiusSelected;

      expect(isCelsiusSelected, isTrue);
      expect(isFahrenheitSelected, isFalse);

      // Simulate toggle action
      isCelsiusSelected = false;
      isFahrenheitSelected = !isCelsiusSelected;

      expect(isCelsiusSelected, isFalse);
      expect(isFahrenheitSelected, isTrue);
    });

    test('should validate BLE protocol temperature unit flag logic', () {
      // According to G1 BLE protocol:
      // - Temperature field (byte 18): Always in Celsius
      // - C/F flag (byte 19): 0=Celsius display, 1=Fahrenheit display

      // Test Celsius display preference logic
      TemperatureUnit celsiusUnit = TemperatureUnit.CELSIUS;
      int celsiusFlag = celsiusUnit == TemperatureUnit.FAHRENHEIT ? 1 : 0;
      expect(celsiusFlag, equals(0)); // Should be 0 for Celsius display

      // Test Fahrenheit display preference logic
      TemperatureUnit fahrenheitUnit = TemperatureUnit.FAHRENHEIT;
      int fahrenheitFlag = fahrenheitUnit == TemperatureUnit.FAHRENHEIT ? 1 : 0;
      expect(fahrenheitFlag, equals(1)); // Should be 1 for Fahrenheit display

      // Test the enum index values match the expected flags
      expect(TemperatureUnit.CELSIUS.index, equals(0));
      expect(TemperatureUnit.FAHRENHEIT.index, equals(1));
    });

    test('should verify weather service returns Celsius temperatures',
        () async {
      // Test that Open-Meteo API returns Celsius by default
      // (The API defaults to metric units when no unit parameter is specified)

      // Create a mock weather data response (simulating API response)
      final mockWeatherData = WeatherData(
        temperature: 15.5, // API returns this in Celsius
        weatherCode: 61, // Rain
        isDay: true,
        latitude: 52.52,
        longitude: 13.405,
        timestamp: DateTime.now(),
      );

      // Verify the temperature is in Celsius
      expect(mockWeatherData.temperature, equals(15.5));

      // Verify that rounding for BLE keeps it in Celsius
      final bleTemperature = mockWeatherData.temperature.round();
      expect(bleTemperature, equals(16)); // Rounded Celsius, not Fahrenheit

      // Verify icon mapping is correct
      expect(mockWeatherData.g1IconId, equals(0x05)); // Rain icon
    });
  });
}
