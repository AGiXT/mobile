/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';


/// Sign And Send Transactions Config
/// ------------------------------------------------------------------------------------------------

class SignAndSendTransactionsConfig extends Serializable {

  /// Request configurations options for `sign_and_send_transactions` method calls.
  const SignAndSendTransactionsConfig({
    this.minContextSlot,
  });

  /// The minimum slot number at which to perform preflight transaction checks.
  final int? minContextSlot;

  @override
  Map<String, dynamic> toJson() => {
    'min_context_slot': minContextSlot,
  }..removeWhere((_, value) => value == null);
}