/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';
import '../models/sign_transactions_params.dart';


/// Sign Transactions Result
/// ------------------------------------------------------------------------------------------------

class SignTransactionsResult extends Serializable {

  /// The result of a successful `sign_transactions` request.
  const SignTransactionsResult({
    required this.signedPayloads,
  });
  
  /// The `base-64` encoded signed transactions ([SignTransactionsParams.payloads]).
  final List<String> signedPayloads;

  /// {@macro solana_common.Serializable.fromJson}
  factory SignTransactionsResult.fromJson(final Map<String, dynamic> json) 
    => SignTransactionsResult(
      signedPayloads: List<String>.from(json['signed_payloads']),
    );

  @override
  Map<String, dynamic> toJson() => {
    'signed_payloads': signedPayloads,
  };
}