import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Weather data model for Open-Meteo API response
class WeatherData {
  final double temperature;
  final int weatherCode;
  final bool isDay;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.isDay,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory WeatherData.fromOpenMeteo(
      Map<String, dynamic> json, double lat, double lon) {
    final current = json['current'];
    return WeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),
      weatherCode: current['weather_code'] as int,
      isDay: current['is_day'] == 1,
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'weatherCode': weatherCode,
      'isDay': isDay,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WeatherData.fromCachedJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['temperature'] as num).toDouble(),
      weatherCode: json['weatherCode'] as int,
      isDay: json['isDay'] as bool,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Maps Open-Meteo weather codes to Even Realities G1 weather icon IDs
  int get g1IconId {
    // WMO Weather interpretation codes (WW)
    // https://open-meteo.com/en/docs
    switch (weatherCode) {
      case 0: // Clear sky
        return isDay ? 0x10 : 0x01; // Sunny/Clear night
      case 1: // Mainly clear
      case 2: // Partly cloudy
        return isDay ? 0x10 : 0x01; // Sunny/Clear night
      case 3: // Overcast
        return 0x02; // Clouds
      case 45: // Fog
      case 48: // Depositing rime fog
        return 0x0B; // Fog
      case 51: // Drizzle: Light
      case 53: // Drizzle: Moderate
        return 0x03; // Light drizzle
      case 55: // Drizzle: Dense
        return 0x04; // Heavy drizzle
      case 56: // Freezing Drizzle: Light
      case 57: // Freezing Drizzle: Dense
        return 0x0F; // Freezing
      case 61: // Rain: Slight
      case 63: // Rain: Moderate
        return 0x05; // Rain
      case 65: // Rain: Heavy
        return 0x06; // Heavy rain
      case 66: // Freezing Rain: Light
      case 67: // Freezing Rain: Heavy
        return 0x0F; // Freezing
      case 71: // Snow fall: Slight
      case 73: // Snow fall: Moderate
      case 75: // Snow fall: Heavy
      case 77: // Snow grains
        return 0x09; // Snow
      case 80: // Rain showers: Slight
      case 81: // Rain showers: Moderate
        return 0x05; // Rain
      case 82: // Rain showers: Violent
        return 0x06; // Heavy rain
      case 85: // Snow showers: Slight
      case 86: // Snow showers: Heavy
        return 0x09; // Snow
      case 95: // Thunderstorm: Slight or moderate
        return 0x07; // Thunder
      case 96: // Thunderstorm with slight hail
      case 99: // Thunderstorm with heavy hail
        return 0x08; // Thunderstorm
      default:
        return isDay ? 0x10 : 0x01; // Default to sunny/clear
    }
  }

  String get description {
    switch (weatherCode) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
        return 'Fog';
      case 48:
        return 'Depositing rime fog';
      case 51:
        return 'Light drizzle';
      case 53:
        return 'Moderate drizzle';
      case 55:
        return 'Dense drizzle';
      case 56:
        return 'Light freezing drizzle';
      case 57:
        return 'Dense freezing drizzle';
      case 61:
        return 'Slight rain';
      case 63:
        return 'Moderate rain';
      case 65:
        return 'Heavy rain';
      case 66:
        return 'Light freezing rain';
      case 67:
        return 'Heavy freezing rain';
      case 71:
        return 'Slight snow';
      case 73:
        return 'Moderate snow';
      case 75:
        return 'Heavy snow';
      case 77:
        return 'Snow grains';
      case 80:
        return 'Slight rain showers';
      case 81:
        return 'Moderate rain showers';
      case 82:
        return 'Violent rain showers';
      case 85:
        return 'Slight snow showers';
      case 86:
        return 'Heavy snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
        return 'Thunderstorm with slight hail';
      case 99:
        return 'Thunderstorm with heavy hail';
      default:
        return 'Unknown weather';
    }
  }
}

/// Service for fetching weather data using Open-Meteo API
class OpenMeteoWeatherService {
  static final OpenMeteoWeatherService _instance =
      OpenMeteoWeatherService._internal();
  factory OpenMeteoWeatherService() => _instance;
  OpenMeteoWeatherService._internal();

  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String _cacheKey = 'open_meteo_weather_cache';
  static const String _cacheTimestampKey = 'open_meteo_weather_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 10);

  /// Get current weather for user's location
  Future<WeatherData?> getCurrentWeather() async {
    try {
      // Check cache first
      final cachedData = await _getCachedWeather();
      if (cachedData != null && _isCacheValid(await _getCacheTimestamp())) {
        debugPrint('Using cached weather data');
        return cachedData;
      }

      // Get user location
      final position = await _getCurrentPosition();
      if (position == null) {
        debugPrint(
            'Could not get user location, using cached data if available');
        return cachedData; // Return cached data even if expired
      }

      // Fetch weather from Open-Meteo
      final weatherData =
          await _fetchWeatherFromAPI(position.latitude, position.longitude);

      if (weatherData != null) {
        await _cacheWeather(weatherData);
        debugPrint(
            'Weather fetched from Open-Meteo: ${weatherData.description}, ${weatherData.temperature}°C');
        return weatherData;
      }

      // Fallback to cached data
      return cachedData;
    } catch (e) {
      debugPrint('Error getting weather: $e');
      return await _getCachedWeather(); // Return cached data on error
    }
  }

  /// Get user's current position
  Future<Position?> _getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Fetch weather data from Open-Meteo API
  Future<WeatherData?> _fetchWeatherFromAPI(
      double latitude, double longitude) async {
    try {
      final url = Uri.parse(
          '$_baseUrl?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code,is_day&timezone=auto');

      debugPrint('Fetching weather from: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return WeatherData.fromOpenMeteo(data, latitude, longitude);
      } else {
        debugPrint('Failed to fetch weather: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching weather from API: $e');
      return null;
    }
  }

  /// Cache weather data
  Future<void> _cacheWeather(WeatherData weatherData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final weatherJson = jsonEncode(weatherData.toJson());
      await prefs.setString(_cacheKey, weatherJson);
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching weather: $e');
    }
  }

  /// Get cached weather data
  Future<WeatherData?> _getCachedWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final weatherJson = prefs.getString(_cacheKey);
      if (weatherJson != null) {
        final data = jsonDecode(weatherJson);
        return WeatherData.fromCachedJson(data);
      }
    } catch (e) {
      debugPrint('Error getting cached weather: $e');
    }
    return null;
  }

  /// Get cache timestamp
  Future<int?> _getCacheTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_cacheTimestampKey);
    } catch (e) {
      debugPrint('Error getting cache timestamp: $e');
    }
    return null;
  }

  /// Check if cache is valid
  bool _isCacheValid(int? cacheTimestamp) {
    if (cacheTimestamp == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - cacheTimestamp) < _cacheDuration.inMilliseconds;
  }

  /// Clear weather cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      debugPrint('Weather cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
