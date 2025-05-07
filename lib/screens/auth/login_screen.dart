import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/services/cookie_manager.dart';
import 'package:flutter/foundation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  final CookieManager _cookieManager = CookieManager();

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    // Create the WebView controller
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            debugPrint('Page finished loading: $url');
            // Check for JWT cookie when page loads
            _checkForJwtCookie();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            setState(() {
              _errorMessage = 'Error loading login page. Please try again.';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('${AuthService.appUri}/user'));

    // Set up a timer to periodically check for the JWT cookie
    _setupCookieCheckTimer();
  }

  void _setupCookieCheckTimer() {
    // Check for the JWT cookie every 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkForJwtCookie();
        _setupCookieCheckTimer(); // Schedule the next check
      }
    });
  }

  Future<void> _checkForJwtCookie() async {
    if (!mounted) return;
    
    try {
      // JavaScript to check for the jwt cookie
      final jwtCookieScript = '''
      (function() {
        try {
          var cookies = document.cookie.split(';');
          for (var i = 0; i < cookies.length; i++) {
            var cookie = cookies[i].trim();
            if (cookie.startsWith('jwt=')) {
              var value = cookie.substring('jwt='.length);
              console.log('Found JWT cookie:', value);
              return value;
            }
          }
          return '';
        } catch (e) {
          console.error('Error in cookie extraction:', e);
          return '';
        }
      })()
      ''';

      final jwtCookieValue = await _webViewController
          .runJavaScriptReturningResult(jwtCookieScript) as String?;

      debugPrint('Checking for JWT cookie: ${jwtCookieValue != null && jwtCookieValue.isNotEmpty ? "Found" : "Not found"}');

      if (jwtCookieValue != null && 
          jwtCookieValue.isNotEmpty && 
          jwtCookieValue != 'null' && 
          jwtCookieValue != '""') {
        // Store the JWT cookie
        await _cookieManager.saveJwtCookie(jwtCookieValue);
        
        // Also store the JWT in AuthService for compatibility with existing code
        await AuthService.storeJwt(jwtCookieValue);
        
        // Navigate to home screen
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      debugPrint('Error checking for JWT cookie: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appName = AuthService.appName;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Login to $appName'),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              width: double.infinity,
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
          
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}