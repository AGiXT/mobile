import 'package:android_package_manager/src/entities/base/package_item_info.dart';
import 'package:android_package_manager/src/entities/enums.dart';

abstract class PermissionInfo extends PackageItemInfo {

  PermissionInfo({
    this.descriptionRes,
    this.flags,
    this.group,
    this.nonLocalizedDescription,
    this.protection,
    this.protectionFlags,
    Map? packageItemInfo,
  }) : super(
    Map<String, dynamic>.from(packageItemInfo ?? {},),
  );

  final int? descriptionRes;
  final int? flags;
  final String? group;
  final String? nonLocalizedDescription;
  final ProtectionLevel? protection;
  // TODO: Convert to Set of enums
  final int? protectionFlags;
}

abstract class PermissionGroupInfo
    extends PackageItemInfo
    implements Comparable {

  PermissionGroupInfo({
    this.descriptionRes,
    this.flags,
    this.priority,
    Map? packageItemInfo,
  }): super(
    Map<String, dynamic>.from(packageItemInfo ?? {},),
  );

  final int? descriptionRes;
  final int? flags;
  final int? priority;

  @override
  int compareTo(other) {
    if (other is PermissionGroupInfo) {
      final priority = this.priority;
      final otherPriority = other.priority;
      if (priority != null) {
        return priority.compareTo(otherPriority ?? 1,);
      }
      return otherPriority != null ? 1 : 0;
    }
    return -1;
  }
}