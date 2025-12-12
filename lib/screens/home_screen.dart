import 'dart:async';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/agixt/widgets/agixt_chat.dart'; // Import AGiXTChatWidget
import 'package:agixt/screens/settings_screen.dart';
import 'package:agixt/services/ai_service.dart';
import 'package:agixt/services/cookie_manager.dart';
import 'package:agixt/services/location_service.dart'; // Import LocationService
import 'package:agixt/services/onboarding_service.dart';
import 'package:agixt/services/session_manager.dart';
import 'package:agixt/utils/app_events.dart'; // Import AppEvents
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/bluetooth_manager.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.forceNewChat = false});

  /// When true, forces a new chat instead of restoring the previous conversation
  final bool forceNewChat;

  // Static accessor for the WebViewController
  static WebViewController? webViewController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BluetoothManager bluetoothManager = BluetoothManager();
  final AIService aiService = AIService();
  final LocationService _locationService = LocationService();

  String? _userEmail;
  bool _isLoggedIn = true;
  bool _isSideButtonListenerAttached = false;
  WebViewController? _webViewController;
  bool _hasPromptedForGlasses = false;
  Timer? _locationUpdateTimer;
  StreamSubscription<Position>? _locationSubscription;
  bool _hasLoadedChatPage =
      false; // Track if we've successfully loaded chat before detecting logout
  bool _jsChannelsRegistered =
      false; // Track if JavaScript channels have been registered

  @override
  void initState() {
    super.initState();
    // Initialize AIService for foreground mode
    aiService.setBackgroundMode(false);
    _setupBluetoothListeners();
    _initializeApp();
    // Listen for location settings changes
    AppEvents.addLocationListener(_onLocationSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptForGlasses();
    });
  }

  @override
  void dispose() {
    // Clean up WebSocket connections when home screen is disposed
    aiService.disconnectWebSocket();
    // Clean up location updates
    _locationUpdateTimer?.cancel();
    _locationSubscription?.cancel();
    // Remove location settings listener
    AppEvents.removeLocationListener(_onLocationSettingsChanged);
    super.dispose();
  }

  /// Handle location settings changes from the settings screen
  void _onLocationSettingsChanged(bool enabled) {
    debugPrint('HomeScreen: Location settings changed to $enabled');
    if (enabled) {
      _setupLocationInjection();
    } else {
      _locationUpdateTimer?.cancel();
      _locationSubscription?.cancel();
      _clearLocationInWebView();
    }
  }

  /// Initialize the app in proper sequence to avoid race conditions
  Future<void> _initializeApp() async {
    debugPrint('HomeScreen: Starting app initialization');

    // First, load user details to set _isLoggedIn state
    await _loadUserDetails();
    debugPrint('HomeScreen: User details loaded, _isLoggedIn=$_isLoggedIn');

    // Only proceed with WebView initialization if logged in
    if (!_isLoggedIn) {
      debugPrint('HomeScreen: Not logged in, skipping WebView initialization');
      return;
    }

    // Clear cache if needed, then initialize WebView
    debugPrint('HomeScreen: Clearing WebView cache if needed');
    await _clearWebViewCacheIfNeeded();

    debugPrint('HomeScreen: Initializing WebView');
    await _initializeWebView();
    debugPrint('HomeScreen: WebView initialized');

    // Initialize conversation and agent after WebView is ready
    await _ensureConversationId();
    await _initializeAgentCookie();

    // Connect WebSocket for real-time streaming and client commands
    debugPrint('HomeScreen: Connecting WebSocket for streaming');
    await aiService.connectWebSocket();
    debugPrint('HomeScreen: App initialization complete');
  }

  // Clear WebView cache on first launch after install/update to prevent stale state
  Future<void> _clearWebViewCacheIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCacheClear = prefs.getInt('webview_cache_cleared_version') ?? 0;
      const currentVersion =
          2; // Increment this to force cache clear on updates

      if (lastCacheClear < currentVersion) {
        debugPrint(
            'Clearing WebView cache (version $lastCacheClear -> $currentVersion)');

        // Clear WebView cookies
        final cookieManager = WebViewCookieManager();
        await cookieManager.clearCookies();

        // Mark cache as cleared for this version
        await prefs.setInt('webview_cache_cleared_version', currentVersion);
        debugPrint('WebView cache cleared successfully');
      }
    } catch (e) {
      debugPrint('Error clearing WebView cache: $e');
    }
  }

  Future<void> _loadUserDetails() async {
    final email = await AuthService.getEmail();
    final isLoggedIn = await AuthService.isLoggedIn();

    if (mounted) {
      setState(() {
        _userEmail = email;
        _isLoggedIn = isLoggedIn;
      });

      // For debugging
      debugPrint("User email: $_userEmail");
      debugPrint("Is logged in: $_isLoggedIn");

      // Redirect to login if not logged in
      if (!_isLoggedIn) {
        Navigator.of(context).pushReplacementNamed('/login');
      } else if (_userEmail == null || _userEmail!.isEmpty) {
        // If logged in but email is missing, try to get the user info
        final userInfo = await AuthService.getUserInfo();
        if (userInfo != null && userInfo.email.isNotEmpty) {
          setState(() {
            _userEmail = userInfo.email;
          });
          // Store the email for future use
          await AuthService.storeEmail(userInfo.email);
          debugPrint("Updated user email from user info: $_userEmail");
        }
      }
    }
  }

  void _setupBluetoothListeners() {
    // Wait until the glasses are connected to attach the listener
    Future.delayed(const Duration(seconds: 2), () {
      if (bluetoothManager.isConnected && !_isSideButtonListenerAttached) {
        _attachSideButtonListener();
      } else {
        // Try again later
        _setupBluetoothListeners();
      }
    });
  }

  void _attachSideButtonListener() {
    // Monitor for the side button press events from glasses
    if (bluetoothManager.rightGlass != null) {
      bluetoothManager.rightGlass!.onSideButtonPress = () {
        _handleSideButtonPress();
      };
      _isSideButtonListenerAttached = true;
    }
  }

  Future<void> _handleSideButtonPress() async {
    // Check if user is logged in
    if (!await AuthService.isLoggedIn()) {
      bluetoothManager.sendAIResponse('Please log in to use AI assistant');
      return;
    }

    // Handle the side button press to activate AI communications
    await aiService.handleSideButtonPress();
  }

  Future<void> _initializeWebView() async {
    if (!_isLoggedIn) return;

    // Get the URL with authentication token
    final webUrl = await AuthService.getWebUrlWithToken();

    // Create a CookieManager instance
    final cookieManager = CookieManager();

    // Check if we have a previous conversation ID to restore
    final lastConversationId = await cookieManager.getAgixtConversationId();

    // Determine the URL to load
    String urlToLoad;
    if (!widget.forceNewChat &&
        lastConversationId != null &&
        lastConversationId != "-") {
      // Navigate to the previous conversation if available (unless forceNewChat is true)
      final uri = Uri.parse(webUrl);
      urlToLoad = uri.replace(path: '/chat/$lastConversationId').toString();
      debugPrint('Navigating to previous conversation: $urlToLoad');
    } else {
      // Otherwise, just go to the main chat page for a new chat
      final uri = Uri.parse(webUrl);
      urlToLoad = uri.replace(path: '/chat').toString();
      debugPrint('Starting new chat (forceNewChat=${widget.forceNewChat})');
    }

    // Initialize the WebView controller with performance optimizations
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..enableZoom(false);

    // Register JavaScript channels BEFORE setting up navigation delegate
    // This must be done only once per WebViewController instance
    await _registerJavaScriptChannels();

    _webViewController!
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            // Pre-warm any necessary connections
            debugPrint('Page loading started: $url');
          },
          onPageFinished: (String url) async {
            // Extract conversation ID from URL and agent cookie
            await _extractConversationIdAndAgentInfo(url);

            // Remove authentication tokens from the visible URL to
            // prevent them leaking through screenshots or re-shares.
            await _scrubAuthTokenFromLocation();

            // Inject JavaScript observers (channels already registered)
            await _injectUrlChangeObserver();

            // Inject agent selection observer
            await _injectAgentSelectionObserver();

            // Set up location injection for the webview
            await _setupLocationInjection();
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint(
                'Navigation request to: ${request.url} (isMainFrame: ${request.isMainFrame})');

            // Always allow iframe/subframe navigations
            if (!request.isMainFrame) {
              return NavigationDecision.navigate;
            }

            if (!request.url.contains('agixt')) {
              // External link, launch in browser
              _launchInBrowser(request.url);
              return NavigationDecision.prevent;
            } else {
              // Internal link, extract info and navigate
              _extractConversationIdAndAgentInfo(request.url);
              return NavigationDecision.navigate;
            }
          },
          onUrlChange: (UrlChange change) {
            // This catches client-side navigation that might not trigger a full navigation request
            debugPrint('URL changed to: ${change.url}');
            if (change.url != null) {
              _extractConversationIdAndAgentInfo(change.url!);
              _scrubAuthTokenFromLocation();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
                'WebView error: ${error.errorCode} - ${error.description}');
            debugPrint('Failed URL: ${error.url}');
            debugPrint('Error type: ${error.errorType}');

            // Handle common client-side errors
            if (error.isForMainFrame == true) {
              // Only handle main frame errors - iframe errors are often benign
              _handleWebViewError(error);
            } else {
              // Log iframe errors but don't disrupt the user experience
              debugPrint('Iframe error (non-critical): ${error.description}');
            }
          },
          onHttpError: (HttpResponseError error) {
            debugPrint(
                'HTTP error: ${error.response?.statusCode} for ${error.request?.uri}');
            // Handle authentication errors
            if (error.response?.statusCode == 401) {
              _handleAuthenticationError();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(urlToLoad));

    // Update the static accessor so it can be used from other classes
    HomePage.webViewController = _webViewController;

    // Trigger rebuild to show the WebView instead of loading indicator
    if (mounted) {
      setState(() {});
    }
  }

  // Handle WebView errors gracefully
  void _handleWebViewError(WebResourceError error) {
    // Common error codes that indicate we should retry
    const retryableCodes = [
      -2,
      -6,
      -8
    ]; // NET_ERROR_FAILED, NET_ERROR_CONNECTION_REFUSED, etc.

    if (retryableCodes.contains(error.errorCode)) {
      debugPrint('Retryable error detected, will attempt reload');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _webViewController != null) {
          _webViewController!.reload();
        }
      });
    }
  }

  // Handle authentication errors from WebView
  Future<void> _handleAuthenticationError() async {
    debugPrint('Authentication error in WebView, refreshing token');
    // Try to refresh the page with a new token
    if (mounted) {
      final webUrl = await AuthService.getWebUrlWithToken();
      final uri = Uri.parse(webUrl);
      final urlToLoad = uri.replace(path: '/chat').toString();
      _webViewController?.loadRequest(Uri.parse(urlToLoad));
    }
  }

  Future<void> _scrubAuthTokenFromLocation() async {
    if (_webViewController == null) {
      return;
    }

    const script =
        "(() => { try { const current = new URL(window.location.href); if (current.searchParams.has('token')) { current.searchParams.delete('token'); window.history.replaceState(null, document.title, current.toString()); } } catch (err) { console.error('Token cleanup failed', err); } })();";

    try {
      await _webViewController!.runJavaScript(script);
    } catch (e) {
      debugPrint('Error scrubbing auth token from URL: $e');
    }
  }

  /// Check if the URL indicates the user has been logged out
  /// This happens when the webview navigates to the /user login page
  bool _isLogoutUrl(Uri uri) {
    final path = uri.path;
    // Check if we're on the /user page (login page) which indicates logout
    // Also check for /login or empty path with no auth
    return path == '/user' ||
        path.startsWith('/user/') ||
        path == '/login' ||
        path.startsWith('/login/');
  }

  /// Handle logout detected from the WebView
  /// Clears the session and navigates back to the mobile login screen
  Future<void> _handleWebViewLogout() async {
    debugPrint('HomeScreen: WebView logout detected, clearing session');

    // Import SessionManager to clear all session data
    await SessionManager.clearSession(clearWebCookies: true);

    if (mounted) {
      // Navigate to login screen and clear navigation stack
      // This gives the user a fresh start like opening the app for the first time
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  // Extract the conversation ID from URL and agent cookie from WebView
  Future<void> _extractConversationIdAndAgentInfo(String url) async {
    if (_webViewController == null) return;

    try {
      debugPrint('Processing URL for extraction: $url');

      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      debugPrint('Path segments: $pathSegments');

      // Check if we're on a chat page - mark that we've loaded it
      final isOnChatPage = pathSegments.contains('chat');
      if (isOnChatPage && !_hasLoadedChatPage) {
        debugPrint('HomeScreen: First chat page load detected');
        _hasLoadedChatPage = true;
      }

      // Check if the user has logged out (navigated to /user login page)
      // Only trigger logout detection after we've successfully loaded the chat page at least once
      // This prevents false logout detection during initial login flow
      if (_hasLoadedChatPage && _isLogoutUrl(uri)) {
        debugPrint('Detected logout - navigating to login screen');
        await _handleWebViewLogout();
        return;
      }

      // Check if the URL is '/chat' (exactly)
      if (pathSegments.contains('chat') &&
          (pathSegments.length == 1 ||
              (pathSegments.length > 1 && pathSegments.last == 'chat'))) {
        // Handle case when URL is just '/chat' without another '/'
        debugPrint('URL is exactly /chat - setting conversation ID to "-"');
        final cookieManager = CookieManager();
        await cookieManager.saveAgixtConversationId("-");
        debugPrint('Set conversation ID to "-" for /chat URL');
      }
      // Extract conversation ID from URL path if it contains '/chat/'
      else if (url.contains('/chat/')) {
        // Find the index of 'chat' in the path segments
        final chatIndex = pathSegments.indexOf('chat');
        debugPrint('Chat index in path: $chatIndex');

        // If 'chat' is found and there's a segment after it, that's our conversation ID
        if (chatIndex >= 0 && chatIndex < pathSegments.length - 1) {
          final conversationId = pathSegments[chatIndex + 1];
          debugPrint('Found conversation ID in URL: $conversationId');

          if (conversationId.isNotEmpty) {
            // Store the conversation ID directly
            final cookieManager = CookieManager();
            await cookieManager.saveAgixtConversationId(conversationId);
            debugPrint('Saved conversation ID directly: $conversationId');

            // Also use the AGiXTChatWidget method as a backup
            final chatWidget = AGiXTChatWidget();
            await chatWidget.updateConversationIdFromUrl(url);
          }
        } else {
          // Handle case where we're on the /chat/ page but no specific conversation ID
          // Try to get the existing conversation ID or generate a new one
          _ensureConversationId();
        }
      } else {
        // If we're not on a chat page at all, ensure we have a default conversation ID
        _ensureConversationId();
      }

      // Using improved JavaScript to extract the agixt-agent cookie
      final agentCookieScript = '''
      (function() {
        try {
          var cookies = document.cookie.split(';');
          for (var i = 0; i < cookies.length; i++) {
            var cookie = cookies[i].trim();
            if (cookie.startsWith('agixt-agent=')) {
              var value = cookie.substring('agixt-agent='.length);
              console.log('Found agixt-agent cookie:', value);
              return value;
            }
          }
          
          // Try to find the agent from the page content if cookie approach failed
          var agentElement = document.querySelector('.agent-selector .selected');
          if (agentElement) {
            var agentName = agentElement.textContent.trim();
            console.log('Found agent from selector:', agentName);
            return agentName;
          }
          
          return '';
        } catch (e) {
          console.error('Error in cookie extraction:', e);
          return '';
        }
      })()
      ''';

      final agentCookieValue =
          await _webViewController!.runJavaScriptReturningResult(
        agentCookieScript,
      ) as String?;

      debugPrint('Extracted agent value: ${agentCookieValue ?? "null"}');

      if (agentCookieValue != null &&
          agentCookieValue.isNotEmpty &&
          agentCookieValue != 'null' &&
          agentCookieValue != '""') {
        // Store the agent cookie using our CookieManager
        final cookieManager = CookieManager();
        await cookieManager.saveAgixtAgentCookie(agentCookieValue);
        debugPrint('Saved agent value: $agentCookieValue');
      } else {
        // If we didn't get a value, schedule a retry after a delay
        // This helps when the page is still loading or cookies aren't yet set
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _extractAgentInfoRetry();
          }
        });
      }
    } catch (e) {
      debugPrint('Error extracting conversation ID or agent info: $e');
    }
  }

  // Ensure we have a valid conversation ID
  Future<void> _ensureConversationId() async {
    try {
      final cookieManager = CookieManager();
      final existingId = await cookieManager.getAgixtConversationId();

      // If we don't have a conversation ID, set it to "-" instead of generating one
      if (existingId == null || existingId.isEmpty || existingId == 'Not set') {
        await cookieManager.saveAgixtConversationId("-");
        debugPrint('Set default conversation ID to "-"');
      } else {
        debugPrint('Using existing conversation ID: $existingId');
      }
    } catch (e) {
      debugPrint('Error ensuring conversation ID: $e');
    }
  }

  Future<void> _maybePromptForGlasses() async {
    if (_hasPromptedForGlasses || !mounted) {
      return;
    }

    final shouldShow = await OnboardingService.shouldShowGlassesPrompt();
    if (!shouldShow || !mounted) {
      return;
    }

    _hasPromptedForGlasses = true;

    final wantsToConnect = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connect your Even Realities glasses?'),
            content: const Text(
              'We can help you pair and customize your Even Realities G1 glasses now. You can also do this later from Glasses Settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Skip'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Connect now'),
              ),
            ],
          ),
        ) ??
        false;

    await OnboardingService.markGlassesPromptCompleted();

    if (wantsToConnect && mounted) {
      _openGlassesSettings();
    }
  }

  void _openGlassesSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GlassesSettingsPage()),
    ).then((_) => setState(() {}));
  }

  // Retry extracting agent info after a delay
  Future<void> _extractAgentInfoRetry() async {
    if (_webViewController == null) return;

    try {
      debugPrint('Retrying agent extraction...');

      // Alternative JavaScript approach focused just on agent extraction
      final altAgentScript = '''
      (function() {
        try {
          // Try cookie approach first
          var cookies = document.cookie.split(';');
          for (var i = 0; i < cookies.length; i++) {
            var cookie = cookies[i].trim();
            if (cookie.startsWith('agixt-agent=')) {
              return cookie.substring('agixt-agent='.length);
            }
          }
          
          // Try DOM inspection
          // Look for agent selector or any UI element that might contain the agent name
          var agentElements = document.querySelectorAll('[data-agent], .agent-name, .model-selector');
          for (var i = 0; i < agentElements.length; i++) {
            var text = agentElements[i].textContent.trim();
            if (text && text.length > 0 && text !== 'null') {
              return text;
            }
          }
          
          return '';
        } catch (e) {
          console.error('Error in alternative agent extraction:', e);
          return '';
        }
      })()
      ''';

      final agentValue = await _webViewController!
          .runJavaScriptReturningResult(altAgentScript) as String?;

      if (agentValue != null &&
          agentValue.isNotEmpty &&
          agentValue != 'null' &&
          agentValue != '""') {
        final cookieManager = CookieManager();
        await cookieManager.saveAgixtAgentCookie(agentValue);
        debugPrint('Saved agent value from retry: $agentValue');
      }
    } catch (e) {
      debugPrint('Error in agent retry: $e');
    }
  }

  /// Register JavaScript channels for WebView communication
  /// This must be called once when the WebViewController is created, before loading any URL
  Future<void> _registerJavaScriptChannels() async {
    if (_webViewController == null || _jsChannelsRegistered) return;

    try {
      // Register the URL change listener channel
      await _webViewController!.addJavaScriptChannel(
        'UrlChangeListener',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('URL change from JS: ${message.message}');
          _extractConversationIdAndAgentInfo(message.message);
        },
      );

      // Register the agent change listener channel
      await _webViewController!.addJavaScriptChannel(
        'AgentChangeListener',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message.isNotEmpty &&
              message.message != 'null' &&
              message.message != '""') {
            debugPrint('Agent change from JS: ${message.message}');
            _saveAgentValue(message.message);
          }
        },
      );

      _jsChannelsRegistered = true;
      debugPrint('JavaScript channels registered successfully');
    } catch (e) {
      debugPrint('Error registering JavaScript channels: $e');
    }
  }

  /// Inject URL change observer JavaScript (channels must already be registered)
  Future<void> _injectUrlChangeObserver() async {
    if (_webViewController == null) return;

    try {
      // JavaScript to observe URL changes and call our handling function
      final urlObserverScript = '''
      (function() {
        // Check if we've already set up the observer
        if (window._agixtUrlObserverSetup) return;
        
        // Track the last URL we've seen
        let lastUrl = window.location.href;
        
        // Create a function to check for URL changes
        function checkUrlChange() {
          if (lastUrl !== window.location.href) {
            console.log('URL changed from JS observer:', window.location.href);
            lastUrl = window.location.href;
            
            // Use the registered JavaScript channel
            if (typeof UrlChangeListener !== 'undefined') {
              UrlChangeListener.postMessage(lastUrl);
            }
          }
        }
        
        // Set a regular interval to check for changes
        setInterval(checkUrlChange, 300);
        
        // Also monitor History API
        const originalPushState = history.pushState;
        const originalReplaceState = history.replaceState;
        
        history.pushState = function() {
          originalPushState.apply(this, arguments);
          checkUrlChange();
        };
        
        history.replaceState = function() {
          originalReplaceState.apply(this, arguments);
          checkUrlChange();
        };
        
        // Mark as set up
        window._agixtUrlObserverSetup = true;
        
        console.log('AGiXT URL observer initialized');
      })();
      ''';

      await _webViewController!.runJavaScript(urlObserverScript);
      debugPrint('URL change observer script injected');
    } catch (e) {
      debugPrint('Error injecting URL observer: $e');
    }
  }

  /// Inject agent selection observer JavaScript (channels must already be registered)
  Future<void> _injectAgentSelectionObserver() async {
    if (_webViewController == null) return;

    try {
      // JavaScript to observe agent selection changes
      final agentObserverScript = '''
      (function() {
        // Check if we've already set up the observer
        if (window._agixtAgentObserverSetup) return;
        
        // Function to extract current agent
        function extractCurrentAgent() {
          try {
            // Try cookie approach first
            const cookies = document.cookie.split(';');
            for (let i = 0; i < cookies.length; i++) {
              const cookie = cookies[i].trim();
              if (cookie.startsWith('agixt-agent=')) {
                const value = cookie.substring('agixt-agent='.length);
                if (value) return value;
              }
            }
            
            // Try DOM approaches
            // Look for agent selector or any UI element that might contain the agent name
            const selectors = [
              '.agent-selector .selected',
              '[data-agent]',
              '.agent-name',
              '.model-selector .selected',
              '.dropdown-content button.selected'
            ];
            
            for (const selector of selectors) {
              const elements = document.querySelectorAll(selector);
              for (let i = 0; i < elements.length; i++) {
                const text = elements[i].textContent.trim();
                if (text && text.length > 0 && text !== 'null') {
                  return text;
                }
              }
            }
            
            return '';
          } catch (e) {
            console.error('Error extracting agent:', e);
            return '';
          }
        }
        
        // Set up click event listeners that might indicate agent change
        document.addEventListener('click', function(e) {
          // Wait a moment for the UI/cookie to update after a click
          setTimeout(() => {
            const agent = extractCurrentAgent();
            if (agent && typeof AgentChangeListener !== 'undefined') {
              console.log('Agent may have changed to:', agent);
              // Use the registered JavaScript channel
              AgentChangeListener.postMessage(agent);
            }
          }, 300);
        }, true);
        
        // Also check periodically
        setInterval(() => {
          const agent = extractCurrentAgent();
          if (agent && typeof AgentChangeListener !== 'undefined') {
            // Use the registered JavaScript channel
            AgentChangeListener.postMessage(agent);
          }
        }, 2000);
        
        // Mark as set up
        window._agixtAgentObserverSetup = true;
        
        console.log('AGiXT agent observer initialized');
      })();
      ''';

      await _webViewController!.runJavaScript(agentObserverScript);
      debugPrint('Agent selection observer script injected');
    } catch (e) {
      debugPrint('Error injecting agent observer: $e');
    }
  }

  // Helper method to save agent value
  Future<void> _saveAgentValue(String agentValue) async {
    // Remove quotes that might be surrounding the agent value
    String cleanValue = agentValue;

    // Check if the value starts and ends with quotes
    if (cleanValue.startsWith('"') && cleanValue.endsWith('"')) {
      cleanValue = cleanValue.substring(1, cleanValue.length - 1);
    }

    debugPrint('Original agent value: $agentValue, Clean value: $cleanValue');

    final cookieManager = CookieManager();
    await cookieManager.saveAgixtAgentCookie(cleanValue);
    debugPrint('Saved agent value: $cleanValue');

    // Notify any listening screens to update
    _notifyDataChange();
  }

  // Notify that data has changed so listening screens can update
  void _notifyDataChange() {
    // Using EventBus would be better, but we're keeping it simple with a static method
    AppEvents.notifyDataChanged();
  }

  // Initialize agent cookie with primary agent if none is set
  Future<void> _initializeAgentCookie() async {
    try {
      final cookieManager = CookieManager();
      await cookieManager.initializeAgentCookie();
    } catch (e) {
      debugPrint('Error initializing agent cookie: $e');
    }
  }

  // Set up location injection for the webview
  Future<void> _setupLocationInjection() async {
    if (_webViewController == null) return;

    try {
      // Check if location is enabled in settings
      final isLocationEnabled = await _locationService.isLocationEnabled();
      debugPrint('Location enabled in settings: $isLocationEnabled');

      if (!isLocationEnabled) {
        debugPrint('Location is disabled in settings, skipping injection');
        // Clear any existing location data in the webview
        await _clearLocationInWebView();
        return;
      }

      // Set up JavaScript channel for location requests from webview
      await _webViewController!.addJavaScriptChannel(
        'NativeLocationChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          debugPrint('Location request from webview: ${message.message}');
          await _injectCurrentLocation();
        },
      );

      // Inject initial location
      await _injectCurrentLocation();

      // Start periodic location updates (every 30 seconds)
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _injectCurrentLocation(),
      );

      // Also listen to location stream for real-time updates
      _locationSubscription?.cancel();
      final locationStream = _locationService.getLocationStream();
      if (locationStream != null) {
        _locationSubscription = locationStream.listen(
          (Position position) {
            _injectPositionToWebView(position);
          },
          onError: (error) {
            debugPrint('Location stream error: $error');
          },
        );
      }

      // Inject JavaScript to override navigator.geolocation API
      await _injectGeolocationOverride();

      // Inject fetch interceptor to add location context to chat API calls
      await _injectFetchInterceptor();

      debugPrint('Location injection setup complete');
    } catch (e) {
      debugPrint('Error setting up location injection: $e');
    }
  }

  // Inject a fetch interceptor to add location context to chat completions API calls
  Future<void> _injectFetchInterceptor() async {
    if (_webViewController == null) return;

    try {
      const fetchInterceptorScript = '''
      (function() {
        if (window._fetchInterceptorSetup) return;
        
        // Store the original fetch function
        const originalFetch = window.fetch;
        
        // Helper to build location context string
        function buildLocationContext() {
          if (!window._nativeDeviceLocation || !window._nativeLocationEnabled) {
            return null;
          }
          
          const loc = window._nativeDeviceLocation;
          const lines = [
            "### User's Current Location",
            "",
            "Coordinates: " + loc.formatted,
            "Latitude: " + loc.latitude,
            "Longitude: " + loc.longitude
          ];
          
          if (loc.altitude !== null && loc.altitude !== undefined) {
            lines.push("Altitude: " + loc.altitude.toFixed(1) + " m");
          }
          if (loc.accuracy !== null && loc.accuracy !== undefined) {
            lines.push("Accuracy: " + loc.accuracy.toFixed(1) + " m");
          }
          if (loc.speed !== null && loc.speed !== undefined && loc.speed > 0) {
            lines.push("Speed: " + loc.speed.toFixed(1) + " m/s");
          }
          if (loc.heading !== null && loc.heading !== undefined && loc.heading >= 0) {
            lines.push("Heading: " + loc.heading.toFixed(1) + "°");
          }
          
          return lines.join("\\n");
        }
        
        // Helper to inject location into user_input for GraphQL mutations
        function injectLocationIntoUserInput(userInput, locationContext) {
          if (!userInput || !locationContext) return userInput;
          return userInput + "\\n\\n[Location Context]\\n" + locationContext;
        }
        
        // Override fetch
        window.fetch = async function(url, options) {
          const urlStr = typeof url === 'string' ? url : url.toString();
          
          // Skip if location is not enabled
          if (!window._nativeLocationEnabled || !window._nativeDeviceLocation) {
            return originalFetch.apply(this, arguments);
          }
          
          // Check if this is a chat completions REST request
          const isChatCompletion = urlStr.includes('/v1/chat/completions') || 
                                    (urlStr.includes('/api/agent/') && urlStr.includes('/prompt'));
          
          // Check if this is a GraphQL request
          const isGraphQL = urlStr.includes('/graphql');
          
          if (options && options.body) {
            try {
              const body = JSON.parse(options.body);
              const locationContext = buildLocationContext();
              
              if (!locationContext) {
                return originalFetch.apply(this, arguments);
              }
              
              let modified = false;
              
              // Handle REST chat completions
              if (isChatCompletion && body.messages && body.messages.length > 0) {
                for (let i = body.messages.length - 1; i >= 0; i--) {
                  if (body.messages[i].role === 'user') {
                    if (body.messages[i].context) {
                      body.messages[i].context = body.messages[i].context + "\\n\\n" + locationContext;
                    } else {
                      body.messages[i].context = locationContext;
                    }
                    console.log('[Native Location] Injected into REST chat message');
                    modified = true;
                    break;
                  }
                }
              }
              
              // Handle GraphQL mutations (promptAgent, chat completions via GQL)
              if (isGraphQL && body.query) {
                const query = body.query.toLowerCase();
                const isPromptMutation = query.includes('mutation') && 
                  (query.includes('promptagent') || query.includes('prompt_agent') || 
                   query.includes('chatcompletion') || query.includes('chat_completion'));
                
                if (isPromptMutation && body.variables) {
                  // Look for user_input or content in variables
                  if (body.variables.input) {
                    if (body.variables.input.prompt_args && body.variables.input.prompt_args.user_input) {
                      body.variables.input.prompt_args.user_input = 
                        injectLocationIntoUserInput(body.variables.input.prompt_args.user_input, locationContext);
                      console.log('[Native Location] Injected into GraphQL prompt_args.user_input');
                      modified = true;
                    } else if (body.variables.input.user_input) {
                      body.variables.input.user_input = 
                        injectLocationIntoUserInput(body.variables.input.user_input, locationContext);
                      console.log('[Native Location] Injected into GraphQL input.user_input');
                      modified = true;
                    }
                  }
                  
                  // Also check for messages array in variables (chat completions style)
                  if (body.variables.messages && Array.isArray(body.variables.messages)) {
                    for (let i = body.variables.messages.length - 1; i >= 0; i--) {
                      if (body.variables.messages[i].role === 'user') {
                        const msg = body.variables.messages[i];
                        if (typeof msg.content === 'string') {
                          body.variables.messages[i].content = 
                            injectLocationIntoUserInput(msg.content, locationContext);
                          console.log('[Native Location] Injected into GraphQL messages content');
                          modified = true;
                          break;
                        }
                      }
                    }
                  }
                }
              }
              
              if (modified) {
                // Create new options object with modified body
                const newOptions = { ...options, body: JSON.stringify(body) };
                return originalFetch.call(this, url, newOptions);
              }
            } catch (e) {
              console.error('[Native Location] Error injecting location:', e);
            }
          }
          
          // Call the original fetch with original arguments
          return originalFetch.apply(this, arguments);
        };
        
        window._fetchInterceptorSetup = true;
        console.log('[Native Location] Fetch interceptor initialized - location will be injected into chat messages');
      })();
      ''';

      await _webViewController!.runJavaScript(fetchInterceptorScript);
      debugPrint('Fetch interceptor injected');
    } catch (e) {
      debugPrint('Error injecting fetch interceptor: $e');
    }
  }

  // Clear location data from webview when location is disabled
  Future<void> _clearLocationInWebView() async {
    if (_webViewController == null) return;

    try {
      const clearScript = '''
      (function() {
        // Clear native device location
        window._nativeDeviceLocation = null;
        window._nativeLocationEnabled = false;
        console.log('Native device location cleared - location will no longer be injected into chat messages');
      })();
      ''';
      await _webViewController!.runJavaScript(clearScript);
    } catch (e) {
      debugPrint('Error clearing location in webview: $e');
    }
  }

  // Inject current location into the webview
  Future<void> _injectCurrentLocation() async {
    if (_webViewController == null) return;

    try {
      // Check if location is still enabled
      final isLocationEnabled = await _locationService.isLocationEnabled();
      if (!isLocationEnabled) {
        await _clearLocationInWebView();
        return;
      }

      // Get current position with timeout
      final position = await _locationService.getCurrentPosition(
        timeout: const Duration(seconds: 5),
      );

      if (position != null) {
        await _injectPositionToWebView(position);
      } else {
        // Try to use last known position
        final lastPosition = await _locationService.getLastPosition();
        if (lastPosition.isNotEmpty) {
          await _injectLastPositionToWebView(lastPosition);
        }
      }
    } catch (e) {
      debugPrint('Error injecting current location: $e');
    }
  }

  // Inject a Position object to the webview
  Future<void> _injectPositionToWebView(Position position) async {
    if (_webViewController == null) return;

    try {
      final timestamp = position.timestamp.millisecondsSinceEpoch;

      final locationScript = '''
      (function() {
        window._nativeDeviceLocation = {
          latitude: ${position.latitude},
          longitude: ${position.longitude},
          altitude: ${position.altitude},
          accuracy: ${position.accuracy},
          altitudeAccuracy: ${position.altitudeAccuracy},
          heading: ${position.heading},
          speed: ${position.speed},
          timestamp: $timestamp,
          formatted: "${LocationService.formatCoordinates(position.latitude, position.longitude)}"
        };
        window._nativeLocationEnabled = true;
        console.log('Native device location updated:', window._nativeDeviceLocation);
        
        // Dispatch event so web app knows location is available
        window.dispatchEvent(new CustomEvent('nativeLocationUpdate', { 
          detail: window._nativeDeviceLocation 
        }));
      })();
      ''';

      await _webViewController!.runJavaScript(locationScript);
      debugPrint(
          'Location injected: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Error injecting position to webview: $e');
    }
  }

  // Inject last known position to the webview
  Future<void> _injectLastPositionToWebView(
      Map<String, dynamic> lastPosition) async {
    if (_webViewController == null) return;

    try {
      final latitude = lastPosition['latitude'] as double?;
      final longitude = lastPosition['longitude'] as double?;
      if (latitude == null || longitude == null) return;

      final altitude = lastPosition['altitude'] as double? ?? 0.0;
      final accuracy = lastPosition['accuracy'] as double? ?? 0.0;
      final timestamp =
          (lastPosition['timestamp'] as DateTime?)?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch;

      final locationScript = '''
      (function() {
        window._nativeDeviceLocation = {
          latitude: $latitude,
          longitude: $longitude,
          altitude: $altitude,
          accuracy: $accuracy,
          altitudeAccuracy: null,
          heading: null,
          speed: null,
          timestamp: $timestamp,
          formatted: "${LocationService.formatCoordinates(latitude, longitude)}",
          isLastKnown: true
        };
        window._nativeLocationEnabled = true;
        console.log('Native device location updated (last known):', window._nativeDeviceLocation);
        
        // Dispatch event so web app knows location is available
        window.dispatchEvent(new CustomEvent('nativeLocationUpdate', { 
          detail: window._nativeDeviceLocation 
        }));
      })();
      ''';

      await _webViewController!.runJavaScript(locationScript);
      debugPrint('Last known location injected: $latitude, $longitude');
    } catch (e) {
      debugPrint('Error injecting last position to webview: $e');
    }
  }

  // Inject a geolocation API override into the webview
  Future<void> _injectGeolocationOverride() async {
    if (_webViewController == null) return;

    try {
      const geolocationScript = '''
      (function() {
        if (window._geolocationOverrideSetup) return;
        
        // Store original geolocation
        const originalGeolocation = navigator.geolocation;
        
        // Override getCurrentPosition
        const customGetCurrentPosition = function(success, error, options) {
          // First try native device location
          if (window._nativeDeviceLocation && window._nativeLocationEnabled) {
            const loc = window._nativeDeviceLocation;
            const position = {
              coords: {
                latitude: loc.latitude,
                longitude: loc.longitude,
                altitude: loc.altitude,
                accuracy: loc.accuracy,
                altitudeAccuracy: loc.altitudeAccuracy,
                heading: loc.heading,
                speed: loc.speed
              },
              timestamp: loc.timestamp
            };
            console.log('Using native device location for getCurrentPosition');
            success(position);
            return;
          }
          
          // Fall back to browser geolocation
          console.log('Native location not available, falling back to browser');
          if (originalGeolocation && originalGeolocation.getCurrentPosition) {
            originalGeolocation.getCurrentPosition(success, error, options);
          } else if (error) {
            error({ code: 2, message: 'Location not available' });
          }
        };
        
        // Override watchPosition
        const customWatchPosition = function(success, error, options) {
          // Set up listener for native location updates
          let watchId = Math.floor(Math.random() * 1000000);
          
          const handleUpdate = function(event) {
            if (event.detail && window._nativeLocationEnabled) {
              const loc = event.detail;
              const position = {
                coords: {
                  latitude: loc.latitude,
                  longitude: loc.longitude,
                  altitude: loc.altitude,
                  accuracy: loc.accuracy,
                  altitudeAccuracy: loc.altitudeAccuracy,
                  heading: loc.heading,
                  speed: loc.speed
                },
                timestamp: loc.timestamp
              };
              success(position);
            }
          };
          
          window.addEventListener('nativeLocationUpdate', handleUpdate);
          
          // Send initial position if available
          if (window._nativeDeviceLocation && window._nativeLocationEnabled) {
            handleUpdate({ detail: window._nativeDeviceLocation });
          }
          
          // Store the handler for clearWatch
          window._geoWatches = window._geoWatches || {};
          window._geoWatches[watchId] = handleUpdate;
          
          return watchId;
        };
        
        // Override clearWatch
        const customClearWatch = function(watchId) {
          if (window._geoWatches && window._geoWatches[watchId]) {
            window.removeEventListener('nativeLocationUpdate', window._geoWatches[watchId]);
            delete window._geoWatches[watchId];
          }
        };
        
        // Apply overrides
        Object.defineProperty(navigator, 'geolocation', {
          value: {
            getCurrentPosition: customGetCurrentPosition,
            watchPosition: customWatchPosition,
            clearWatch: customClearWatch
          },
          configurable: true,
          writable: false
        });
        
        window._geolocationOverrideSetup = true;
        console.log('Geolocation API override initialized');
      })();
      ''';

      await _webViewController!.runJavaScript(geolocationScript);
      debugPrint('Geolocation override injected');
    } catch (e) {
      debugPrint('Error injecting geolocation override: $e');
    }
  }

  Future<void> _launchInBrowser(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildWebView()),
            Positioned(
              top: kToolbarHeight +
                  12, // keep shortcut clear of account/settings buttons
              right: 12,
              child: _GlassesShortcut(onPressed: _openGlassesSettings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView() {
    if (_webViewController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Use RepaintBoundary to optimize rendering performance
    return RepaintBoundary(
      child: WebViewWidget(controller: _webViewController!),
    );
  }
}

class _GlassesShortcut extends StatelessWidget {
  const _GlassesShortcut({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.all(10),
        shape: const CircleBorder(),
        visualDensity: VisualDensity.compact,
      ),
      child: const Icon(Symbols.eyeglasses_rounded),
    );
  }
}
