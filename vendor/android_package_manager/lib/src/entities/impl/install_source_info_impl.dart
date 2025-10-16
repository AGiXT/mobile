import 'package:android_package_manager/src/entities/base/install_source_info.dart';
import 'package:android_package_manager/src/entities/impl/signing_info_impl.dart';
import 'package:android_package_manager/src/utils/parser_utils.dart';

class InstallSourceInfoImpl extends InstallSourceInfo {

  InstallSourceInfoImpl(Map<String, dynamic> data,): super(
    initiatingPackageName: data['initiatingPackageName'],
    installingPackageName: data['installingPackageName'],
    originatingPackageName: data['originatingPackageName'],
    initiatingPackageSigningInfo: safeMapParse(
      data['initiatingPackageSigningInfo'], (data) => SigningInfoImpl(data,),
    ),
  );
}