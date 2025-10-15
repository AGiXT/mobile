import 'package:android_package_manager/src/entities/impl/application_info.dart';

import '../base/provider_info.dart';

class ProviderInfoImpl extends ProviderInfo {

  ProviderInfoImpl(Map<String, dynamic> data,): super(
    authority: data['authority'],
    readPermission: data['readPermission'],
    writePermission: data['writePermission'],
    grantUriPermission: data['grantUriPermission'] ?? false,
    multiProcess: data['multiprocess'] ?? false,
    initOrder: data['initOrder'],
    flags: data['flags'],
    forceUriPermissions: data['forceUriPermissions'] ?? false,
    componentInfo: data.map(
      (key, value) {
        if (key == 'applicationInfo') {
          return MapEntry(
            key,
            ApplicationInfoImpl(Map<String, dynamic>.from(value,),),
          );
        }
        return MapEntry(key, value,);
      },
    ),
  );
}