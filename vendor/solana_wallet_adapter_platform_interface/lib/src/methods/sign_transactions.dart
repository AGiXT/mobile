/// Imports
/// ------------------------------------------------------------------------------------------------

import '../models/sign_transactions_params.dart';
import '../models/sign_transactions_result.dart';
import 'method.dart';


/// Sign Transactions
/// ------------------------------------------------------------------------------------------------

/// A JSON RPC `sign_transactions` method.
class SignTransactions extends JsonRpcAdapterMethod<SignTransactionsResult> {

  /// Creates a JSON RPC `sign_transactions` method.
  const SignTransactions(
    final SignTransactionsParams params,
  ): super('sign_transactions', values: params);

  @override
  SignTransactionsResult decoder(final Map<String, dynamic> value) 
    => SignTransactionsResult.fromJson(value);
}