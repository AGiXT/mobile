/// Weather data model for handling weather information from OpenWeatherMap API
class WeatherData {
  final String main;           // e.g., "Clear", "Rain", "Snow"
  final String description;    // e.g., "clear sky", "light rain"
  final String icon;          // OpenWeatherMap icon code
  final double temperature;    // Temperature in Celsius
  final double feelsLike;     // Feels like temperature in Celsius
  final int humidity;         // Humidity percentage
  final double windSpeed;     // Wind speed in m/s
  final String locationName;  // City name
  final String country;       // Country code
  final DateTime timestamp;   // When the data was fetched

  WeatherData({
    required this.main,
    required this.description,
    required this.icon,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.locationName,
    required this.country,
    required this.timestamp,
  });

  /// Creates WeatherData from OpenWeatherMap API JSON response
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'][0] as Map<String, dynamic>;
    final main = json['main'] as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>? ?? {};
    final sys = json['sys'] as Map<String, dynamic>? ?? {};

    return WeatherData(
      main: weather['main'] as String,
      description: weather['description'] as String,
      icon: weather['icon'] as String,
      temperature: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      humidity: main['humidity'] as int,
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0.0,
      locationName: json['name'] as String,
      country: sys['country'] as String? ?? '',
      timestamp: DateTime.now(),
    );
  }

  /// Converts WeatherData to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'main': main,
      'description': description,
      'icon': icon,
      'temperature': temperature,
      'feelsLike': feelsLike,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'locationName': locationName,
      'country': country,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Creates WeatherData from cached JSON
  factory WeatherData.fromCachedJson(Map<String, dynamic> json) {
    return WeatherData(
      main: json['main'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      feelsLike: (json['feelsLike'] as num).toDouble(),
      humidity: json['humidity'] as int,
      windSpeed: (json['windSpeed'] as num).toDouble(),
      locationName: json['locationName'] as String,
      country: json['country'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Creates WeatherData from device weather data
  factory WeatherData.fromDeviceData(Map<String, dynamic> data) {
    return WeatherData(
      main: data['condition'] as String,
      description: data['description'] as String,
      icon: data['isDay'] == true ? '01d' : '01n', // Simple day/night icon
      temperature: (data['temperature'] as num).toDouble(),
      feelsLike: (data['temperature'] as num).toDouble() + 2, // Estimate feels like
      humidity: data['humidity'] as int? ?? 65,
      windSpeed: (data['windSpeed'] as num?)?.toDouble() ?? 0.0,
      locationName: data['location'] as String? ?? 'Unknown',
      country: '', // Device data might not have country
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }

  /// Returns true if it's currently day time based on the icon
  bool get isDay {
    return icon.endsWith('d');
  }

  /// Returns formatted temperature string
  String get temperatureString {
    return '${temperature.round()}°C';
  }

  /// Returns formatted location string
  String get location {
    return country.isNotEmpty ? '$locationName, $country' : locationName;
  }

  /// Returns a user-friendly weather summary
  String get summary {
    return '$description, $temperatureString';
  }

  @override
  String toString() {
    return 'WeatherData(main: $main, description: $description, temp: $temperatureString, location: $location)';
  }
}
