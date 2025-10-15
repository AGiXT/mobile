/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:solana_common/models.dart';
import 'package:solana_wallet_adapter_platform_interface/models.dart';


/// Solana Wallet Adapter State
/// ------------------------------------------------------------------------------------------------

/// The latest authorization state.
class SolanaWalletAdapterState extends Serializable {

  /// The wallet adapter's current state.
  const SolanaWalletAdapterState({
    this.authorizeResult,
    this.connectedAccount,
  });

  /// The latest result of a successful `authorize` request.
  final AuthorizeResult? authorizeResult;

  /// The connected account and default fee payer.
  final Account? connectedAccount;
  
  /// {@macro solana_common.Serializable.fromJson}
  factory SolanaWalletAdapterState.fromJson(
    final Map<String, dynamic> json,
  ) => SolanaWalletAdapterState(
    authorizeResult: AuthorizeResult.tryFromJson(json['authorizeResult']),
    connectedAccount: Account.tryFromJson(json['connectedAccount']),
  );

  /// Creates an instance of `this` class from a json encoded string of the constructor parameters.
  /// 
  /// ```
  /// SolanaWalletAdapterState.fromJsonString('{ <parameter>: <value> }');
  /// ```
  factory SolanaWalletAdapterState.fromJsonString(final String jsonString) 
    => SolanaWalletAdapterState.fromJson(jsonDecode(jsonString));

  @override
  Map<String, dynamic> toJson() => {
    'authorizeResult': authorizeResult,   // jsonEncode calls .toJson()
    'connectedAccount': connectedAccount, // jsonEncode calls .toJson()
  };

  /// Serializes this class into a JSON string.
  String toJsonString() => jsonEncode(toJson());
}