import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BatteryOptimizationHelper {
  static const MethodChannel _channel =
      MethodChannel('dev.agixt.agixt/battery_optimization');

  /// Check if battery optimization is disabled for this app
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;

    try {
      final bool result =
          await _channel.invokeMethod('isBatteryOptimizationDisabled');
      return result;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      return false;
    }
  }

  /// Request user to disable battery optimization for this app
  static Future<bool> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return true;

    try {
      final bool result =
          await _channel.invokeMethod('requestDisableBatteryOptimization');
      return result;
    } catch (e) {
      debugPrint('Error requesting battery optimization disable: $e');
      return false;
    }
  }

  /// Show dialog to user explaining why battery optimization should be disabled
  static String getBatteryOptimizationExplanation() {
    return 'For AGiXT to respond to voice commands when your screen is locked, '
        'you need to disable battery optimization for this app. This allows '
        'the app to maintain connection to your glasses and process voice '
        'commands even when the screen is off.';
  }
}
