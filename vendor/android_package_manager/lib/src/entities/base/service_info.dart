import 'component_info.dart';

abstract class ServiceInfo extends ComponentInfo {

  ServiceInfo({
    this.permission,
    required this.flags,
    this.foregroundServiceType,
    Map? componentInfo,
  }): super(
    Map<String, dynamic>.from(componentInfo ?? {},),
  );

  final String? permission;
  // Bitmask
  final int flags;
  // Bitmask
  final int? foregroundServiceType;
}