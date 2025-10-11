import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:solana_wallet_adapter/solana_wallet_adapter.dart';

/// Centralized helper for interacting with the Solana Mobile Wallet Adapter.
class WalletAdapterService {
  WalletAdapterService._();

  static SolanaWalletAdapter? _adapter;
  static bool _initialized = false;

  /// Canonical provider identifiers mapped to their known aliases.
  static const Map<String, List<String>> _providerAliases = {
    'phantom': ['phantom'],
    'solflare': ['solflare'],
    'solana_mobile_stack': [
      'solana_mobile_stack',
      'solana_mobile',
      'solanamobile',
      'solana_mobile_wallet',
      'solanamobilestack',
      'solanamobilewallet',
      'solanamobilevault',
      'solanamobileseeker',
      'solana_mobile_vault',
      'solana_mobile_adapter',
      'solana_mobile_stack_wallet',
      'seeker',
    ],
  };

  /// Returns a canonical provider identifier for the supplied [providerId].
  static String? canonicalProviderId(String providerId) =>
      _canonicalProviderId(providerId);

  /// Returns the set of installed canonical provider identifiers on this device.
  static Set<String> get installedProviderIds => _resolveInstalledProviders();

  /// Returns `true` if the provided wallet identifier is supported and installed.
  static bool supportsProvider(String providerId) {
    final canonical = _canonicalProviderId(providerId);
    if (canonical == null) {
      return false;
    }
    final installed = _resolveInstalledProviders();
    return installed.contains(canonical);
  }

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
    final String? canonicalProvider =
        providerId != null ? _canonicalProviderId(providerId) : null;
    final Uri? walletUriBase = _walletUriForProvider(
      adapter,
      providerId,
      canonicalProvider: canonicalProvider,
    );

    if (canonicalProvider != null &&
        !_resolveInstalledProviders().contains(canonicalProvider)) {
      throw StateError(
        'The selected wallet provider is not installed on this device. '
        'Install the wallet app or choose another provider.',
      );
    }

    try {
      final AuthorizeResult result = await adapter.reauthorizeOrAuthorize(
        walletUriBase: walletUriBase,
      );

      return _extractAccount(adapter, result);
    } on PlatformException catch (error) {
      if (_isActivityNotFound(error)) {
        final Uri? fallbackUri = _defaultWalletUri(
          adapter,
          exclude: walletUriBase,
        );
        if (fallbackUri != null) {
          try {
            final AuthorizeResult fallbackResult = await adapter
                .reauthorizeOrAuthorize(walletUriBase: fallbackUri);
            return _extractAccount(adapter, fallbackResult);
          } on PlatformException catch (fallbackError) {
            if (_isActivityNotFound(fallbackError)) {
              throw StateError(
                canonicalProvider == 'solana_mobile_stack'
                    ? 'No compatible Solana Mobile wallet was found. '
                        'Install the Solana Mobile Vault or choose another provider.'
                    : 'No wallet application was found to handle the selected provider. '
                        'Install the wallet app or choose another provider.',
              );
            }
            rethrow;
          }
        }

        throw StateError(
          'No wallet application was found to handle the selected provider. '
          'Install the wallet app or choose another provider.',
        );
      }

      rethrow;
    }
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
    final String? canonical =
        providerId != null ? _canonicalProviderId(providerId) : null;
    final Uri? walletUriBase = _walletUriForProvider(
      adapter,
      providerId,
      canonicalProvider: canonical,
    );

    final SignMessagesResult result = await adapter.signMessages(
      [encodedMessage],
      addresses: [encodedAccount],
      walletUriBase: walletUriBase,
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
    String? providerId, {
    String? canonicalProvider,
  }) {
    if (providerId == null || canonicalProvider == null) {
      return _defaultWalletUri(adapter);
    }

    Uri? candidate;
    for (final app in adapter.store.apps) {
      final Uri? walletUri = _safeWalletUri(app);
      final String? appCanonical = _canonicalFromStoreApp(app);

      if (appCanonical == canonicalProvider && walletUri != null) {
        return walletUri;
      }

      if (canonicalProvider == 'solana_mobile_stack' &&
          walletUri != null &&
          _looksLikeSolanaMobile(walletUri)) {
        candidate ??= walletUri;
      }
    }

    candidate ??= adapter.authorizeResult?.walletUriBase;

    if (candidate == null && canonicalProvider == 'solana_mobile_stack') {
      candidate = _firstWalletUriMatching(adapter, _looksLikeSolanaMobile);
    }

    return candidate ?? _defaultWalletUri(adapter);
  }

  static Account _extractAccount(
    SolanaWalletAdapter adapter,
    AuthorizeResult result,
  ) {
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

  static Set<String> _resolveInstalledProviders() {
    final adapter = _adapter;
    if (adapter == null) {
      return const {};
    }

    final Set<String> installed = {};

    for (final app in adapter.store.apps) {
      final String? canonical = _canonicalFromStoreApp(app);
      if (canonical != null) {
        installed.add(canonical);
      }

      final Uri? walletUri = _safeWalletUri(app);
      if (walletUri != null) {
        final String? fromUri = _canonicalFromUri(walletUri);
        if (fromUri != null) {
          installed.add(fromUri);
        }
      }
    }

    final Uri? previous = adapter.authorizeResult?.walletUriBase;
    if (previous != null) {
      final String? canonical = _canonicalFromUri(previous);
      if (canonical != null) {
        installed.add(canonical);
      }
    }

    return installed;
  }

  static String? _canonicalFromStoreApp(dynamic app) {
    if (app == null) {
      return null;
    }

    final List<String?> candidates = [];

    try {
      final dynamic enumValue = app.app;
      if (enumValue != null) {
        candidates.add(enumValue.toString());
        try {
          final dynamic nameValue = enumValue.name;
          if (nameValue is String) {
            candidates.add(nameValue);
          }
        } catch (_) {}
      }
    } catch (_) {}

    final Uri? walletUri = _safeWalletUri(app);
    if (walletUri != null) {
      candidates.add(walletUri.scheme);
      candidates.add(walletUri.host);
      candidates.add(walletUri.toString());
    }

    try {
      final dynamic packageId = app.packageId;
      if (packageId is String) {
        candidates.add(packageId);
      }
    } catch (_) {}

    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) {
        continue;
      }

      final String? canonical = _canonicalProviderId(candidate);
      if (canonical != null) {
        return canonical;
      }

      if (candidate.toLowerCase().contains('solanamobile')) {
        return 'solana_mobile_stack';
      }
    }

    return null;
  }

  static Uri? _safeWalletUri(dynamic app) {
    try {
      final dynamic walletUri = app.walletUriBase;
      if (walletUri is Uri) {
        return walletUri;
      }
    } catch (_) {}
    return null;
  }

  static String? _canonicalFromUri(Uri uri) {
    final List<String?> tokens = [
      uri.scheme,
      uri.host,
      uri.path,
      uri.toString(),
    ];

    for (final token in tokens) {
      if (token == null || token.isEmpty) {
        continue;
      }
      final String? canonical = _canonicalProviderId(token);
      if (canonical != null) {
        return canonical;
      }
      if (token.toLowerCase().contains('solanamobile')) {
        return 'solana_mobile_stack';
      }
    }

    return null;
  }

  static Uri? _defaultWalletUri(SolanaWalletAdapter adapter, {Uri? exclude}) {
    for (final app in adapter.store.apps) {
      final Uri? walletUri = _safeWalletUri(app);
      if (walletUri != null && walletUri != exclude) {
        return walletUri;
      }
    }

    final Uri? previous = adapter.authorizeResult?.walletUriBase;
    if (previous != exclude) {
      return previous;
    }

    return null;
  }

  static Uri? _firstWalletUriMatching(
    SolanaWalletAdapter adapter,
    bool Function(Uri) predicate,
  ) {
    for (final app in adapter.store.apps) {
      final Uri? walletUri = _safeWalletUri(app);
      if (walletUri != null && predicate(walletUri)) {
        return walletUri;
      }
    }
    return null;
  }

  static bool _looksLikeSolanaMobile(Uri uri) {
    final String value = uri.toString().toLowerCase();
    return value.contains('solanamobile') || value.contains('seeker');
  }

  static bool _isActivityNotFound(PlatformException error) {
    final String code = error.code.toLowerCase();
    if (code.contains('activity') && code.contains('not')) {
      return true;
    }

    final String message = (error.message ?? '').toLowerCase();
    if (message.contains('activity') &&
        message.contains('not') &&
        message.contains('found')) {
      return true;
    }

    final String details = (error.details ?? '').toString().toLowerCase();
    return details.contains('activity') &&
        details.contains('not') &&
        details.contains('found');
  }

  static String? _canonicalProviderId(String value) {
    if (value.isEmpty) {
      return null;
    }

    final String normalized = _normalizeToken(value);
    if (normalized.isEmpty) {
      return null;
    }

    for (final entry in _providerAliases.entries) {
      for (final alias in entry.value) {
        if (_normalizeToken(alias) == normalized) {
          return entry.key;
        }
      }

      if (_normalizeToken(entry.key) == normalized) {
        return entry.key;
      }
    }

    return null;
  }

  static String _normalizeToken(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
