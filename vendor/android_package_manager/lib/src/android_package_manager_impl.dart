part of '../android_package_manager.dart';

class AndroidPackageManagerImpl extends AndroidPackageManager {
  const AndroidPackageManagerImpl() : super._();

  static const MethodChannel _channel = MethodChannel(
    'android_package_manager',
  );

  static const Map<int, CheckPermissionStatus> _checkPermissionResultMap = {
    0: CheckPermissionStatus.granted,
    -1: CheckPermissionStatus.denied,
  };

  static const Map<int, SignatureCheckResult> _signatureCheckResultMap = {
    0: SignatureCheckResult.match,
    1: SignatureCheckResult.neitherSigned,
    -1: SignatureCheckResult.firstNotSigned,
    -2: SignatureCheckResult.secondNotSigned,
    -3: SignatureCheckResult.noMatch,
    -4: SignatureCheckResult.unknownPackage,
  };

  @override
  Future<bool> canPackageQuery({
    required String sourcePackageName,
    required String targetPackageName,
  }) async {
    final queryable = await _channel.invokeMethod<bool>(
      "canPackageQuery",
      {
        "sourcePackageName": sourcePackageName,
        "targetPackageName": targetPackageName,
      },
    );
    return queryable ?? false;
  }

  @override
  Future<List<String>?> canonicalToCurrentPackageNames({
    required List<String> packageNames,
  }) => _channel.invokeListMethod<String>(
    "canonicalToCurrentPackageNames",
    {
      "packageNames": packageNames,
    },
  );

  @override
  Future<CheckPermissionStatus?> checkPermission({
    required String packageName,
    required String permName,
  }) async {
    final checkResult = await _channel.invokeMethod<int>(
      "checkPermission",
      {
        "packageName": packageName,
        "permName": permName,
      },
    );
    return _checkPermissionResultMap[checkResult];
  }

  @override
  Future<SignatureCheckResult> checkSignatures({
    required String packageName1,
    required String packageName2,
  }) async {
    final checkResult = await _channel.invokeMethod<int>(
      "checkSignatures",
      {
        "packageName1": packageName1,
        "packageName2": packageName2,
      },
    );
    return _signatureCheckResultMap[checkResult] ??
        SignatureCheckResult.unknownPackage;
  }

  @override
  Future<List<String>?> currentToCanonicalPackageNames({
    required List<String> packageNames,
  }) => _channel.invokeListMethod<String>(
    "currentToCanonicalPackageNames",
    {
      "packageNames": packageNames,
    },
  );

  @override
  Future<Uint8List?> getActivityDrawableResource({
    required ComponentName componentName,
    required ActivityResourceType type,
  }) {
    const Map<ActivityResourceType, String> availableMethods = {
      ActivityResourceType.banner: "getActivityBanner",
      ActivityResourceType.icon: "getActivityIcon",
      ActivityResourceType.logo: "getActivityLogo",
    };
    return _channel.invokeMethod<Uint8List>(
      availableMethods[type]!,
      componentName.asMap,
    );
  }

  @override
  Future<List<PermissionGroupInfo>?> getAllPermissionGroups({
    PermissionGroupInfoFlags? flags,
  }) async {
    final permissionGroupsData = await _channel.invokeListMethod(
      "getAllPermissionGroups",
      {
        "flags": flags?.flags,
      },
    );
    return permissionGroupsData
        ?.map<PermissionGroupInfo>(
          (data) => PermissionGroupInfoImpl(
            Map<String, dynamic>.from(
              data,
            ),
          ),
        )
        .toList(
          growable: false,
        );
  }

  @override
  Future<bool?> getApplicationEnabledSetting({
    required String packageName,
  }) => _channel.invokeMethod<bool>(
    "getApplicationEnabledSetting",
    {
      "packageName": packageName,
    },
  );

  @override
  Future<Uint8List?> getApplicationIcon({
    required String packageName,
    BitmapCompressFormat format = BitmapCompressFormat.png,
    int quality = 100,
  }) => _channel.invokeMethod<Uint8List>(
    "getApplicationIcon",
    {
      'packageName': packageName,
      'quality': quality.clamp(1, 100,),
      'format': format.index,
    },
  );

  @override
  Future<String?> getApplicationLabel({
    required String packageName,
    ApplicationInfoFlags? flags,
  }) => _channel.invokeMethod<String>(
    "getApplicationLabel",
    {
      "packageName": packageName,
      'flags': flags?.flags,
    },
  );

  @override
  Future<Uint8List?> getActivityIcon({
    required String packageName,
    BitmapCompressFormat format = BitmapCompressFormat.png,
    int quality = 100,
  }) =>
      _channel.invokeMethod<Uint8List>(
        "getActivityIcon",
        {
          'packageName': packageName,
          'quality': quality.clamp(
            1,
            100,
          ),
          'format': format.index,
        },
      );

  @override
  Future<Uint8List?> getActivityLogo({
    required String packageName,
    BitmapCompressFormat format = BitmapCompressFormat.png,
    int quality = 100,
  }) =>
      _channel.invokeMethod<Uint8List>(
        "getActivityLogo",
        {
          'packageName': packageName,
          'quality': quality.clamp(
            1,
            100,
          ),
          'format': format.index,
        },
      );

  @override
  Future<bool?> getComponentEnabledSetting({
    required String packageName,
  }) =>
      _channel.invokeMethod<bool>(
        "getComponentEnabledSetting",
        {
          "packageName": packageName,
        },
      );

  @override
  Future<Uint8List?> getDefaultActivityIcon() =>
      _channel.invokeMethod<Uint8List>(
        "getDefaultActivityIcon",
      );

  @override
  Future<List<ApplicationInfo>?> getInstalledApplications({
    ApplicationInfoFlags? flags,
  }) async {
    final installedApplicationsData = await _channel.invokeListMethod(
      "getInstalledApplications",
      {
        "flags": flags?.flags,
      },
    );
    return installedApplicationsData
        ?.map<ApplicationInfo>(
          (data) => ApplicationInfoImpl(
            Map<String, dynamic>.from(
              data,
            ),
          ),
        )
        .toList(
          growable: false,
        );
  }

  @override
  Future<InstallSourceInfo?> getInstallSourceInfo({
    required String packageName,
  }) async {
    final sourceInfo = await _channel.invokeMapMethod(
      'getInstallSourceInfo',
      {
        'packageName': packageName,
      },
    );
    if (sourceInfo != null) {
      return InstallSourceInfoImpl(
        Map<String, dynamic>.from(
          sourceInfo,
        ),
      );
    }
    return null;
  }

  @override
  Future<List<PackageInfo>?> getInstalledPackages({
    PackageInfoFlags? flags,
  }) async {
    final installedPackagesData = await _channel.invokeListMethod(
      "getInstalledPackages",
      {
        "flags": flags?.flags,
      },
    );
    return installedPackagesData
        ?.map<PackageInfo>(
          (data) => PackageInfoImpl(
            Map<String, dynamic>.from(
              data,
            ),
          ),
        )
        .toList(
          growable: false,
        );
  }

  @override
  Future<String?> getInstallerPackageName({required String packageName}) async {
    final installerPackageName = await _channel.invokeMethod(
      'getInstallerPackageName',
      {
        'packageName': packageName,
      },
    );
    return installerPackageName?.toString();
  }

  @override
  Future<InstrumentationInfo?> getInstrumentationInfo({
    required ComponentName componentName,
  }) async {
    var instrumentationInfoData = await _channel.invokeMapMethod(
      "getInstrumentationInfo",
      componentName.asMap,
    );
    if (instrumentationInfoData != null) {
      return InstrumentationInfoImpl(
        Map<String, dynamic>.from(
          instrumentationInfoData,
        ),
      );
    }
    return null;
  }

  @override
  Future<String?> getNameForUid(int uid) => _channel.invokeMethod<String>(
        "getNameForUid",
        {
          'uid': uid,
        },
      );

  @override
  Future<PackageInfo?> getPackageArchiveInfo({
    required String archiveFilePath,
    PackageInfoFlags? flags,
  }) async {
    final packageData = await _channel.invokeMethod(
      "getPackageArchiveInfo",
      {
        "archiveFilePath": archiveFilePath,
        "flags": flags?.flags,
      },
    );
    if (packageData != null) {
      return PackageInfoImpl(
        Map<String, dynamic>.from(
          packageData,
        ),
      );
    }
    return null;
  }

  @override
  Future<List<int>?> getPackageGids({required String packageName}) async {
    final data = await _channel.invokeListMethod(
      "getPackageGids",
      {
        "packageName": packageName,
      },
    );
    return data?.whereType<int>().toList(
          growable: false,
        );
  }

  @override
  Future<PackageInfo?> getPackageInfo({
    required String packageName,
    PackageInfoFlags? flags,
  }) async {
    final packageData = await _channel.invokeMethod(
      "getPackageInfo",
      {
        "packageName": packageName,
        "flags": flags?.flags,
      },
    );
    if (packageData != null) {
      return PackageInfoImpl(
        Map<String, dynamic>.from(
          packageData,
        ),
      );
    }
    return null;
  }

  @override
  Future<List<String>?> getPackagesForUid(int uid) async {
    final data = await _channel.invokeListMethod("getPackagesForUid", {
      "uid": uid,
    });
    return data?.whereType<String>().toList(
          growable: false,
        );
  }

  @override
  Future<List<PackageInfo>?> getPackagesHoldingPermissions(
      Set<String> permissions) async {
    final packagesData = await _channel.invokeListMethod(
      "getPackagesHoldingPermissions",
      {
        "permissions": permissions.toList(),
      },
    );
    return packagesData
        ?.whereType<Map<String, dynamic>>()
        .map(
          (e) => PackageInfoImpl(
            e,
          ),
        )
        .toList(
          growable: false,
        );
  }

  @override
  Future<PermissionGroupInfo?> getPermissionGroupInfo(
    String packageName,
  ) async {
    final infoData = await _channel.invokeMethod(
      "getPermissionGroupInfo",
      {
        "packageName": packageName,
      },
    );
    if (infoData != null) {
      return PermissionGroupInfoImpl(
        Map<String, dynamic>.from(
          infoData,
        ),
      );
    }
    return null;
  }

  @override
  Future<PermissionInfo?> getPermissionInfo(String permName) async {
    final infoData = await _channel.invokeMethod(
      "getPermissionInfo",
      {
        "permName": permName,
      },
    );
    if (infoData != null) {
      return PermissionInfoImpl(
        Map<String, dynamic>.from(
          infoData,
        ),
      );
    }
    return null;
  }

  @override
  Future<ProviderInfo?> getProviderInfo({
    required ComponentName componentName,
    ComponentInfoFlags? flags,
  }) async {
    final providerData = await _channel.invokeMethod(
      "getProviderInfo",
      {
        ...componentName.asMap,
        "flags": flags?.flags,
      },
    );
    if (providerData != null) {
      return ProviderInfoImpl(
        Map<String, dynamic>.from(
          providerData,
        ),
      );
    }
    return null;
  }

  @override
  Future<ActivityInfo?> getReceiverInfo(
      {required ComponentName componentName, ComponentInfoFlags? flags}) async {
    final receiverData = await _channel.invokeMethod(
      "getReceiverInfo",
      {
        ...componentName.asMap,
        "flags": flags?.flags,
      },
    );
    if (receiverData != null) {
      return ActivityInfoImpl(
        Map<String, dynamic>.from(
          receiverData,
        ),
      );
    }
    return null;
  }

  @override
  Future<ServiceInfo?> getServiceInfo({
    required ComponentName componentName,
    ComponentInfoFlags? flags,
  }) async {
    final serviceData = await _channel.invokeMethod(
      "getServiceInfo",
      {
        ...componentName.asMap,
        "flags": flags?.flags,
      },
    );
    if (serviceData != null) {
      return ServiceInfoImpl(
        Map<String, dynamic>.from(
          serviceData,
        ),
      );
    }
    return null;
  }

  @override
  Future<List<FeatureInfo>?> getSystemAvailableFeatures() async {
    final featureData = await _channel.invokeListMethod(
      "getSystemAvailableFeatures",
    );
    return featureData
        ?.whereType<Map<String, dynamic>>()
        .map(
          (e) => FeatureInfoImpl(
            e,
          ),
        )
        .toList(
          growable: false,
        );
  }

  @override
  Future<List<String>?> getSystemSharedLibraryNames() async {
    final nameData = await _channel.invokeListMethod(
      "getSystemSharedLibraryNames",
    );
    return nameData?.whereType<String>().toList(
          growable: false,
        );
  }

  @override
  Future<bool> hasSigningCertificateByUid({
    required int uid,
    required Uint8List certificateBytes,
    CertificateType type = CertificateType.rawX509,
  }) async {
    final result = await _channel.invokeMethod(
      'hasSigningCertificateWithUid',
      {
        'uid': uid,
        'bytes': certificateBytes,
        'type': type.index,
      },
    );
    return result == true;
  }

  @override
  Future<bool> hasSigningCertificate({
    required String packageName,
    required Uint8List certificateBytes,
    CertificateType type = CertificateType.rawX509,
  }) async {
    final result = await _channel.invokeMethod(
      'hasSigningCertificate',
      {
        'packageName': packageName,
        'bytes': certificateBytes,
        'type': type.index,
      },
    );
    return result == true;
  }

  @override
  Future<bool> hasSystemFeature({required String featureName, int? version}) =>
      _channel.invokeMethod(
        "hasSystemFeature",
        {
          "featureName": featureName,
          "version": version,
        },
      ).then(
        (result) => result == true,
      );

  @override
  Future<bool> isSafeMode() => _channel
      .invokeMethod(
        "isSafeMode",
      )
      .then(
        (result) => result == true,
      );

  @override
  Future<void> launchLeanback(String packageName) async {
    await _channel.invokeMethod(
      "launchLeanback",
      {
        "packageName": packageName,
      },
    );
  }

  @override
  Future<void> openApp(String packageName) async {
    await _channel.invokeMethod(
      "openApp",
      {
        "packageName": packageName,
      },
    );
  }

  @override
  Future<List<ProviderInfo>?> queryContentProviders({
    required int uid,
    String? processName,
    ComponentInfoFlags? flags,
  }) async {
    final providerData = await _channel.invokeListMethod(
      "queryContentProviders",
      {
        "uid": uid,
        "processName": processName,
        "flags": flags?.flags,
      },
    );
    return providerData
        ?.whereType<Map<String, dynamic>>()
        .map(
          (e) => ProviderInfoImpl(
            e,
          ),
        )
        .toList(
          growable: false,
        );
  }

  @override
  Future<List<InstrumentationInfo>?> queryInstrumentation(
    String targetPackage,
  ) async {
    final info = await _channel.invokeListMethod(
      "queryInstrumentation",
    );
    return info
        ?.whereType<Map<String, dynamic>>()
        .map(
          (e) => InstrumentationInfoImpl(
            e,
          ),
        )
        .toList(
          growable: false,
        );
  }

  @override
  Future<List<PermissionInfo>?> queryPermissionsByGroup(
      String permissionGroup) async {
    final info = await _channel.invokeListMethod(
      "queryPermissionsByGroup",
    );
    return info
        ?.whereType<Map<String, dynamic>>()
        .map(
          (e) => PermissionInfoImpl(
            e,
          ),
        )
        .toList(
          growable: false,
        );
  }

  @override
  Future<void> removePermission(String permName) async {
    await _channel.invokeMethod(
      "removePermission",
      {
        "permName": permName,
      },
    );
  }

  @override
  Future<ProviderInfo?> resolveContentProvider({
    required String authority,
    ComponentInfoFlags? flags,
  }) async {
    final providerData = await _channel.invokeMethod(
      "resolveContentProvider",
      {
        "authority": authority,
        "flags": flags?.flags,
      },
    );
    if (providerData != null) {
      return ProviderInfoImpl(
        Map<String, dynamic>.from(
          providerData,
        ),
      );
    }
    return null;
  }

  @override
  Future<void> setApplicationEnabledSetting({
    required String packageName,
    required ComponentEnabledState newState,
    EnabledFlags? flags,
  }) async {
    await _channel.invokeMethod(
      "setApplicationEnabledSetting",
      {
        "packageName": packageName,
        "newState": newState.index,
        "flags": flags?.flags,
      },
    );
  }

  @override
  Future<void> setComponentEnabledSetting({
    required ComponentName componentName,
    required ComponentEnabledState newState,
    EnabledFlags? flags,
  }) async {
    await _channel.invokeMethod(
      "setComponentEnabledSetting",
      {
        ...componentName.asMap,
        "newState": newState.index,
        "flags": flags?.flags,
      },
    );
  }

  @override
  Future<void> setInstallerPackageName({
    required String targetPackage,
    String? installerPackageName,
  }) async {
    await _channel.invokeMethod(
      "setInstallerPackageName",
      {
        "targetPackage": targetPackage,
        "installerPackageName": installerPackageName,
      },
    );
  }

  @override
  Future<void> verifyPendingInstall({
    required int id,
    required VerificationCode verificationCode,
  }) async {
    await _channel.invokeMethod(
      "verifyPendingInstall",
      {
        "id": id,
        "verificationCode": <VerificationCode, int>{
          VerificationCode.allow: 1,
          VerificationCode.reject: -1,
        }[verificationCode],
      },
    );
  }
}
