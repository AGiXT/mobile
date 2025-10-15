import 'package_item_info.dart';

abstract class InstrumentationInfo extends PackageItemInfo {
  InstrumentationInfo({
    this.targetPackage,
    this.sourceDir,
    this.publicSourceDir,
    this.splitSourceDirs,
    this.splitPublicSourceDirs,
    this.dataDir,
    this.handleProfiling = false,
    this.functionalTest = false,
    Map? packageItemInfo,
  }) : super(
    Map<String, dynamic>.from(packageItemInfo ?? {},),
  );

  final String? targetPackage;
  final String? sourceDir;
  final String? publicSourceDir;
  final List<String>? splitSourceDirs;
  final List<String>? splitPublicSourceDirs;
  final String? dataDir;
  final bool handleProfiling;
  final bool functionalTest;
}