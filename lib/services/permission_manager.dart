import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Logical groups of permissions that map to user-facing features.
enum AppPermission {
  bluetooth,
  location,
  notifications,
  calendar,
  microphone,
  storage,
  batteryOptimization,
}

/// Metadata describing a logical permission group.
class PermissionDefinition {
  const PermissionDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.permissions,
    this.requiredForCoreFlow = false,
    this.androidOnly = false,
    this.iosOnly = false,
  });

  final AppPermission id;
  final String title;
  final String description;
  final List<Permission> permissions;
  final bool requiredForCoreFlow;
  final bool androidOnly;
  final bool iosOnly;
}

/// Snapshot of the current status for a permission group.
class PermissionSummary {
  PermissionSummary({
    required this.definition,
    required this.statuses,
  });

  final PermissionDefinition definition;
  final Map<Permission, PermissionStatus> statuses;

  bool get allGranted {
    if (statuses.isEmpty) {
      return true;
    }
    return statuses.values.every((status) => status.isGranted);
  }

  bool get anyPermanentlyDenied =>
      statuses.values.any((status) => status.isPermanentlyDenied);

  bool get anyDenied =>
      statuses.values.any((status) => status.isDenied || status.isRestricted);
}

class PermissionManager {
  static final List<Permission> _android13MediaPermissions =
      List<Permission>.unmodifiable(<Permission>[
    Permission.photos,
    Permission.videos,
    Permission.audio,
  ]);

  static int? _cachedAndroidSdkInt;

  static final List<PermissionDefinition> _definitions = [
    const PermissionDefinition(
      id: AppPermission.bluetooth,
      title: 'Glasses & Nearby Devices',
      description:
          'Needed to scan, pair, and stay connected with your Even Realities G1 glasses.',
      permissions: [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ],
      requiredForCoreFlow: true,
      androidOnly: true,
    ),
    const PermissionDefinition(
      id: AppPermission.location,
      title: 'Location',
      description:
          'Lets the app deliver local weather and location-aware AI responses when you ask for them.',
      permissions: [
        Permission.location,
      ],
      requiredForCoreFlow: false,
    ),
    const PermissionDefinition(
      id: AppPermission.notifications,
      title: 'Notifications',
      description:
          'Allows alerts and messages to show on your phone and glasses at the right moment.',
      permissions: [
        Permission.notification,
      ],
      requiredForCoreFlow: false,
    ),
    const PermissionDefinition(
      id: AppPermission.calendar,
      title: 'Calendar',
      description:
          'Used when you connect calendars so events and reminders appear across devices.',
      permissions: [
        Permission.calendarFullAccess,
        Permission.calendarWriteOnly,
      ],
      requiredForCoreFlow: false,
    ),
    const PermissionDefinition(
      id: AppPermission.microphone,
      title: 'Microphone',
      description:
          'Enable when you want hands-free voice notes or voice-controlled features.',
      permissions: [
        Permission.microphone,
      ],
      requiredForCoreFlow: false,
    ),
    const PermissionDefinition(
      id: AppPermission.storage,
      title: 'Media & Files',
      description:
          'Allows saving exports and working with shared images, audio, or documents.',
      permissions: [
        Permission.storage,
      ],
      requiredForCoreFlow: false,
      androidOnly: true,
    ),
    const PermissionDefinition(
      id: AppPermission.batteryOptimization,
      title: 'Battery Optimization',
      description:
          'Needed only if you want the background Bluetooth service to stay active without interruption.',
      permissions: [
        Permission.ignoreBatteryOptimizations,
      ],
      requiredForCoreFlow: false,
      androidOnly: true,
    ),
  ];

  static List<PermissionDefinition> get availableDefinitions {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const [];
    }

    return _definitions.where((definition) {
      if (definition.androidOnly && !Platform.isAndroid) {
        return false;
      }
      if (definition.iosOnly && !Platform.isIOS) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  static PermissionDefinition definitionOf(AppPermission id) {
    return _definitions.firstWhere((definition) => definition.id == id);
  }

  static Future<PermissionSummary> getSummary(AppPermission id) async {
    final definition = definitionOf(id);
    final Map<Permission, PermissionStatus> statuses = {};
    final permissions = await _effectivePermissions(definition);

    if (!Platform.isAndroid && !Platform.isIOS) {
      return PermissionSummary(definition: definition, statuses: {});
    }

    if (definition.androidOnly && !Platform.isAndroid) {
      return PermissionSummary(definition: definition, statuses: {});
    }

    if (definition.iosOnly && !Platform.isIOS) {
      return PermissionSummary(definition: definition, statuses: {});
    }

    for (final permission in permissions) {
      try {
        final status = await permission.status;
        statuses[permission] = status;
      } catch (error) {
        debugPrint(
          'PermissionManager: Failed to fetch status for ${permission.toString()}: $error',
        );
      }
    }

    return PermissionSummary(definition: definition, statuses: statuses);
  }

  static Future<PermissionSummary> requestPermissions(AppPermission id) async {
    final definition = definitionOf(id);
    final Map<Permission, PermissionStatus> statuses = {};

    if (!Platform.isAndroid && !Platform.isIOS) {
      return PermissionSummary(definition: definition, statuses: {});
    }

    if (definition.androidOnly && !Platform.isAndroid) {
      return PermissionSummary(definition: definition, statuses: {});
    }

    if (definition.iosOnly && !Platform.isIOS) {
      return PermissionSummary(definition: definition, statuses: {});
    }

    final permissions = await _effectivePermissions(definition);

    for (final permission in permissions) {
      try {
        final currentStatus = await permission.status;
        if (currentStatus.isGranted) {
          statuses[permission] = currentStatus;
          continue;
        }

        final requestedStatus = await permission.request();
        statuses[permission] = requestedStatus;
      } catch (error) {
        debugPrint(
          'PermissionManager: Request failed for ${permission.toString()}: $error',
        );
      }
    }

    return PermissionSummary(definition: definition, statuses: statuses);
  }

  static Future<bool> ensureGranted(AppPermission id) async {
    final summary = await getSummary(id);
    if (summary.allGranted) {
      return true;
    }

    final requested = await requestPermissions(id);
    return requested.allGranted;
  }

  static Future<List<Permission>> _effectivePermissions(
    PermissionDefinition definition,
  ) async {
    if (definition.id == AppPermission.storage && Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkInt();
      if (sdkInt != null && sdkInt >= 33) {
        return _android13MediaPermissions;
      }
    }

    return definition.permissions;
  }

  static Future<int?> _getAndroidSdkInt() async {
    if (!Platform.isAndroid) {
      return null;
    }

    if (_cachedAndroidSdkInt != null) {
      return _cachedAndroidSdkInt;
    }

    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _cachedAndroidSdkInt = info.version.sdkInt;
    } catch (error) {
      debugPrint('PermissionManager: Failed to read Android SDK version: $error');
    }

    return _cachedAndroidSdkInt;
  }

  static Future<bool> isGroupGranted(AppPermission id) async {
    final summary = await getSummary(id);
    return summary.allGranted;
  }

  static Future<bool> openSettings() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return false;
      }
      return await openAppSettings();
    } catch (error) {
      debugPrint('PermissionManager: Error opening settings: $error');
      return false;
    }
  }
}
