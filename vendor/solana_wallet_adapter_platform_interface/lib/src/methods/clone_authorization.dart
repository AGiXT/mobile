/// Imports
/// ------------------------------------------------------------------------------------------------

import '../models/clone_authorization_params.dart';
import '../models/clone_authorization_result.dart';
import 'method.dart';


/// Clone Authorization
/// ------------------------------------------------------------------------------------------------

/// A JSON RPC `clone_authorization` method.
class CloneAuthorization extends JsonRpcAdapterMethod<CloneAuthorizationResult> {

  /// Creates a JSON RPC `clone_authorization` method.
  const CloneAuthorization(
    final CloneAuthorizationParams params,
  ): super('clone_authorization', values: params);

  @override
  CloneAuthorizationResult decoder(final Map<String, dynamic> value) 
    => CloneAuthorizationResult.fromJson(value);
}