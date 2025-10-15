// import 'package:flutter/src/services/message_codec.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// import 'package:solana_wallet_adapter_platform_interface/method_channel_solana_wallet_adapter.dart';
// import 'package:solana_wallet_adapter_platform_interface/solana_wallet_adapter_platform_interface.dart';

// class MockSolanaWalletAdapterPlatform
//     with MockPlatformInterfaceMixin
//     implements SolanaWalletAdapterPlatform {
//   @override
//   Future<bool> closeWallet() {
//     // TODO: implement closeWallet
//     throw UnimplementedError();
//   }

//   @override
//   Future<bool> isWalletInstalled(String id) {
//     // TODO: implement isWalletInstalled
//     throw UnimplementedError();
//   }

//   @override
//   Future<bool> openStore(String id) {
//     // TODO: implement openStore
//     throw UnimplementedError();
//   }

//   @override
//   Future<bool> openUri(Uri uri) {
//     // TODO: implement openUri
//     throw UnimplementedError();
//   }

//   @override
//   Future<bool> openWallet(Uri associationUri) {
//     // TODO: implement openWallet
//     throw UnimplementedError();
//   }

//   @override
//   void setMethodCallHandler(Future Function(MethodCall p1)? handler) {
//     // TODO: implement setMethodCallHandler
//   }
// }

// void main() {
//   final SolanaWalletAdapterPlatform initialPlatform = SolanaWalletAdapterPlatform.instance;

//   test('$MethodChannelSolanaWalletAdapter is the default instance', () {
//     expect(initialPlatform, isInstanceOf<MethodChannelSolanaWalletAdapter>());
//   });
// }
