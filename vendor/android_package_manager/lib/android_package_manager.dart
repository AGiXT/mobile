library android_package_manager;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'src/entities/entities.dart';
import 'src/entities/entities_impl.dart';
import 'src/entities/enums.dart';

export 'src/entities/entities.dart';
export 'src/entities/enums.dart';

part 'src/android_package_manager_impl.dart';

abstract class AndroidPackageManager {
  const AndroidPackageManager._();

  static const AndroidPackageManager _pm = AndroidPackageManagerImpl();

  factory AndroidPackageManager() {
    if (!Platform.isAndroid) {
      throw StateError(
        "Can only be run on Android devices",
      );
    }
    return _pm;
  }

  Future<bool> canPackageQuery({
    required String sourcePackageName,
    required String targetPackageName,
  }) =>
      throw UnimplementedError();

  Future<List<String>?> canonicalToCurrentPackageNames({
    required List<String> packageNames,
  }) => throw UnimplementedError();

  Future<CheckPermissionStatus?> checkPermission({
    required String packageName,
    required String permName,
  }) => throw UnimplementedError();

  Future<SignatureCheckResult> checkSignatures({
    required String packageName1, required String packageName2,
  }) => throw UnimplementedError();

  Future<List<String>?> currentToCanonicalPackageNames({
    required List<String> packageNames,
  }) => throw UnimplementedError();

  Future<Uint8List?> getActivityDrawableResource({
    required ComponentName componentName,
    required ActivityResourceType type,
  }) => throw UnimplementedError();

  Future<List<PermissionGroupInfo>?> getAllPermissionGroups({
    PermissionGroupInfoFlags? flags,
  });

  Future<bool?> getApplicationEnabledSetting({
    required String packageName,
  });

  Future<Uint8List?> getApplicationIcon({
    required String packageName,
    BitmapCompressFormat format = BitmapCompressFormat.png,
    int quality = 100,
  });

  Future<String?> getApplicationLabel({
    required String packageName,
    ApplicationInfoFlags? flags,
  });

  Future<Uint8List?> getActivityIcon({
    required String packageName,
    BitmapCompressFormat format = BitmapCompressFormat.png,
    int quality = 100,
  });

  Future<Uint8List?> getActivityLogo({
    required String packageName,
    BitmapCompressFormat format = BitmapCompressFormat.png,
    int quality = 100,
  });

  Future<bool?> getComponentEnabledSetting({
    required String packageName,
  });

  Future<Uint8List?> getDefaultActivityIcon();

  /// Available for SDK Int >= 30 (Android R)
  Future<InstallSourceInfo?> getInstallSourceInfo({
    required String packageName,
  });

  Future<List<ApplicationInfo>?> getInstalledApplications({
    ApplicationInfoFlags? flags,
  }) => throw UnimplementedError();

  Future<List<PackageInfo>?> getInstalledPackages({
    PackageInfoFlags? flags,
  }) => throw UnimplementedError();

  /// Available for SDK Int < 30 (before Android R)
  Future<String?> getInstallerPackageName({
    required String packageName,
  });

  Future<InstrumentationInfo?> getInstrumentationInfo({
    required ComponentName componentName,
  }) => throw UnimplementedError();

  Future<String?> getNameForUid(
    int uid,
  ) =>
      throw UnimplementedError();

  Future<PackageInfo?> getPackageArchiveInfo({
    required String archiveFilePath,
    PackageInfoFlags? flags,
  }) => throw UnimplementedError();

  Future<List<int>?> getPackageGids({
    required String packageName,
  }) => throw UnimplementedError();

  Future<PackageInfo?> getPackageInfo({
    required String packageName,
    PackageInfoFlags? flags,
  }) => throw UnimplementedError();

  Future<List<String>?> getPackagesForUid(
    int uid,
  ) => throw UnimplementedError();

  Future<List<PackageInfo>?> getPackagesHoldingPermissions(
    Set<String> permissions,
  ) => throw UnimplementedError();

  Future<PermissionGroupInfo?> getPermissionGroupInfo(
    String packageName,
  ) => throw UnimplementedError();

  Future<PermissionInfo?> getPermissionInfo(
    String permName,
  ) => throw UnimplementedError();

  Future<ProviderInfo?> getProviderInfo({
    required ComponentName componentName,
    ComponentInfoFlags? flags,
  }) => throw UnimplementedError();

  Future<ActivityInfo?> getReceiverInfo({
    required ComponentName componentName,
    ComponentInfoFlags? flags,
  }) => throw UnimplementedError();

  Future<ServiceInfo?> getServiceInfo({
    required ComponentName componentName,
    ComponentInfoFlags? flags,
  }) => throw UnimplementedError();

  Future<List<FeatureInfo>?> getSystemAvailableFeatures() =>
      throw UnimplementedError();

  Future<List<String>?> getSystemSharedLibraryNames() =>
      throw UnimplementedError();

  Future<bool> hasSigningCertificateByUid({
    required int uid,
    required Uint8List certificateBytes,
    CertificateType type = CertificateType.rawX509,
  }) => throw UnimplementedError();

  Future<bool> hasSigningCertificate({
    required String packageName,
    required Uint8List certificateBytes,
    CertificateType type = CertificateType.rawX509,
  }) => throw UnimplementedError();

  Future<bool> hasSystemFeature({
    required String featureName,
    int? version,
  }) => throw UnimplementedError();

  Future<bool> isSafeMode() => throw UnimplementedError();

  Future<void> launchLeanback(
    String packageName,
  ) => throw UnimplementedError();

  Future<void> openApp(
    String packageName,
  ) => throw UnimplementedError();

  Future<List<ProviderInfo>?> queryContentProviders({
    required int uid,
    String? processName,
    ComponentInfoFlags? flags,
  }) => throw UnimplementedError();

  Future<List<InstrumentationInfo>?> queryInstrumentation(
    String targetPackage,
  ) => throw UnimplementedError();

  Future<List<PermissionInfo>?> queryPermissionsByGroup(
    String permissionGroup,
  ) => throw UnimplementedError();

  Future<void> removePermission(
    String permName,
  ) => throw UnimplementedError();

  Future<ProviderInfo?> resolveContentProvider({
    required String authority,
    ComponentInfoFlags? flags,
  }) => throw UnimplementedError();

  Future<void> setApplicationEnabledSetting({
    required String packageName,
    required ComponentEnabledState newState,
    EnabledFlags? flags,
  }) => throw UnimplementedError();

  Future<void> setComponentEnabledSetting({
    required ComponentName componentName,
    required ComponentEnabledState newState,
    EnabledFlags? flags,
  }) => throw UnimplementedError();

  Future<void> setInstallerPackageName({
    required String targetPackage,
    String? installerPackageName,
  }) => throw UnimplementedError();

  Future<void> verifyPendingInstall({
    required int id,
    required VerificationCode verificationCode,
  }) => throw UnimplementedError();
}
