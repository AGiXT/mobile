/// Imports
/// ------------------------------------------------------------------------------------------------

import '../models/reauthorize_params.dart';
import '../models/reauthorize_result.dart';
import 'method.dart';


/// Reauthorize
/// ------------------------------------------------------------------------------------------------

/// A JSON RPC `reauthorize` method.
class Reauthorize extends JsonRpcAdapterMethod<ReauthorizeResult> {

  /// Creates a JSON RPC `reauthorize` method.
  const Reauthorize(
    final ReauthorizeParams params,
  ): super('reauthorize', values: params);

  @override
  ReauthorizeResult decoder(final Map<String, dynamic> value) 
    => ReauthorizeResult.fromJson(value);
}