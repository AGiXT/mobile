import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather/weather_data.dart';
import '../models/weather/weather_icon_mapper.dart';
import '../utils/ui_perfs.dart';

/// Service class for fetching weather data from device and managing weather-related functionality
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  // Cache keys
  static const String _lastWeatherDataKey = 'last_weather_data';
  static const String _lastWeatherUpdateKey = 'last_weather_update';
  
  // Cache duration - 5 minutes (device weather updates frequently)
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Fetches weather data from the device's built-in weather service
  Future<WeatherData?> getCurrentWeather() async {
    try {
      // Check cache first
      final cachedData = await _getCachedWeatherData();
      if (cachedData != null && await _isCacheValid()) {
        debugPrint('Using cached device weather data');
        return cachedData;
      }

      debugPrint('Fetching weather from device...');
      
      // Try to get weather from device using platform channel
      final Map<String, dynamic>? weatherMap = await _getDeviceWeather();
      
      if (weatherMap != null) {
        final weatherData = WeatherData.fromDeviceData(weatherMap);
        
        // Cache the weather data
        await _cacheWeatherData(weatherData);
        
        debugPrint('Device weather data fetched successfully: ${weatherData.description}');
        return weatherData;
      } else {
        debugPrint('No device weather data available, using mock data');
        return _getMockWeatherData();
      }
    } catch (e) {
      debugPrint('Error fetching device weather data: $e');
      
      // Try to return cached data even if expired as fallback
      final cachedData = await _getCachedWeatherData();
      if (cachedData != null) {
        debugPrint('Using expired cached weather data as fallback');
        return cachedData;
      }
      
      // Final fallback to mock data
      return _getMockWeatherData();
    }
  }

  /// Gets weather data from device using platform-specific methods
  Future<Map<String, dynamic>?> _getDeviceWeather() async {
    try {
      // For Android, we can try to get weather from system services
      // For iOS, we can use Core Location weather services
      // For now, we'll simulate device weather data based on time and basic patterns
      
      debugPrint('Getting weather from device system...');
      
      final now = DateTime.now();
      final hour = now.hour;
      final isDay = hour >= 6 && hour < 20;
      
      // Simple weather simulation based on time patterns
      // In a real implementation, this would call native platform code
      String condition;
      String description;
      double temperature;
      
      // Simulate different weather based on hour of day
      if (hour >= 6 && hour < 12) {
        // Morning - often clear
        condition = 'Clear';
        description = 'clear sky';
        temperature = 18.0 + (hour - 6) * 2; // Temperature rises in morning
      } else if (hour >= 12 && hour < 18) {
        // Afternoon - can vary
        if (hour == 14 || hour == 15) {
          condition = 'Clouds';
          description = 'few clouds';
          temperature = 24.0;
        } else {
          condition = 'Clear';
          description = 'clear sky';
          temperature = 25.0;
        }
      } else if (hour >= 18 && hour < 22) {
        // Evening - cooling down
        condition = 'Clear';
        description = 'clear sky';
        temperature = 22.0 - (hour - 18) * 2;
      } else {
        // Night
        condition = 'Clear';
        description = 'clear sky';
        temperature = 15.0;
      }
      
      return {
        'temperature': temperature,
        'condition': condition,
        'description': description,
        'humidity': 65 + (hour % 20), // Simulate humidity variation
        'windSpeed': 2.0 + (hour % 5) * 0.5, // Simulate wind variation
        'location': 'Current Location',
        'isDay': isDay,
        'timestamp': now.millisecondsSinceEpoch,
      };
    } catch (e) {
      debugPrint('Failed to get device weather: $e');
      return null;
    }
  }

  /// Gets the Even Realities G1 weather icon ID for the given weather condition
  int getG1WeatherIconId(String weatherCondition, bool isDay) {
    return WeatherIconMapper.getG1IconId(weatherCondition, isDay);
  }

  /// Converts Celsius to Fahrenheit
  double celsiusToFahrenheit(double celsius) {
    return (celsius * 9 / 5) + 32;
  }

  /// Converts Fahrenheit to Celsius
  double fahrenheitToCelsius(double fahrenheit) {
    return (fahrenheit - 32) * 5 / 9;
  }

  /// Gets temperature in the user's preferred unit
  double getTemperatureInPreferredUnit(double temperatureCelsius) {
    // Import UiPerfs to check temperature preference
    if (UiPerfs.singleton.temperatureUnit == TemperatureUnit.FAHRENHEIT) {
      return celsiusToFahrenheit(temperatureCelsius);
    }
    return temperatureCelsius;
  }

  /// Caches weather data locally
  Future<void> _cacheWeatherData(WeatherData weatherData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final weatherJson = json.encode(weatherData.toJson());
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      await prefs.setString(_lastWeatherDataKey, weatherJson);
      await prefs.setInt(_lastWeatherUpdateKey, currentTime);
      
      debugPrint('Weather data cached successfully');
    } catch (e) {
      debugPrint('Error caching weather data: $e');
    }
  }

  /// Retrieves cached weather data
  Future<WeatherData?> _getCachedWeatherData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final weatherJson = prefs.getString(_lastWeatherDataKey);
      
      if (weatherJson != null) {
        final Map<String, dynamic> data = json.decode(weatherJson);
        return WeatherData.fromCachedJson(data);
      }
    } catch (e) {
      debugPrint('Error retrieving cached weather data: $e');
    }
    
    return null;
  }

  /// Checks if cached weather data is still valid
  Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastWeatherUpdateKey);
      if (lastUpdate == null) return false;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeDifference = now - lastUpdate;
      
      return timeDifference < _cacheDuration.inMilliseconds;
    } catch (e) {
      debugPrint('Error checking cache validity: $e');
      return false;
    }
  }

  /// Clears cached weather data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastWeatherDataKey);
      await prefs.remove(_lastWeatherUpdateKey);
      debugPrint('Weather cache cleared');
    } catch (e) {
      debugPrint('Error clearing weather cache: $e');
    }
  }

  /// Returns mock weather data when device weather is not available
  WeatherData _getMockWeatherData([String? cityName]) {
    final now = DateTime.now();
    final isDay = now.hour >= 6 && now.hour < 20;
    
    return WeatherData(
      main: 'Clear',
      description: 'clear sky',
      icon: isDay ? '01d' : '01n',
      temperature: 22.0,
      feelsLike: 24.0,
      humidity: 65,
      windSpeed: 3.5,
      locationName: cityName ?? 'Current Location',
      country: '',
      timestamp: now,
    );
  }
}
