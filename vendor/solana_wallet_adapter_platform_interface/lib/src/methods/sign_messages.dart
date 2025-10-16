/// Imports
/// ------------------------------------------------------------------------------------------------

import '../models/sign_messages_params.dart';
import '../models/sign_messages_result.dart';
import 'method.dart';


/// Sign Messages
/// ------------------------------------------------------------------------------------------------

/// A JSON RPC `sign_messages` method.
class SignMessages extends JsonRpcAdapterMethod<SignMessagesResult> {

  /// Creates a JSON RPC `sign_messages` method.
  const SignMessages(
    final SignMessagesParams params,
  ): super('sign_messages', values: params);

  @override
  SignMessagesResult decoder(final Map<String, dynamic> value) 
    => SignMessagesResult.fromJson(value);
}