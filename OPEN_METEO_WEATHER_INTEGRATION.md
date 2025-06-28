# Open-Meteo Weather Integration for Even Realities G1 Glasses

This document describes the weather functionality that uses the Open-Meteo API to provide real weather data for the AGiXT mobile application and Even Realities G1 glasses.

## Features

### Real-Time Weather Data
- Fetches current weather data from Open-Meteo API using user's GPS location
- Updates weather information every 10 minutes (cached to reduce API calls)
- Automatically falls back to time-based simulation if API is unavailable

### Location-Based Weather
- Uses device GPS to get user's current coordinates
- Automatically requests location permissions when needed
- Works offline using cached weather data

### Weather Icon Mapping
The system maps Open-Meteo WMO weather codes to Even Realities G1 weather icon set:

| Weather Code | Condition | G1 Icon | Description |
|-------------|-----------|---------|-------------|
| 0 | Clear sky | 0x10/0x01 | Sunny/Clear night |
| 1-2 | Mainly/Partly clear | 0x10/0x01 | Sunny/Clear night |
| 3 | Overcast | 0x02 | Cloudy |
| 45-48 | Fog | 0x0B | Fog |
| 51-53 | Light/Moderate drizzle | 0x03 | Light drizzle |
| 55 | Dense drizzle | 0x04 | Heavy drizzle |
| 56-57 | Freezing drizzle | 0x0F | Freezing |
| 61-63 | Slight/Moderate rain | 0x05 | Rain |
| 65 | Heavy rain | 0x06 | Heavy rain |
| 66-67 | Freezing rain | 0x0F | Freezing |
| 71-77 | Snow | 0x09 | Snow |
| 80-82 | Rain showers | 0x05/0x06 | Rain/Heavy rain |
| 85-86 | Snow showers | 0x09 | Snow |
| 95 | Thunderstorm | 0x07 | Thunder |
| 96-99 | Thunderstorm with hail | 0x08 | Thunderstorm |

## Implementation

### Core Components

#### OpenMeteoWeatherService
- Main service class that handles API communication
- Manages location permissions and GPS access
- Implements caching strategy for offline operation
- Maps weather codes to G1 icon IDs

#### WeatherData Model
- Represents weather information from Open-Meteo API
- Includes temperature, weather code, day/night flag, and location
- Provides G1 icon mapping and weather descriptions
- Supports JSON serialization for caching

#### TimeSync Integration
- Weather data is automatically included in time synchronization
- Sends weather icon ID and temperature to glasses via BLE
- Falls back to time-based simulation if real weather unavailable

### API Integration

#### Open-Meteo Endpoint
```
https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code,is_day&timezone=auto
```

#### Example Response
```json
{
  "current": {
    "temperature_2m": 22.5,
    "weather_code": 0,
    "is_day": 1
  }
}
```

### Caching Strategy
- Weather data cached for 10 minutes to reduce API calls
- Uses SharedPreferences for local storage
- Includes timestamp validation for cache expiry
- Falls back to cached data if API is unavailable

### Location Services
- Automatically requests location permissions
- Uses low accuracy for faster GPS lock
- 10-second timeout for location requests
- Graceful fallback if location unavailable

## Setup

### No API Key Required
- Open-Meteo provides free weather data without API keys
- No registration or configuration needed
- Works immediately after app installation

### Permissions
The app will automatically request these permissions:
- **Location**: Required to get user's coordinates for weather data
- **Internet**: Required to fetch weather data from Open-Meteo API

## Usage

### Automatic Operation
- Weather data is automatically fetched when glasses are connected
- Updates every minute via existing sync mechanism
- No user intervention required

### Manual Testing
```dart
final weatherService = OpenMeteoWeatherService();
final weatherData = await weatherService.getCurrentWeather();
if (weatherData != null) {
  print('${weatherData.description}: ${weatherData.temperature}°C');
}
```

## Error Handling

### Graceful Degradation
- Falls back to cached data when API is unavailable
- Uses time-based simulation when no cached data exists
- Continues operation with default weather if all sources fail

### Logging
- Comprehensive debug logging for troubleshooting
- Location and API errors logged to console
- Cache operations logged for debugging

## Testing

### Unit Tests
Located in `test/open_meteo_weather_test.dart`:
- Weather data model serialization/deserialization
- Weather code to G1 icon mapping
- API response parsing
- Cache functionality

### Manual Testing
1. Enable location services on device
2. Connect glasses via Bluetooth
3. Verify weather icon appears on glasses display
4. Check console logs for weather fetch status

## Files

### Core Implementation
- `lib/services/open_meteo_weather_service.dart` - Main weather service
- `lib/services/time_sync.dart` - Integration with glasses sync

### Testing
- `test/open_meteo_weather_test.dart` - Unit tests for weather functionality

## Benefits

1. **No External Dependencies**: Free API with no registration required
2. **Real Location Data**: Uses actual GPS coordinates for accurate weather
3. **Offline Support**: Cached data works without internet connection
4. **Privacy Friendly**: Location data only used locally, not sent to third parties
5. **Reliable**: Multiple fallback strategies ensure weather always displays

## Troubleshooting

### Common Issues
1. **No weather data**: Check location permissions and internet connection
2. **Old weather data**: Weather updates every 10 minutes, check cache timestamp
3. **Location unavailable**: App falls back to cached data or simulation
4. **API unavailable**: App uses cached data automatically

### Debug Steps
1. Check console logs for error messages
2. Verify location permissions are granted
3. Test internet connectivity
4. Check if location services are enabled
5. Verify glasses connection status
