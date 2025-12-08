import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/agixt/auth/oauth.dart';
import 'package:agixt/models/agixt/auth/wallet.dart';
import 'package:agixt/screens/auth/oauth_webview_screen.dart';
import 'package:agixt/screens/settings/permissions_screen.dart';
import 'package:agixt/services/onboarding_service.dart';
import 'package:agixt/services/wallet_adapter_service.dart';
import 'package:bs58/bs58.dart' as bs58;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _mfaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;
  List<OAuthProvider> _oauthProviders = [];
  bool _loadingProviders = true;
  List<WalletProvider> _walletProviders = [];
  bool _loadingWalletProviders = true;
  String? _walletErrorMessage;
  bool _walletConnecting = false;
  String? _activeWalletProviderId;

  @override
  void initState() {
    super.initState();
    _loadOAuthProviders();
    _loadWalletProviders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowPermissionManager();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _mfaController.dispose();
    super.dispose();
  }

  Future<void> _loadOAuthProviders() async {
    try {
      setState(() {
        _loadingProviders = true;
      });

      final providers = await OAuthService.getProviders();

      setState(() {
        _oauthProviders = providers;
        _loadingProviders = false;
      });
    } catch (e) {
      setState(() {
        _loadingProviders = false;
      });
    }
  }

  Future<void> _loadWalletProviders() async {
    if (!WalletAdapterService.isAvailable) {
      setState(() {
        _walletProviders = [];
        _loadingWalletProviders = false;
        _walletErrorMessage = 'Wallet login isn\'t supported on this device.';
      });
      return;
    }

    try {
      final providers = await WalletAuthService.getProviders();
      final installed = WalletAdapterService.installedProviderIds;

      // First, include providers that match installed wallets
      final filtered = providers.where((provider) {
        if (!provider.supportsChain('solana')) {
          return false;
        }
        final canonical = WalletAdapterService.canonicalProviderId(
          provider.id,
        );
        // If we have a canonical ID, check if it's installed
        if (canonical != null) {
          return installed.contains(canonical);
        }
        // If no canonical mapping, still show the provider if it supports Solana
        // This ensures new providers aren't hidden
        return WalletAdapterService.supportsProvider(provider.id);
      }).toList();

      final Set<String> missingInstalled = {...installed}..removeWhere(
          (id) => filtered.any(
            (provider) =>
                WalletAdapterService.canonicalProviderId(provider.id) == id,
          ),
        );

      // Add Phantom if installed but not provided by the server
      if (missingInstalled.contains('phantom') ||
          (installed.contains('phantom') &&
              !filtered.any((p) =>
                  WalletAdapterService.canonicalProviderId(p.id) ==
                  'phantom'))) {
        filtered.add(
          WalletProvider(
            id: 'phantom',
            name: 'Phantom',
            chains: const ['solana'],
            primaryChain: 'solana',
            icon: 'phantom',
          ),
        );
      }

      // Add Solflare if installed but not provided by the server
      if (missingInstalled.contains('solflare') ||
          (installed.contains('solflare') &&
              !filtered.any((p) =>
                  WalletAdapterService.canonicalProviderId(p.id) ==
                  'solflare'))) {
        filtered.add(
          WalletProvider(
            id: 'solflare',
            name: 'Solflare',
            chains: const ['solana'],
            primaryChain: 'solana',
            icon: 'solflare',
          ),
        );
      }

      if (missingInstalled.contains('solana_mobile_stack')) {
        filtered.add(
          WalletProvider(
            id: 'solana_mobile_stack',
            name: 'Solana Mobile Wallet',
            chains: const ['solana'],
            primaryChain: 'solana',
            icon: 'solana_mobile',
          ),
        );
      }

      filtered.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      setState(() {
        _walletProviders = filtered;
        _loadingWalletProviders = false;
        _walletErrorMessage = filtered.isEmpty
            ? 'No compatible Solana wallets were detected on this device. Install a supported wallet to continue.'
            : null;
      });
    } catch (e) {
      setState(() {
        _walletProviders = [];
        _loadingWalletProviders = false;
        _walletErrorMessage =
            'Unable to load wallet providers. Please try again later.';
      });
    }
  }

  Uint8List _decodeWalletSignedPayload(String payload) {
    try {
      return Uint8List.fromList(base64Decode(payload));
    } on FormatException {
      try {
        return Uint8List.fromList(
            base64Url.decode(base64Url.normalize(payload)));
      } on FormatException {
        throw StateError('Wallet returned an invalid signature payload.');
      }
    }
  }

  Uint8List _extractSignatureFromPayload(
    Uint8List signedPayload,
    String originalMessage,
  ) {
    const int signatureLength = 64;
    if (signedPayload.length == signatureLength) {
      return signedPayload;
    }

    if (signedPayload.length < signatureLength) {
      throw StateError(
        'Wallet returned an unexpectedly short signature payload.',
      );
    }

    final Uint8List messageBytes = Uint8List.fromList(
      utf8.encode(originalMessage),
    );
    final bool hasMessagePrefix = messageBytes.isNotEmpty &&
        _startsWithBytes(signedPayload, messageBytes);

    if (hasMessagePrefix &&
        signedPayload.length == messageBytes.length + signatureLength) {
      return signedPayload.sublist(signedPayload.length - signatureLength);
    }

    if (signedPayload.length > signatureLength) {
      return signedPayload.sublist(signedPayload.length - signatureLength);
    }

    throw StateError('Wallet returned an unexpected signed payload format.');
  }

  bool _startsWithBytes(Uint8List data, Uint8List prefix) {
    if (prefix.isEmpty) {
      return true;
    }
    if (data.length < prefix.length) {
      return false;
    }
    for (int index = 0; index < prefix.length; index += 1) {
      if (data[index] != prefix[index]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final jwt = await AuthService.login(
        _emailController.text,
        _mfaController.text,
      );

      if (jwt != null) {
        // Login successful, navigate to home
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        setState(() {
          _errorMessage = 'Login failed. Please check your credentials.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithOAuth(OAuthProvider provider) async {
    // Use WebView-based OAuth for a smoother in-app experience
    // Opens directly to the OAuth provider's login page
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => OAuthWebViewScreen(provider: provider),
      ),
    );
    // Navigation to home is handled by the WebView screen on success
  }

  Future<void> _loginWithWallet(WalletProvider provider) async {
    if (!WalletAdapterService.isAvailable) {
      setState(() {
        _walletErrorMessage =
            'Wallet authentication is not available on this device.';
      });
      return;
    }

    setState(() {
      _walletConnecting = true;
      _walletErrorMessage = null;
      _activeWalletProviderId = provider.id;
    });

    if (!WalletAdapterService.supportsProvider(provider.id)) {
      final bool launched = await WalletAdapterService.openProviderInstallPage(
        provider.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _walletConnecting = false;
        _activeWalletProviderId = null;
        final bool isSolanaMobile =
            WalletAdapterService.canonicalProviderId(provider.id) ==
                'solana_mobile_stack';
        final String guidance = isSolanaMobile
            ? 'If you’re using a Solana Seeker headset, open Seeker settings '
                'and ensure the Solana Mobile Stack wallet is enabled.'
            : 'Install the wallet app from the store and try again, or choose a different provider.';
        _walletErrorMessage =
            'We couldn’t find ${provider.name} on this device. $guidance';
      });
      if (!launched) {
        debugPrint(
          'No install URI available for wallet provider ${provider.id}',
        );
      }
      return;
    }

    try {
      final account = await WalletAdapterService.connect(
        providerId: provider.id,
      );
      final walletAddress = account.toBase58();

      final nonce = await WalletAuthService.requestNonce(
        walletAddress: walletAddress,
        chain: provider.primaryChain,
      );

      final signatureBase64 = await WalletAdapterService.signMessage(
        nonce.message,
        account: account,
        providerId: provider.id,
      );

      final signedPayload = _decodeWalletSignedPayload(signatureBase64);
      final signatureBytes =
          _extractSignatureFromPayload(signedPayload, nonce.message);
      final signatureBase58 = bs58.base58.encode(signatureBytes);

      final result = await WalletAuthService.verifySignature(
        walletAddress: walletAddress,
        signature: signatureBase58,
        message: nonce.message,
        nonce: nonce.nonce,
        walletType: provider.id,
        chain: provider.primaryChain,
        referrer: AuthService.appUri,
      );

      final token = result.jwtToken;
      if (token == null || token.isEmpty) {
        throw StateError(
          'Wallet authentication did not return a session token.',
        );
      }

      await AuthService.storeJwt(token);
      if (result.email != null && result.email!.isNotEmpty) {
        await AuthService.storeEmail(result.email!);
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (error, stackTrace) {
      debugPrint('Wallet login failed for provider ${provider.id}: $error');
      debugPrint('$stackTrace');

      String message;
      if (error is StateError) {
        message = error.message;
      } else if (error is PlatformException) {
        message = error.message ?? error.code;
      } else {
        message = error.toString();
      }

      if (WalletAdapterService.isActivityNotFoundError(error)) {
        final bool launched =
            await WalletAdapterService.openProviderInstallPage(provider.id);
        if (WalletAdapterService.canonicalProviderId(provider.id) ==
            'solana_mobile_stack') {
          message =
              'We couldn’t open ${provider.name} because its activity isn’t available. '
              'On Solana Seeker, enable the built-in Solana Mobile Stack wallet from settings, '
              'or install the latest wallet update and try again.';
        } else {
          message =
              'We couldn’t open ${provider.name} because it isn’t installed. '
              'Install the wallet app and try again, or choose another provider.';
        }
        if (!launched) {
          debugPrint(
            'Unable to launch install page for provider ${provider.id}',
          );
        }
      }

      if (message.startsWith('Exception: ')) {
        message = message.substring('Exception: '.length);
      }
      if (message.startsWith('Bad state: ')) {
        message = message.substring('Bad state: '.length);
      }
      setState(() {
        _walletErrorMessage = message.isEmpty
            ? 'Wallet authentication failed. Please try again.'
            : message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _walletConnecting = false;
          _activeWalletProviderId = null;
        });
      }
    }
  }

  void _openRegistrationPage() async {
    final Uri url = Uri.parse(AuthService.appUri);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _maybeShowPermissionManager() async {
    if (!mounted) {
      return;
    }

    final shouldShow = await OnboardingService.shouldShowPermissionManager();
    if (!shouldShow || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PermissionsSettingsPage(),
        fullscreenDialog: true,
      ),
    );
    await OnboardingService.markPermissionManagerShown();
  }

  @override
  Widget build(BuildContext context) {
    final appName = AuthService.appName;

    return Scaffold(
      appBar: AppBar(title: Text('Login to $appName')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // Logo or app name
            Center(
              child: Text(
                appName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Error message if login fails
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),

            const SizedBox(height: 20),

            // Email & MFA login form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mfaController,
                    decoration: const InputDecoration(
                      labelText: '6-Digit MFA Code',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your MFA code';
                      }
                      if (value.length != 6 || int.tryParse(value) == null) {
                        return 'Please enter a valid 6-digit code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Login'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Divider(),

            // OAuth providers section
            Text(
              'Or continue with',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            if (_loadingProviders)
              const Center(child: CircularProgressIndicator())
            else if (_oauthProviders.isEmpty)
              const Center(child: Text('No OAuth providers available'))
            else
              ...List.generate(_oauthProviders.length, (index) {
                final provider = _oauthProviders[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: OutlinedButton(
                    onPressed:
                        _isLoading ? null : () => _loginWithOAuth(provider),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('Continue with ${provider.name.toUpperCase()}'),
                  ),
                );
              }),

            const SizedBox(height: 30),
            const Divider(),

            Text(
              'Or connect your Solana wallet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            if (_walletErrorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.orange.shade100,
                child: Text(
                  _walletErrorMessage!,
                  style: TextStyle(color: Colors.orange.shade900),
                ),
              ),

            if (_loadingWalletProviders)
              const Center(child: CircularProgressIndicator())
            else if (_walletProviders.isEmpty)
              const Center(
                child: Text('Wallet login is currently unavailable.'),
              )
            else
              ..._walletProviders.map((provider) {
                final bool isActive =
                    _walletConnecting && _activeWalletProviderId == provider.id;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: OutlinedButton(
                    onPressed: _walletConnecting
                        ? null
                        : () => _loginWithWallet(provider),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isActive
                          ? 'Connecting to ${provider.name}...'
                          : 'Continue with ${provider.name}',
                    ),
                  ),
                );
              }),

            const SizedBox(height: 30),

            // Registration link
            Center(
              child: RichText(
                text: TextSpan(
                  text: 'Don\'t have an account? ',
                  style: TextStyle(color: Colors.grey[700]),
                  children: [
                    TextSpan(
                      text: 'Register',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = _openRegistrationPage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
