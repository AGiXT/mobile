/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana_wallet_adapter_platform_interface/models.dart';
import 'package:solana_wallet_adapter_platform_interface/types.dart';
import 'solana_wallet_adapter_state.dart';


/// Solana Wallet Adapter Storage
/// ------------------------------------------------------------------------------------------------

/// Stores the wallet adapter's latest authorization state.
class SolanaWalletAdapterStorage {

  /// The storage instance.
  static Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  /// The storage key.
  static const String _key = 'com.merigo.solana_wallet_adapter/storage';

  /// The storage value/notifier.
  Listenable get notifier => _notifier;
  static final ValueNotifier<SolanaWalletAdapterState?> _notifier = ValueNotifier(null);

  /// The current authorization state.
  SolanaWalletAdapterState? get state => _notifier.value;

  /// The [state]'s [SolanaWalletAdapterState.authorizeResult].
  AuthorizeResult? get authorizeResult => state?.authorizeResult;

  /// The [state]'s [SolanaWalletAdapterState.connectedAccount].
  /// 
  /// Returns `null` if the set account has not been authorized by the wallet endpoint (i.e. the 
  /// account does not exist within the [state]'s [SolanaWalletAdapterState.authorizeResult] 
  /// accounts list).
  Account? get connectedAccount => state?.connectedAccount;

  /// Loads the stored data into memory. 
  /// 
  /// This method should be called at the start of your application, before accessing any instance 
  /// properties or methods.
  Future<void> initialize() async {
    final String? value = (await _storage).getString(_key);
    _notifier.value = value != null ? SolanaWalletAdapterState.fromJsonString(value) : null;
  }

  /// Clears all stored data.
  Future<bool> clear() async {
    if (_notifier.value != null) {
      final SharedPreferences prefs = await _storage;
      final bool removed = await prefs.remove(_key);
      if (removed) _notifier.value = null;
    }
    return _notifier.value == null;
  }

  /// Disposes of the value [notifier].
  void dispose() => _notifier.dispose();

  /// Registers [listener] to receive storage data change notifications.
  void addListener(final VoidCallback listener) => _notifier.addListener(listener);

  /// Unregisters [listener] to stop receiving storage data change notifications.
  void remoteListener(final VoidCallback listener) => _notifier.removeListener(listener);

  /// Sets [authorizeResult] and [connectedAccount] as the new state.
  /// 
  /// If [connectedAccount] is `provided` it must exist in the [AuthorizeResult.accounts], otherwise 
  /// it will be set to `null`.
  /// 
  /// If [connectedAccount] is `omitted` it will default to the first account in 
  /// [AuthorizeResult.accounts]. To prevent the method from applying a default value, set 
  /// [applyDefaultConnectedAccount] to `false`.
  Future<bool> _setState({
    required final AuthorizeResult? authorizeResult,
    required final Account? connectedAccount,
    required final bool applyDefaultConnectedAccount,
  }) async {
    if (authorizeResult?.authToken != this.authorizeResult?.authToken) {
      Account? connected;
      if (applyDefaultConnectedAccount && authorizeResult != null) {
        if (authorizeResult.accounts.length == 1) {
          connected = authorizeResult.accounts.first;
        } else if (authorizeResult.accounts.contains(connectedAccount)) {
          connected = connectedAccount;
        }
      }
      final SolanaWalletAdapterState value = SolanaWalletAdapterState(
        authorizeResult: authorizeResult, 
        connectedAccount: connected,
      );
      _notifier.value = value;
      final SharedPreferences prefs = await _storage;
      return prefs.setString(_key, value.toJsonString());
    } else {
      return true;
    }
  }

  /// Sets the [state]'s [SolanaWalletAdapterState.authorizeResult].
  Future<bool> setAuthorizeResult(final AuthorizeResult? authorizeResult) async {
    return _setState(
      authorizeResult: authorizeResult,
      connectedAccount: state?.connectedAccount,
      applyDefaultConnectedAccount: true,
    );
  }

  /// Clears the [state]'s [SolanaWalletAdapterState.authorizeResult] for the provided [authToken].
  Future<bool> clearAuthorizeResult({ required final AuthToken authToken }) async {
    final AuthToken? token = state?.authorizeResult?.authToken;
    return token == authToken ? setAuthorizeResult(null) : Future.value(true);
  }

  /// Sets the [state]'s [SolanaWalletAdapterState.connectedAccount].
  Future<bool> setConnectedAccount(final Account? connectedAccount) async {
    return _setState(
      authorizeResult: state?.authorizeResult,
      connectedAccount: connectedAccount,
      applyDefaultConnectedAccount: connectedAccount != null,
    );
  }

  /// Clears the [state]'s [SolanaWalletAdapterState.connectedAccount].
  Future<bool> clearConnectedAccount() => setConnectedAccount(null);
}