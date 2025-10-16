import '../base/permission_info.dart';
import '../enums.dart';

class PermissionInfoImpl extends PermissionInfo {

  PermissionInfoImpl(Map<String, dynamic> data,): super(
    descriptionRes: data['descriptionRes'],
    flags: data['flags'],
    group: data['group'],
    nonLocalizedDescription: data['nonLocalizedDescription'],
    protection: _parseProtectionLevel(data['protection'],),
    protectionFlags: data['protectionFlags'],
    packageItemInfo: data['packageItemInfo'],
  );

  static ProtectionLevel? _parseProtectionLevel(dynamic data,) {
    if (data is int) {
      for (var level in ProtectionLevel.values) {
        if (data == level.index) {
          return level;
        }
      }
    }
    return null;
  }
}

class PermissionGroupInfoImpl extends PermissionGroupInfo {

  PermissionGroupInfoImpl(Map<String, dynamic> data,): super(
    descriptionRes: data['descriptionRes'],
    flags: data['flags'],
    priority: data['priority'],
    packageItemInfo: data['packageItemInfo'],
  );
}