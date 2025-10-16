/// Imports
/// ------------------------------------------------------------------------------------------------

import '../models/authorize_params.dart';
import '../models/authorize_result.dart';
import 'method.dart';


/// Authorize
/// ------------------------------------------------------------------------------------------------

/// A JSON RPC `authorize` method.
class Authorize extends JsonRpcAdapterMethod<AuthorizeResult> {

  /// Creates a JSON RPC `authorize` method.
  const Authorize(
    final AuthorizeParams params,
  ): super('authorize', values: params);

  @override
  AuthorizeResult decoder(final Map<String, dynamic> value) 
    => AuthorizeResult.fromJson(value);
}