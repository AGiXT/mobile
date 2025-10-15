// /// Imports
// /// ------------------------------------------------------------------------------------------------

// import 'dart:async';
// import 'dart:convert';
// import 'package:solana_common/convert.dart';
// import 'package:solana_common/exceptions.dart';

// import 'browser_extension_provider.dart';
// import 'scenario.dart';
// import '../models/index.dart';
// import '../utils/types.dart';


// /// Browser Association Scenario
// /// ------------------------------------------------------------------------------------------------

// class BrowserAssociationScenario with Scenario {

//   /// Bridges the Mobile Wallet Adapter Specification interface with a web wallet [provider].
//   BrowserAssociationScenario(
//     this.provider,
//   );

//   /// A web wallet browser extension.
//   final BrowserExtensionProvider provider;

//   @override
//   Future<void> dispose([final Object? error, final StackTrace? stackTrace]) => Future.value();

//   @override
//   Future<T> run<T>(
//     final AssociationCallback<T> callback, {
//     final Duration? timeout, 
//     final Uri? walletUriBase,
//     final String? scheme, 
//   }) {
//     this.walletUriBase = walletUriBase;
//     return timeout != null ? callback(this).timeout(timeout) : callback(this);
//   }

//   @override
//   Future<AuthorizeResult> authorize(final AuthorizeParams params) async {
//     await provider.connect();
//     return _authorizeResult();
//   }

//   @override
//   Future<DeauthorizeResult> deauthorize(final DeauthorizeParams params) async {
//     await provider.disconnect();
//     return const DeauthorizeResult();
//   }

//   @override
//   Future<ReauthorizeResult> reauthorize(final ReauthorizeParams params) {
//     return provider.isConnected 
//       ? _authorizeResult() 
//       : authorize(AuthorizeParams(identity: params.identity, cluster: null));
//   }

//   @override
//   Future<GetCapabilitiesResult> getCapabilities() {
//     throw _methodUnsupported('getCapabilities');
//   }

//   @override
//   Future<SignTransactionsResult> signTransactions(final SignTransactionsParams params) async {
//     _debugAssertSupport(params.payloads.length == 1, 'Signing multiple transactions');
//     final result = await provider.signTransaction(params.payloads.first);
//     return SignTransactionsResult(
//       signedPayloads: [base58To64Encode(result['signature'])],
//     );
//   }

//   @override
//   Future<SignAndSendTransactionsResult> signAndSendTransactions(
//     final SignAndSendTransactionsParams params, 
//   ) async {
//     _debugAssertSupport(params.payloads.length == 1, 'Signing and sending multiple transactions');
//     final result = await provider.signAndSendTransaction(params.payloads.first);
//     return SignAndSendTransactionsResult(
//       signatures: [base58To64Encode(result['signature'])],
//     );
//   }

//   @override
//   Future<SignMessagesResult> signMessages(final SignMessagesParams params) async {
//     _debugAssertSupport(params.addresses.isEmpty, 'Sign messages [addresses]');
//     _debugAssertSupport(params.payloads.length == 1, 'Signing multiple messages');
//     final result = await provider.signMessage(utf8.encode(params.payloads.first));
//     return SignMessagesResult(
//       signedPayloads: [base58To64Encode(result['signature'])],
//     );
//   }

//   @override
//   Future<CloneAuthorizationResult> cloneAuthorization() {
//     throw _methodUnsupported('cloneAuthorization');
//   }

//   /// Creates an [UnsupportedError] for [method].
//   UnsupportedError _methodUnsupported(final String method) {
//     return UnsupportedError('Method [$method] not supported on desktop browser.');
//   }

//   /// Asserts [condition] with error message '[description] not supported.'
//   void _debugAssertSupport(final bool condition, final String description) {
//     assert(condition, '$description not supported.');
//   }
  
//   /// Creates an [AuthorizeResult] from the connected account.
//   Future<AuthorizeResult> _authorizeResult() {
//     final Account? account = provider.toAccount();
//     return account == null
//       ? Future.error(
//           const SolanaException(
//             'Wallet authorization failed.',
//           ),
//         )
//       : Future.value(
//           AuthorizeResult(
//             accounts: [account], 
//             authToken: '__web__', 
//             walletUriBase: walletUriBase,
//           ),
//         );
//   }
// }