/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:async' show FutureOr;
import 'package:async/async.dart' show CancelableOperation;
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:solana_common/models.dart';
import 'package:solana_common/validators.dart';
import 'package:solana_jsonrpc/jsonrpc.dart' show Cluster, JsonRpcException, JsonRpcExceptionCode;
import 'package:solana_wallet_adapter_platform_interface/association.dart';
import 'package:solana_wallet_adapter_platform_interface/channels.dart';
import 'package:solana_wallet_adapter_platform_interface/exceptions.dart';
import 'package:solana_wallet_adapter_platform_interface/models.dart';
import 'package:solana_wallet_adapter_platform_interface/solana_wallet_adapter_platform.dart';
import 'package:solana_wallet_adapter_platform_interface/scenarios.dart';
import 'package:solana_wallet_adapter_platform_interface/sessions.dart';
import 'package:solana_wallet_adapter_platform_interface/stores.dart' show StoreInfo;
import 'package:solana_wallet_adapter_platform_interface/types.dart';
import 'package:synchronized/synchronized.dart';
import 'src/solana_wallet_adapter_state.dart';
import 'src/solana_wallet_adapter_storage.dart';


/// Exports
/// ------------------------------------------------------------------------------------------------

export 'package:solana_jsonrpc/jsonrpc.dart' show Cluster;
export 'package:solana_wallet_adapter_platform_interface/association.dart';
export 'package:solana_wallet_adapter_platform_interface/exceptions.dart';
export 'package:solana_wallet_adapter_platform_interface/models.dart';
export 'package:solana_wallet_adapter_platform_interface/stores.dart';
export 'src/solana_wallet_adapter_state.dart';


/// Web Listener
/// ------------------------------------------------------------------------------------------------

class _WebListener extends WebListener {

  /// Web wallet provider event handler.
  const _WebListener();

  /// Returns true if [account] does not match the save account.
  bool _hasChanged(final Account? account) {
    final Account? connectedAccount = SolanaWalletAdapter._storage.connectedAccount;
    return connectedAccount != account;
  }

  @override
  FutureOr<void> onConnect(final Account account) {
    if (_hasChanged(account)) {
      SolanaWalletAdapter._storage.setConnectedAccount(account);
    }
  }

  @override
  FutureOr<void> onDisconnect() {
    if (_hasChanged(null)) {
      SolanaWalletAdapter._storage.setAuthorizeResult(null);
    }
  }

  @override
  FutureOr<void> onAccountChanged(final Account? account) {
    if (_hasChanged(account)) {
      SolanaWalletAdapter._storage.setConnectedAccount(account);
    }
  }
}


/// Solana Wallet Adapter
/// ------------------------------------------------------------------------------------------------

/// An implementation of the `Mobile Wallet Adapter Specifiction` used to invoke methods exposed by 
/// wallet applications.
/// 
/// Initialize the authorization state by calling `[SolanaWalletAdapter.initialize]` when your 
/// application first loads.
/// 
/// Making concurrent requests to a wallet application is `prohibited` and will result in a 
/// [JsonRpcException] being thrown with error code 
/// [JsonRpcExceptionCode.serverErrorSendTransactionPreflightFailure]. A pending request between the 
/// dApp and mobile wallet application can be discarded using [autoCancel]/[cancel].
/// 
/// {@macro solana_wallet_adapter_platform_interface.Session.nonPrivilegedMethods}
/// 
/// {@macro solana_wallet_adapter_platform_interface.Session.privilegedMethods}
class SolanaWalletAdapter {

  /// {@template solana_wallet_adapter}
  /// Creates an adapter to connect the dApp to a wallet application that implements the 
  /// [Mobile Wallet Adapter Specification](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html).
  /// {@endtemplate}
  SolanaWalletAdapter(
    this.identity, {
    this.cluster,
    this.hostAuthority,
    this.timeLimit,
    this.remoteTimeLimit,
    this.autoCancel = true,
  });
  
  /// The dApp's identity information used by the wallet to verify the dApp making the requests.
  /// 
  /// [DApp identity verification](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html#dapp-identity-verification) 
  /// requires you to host a `Digital Asset Links` file at your [AppIdentity.uri].
  /// 
  /// ```
  /// // GET: https:://<YOUR_DOMAIN>/.well-known/assetlinks.json
  /// [{
  ///   "relation": ["delegate_permission/common.handle_all_urls"],
  ///   "target": { 
  ///     "namespace": "android_app", 
  ///     "package_name": "<APPLICATION_ID>",
  ///     "sha256_cert_fingerprints": ["<SHA256_FINGERPRINT>"]
  ///   }
  /// }]
  /// ```
  final AppIdentity identity;

  /// The Solana cluster the dApp endpoint intends to interact with.
  final Cluster? cluster;

  /// {@template solana_wallet_adapter.hostAuthority}
  /// The address of a publicly routable web socket server implementing the reflector protocol to 
  /// establish a remote connection with a wallet running on another device.
  /// {@endtemplate}
  final String? hostAuthority;

  /// The default timeout duration applied to a [Session].
  final Duration? timeLimit;

  /// The default timeout duration applied to a remote [Session] (defaults to [timeLimit]).
  final Duration? remoteTimeLimit;

  /// If true the adapter will automatically cancel a pending request before making a new one to 
  /// the wallet application. Concurrent requests to a wallet application is `prohibited`.
  /// 
  /// `A request made to a wallet browser extension cannot be cancelled, this flag has no effect 
  /// when running on a desktop browser.`
  final bool autoCancel;

  /// The platform specific implementation of the Mobile Wallet Adapter Specification.
  static SolanaWalletAdapterPlatform get _instance => SolanaWalletAdapterPlatform.instance;

  /// The authorization state of the dApp.
  static final _storage = SolanaWalletAdapterStorage();

  /// The lock that prevents multiple connections by a dApp to a wallet endpoint. A dApp can only be 
  /// authorized for use with a single wallet endpoint at a time.
  static final _sessionLock = Lock();

  /// The current session.
  static CancelableOperation? _operation;

  /// {@template solana_wallet_adapter.state}
  /// The authorization state.
  /// {@endtemplate}
  SolanaWalletAdapterState? get state => _storage.state;

  /// {@template solana_wallet_adapter.authorizeResult}
  /// The latest authorization result of an `authorize` or `reauthorize` request.
  /// {@endtemplate}
  AuthorizeResult? get authorizeResult => _storage.authorizeResult;

  /// {@template solana_wallet_adapter.isAuthorized}
  /// True if the dApp has been authorized.
  /// {@endtemplate}
  bool get isAuthorized => authorizeResult != null;

  /// {@template solana_wallet_adapter.connectedAccount}
  /// The connected account and default fee payer.
  /// {@endtemplate}
  Account? get connectedAccount => _storage.connectedAccount;

  /// {@macro solana_wallet_adapter_platform_interface.store}
  StoreInfo get store => _instance.store;

  /// True if the current platform is a desktop browser.
  bool get isDesktopBrowser => _instance.isDesktopBrowser;

  /// Loads the stored [state].
  /// 
  /// `This method should be called when the application is first launched.`
  /// 
  /// # Example
  /// ```
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await SolanaWalletAdapter.initialize(); // Loads the authorization state.
  ///   runApp(const MaterialApp(...));
  /// }
  /// ```
  static Future<void> initialize() async {
    await _storage.initialize();
    final AuthorizeResult? result = _storage.authorizeResult;
    return _instance.initializeWeb(result, const _WebListener());
  }

  /// Cancels the current session.
  /// 
  /// `A request made to a web based browser extension cannot be cancelled, invoking this method 
  /// results in no-op when running on a desktop browser.`
  static Future<void> cancel() async 
    => _instance.isDesktopBrowser ? Future.value() : _operation?.cancel();

  /// Releases all acquired resources.
  Future<void> dispose() async {
    _storage.dispose();
    return cancel();
  }

  /// Clears the stored [state].
  Future<void> clear() => _storage.clear();

  /// Registers [listener] to receive authorization [state] change notifications.
  void addListener(final VoidCallback listener) => _storage.notifier.addListener(listener);

  /// Unregisters [listener] from receiving authorization [state] change notifications.
  void removeListener(final VoidCallback listener) => _storage.notifier.removeListener(listener);
  
  /// {@macro solana_wallet_adapter_platform_interface.openUri}
  Future<bool> openUri(final Uri uri, [final String? target]) => _instance.openUri(uri, target);

  /// {@macro solana_wallet_adapter_platform_interface.encodeTransaction}
  String encodeTransaction(
    final TransactionSerializableMixin transaction, {
    final TransactionSerializableConfig config 
      = const TransactionSerializableConfig(requireAllSignatures: false),
  }) => _instance.encodeTransaction(transaction, config: config);
  
  /// {@macro solana_wallet_adapter_platform_interface.encodeMessage}
  String encodeMessage(final String message) => _instance.encodeMessage(message);

  /// {@macro solana_wallet_adapter_platform_interface.encodeAccount}
  String encodeAccount(final Account account) => _instance.encodeAccount(account);

  /// {@macro solana_wallet_adapter_platform_interface.scenario}
  Scenario scenario() => _instance.scenario();

  /// {@macro solana_wallet_adapter_platform_interface.Session.authorize}
  Future<AuthorizeResult> _authorizeHandler(
    final Session session,
  ) async { 
    final AuthorizeParams params = AuthorizeParams(identity: identity, cluster: cluster);
    final AuthorizeResult result = await session.authorize(params);
    await _storage.setAuthorizeResult(result);
    return result;
  }

  /// {@macro solana_wallet_adapter_platform_interface.Session.authorize}
  Future<AuthorizeResult> authorize({
    final AssociationType? type,
    final String? hostAuthority,
    final Duration? timeLimit,
    final Uri? walletUriBase,
  }) => session(
    type: type, 
    hostAuthority: hostAuthority, 
    timeLimit: timeLimit,
    walletUriBase: walletUriBase,
    _authorizeHandler, 
  );

  /// {@macro solana_wallet_adapter_platform_interface.Session.deauthorize}
  Future<DeauthorizeResult> deauthorize({
    final AssociationType? type,
    final String? hostAuthority,
    final Duration? timeLimit,
    final Uri? walletUriBase,
  }) async {
    final AuthorizeResult? authResult = authorizeResult;
    if (authResult != null) {
      try {
        return await session(
          type: type, 
          hostAuthority: hostAuthority, 
          timeLimit: timeLimit,
          walletUriBase: walletUriBase,
          (session) => session.deauthorize(DeauthorizeParams(authToken: authResult.authToken)),
        );
      } catch(error) {
        // Suppress all errors when disconnecting an application. Errors can be thrown for a number 
        // of reasons. For example, when a previously connected wallet application has been deleted 
        // from the device.
      } finally {
        cancel().ignore();
        await _storage.clearAuthorizeResult(authToken: authResult.authToken);
      }
    }
    return const DeauthorizeResult();
  }

  /// Returns the latest authorization result's auth token.
  /// 
  /// Throws a [SolanaWalletAdapterException] with error code 
  /// [SolanaWalletAdapterExceptionCode.secureContextRequired] if not auth token is found.
  AuthToken _reauthorizeToken() {
    final AuthToken? authToken = authorizeResult?.authToken;
    if (authToken == null) {
      throw const SolanaWalletAdapterException(
        'Invalid auth token, request a new token with the authorize method.',
        code: SolanaWalletAdapterExceptionCode.secureContextRequired,
      );
    }
    return authToken;
  }

  /// {@macro solana_wallet_adapter_platform_interface.Session.reauthorize}
  Future<AuthorizeResult> _reauthorizeHandler(
    final Session session, {
    required final String authToken,
  }) async { 
    final ReauthorizeParams params = ReauthorizeParams(identity: identity, authToken: authToken);
    final ReauthorizeResult result = await session.reauthorize(params);
    await _storage.setAuthorizeResult(result);
    return result;
  }

  /// {@macro solana_wallet_adapter_platform_interface.Session.reauthorize}
  Future<AuthorizeResult> reauthorize({
    final AssociationType? type,
    final String? hostAuthority,
    final Duration? timeLimit,
    final Uri? walletUriBase,
  }) => session(
    type: type, 
    hostAuthority: hostAuthority, 
    timeLimit: timeLimit,
    walletUriBase: walletUriBase,
    (session) => _reauthorizeHandler(session, authToken: _reauthorizeToken()), 
  );

  /// Makes a `reauthorize` request if [_storage] contains an auth token and an `authorize` request 
  /// if [_storage] does not contain an auth token or the reauthorize request fails with 
  /// a [SolanaWalletAdapterProtocolExceptionCode.authorizationFailed] error code.
  Future<AuthorizeResult> _reauthorizeOrAuthorizeHandler(
    final Session session,
  ) async {
    final AuthorizeResult? result = authorizeResult;
    if (result != null) {
      try {
        return await _reauthorizeHandler(session, authToken: result.authToken);
      } on JsonRpcException catch(error, stackTrace) {
        if (error.code != SolanaWalletAdapterProtocolExceptionCode.authorizationFailed) {
          return Future.error(error, stackTrace);
        }
      }
    }
    return _authorizeHandler(session);
  }

  /// Requests dApp `reauthorization` or `authorization` based on the current authorization state.
  Future<AuthorizeResult> reauthorizeOrAuthorize({
    final AssociationType? type,
    final String? hostAuthority,
    final Duration? timeLimit,
    final Uri? walletUriBase,
  }) => session(
    type: type, 
    hostAuthority: hostAuthority, 
    timeLimit: timeLimit,
    walletUriBase: walletUriBase,
    _reauthorizeOrAuthorizeHandler,
  );

  /// {@macro solana_wallet_adapter_platform_interface.Session.getCapabilities}
  Future<GetCapabilitiesResult> getCapabilities({
    final AssociationType? type,
    final String? hostAuthority,
    final Duration? timeLimit,
    final Uri? walletUriBase,
  }) => session(
    type: type, 
    hostAuthority: hostAuthority, 
    timeLimit: timeLimit,
    walletUriBase: walletUriBase, 
    (session) => session.getCapabilities(),
  );

  /// {@macro solana_wallet_adapter_platform_interface.Session.signTransactions}
  Future<SignTransactionsResult> signTransactions(
    final List<String> transactions, {
    final AssociationType? type,
    final String? hostAuthority,
    final Duration? timeLimit,
    final Uri? walletUriBase,
  }) => session(
    type: type, 
    hostAuthority: hostAuthority, 
    timeLimit: timeLimit,
    walletUriBase: walletUriBase,
    (session) async {
      await _reauthorizeHandler(session, authToken: _reauthorizeToken());
      return session.signTransactions(SignTransactionsParams(payloads: transactions));
    },
  );

  /// {@macro solana_wallet_adapter_platform_interface.Session.signAndSendTransactions}
  Future<SignAndSendTransactionsResult> signAndSendTransactions(
    final List<String> transactions, {
    final SignAndSendTransactionsConfig? config,
    final AssociationType? type,
    final String? hostAuthority,
    final Duration? timeLimit,
    final Uri? walletUriBase,
  }) => session(
    type: type, 
    hostAuthority: hostAuthority, 
    timeLimit: timeLimit,
    walletUriBase: walletUriBase,
    (session) async {
      await _reauthorizeHandler(session, authToken: _reauthorizeToken());
      final options = config ?? const SignAndSendTransactionsConfig();
      final params = SignAndSendTransactionsParams(payloads: transactions, options: options);
      return session.signAndSendTransactions(params);
    },
  );

  /// {@macro solana_wallet_adapter_platform_interface.Session.signMessages}
  Future<SignMessagesResult> signMessages(
    final List<String> messages, {
    required final List<String> addresses,
    final AssociationType? type,
    final String? hostAuthority,
    final Duration? timeLimit,
    final Uri? walletUriBase,
  }) => session(
    type: type, 
    hostAuthority: hostAuthority, 
    timeLimit: timeLimit,
    walletUriBase: walletUriBase,
    (session) async {
      await _reauthorizeHandler(session, authToken: _reauthorizeToken());
      return session.signMessages(SignMessagesParams(addresses: addresses, payloads: messages));
    },
  );

  /// {@macro solana_wallet_adapter_platform_interface.Session.cloneAuthorization}
  Future<CloneAuthorizationResult> cloneAuthorization({
    final AssociationType? type,
    required final String? hostAuthority,
    final Duration? timeLimit,
    final Uri? walletUriBase,
  }) => session(
    type: type, 
    hostAuthority: hostAuthority, 
    timeLimit: timeLimit,
    walletUriBase: walletUriBase,
    (session) async {
      await _reauthorizeHandler(session, authToken: _reauthorizeToken());
      return session.cloneAuthorization();
    },
  );

  /// Returns [type]'s adapter scenario.
  Scenario _scenario(
    final AssociationType? type, {
    required final String? hostAuthority,
    required final Duration? timeLimit,
  }) {
    switch(type) {
      case null:
      case AssociationType.local:
        return _instance.scenario(timeLimit: timeLimit);
      case AssociationType.remote:
        final String? host = hostAuthority ?? this.hostAuthority;
        check(host != null, '[SolanaWalletAdapter.hostAuthority] required for `remote`.');
        final Duration? timeout = remoteTimeLimit ?? timeLimit;
        return RemoteAssociationScenario(host!, timeLimit: timeout);
    }
  }

  /// Establishes a secure connection between the dApp and wallet endpoint before invoking 
  /// [callback].
  Future<T> session<T>(
    Future<T> Function(Session) callback, {
    required final AssociationType? type,
    required final String? hostAuthority,
    required final Duration? timeLimit,
    required final Uri? walletUriBase,
  }) async {
    if (autoCancel) {
      await cancel();
    }
    checkThrow(
      !_sessionLock.locked, 
      () => JsonRpcException(
        'Requested resource not available.', 
        code: JsonRpcExceptionCode.serverErrorSendTransactionPreflightFailure, 
      ),
    );
    return _sessionLock.synchronized(
      timeout: Duration.zero,
      () => _session(
        callback, 
        type: type,
        hostAuthority: hostAuthority,
        timeLimit: timeLimit, 
        walletUriBase: walletUriBase,
      ),
    );
  }

  /// Establishes a secure connection between the dApp and wallet endpoint before invoking 
  /// [callback].
  Future<T> _session<T>(
    Future<T> Function(Session) callback, {
    required final AssociationType? type,
    required final String? hostAuthority,
    required final Duration? timeLimit,
    required final Uri? walletUriBase,
  }) async {
    final Uri? base = walletUriBase ?? authorizeResult?.walletUriBase;
    final Scenario scenario = _scenario(type, hostAuthority: hostAuthority, timeLimit: timeLimit);
    try {
      final Duration? timeout = timeLimit ?? this.timeLimit;
      final CancelableOperation operation = _operation = CancelableOperation.fromFuture(
        scenario.connect(timeLimit: timeout, walletUriBase: base).then(callback)
      );
      final T? result = await operation.valueOrCancellation();
      return result ?? (throw const SolanaWalletAdapterException(
        'The request has been cancelled.',
        code: SolanaWalletAdapterExceptionCode.cancelled,
      ));
    } finally {
      scenario.dispose();
    }
  }
}