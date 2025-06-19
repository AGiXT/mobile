import 'package:flutter_test/flutter_test.dart';
import 'package:agixt/models/weather/weather_data.dart';
import 'package:agixt/models/weather/weather_icon_mapper.dart';

void main() {
  group('Weather Icon Mapper Tests', () {
    test('should map weather conditions to correct G1 icons', () {
      expect(WeatherIconMapper.getG1IconId('clear', true), equals(0x10));
      expect(WeatherIconMapper.getG1IconId('clear', false), equals(0x01));
      expect(WeatherIconMapper.getG1IconId('clouds', true), equals(0x02));
      expect(WeatherIconMapper.getG1IconId('rain', true), equals(0x05));
      expect(WeatherIconMapper.getG1IconId('thunderstorm', true), equals(0x08));
      expect(WeatherIconMapper.getG1IconId('snow', true), equals(0x09));
      expect(WeatherIconMapper.getG1IconId('unknown', true),
          equals(0x10)); // Default to sunny
    });

    test('should provide detailed weather mapping', () {
      expect(WeatherIconMapper.getG1IconIdDetailed('rain', 'heavy rain', true),
          equals(0x06));
      expect(WeatherIconMapper.getG1IconIdDetailed('rain', 'light rain', true),
          equals(0x05));
      expect(
          WeatherIconMapper.getG1IconIdDetailed(
              'drizzle', 'heavy drizzle', true),
          equals(0x04));
      expect(
          WeatherIconMapper.getG1IconIdDetailed(
              'thunderstorm', 'heavy thunderstorm', true),
          equals(0x08));
    });

    test('should provide icon descriptions', () {
      expect(WeatherIconMapper.getIconDescription(0x10), equals('Sunny'));
      expect(WeatherIconMapper.getIconDescription(0x01), equals('Clear night'));
      expect(WeatherIconMapper.getIconDescription(0x05), equals('Rain'));
      expect(WeatherIconMapper.getIconDescription(0x09), equals('Snow'));
    });

    test('should return all available icon IDs', () {
      final iconIds = WeatherIconMapper.getAllIconIds();
      expect(iconIds.length, equals(17));
      expect(iconIds.contains(0x10), isTrue); // Sunny
      expect(iconIds.contains(0x01), isTrue); // Night
      expect(iconIds.contains(0x05), isTrue); // Rain
    });
  });

  group('Weather Data Model Tests', () {
    test('should create weather data from OpenWeatherMap JSON', () {
      final mockJson = {
        'weather': [
          {'main': 'Clear', 'description': 'clear sky', 'icon': '01d'}
        ],
        'main': {'temp': 22.5, 'feels_like': 24.0, 'humidity': 65},
        'wind': {'speed': 3.5},
        'name': 'London',
        'sys': {'country': 'GB'}
      };

      final weatherData = WeatherData.fromJson(mockJson);

      expect(weatherData.main, equals('Clear'));
      expect(weatherData.description, equals('clear sky'));
      expect(weatherData.temperature, equals(22.5));
      expect(weatherData.feelsLike, equals(24.0));
      expect(weatherData.humidity, equals(65));
      expect(weatherData.windSpeed, equals(3.5));
      expect(weatherData.locationName, equals('London'));
      expect(weatherData.country, equals('GB'));
      expect(weatherData.isDay, isTrue);
    });

    test('should serialize and deserialize weather data', () {
      final originalData = WeatherData(
        main: 'Rain',
        description: 'light rain',
        icon: '10d',
        temperature: 18.5,
        feelsLike: 17.0,
        humidity: 80,
        windSpeed: 4.2,
        locationName: 'New York',
        country: 'US',
        timestamp: DateTime.now(),
      );

      final json = originalData.toJson();
      final deserializedData = WeatherData.fromCachedJson(json);

      expect(deserializedData.main, equals(originalData.main));
      expect(deserializedData.description, equals(originalData.description));
      expect(deserializedData.temperature, equals(originalData.temperature));
      expect(deserializedData.locationName, equals(originalData.locationName));
    });

    test('should provide formatted strings', () {
      final weatherData = WeatherData(
        main: 'Rain',
        description: 'light rain',
        icon: '10d',
        temperature: 18.5,
        feelsLike: 17.0,
        humidity: 80,
        windSpeed: 4.2,
        locationName: 'New York',
        country: 'US',
        timestamp: DateTime.now(),
      );

      expect(weatherData.temperatureString, equals('19°C'));
      expect(weatherData.location, equals('New York, US'));
      expect(weatherData.summary, equals('light rain, 19°C'));
    });
  });
}
