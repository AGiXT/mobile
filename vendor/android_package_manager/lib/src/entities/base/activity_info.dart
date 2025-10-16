import 'dart:typed_data';

import 'package:android_package_manager/android_package_manager.dart';

import 'component_info.dart';

abstract class ActivityInfo extends ComponentInfo {

  ActivityInfo({
    this.theme,
    required this.launchMode,
    required this.documentLaunchMode,
    required this.persistableMode,
    this.maxRecents,
    this.permission,
    this.taskAffinity,
    this.targetActivity,
    this.colorMode = ColorMode.defaultColor,
    required this.flags,
    this.screenOrientation = ScreenOrientation.unspecified,
    required this.configChanges,
    this.softInputMode = SoftInputState.unspecified,
    this.uiOptions,
    this.parentActivityName,
    this.rotationAnimation = RotationAnimation.unspecified,
    this.windowLayout,
    this.themeResource,
    Map? componentInfo,
  }): super(
    Map<String, dynamic>.from(componentInfo ?? {},),
  );

  Future<Uint8List?> getIcon({
    int quality = 100,
    BitmapCompressFormat format = BitmapCompressFormat.png,
  }) async {
    if (packageName != null) {
      return AndroidPackageManager().getActivityIcon(
        packageName: packageName!,
        format: format,
        quality: quality,
      );
    }
    return null;
  }

  Future<Uint8List?> getLogo({
    int quality = 100,
    BitmapCompressFormat format = BitmapCompressFormat.png,
  }) async {
    if (packageName != null) {
      return AndroidPackageManager().getActivityLogo(
        packageName: packageName!,
        format: format,
        quality: quality,
      );
    }
    return null;
  }

  final int? theme;
  final LaunchMode launchMode;
  final DocumentLaunchMode documentLaunchMode;
  final PersistableMode persistableMode;
  final int? maxRecents;
  final String? permission;
  final String? taskAffinity;
  final String? targetActivity;
  final ColorMode colorMode;
  final int flags;
  final ScreenOrientation screenOrientation;
  final int configChanges;
  final SoftInputState softInputMode;
  final int? uiOptions;
  final String? parentActivityName;
  final RotationAnimation rotationAnimation;
  final WindowLayout? windowLayout;
  final int? themeResource;

}

abstract class WindowLayout {

  WindowLayout({
    this.width, this.widthFraction,
    this.height, this.heightFraction,
    this.gravity,
    this.minHeight, this.minWidth,
  });

  final int? width;
  final double? widthFraction;
  final int? height;
  final double? heightFraction;
  // Bitmask
  final int? gravity;
  final int? minHeight;
  final int? minWidth;

}