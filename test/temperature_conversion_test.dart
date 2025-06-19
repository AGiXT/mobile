import 'package:flutter_test/flutter_test.dart';
import 'package:agixt/services/weather_service.dart';

void main() {
  group('Temperature Conversion Tests', () {
    late WeatherService weatherService;

    setUp(() {
      weatherService = WeatherService();
    });

    test('should convert Celsius to Fahrenheit correctly', () {
      expect(weatherService.celsiusToFahrenheit(0), equals(32.0));
      expect(weatherService.celsiusToFahrenheit(100), equals(212.0));
      expect(weatherService.celsiusToFahrenheit(25), equals(77.0));
      expect(weatherService.celsiusToFahrenheit(-10), equals(14.0));
    });

    test('should convert Fahrenheit to Celsius correctly', () {
      expect(weatherService.fahrenheitToCelsius(32), equals(0.0));
      expect(weatherService.fahrenheitToCelsius(212), equals(100.0));
      expect(weatherService.fahrenheitToCelsius(77), equals(25.0));
      expect(weatherService.fahrenheitToCelsius(14), equals(-10.0));
    });

    test('temperature conversions should be reversible', () {
      const testTemps = [0.0, 25.0, -10.0, 100.0, 37.5];
      
      for (final temp in testTemps) {
        final fahrenheit = weatherService.celsiusToFahrenheit(temp);
        final backToCelsius = weatherService.fahrenheitToCelsius(fahrenheit);
        expect(backToCelsius, closeTo(temp, 0.001));
      }
    });
  });
}
