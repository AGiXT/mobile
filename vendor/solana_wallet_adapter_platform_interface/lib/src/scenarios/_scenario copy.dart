// /// Imports
// /// ------------------------------------------------------------------------------------------------

// import 'dart:async';
// import '../../solana_wallet_adapter_platform_interface.dart';


// /// Scenario
// /// ------------------------------------------------------------------------------------------------

// /// The interface of a mobile wallet adapter scenario.
// mixin Scenario implements SolanaWalletAdapterConnection {

//   Uri? walletUriBase;

//   /// Disposes of all the acquired resources.
//   Future<void> dispose([final Object? error, final StackTrace? stackTrace]);

//   /// Establishes an encrypted session between the dApp and wallet endpoints before calling the 
//   /// [callback] function.
//   /// 
//   /// `This method should run in a synchronized block and can only be called once.`
//   Future<T> run<T>(
//     final AssociationCallback<T> callback, {
//     final Duration? timeout,
//     final Uri? walletUriBase,
//     final String? scheme,
//   });
// }