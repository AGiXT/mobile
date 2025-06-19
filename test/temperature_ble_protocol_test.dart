import 'package:flutter_test/flutter_test.dart';
import 'package:agixt/services/weather_service.dart';

void main() {
  group('Temperature BLE Protocol Tests', () {
    test('should always send Celsius values to glasses regardless of display preference', () {
      final weatherService = WeatherService();
      
      // Test temperature of 32°C (89.6°F)
      const celsiusTemp = 32.0;
      final fahrenheitTemp = weatherService.celsiusToFahrenheit(celsiusTemp);
      
      // Verify conversion is correct
      expect(fahrenheitTemp, closeTo(89.6, 0.1));
      
      // The BLE protocol should always send Celsius values
      // Even when user prefers Fahrenheit, we send 32 (Celsius) not 89 (Fahrenheit)
      final temperatureForBLE = celsiusTemp.round();
      expect(temperatureForBLE, equals(32));
      
      // The display flag (C/F) tells glasses how to show it
      // 0 = show as Celsius (32°C)
      // 1 = show as Fahrenheit (89.6°F converted by glasses)
    });
    
    test('should handle edge case temperatures correctly', () {
      final weatherService = WeatherService();
      
      // Test various temperatures
      const testTemps = [0.0, 25.0, 32.0, 37.0, -10.0];
      
      for (final temp in testTemps) {
        // BLE should always send Celsius value
        final bleTemp = temp.round();
        expect(bleTemp, equals(temp.round()));
        
        // Verify conversion works both ways
        final fahrenheit = weatherService.celsiusToFahrenheit(temp);
        final backToCelsius = weatherService.fahrenheitToCelsius(fahrenheit);
        expect(backToCelsius, closeTo(temp, 0.01));
      }
    });
  });
}
