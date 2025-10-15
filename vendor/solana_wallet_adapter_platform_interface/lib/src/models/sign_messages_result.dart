/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';
import '../models/sign_messages_params.dart';


/// Sign Messages Result
/// ------------------------------------------------------------------------------------------------

class SignMessagesResult extends Serializable {

  /// The result of a successful `sign_messages` request.
  const SignMessagesResult({
    required this.signedPayloads,
  });
  
  /// The `base-64` encoded signed messages ([SignMessagesParams.payloads]).
  final List<String> signedPayloads;

  /// {@macro solana_common.Serializable.fromJson}
  factory SignMessagesResult.fromJson(final Map<String, dynamic> json) 
    => SignMessagesResult(
      signedPayloads: List<String>.from(json['signed_payloads']),
    );
    
  @override
  Map<String, dynamic> toJson() => {
    'signed_payloads': signedPayloads,
  };
}