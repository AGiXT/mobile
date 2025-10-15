import 'package:android_package_manager/src/entities/enums.dart';

import 'activity_info.dart';
import 'application_info.dart';
import 'configuration_info.dart';
import 'feature_info.dart';
import 'instrumentation_info.dart';
import 'permission_info.dart';
import 'provider_info.dart';
import 'service_info.dart';
import 'signing_info.dart';

abstract class PackageInfo {
  const PackageInfo({
    this.activities,
    this.applicationInfo,
    this.configPreferences,
    this.featureGroups,
    this.firstInstallTime,
    this.gids,
    required this.installLocation,
    this.instrumentation,
    this.lastUpdateTime,
    this.packageName,
    this.permissions,
    this.providers,
    this.receivers,
    this.reqFeatures,
    this.requestedPermissions,
    this.requestedPermissionFlags,
    this.services,
    this.sharedUserId,
    this.sharedUserLabel,
    this.splitNames,
    this.versionName,
    this.versionCode,
    // Since Android 22
    this.baseRevisionCode,
    this.splitRevisionCodes,
    // Since Android 28
    this.longVersionCode,
    this.signingInfo,
    // Since Android 29
    this.isApex,
    // Since Android 31
    this.attributions,
  });

  final List<ActivityInfo>? activities;
  final ApplicationInfo? applicationInfo;
  final List<ConfigurationInfo>? configPreferences;
  final List<FeatureGroupInfo>? featureGroups;
  final int? firstInstallTime;
  final List<int>? gids;
  final AndroidInstallLocation installLocation;
  final List<InstrumentationInfo>? instrumentation;
  final int? lastUpdateTime;
  final String? packageName;
  final List<PermissionInfo>? permissions;
  final List<ProviderInfo>? providers;
  final List<ActivityInfo>? receivers;
  final List<FeatureInfo>? reqFeatures;
  final List<String>? requestedPermissions;
  final List<int>? requestedPermissionFlags;
  final List<ServiceInfo>? services;
  final String? sharedUserId;
  final int? sharedUserLabel;
  final List<String>? splitNames;
  final String? versionName;
  final int? versionCode;

  // Since Android 22
  final int? baseRevisionCode;
  final List<int>? splitRevisionCodes;

  // Since Android 28
  final int? longVersionCode;
  final SigningInfo? signingInfo;

  // Since Android 29
  final bool? isApex;

  // Since Android 31
  final Map<String, dynamic>? attributions;
}
