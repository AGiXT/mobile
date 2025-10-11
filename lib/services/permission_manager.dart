import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static const List<Permission> _requiredPermissions = [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
    Permission.ignoreBatteryOptimizations,
    Permission.notification,
  ];

  static const List<Permission> _optionalPermissions = [
    Permission.microphone,
    Permission.calendarFullAccess,
    Permission.calendarWriteOnly,
    Permission.storage,
  ];

  static bool _isInitializing = false;

  /// Initialize permissions safely without blocking the UI
  static Future<bool> initializePermissions() async {
    if (_isInitializing) {
      debugPrint(
          'PermissionManager: Already initializing permissions, skipping');
      return true;
    }

    _isInitializing = true;

    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        debugPrint(
            'PermissionManager: Platform does not require runtime permissions');
        return true;
      }

      // Use a more gradual approach to avoid freezing
      return await _requestPermissionsGradually();
    } catch (e) {
      debugPrint(
          'PermissionManager: Error during permission initialization: $e');
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Request permissions gradually to avoid UI freezing
  static Future<bool> _requestPermissionsGradually() async {
    bool allCriticalGranted = true;

    // First, check what permissions are already granted
    final Map<Permission, PermissionStatus> currentStatuses = {};
    for (Permission permission in [
      ..._requiredPermissions,
      ..._optionalPermissions
    ]) {
      try {
        currentStatuses[permission] = await permission.status;
      } catch (e) {
        debugPrint(
            'PermissionManager: Error checking status for ${permission.toString()}: $e');
      }
    }

    // Request required permissions one by one with delays
    for (Permission permission in _requiredPermissions) {
      try {
        final currentStatus = currentStatuses[permission];
        if (currentStatus?.isGranted == true) {
          debugPrint(
              'PermissionManager: Permission ${permission.toString()} already granted');
          continue;
        }

        debugPrint(
            'PermissionManager: Requesting permission: ${permission.toString()}');

        // Add a small delay to prevent UI freezing
        await Future.delayed(const Duration(milliseconds: 100));

        final status = await permission.request();

        if (status.isDenied || status.isPermanentlyDenied) {
          debugPrint(
              'PermissionManager: Critical permission ${permission.toString()} denied');
          allCriticalGranted = false;
        } else {
          debugPrint(
              'PermissionManager: Permission ${permission.toString()} granted');
        }

        // Add a delay between permission requests to prevent system overload
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        debugPrint(
            'PermissionManager: Error requesting permission ${permission.toString()}: $e');
        allCriticalGranted = false;

        // Continue with other permissions even if one fails
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Request optional permissions (more gradually and with better error handling)
    await _requestOptionalPermissions(currentStatuses);

    return allCriticalGranted;
  }

  /// Request optional permissions separately to avoid blocking critical ones
  static Future<void> _requestOptionalPermissions(
      Map<Permission, PermissionStatus> currentStatuses) async {
    for (Permission permission in _optionalPermissions) {
      try {
        final currentStatus = currentStatuses[permission];
        if (currentStatus?.isGranted == true) {
          debugPrint(
              'PermissionManager: Optional permission ${permission.toString()} already granted');
          continue;
        }

        debugPrint(
            'PermissionManager: Requesting optional permission: ${permission.toString()}');

        // Longer delay for optional permissions to avoid overwhelming the user
        await Future.delayed(const Duration(milliseconds: 300));

        final status = await permission.request();

        if (status.isGranted) {
          debugPrint(
              'PermissionManager: Optional permission ${permission.toString()} granted');
        } else {
          debugPrint(
              'PermissionManager: Optional permission ${permission.toString()} denied (non-critical)');
        }

        // Longer delay between optional permission requests
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint(
            'PermissionManager: Error requesting optional permission ${permission.toString()}: $e');

        // Continue with other permissions even if one fails
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  /// Check if all required permissions are granted
  static Future<bool> areRequiredPermissionsGranted() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return true;
      }

      for (Permission permission in _requiredPermissions) {
        try {
          final status = await permission.status;
          if (!status.isGranted) {
            return false;
          }
        } catch (e) {
          debugPrint(
              'PermissionManager: Error checking permission ${permission.toString()}: $e');
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('PermissionManager: Error checking required permissions: $e');
      return false;
    }
  }

  /// Request a specific permission safely
  static Future<bool> requestPermission(Permission permission) async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return true;
      }

      final status = await permission.request();
      return status.isGranted;
    } catch (e) {
      debugPrint(
          'PermissionManager: Error requesting permission ${permission.toString()}: $e');
      return false;
    }
  }

  /// Check if a specific permission is granted
  static Future<bool> isPermissionGranted(Permission permission) async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return true;
      }

      final status = await permission.status;
      return status.isGranted;
    } catch (e) {
      debugPrint(
          'PermissionManager: Error checking permission ${permission.toString()}: $e');
      return false;
    }
  }

  /// Open app settings for manual permission management
  static Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('PermissionManager: Error opening app settings: $e');
      return false;
    }
  }
}
