/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';


/// Sign Transactions Params
/// ------------------------------------------------------------------------------------------------

class SignTransactionsParams extends Serializable {

  /// Sign transactions request parameters.
  const SignTransactionsParams({
    required this.payloads,
  });

  /// The encoded transactions to sign (`base-64` for mobile applications and `base-58` for desktop 
  /// browsers - use the adapter's `encodeTransaction` method to encode transactions for the current 
  /// platform).
  final List<String> payloads;

  @override
  Map<String, dynamic> toJson() => {
    'payloads': payloads,
  };
}