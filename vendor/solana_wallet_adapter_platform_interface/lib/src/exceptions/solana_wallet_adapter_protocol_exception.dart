/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_jsonrpc/jsonrpc.dart' show JsonRpcException;


/// Solana Wallet Adapter Protocol Exception Codes
/// ------------------------------------------------------------------------------------------------

/// Mobile wallet adapter specification error codes.
class SolanaWalletAdapterProtocolExceptionCode {
  static const int authorizationFailed = -1;
  static const int invalidPayloads = -2;
  static const int notSigned = -3;
  static const int notSubmitted = -4;
  static const int notCloned = -5;
  static const int tooManyPayloads = -6;
  static const int clusterNotSupported = -7;
  static const int attestOriginAndroid = -100;
}


/// Solana Wallet Adapter Protocol Exception
/// ------------------------------------------------------------------------------------------------

typedef SolanaWalletAdapterProtocolException = JsonRpcException;