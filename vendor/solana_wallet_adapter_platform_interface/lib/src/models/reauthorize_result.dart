/// Imports
/// ------------------------------------------------------------------------------------------------

import 'authorize_result.dart';


/// Reauthorize Result
/// ------------------------------------------------------------------------------------------------

/// The result of a successful `reauthorize` request containing the accounts authorized by the 
/// wallet for use by the dApp. You can cache this and use it later to invoke privileged methods.
typedef ReauthorizeResult = AuthorizeResult;