/// Maps OpenWeatherMap weather conditions to Even Realities G1 weather icon IDs
class WeatherIconMapper {
  // Even Realities G1 Weather Icon IDs (from protocol documentation)
  static const int iconNone = 0x00;
  static const int iconNight = 0x01;
  static const int iconClouds = 0x02;
  static const int iconDrizzle = 0x03;
  static const int iconHeavyDrizzle = 0x04;
  static const int iconRain = 0x05;
  static const int iconHeavyRain = 0x06;
  static const int iconThunder = 0x07;
  static const int iconThunderStorm = 0x08;
  static const int iconSnow = 0x09;
  static const int iconMist = 0x0A;
  static const int iconFog = 0x0B;
  static const int iconSand = 0x0C;
  static const int iconSqualls = 0x0D;
  static const int iconTornado = 0x0E;
  static const int iconFreezing = 0x0F;
  static const int iconSunny = 0x10;

  /// Maps OpenWeatherMap main weather condition to G1 icon ID
  static int getG1IconId(String weatherMain, bool isDay) {
    // Convert to lowercase for case-insensitive matching
    final condition = weatherMain.toLowerCase();

    switch (condition) {
      case 'clear':
        return isDay ? iconSunny : iconNight;

      case 'clouds':
      case 'overcast':
        return iconClouds;

      case 'drizzle':
        return iconDrizzle;

      case 'rain':
        return iconRain;

      case 'thunderstorm':
        return iconThunderStorm;

      case 'snow':
        return iconSnow;

      case 'mist':
        return iconMist;

      case 'fog':
      case 'haze':
        return iconFog;

      case 'sand':
      case 'dust':
        return iconSand;

      case 'squall':
        return iconSqualls;

      case 'tornado':
        return iconTornado;

      case 'extreme':
        return iconFreezing;

      default:
        // Default to sunny for day, night for night if condition is unknown
        return isDay ? iconSunny : iconNight;
    }
  }

  /// Maps detailed OpenWeatherMap weather condition to G1 icon ID
  static int getG1IconIdDetailed(
      String weatherMain, String description, bool isDay) {
    final condition = weatherMain.toLowerCase();
    final desc = description.toLowerCase();

    // Handle specific conditions based on description
    switch (condition) {
      case 'rain':
        if (desc.contains('heavy') || desc.contains('extreme')) {
          return iconHeavyRain;
        } else if (desc.contains('light') || desc.contains('shower')) {
          return iconRain;
        }
        return iconRain;

      case 'drizzle':
        if (desc.contains('heavy') || desc.contains('dense')) {
          return iconHeavyDrizzle;
        }
        return iconDrizzle;

      case 'thunderstorm':
        if (desc.contains('heavy') || desc.contains('extreme')) {
          return iconThunderStorm;
        }
        return iconThunder;

      case 'snow':
        if (desc.contains('freezing') || desc.contains('ice')) {
          return iconFreezing;
        }
        return iconSnow;

      case 'atmosphere':
        if (desc.contains('fog')) {
          return iconFog;
        } else if (desc.contains('mist')) {
          return iconMist;
        } else if (desc.contains('sand') || desc.contains('dust')) {
          return iconSand;
        }
        return iconMist;

      default:
        // Fall back to simple mapping
        return getG1IconId(weatherMain, isDay);
    }
  }

  /// Gets a human-readable description of the weather icon
  static String getIconDescription(int iconId) {
    switch (iconId) {
      case iconNone:
        return 'No weather data';
      case iconNight:
        return 'Clear night';
      case iconClouds:
        return 'Cloudy';
      case iconDrizzle:
        return 'Light drizzle';
      case iconHeavyDrizzle:
        return 'Heavy drizzle';
      case iconRain:
        return 'Rain';
      case iconHeavyRain:
        return 'Heavy rain';
      case iconThunder:
        return 'Thunder';
      case iconThunderStorm:
        return 'Thunderstorm';
      case iconSnow:
        return 'Snow';
      case iconMist:
        return 'Mist';
      case iconFog:
        return 'Fog';
      case iconSand:
        return 'Sand/Dust';
      case iconSqualls:
        return 'Squalls';
      case iconTornado:
        return 'Tornado';
      case iconFreezing:
        return 'Freezing';
      case iconSunny:
        return 'Sunny';
      default:
        return 'Unknown weather';
    }
  }

  /// Returns all available weather icon IDs
  static List<int> getAllIconIds() {
    return [
      iconNone,
      iconNight,
      iconClouds,
      iconDrizzle,
      iconHeavyDrizzle,
      iconRain,
      iconHeavyRain,
      iconThunder,
      iconThunderStorm,
      iconSnow,
      iconMist,
      iconFog,
      iconSand,
      iconSqualls,
      iconTornado,
      iconFreezing,
      iconSunny,
    ];
  }
}
