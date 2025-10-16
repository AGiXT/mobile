// /// Imports
// /// ------------------------------------------------------------------------------------------------

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:solana_jsonrpc/jsonrpc.dart';
// import '../methods/authorize.dart';
// import '../methods/clone_authorization.dart';
// import '../methods/get_capabilities.dart';
// import '../methods/method.dart';
// import '../methods/reauthorize.dart';
// import '../methods/deauthorize.dart';
// import '../methods/sign_messages.dart';
// import '../methods/sign_and_send_transactions.dart';
// import '../methods/sign_transactions.dart';
// import '../crypto/association_token.dart';
// import '../protocol/solana_wallet_adapter_session.dart';
// import '../../solana_wallet_adapter_platform_interface.dart';
// import '../../solana_wallet_adapter_platform_method.dart';


// /// Native Scenario
// /// ------------------------------------------------------------------------------------------------

// abstract class NativeScenario with Scenario {

//   /// Creates a secure session in which a dApp can call a mobile wallet application's methods using 
//   /// [run].
//   NativeScenario(
//     this.association, {
//     required final int? maxAttempts,
//     required final List<int>? backoffSchedule,
//     required final Iterable<String>? protocols, 
//     this.connectionTimeout,
//     this.exchangeTimeout,
//   }): session = SolanaWalletAdapterSession() 
//   {
//     client = JsonRpcWebsocketClient<List<int>>(
//       association.sessionUri(),
//       maxAttempts: maxAttempts,
//       backoffSchedule: backoffSchedule,
//       protocols: protocols,
//       onConnect: onWebSocketConnect,
//       onDisconnect: onWebSocketDisconnect,
//       onData: onWebSocketData,
//       encoder: session.encoder,
//       decoder: session.decoder,
//     );
//   }

//   /// The scenario's [Association] information.
//   final Association association;

//   /// The connection.
//   @protected
//   late final JsonRpcWebsocketClient<List<int>> client;

//   /// The session keys.
//   @protected
//   final SolanaWalletAdapterSession session;

//   /// The default connection time out
//   final Duration? connectionTimeout;

//   @override
//   final Duration? exchangeTimeout;

//   /// The request queue.
//   // Iterable<WebSocketExchange> get _queue => webSocketExchangeManager.values;

//   /// True if [dispose] has been called.
//   bool _disposed = false;
  
//   /// Disposes of all the acquired resources:
//   /// * Disconnect web socket.
//   /// * Discard session keys.
//   @override
//   Future<void> dispose([final Object? error, final StackTrace? stackTrace]) {
//     if (!_disposed) {
//       _disposed = true;
//       session.dispose();
//       closeUI().ignore();
//       return client.dispose();
//       // return super.dispose(error, stackTrace);
//     } else {
//       return Future.value();
//     }
//   }

//   /// Opens the user interface required to establish a web socket connection (for example, a mobile 
//   /// wallet application).
//   /// 
//   /// Returns true if the UI was launched successfully.
//   @protected
//   Future<bool> openUI(final Uri uri, [final Duration? timeLimit]);

//   /// Cleans up any resources acquired by [openUI].
//   /// 
//   /// Returns true if the method call completes successfully.
//   @protected
//   Future<bool> closeUI();

//   /// Returns true if an app is installed to handle the [scheme].
//   @protected
//   Future<bool> isAppInstalled(final String scheme);
  
//   /// Called when the dApp receives an `APP_PING` message.
//   /// 
//   /// An `APP_PING` is an empty message. It's sent by the reflector to each endpoint when both 
//   /// endpoints have connected to the reflector. On first connecting to a reflector, the endpoints 
//   /// should wait to receive this message before initiating any communications. After any other 
//   /// message has been received, the APP_PING message becomes a no-op, and should be ignored.
//   @protected
//   void onAppPing() => {};

//   /// Called when the dApp and wallet endpoint establish web socket connection.
//   void onWebSocketConnect() {}
  
//   /// Called when the dApp and wallet endpoints disconnect.
//   void onWebSocketDisconnect([final int? code, final String? reason]) {
//     // return dispose(SolanaWalletAdapterException(
//     //   'The web socket has been disconnected.', 
//     //   code: SolanaWalletAdapterExceptionCode.sessionClosed,
//     // )).ignore();
//   }
  
//   /// Called when the dApp receives an [error] from the wallet endpoint.
//   void onWebSocketError(final Object error, [final StackTrace? stackTrace]) {
//     // return dispose(error, stackTrace).ignore();
//   }
  
//   /// Called when the dApp receives [data] from the wallet endpoint.
//   void onWebSocketData(final Map<String, dynamic> data) {
//     try {
//       print('ON DATA $data');
//       // final Uint8List message = Uint8List.fromList(data);
//       // return message.isEmpty ? onAppPing() : _receive(message);
//     } catch (error, stackTrace) {
//       dispose(error, stackTrace);
//     }
//   }

//   /// Invokes the wallet endpoint [method] with [params].
//   Future<T> request<T>(
//     final JsonRpcAdapterMethod<T> method, {
//     final JsonRpcClientConfig? config,
//   }) async {
//     // check(_queue.isEmpty);
//     return (await client.send<T>(method.request(), method.response, config: config)).result!;
//     // return webSocketRequest<T>(association.sessionUri(), request, config: config).unwrap();
//   }

//   // /// Handles a response [message] recevied from the wallet endpoint.
//   // void _receive(final Uint8List message) async {
//   //   check(_queue.length == 1);
//   //   final Map<String, dynamic> json = await _decrypt(message);
//   //   final JsonRpcRequest request = webSocketExchangeManager.first.request;
//   //   final AdapterMethod? method = AdapterMethod.tryFromName(request.method);
//   //   switch (method) {
//   //     case AdapterMethod.hello_req:
//   //       final JsonRpcResponse response = request.toResponse(result: message);
//   //       return _complete(response.toJson(), HelloResult.fromMessage);
//   //     case AdapterMethod.authorize:
//   //       return _complete(json, AuthorizeResult.fromJson);
//   //     case AdapterMethod.deauthorize:
//   //       return _complete(json, DeauthorizeResult.fromJson);
//   //     case AdapterMethod.reauthorize:
//   //       return _complete(json, ReauthorizeResult.fromJson);
//   //     case AdapterMethod.get_capabilities:
//   //       return _complete(json, GetCapabilitiesResult.fromJson);
//   //     case AdapterMethod.sign_transactions:
//   //       return _complete(json, SignTransactionsResult.fromJson);
//   //     case AdapterMethod.sign_and_send_transactions:
//   //       return _complete(json, SignAndSendTransactionsResult.fromJson);
//   //     case AdapterMethod.sign_messages:
//   //       return _complete(json, SignMessagesResult.fromJson);
//   //     case AdapterMethod.clone_authorization:
//   //       return _complete(json, CloneAuthorizationResult.fromJson);
//   //     case null:
//   //       final error = JsonRpcException('No pending request found for method $method.');
//   //       final JsonRpcResponse response = request.toResponse(error: error);
//   //       return _complete(response.toJson(), (e) => e);
//   //   }
//   // }

//   // /// Completes the [json] response with a `success` or `error` [JsonRpcResponse].
//   // void _complete<T, U>(final Map<String, dynamic> json, final JsonRpcParser<T, U> parser) {
//   //   _injectWalletUriBase(json);
//   //   final JsonRpcResponse<T> response = JsonRpcResponse.parse(json, parser);
//   //   webSocketExchangeManager.complete(response, remove: true);
//   // }

//   /// Add [walletUriBase] to the [json] response.
//   /// TODO: consider removing property [walletUriBase] and rely on wallet to provide it.
//   void _injectWalletUriBase(final Map<String, dynamic> json) {
//     final dynamic result = json['result'];
//     if (result is Map) {
//       result['wallet_uri_base'] ??= walletUriBase?.toString();
//     }
//   }
  
//   // /// Encrypts [data] if a secure session has been established. A `hello_req` message is returned if 
//   // /// the session has not been encrypted.
//   // @override
//   // FutureOr<List<int>> encrypt(final List<int> data) {
//   //   return session.isEncrypted 
//   //     ? session.encrypt(data) 
//   //     : session.generateHelloRequest();
//   // }

//   // /// Decrypts [data] if a secure session has been established. A empty object is returned if the 
//   // /// session has not been encrypted.
//   // FutureOr<Map<String, dynamic>> _decrypt(final List<int> data) {
//   //   return session.isEncrypted 
//   //     ? session.decrypt(data) 
//   //     : Future.value({});
//   // }

//   /// Adds a `hello_req` message to the request [_queue] for processing.
//   @protected
//   Future<List<int>> helloRequest() async {
//     final Uint8List hello = await session.generateHelloRequest();
//     return client.handshake(hello);  
//   }

//   /// Establishes an encrypted session between the dApp and wallet endpoints before calling the 
//   /// [callback] function.
//   /// 
//   /// `This method should run in a synchronized block and can only be called once.`
//   Future<T> run<T>(
//     final AssociationCallback<T> callback, {
//     final Duration? timeout,
//     final Uri? walletUriBase,
//     final String? scheme,
//   }) async {

//     // Checks that the app is installed on the device.
//     if (scheme != null && !await isAppInstalled(scheme)) {
//       throw SolanaWalletAdapterException(
//         'The wallet application is not installed.', 
//         code: SolanaWalletAdapterExceptionCode.walletNotFound,
//       );
//     }

//     // Create an association key and get the association token.
//     final AssociationToken associationToken = await session.generateAssociationToken();

//     // Creates the wallet uri.
//     final Uri walletUri = association.walletUri(
//       associationToken, 
//       uriPrefix: walletUriBase,
//     );

//     final Duration? timeLimit = timeout ?? connectionTimeout;

//     // Launch the UI for the current scenario.
//     if (!await openUI(walletUri, timeout)) {
//       throw SolanaWalletAdapterException(
//         'The wallet application could not be opened.', 
//         code: SolanaWalletAdapterExceptionCode.walletNotFound,
//       );
//     }

//     // Listen for `ping` messages to keep the application alive in the background.
//     SolanaWalletAdapterPlatform.instance.setMethodCallHandler(_onMethodCall);

//     // Start the web socket connection.
//     await client.connect(
//       timeLimit: timeLimit,
//     );

//     // Create a new ECDH keypair.
//     await session.generateSessionKeypair();

//     // Send a `hello_req` message to encrypt the session.
//     final List<int> keypoint = await helloRequest();    

//     // Create the shared secret key.
//     await session.generateSharedSecretKey(keypoint);  

//     // Set wallet uri base for applications that do not return it.
//     this.walletUriBase = walletUriBase;

//     // Once encrypted, run the callback function.
//     return callback(this);
//   }

//   /// Handles incoming messages from the native platform (Android or IOS).
//   static Future _onMethodCall(final MethodCall call) async {
//     if (call.method == SolanaWalletAdapterPlatformMethod.ping.name) {
//     }
//   }

//   /// {@macro solana_wallet_adapter_platform_interface.authorize}
//   Future<AuthorizeResult> authorize(final AuthorizeParams params) 
//     => request(Authorize(params));

//   /// {@macro solana_wallet_adapter_platform_interface.deauthorize}
//   Future<DeauthorizeResult> deauthorize(final DeauthorizeParams params)
//     => request<DeauthorizeResult>(Deauthorize(params));

//   /// {@macro solana_wallet_adapter_platform_interface.reauthorize}
//   Future<ReauthorizeResult> reauthorize(final ReauthorizeParams params) 
//     => request<ReauthorizeResult>(Reauthorize(params));

//   /// {@macro solana_wallet_adapter_platform_interface.getCapabilities}
//   Future<GetCapabilitiesResult> getCapabilities() 
//     => request<GetCapabilitiesResult>(GetCapabilities(const GetCapabilitiesParams()));

//   /// {@macro solana_wallet_adapter_platform_interface.signTransactions}
//   Future<SignTransactionsResult> signTransactions(final SignTransactionsParams params) 
//     => request<SignTransactionsResult>(SignTransactions(params));

//   /// {@macro solana_wallet_adapter_platform_interface.signAndSendTransactions}
//   Future<SignAndSendTransactionsResult> signAndSendTransactions(
//     final SignAndSendTransactionsParams params,
//   ) => request<SignAndSendTransactionsResult>(SignAndSendTransactions(params));
  
//   /// {@macro solana_wallet_adapter_platform_interface.signMessages}
//   Future<SignMessagesResult> signMessages(final SignMessagesParams params) 
//     => request<SignMessagesResult>(SignMessages(params));

//   /// {@macro solana_wallet_adapter_platform_interface.cloneAuthorization}
//   Future<CloneAuthorizationResult> cloneAuthorization() 
//     => request<CloneAuthorizationResult>(CloneAuthorization(const CloneAuthorizationParams()));
// }