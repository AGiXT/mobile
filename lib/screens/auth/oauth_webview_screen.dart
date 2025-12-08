import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/agixt/auth/oauth.dart';
import 'package:agixt/services/cookie_manager.dart';

/// A WebView-based OAuth login screen that handles authentication
/// by loading the AGiXT web app's OAuth flow and extracting the JWT after login.
class OAuthWebViewScreen extends StatefulWidget {
  final OAuthProvider provider;

  const OAuthWebViewScreen({
    super.key,
    required this.provider,
  });

  @override
  State<OAuthWebViewScreen> createState() => _OAuthWebViewScreenState();
}

class _OAuthWebViewScreenState extends State<OAuthWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  bool _hasCheckedAuth = false;
  bool _isOnChatPage = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() async {
    // Use the AGiXT web app's OAuth endpoint
    final providerName = widget.provider.name.toLowerCase();
    final baseUrl = AuthService.appUri;
    final loginUrl = Uri.parse('$baseUrl/user/$providerName');

    debugPrint('OAuth WebView: Loading $providerName via AGiXT');
    debugPrint('OAuth WebView: URL = $loginUrl');

    // Set the href cookie so the web app knows which provider to use
    final cookieManager = WebViewCookieManager();
    await cookieManager.setCookie(
      WebViewCookie(
        name: 'href',
        value: '$baseUrl/user/$providerName',
        domain: Uri.parse(baseUrl).host,
        path: '/',
      ),
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0c0910))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('OAuth WebView: Page started: $url');
            if (!_isOnChatPage) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) async {
            debugPrint('OAuth WebView: Page finished: $url');
            setState(() {
              _isLoading = false;
            });

            // First, check if there's a token in the URL itself
            final uri = Uri.tryParse(url);
            if (uri != null) {
              final token = uri.queryParameters['token'] ??
                  uri.queryParameters['access_token'] ??
                  uri.queryParameters['jwt'];
              if (token != null && token.isNotEmpty && !_hasCheckedAuth) {
                debugPrint('OAuth WebView: Found token in page URL');
                _hasCheckedAuth = true;
                await _handleSuccessfulLogin(token);
                return;
              }
            }

            // Auto-click the provider button if we're on the /user page
            if (uri != null && uri.path == '/user') {
              await _autoClickProviderButton(providerName);
            }

            // Check for JWT in cookies after page load
            await _checkForAuthToken(url);
          },
          onUrlChange: (UrlChange change) async {
            debugPrint('OAuth WebView: URL changed to: ${change.url}');
            if (change.url != null) {
              await _checkForAuthToken(change.url!);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('OAuth WebView: Navigation request to: ${request.url}');

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
                debugPrint('OAuth WebView: Found token in navigation URL');
                _handleSuccessfulLogin(token);
                return NavigationDecision.prevent;
              }
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
                'OAuth WebView: Error: ${error.errorCode} - ${error.description}');
            if (error.isForMainFrame == true && !_isOnChatPage) {
              setState(() {
                _error = 'Failed to load login page: ${error.description}';
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(loginUrl);
  }

  Future<void> _autoClickProviderButton(String providerName) async {
    // Wait a moment for the page to fully render
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Find and click the OAuth provider button
      // The AGiXT web app has buttons with provider names
      await _controller.runJavaScript('''
        (function() {
          // Look for a button or link containing the provider name
          var providerName = '$providerName';
          var buttons = document.querySelectorAll('button, a');
          
          for (var i = 0; i < buttons.length; i++) {
            var btn = buttons[i];
            var text = (btn.textContent || btn.innerText || '').toLowerCase();
            var ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
            
            if (text.includes(providerName) || ariaLabel.includes(providerName)) {
              console.log('Clicking provider button: ' + providerName);
              btn.click();
              return;
            }
          }
          
          // Also try clicking by icon/image alt text
          var imgs = document.querySelectorAll('img, svg');
          for (var j = 0; j < imgs.length; j++) {
            var img = imgs[j];
            var parent = img.closest('button, a');
            if (parent) {
              var alt = (img.getAttribute('alt') || '').toLowerCase();
              if (alt.includes(providerName)) {
                console.log('Clicking provider button via image: ' + providerName);
                parent.click();
                return;
              }
            }
          }
        })();
      ''');
    } catch (e) {
      debugPrint('OAuth WebView: Error auto-clicking provider button: $e');
    }
  }

  Future<void> _checkForAuthToken(String url) async {
    // Don't check repeatedly if we've already found a token
    if (_hasCheckedAuth) return;

    // Check URL for token first (some OAuth flows pass it in URL)
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // Check query parameters for token
    final urlToken = uri.queryParameters['token'] ??
        uri.queryParameters['access_token'] ??
        uri.queryParameters['jwt'];
    if (urlToken != null && urlToken.isNotEmpty) {
      debugPrint('OAuth WebView: Found token in URL parameters');
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
        debugPrint('OAuth WebView: Found token in URL fragment');
        _hasCheckedAuth = true;
        await _handleSuccessfulLogin(fragmentToken);
        return;
      }
    }

    // Check if we're on the AGiXT domain
    final isAgixtDomain = uri.host.contains('agixt');

    // Check if we're on the chat page (successful login)
    final isOnChat = uri.path == '/chat' || uri.path.startsWith('/chat/');

    if (isAgixtDomain && isOnChat) {
      debugPrint('OAuth WebView: Successfully landed on chat page');
      _hasCheckedAuth = true;

      // We're on the chat page - try to extract the JWT
      String? jwtToken;

      // Try to get JWT via JavaScript from cookies/localStorage/sessionStorage
      try {
        final jsResult = await _controller.runJavaScriptReturningResult('''
          (function() {
            // Try localStorage with various keys
            var keys = ['jwt', 'token', 'access_token', 'accessToken', 'auth_token', 'authToken', 'id_token', 'idToken'];
            for (var i = 0; i < keys.length; i++) {
              var token = localStorage.getItem(keys[i]);
              if (token && token !== 'null' && token !== 'undefined') {
                console.log('Found token in localStorage: ' + keys[i]);
                return token;
              }
            }
            
            // Try sessionStorage with various keys
            for (var i = 0; i < keys.length; i++) {
              var token = sessionStorage.getItem(keys[i]);
              if (token && token !== 'null' && token !== 'undefined') {
                console.log('Found token in sessionStorage: ' + keys[i]);
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
                  console.log('Found token in cookie: ' + cookieKeys[k]);
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
                  console.log('Found potential token in localStorage key: ' + key);
                  return val;
                }
              }
            }
            
            return null;
          })()
        ''');

        if (jsResult != 'null' && jsResult.toString().isNotEmpty) {
          // Remove quotes if present
          jwtToken =
              jsResult.toString().replaceAll('"', '').replaceAll("'", '');
          if (jwtToken == 'null') jwtToken = null;
        }
      } catch (e) {
        debugPrint('OAuth WebView: Error running JavaScript: $e');
      }

      if (jwtToken != null && jwtToken.isNotEmpty) {
        debugPrint('OAuth WebView: Found JWT token, storing and navigating');
        await _handleSuccessfulLogin(jwtToken);
      } else {
        // Even if we couldn't extract the JWT, we're logged in via the web app cookies
        // Mark as cookie-authenticated and navigate to home
        debugPrint(
            'OAuth WebView: No JWT found but on chat page - using cookie auth');
        await _handleSuccessfulLoginViaCookies();
      }
    }
  }

  /// Handle successful login when we can't extract the JWT token directly
  /// The web app has the user logged in via cookies
  Future<void> _handleSuccessfulLoginViaCookies() async {
    try {
      // Mark that we're authenticated via cookies
      await AuthService.setCookieAuthenticated(true);

      // Clear any previous conversation ID so the user starts with a fresh new chat
      final cookieManager = CookieManager();
      await cookieManager.clearAgixtConversationId();

      if (!mounted) return;

      // Navigate to home with forceNewChat=true to start a fresh chat
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: {'forceNewChat': true},
      );
    } catch (e) {
      debugPrint('OAuth WebView: Error completing cookie login: $e');
      setState(() {
        _error = 'Failed to complete login. Please try again.';
      });
    }
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
    try {
      await AuthService.storeJwt(token);

      // Clear any previous conversation ID so the user starts with a fresh new chat
      final cookieManager = CookieManager();
      await cookieManager.clearAgixtConversationId();

      if (!mounted) return;

      // Mark that we're now on the chat page - hide the app bar and show full screen
      setState(() {
        _isOnChatPage = true;
      });

      // Navigate to home with forceNewChat=true to start a fresh chat
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: {'forceNewChat': true},
      );
    } catch (e) {
      debugPrint('OAuth WebView: Error storing token: $e');
      setState(() {
        _error = 'Failed to complete login. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Once logged in, show fullscreen WebView without app bar
    if (_isOnChatPage) {
      return Scaffold(
        body: SafeArea(
          child: WebViewWidget(controller: _controller),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Sign in with ${widget.provider.name}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isLoading = true;
                        });
                        _initWebView();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
