/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_jsonrpc/jsonrpc.dart';
import '../../constants.dart';
import '../../solana_wallet_adapter_platform.dart';
import '../association/local_association.dart';
import '../exceptions/solana_wallet_adapter_exception.dart';
import 'association_scenario.dart';


/// Mobile Association Scenario
/// ------------------------------------------------------------------------------------------------

/// A scenario for connecting to a wallet application running on a mobile device.
class MobileAssociationScenario extends AssociationScenario {

  /// Creates a local association between the dApp and wallet endpoint, which can be used to make 
  /// method calls within a secure session.
  MobileAssociationScenario({
    final int? port,
    required final Duration? timeLimit,
  }): super(
      LocalAssociation(port: port),
      // If [timeLimit] is provided set [maxAttempts] to any value that will exceed [timeLimit].
      maxAttempts: timeLimit != null ? timeLimit.inSeconds : 34, // ~ 30 seconds
      backoffSchedule: const [150, 150, 200, 500, 500, 750, 750, 1000],
      protocols: const [websocketProtocol],
      timeLimit: timeLimit,
    );

  @override
  Future<void> initialize(
    final JsonRpcWebsocketClient client, 
    final Uri walletUri, {
    final Duration? timeLimit,
  }) async {
    if (!await SolanaWalletAdapterPlatform.instance.openWallet(walletUri)) {
      throw SolanaWalletAdapterException(
        'The wallet application could not be opened.', 
        code: SolanaWalletAdapterExceptionCode.walletNotFound,
      );
    }
  }
}