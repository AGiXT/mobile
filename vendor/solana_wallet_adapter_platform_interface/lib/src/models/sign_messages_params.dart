/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';


/// Sign Messages Params
/// ------------------------------------------------------------------------------------------------

class SignMessagesParams extends Serializable {

  /// Sign messages request parameters.
  const SignMessagesParams({
    required this.addresses,
    required this.payloads,
  });

  /// The encoded addresses of the accounts which should be used to sign message (`base-64` for 
  /// mobile applications and `base-58` for desktop browsers - use the adapter's `encodeAccount` 
  /// method to encode [Account]s for the current platform). These 
  /// should be a subset of the addresses returned by authorize or reauthorize for the current 
  /// session’s authorization.
  final List<String> addresses;

  /// The encoded messages to sign (`base-64 URL` for mobile applications and `utf-8` for desktop 
  /// browsers - use the adapter's `encodeMessage` method to encode messages for the current 
  /// platform).
  final List<String> payloads;

  @override
  Map<String, dynamic> toJson() => {
    'addresses': addresses,
    'payloads': payloads,
  };
}