import 'dart:typed_data';

abstract class SigningInfo {

  const SigningInfo({
    this.signingCertificateHistory,
    this.apkContentSigners,
    this.hasPastSigningCertificates = false,
    this.hasMultipleSigners = false,
  });

  final List<Uint8List>? signingCertificateHistory;
  final List<Uint8List>? apkContentSigners;
  final bool hasPastSigningCertificates;
  final bool hasMultipleSigners;
}