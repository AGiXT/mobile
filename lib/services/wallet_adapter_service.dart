import 'dart:io' show Platform;

import 'package:android_package_manager/android_package_manager.dart'
    hide LaunchMode;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:solana_wallet_adapter/solana_wallet_adapter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Centralized helper for interacting with the Solana Mobile Wallet Adapter.
class WalletAdapterService {
  WalletAdapterService._();

  static SolanaWalletAdapter? _adapter;
  static bool _initialized = false;
  static bool _assumeSolanaMobileStack = false;

  static const Set<String> _solanaMobilePackageIds = {
    'com.solanamobile.wallet',
    'com.solanamobile.walletapp',
    'com.solanamobile.seeker',
    'com.solana.mobilewallet',
    'com.solana.mobile.wallet',
    'com.solana.seeker.wallet',
  };

  static final List<Uri> _solanaMobileFallbackUris = [
    Uri.parse('sms://wallet-adapter'),
    Uri.parse('solanamobilesdk://wallet-adapter'),
    Uri.parse('solana-mobile://wallet-adapter'),
    Uri.parse('https://vault.solanamobile.com/'),
    Uri.parse('https://wallet.solanamobile.com/'),
    Uri.parse('https://seeker.solanamobile.com/'),
    Uri.parse('https://www.solanamobile.com/wallet'),
    Uri.parse('https://solanamobile.com/wallet'),
  ];

  static final List<Uri> _solanaMobileHttpsUris = [
    Uri.parse('https://vault.solanamobile.com/'),
    Uri.parse('https://wallet.solanamobile.com/'),
    Uri.parse('https://seeker.solanamobile.com/'),
    Uri.parse('https://www.solanamobile.com/wallet'),
    Uri.parse('https://solanamobile.com/wallet'),
  ];

  static final Map<String, List<Uri>> _providerInstallUris = {
    'solana_mobile_stack': [
      Uri.parse('market://details?id=com.solanamobile.wallet'),
      Uri.parse(
        'https://play.google.com/store/apps/details?id=com.solanamobile.wallet',
      ),
      Uri.parse('https://solanamobile.com/wallet'),
    ],
  };

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
      'solanamobilewalletapp',
      'solanamobilewalletadapter',
      'solana_mobile_wallet_adapter',
      'com.solanamobile.wallet',
      'com.solanamobile.walletapp',
      'com.solanamobile.seeker',
      'com.solana.mobilewallet',
      'com.solana.mobile.wallet',
      'com.solana.seeker.wallet',
      'smsvault',
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

  static Future<bool> _hasSolanaMobilePackage() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final applications =
          await AndroidPackageManager().getInstalledApplications() ?? const [];
      for (final app in applications) {
        final packageName = app.packageName?.toLowerCase();
        if (packageName != null &&
            _solanaMobilePackageIds.contains(packageName)) {
          return true;
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to query installed packages: $error');
      debugPrint('$stackTrace');
    }

    return false;
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
      _assumeSolanaMobileStack = await _shouldAssumeSolanaMobileStack();
    } catch (error, stackTrace) {
      debugPrint('Failed to initialise Solana wallet adapter: $error');
      debugPrint('$stackTrace');
      _adapter = null;
      _assumeSolanaMobileStack = false;
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

  /// Attempts to open the install page for the supplied [providerId].
  /// Returns `true` if a browser or app store was launched.
  static Future<bool> openProviderInstallPage(String providerId) async {
    final String? canonical = _canonicalProviderId(providerId);
    if (canonical == null) {
      return false;
    }

    final List<Uri> targets = [];
    final Set<String> seen = {};

    void addCandidate(Uri? uri) {
      if (uri == null) {
        return;
      }
      final String key = uri.toString();
      if (seen.add(key)) {
        targets.add(uri);
      }
    }

    if (canonical == 'solana_mobile_stack') {
      for (final uri in _solanaMobileFallbackUris) {
        addCandidate(uri);
      }
    }

    for (final uri in _providerInstallUris[canonical] ?? const <Uri>[]) {
      addCandidate(uri);
    }

    if (canonical == 'solana_mobile_stack') {
      addCandidate(_solanaMobileHttpsFallback(forToken: canonical));
    }

    if (targets.isEmpty) {
      return false;
    }

    for (final uri in targets) {
      final bool launched = await _launchExternalUri(uri);
      if (launched) {
        return true;
      }
    }

    return false;
  }

  /// Determines whether the supplied [error] indicates no activity could handle
  /// the intent generated by the wallet adapter.
  static bool isActivityNotFoundError(Object error) {
    if (error is PlatformException) {
      return _isActivityNotFound(error);
    }
    return false;
  }

  static Future<bool> _launchExternalUri(Uri uri) async {
    try {
      final bool externalLaunched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (externalLaunched) {
        return true;
      }
    } catch (error) {
      debugPrint('Failed external launch for URI $uri: $error');
    }

    try {
      final bool fallbackLaunched = await launchUrl(uri);
      if (fallbackLaunched) {
        return true;
      }
    } catch (error) {
      debugPrint('Failed default launch for URI $uri: $error');
    }

    debugPrint('Attempted to launch $uri but no activity handled it.');
    return false;
  }

  static Uri? _walletUriForProvider(
    SolanaWalletAdapter adapter,
    String? providerId, {
    String? canonicalProvider,
  }) {
    if (providerId == null || canonicalProvider == null) {
      return _defaultWalletUri(adapter);
    }

    final String canonicalKey = canonicalProvider;

    Uri? candidate;
    for (final app in adapter.store.apps) {
      final Uri? walletUri = _safeWalletUri(app);
      final String? appCanonical = _canonicalFromStoreApp(app);

      if (appCanonical == canonicalKey && walletUri != null) {
        final Uri? normalized = _normalizeWalletUriForProvider(
          walletUri,
          canonicalKey,
          hint: app,
        );
        if (normalized != null) {
          return normalized;
        }
      }

      if (canonicalKey == 'solana_mobile_stack') {
        if (walletUri != null && _looksLikeSolanaMobile(walletUri)) {
          candidate ??= _normalizeWalletUriForProvider(
            walletUri,
            canonicalKey,
            hint: app,
          );
        }

        if (walletUri == null || candidate == null) {
          final Uri? inferred = _solanaMobileUriFromApp(app);
          if (inferred != null) {
            return inferred;
          }
        }
      }
    }

    candidate ??= adapter.authorizeResult?.walletUriBase;

    final Uri? baseCandidate = candidate;
    if (baseCandidate != null) {
      final Uri? normalized = _normalizeWalletUriForProvider(
        baseCandidate,
        canonicalKey,
      );
      final Uri effective = normalized ?? baseCandidate;
      final String? canonical = _canonicalFromUri(effective);
      if (canonical == canonicalKey) {
        return effective;
      }
    }

    if (canonicalKey == 'solana_mobile_stack') {
      final Uri? fallback = _solanaMobileWalletUri(adapter);
      if (fallback != null) {
        return fallback;
      }
    }

    return _defaultWalletUri(adapter, canonical: canonicalKey);
  }

  static Account _extractAccount(
    SolanaWalletAdapter adapter,
    AuthorizeResult result,
  ) {
    final Account? account = adapter.connectedAccount ??
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

    if (_assumeSolanaMobileStack) {
      installed.add('solana_mobile_stack');
    }

    return installed;
  }

  static Future<bool> _shouldAssumeSolanaMobileStack() async {
    if (!Platform.isAndroid) {
      return false;
    }

    if (await _hasSolanaMobilePackage()) {
      return true;
    }

    try {
      final DeviceInfoPlugin info = DeviceInfoPlugin();
      final AndroidDeviceInfo android = await info.androidInfo;
      final Iterable<String?> tokens = <String?>[
        android.brand,
        android.device,
        android.hardware,
        android.manufacturer,
        android.model,
        android.product,
        android.display,
        android.board,
        android.host,
      ];

      for (final token in tokens) {
        if (token == null || token.isEmpty) {
          continue;
        }

        final String normalized = token.toLowerCase();
        if (normalized.contains('solana') || normalized.contains('seeker')) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }

    return false;
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

  static Uri? _defaultWalletUri(
    SolanaWalletAdapter adapter, {
    Uri? exclude,
    String? canonical,
  }) {
    for (final app in adapter.store.apps) {
      final Uri? walletUri = _safeWalletUri(app);
      if (walletUri != null && walletUri != exclude) {
        if (canonical != null) {
          final String? resolved = _canonicalFromUri(walletUri);
          if (resolved != canonical) {
            continue;
          }
        }
        final Uri baseUri = walletUri;
        final Uri? normalized = canonical != null
            ? _normalizeWalletUriForProvider(baseUri, canonical, hint: app)
            : null;
        if (normalized != null) {
          return normalized;
        }
        if (canonical == null) {
          return baseUri;
        }
      }
    }

    final Uri? previous = adapter.authorizeResult?.walletUriBase;
    if (previous != null && previous != exclude) {
      if (canonical != null) {
        final Uri basePrevious = previous;
        final Uri? normalized = _normalizeWalletUriForProvider(
          basePrevious,
          canonical,
        );
        final Uri effective = normalized ?? basePrevious;
        final String? resolved = _canonicalFromUri(effective);
        if (resolved != canonical) {
          return null;
        }
        return effective;
      }
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
    if (value.contains('solanamobile') ||
        value.contains('solana_mobile') ||
        value.contains('solana-mobile') ||
        value.contains('seeker') ||
        value.contains('smsvault') ||
        (value.contains('solana') && value.contains('vault')) ||
        (value.contains('solana') && value.contains('mobile'))) {
      return true;
    }
    return false;
  }

  static Uri? _solanaMobileWalletUri(SolanaWalletAdapter adapter) {
    final Uri? fromStore = _firstWalletUriMatching(
      adapter,
      _looksLikeSolanaMobile,
    );
    if (fromStore != null) {
      final Uri? normalized = _normalizeWalletUriForProvider(
        fromStore,
        'solana_mobile_stack',
        hint: fromStore,
      );
      if (normalized != null) {
        return normalized;
      }
    }

    if (!_assumeSolanaMobileStack) {
      return null;
    }

    for (final Uri uri in _solanaMobileFallbackUris) {
      final Uri? normalized = _normalizeWalletUriForProvider(
        uri,
        'solana_mobile_stack',
        hint: uri,
      );
      if (normalized != null) {
        return normalized;
      }
    }

    return null;
  }

  static Uri? _solanaMobileUriFromApp(dynamic app) {
    final List<String?> tokens = [];

    try {
      final dynamic packageId = app.packageId;
      if (packageId is String) {
        tokens.add(packageId);
      }
    } catch (_) {}

    try {
      final dynamic name = app.app?.name;
      if (name is String) {
        tokens.add(name);
      }
    } catch (_) {}

    try {
      tokens.add(app.toString());
    } catch (_) {}

    for (final token in tokens) {
      if (token == null || token.isEmpty) {
        continue;
      }

      final String normalized = token.toLowerCase();
      if ((normalized.contains('solana') && normalized.contains('vault')) ||
          normalized.contains('solanamobile') ||
          normalized.contains('solana_mobile') ||
          normalized.contains('solana-mobile') ||
          normalized.contains('smsvault') ||
          normalized.contains('seeker')) {
        try {
          if (normalized.startsWith('com.')) {
            return _solanaMobileHttpsFallback(forToken: token);
          }
        } catch (_) {}
        break;
      }
    }

    return null;
  }

  static Uri? _normalizeWalletUriForProvider(
    Uri uri,
    String canonical, {
    dynamic hint,
  }) {
    if (canonical != 'solana_mobile_stack') {
      return uri;
    }

    if (uri.scheme == 'https') {
      return uri;
    }

    if (uri.scheme == 'http') {
      return uri.replace(scheme: 'https');
    }

    final Uri? httpsFallback = _solanaMobileHttpsFallback(
      forToken: uri.toString(),
      hint: hint,
    );

    if (httpsFallback != null) {
      return httpsFallback;
    }

    return null;
  }

  static Uri? _solanaMobileHttpsFallback({String? forToken, dynamic hint}) {
    if (_solanaMobileHttpsUris.isEmpty) {
      return null;
    }

    final String token = (forToken ?? hint?.toString() ?? '').toLowerCase();

    Uri? selectMatching(String keyword) {
      for (final uri in _solanaMobileHttpsUris) {
        if (uri.toString().toLowerCase().contains(keyword)) {
          return uri;
        }
      }
      return null;
    }

    Uri? match;
    if (token.contains('vault')) {
      match = selectMatching('vault');
    } else if (token.contains('wallet')) {
      match = selectMatching('wallet');
    } else if (token.contains('seeker')) {
      match = selectMatching('seeker');
    }

    return match ?? _solanaMobileHttpsUris.first;
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
