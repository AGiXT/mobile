import 'package:android_package_manager/android_package_manager.dart';

abstract class InstallSourceInfo {

  const InstallSourceInfo({
    this.initiatingPackageName,
    this.installingPackageName,
    this.originatingPackageName,
    this.initiatingPackageSigningInfo,
  });

  final String? initiatingPackageName;
  final String? installingPackageName;
  final String? originatingPackageName;
  final SigningInfo? initiatingPackageSigningInfo;
}