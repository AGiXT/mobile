import 'package:android_package_manager/src/entities/base/application_info.dart';
import 'package:android_package_manager/src/entities/base/package_item_info.dart';

class ComponentInfo extends PackageItemInfo {

  final ApplicationInfo applicationInfo;
  final String processName;
  final String? splitName;
  final List<String>? attributionTags;
  final int? descriptionRes;
  final bool enabled;
  final bool exported;
  final bool? directBootAware;
  final bool isEnabled;
  final int? iconResource;
  final int? logoResource;
  final int? bannerResource;

  ComponentInfo(Map<String, dynamic> data,)
      : applicationInfo = data['applicationInfo'],
        processName = data['processName'],
        splitName = data['splitName'],
        attributionTags = data['attributionTags']?.whereType<String>().toList(growable: false,),
        descriptionRes = data['descriptionRes'],
        enabled = data['enabled'],
        exported = data['exported'],
        directBootAware = data['directBootAware'],
        isEnabled = data['isEnabled'],
        iconResource = data['iconResource'],
        logoResource = data['logoResource'],
        bannerResource = data['bannerResource'],
        super(data,);
}