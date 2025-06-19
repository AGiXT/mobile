# Weather Integration for Even Realities G1 Glasses

This document describes the weather functionality added to the AGiXT mobile application for Even Realities G1 glasses.

## Features

### Automatic Weather Updates
- Weather information is automatically fetched from the device's built-in weather system
- Weather data is updated every few minutes while glasses are connected
- Weather icons are mapped to the appropriate Even Realities G1 weather icon set

### Device-Based Weather Data
- Uses the device's native weather services (no external APIs required)
- No API keys or internet connection needed for basic weather functionality
- Includes intelligent caching to improve performance
- Falls back to simulated weather data when device weather is unavailable

### Weather Icon Mapping
The system maps weather conditions to the Even Realities G1 weather icon set:

| Condition | G1 Icon | Description |
|-----------|---------|-------------|
| Clear (Day) | 0x10 | Sunny |
| Clear (Night) | 0x01 | Night |
| Clouds | 0x02 | Cloudy |
| Drizzle | 0x03 | Light Drizzle |
| Heavy Drizzle | 0x04 | Heavy Drizzle |
| Rain | 0x05 | Rain |
| Heavy Rain | 0x06 | Heavy Rain |
| Thunder | 0x07 | Thunder |
| Thunderstorm | 0x08 | Thunderstorm |
| Snow | 0x09 | Snow |
| Mist | 0x0A | Mist |
| Fog | 0x0B | Fog |
| Sand/Dust | 0x0C | Sand |
| Squalls | 0x0D | Squalls |
| Tornado | 0x0E | Tornado |
| Freezing | 0x0F | Freezing |

## Setup

### No Setup Required!
The weather functionality works out of the box with no configuration needed:
- No API keys required
- No external weather services needed
- Uses your device's built-in weather system
- Automatically displays appropriate weather icons on glasses

### Usage

#### Automatic Updates
- Weather is automatically displayed when glasses connect
- Updates every few minutes while connected
- No manual configuration required

#### Manual Control
- Use the Weather Settings screen to refresh weather manually
- View current weather information in the settings
- Weather data is cached for better performance

### Bluetooth Protocol
Weather data is sent to the glasses using the Even Realities G1 BLE protocol:

**Command: Set Time and Weather (0x06)**
```
Header: 06 15 00 XX
Subcommand: 01
Epoch Time (32-bit): XX XX XX XX
Epoch Time (64-bit): XX XX XX XX XX XX XX XX
Weather Icon ID: XX (see mapping table above)
Temperature (°C): XX
C/F Flag: 00 (Celsius)
24H/12H Flag: XX (based on user preference)
```

## File Structure

### Core Services
- `lib/services/weather_service.dart` - Main weather service with API integration
- `lib/services/time_sync.dart` - Extended to include weather data in time sync
- `lib/services/bluetooth_manager.dart` - Extended with weather update methods

### Models
- `lib/models/weather/weather_data.dart` - Weather data model
- `lib/models/weather/weather_icon_mapper.dart` - Icon mapping logic

### UI
- `lib/screens/settings/weather_screen.dart` - Weather settings interface

## API Endpoints

### OpenWeatherMap API
- **Current Weather by City**: `GET /weather?q={city}&appid={API_key}&units=metric`
- **Current Weather by Coordinates**: `GET /weather?lat={lat}&lon={lon}&appid={API_key}&units=metric`

### Response Format
```json
{
  "weather": [
    {
      "main": "Clear",
      "description": "clear sky",
      "icon": "01d"
    }
  ],
  "main": {
    "temp": 22.5,
    "feels_like": 24.0,
    "humidity": 65
  },
  "wind": {
    "speed": 3.5
  },
  "name": "London",
  "sys": {
    "country": "GB"
  }
}
```

## Caching

### Cache Strategy
- Weather data is cached locally for 10 minutes
- Reduces API calls and improves performance
- Falls back to cached data if API is unavailable

### Cache Storage
- Uses SharedPreferences for local storage
- Stores JSON-serialized weather data
- Includes timestamp for cache validation

## Error Handling

### Graceful Degradation
- Falls back to mock data when API key is not configured
- Uses cached data when API is unavailable
- Continues operation with default weather if all else fails

### Logging
- Comprehensive debug logging for troubleshooting
- Error messages logged to console
- User-friendly error messages in UI

## Testing

### Mock Data
When no API key is configured, the system uses mock weather data:
- Temperature: 22°C
- Condition: Clear sky (Sunny icon)
- Location: Mock City

### Manual Testing
1. Set a valid location in Weather Settings
2. Connect glasses
3. Verify weather icon appears on glasses display
4. Check console logs for weather fetch status

## Troubleshooting

### Common Issues
1. **No weather data**: Check API key configuration
2. **Wrong location**: Verify city name spelling
3. **Outdated weather**: Check internet connection and API status
4. **Glasses not updating**: Ensure glasses are connected and sync is working

### Debug Steps
1. Check console logs for error messages
2. Verify API key is valid and active
3. Test with different city names
4. Check OpenWeatherMap API status
5. Verify glasses connection status

## Future Enhancements

### Potential Improvements
- GPS-based location detection
- Weather forecasts (not just current weather)
- Multiple location support
- Weather alerts and notifications
- Hourly weather updates
- Different temperature units (Fahrenheit support)
- Weather history tracking
