/// Imports
/// ------------------------------------------------------------------------------------------------

import '../models/deauthorize_params.dart';
import '../models/deauthorize_result.dart';
import 'method.dart';


/// Deauthorize
/// ------------------------------------------------------------------------------------------------

/// A JSON RPC `deauthorize` method.
class Deauthorize extends JsonRpcAdapterMethod<DeauthorizeResult> {

  /// Creates a JSON RPC `deauthorize` method.
  const Deauthorize(
    final DeauthorizeParams params,
  ): super('deauthorize', values: params);

  @override
  DeauthorizeResult decoder(final Map<String, dynamic> value) 
    => DeauthorizeResult.fromJson(value);
}