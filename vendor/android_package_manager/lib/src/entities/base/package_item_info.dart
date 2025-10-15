import 'dart:typed_data';

import 'package:android_package_manager/android_package_manager.dart';

class PackageItemInfo {
  PackageItemInfo(
    Map<String, dynamic> data,
  )
      : name = data['name'],
        packageName = data['packageName'],
        labelRes = data['labelRes'],
        nonLocalizedLabel = data['nonLocalizedLabel'],
        icon = data['icon'],
        banner = data['banner'],
        logo = data['logo'],
        metaData = _parseMetaData(
          data['metaData'],
        );

  static Map<String, dynamic>? _parseMetaData(
    dynamic data,
  ) {
    if (data is Map) {
      return Map<String, dynamic>.from(
        data,
      );
    }
    return null;
  }

  Future<Uint8List?> getAppIcon({
    int quality = 100,
    BitmapCompressFormat format = BitmapCompressFormat.png,
  }) async {
    if (packageName != null) {
      return AndroidPackageManager().getApplicationIcon(
        packageName: packageName!,
        format: format,
        quality: quality,
      );
    }
    return null;
  }

  Future<String?> getAppLabel() async {
    if (packageName != null) {
      return AndroidPackageManager()
          .getApplicationLabel(packageName: packageName!);
    }
    return null;
  }

  final String? name;
  final String? packageName;
  final int? labelRes;
  final String? nonLocalizedLabel;
  final int? icon;
  final int? banner;
  final int? logo;
  final Map<String, dynamic>? metaData;
}