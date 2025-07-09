# G1 Glasses Battery Monitoring

This document explains the battery monitoring functionality for Even Realities G1 smart glasses in the AGiXT Mobile app.

## Overview

The battery monitoring system provides real-time battery status information for both left and right G1 glasses, following the official Even Realities G1 BLE Protocol.

## Features

### 🔋 Real-time Battery Monitoring
- **Automatic Updates**: Battery status is updated every 5 minutes when glasses are connected
- **Dual Glass Support**: Monitors both left and right glasses independently 
- **Charging Detection**: Shows when glasses are charging
- **Low Battery Alerts**: Visual indicators for different battery levels

### 📱 User Interface Components

#### 1. App Bar Indicator
- **Location**: Top-right of the main screen
- **Display**: Shows lowest battery percentage and charging status
- **Interaction**: Tap to view detailed battery information

#### 2. Battery Widget (Home Screen)
- **Location**: Below the app bar on the home screen
- **Display**: Compact view showing overall status and individual glass indicators
- **Features**: 
  - Combined battery percentage
  - Individual L/R glass indicators
  - Charging status icons
  - Last update timestamp

#### 3. Detailed Battery Dialog
- **Access**: Tap the app bar battery indicator
- **Features**:
  - Detailed view for each glass
  - Battery percentage with progress bars
  - Voltage information (when available)
  - Charging status
  - Manual refresh button

## Technical Implementation

### Protocol Compliance
The implementation follows the Even Realities G1 BLE Protocol specification:
- **Command**: `0x2C 0x01` (Get Battery State)
- **Response Format**: `[0x2C, 0x66, percentage, voltage, charging, ...]`
- **Supported Range**: 0-100% battery level

### Data Flow
1. **Request**: BluetoothManager sends battery request to both glasses
2. **Response**: Each glass sends battery data via BLE
3. **Parsing**: G1BatteryInfo parses the raw protocol data
4. **Update**: Battery status is updated and broadcasted
5. **Display**: UI components receive updates and refresh

### Battery Status Model
```dart
class G1BatteryInfo {
  final int percentage;      // 0-100%
  final int voltage;         // Raw voltage value
  final bool isCharging;     // Charging state
  final GlassSide side;      // left or right
  final DateTime timestamp;  // When the data was received
}
```

### Battery Aggregation
```dart
class G1BatteryStatus {
  final G1BatteryInfo? leftBattery;   // Left glass battery
  final G1BatteryInfo? rightBattery;  // Right glass battery
  final DateTime lastUpdated;         // Last update time
  
  // Computed properties
  int? get lowestBatteryPercentage;   // Lowest of both glasses
  bool get isAnyCharging;             // True if any glass is charging
  bool get hasData;                   // True if any battery data available
}
```

## Usage Instructions

### Automatic Monitoring
1. **Connect Glasses**: Ensure G1 glasses are paired and connected
2. **Enable Battery Monitoring**: Battery monitoring starts automatically when glasses connect
3. **View Status**: Check the app bar indicator for quick status

### Manual Battery Request
1. **Settings Screen**: Navigate to Settings
2. **Battery Section**: Look for "Request Battery Info" option (only visible when connected)
3. **Manual Request**: Tap to manually request fresh battery data
4. **Confirmation**: A snackbar will confirm the request was sent

### Interpreting Battery Status

#### Battery Levels
- **Green (>50%)**: Good battery level
- **Orange (20-50%)**: Medium battery level  
- **Red (<20%)**: Low battery level

#### Status Text
- **"Good"**: Battery level above 20%, not charging
- **"Low"**: Battery level 10-20%, not charging
- **"Critical"**: Battery level below 10%, not charging
- **"Charging"**: Currently charging (regardless of level)

## Troubleshooting

### Battery Data Not Appearing
1. **Check Connection**: Ensure glasses are properly connected
2. **Manual Request**: Use the settings option to manually request battery info
3. **Restart Connection**: Disconnect and reconnect glasses
4. **Check Logs**: Look for battery-related debug messages

### Inaccurate Battery Readings
1. **Wait for Update**: Battery data updates every 5 minutes
2. **Manual Refresh**: Use the refresh button in the detailed view
3. **Glasses Firmware**: Ensure glasses have latest firmware (v1.5.6+)

### Missing Battery Indicator
1. **Data Availability**: Indicator only shows when battery data is available
2. **Connection Status**: Verify glasses are connected in settings
3. **App Restart**: Try restarting the app

## Development Notes

### Testing Battery Functionality
Run the battery tests to verify the implementation:
```bash
flutter test test/g1_battery_test.dart
```

### Debug Options
- Battery requests can be manually triggered via settings
- Debug logs show raw protocol data and parsing results
- Test data is included for development and testing

### Integration Points
- **BluetoothManager**: Central coordination of battery requests
- **Glass Class**: Direct BLE communication and response handling
- **Home Screen**: Primary UI integration point
- **Settings Screen**: Manual testing and configuration

## Future Enhancements

### Planned Features
- **Battery History**: Track battery usage over time
- **Low Battery Notifications**: System notifications for critical battery
- **Power Saving Mode**: Automatic features to extend battery life
- **Battery Analytics**: Usage patterns and optimization suggestions

### Protocol Extensions
- **Case Battery**: Monitor charging case battery level
- **Advanced Metrics**: Temperature, cycle count, health status
- **Predictive Alerts**: Estimated time remaining based on usage

## Conclusion

The G1 battery monitoring system provides comprehensive battery management for Even Realities G1 glasses, ensuring users stay informed about their device status and can proactively manage power consumption.
