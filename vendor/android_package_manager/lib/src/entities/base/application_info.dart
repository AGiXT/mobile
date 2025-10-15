import 'package_item_info.dart';

abstract class ApplicationInfo extends PackageItemInfo {
  ApplicationInfo({
    this.className,
    required this.compatibleWidthLimitDp,
    required this.dataDir,
    required this.descriptionRes,
    required this.enabled,
    required this.flags,
    required this.largestWidthLimitDp,
    required this.processName,
    required this.publicSourceDir,
    required this.requiresSmallestWidthDp,
    required this.sourceDir,
    this.splitPublicSourceDirs,
    this.splitSourceDirs,
    this.taskAffinity,
    required this.theme,
    required this.uiOptions,
    required this.uid,
    required this.targetSdkVersion,
    this.manageSpaceActivityName,
    this.nativeLibraryDir,
    this.permission,
    this.sharedLibraryFiles,
    this.backupAgentName,
    this.deviceProtectedDataDir,
    this.minSdkVersion,
    this.category,
    this.splitNames,
    this.storageUuid,
    this.isVirtualPreload,
    this.appComponentFactory,
    this.isProfileableByShell,
    this.isResourceOverlay,
    this.gwpAsanMode,
    this.compileSdkVersion,
    this.compileSdkVersionCodename,
    this.isProfileable,
    this.memtagMode,
    this.nativeHeapZeroInitialized,
    this.requestRawExternalStorageAccess,
    this.areAttributionsUserVisible,
    Map? packageItemInfo,
  }) : super(
          Map<String, dynamic>.from(
            packageItemInfo ?? {},
          ),
        );

  final String? backupAgentName;
  final String? className;
  final int compatibleWidthLimitDp;
  final String? dataDir;
  final int descriptionRes;
  final bool enabled;
  final int flags;
  final int largestWidthLimitDp;
  final String? manageSpaceActivityName;
  final String? nativeLibraryDir;
  final String? permission;
  final String? processName;
  final String? publicSourceDir;
  final int requiresSmallestWidthDp;
  final List<String>? sharedLibraryFiles;
  final String? sourceDir;
  final List<String>? splitPublicSourceDirs;
  final List<String>? splitSourceDirs;
  final int targetSdkVersion;
  final String? taskAffinity;
  final int theme;
  final int uiOptions;
  final int uid;

  final String? deviceProtectedDataDir;
  final int? minSdkVersion;

  final int? category;
  final List<String>? splitNames;
  final String? storageUuid;

  final bool? isVirtualPreload;

  final String? appComponentFactory;

  final bool? isProfileableByShell;
  final bool? isResourceOverlay;

  final int? gwpAsanMode;

  final int? compileSdkVersion;
  final String? compileSdkVersionCodename;
  final bool? isProfileable;
  final int? memtagMode;
  final int? nativeHeapZeroInitialized;
  final int? requestRawExternalStorageAccess;
  final bool? areAttributionsUserVisible;
}
