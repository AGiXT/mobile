import 'package:flutter/foundation.dart';
import 'package:solana_wallet_adapter/solana_wallet_adapter.dart';

/// Centralized helper for interacting with the Solana Mobile Wallet Adapter.
class WalletAdapterService {
  WalletAdapterService._();

  static SolanaWalletAdapter? _adapter;
  static bool _initialized = false;

  /// Wallet types supported by the mobile adapter implementation.
  static const Set<String> _supportedProviders = {'phantom', 'solflare'};

  /// Returns `true` if the provided wallet identifier is supported.
  static bool supportsProvider(String providerId) =>
      _supportedProviders.contains(providerId.toLowerCase());

  /// Initialize the adapter once during application start.
  static Future<void> initialize({
    required String appUri,
    required String appName,
    Cluster? cluster,
  }) async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    try {
      await SolanaWalletAdapter.initialize();
      final Uri? identityUri = Uri.tryParse(appUri);
      _adapter = SolanaWalletAdapter(
        AppIdentity(uri: identityUri, name: appName),
        cluster: cluster ?? Cluster.mainnet,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to initialise Solana wallet adapter: $error');
      debugPrint('$stackTrace');
      _adapter = null;
    }
  }

  /// Returns `true` when a wallet adapter instance is available on this device.
  static bool get isAvailable => _adapter != null;

  static SolanaWalletAdapter get _safeAdapter {
    final adapter = _adapter;
    if (adapter == null) {
      throw StateError(
        'Solana wallet adapter is not available on this device.',
      );
    }
    return adapter;
  }

  /// Connect to the selected wallet application and resolve the active account.
  static Future<Account> connect({String? providerId}) async {
    final adapter = _safeAdapter;
    final Uri? walletUriBase = _walletUriForProvider(adapter, providerId);

    final AuthorizeResult result = await adapter.reauthorizeOrAuthorize(
      walletUriBase: walletUriBase,
    );

    final Account? account =
        adapter.connectedAccount ??
        (result.accounts.isNotEmpty ? result.accounts.first : null);

    if (account == null) {
      throw StateError(
        'Unable to resolve a wallet account after authorization.',
      );
    }

    return account;
  }

  /// Request the wallet to sign the supplied [message] using [account].
  static Future<String> signMessage(
    String message, {
    required Account account,
    String? providerId,
  }) async {
    final adapter = _safeAdapter;

    if (!adapter.isAuthorized) {
      await connect(providerId: providerId);
    }

    final String encodedMessage = adapter.encodeMessage(message);
    final String encodedAccount = adapter.encodeAccount(account);

    final SignMessagesResult result = await adapter.signMessages(
      [encodedMessage],
      addresses: [encodedAccount],
      walletUriBase: _walletUriForProvider(adapter, providerId),
    );

    if (result.signedPayloads.isEmpty) {
      throw StateError('The wallet did not return a signed payload.');
    }

    return result.signedPayloads.first;
  }

  /// Disconnect the current wallet session.
  static Future<void> disconnect() async {
    final adapter = _adapter;
    if (adapter == null) {
      return;
    }

    try {
      await adapter.deauthorize();
    } catch (error) {
      debugPrint('Failed to deauthorise wallet session: $error');
    }
  }

  static Uri? _walletUriForProvider(
    SolanaWalletAdapter adapter,
    String? providerId,
  ) {
    if (providerId == null) {
      return adapter.authorizeResult?.walletUriBase ??
          (adapter.store.apps.isNotEmpty
              ? adapter.store.apps.first.walletUriBase
              : null);
    }

    final String normalized = providerId.toLowerCase();
    if (!supportsProvider(normalized)) {
      return adapter.authorizeResult?.walletUriBase ??
          (adapter.store.apps.isNotEmpty
              ? adapter.store.apps.first.walletUriBase
              : null);
    }

    for (final app in adapter.store.apps) {
      switch (app.app) {
        case App.phantom:
          if (normalized == 'phantom') {
            return app.walletUriBase;
          }
          break;
        case App.solflare:
          if (normalized == 'solflare') {
            return app.walletUriBase;
          }
          break;
      }
    }

    return adapter.authorizeResult?.walletUriBase ??
        (adapter.store.apps.isNotEmpty
            ? adapter.store.apps.first.walletUriBase
            : null);
  }
}
