import 'package:android_package_manager/src/entities/impl/signing_info_impl.dart';
import 'package:android_package_manager/src/utils/parser_utils.dart';

import '../base/activity_info.dart';
import '../base/application_info.dart';
import '../base/configuration_info.dart';
import '../base/feature_info.dart';
import '../base/instrumentation_info.dart';
import '../base/package_info.dart';
import '../base/permission_info.dart';
import '../base/provider_info.dart';
import '../base/service_info.dart';
import '../enums.dart';
import 'activity_info.dart';
import 'application_info.dart';
import 'configuration_info.dart';
import 'feature_info.dart';
import 'instrumentation_info.dart';
import 'permission_info.dart';
import 'provider_info.dart';
import 'service_info.dart';

class PackageInfoImpl extends PackageInfo {
  PackageInfoImpl(
    Map<String, dynamic> data,
  ) : super(
    activities: safeListParse<ActivityInfo>(
      data['activities'],
      (data) => ActivityInfoImpl(
        data,
      ),
    ),
    applicationInfo: safeMapParse<ApplicationInfo>(
      data['applicationInfo'],
      (data) => ApplicationInfoImpl(
        data,
      ),
    ),
    configPreferences: safeListParse<ConfigurationInfo>(
      data['configPreferences'],
      (data) => ConfigurationInfoImpl(
        data,
      ),
    ),
    featureGroups: safeListParse<FeatureGroupInfo>(
      data['featureGroups'],
      (data) => FeatureGroupInfoImpl(
        data,
      ),
    ),
    firstInstallTime: data['firstInstallTime'],
    gids: data['gids'],
    installLocation: _parseInstallLocation(
      data['installLocation'],
    ),
    instrumentation: safeListParse<InstrumentationInfo>(
      data['instrumentation'],
      (data) => InstrumentationInfoImpl(
        data,
      ),
    ),
    lastUpdateTime: data['lastUpdateTime'],
    packageName: data['packageName'],
    permissions: safeListParse<PermissionInfo>(
      data['permissions'],
      (data) => PermissionInfoImpl(
        data,
      ),
    ),
    providers: safeListParse<ProviderInfo>(
      data['providers'],
      (data) => ProviderInfoImpl(
        data,
      ),
    ),
    receivers: safeListParse<ActivityInfo>(
      data['receivers'],
      (data) => ActivityInfoImpl(
        data,
      ),
    ),
    reqFeatures: safeListParse<FeatureInfo>(
      data['reqFeatures'],
      (data) => FeatureInfoImpl(
        data,
      ),
    ),
    requestedPermissions: asTypedList<String>(
      data['requestedPermissions'],
    ),
    requestedPermissionFlags: data['requestedPermissionFlags'],
    services: safeListParse<ServiceInfo>(
      data['services'],
      (data) => ServiceInfoImpl(
        data,
      ),
    ),
    sharedUserId: data['sharedUserId'],
    sharedUserLabel: data['sharedUserLabel'],
    splitNames: data['splitNames']?.whereType<String>().toList(
      growable: false,
    ),
    versionName: data['versionName'],
    versionCode: data['versionCode'],
    // Since Android 22
    baseRevisionCode: data['baseRevisionCode'],
    splitRevisionCodes: data['splitRevisionCodes'],
    // Since Android 28
    longVersionCode: data['longRevisionCode'],
    signingInfo: safeMapParse(
      data['signingInfo'], (data) => SigningInfoImpl(data,),
    ),
    // Since Android 29
    isApex: data['isApex'],
    // Since Android 31
    attributions: safeMapParse(data['attributions'], (data) => data,),
  );

  static AndroidInstallLocation _parseInstallLocation(
    dynamic data,
  ) {
    if (data is int) {
      AndroidInstallLocation.values.asMap()[data + 1] ??
          AndroidInstallLocation.unspecified;
    }
    return AndroidInstallLocation.unspecified;
  }
}
