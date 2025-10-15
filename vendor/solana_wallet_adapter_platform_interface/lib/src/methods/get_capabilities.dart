/// Imports
/// ------------------------------------------------------------------------------------------------

import '../models/get_capabilities_params.dart';
import '../models/get_capabilities_result.dart';
import 'method.dart';


/// Get Capabilities
/// ------------------------------------------------------------------------------------------------

  /// A JSON RPC `get_capabilities` method.
class GetCapabilities extends JsonRpcAdapterMethod<GetCapabilitiesResult> {

  /// Creates a JSON RPC `get_capabilities` method.
  const GetCapabilities(
    final GetCapabilitiesParams params,
  ): super('get_capabilities', values: params);

  @override
  GetCapabilitiesResult decoder(final Map<String, dynamic> value) 
    => GetCapabilitiesResult.fromJson(value);
}