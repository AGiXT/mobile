import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/agixt/widgets/agixt_chat.dart'; // Import AGiXTChatWidget
import 'package:agixt/screens/auth/profile_screen.dart';
import 'package:agixt/screens/settings_screen.dart';
import 'package:agixt/services/ai_service.dart';
import 'package:agixt/services/cookie_manager.dart';
import 'package:agixt/utils/app_events.dart'; // Import AppEvents
import 'package:agixt/widgets/gravatar_image.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/bluetooth_manager.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  // Static accessor for the WebViewController
  static WebViewController? webViewController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BluetoothManager bluetoothManager = BluetoothManager();
  final AIService aiService = AIService();

  String? _userEmail;
  bool _isLoggedIn = true;
  bool _isSideButtonListenerAttached = false;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    // Initialize AIService for foreground mode
    aiService.setBackgroundMode(false);
    _loadUserDetails();
    _setupBluetoothListeners();
    _initializeWebView();
    _ensureConversationId(); // Ensure a conversation ID exists at startup
    _initializeAgentCookie(); // Initialize the agent cookie with primary agent if needed
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
    if (lastConversationId != null && lastConversationId != "-") {
      // Navigate to the previous conversation if available
      final uri = Uri.parse(webUrl);
      urlToLoad = uri.replace(path: '/chat/$lastConversationId').toString();
      debugPrint('Navigating to previous conversation: $urlToLoad');
    } else {
      // Otherwise, just go to the main chat page
      final uri = Uri.parse(webUrl);
      urlToLoad = uri.replace(path: '/chat').toString();
    }

    // Initialize the WebView controller
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            // Extract conversation ID from URL and agent cookie
            await _extractConversationIdAndAgentInfo(url);

            // Remove authentication tokens from the visible URL to
            // prevent them leaking through screenshots or re-shares.
            await _scrubAuthTokenFromLocation();

            // Set up URL change observer using JavaScript
            await _setupUrlChangeObserver();

            // Set up agent selection observer
            await _setupAgentSelectionObserver();
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('Navigation request to: ${request.url}');
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
        ),
      )
      ..loadRequest(Uri.parse(urlToLoad));

    // Update the static accessor so it can be used from other classes
    HomePage.webViewController = _webViewController;
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

  // Extract the conversation ID from URL and agent cookie from WebView
  Future<void> _extractConversationIdAndAgentInfo(String url) async {
    if (_webViewController == null) return;

    try {
      debugPrint('Processing URL for extraction: $url');

      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      debugPrint('Path segments: $pathSegments');

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

  // Set up a JavaScript observer for URL changes (for SPA navigation that doesn't trigger native events)
  Future<void> _setupUrlChangeObserver() async {
    if (_webViewController == null) return;

    try {
      // Register the JavaScript channel first
      await _webViewController!.addJavaScriptChannel(
        'UrlChangeListener',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('URL change from JS: ${message.message}');
          _extractConversationIdAndAgentInfo(message.message);
        },
      );

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
            UrlChangeListener.postMessage(lastUrl);
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
      debugPrint('URL change observer setup complete');
    } catch (e) {
      debugPrint('Error setting up URL observer: $e');
    }
  }

  // Set up a JavaScript observer for agent selection changes
  Future<void> _setupAgentSelectionObserver() async {
    if (_webViewController == null) return;

    try {
      // Register the JavaScript channel first
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
            if (agent) {
              console.log('Agent may have changed to:', agent);
              // Use the registered JavaScript channel
              AgentChangeListener.postMessage(agent);
            }
          }, 300);
        }, true);
        
        // Also check periodically
        setInterval(() => {
          const agent = extractCurrentAgent();
          if (agent) {
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
      debugPrint('Agent selection observer setup complete');
    } catch (e) {
      debugPrint('Error setting up agent observer: $e');
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
      appBar: AppBar(
        title: Text(AuthService.appName),
        actions: [
          // Profile button with Gravatar
          if (_userEmail != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                child: GravatarImage(email: _userEmail!, size: 40),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: _buildWebView(),
    );
  }

  Widget _buildWebView() {
    if (_webViewController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return WebViewWidget(controller: _webViewController!);
  }
}
