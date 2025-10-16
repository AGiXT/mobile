/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/convert.dart';
import 'package:solana_common/models.dart';


/// Account
/// ------------------------------------------------------------------------------------------------

/// A wallet account.
class Account extends Serializable {

  /// Wallet account information.
  /// 
  /// ```
  /// final account = Account(
  ///   address: 'BQU8XcxOALDAs5yEFghOD61XYpKNty/MMsCqmSiN0QM=', // base-64
  ///   label: 'Wallet 1'
  /// );
  /// ```
  const Account({
    required this.address,
    required this.label,
  });
  
  /// The base-64 encoded address of this account.
  final String address;

  /// A human-readable string that describes this account.
  final String? label;

  /// Returns the base-64 [address] as a base-58 encoded string.
  String toBase58() => base58To64Decode(address);

  @override
  int get hashCode => address.hashCode;

  @override
  bool operator==(final dynamic other) => other is Account && other.address == address;

  /// Creates an [Account] from a base-58 [address].
  factory Account.fromBase58(
    final String address, {
    final String? label,
  }) => Account(
    address: base58To64Encode(address), 
    label: label,
  );

  /// Creates an [Account] from a base-58 [address].
  /// 
  /// Returns `null` if [address] is omitted.
  static Account? tryFromBase58(
    final String? address, {
    final String? label,
  }) => address != null ? Account.fromBase58(address, label: label) : null;


  /// {@macro solana_common.Serializable.fromJson}
  factory Account.fromJson(final Map<String, dynamic> json) => Account(
    address: json['address'], 
    label: json['label'],
  );

  /// {@macro solana_common.Serializable.tryFromJson}
  static Account? tryFromJson(final Map<String, dynamic>? json)
    => json != null ? Account.fromJson(json) : null;

  @override
  Map<String, dynamic> toJson() => {
    'address': address,
    'label': label
  };
}