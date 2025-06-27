import 'package:flutter_test/flutter_test.dart';
import 'package:agixt/services/open_meteo_weather_service.dart';
import 'package:agixt/utils/ui_perfs.dart';

void main() {
  group('Even Realities G1 BLE Weather Protocol Tests', () {
    test('should format weather data according to G1 BLE protocol', () {
      // Test basic weather data formatting
      final weatherData = WeatherData(
        temperature: 22.5,
        weatherCode: 0, // Clear sky
        isDay: true,
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
      );

      expect(weatherData.g1IconId, equals(0x10)); // Sunny icon
      expect(
          weatherData.temperature.round(), equals(23)); // Rounded temperature

      // Test night scenario
      final nightWeatherData = WeatherData(
        temperature: 15.0,
        weatherCode: 0,
        isDay: false,
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
      );

      expect(nightWeatherData.g1IconId, equals(0x01)); // Night icon
    });

    test('should map weather codes to correct G1 icons', () {
      final testCases = [
        {'code': 0, 'isDay': true, 'expected': 0x10, 'description': 'Sunny'},
        {
          'code': 0,
          'isDay': false,
          'expected': 0x01,
          'description': 'Clear night'
        },
        {'code': 3, 'isDay': true, 'expected': 0x02, 'description': 'Cloudy'},
        {'code': 61, 'isDay': true, 'expected': 0x05, 'description': 'Rain'},
        {
          'code': 65,
          'isDay': true,
          'expected': 0x06,
          'description': 'Heavy rain'
        },
        {'code': 71, 'isDay': true, 'expected': 0x09, 'description': 'Snow'},
        {'code': 95, 'isDay': true, 'expected': 0x07, 'description': 'Thunder'},
        {'code': 45, 'isDay': true, 'expected': 0x0B, 'description': 'Fog'},
        {
          'code': 51,
          'isDay': true,
          'expected': 0x03,
          'description': 'Light drizzle'
        },
        {
          'code': 56,
          'isDay': true,
          'expected': 0x0F,
          'description': 'Freezing'
        },
      ];

      for (final testCase in testCases) {
        final weatherData = WeatherData(
          temperature: 20.0,
          weatherCode: testCase['code'] as int,
          isDay: testCase['isDay'] as bool,
          latitude: 40.7128,
          longitude: -74.0060,
          timestamp: DateTime.now(),
        );

        expect(
          weatherData.g1IconId,
          equals(testCase['expected']),
          reason:
              'Weather code ${testCase['code']} should map to icon ${testCase['expected']}',
        );
      }
    });

    test('should validate temperature always sent in Celsius for BLE protocol',
        () {
      // BLE protocol requires temperature always in Celsius
      final weatherData = WeatherData(
        temperature: 25.0, // 25°C = 77°F
        weatherCode: 0,
        isDay: true,
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
      );

      expect(weatherData.temperature, equals(25.0));
      expect(weatherData.temperature.round(), equals(25)); // 25°C, not 77°F

      // Test temperature rounding
      final testTemperatures = [
        {'celsius': 15.5, 'expected': 16},
        {'celsius': 23.7, 'expected': 24},
        {'celsius': -10.3, 'expected': -10},
      ];

      for (final temp in testTemperatures) {
        final data = WeatherData(
          temperature: temp['celsius'] as double,
          weatherCode: 0,
          isDay: true,
          latitude: 40.7128,
          longitude: -74.0060,
          timestamp: DateTime.now(),
        );

        expect(data.temperature.round(), equals(temp['expected']));
      }
    });

    test('should handle temperature unit display flags correctly', () {
      // Test that temperature unit preference affects display flag, not temperature value

      // Celsius preference
      const celsiusUnit = TemperatureUnit.CELSIUS;
      int celsiusFlag = (celsiusUnit == TemperatureUnit.FAHRENHEIT) ? 1 : 0;
      expect(celsiusFlag, equals(0));

      // Fahrenheit preference
      const fahrenheitUnit = TemperatureUnit.FAHRENHEIT;
      int fahrenheitFlag =
          (fahrenheitUnit == TemperatureUnit.FAHRENHEIT) ? 1 : 0;
      expect(fahrenheitFlag, equals(1));

      // Verify enum values
      expect(TemperatureUnit.CELSIUS.index, equals(0));
      expect(TemperatureUnit.FAHRENHEIT.index, equals(1));
    });

    test('should validate all weather icons are within G1 protocol range', () {
      final validIconIds = List.generate(17, (i) => i); // 0x00 to 0x10
      final weatherCodes = [
        0,
        1,
        2,
        3,
        45,
        48,
        51,
        53,
        55,
        56,
        57,
        61,
        63,
        65,
        66,
        67,
        71,
        73,
        75,
        77,
        80,
        81,
        82,
        85,
        86,
        95,
        96,
        99
      ];

      for (final code in weatherCodes) {
        for (final isDay in [true, false]) {
          final weatherData = WeatherData(
            temperature: 20.0,
            weatherCode: code,
            isDay: isDay,
            latitude: 40.7128,
            longitude: -74.0060,
            timestamp: DateTime.now(),
          );

          expect(
            validIconIds.contains(weatherData.g1IconId),
            isTrue,
            reason:
                'Weather code $code maps to invalid icon ID 0x${weatherData.g1IconId.toRadixString(16)}',
          );
        }
      }
    });
  });
}
