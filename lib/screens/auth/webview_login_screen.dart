import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/agixt/auth/wallet.dart';
import 'package:agixt/services/cookie_manager.dart';
import 'package:agixt/services/onboarding_service.dart';
import 'package:agixt/services/phantom_wallet_bridge.dart';
import 'package:agixt/services/wallet_adapter_service.dart';
import 'package:agixt/screens/settings/permissions_screen.dart';
import 'package:agixt/main.dart'; // For AGiXTApp.onLoginSuccess callback
import 'dart:convert';
import 'dart:typed_data';
import 'package:bs58/bs58.dart' as bs58;

/// A WebView-based login screen that loads the AGiXT web app's login page
/// directly, allowing users to use any authentication method supported by
/// the web app (Microsoft, Google, Phantom Wallet, etc.)
class WebViewLoginScreen extends StatefulWidget {
  const WebViewLoginScreen({super.key});

  @override
  State<WebViewLoginScreen> createState() => _WebViewLoginScreenState();
}

class _WebViewLoginScreenState extends State<WebViewLoginScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isInitialLoad = true;
  String? _error;
  bool _hasCheckedAuth = false;
  bool _isAuthenticated = false;
  bool _canGoBack = false;
  bool _isOnPostLoginPage = false; // User has logged in, stay in this webview
  bool _hasOfferedPhantomApp =
      false; // Track if we've already offered native Phantom
  bool _isProcessingPhantomLogin =
      false; // Track if we're in the middle of Phantom login
  final PhantomWalletBridge _phantomBridge = PhantomWalletBridge();

  @override
  void initState() {
    super.initState();
    _initPhantomBridge();
    _checkExistingAuthAndInit();
    // Show permission manager on first launch (like the old login screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowPermissionManager();
    });
  }

  /// Initialize the Phantom wallet bridge for native app integration
  Future<void> _initPhantomBridge() async {
    try {
      await _phantomBridge.initialize();
      debugPrint('WebView Login: Phantom bridge initialized');
    } catch (e) {
      debugPrint('WebView Login: Failed to initialize Phantom bridge: $e');
    }
  }

  @override
  void dispose() {
    _phantomBridge.dispose();
    super.dispose();
  }

  /// Show the permission manager screen if this is the user's first time
  Future<void> _maybeShowPermissionManager() async {
    if (!mounted) return;

    final shouldShow = await OnboardingService.shouldShowPermissionManager();
    if (!shouldShow || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PermissionsSettingsPage(),
        fullscreenDialog: true,
      ),
    );
    await OnboardingService.markPermissionManagerShown();
  }

  /// Check if user is already logged in before showing login screen
  /// This handles cases where the app state got out of sync
  Future<void> _checkExistingAuthAndInit() async {
    final isAlreadyLoggedIn = await AuthService.isLoggedIn();
    debugPrint(
        'WebView Login: Checking existing auth, isLoggedIn = $isAlreadyLoggedIn');

    if (isAlreadyLoggedIn && mounted) {
      // Already logged in, go straight to home
      debugPrint('WebView Login: Already logged in, navigating to home');
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: {'forceNewChat': false},
      );
      return;
    }

    // Not logged in, initialize the WebView for login
    _initWebView();
  }

  Future<void> _initWebView() async {
    final baseUrl = AuthService.appUri;
    // Load the /user page which shows all login options
    final loginUrl = Uri.parse('$baseUrl/user');

    debugPrint('WebView Login: Loading $loginUrl');

    // Don't clear cookies - we want to preserve any existing session
    // that might help with OAuth flows

    final newController = WebViewController();

    await newController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await newController.setBackgroundColor(const Color(0xFF0c0910));

    // Set user agent to ensure the web page renders properly for mobile
    await newController.setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');

    await newController.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          debugPrint('WebView Login: Page started: $url');
          if (!_isAuthenticated && mounted) {
            setState(() {
              _isLoading = true;
            });
          }
        },
        onPageFinished: (String url) async {
          debugPrint('WebView Login: Page finished: $url');

          // Update back button state
          final canGoBack =
              _controller != null ? await _controller!.canGoBack() : false;

          if (mounted) {
            setState(() {
              _isLoading = false;
              _isInitialLoad = false;
              _canGoBack = canGoBack;
            });
          }

          // Check if there's a token in the URL itself
          await _checkForAuthToken(url);

          // Check if we're on a Phantom wallet login page and offer native app
          await _checkForPhantomLoginPage(url);

          // Re-inject Phantom detection script on each page load
          if (!_isAuthenticated && !_hasOfferedPhantomApp) {
            _injectPhantomDetectionScript();
          }
        },
        onUrlChange: (UrlChange change) async {
          debugPrint('WebView Login: URL changed to: ${change.url}');
          if (change.url != null) {
            await _checkForAuthToken(change.url!);
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          debugPrint('WebView Login: Navigation request to: ${request.url}');

          // Handle agixt:// deep links (in case the web app redirects to them)
          if (request.url.startsWith('agixt://')) {
            _handleDeepLink(request.url);
            return NavigationDecision.prevent;
          }

          // Check if the URL contains a token parameter (successful OAuth redirect)
          final uri = Uri.tryParse(request.url);
          if (uri != null) {
            final token = uri.queryParameters['token'] ??
                uri.queryParameters['access_token'] ??
                uri.queryParameters['jwt'];
            if (token != null && token.isNotEmpty) {
              debugPrint('WebView Login: Found token in navigation URL');
              _handleSuccessfulLogin(token);
              return NavigationDecision.prevent;
            }
          }

          return NavigationDecision.navigate;
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint(
              'WebView Login: Error: ${error.errorCode} - ${error.description}');
          // Only show error for main frame failures, not subresources
          if (error.isForMainFrame == true && !_isAuthenticated && mounted) {
            setState(() {
              _error =
                  'Unable to load login page. Please check your internet connection.';
              _isLoading = false;
              _isInitialLoad = false;
            });
          }
        },
        onHttpError: (HttpResponseError error) {
          debugPrint('WebView Login: HTTP error ${error.response?.statusCode}');
          // Don't show errors for OAuth redirects which may return non-200 codes
        },
      ),
    );

    // Add JavaScript channel to detect Phantom wallet button clicks
    await newController.addJavaScriptChannel(
      'PhantomDetector',
      onMessageReceived: (JavaScriptMessage message) async {
        debugPrint(
            'WebView Login: PhantomDetector message: ${message.message}');
        if (message.message == 'phantom_clicked' &&
            !_hasOfferedPhantomApp &&
            !_isProcessingPhantomLogin) {
          _hasOfferedPhantomApp = true;
          await _offerPhantomNativeApp();
        }
      },
    );

    // Set the controller before loading the request so callbacks can access it
    if (mounted) {
      setState(() {
        _controller = newController;
      });
    }

    await newController.loadRequest(loginUrl);

    // Inject script to detect Phantom button clicks after page loads
    _injectPhantomDetectionScript();
  }

  /// Inject a script to detect when user clicks on Phantom wallet login button
  Future<void> _injectPhantomDetectionScript() async {
    // Wait a moment for the controller to be ready
    await Future.delayed(const Duration(milliseconds: 500));

    if (_controller == null) return;

    try {
      await _controller!.runJavaScript('''
        (function() {
          // Function to check if an element is related to Phantom wallet
          function isPhantomElement(element) {
            if (!element) return false;
            
            var text = (element.innerText || element.textContent || '').toLowerCase();
            var className = (element.className || '').toLowerCase();
            var id = (element.id || '').toLowerCase();
            var ariaLabel = (element.getAttribute('aria-label') || '').toLowerCase();
            var dataWallet = (element.getAttribute('data-wallet') || '').toLowerCase();
            var src = (element.src || '').toLowerCase();
            var alt = (element.alt || '').toLowerCase();
            
            return text.includes('phantom') || 
                   className.includes('phantom') || 
                   id.includes('phantom') ||
                   ariaLabel.includes('phantom') ||
                   dataWallet.includes('phantom') ||
                   src.includes('phantom') ||
                   alt.includes('phantom');
          }
          
          // Add click listener to detect Phantom button clicks
          document.addEventListener('click', function(e) {
            var target = e.target;
            
            // Check the clicked element and its parents
            var current = target;
            for (var i = 0; i < 5 && current; i++) {
              if (isPhantomElement(current)) {
                console.log('Phantom wallet button clicked');
                if (window.PhantomDetector) {
                  window.PhantomDetector.postMessage('phantom_clicked');
                }
                break;
              }
              current = current.parentElement;
            }
          }, true);
          
          // Also observe for dynamically added Phantom elements (modals)
          var observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === 1) { // Element node
                  if (isPhantomElement(node) || node.querySelector && node.querySelector('[class*="phantom"], [id*="phantom"], [data-wallet="phantom"]')) {
                    console.log('Phantom modal detected');
                    // Don't auto-trigger, wait for click
                  }
                }
              });
            });
          });
          
          observer.observe(document.body, { childList: true, subtree: true });
          
          console.log('Phantom detection script injected');
        })();
      ''');
      debugPrint('WebView Login: Phantom detection script injected');
    } catch (e) {
      debugPrint('WebView Login: Error injecting Phantom detection script: $e');
    }
  }

  Future<void> _checkForAuthToken(String url) async {
    // Don't check repeatedly if we've already found a token
    if (_hasCheckedAuth || _isAuthenticated) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // Check query parameters for token
    final urlToken = uri.queryParameters['token'] ??
        uri.queryParameters['access_token'] ??
        uri.queryParameters['jwt'];
    if (urlToken != null && urlToken.isNotEmpty) {
      debugPrint('WebView Login: Found token in URL parameters');
      _hasCheckedAuth = true;
      await _handleSuccessfulLogin(urlToken);
      return;
    }

    // Check hash fragment for token (some OAuth flows use hash)
    if (uri.fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      final fragmentToken = fragmentParams['token'] ??
          fragmentParams['access_token'] ??
          fragmentParams['jwt'];
      if (fragmentToken != null && fragmentToken.isNotEmpty) {
        debugPrint('WebView Login: Found token in URL fragment');
        _hasCheckedAuth = true;
        await _handleSuccessfulLogin(fragmentToken);
        return;
      }
    }

    // Check if we're on the AGiXT domain and on the chat page (successful login)
    final isAgixtDomain = uri.host.contains('agixt');
    final isOnChat = uri.path == '/chat' || uri.path.startsWith('/chat/');

    if (isAgixtDomain && isOnChat) {
      debugPrint('WebView Login: Successfully landed on chat page');
      _hasCheckedAuth = true;

      // We're on the chat page - try to extract the JWT
      String? jwtToken = await _extractJwtFromWebView();

      if (jwtToken != null && jwtToken.isNotEmpty) {
        debugPrint('WebView Login: Found JWT token, storing it');
        await AuthService.storeJwt(jwtToken);
      } else {
        // Even if we couldn't extract the JWT, we're logged in via the web app cookies
        debugPrint(
            'WebView Login: No JWT found but on chat page - using cookie auth');
        await AuthService.setCookieAuthenticated(true);
      }

      // Mark as authenticated and stay on this page (don't navigate away)
      // The user is already on the chat page in this WebView, so let them continue
      await _markAuthenticatedAndStayInWebView();
    }
  }

  /// Check if the current page is a Phantom wallet login page
  /// and offer to use the native Phantom app instead
  Future<void> _checkForPhantomLoginPage(String url) async {
    // Don't check if already authenticated or if we've already offered
    if (_isAuthenticated ||
        _hasOfferedPhantomApp ||
        _isProcessingPhantomLogin) {
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // ONLY trigger on actual Phantom domain redirects, not generic wallet checks
    // This prevents false positives during Microsoft/Google OAuth flows
    final isPhantomDomain = uri.host.contains('phantom.app');

    if (isPhantomDomain) {
      debugPrint('WebView Login: Detected actual Phantom domain redirect: $url');
      _hasOfferedPhantomApp = true;
      await _offerPhantomNativeApp();
    }
    // Don't automatically check page content - wait for explicit user click via JavaScript channel
  }

  /// Check page content for Phantom wallet related elements
  Future<void> _checkPageForPhantomContent() async {
    if (_controller == null || _isAuthenticated || _hasOfferedPhantomApp) {
      return;
    }

    try {
      // Check if the page has Phantom wallet elements or if we're in a Phantom flow
      final jsResult = await _controller!.runJavaScriptReturningResult('''
        (function() {
          // Check URL
          var url = window.location.href.toLowerCase();
          if (url.includes('phantom.app') || url.includes('phantom/connect')) {
            return 'phantom_url';
          }
          
          // Check for Phantom-specific elements in the page
          var phantomElements = document.querySelectorAll('[data-wallet="phantom"], [class*="phantom"], [id*="phantom"]');
          if (phantomElements.length > 0) {
            // Check if any Phantom element is visible/active (like a modal)
            for (var el of phantomElements) {
              var rect = el.getBoundingClientRect();
              if (rect.width > 0 && rect.height > 0) {
                var style = window.getComputedStyle(el);
                if (style.display !== 'none' && style.visibility !== 'hidden') {
                  return 'phantom_visible';
                }
              }
            }
          }
          
          // Check for generic wallet connect modal that might include Phantom
          var walletModals = document.querySelectorAll('[class*="wallet-modal"], [class*="walletconnect"], [class*="WalletModal"]');
          for (var modal of walletModals) {
            if (modal.innerText && modal.innerText.toLowerCase().includes('phantom')) {
              var rect = modal.getBoundingClientRect();
              if (rect.width > 0 && rect.height > 0) {
                return 'phantom_in_modal';
              }
            }
          }
          
          return 'none';
        })()
      ''');

      final result =
          jsResult.toString().replaceAll('"', '').replaceAll("'", '');
      debugPrint('WebView Login: Phantom content check result: $result');

      if (result != 'none' && result != 'null') {
        debugPrint('WebView Login: Found Phantom content on page: $result');
        _hasOfferedPhantomApp = true;
        await _offerPhantomNativeApp();
      }
    } catch (e) {
      debugPrint('WebView Login: Error checking for Phantom content: $e');
    }
  }

  /// Offer to use the native Phantom app for authentication
  Future<void> _offerPhantomNativeApp() async {
    if (!mounted || _isProcessingPhantomLogin) return;

    // First check if Phantom wallet app is installed
    final isPhantomInstalled = await _phantomBridge.isPhantomLikelyInstalled();
    if (!isPhantomInstalled) {
      debugPrint(
          'WebView Login: Phantom wallet app not installed, skipping native app offer');
      return;
    }

    // Check if the Phantom bridge is ready (this also initializes if needed)
    if (!_phantomBridge.isReady) {
      debugPrint(
          'WebView Login: Phantom bridge not ready, skipping native app offer');
      return;
    }

    debugPrint('WebView Login: Phantom is installed and bridge is ready, showing dialog');

    // Show dialog asking user if they want to use native Phantom app
    final useNativeApp =
        await PhantomWalletBridge.showPhantomAppDialog(context);

    if (useNativeApp && mounted) {
      await _handlePhantomNativeLogin();
    } else {
      debugPrint('WebView Login: User chose to continue in browser');
    }
  }

  /// Handle the native Phantom app login flow
  /// This uses the API-based authentication flow:
  /// 1. Connect to Phantom and get wallet address
  /// 2. Request nonce from AGiXT API
  /// 3. Sign nonce with Phantom wallet
  /// 4. Verify signature with API to get JWT token
  /// 5. Store JWT and navigate to home
  Future<void> _handlePhantomNativeLogin() async {
    if (!mounted) return;

    setState(() {
      _isProcessingPhantomLogin = true;
      _isLoading = true;
    });

    try {
      debugPrint('WebView Login: Starting native Phantom login...');

      // Step 1: Connect to Phantom and get the wallet account
      // Use WalletAdapterService directly to get the Account object we need for signing
      debugPrint('WebView Login: Connecting to Phantom wallet...');
      final account = await WalletAdapterService.connect(providerId: 'phantom');
      final walletAddress = account.toBase58();
      
      debugPrint('WebView Login: Got wallet address: $walletAddress');

      // Step 2: Request nonce from AGiXT API
      debugPrint('WebView Login: Requesting nonce from API...');
      final nonce = await WalletAuthService.requestNonce(
        walletAddress: walletAddress,
        chain: 'solana',
      );
      debugPrint('WebView Login: Nonce received: ${nonce.nonce}');
      debugPrint('WebView Login: Message to sign: "${nonce.message}"');
      debugPrint('WebView Login: Message to sign length: ${nonce.message.length}');
      debugPrint('WebView Login: Message bytes (UTF-8): ${utf8.encode(nonce.message).length} bytes');

      // Step 3: Sign the nonce message with Phantom wallet
      debugPrint('WebView Login: Signing message with Phantom...');
      debugPrint('WebView Login: Account address (internal base64): ${account.address}');
      debugPrint('WebView Login: Account toBase58: ${account.toBase58()}');
      final signatureBase64 = await WalletAdapterService.signMessage(
        nonce.message,
        account: account,
        providerId: 'phantom',
      );
      debugPrint('WebView Login: Raw signature from wallet (base64): $signatureBase64');
      debugPrint('WebView Login: Signature received (base64 length): ${signatureBase64.length}');

      // The wallet returns the signed payload as base64
      // We'll try multiple formats to see which one the API accepts
      
      // 1. Raw base64 from wallet (like commit df34d68)
      final rawSignature = signatureBase64;
      
      // 2. Decode and extract signature bytes
      final signedPayload = _decodeWalletSignedPayload(signatureBase64);
      debugPrint('WebView Login: Decoded payload length: ${signedPayload.length}');
      
      final signatureBytes = _extractSignatureFromPayload(signedPayload, nonce.message);
      debugPrint('WebView Login: Extracted signature bytes length: ${signatureBytes.length}');
      
      // 3. Base58 encode the extracted signature
      final signatureBase58 = bs58.base58.encode(signatureBytes);
      debugPrint('WebView Login: Extracted signature (base58): $signatureBase58');
      
      // 4. Base64 encode the extracted signature
      final signatureBase64Extracted = base64Encode(signatureBytes);
      debugPrint('WebView Login: Extracted signature (base64): $signatureBase64Extracted');

      // Step 4: Verify signature with API - try all formats
      debugPrint('WebView Login: Verifying signature with API...');
      debugPrint('WebView Login: wallet_address: $walletAddress');
      debugPrint('WebView Login: nonce: ${nonce.nonce}');
      debugPrint('WebView Login: Trying multiple signature formats...');
      
      WalletAuthResult? result;
      String? lastError;
      
      // Format 1: Raw base64 from wallet (commit df34d68 approach)
      try {
        debugPrint('WebView Login: Trying raw base64 from wallet...');
        result = await WalletAuthService.verifySignature(
          walletAddress: walletAddress,
          signature: rawSignature,
          message: nonce.message,
          nonce: nonce.nonce,
          walletType: 'phantom',
          chain: 'solana',
          referrer: AuthService.appUri,
        );
        debugPrint('WebView Login: Raw base64 WORKED!');
      } catch (e) {
        lastError = e.toString();
        debugPrint('WebView Login: Raw base64 failed: $e');
        
        // Format 2: Extracted signature as base58 (commit 25f4152 approach)
        try {
          debugPrint('WebView Login: Trying extracted base58...');
          result = await WalletAuthService.verifySignature(
            walletAddress: walletAddress,
            signature: signatureBase58,
            message: nonce.message,
            nonce: nonce.nonce,
            walletType: 'phantom',
            chain: 'solana',
            referrer: AuthService.appUri,
          );
          debugPrint('WebView Login: Extracted base58 WORKED!');
        } catch (e2) {
          debugPrint('WebView Login: Extracted base58 failed: $e2');
          
          // Format 3: Extracted signature as base64
          try {
            debugPrint('WebView Login: Trying extracted base64...');
            result = await WalletAuthService.verifySignature(
              walletAddress: walletAddress,
              signature: signatureBase64Extracted,
              message: nonce.message,
              nonce: nonce.nonce,
              walletType: 'phantom',
              chain: 'solana',
              referrer: AuthService.appUri,
            );
            debugPrint('WebView Login: Extracted base64 WORKED!');
          } catch (e3) {
            debugPrint('WebView Login: Extracted base64 also failed: $e3');
            debugPrint('WebView Login: All signature formats failed!');
            throw Exception(lastError);
          }
        }
      }

      final token = result?.jwtToken;
      if (token == null || token.isEmpty) {
        throw StateError('Wallet authentication did not return a session token.');
      }

      // Step 5: Store JWT and navigate to home
      debugPrint('WebView Login: Authentication successful! Token received.');
      debugPrint('WebView Login: Token length: ${token.length}');
      
      await AuthService.storeJwt(token);
      debugPrint('WebView Login: JWT stored');
      
      if (result.email != null && result.email!.isNotEmpty) {
        await AuthService.storeEmail(result.email!);
        debugPrint('WebView Login: Email stored: ${result.email}');
      }
      
      // Verify the JWT was stored correctly
      final storedJwt = await AuthService.getJwt();
      final isNowLoggedIn = await AuthService.isLoggedIn();
      debugPrint('WebView Login: Verification - storedJwt exists: ${storedJwt != null && storedJwt.isNotEmpty}, isLoggedIn: $isNowLoggedIn');

      if (!isNowLoggedIn) {
        throw StateError('JWT was not stored properly');
      }

      if (mounted) {
        // Call the login success callback FIRST to update main widget state
        debugPrint('WebView Login: Calling onLoginSuccess callback...');
        AGiXTApp.onLoginSuccess?.call();
        
        // Small delay to ensure state propagates
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Navigate to home
        debugPrint('WebView Login: Navigating to /home...');
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
          arguments: {'forceNewChat': true},
        );
      }
    } catch (e, stackTrace) {
      debugPrint('WebView Login: Error during Phantom native login: $e');
      debugPrint('WebView Login: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wallet login failed: ${e.toString().replaceAll('StateError: ', '').replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
        // Go back to the main login page on error
        final loginUrl = Uri.parse('${AuthService.appUri}/user');
        await _controller?.loadRequest(loginUrl);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPhantomLogin = false;
          _isLoading = false;
        });
      }
    }
  }

  /// Decode a base64-encoded wallet signature payload
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

  /// Extract the 64-byte Ed25519 signature from a wallet's signed payload
  Uint8List _extractSignatureFromPayload(
    Uint8List signedPayload,
    String originalMessage,
  ) {
    const int signatureLength = 64;

    debugPrint(
      'Signed payload length: ${signedPayload.length}, expected signature: $signatureLength',
    );
    debugPrint('Payload first 10 bytes: ${signedPayload.take(10).toList()}');
    if (signedPayload.length > 64) {
      debugPrint('Payload bytes 60-70: ${signedPayload.skip(60).take(10).toList()}');
    }

    // Case 1: Exact signature length - return as-is
    if (signedPayload.length == signatureLength) {
      debugPrint('Case 1: Exact signature length, returning as-is');
      return signedPayload;
    }

    if (signedPayload.length < signatureLength) {
      throw StateError(
        'Wallet returned an unexpectedly short signature payload (${signedPayload.length} bytes).',
      );
    }

    final Uint8List messageBytes = Uint8List.fromList(
      utf8.encode(originalMessage),
    );
    debugPrint('Original message bytes length: ${messageBytes.length}');

    // Case 2: Message prefix + signature (message at start, signature at end)
    final bool hasMessagePrefix = messageBytes.isNotEmpty &&
        _startsWithBytes(signedPayload, messageBytes);

    if (hasMessagePrefix &&
        signedPayload.length == messageBytes.length + signatureLength) {
      debugPrint('Case 2: Extracting signature from end (after message prefix)');
      return signedPayload.sublist(signedPayload.length - signatureLength);
    }

    // Case 3: Signature prefix + message (signature at start, message at end)
    // This is the "signed message" format used by some Ed25519 implementations
    final bool hasMessageSuffix = messageBytes.isNotEmpty &&
        signedPayload.length == signatureLength + messageBytes.length &&
        _endsWithBytes(signedPayload, messageBytes);

    if (hasMessageSuffix) {
      debugPrint('Case 3: Extracting signature from beginning (before message suffix)');
      return signedPayload.sublist(0, signatureLength);
    }

    // Case 4: Unknown format but longer than signature
    // MWA standard format is: signature (64 bytes) + message
    // So extract from the BEGINNING (first 64 bytes)
    if (signedPayload.length > signatureLength) {
      // Log both possibilities for debugging
      final firstBytes = signedPayload.sublist(0, signatureLength);
      final lastBytes = signedPayload.sublist(signedPayload.length - signatureLength);
      debugPrint(
        'Case 4: Unknown payload format (${signedPayload.length} bytes)',
      );
      debugPrint('First 64 bytes as base58: ${bs58.base58.encode(firstBytes)}');
      debugPrint('Last 64 bytes as base58: ${bs58.base58.encode(lastBytes)}');
      debugPrint('Extracting FIRST $signatureLength bytes (MWA standard: signature || message)');
      
      // Return the first 64 bytes (MWA standard format: signature at beginning)
      return firstBytes;
    }

    throw StateError('Wallet returned an unexpected signed payload format.');
  }

  bool _startsWithBytes(Uint8List data, Uint8List prefix) {
    if (prefix.isEmpty) return true;
    if (data.length < prefix.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) return false;
    }
    return true;
  }

  bool _endsWithBytes(Uint8List data, Uint8List suffix) {
    if (suffix.isEmpty) return true;
    if (data.length < suffix.length) return false;
    final int offset = data.length - suffix.length;
    for (int i = 0; i < suffix.length; i++) {
      if (data[offset + i] != suffix[i]) return false;
    }
    return true;
  }

  /// Try to get a nonce/message from the web page that needs to be signed
  Future<String?> _getNonceFromWebPage() async {
    if (_controller == null) return null;

    try {
      final result = await _controller!.runJavaScriptReturningResult('''
        (function() {
          // Try to find a nonce in various places
          
          // Check localStorage/sessionStorage for nonce
          var nonce = localStorage.getItem('phantom_nonce') || 
                      localStorage.getItem('wallet_nonce') || 
                      localStorage.getItem('auth_nonce') ||
                      sessionStorage.getItem('phantom_nonce') || 
                      sessionStorage.getItem('wallet_nonce') || 
                      sessionStorage.getItem('auth_nonce');
          if (nonce) return nonce;
          
          // Check for nonce in page content (some apps display it)
          var nonceElements = document.querySelectorAll('[data-nonce], [id*="nonce"], [class*="nonce"]');
          for (var el of nonceElements) {
            var text = el.textContent || el.innerText || el.value;
            if (text && text.length > 10 && text.length < 200) {
              return text.trim();
            }
          }
          
          // Check URL for nonce parameter
          var urlParams = new URLSearchParams(window.location.search);
          var urlNonce = urlParams.get('nonce') || urlParams.get('message') || urlParams.get('challenge');
          if (urlNonce) return urlNonce;
          
          // Generate a default sign-in message if nothing found
          // This is a common pattern for wallet authentication
          return 'Sign in to AGiXT with your Solana wallet';
        })()
      ''');

      final nonce = result.toString().replaceAll('"', '').replaceAll("'", '');
      if (nonce.isNotEmpty && nonce != 'null') {
        return nonce;
      }
    } catch (e) {
      debugPrint('WebView Login: Error getting nonce: $e');
    }

    return null;
  }

  /// Inject the wallet address into the webview to complete the Phantom login
  Future<void> _injectWalletAddressAndLogin(String walletAddress, {String? signature}) async {
    if (_controller == null) return;

    final signatureJs = signature ?? '';
    
    try {
      debugPrint('WebView Login: Injecting wallet address into webview...');
      debugPrint('WebView Login: Signature available: ${signature != null}');

      // First, let's understand the current page state and what the web app expects
      final pageInfo = await _controller!.runJavaScriptReturningResult('''
        (function() {
          var info = {
            url: window.location.href,
            hasPhantom: typeof window.phantom !== 'undefined',
            hasSolana: typeof window.solana !== 'undefined',
            hasSolanaConnect: typeof window.solana !== 'undefined' && typeof window.solana.connect === 'function',
          };
          return JSON.stringify(info);
        })()
      ''');
      debugPrint('WebView Login: Page info: $pageInfo');

      // Approach: Create a mock Phantom provider and trigger the connect flow
      final jsResult = await _controller!.runJavaScriptReturningResult('''
        (async function() {
          var walletAddress = '$walletAddress';
          var walletSignature = '$signatureJs';
          var results = [];
          
          // Create a proper PublicKey-like object
          var mockPublicKey = {
            toBase58: function() { return walletAddress; },
            toString: function() { return walletAddress; },
            toBuffer: function() { return new Uint8Array(32); },
            toBytes: function() { return new Uint8Array(32); },
            equals: function(other) { return other && other.toBase58 && other.toBase58() === walletAddress; }
          };
          
          // Create mock Phantom/Solana provider
          var mockProvider = {
            isPhantom: true,
            isConnected: true,
            publicKey: mockPublicKey,
            connect: async function(opts) {
              this.isConnected = true;
              results.push('connect_called');
              return { publicKey: mockPublicKey };
            },
            disconnect: async function() {
              this.isConnected = false;
              return;
            },
            signMessage: async function(message, display) {
              results.push('signMessage_called');
              // Return the real signature if we have one, otherwise a placeholder
              if (walletSignature) {
                // Convert base64 signature to Uint8Array if needed
                try {
                  var binaryStr = atob(walletSignature);
                  var bytes = new Uint8Array(binaryStr.length);
                  for (var i = 0; i < binaryStr.length; i++) {
                    bytes[i] = binaryStr.charCodeAt(i);
                  }
                  return { signature: bytes, publicKey: mockPublicKey };
                } catch(e) {
                  results.push('signature_decode_error');
                }
              }
              return { signature: new Uint8Array(64), publicKey: mockPublicKey };
            },
            signTransaction: async function(tx) {
              results.push('signTransaction_called');
              return tx;
            },
            signAllTransactions: async function(txs) {
              results.push('signAllTransactions_called');
              return txs;
            },
            on: function(event, handler) { 
              if (event === 'connect') {
                setTimeout(() => handler({ publicKey: mockPublicKey }), 100);
              }
              return this; 
            },
            off: function(event, handler) { return this; },
            removeListener: function(event, handler) { return this; },
            emit: function(event, data) { return this; },
            request: async function(params) {
              if (params.method === 'connect') {
                return { publicKey: mockPublicKey };
              }
              return null;
            }
          };
          
          // Override window.phantom and window.solana
          window.phantom = window.phantom || {};
          window.phantom.solana = mockProvider;
          window.solana = mockProvider;
          
          // Store in localStorage for apps that check there
          try {
            localStorage.setItem('phantom_wallet_address', walletAddress);
            localStorage.setItem('walletAddress', walletAddress);
            localStorage.setItem('connected_wallet', walletAddress);
            localStorage.setItem('solana_wallet_address', walletAddress);
            localStorage.setItem('phantom.publicKey', walletAddress);
            if (walletSignature) {
              localStorage.setItem('phantom_signature', walletSignature);
              localStorage.setItem('wallet_signature', walletSignature);
            }
            sessionStorage.setItem('phantom_wallet_address', walletAddress);
            sessionStorage.setItem('walletAddress', walletAddress);
            results.push('localStorage_set');
          } catch(e) {
            results.push('localStorage_error: ' + e.message);
          }
          
          // Dispatch connect event that dApps listen for
          try {
            window.dispatchEvent(new CustomEvent('phantom#connected', { detail: { publicKey: mockPublicKey } }));
            window.dispatchEvent(new CustomEvent('solana#connected', { detail: { publicKey: mockPublicKey } }));
            
            // Also try the standard wallet adapter events
            if (window.solana && window.solana.emit) {
              window.solana.emit('connect', { publicKey: mockPublicKey });
            }
            results.push('events_dispatched');
          } catch(e) {
            results.push('events_error: ' + e.message);
          }
          
          // Find and click any wallet connect buttons that might be waiting
          await new Promise(resolve => setTimeout(resolve, 500));
          
          // Look for buttons that suggest connection
          var buttons = Array.from(document.querySelectorAll('button, a, [role="button"]'));
          for (var btn of buttons) {
            var text = (btn.innerText || btn.textContent || '').toLowerCase().trim();
            var ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
            
            // Skip if button says "connect" or "login" - we want post-connection buttons
            if (text.includes('continue') || text.includes('proceed') || text.includes('sign in') || 
                text.includes('authenticate') || text.includes('verify') || text.includes('confirm wallet')) {
              results.push('clicking: ' + text.substring(0, 30));
              btn.click();
              await new Promise(resolve => setTimeout(resolve, 300));
            }
          }
          
          // Check if the page has a specific callback URL pattern for wallet auth
          var currentUrl = new URL(window.location.href);
          var callbackUrl = currentUrl.searchParams.get('callback') || 
                           currentUrl.searchParams.get('redirect_uri') ||
                           currentUrl.searchParams.get('redirect');
          
          if (callbackUrl) {
            try {
              var redirectUrl = new URL(callbackUrl, window.location.origin);
              redirectUrl.searchParams.set('wallet', walletAddress);
              redirectUrl.searchParams.set('publicKey', walletAddress);
              redirectUrl.searchParams.set('address', walletAddress);
              if (walletSignature) {
                redirectUrl.searchParams.set('signature', walletSignature);
              }
              results.push('redirect_url_built');
              // Don't auto-redirect, let the page handle it
            } catch(e) {
              results.push('redirect_build_error: ' + e.message);
            }
          }
          
          // Try to navigate directly to login completion if on AGiXT
          if (window.location.hostname.includes('agixt')) {
            // Check if there's an API endpoint we can call
            try {
              var apiUrl = '/api/v1/user/oauth/phantom/callback?wallet=' + walletAddress;
              if (walletSignature) {
                apiUrl += '&signature=' + encodeURIComponent(walletSignature);
              }
              var response = await fetch(apiUrl, {
                method: 'GET',
                credentials: 'include'
              });
              if (response.ok) {
                results.push('api_callback_success');
                var data = await response.json();
                if (data.token) {
                  localStorage.setItem('jwt', data.token);
                  results.push('jwt_stored');
                }
              } else {
                results.push('api_callback_status: ' + response.status);
              }
            } catch(e) {
              results.push('api_callback_error: ' + e.message);
            }
          }
          
          return results.join('; ');
        })()
      ''');

      debugPrint('WebView Login: Wallet injection result: $jsResult');

      // Give the page time to process
      await Future.delayed(const Duration(milliseconds: 1500));

      // Now try to navigate or trigger the final login step
      await _tryCompleteWalletLogin(walletAddress, signature: signature);
      
    } catch (e) {
      debugPrint('WebView Login: Error injecting wallet address: $e');
    }
  }

  /// Try to complete the wallet login by calling the AGiXT API directly
  Future<void> _tryCompleteWalletLogin(String walletAddress, {String? signature}) async {
    if (_controller == null) return;

    final signatureJs = signature ?? '';
    
    try {
      // Check if we can complete the login via the API
      final completeResult = await _controller!.runJavaScriptReturningResult('''
        (async function() {
          var walletAddress = '$walletAddress';
          var walletSignature = '$signatureJs';
          var results = [];
          
          // Build request body with signature if available
          var requestBody = { 
            wallet: walletAddress, 
            publicKey: walletAddress, 
            address: walletAddress 
          };
          if (walletSignature) {
            requestBody.signature = walletSignature;
          }
          
          // Try the AGiXT phantom callback endpoints
          var endpoints = [
            '/api/v1/oauth/phantom',
            '/v1/oauth/phantom',
            '/api/auth/phantom',
            '/auth/phantom',
            '/api/v1/user/wallet',
          ];
          
          for (var endpoint of endpoints) {
            try {
              var response = await fetch(endpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(requestBody),
                credentials: 'include'
              });
              
              if (response.ok) {
                var data = await response.json();
                results.push('endpoint_ok: ' + endpoint);
                
                if (data.token || data.jwt || data.access_token) {
                  var token = data.token || data.jwt || data.access_token;
                  localStorage.setItem('jwt', token);
                  localStorage.setItem('token', token);
                  results.push('token_saved');
                  
                  // Redirect to chat with token
                  window.location.href = '/chat?token=' + token;
                  return results.join('; ');
                }
                
                if (data.redirect || data.redirectUrl) {
                  window.location.href = data.redirect || data.redirectUrl;
                  return results.join('; ');
                }
              } else {
                results.push('endpoint_' + response.status + ': ' + endpoint);
              }
            } catch(e) {
              results.push('endpoint_error: ' + endpoint);
            }
          }
          
          // If no API worked, try refreshing to let the page detect the connected wallet
          results.push('will_reload');
          
          return results.join('; ');
        })()
      ''');
      
      debugPrint('WebView Login: Complete wallet login result: $completeResult');

      // Wait and check current URL
      await Future.delayed(const Duration(milliseconds: 500));
      
      final currentUrl = await _controller!.currentUrl();
      debugPrint('WebView Login: Current URL after wallet login attempt: $currentUrl');
      
      if (currentUrl != null) {
        await _checkForAuthToken(currentUrl);
        
        // If still not authenticated, try reloading the page
        // The mock wallet provider should be detected on reload
        if (!_isAuthenticated && currentUrl.contains('agixt')) {
          debugPrint('WebView Login: Reloading page to detect connected wallet...');
          await _controller!.reload();
        }
      }
    } catch (e) {
      debugPrint('WebView Login: Error completing wallet login: $e');
    }
  }

  /// Mark the user as authenticated and stay in the current WebView
  /// instead of navigating to a new screen
  Future<void> _markAuthenticatedAndStayInWebView() async {
    if (_isOnPostLoginPage) return; // Already handled

    try {
      debugPrint('WebView Login: Marking authenticated and staying in WebView');

      // Verify auth was saved correctly
      final isNowLoggedIn = await AuthService.isLoggedIn();
      debugPrint(
          'WebView Login: After setting auth, isLoggedIn = $isNowLoggedIn');

      if (!isNowLoggedIn) {
        debugPrint('WebView Login: ERROR - Auth state was not saved!');
        setState(() {
          _error = 'Login state was not saved. Please try again.';
          _hasCheckedAuth = false;
        });
        return;
      }

      // Clear any previous conversation ID
      final cookieManager = CookieManager();
      await cookieManager.clearAgixtConversationId();

      if (!mounted) return;

      // Notify the root state of successful login
      debugPrint('WebView Login: Notifying root state of login success...');
      AGiXTApp.onLoginSuccess?.call();

      // Update state to show fullscreen WebView (no app bar)
      setState(() {
        _isAuthenticated = true;
        _isOnPostLoginPage = true;
      });

      debugPrint('WebView Login: User can now continue in WebView');
    } catch (e) {
      debugPrint('WebView Login: Error marking authenticated: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to complete login. Please try again.';
        });
      }
    }
  }

  Future<String?> _extractJwtFromWebView() async {
    if (_controller == null) return null;

    try {
      final jsResult = await _controller!.runJavaScriptReturningResult('''
        (function() {
          // Try localStorage with various keys
          var keys = ['jwt', 'token', 'access_token', 'accessToken', 'auth_token', 'authToken', 'id_token', 'idToken'];
          for (var i = 0; i < keys.length; i++) {
            var token = localStorage.getItem(keys[i]);
            if (token && token !== 'null' && token !== 'undefined') {
              return token;
            }
          }
          
          // Try sessionStorage with various keys
          for (var i = 0; i < keys.length; i++) {
            var token = sessionStorage.getItem(keys[i]);
            if (token && token !== 'null' && token !== 'undefined') {
              return token;
            }
          }
          
          // Try cookies with various names
          var cookieKeys = ['jwt', 'token', 'access_token', 'accessToken', 'auth_token', 'authToken'];
          var cookies = document.cookie.split(';');
          for (var j = 0; j < cookies.length; j++) {
            var cookie = cookies[j].trim();
            for (var k = 0; k < cookieKeys.length; k++) {
              if (cookie.startsWith(cookieKeys[k] + '=')) {
                return cookie.substring(cookieKeys[k].length + 1);
              }
            }
          }
          
          // Try checking for any auth-related data in localStorage
          for (var m = 0; m < localStorage.length; m++) {
            var key = localStorage.key(m);
            if (key && (key.toLowerCase().includes('token') || key.toLowerCase().includes('auth') || key.toLowerCase().includes('jwt'))) {
              var val = localStorage.getItem(key);
              if (val && val.length > 20 && !val.startsWith('{') && !val.startsWith('[')) {
                return val;
              }
            }
          }
          
          return null;
        })()
      ''');

      if (jsResult != 'null' && jsResult.toString().isNotEmpty) {
        // Remove quotes if present
        var token = jsResult.toString().replaceAll('"', '').replaceAll("'", '');
        if (token != 'null' && token.isNotEmpty) {
          return token;
        }
      }
    } catch (e) {
      debugPrint('WebView Login: Error extracting JWT: $e');
    }

    return null;
  }

  void _handleDeepLink(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final token =
        uri.queryParameters['token'] ?? uri.queryParameters['access_token'];
    if (token != null && token.isNotEmpty) {
      _handleSuccessfulLogin(token);
    }
  }

  Future<void> _handleSuccessfulLogin(String token) async {
    if (_isAuthenticated || _isOnPostLoginPage) return;

    try {
      debugPrint('WebView Login: Storing JWT token...');
      await AuthService.storeJwt(token);

      // Verify it was saved correctly
      final isNowLoggedIn = await AuthService.isLoggedIn();
      debugPrint(
          'WebView Login: After storing JWT, isLoggedIn = $isNowLoggedIn');

      // Stay in WebView instead of navigating away
      await _markAuthenticatedAndStayInWebView();
    } catch (e) {
      debugPrint('WebView Login: Error storing token: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to complete login. Please try again.';
        });
      }
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _isLoading = true;
      _isInitialLoad = true;
      _hasCheckedAuth = false;
      _isAuthenticated = false;
      _isOnPostLoginPage = false;
      _hasOfferedPhantomApp = false;
      _isProcessingPhantomLogin = false;
      _controller = null;
    });
    await _initWebView();
  }

  Future<bool> _onWillPop() async {
    if (_controller != null && await _controller!.canGoBack()) {
      await _controller!.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Once logged in and on post-login page, show fullscreen WebView
    // This allows the user to continue using the website after login
    if (_isOnPostLoginPage && _controller != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          // Handle back navigation within the WebView
          if (_controller != null && await _controller!.canGoBack()) {
            await _controller!.goBack();
          }
          // Don't pop the screen - user stays in the authenticated webview
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0c0910),
          body: SafeArea(
            child: WebViewWidget(controller: _controller!),
          ),
        ),
      );
    }

    // Show error view if there's an error
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0c0910),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0c0910),
          elevation: 0,
          title: Text(
            'Sign in to ${AuthService.appName}',
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _retry,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _buildErrorView(),
      );
    }

    // Standard login screen with app bar
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          // Allow pop only if there's nowhere to go back in WebView
          // But since this is login, we don't actually want to pop
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0c0910),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0c0910),
          elevation: 0,
          leading: _canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    if (_controller != null) {
                      await _controller!.goBack();
                    }
                  },
                  tooltip: 'Go back',
                )
              : null,
          title: Text(
            'Sign in to ${AuthService.appName}',
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _retry,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorView();
    }

    return Stack(
      children: [
        // WebView - always render if controller exists
        if (_controller != null)
          Positioned.fill(
            child: WebViewWidget(controller: _controller!),
          ),

        // Loading overlay - only show on initial load, positioned to cover WebView
        if (_isLoading && _isInitialLoad)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0c0910),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading login page...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Subtle loading indicator for subsequent page loads
        if (_isLoading && !_isInitialLoad)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
