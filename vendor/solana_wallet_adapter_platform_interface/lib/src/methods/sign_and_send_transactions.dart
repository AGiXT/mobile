/// Imports
/// ------------------------------------------------------------------------------------------------

import '../models/sign_and_send_transactions_params.dart';
import '../models/sign_and_send_transactions_result.dart';
import 'method.dart';


/// Sign and Send Transactions
/// ------------------------------------------------------------------------------------------------

/// A JSON RPC `sign_and_send_transactions` method.
class SignAndSendTransactions extends JsonRpcAdapterMethod<SignAndSendTransactionsResult> {

  /// Creates a JSON RPC `sign_and_send_transactions` method.
  const SignAndSendTransactions(
    final SignAndSendTransactionsParams params,
  ): super('sign_and_send_transactions', values: params);

  @override
  SignAndSendTransactionsResult decoder(final Map<String, dynamic> value) 
    => SignAndSendTransactionsResult.fromJson(value);
}