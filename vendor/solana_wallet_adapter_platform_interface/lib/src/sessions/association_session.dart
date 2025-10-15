/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:async';
import 'package:solana_jsonrpc/jsonrpc.dart';
import '../methods/authorize.dart';
import '../methods/clone_authorization.dart';
import '../methods/deauthorize.dart';
import '../methods/get_capabilities.dart';
import '../methods/method.dart';
import '../methods/reauthorize.dart';
import '../methods/sign_and_send_transactions.dart';
import '../methods/sign_messages.dart';
import '../methods/sign_transactions.dart';
import '../../models.dart';
import 'session.dart';


/// Session
/// ------------------------------------------------------------------------------------------------

/// A websocket session between the dApp and wallet application.
class AssociationSession extends Session {

  /// Creates a websocket session between the dApp and wallet application.
  AssociationSession(
    this._client,
  );

  /// The encrypted websocket connection.
  final JsonRpcWebsocketClient<List<int>> _client;

  /// Invokes the wallet application [method].
  Future<T> _send<T>(final JsonRpcAdapterMethod<T> method) async {
    final result = await _client.send(method.request(), method.response);
    return result.result!;
  }

  @override
  Future<AuthorizeResult> authorize(
    final AuthorizeParams params,
  ) => _send(Authorize(params));

  @override
  Future<DeauthorizeResult> deauthorize(
    final DeauthorizeParams params,
  ) => _send(Deauthorize(params));

  @override
  Future<ReauthorizeResult> reauthorize(
    final ReauthorizeParams params,
  ) => _send(Reauthorize(params));

  @override
  Future<GetCapabilitiesResult> getCapabilities(
  ) => _send(GetCapabilities(const GetCapabilitiesParams()));

  @override
  Future<SignTransactionsResult> signTransactions(
    final SignTransactionsParams params,
  ) => _send(SignTransactions(params));

  @override
  Future<SignAndSendTransactionsResult> signAndSendTransactions(
    final SignAndSendTransactionsParams params, 
  ) => _send(SignAndSendTransactions(params));

  @override
  Future<SignMessagesResult> signMessages(
    final SignMessagesParams params,
  ) => _send(SignMessages(params));

  @override
  Future<CloneAuthorizationResult> cloneAuthorization(
  ) => _send(CloneAuthorization(const CloneAuthorizationParams()));
}