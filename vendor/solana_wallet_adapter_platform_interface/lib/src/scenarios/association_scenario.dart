/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:solana_jsonrpc/jsonrpc.dart';
import 'package:webcrypto/webcrypto.dart';
import '../../types.dart';
import '../association/association.dart';
import '../sessions/association_session.dart';
import '../sessions/session_state.dart';
import '../sessions/session.dart';
import 'scenario.dart';


/// Association Scenario
/// ------------------------------------------------------------------------------------------------

/// The interface for a scenario that connects a dApp with a wallet application via a websocket.
abstract class AssociationScenario extends Scenario {

  /// Creates a scenario that connects a dApp with a wallet application via a websocket.
  AssociationScenario(
    this.association, {
    required final int? maxAttempts,
    required final List<int>? backoffSchedule,
    required final List<String>? protocols, 
    required super.timeLimit,
  }) {
    _sessionState = SessionState();
    _client = JsonRpcWebsocketClient<List<int>>(
      association.sessionUri(),
      timeLimit: timeLimit,
      maxAttempts: maxAttempts,
      backoffSchedule: backoffSchedule,
      protocols: protocols,
      onPing: onWebsocketPing,
      isPing: isWebsocketPing,
      encoder: _sessionState.encoder,
      decoder: _sessionState.decoder,
    );
  }

  /// The scenario's [Association] information.
  final Association association;

  /// The session keys and sequence numbers.
  late final SessionState _sessionState;

  /// The websocket connection.
  late final JsonRpcWebsocketClient<List<int>> _client;

  /// Called when the dApp receives an APP_PING message from the wallet endpoint.
  void onWebsocketPing(final List<int> data) => null;

  /// Returns true if [data] is an APP_PING message.
  bool isWebsocketPing(final List<int> data) => data.isEmpty;

  /// Performs any setup required by the scenario prior to establishing an encrypted session
  /// (e.g. launching the mobile wallet application or waiting for a ping frame).
  /// 
  /// Throws an exception to abort the request.
  @protected
  Future<void> initialize(
    final JsonRpcWebsocketClient client, 
    final Uri walletUri, { 
    final Duration? timeLimit, 
  });

  @override
  Future<void> dispose() => _client.dispose();

  /// Returns the JSON RPC API for the connected [client].
  FutureOr<Session> session(
    final JsonRpcWebsocketClient<List<int>> client,
  ) => AssociationSession(client);

  @override
  Future<Session> connect({
    final Duration? timeLimit,
    final Uri? walletUriBase,
  }) async {

    // Create a new association keypair.
    final AssociationKeypair associationKeypair = await EcdsaPrivateKey.generateKey(
      EllipticCurve.p256,
    );
    
    // Encode the X9.62 public key as a `base-64 URL`.
    final Uint8List associationRawKey = await associationKeypair.publicKey.exportRawKey();
    final AssociationToken associationToken = base64Url.encode(associationRawKey);

    // Creates the wallet uri.
    final Uri walletUri = association.walletUri(
      associationToken, 
      uriPrefix: walletUriBase,
    );

    // Setup the current scenario.
    final Duration? timeout = timeLimit ?? this.timeLimit;
    await initialize(_client, walletUri, timeLimit: timeout);

    // Create a new session keypair.
    final SessionKeypair sessionKeypair = await EcdhPrivateKey.generateKey(EllipticCurve.p256);

    // The hashing algorithm.
    final Hash hash = Hash.sha256;

    // Send a `hello_req` message and receive the keypoint response.
    final Uint8List sessionRawKey = await sessionKeypair.publicKey.exportRawKey();
    final Uint8List signature = await associationKeypair.privateKey.signBytes(sessionRawKey, hash);
    final JsonRpcClientConfig config = JsonRpcClientConfig(timeLimit: timeout);
    // NOTE: The current websocket implementation ([JsonRpcWebsocketClient]) sends data as a 
    // byte-array ([Uint8List]), otherwise [sessionRawKey + signature] would need to be sent using 
    // Uint8List.fromList(sessionRawKey + signature) to work on web.
    final List<int> keypoint = await _client.handshake(sessionRawKey + signature, config: config);

    // Derive the shared secret.
    const int sharedSecretLength = SessionState.sharedSecretBitLength;
    final int aesGcmSeckeyLength = SessionState.aesGcmSeckeyBitLength;
    final EcdhPublicKey pubkey = await EcdhPublicKey.importRawKey(keypoint, EllipticCurve.p256);
    final Uint8List sharedSecret = await sessionKeypair.privateKey.deriveBits(sharedSecretLength, pubkey);
    final HkdfSecretKey seckey = await HkdfSecretKey.importRawKey(sharedSecret);
    final Uint8List sharedSeckeyBuffer = await seckey.deriveBits(aesGcmSeckeyLength, hash, associationRawKey, const []);
    final SharedSeckey sharedSeckey = await AesGcmSecretKey.importRawKey(sharedSeckeyBuffer);

    // Store the shared secret to encrypt future requests/responses.
    _sessionState.encrypt(sharedSeckey);

    // Return the JSON RPC API.
    return session(_client);
  }
}