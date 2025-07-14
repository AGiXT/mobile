import 'glass.dart';

class G1BatteryInfo {
  final int percentage;
  final int voltage;
  final bool isCharging;
  final GlassSide side;
  final DateTime timestamp;

  const G1BatteryInfo({
    required this.percentage,
    required this.voltage,
    required this.isCharging,
    required this.side,
    required this.timestamp,
  });

  /// Parse battery response according to protocol:
  /// Response: [0x2C, 0x66, batteryPercentage, voltage, charging, ...]
  static G1BatteryInfo? fromResponse(List<int> data, GlassSide side) {
    if (data.length < 4) {
      return null;
    }

    // Check if it's a battery response (0x2C)
    if (data[0] != 0x2C) {
      return null;
    }

    // Extract raw battery percentage (0-100)
    final rawPercentage = data[2];

    // Ensure percentage is within valid range and accurate
    final percentage = rawPercentage.clamp(0, 100);

    // Voltage is typically spread across multiple bytes, but for simplicity we'll use one byte
    final voltage = data.length > 3 ? data[3] : 0;

    // Charging status from the protocol example
    final isCharging = data.length > 4 ? (data[4] & 0x01) == 1 : false;

    return G1BatteryInfo(
      percentage: percentage,
      voltage: voltage,
      isCharging: isCharging,
      side: side,
      timestamp: DateTime.now(),
    );
  }

  String get batteryLevelText {
    return '$percentage%';
  }

  String get statusText {
    if (isCharging) {
      return 'Charging';
    } else if (percentage >= 90) {
      return 'Excellent';
    } else if (percentage >= 80) {
      return 'Very Good';
    } else if (percentage >= 60) {
      return 'Good';
    } else if (percentage >= 40) {
      return 'Fair';
    } else if (percentage >= 20) {
      return 'Low';
    } else if (percentage >= 10) {
      return 'Very Low';
    } else if (percentage >= 5) {
      return 'Critical';
    } else {
      return 'Empty';
    }
  }

  @override
  String toString() {
    return 'G1BatteryInfo(${side.name}: $percentage%, voltage: $voltage, charging: $isCharging)';
  }
}

class G1BatteryStatus {
  final G1BatteryInfo? leftBattery;
  final G1BatteryInfo? rightBattery;
  final DateTime lastUpdated;

  const G1BatteryStatus({
    this.leftBattery,
    this.rightBattery,
    required this.lastUpdated,
  });

  bool get hasData => leftBattery != null || rightBattery != null;

  int? get lowestBatteryPercentage {
    if (leftBattery == null && rightBattery == null) return null;
    if (leftBattery == null) return rightBattery!.percentage;
    if (rightBattery == null) return leftBattery!.percentage;
    return leftBattery!.percentage < rightBattery!.percentage
        ? leftBattery!.percentage
        : rightBattery!.percentage;
  }

  bool get isAnyCharging =>
      (leftBattery?.isCharging ?? false) || (rightBattery?.isCharging ?? false);

  G1BatteryStatus copyWith({
    G1BatteryInfo? leftBattery,
    G1BatteryInfo? rightBattery,
    DateTime? lastUpdated,
  }) {
    return G1BatteryStatus(
      leftBattery: leftBattery ?? this.leftBattery,
      rightBattery: rightBattery ?? this.rightBattery,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
