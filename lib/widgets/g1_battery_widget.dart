import 'package:flutter/material.dart';
import 'package:agixt/models/g1/battery.dart';

class G1BatteryWidget extends StatelessWidget {
  final G1BatteryStatus batteryStatus;
  final bool showDetails;

  const G1BatteryWidget({
    super.key,
    required this.batteryStatus,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!batteryStatus.hasData) {
      return const SizedBox.shrink();
    }

    // For compact mode, show minimal battery indicator
    if (!showDetails) {
      final lowestBattery = batteryStatus.lowestBatteryPercentage;
      if (lowestBattery == null) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getBatteryColor(lowestBattery).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getBatteryColor(lowestBattery).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glasses icon
            Icon(
              Icons.visibility, // Better glasses icon
              size: 14,
              color: _getBatteryColor(lowestBattery),
            ),
            const SizedBox(width: 4),
            Icon(
              _getBatteryIcon(lowestBattery),
              size: 16,
              color: _getBatteryColor(lowestBattery),
            ),
            const SizedBox(width: 6),
            Text(
              '$lowestBattery%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _getBatteryColor(lowestBattery),
              ),
            ),
          ],
        ),
      );
    }

    // Detailed view for dialog
    return Card(
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_full,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'G1 Glasses Battery',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailedView(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedView(BuildContext context) {
    return Column(
      children: [
        if (batteryStatus.leftBattery != null)
          _buildDetailedGlassInfo(
              'Left Glass', batteryStatus.leftBattery!, context),
        if (batteryStatus.leftBattery != null &&
            batteryStatus.rightBattery != null)
          const SizedBox(height: 12),
        if (batteryStatus.rightBattery != null)
          _buildDetailedGlassInfo(
              'Right Glass', batteryStatus.rightBattery!, context),
      ],
    );
  }

  Widget _buildDetailedGlassInfo(
      String title, G1BatteryInfo batteryInfo, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                '${batteryInfo.percentage}%',
                style: TextStyle(
                  color: _getBatteryColor(batteryInfo.percentage),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${batteryInfo.percentage}%',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getBatteryColor(batteryInfo.percentage),
                              ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: batteryInfo.percentage / 100,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getBatteryColor(batteryInfo.percentage),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(int percentage) {
    if (percentage >= 80) {
      return const Color(0xFF4CAF50); // Material Green 500 - Excellent
    }
    if (percentage >= 60) {
      return const Color(0xFF66BB6A); // Material Green 400 - Good
    }
    if (percentage >= 40) {
      return const Color(
          0xFF2196F3); // Material Blue 500 - Fair (matches app theme)
    }
    if (percentage >= 20) {
      return const Color(0xFFFF9800); // Material Orange 500 - Low
    }
    if (percentage >= 10) {
      return const Color(0xFFFF5722); // Material Deep Orange 500 - Very Low
    }
    return const Color(0xFFF44336); // Material Red 500 - Critical
  }

  IconData _getBatteryIcon(int percentage) {
    if (percentage >= 90) return Icons.battery_full;
    if (percentage >= 75) return Icons.battery_6_bar;
    if (percentage >= 60) return Icons.battery_5_bar;
    if (percentage >= 45) return Icons.battery_4_bar;
    if (percentage >= 30) return Icons.battery_3_bar;
    if (percentage >= 15) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }
}

/// Compact battery status widget for app bars or status displays
class G1BatteryIndicator extends StatelessWidget {
  final G1BatteryStatus batteryStatus;
  final VoidCallback? onTap;

  const G1BatteryIndicator({
    super.key,
    required this.batteryStatus,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!batteryStatus.hasData) {
      return const SizedBox.shrink();
    }

    final lowestBattery = batteryStatus.lowestBatteryPercentage;
    if (lowestBattery == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getBatteryColor(lowestBattery).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getBatteryColor(lowestBattery),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getBatteryIcon(lowestBattery),
              size: 16,
              color: _getBatteryColor(lowestBattery),
            ),
            const SizedBox(width: 4),
            Text(
              '$lowestBattery%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _getBatteryColor(lowestBattery),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBatteryColor(int percentage) {
    if (percentage >= 80) {
      return const Color(0xFF4CAF50); // Material Green 500 - Excellent
    }
    if (percentage >= 60) {
      return const Color(0xFF66BB6A); // Material Green 400 - Good
    }
    if (percentage >= 40) {
      return const Color(
          0xFF2196F3); // Material Blue 500 - Fair (matches app theme)
    }
    if (percentage >= 20) {
      return const Color(0xFFFF9800); // Material Orange 500 - Low
    }
    if (percentage >= 10) {
      return const Color(0xFFFF5722); // Material Deep Orange 500 - Very Low
    }
    return const Color(0xFFF44336); // Material Red 500 - Critical
  }

  IconData _getBatteryIcon(int percentage) {
    if (percentage >= 90) return Icons.battery_full;
    if (percentage >= 75) return Icons.battery_6_bar;
    if (percentage >= 60) return Icons.battery_5_bar;
    if (percentage >= 45) return Icons.battery_4_bar;
    if (percentage >= 30) return Icons.battery_3_bar;
    if (percentage >= 15) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }
}
