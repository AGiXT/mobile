import 'package:android_package_manager/src/entities/base/signing_info.dart';
import 'package:android_package_manager/src/utils/parser_utils.dart';

class SigningInfoImpl extends SigningInfo {

  SigningInfoImpl(Map<String, dynamic> data,): super(
    signingCertificateHistory: asTypedList(data['signingCertificateHistory'],),
    apkContentSigners: asTypedList(data['apkContentSigners'],),
    hasPastSigningCertificates: data['hasPastSigningCertificates'] ?? false,
    hasMultipleSigners: data['hasMultipleSigners'] ?? false,
  );
}