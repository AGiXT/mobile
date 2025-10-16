/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';
import 'package:solana_jsonrpc/jsonrpc.dart';


/// JSON RPC Adapter Method
/// ------------------------------------------------------------------------------------------------

/// A JSON RPC method handler for wallet adapter endpoints.
abstract class JsonRpcAdapterMethod<T> extends JsonRpcMethod<Map<String, dynamic>, T> {

  /// Creates a JSON RPC method handler for wallet adapter endpoints.
  const JsonRpcAdapterMethod(
    super.method, {
    this.values,
  });

  /// The request's `params` object.
  final Serializable? values;

  @override
  Object? params([final Commitment? commitment]) => values?.toJson();
}