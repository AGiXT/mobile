import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/services/cookie_manager.dart';
import 'package:agixt/services/onboarding_service.dart';
import 'package:agixt/screens/settings/permissions_screen.dart';
import 'package:agixt/main.dart'; // For AGiXTApp.onLoginSuccess callback

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

  @override
  void initState() {
    super.initState();
    _checkExistingAuthAndInit();
    // Show permission manager on first launch (like the old login screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowPermissionManager();
    });
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

    // Set the controller before loading the request so callbacks can access it
    if (mounted) {
      setState(() {
        _controller = newController;
      });
    }

    await newController.loadRequest(loginUrl);
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
