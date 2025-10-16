/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';


/// Deauthorize Result
/// ------------------------------------------------------------------------------------------------

class DeauthorizeResult extends Serializable {

  /// The result of a successful `deauthorize` request.
  const DeauthorizeResult();

  /// {@macro solana_common.Serializable.fromJson}
  factory DeauthorizeResult.fromJson(final Map<String, dynamic> json) => const DeauthorizeResult();

  @override 
  Map<String, dynamic> toJson() => {};
}