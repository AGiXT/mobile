// /// Imports
// /// ------------------------------------------------------------------------------------------------

// import 'package:solana_common/convert.dart';
// import '../models/app_info.dart';
// import '../models/sign_and_send_transactions_config.dart';
// import '../models/account.dart';


// /// Browser Extension Provider
// /// ------------------------------------------------------------------------------------------------

// abstract class BrowserExtensionProvider {

//   /// The interface of a wallet adapter browser extension.
//   const BrowserExtensionProvider();

//   /// True if the wallet extension is connected to the application.
//   bool get isConnected;

//   /// The connected account's public key.
//   String? get pubkey;

//   /// App's information of the extension.
//   AppInfo get info;

//   /// Initializes the provider.
//   void initialize();

//   /// Disposes of all acquired resources.
//   void dispose();

//   /// Creates an [Account] from [pubkey].
//   Account? toAccount([final String? pubkey]) {
//     final String? pk = pubkey ?? this.pubkey;
//     return pk != null ? Account(address: base58To64Encode(pk), label: null) : null;
//   }

//   /// Connects the application to the wallet extension.
//   Future connect({ final bool? onlyIfTrusted });

//   /// Disconnects the application from the wallet extension.
//   Future disconnect();

//   /// Signs a `base-58` encoded [transaction] with the wallet's account.
//   Future signTransaction(final String transaction);

//   /// Signs all `base-58` encoded [transactions] with the wallet's account.
//   /// 
//   /// `Multiple transaction signing is currently not supported.`
//   Future signAllTransactions(final List<String> transactions);

//   /// Signs a `base-58` encoded [transaction] with the wallet's account and broadcasts the 
//   /// signed transaction to the Solana network.
//   Future signAndSendTransaction(
//     final String transaction, { 
//     final SignAndSendTransactionsConfig? options, 
//   });

//   /// Signs a `utf8` [message] with the connected account.
//   Future signMessage(final List<int> message);
// }