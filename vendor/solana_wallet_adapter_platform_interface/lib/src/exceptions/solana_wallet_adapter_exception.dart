/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/exceptions.dart' show SolanaException;


/// Solana Wallet Adapter Exception Codes
/// ------------------------------------------------------------------------------------------------

/// Mobile wallet adapter package error codes.
class SolanaWalletAdapterExceptionCode {
  static const int forbiddenWalletBaseUri = 0;
  static const int secureContextRequired = 1;
  static const int walletNotFound = 2;
  static const int cancelled = 3;
  // static const int sessionClosed = 3;
  // static const int sessionKeypair = 4;
  // static const int cancelled = 5;
}


/// Solana Wallet Adapter Exception
/// ------------------------------------------------------------------------------------------------

class SolanaWalletAdapterException extends SolanaException {
  const SolanaWalletAdapterException(
    super.message, {
    super.code,
  });
}