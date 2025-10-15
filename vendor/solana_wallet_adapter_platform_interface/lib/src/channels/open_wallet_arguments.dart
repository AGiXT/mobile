/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';
import 'method_names.dart';


/// Open Wallet Arguments
/// ------------------------------------------------------------------------------------------------

/// The method call arguments for [MethodName.openWallet].
class OpenWalletArguments extends Serializable {

  /// The method call arguments for [MethodName.openUri].
  const OpenWalletArguments(
    this.uri, 
  );

  /// The wallet scheme or deep-link url.
  final Uri uri;

  /// {@macro solana_common.Serializable.fromJson}
  factory OpenWalletArguments.fromJson(
    final Map<String, dynamic> json, 
  ) => OpenWalletArguments(
    Uri.parse(json['uri']),
  );

  @override
  Map<String, dynamic> toJson() => {
    'uri': uri.toString(),
  };
}