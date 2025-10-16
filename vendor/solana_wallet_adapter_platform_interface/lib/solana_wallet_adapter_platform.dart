/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:convert';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:plugin_platform_interface/plugin_platform_interface.dart' show PlatformInterface;
import 'package:solana_common/models.dart';
import 'channels.dart';
import 'models.dart';
import 'src/scenarios/scenario.dart';
import 'src/stores/store_info.dart';


/// Solana Wallet Adapter Platform
/// ------------------------------------------------------------------------------------------------

/// The interface that implementations of `solana_wallet_adapter` must `extend`.
abstract class SolanaWalletAdapterPlatform extends PlatformInterface {

  /// Solana Wallet Adapter Platform interface for the
  /// [Mobile Wallet Adapter Specification](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html).
  SolanaWalletAdapterPlatform()
    : super(token: _token);

  /// The method channel name.
  static const String channelName = 'com.merigo/solana_wallet_adapter';

  /// The method channel used to interact with the native platform (Flutter -> Platform).
  final _channel = const MethodChannel(channelName);

  /// The private static token object which will be be passed to [PlatformInterface.verifyToken] 
  /// along with a platform interface object for verification.
  static final Object _token = Object();

  /// The platform specific implementation.
  static SolanaWalletAdapterPlatform get instance => _instance;
  static late SolanaWalletAdapterPlatform _instance;
  
  /// Platform-specific implementations should set this with their own platform-specific class that 
  /// extends [SolanaWalletAdapterPlatform] when they register themselves.
  static set instance(final SolanaWalletAdapterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// {@template solana_wallet_adapter_platform_interface.store}
  /// Returns the platform's store handler. 
  /// {@endtemplate}
  StoreInfo get store;

  /// ** For Desktop Browsers Only **
  /// 
  /// True if the current platform implementation is for desktop browsers.
  bool get isDesktopBrowser => false;

  /// ** For Desktop Browsers Only **
  /// 
  /// A web hook for Desktop browsers to initialize state.
  /// 
  /// The wallet adapter should call this method with the saved authorization [result] and an event 
  /// [listener] to update state on changes.
  Future<void> initializeWeb(
    final AuthorizeResult? result, 
    final WebListener listener,
  ) async {
    // Implemented by Desktop browsers. NA to other platforms.
  }

  /// {@template solana_wallet_adapter_platform_interface.scenario}
  /// Returns the platform's scenario handler. 
  /// {@endtemplate}
  Scenario scenario({ final Duration? timeLimit });

  /// Invokes [method] with [arguments] and returns the result.
  Future<bool> _invokeMethod(
    final String method, [
    final Map<String, dynamic>? arguments,
  ]) async => await _channel.invokeMethod(method, arguments) ??  false;

  /// {@template solana_wallet_adapter_platform_interface.openUri}
  /// Launches [uri] and returns true if successful.
  /// {@endtemplate}
  Future<bool> openUri(final Uri uri, [final String? target]) => _invokeMethod(
    MethodName.openUri.name,
    OpenUriArguments(uri, target: target).toJson(),
  );

  /// {@template solana_wallet_adapter_platform_interface.openWallet}
  /// Launches a wallet application for the association [uri].
  /// {@endtemplate}
  Future<bool> openWallet(final Uri uri) => _invokeMethod(
    MethodName.openWallet.name,
    OpenWalletArguments(uri).toJson(),
  );

  /// {@template solana_wallet_adapter_platform_interface.encodeTransaction}
  /// Serializes [transaction] to an encoded string that can passed to the adapter's 
  /// `sign transaction` methods.
  /// {@endtemplate}
  String encodeTransaction(
    final TransactionSerializableMixin transaction, {
    required final TransactionSerializableConfig config,
  }) => base64Encode(transaction.serialize(config).toList(growable: false));

  /// {@template solana_wallet_adapter_platform_interface.encodeMessage}
  /// Encodes a utf-8 [message] to an encoded string that can passed to the adapter's `sign message` 
  /// method.
  /// {@endtemplate}
  String encodeMessage(
    final String message, 
  ) => base64UrlEncode(utf8.encode(message));

  /// {@template solana_wallet_adapter_platform_interface.encodeAccount}
  /// Encodes [account] to an encoded public key address that can passed to the adapter's 
  /// `sign message` method.
  /// {@endtemplate}
  String encodeAccount(
    final Account account, 
  ) => account.address;
}