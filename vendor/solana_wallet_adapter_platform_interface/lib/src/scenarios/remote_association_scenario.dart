/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:async' show Completer;
import 'package:solana_jsonrpc/jsonrpc.dart';
import '../../constants.dart';
import '../association/remote_association.dart';
import 'association_scenario.dart';


/// Remote Association Scenario
/// ------------------------------------------------------------------------------------------------

/// A scenario for connecting to a wallet application running on a different device.
class RemoteAssociationScenario extends AssociationScenario {

  /// Creates a remote association between the dApp and a wallet application running on a different 
  /// device.
  /// 
  /// [hostAuthority] is the websocket server that brokers communication between the dApp and 
  /// a remote wallet application.
  RemoteAssociationScenario(
    final String hostAuthority, {
    final int? id,
    required final Duration? timeLimit,
  }): super(
      RemoteAssociation(
        hostAuthority: hostAuthority, 
        id: id,
      ),
      // If [timeLimit] is provided set [maxAttempts] to any value that will exceed [timeLimit].
      maxAttempts: timeLimit != null ? timeLimit.inSeconds : 122, // ~ 2 minutes.
      backoffSchedule: const [1000, 500, 500, 500, 500, 1000],
      protocols: const [websocketProtocol, websocketReflectorProtocol],
      timeLimit: timeLimit,
    );

  /// Completes when an APP_PING message is received.
  final Completer<void> _pingCompleter = Completer();

  /// "An APP_PING is an empty message. It is sent by the reflector to each endpoint when both 
  /// endpoints have connected to the reflector. On first connecting to a reflector, the endpoints 
  /// should wait to receive this message before initiating any communications. After any other 
  /// message has been received, the APP_PING message becomes a no-op, and should be ignored." 
  /// [source](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html#app_ping)
  @override
  void onWebsocketPing(final List<int> data) {
    if (!_pingCompleter.isCompleted) {
      _pingCompleter.complete();
    }
  }

  @override
  Future<void> initialize(
    final JsonRpcWebsocketClient client, 
    final Uri walletUri, {
    final Duration? timeLimit,
  }) async {
    await client.connect(timeLimit: timeLimit);
    await _pingCompleter.future;
  }
}