import 'package:android_package_manager/src/entities/entities_impl.dart';

import '../base/service_info.dart';

class ServiceInfoImpl extends ServiceInfo {

  ServiceInfoImpl(Map<String, dynamic> data,) : super(
    permission: data['permission'],
    flags: data['flags'],
    foregroundServiceType: data['foregroundServiceType'],
    componentInfo: data.map(
      (key, value) {
        if (key == 'applicationInfo') {
          return MapEntry(
            key,
            ApplicationInfoImpl(
              Map<String, dynamic>.from(value,),
            ),
          );
        }
        return MapEntry(key, value,);
      },
    ),
  );
}