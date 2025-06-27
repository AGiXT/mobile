import 'package:flutter_test/flutter_test.dart';
import 'package:agixt/services/open_meteo_weather_service.dart';

void main() {
  group('Open-Meteo Weather Service Tests', () {
    test('should create WeatherData from Open-Meteo response', () {
      final mockResponse = {
        'current': {
          'temperature_2m': 22.5,
          'weather_code': 0,
          'is_day': 1,
        }
      };

      final weatherData = WeatherData.fromOpenMeteo(mockResponse, 40.7128, -74.0060);

      expect(weatherData.temperature, equals(22.5));
      expect(weatherData.weatherCode, equals(0));
      expect(weatherData.isDay, equals(true));
      expect(weatherData.latitude, equals(40.7128));
      expect(weatherData.longitude, equals(-74.0060));
    });

    test('should map weather codes to correct G1 icons', () {
      final clearSkyDay = WeatherData(
        temperature: 22.0,
        weatherCode: 0,
        isDay: true,
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
      );

      final clearSkyNight = WeatherData(
        temperature: 15.0,
        weatherCode: 0,
        isDay: false,
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
      );

      final rain = WeatherData(
        temperature: 18.0,
        weatherCode: 61,
        isDay: true,
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
      );

      expect(clearSkyDay.g1IconId, equals(0x10)); // Sunny
      expect(clearSkyNight.g1IconId, equals(0x01)); // Clear night
      expect(rain.g1IconId, equals(0x05)); // Rain
    });

    test('should provide weather descriptions', () {
      final weatherData = WeatherData(
        temperature: 22.0,
        weatherCode: 61,
        isDay: true,
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
      );

      expect(weatherData.description, equals('Slight rain'));
    });

    test('should serialize and deserialize weather data', () {
      final originalData = WeatherData(
        temperature: 25.5,
        weatherCode: 3,
        isDay: true,
        latitude: 52.5200,
        longitude: 13.4050,
        timestamp: DateTime.now(),
      );

      final json = originalData.toJson();
      final deserializedData = WeatherData.fromCachedJson(json);

      expect(deserializedData.temperature, equals(originalData.temperature));
      expect(deserializedData.weatherCode, equals(originalData.weatherCode));
      expect(deserializedData.isDay, equals(originalData.isDay));
      expect(deserializedData.latitude, equals(originalData.latitude));
      expect(deserializedData.longitude, equals(originalData.longitude));
    });
  });
}
