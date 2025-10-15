/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';
import 'sign_and_send_transactions_config.dart';


/// Sign And Send Transactions Params
/// ------------------------------------------------------------------------------------------------

class SignAndSendTransactionsParams extends Serializable {

  /// Request parameters for `sign_and_send_transactions` method calls.
  const SignAndSendTransactionsParams({
    required this.payloads,
    this.options,
  });

  /// The encoded transactions to sign (`base-64` for mobile applications and `base-58` for desktop 
  /// browsers - use the adapter's `encodeTransaction` method to encode transactions for the current 
  /// platform).
  final List<String> payloads;

  /// The configuration options.
  final SignAndSendTransactionsConfig? options;

  @override
  Map<String, dynamic> toJson() => {
    'payloads': payloads,
    'options': options?.toJson(),
  };
}