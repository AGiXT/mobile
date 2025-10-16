import 'component_info.dart';

abstract class ProviderInfo extends ComponentInfo {

  ProviderInfo({
    this.authority,
    this.readPermission,
    this.writePermission,
    this.grantUriPermission = false,
    this.multiProcess = false,
    this.initOrder,
    this.flags,
    this.forceUriPermissions = false,
    Map? componentInfo,
  }) : super(
    Map<String, dynamic>.from(componentInfo ?? {},),
  );

  final String? authority;
  final String? readPermission;
  final String? writePermission;
  final bool grantUriPermission;
  final bool multiProcess;
  final int? initOrder;
  final int? flags;
  final bool forceUriPermissions;

}