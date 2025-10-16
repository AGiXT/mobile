/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:convert' show json;
import 'package:solana_common/extensions.dart';
import 'package:solana_common/models.dart';
import 'account.dart';
import '../../types.dart';


/// Authorize Result
/// ------------------------------------------------------------------------------------------------

class AuthorizeResult extends Serializable {

  /// The result of a successful `authorize` request containing the [accounts] authorized by the 
  /// wallet for use by the dApp. You can cache this and use it later to invoke privileged methods.
  const AuthorizeResult({
    required this.accounts,
    required this.authToken,
    required this.walletUriBase,
  });
  
  /// The accounts to which the [authToken] corresponds.
  final List<Account> accounts;

  /// An opaque string representing a unique identifying token issued by the wallet endpoint to the 
  /// dApp endpoint. The dApp endpoint can use this on future connections to reauthorize access to 
  /// privileged methods.
  final AuthToken authToken;

  /// The wallet endpoint's specific URI that should be used for subsequent connections where it 
  /// expects to use this [authToken].
  final Uri? walletUriBase;

  /// Converts a [walletUriBase] string to a [Uri].
  static Uri? _walletUriBaseFromJson(final String? walletUriBase)
    => walletUriBase != null ? Uri.tryParse(walletUriBase) : null;

  /// {@macro solana_common.Serializable.fromJson}
  factory AuthorizeResult.fromJson(final Map<String, dynamic> json) => AuthorizeResult(
    accounts: IterableSerializable.fromJson(json['accounts'], Account.fromJson),
    authToken: json['auth_token'], 
    walletUriBase: _walletUriBaseFromJson(json['wallet_uri_base']),
  );

  /// {@macro solana_common.Serializable.tryFromJson}
  static AuthorizeResult? tryFromJson(final Map<String, dynamic>? json)
    => json != null ? AuthorizeResult.fromJson(json) : null;

  @override 
  Map<String, dynamic> toJson() => {
    'accounts': accounts.toJson(),
    'auth_token': authToken,
    'wallet_uri_base': walletUriBase?.toString(),
  };

  /// Serializes this class into a JSON string.
  String toJsonString() => json.encode(toJson());
}