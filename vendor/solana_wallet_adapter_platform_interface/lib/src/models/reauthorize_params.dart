/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';
import 'app_identity.dart';
import '../../types.dart';


/// Reauthorize Params
/// ------------------------------------------------------------------------------------------------

class ReauthorizeParams extends Serializable {

  /// Request parameters for `reauthorize` method calls.
  const ReauthorizeParams({
    required this.identity,
    required this.authToken,
  });

  /// The dApp's identity information.
  final AppIdentity identity;

  /// An opaque string previously returned by a call to `authorize`, `reauthorize`, or 
  /// `cloneAuthorization`.
  final AuthToken authToken;

  @override
  Map<String, dynamic> toJson() => {
    'identity': identity.toJson(),
    'auth_token': authToken,
  };
}