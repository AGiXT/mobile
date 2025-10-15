/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';


/// Get Capabilities Result
/// ------------------------------------------------------------------------------------------------

class GetCapabilitiesResult extends Serializable {

  /// The result of a successful `get_capabilities` request.
  const GetCapabilitiesResult({
    required this.supportsCloneAuthorization,
    required this.supportsSignAndSendTransactions,
    required this.maxTransactionsPerRequest,
    required this.maxMessagesPerRequest,
  });

  /// True if the `clone_authorization` method is supported, otherwise false.
  final bool supportsCloneAuthorization;

  /// True if the `sign_and_send_transactions` method is supported, otherwise false.
  final bool supportsSignAndSendTransactions;

  /// If present, the max number of transaction payloads which can be signed by a single 
  /// `sign_transactions` or `sign_and_send_transactions` request. If absent, the implementation
  /// doesn’t publish a specific limit for this parameter.
  final int? maxTransactionsPerRequest;

  /// If present, the max number of transaction payloads which can be signed by a single 
  /// `sign_messages` request. If absent, the implementation doesn’t publish a specific limit for 
  /// this parameter.
  final int? maxMessagesPerRequest;

  /// {@macro solana_common.Serializable.fromJson}
  factory GetCapabilitiesResult.fromJson(final Map<String, dynamic> json) 
    => GetCapabilitiesResult(
      supportsCloneAuthorization: json['supports_clone_authorization'],
      supportsSignAndSendTransactions: json['supports_sign_and_send_transactions'],
      maxTransactionsPerRequest: json['max_transactions_per_request'],
      maxMessagesPerRequest: json['max_messages_per_request'],
  );

  @override 
  Map<String, dynamic> toJson() => {
    'supports_clone_authorization': supportsCloneAuthorization,
    'supports_sign_and_send_transactions': supportsSignAndSendTransactions,
    'max_transactions_per_request': maxTransactionsPerRequest,
    'max_messages_per_request': maxMessagesPerRequest,
  };
}