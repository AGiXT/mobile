import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/agixt/calendar.dart';
import 'package:agixt/models/agixt/checklist.dart';
import 'package:agixt/models/agixt/daily.dart';
import 'package:agixt/models/agixt/stop.dart';
import 'package:agixt/screens/auth/webview_login_screen.dart';
import 'package:agixt/screens/auth/profile_screen.dart';
import 'package:agixt/screens/privacy/privacy_consent_screen.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/services/bluetooth_background_service.dart';
import 'package:agixt/services/stops_manager.dart';
import 'package:agixt/services/privacy_consent_service.dart';
import 'package:agixt/services/system_notification_service.dart';
import 'package:agixt/services/wallet_adapter_service.dart';
import 'package:agixt/utils/ui_perfs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/home_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Environment variables with defaults
const String APP_NAME = String.fromEnvironment(
  'APP_NAME',
  defaultValue: 'AGiXT',
);
const String AGIXT_SERVER = String.fromEnvironment(
  'AGIXT_SERVER',
  defaultValue: 'https://api.agixt.dev',
);
const String APP_URI = String.fromEnvironment(
  'APP_URI',
  defaultValue: 'https://agixt.com',
);
const String PRIVACY_POLICY_URL =
    'https://agixt.com/docs/5-Reference/1-Privacy%20Policy';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize AuthService with environment variables
    AuthService.init(
      serverUrl: AGIXT_SERVER,
      appUri: APP_URI,
      appName: APP_NAME,
    );

    // Initialize notifications with error handling
    try {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('agixt_logo'),
        ),
        onDidReceiveNotificationResponse: (NotificationResponse resp) async {
          debugPrint('onDidReceiveBackgroundNotificationResponse: $resp');
          if (resp.actionId == null) {
            return;
          }
          if (resp.actionId!.startsWith("delete_")) {
            _handleDeleteAction(resp.actionId!);
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }

    // Initialize Hive with error handling
    try {
      await _initHive();
    } catch (e) {
      debugPrint('Failed to initialize Hive: $e');
    }

    // Initialize UI preferences with error handling
    try {
      await UiPerfs.singleton.load();
    } catch (e) {
      debugPrint('Failed to load UI preferences: $e');
    }

    // Initialize services sequentially to avoid race conditions
    try {
      await BluetoothBackgroundService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize BluetoothBackgroundService: $e');
    }

    try {
      await BluetoothBackgroundService.requestBatteryOptimizationExemption();
    } catch (e) {
      debugPrint('Failed to request battery optimization exemption: $e');
    }

    try {
      await BluetoothManager.singleton.initialize();
    } catch (e) {
      debugPrint('Failed to initialize BluetoothManager: $e');
    }

    // Initialize system notification service for server-wide alerts
    try {
      await SystemNotificationService().initialize();
    } catch (e) {
      debugPrint('Failed to initialize SystemNotificationService: $e');
    }

    // Initialize wallet adapter service for Solana wallet connections
    try {
      await WalletAdapterService.initialize(appUri: APP_URI, appName: APP_NAME);
    } catch (e) {
      debugPrint('Failed to initialize WalletAdapterService: $e');
    }

    // Note: BluetoothBackgroundService.start() is now called automatically
    // when glasses connect via BluetoothManager._notifyConnectionStatusChanged()

    // Start the legacy background service only if needed
    try {
      final backgroundService = FlutterBackgroundService();
      final isBackgroundServiceRunning = await backgroundService.isRunning();

      if (!isBackgroundServiceRunning) {
        var channel = const MethodChannel('dev.agixt.agixt/background_service');
        var callbackHandle = PluginUtilities.getCallbackHandle(backgroundMain);
        await channel.invokeMethod(
          'startService',
          callbackHandle?.toRawHandle(),
        );
      } else {
        debugPrint('Background service already running, skipping start');
      }
    } catch (e) {
      debugPrint('Failed to start background service: $e');
    }

    // Start the app
    runApp(const AGiXTApp());
  } catch (e, stackTrace) {
    debugPrint('Fatal error during app initialization: $e');
    debugPrint('Stack trace: $stackTrace');

    // Try to run the app with minimal initialization
    runApp(
      MaterialApp(
        title: 'AGiXT',
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'App initialization failed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Error: $e'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void backgroundMain() {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('Background main initialized successfully');
  } catch (e) {
    debugPrint('Error in background main: $e');
  }
}

class AppRetainWidget extends StatelessWidget {
  const AppRetainWidget({super.key, required this.child});

  final Widget child;

  final _channel = const MethodChannel('dev.agixt.agixt/app_retain');

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        if (Platform.isAndroid) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            try {
              await _channel.invokeMethod('sendToBackground');
            } catch (e) {
              debugPrint('Error sending app to background: $e');
              // Fallback: just minimize the app
            }
          }
        }
      },
      child: child,
    );
  }
}

/// Navigator observer that detects when /home route is pushed
/// and syncs the root login state
class _AuthNavigatorObserver extends NavigatorObserver {
  final VoidCallback onHomeRouteActivated;
  
  _AuthNavigatorObserver({required this.onHomeRouteActivated});
  
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/home') {
      debugPrint('AuthNavigatorObserver: /home route pushed, syncing state');
      onHomeRouteActivated();
    }
  }
  
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute?.settings.name == '/home') {
      debugPrint('AuthNavigatorObserver: /home route replaced, syncing state');
      onHomeRouteActivated();
    }
  }
}

class AGiXTApp extends StatefulWidget {
  const AGiXTApp({super.key});

  // Global navigator key for accessing context from anywhere
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Static callback for WebViewLoginScreen to notify successful login
  static void Function()? onLoginSuccess;

  @override
  State<AGiXTApp> createState() => _AGiXTAppState();
}

class _AGiXTAppState extends State<AGiXTApp> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  bool _hasAcceptedPrivacy = false;
  DateTime? _privacyAcceptedAt;
  StreamSubscription? _deepLinkSubscription;
  final _appLinks = AppLinks();
  static final Uri _privacyPolicyUri = Uri.parse(PRIVACY_POLICY_URL);

  @override
  void initState() {
    super.initState();
    // Register the login success callback
    AGiXTApp.onLoginSuccess = _handleLoginSuccess;
    // Initialize with proper error handling
    _safeInitialization();
  }

  /// Called by WebViewLoginScreen when login is successful
  void _handleLoginSuccess() {
    debugPrint('Main: onLoginSuccess callback triggered');
    if (mounted) {
      setState(() {
        _isLoggedIn = true;
      });
    }
  }

  Future<void> _safeInitialization() async {
    try {
      final hasAccepted = await PrivacyConsentService.hasAcceptedLatestPolicy();
      final acceptedAt = await PrivacyConsentService.acceptedAt();

      if (mounted) {
        setState(() {
          _hasAcceptedPrivacy = hasAccepted;
          _privacyAcceptedAt = acceptedAt;
        });
      }

      await _checkLoginStatus();
      await _initDeepLinkHandling();
    } catch (e) {
      debugPrint('Error during app state initialization: $e');
      // Set safe defaults
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePrivacyAccepted() async {
    try {
      await PrivacyConsentService.recordAcceptance();
      final acceptedAt = await PrivacyConsentService.acceptedAt();

      if (!mounted) {
        return;
      }

      // Re-check login status after privacy acceptance
      // This is important because the user may have logged in via WebView
      // before accepting privacy, and we need to update our local state
      final isLoggedIn = await AuthService.isLoggedIn();
      debugPrint('After privacy acceptance, isLoggedIn = $isLoggedIn');

      setState(() {
        _hasAcceptedPrivacy = true;
        _privacyAcceptedAt = acceptedAt;
        _isLoggedIn = isLoggedIn;
      });
    } catch (e) {
      debugPrint('Error recording privacy acceptance: $e');
      final messenger = AGiXTApp.navigatorKey.currentContext;
      if (messenger != null) {
        ScaffoldMessenger.of(messenger).showSnackBar(
          const SnackBar(
            content: Text('We could not save your consent. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      final launched = await launchUrl(
        _privacyPolicyUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showPrivacyPolicyError();
      }
    } catch (e) {
      debugPrint('Error opening privacy policy: $e');
      _showPrivacyPolicyError();
    }
  }

  void _showPrivacyPolicyError() {
    final context = AGiXTApp.navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to open the privacy policy. Please try again later.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    AGiXTApp.onLoginSuccess = null;
    _deepLinkSubscription?.cancel();

    // Clean up all singletons and services with error handling
    try {
      BluetoothManager.singleton.dispose();
    } catch (e) {
      debugPrint('Error disposing BluetoothManager: $e');
    }

    try {
      StopsManager().dispose();
    } catch (e) {
      debugPrint('Error disposing StopsManager: $e');
    }

    super.dispose();
  }

  void _handleDeepLink(String link) {
    debugPrint('Received deep link: $link');

    // Handle various URL formats that might come from the OAuth redirect
    // The web server should redirect to: agixt://callback?token={jwt}
    final uri = Uri.tryParse(link);
    if (uri == null) {
      debugPrint('Failed to parse deep link URI');
      return;
    }

    // Check if this is our callback URL (case-insensitive scheme check)
    if (uri.scheme.toLowerCase() != 'agixt') {
      debugPrint('Deep link scheme is not agixt: ${uri.scheme}');
      return;
    }

    // Accept both 'callback' and 'oauth' hosts for flexibility
    final host = uri.host.toLowerCase();
    if (host != 'callback' && host != 'oauth' && host != '') {
      debugPrint('Deep link host is not callback/oauth: $host');
      return;
    }

    // Try to extract token from query parameters
    String? token = uri.queryParameters['token'];

    // Also check for 'access_token' parameter (some OAuth implementations use this)
    token ??= uri.queryParameters['access_token'];

    // Check path segments for token (agixt://callback/token/{jwt})
    if (token == null &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'token') {
      token = uri.pathSegments[1];
    }

    // Check fragment for token (some OAuth flows put it in the hash)
    if (token == null && uri.fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      token = fragmentParams['token'] ?? fragmentParams['access_token'];
    }

    if (token != null && token.isNotEmpty) {
      debugPrint('Received JWT token from deep link');
      _processJwtToken(token);
    } else {
      debugPrint('No token found in deep link: $link');
      // Check if there's an error parameter
      final error = uri.queryParameters['error'];
      if (error != null) {
        debugPrint(
          'OAuth error: $error - ${uri.queryParameters['error_description']}',
        );
      }
    }
  }

  Future<void> _processJwtToken(String token) async {
    try {
      await AuthService.storeJwt(token);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggedIn = true;
        _isLoading = false;
      });

      // Navigate to home screen after successful login via deep link
      // Use pushNamedAndRemoveUntil to clear the navigation stack
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      debugPrint('Error processing JWT token: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  /// Called by navigator observer when /home route is activated
  /// This syncs the root state with the actual auth state
  void _syncLoginState() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    debugPrint('Main: Navigator detected /home route, syncing state. isLoggedIn=$isLoggedIn');
    if (mounted && isLoggedIn != _isLoggedIn) {
      setState(() {
        _isLoggedIn = isLoggedIn;
      });
    }
  }

  Future<void> _initDeepLinkHandling() async {
    try {
      // Handle links that opened the app
      try {
        final initialUri = await _appLinks.getInitialAppLink();
        if (initialUri != null) {
          _handleDeepLink(initialUri.toString());
        }
      } catch (e) {
        debugPrint('Error getting initial deep link: $e');
      }

      // Handle links while app is running
      try {
        _deepLinkSubscription = _appLinks.uriLinkStream.listen(
          (Uri uri) {
            _handleDeepLink(uri.toString());
          },
          onError: (error) {
            debugPrint('Error handling deep link: $error');
          },
        );
      } catch (e) {
        debugPrint('Error setting up deep link stream: $e');
      }

      // Set up the method channel for OAuth callback from native code
      try {
        const platform = MethodChannel('dev.agixt.agixt/oauth_callback');
        platform.setMethodCallHandler((call) async {
          try {
            if (call.method == 'handleOAuthCallback') {
              final args = call.arguments as Map;
              final token = args['token'] as String?;

              if (token != null && token.isNotEmpty) {
                debugPrint(
                  'Received JWT token via method channel from native code',
                );
                await _processJwtToken(token);
              }
            } else if (call.method == 'checkPendingToken') {
              // This method is called by Flutter to check if there's a pending token
              // No action needed here as we already handle this in native code
              return null;
            }
            return null;
          } catch (e) {
            debugPrint('Error in method call handler: $e');
            return null;
          }
        });

        // Check if we have any pending tokens from native code that arrived before Flutter was initialized
        try {
          final result = await platform.invokeMethod('checkPendingToken');
          if (result != null && result is Map && result.containsKey('token')) {
            final token = result['token'] as String;
            debugPrint('Retrieved pending JWT token from native code');
            await _processJwtToken(token);
          }
        } catch (e) {
          debugPrint('Error checking for pending tokens: $e');
        }
      } catch (e) {
        debugPrint('Error setting up OAuth method channel: $e');
      }

      // Set up method channel for assistant/voice input triggers from native
      try {
        const assistantChannel = MethodChannel('dev.agixt.agixt/channel');
        assistantChannel.setMethodCallHandler((call) async {
          try {
            if (call.method == 'startVoiceInput') {
              debugPrint(
                'Assistant trigger received from native - starting voice input',
              );
              // Navigate to home page and trigger voice input
              final navigator = AGiXTApp.navigatorKey.currentState;
              if (navigator != null) {
                // Navigate to home with voice input flag
                navigator.pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
                  arguments: {'forceNewChat': true, 'startVoiceInput': true},
                );
              }
            }
            return null;
          } catch (e) {
            debugPrint('Error handling assistant method call: $e');
            return null;
          }
        });
      } catch (e) {
        debugPrint('Error setting up assistant method channel: $e');
      }
    } catch (e) {
      debugPrint('Error initializing deep link handling: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return MaterialApp(
        title: APP_NAME,
        navigatorKey: AGiXTApp.navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: _buildHome(),
        navigatorObservers: [_AuthNavigatorObserver(onHomeRouteActivated: _syncLoginState)],
        routes: {
          '/home': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
            final forceNewChat = args?['forceNewChat'] as bool? ?? false;
            final startVoiceInput = args?['startVoiceInput'] as bool? ?? false;
            return HomePage(
              forceNewChat: forceNewChat,
              startVoiceInput: startVoiceInput,
            );
          },
          '/login': (context) => const WebViewLoginScreen(),
          '/profile': (context) => const ProfileScreen(),
        },
      );
    } catch (e) {
      debugPrint('Error building MaterialApp: $e');
      return MaterialApp(
        title: 'AGiXT - Error',
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('App Error', style: TextStyle(fontSize: 24)),
                const SizedBox(height: 8),
                Text('$e'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _safeInitialization(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildHome() {
    try {
      if (_isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      if (!_hasAcceptedPrivacy) {
        return PrivacyConsentScreen(
          policyVersion: PrivacyConsentService.policyVersion,
          acceptedAt: _privacyAcceptedAt,
          onViewPolicy: _openPrivacyPolicy,
          onAccept: _handlePrivacyAccepted,
        );
      }

      return AppRetainWidget(
        child: _isLoggedIn ? const HomePage() : const WebViewLoginScreen(),
      );
    } catch (e) {
      debugPrint('Error building home widget: $e');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Loading Error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _safeInitialization(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }
}

Future<void> _initHive() async {
  try {
    // Initialize Hive
    await Hive.initFlutter();

    // Register adapters
    try {
      Hive.registerAdapter(AGiXTDailyItemAdapter());
      Hive.registerAdapter(AGiXTStopItemAdapter());
      Hive.registerAdapter(AGiXTCalendarAdapter());
      Hive.registerAdapter(AGiXTCheckListItemAdapter());
      Hive.registerAdapter(AGiXTChecklistAdapter());
    } catch (e) {
      // Adapters might already be registered
      debugPrint('Hive adapters already registered or error registering: $e');
    }

    // Open boxes with error handling
    try {
      if (!Hive.isBoxOpen('agixtDailyBox')) {
        await Hive.openBox<AGiXTDailyItem>('agixtDailyBox');
      }
    } catch (e) {
      debugPrint('Failed to open agixtDailyBox: $e');
    }

    try {
      if (!Hive.isBoxOpen('agixtStopBox')) {
        await Hive.openLazyBox<AGiXTStopItem>('agixtStopBox');
      }
    } catch (e) {
      debugPrint('Failed to open agixtStopBox: $e');
    }

    try {
      if (!Hive.isBoxOpen('agixtCalendarBox')) {
        await Hive.openBox<AGiXTCalendar>('agixtCalendarBox');
      }
    } catch (e) {
      debugPrint('Failed to open agixtCalendarBox: $e');
    }

    try {
      if (!Hive.isBoxOpen('agixtChecklistBox')) {
        await Hive.openBox<AGiXTChecklist>('agixtChecklistBox');
      }
    } catch (e) {
      debugPrint('Failed to open agixtChecklistBox: $e');
    }

    try {
      if (!Hive.isBoxOpen('agixtAppPrefs')) {
        await Hive.openBox('agixtAppPrefs');
      }
    } catch (e) {
      debugPrint('Failed to open agixtAppPrefs: $e');
    }
  } catch (e) {
    debugPrint('Critical error initializing Hive: $e');
    rethrow;
  }
}

// this will be used as notification channel id
const notificationChannelId = 'my_foreground';

// this will be used for notification id, So you can update your custom notification with this id.
const notificationId = 888;

Future<void> initializeService() async {
  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();

  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId, // id
    'AGiXT', // title
    description: 'This channel is used for AGiXT notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: false,

      notificationChannelId:
          notificationChannelId, // this must match with notification channel you created above.
      initialNotificationTitle: 'AGiXT',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: notificationId,

      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  try {
    // Only available for flutter 3.0.0 and later
    //DartPluginRegistrant.ensureInitialized();

    // Initialize Hive safely
    try {
      await Hive.initFlutter();

      // Register adapters if not already registered
      try {
        Hive.registerAdapter(AGiXTDailyItemAdapter());
        Hive.registerAdapter(AGiXTStopItemAdapter());
        Hive.registerAdapter(AGiXTCalendarAdapter());
        Hive.registerAdapter(AGiXTCheckListItemAdapter());
        Hive.registerAdapter(AGiXTChecklistAdapter());
      } catch (e) {
        debugPrint('Adapters already registered: $e');
      }

      // Open boxes safely
      try {
        if (!Hive.isBoxOpen('agixtDailyBox')) {
          await Hive.openBox<AGiXTDailyItem>('agixtDailyBox');
        }
      } catch (e) {
        debugPrint('Failed to open agixtDailyBox in background service: $e');
      }

      try {
        if (!Hive.isBoxOpen('agixtStopBox')) {
          await Hive.openLazyBox<AGiXTStopItem>('agixtStopBox');
        }
      } catch (e) {
        debugPrint('Failed to open agixtStopBox in background service: $e');
      }

      try {
        if (!Hive.isBoxOpen('agixtAppPrefs')) {
          await Hive.openBox('agixtAppPrefs');
        }
      } catch (e) {
        debugPrint('Failed to open agixtAppPrefs in background service: $e');
      }
    } catch (e) {
      debugPrint('Failed to initialize Hive in background service: $e');
    }

    // Initialize BluetoothManager safely
    try {
      final bt = BluetoothManager.singleton;
      await bt.initialize();
      if (!bt.isConnected) {
        bt.attemptReconnectFromStorage();
      }
    } catch (e) {
      debugPrint('Failed to initialize Bluetooth in background service: $e');
    }

    // Foreground service periodic task
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        // Check if service is still running to prevent memory leaks
        if (!(await FlutterBackgroundService().isRunning())) {
          timer.cancel();
          return;
        }

        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            await flutterLocalNotificationsPlugin.show(
              notificationId,
              'AGiXT',
              'Active ${DateTime.now().toString().substring(11, 19)}',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  notificationChannelId,
                  'AGiXT Background Service',
                  icon: 'agixt_logo',
                  ongoing: true,
                  autoCancel: false,
                  playSound: false,
                  enableVibration: false,
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error in background service periodic task: $e');
      }
    });
  } catch (e) {
    debugPrint('Critical error in background service onStart: $e');
  }
}

void startBackgroundService() {
  final service = FlutterBackgroundService();
  service.startService();
}

void stopBackgroundService() {
  final service = FlutterBackgroundService();
  service.invoke("stop");
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('notificationTapBackground: $notificationResponse');
  if (notificationResponse.actionId == null) {
    return;
  }

  if (notificationResponse.actionId!.startsWith("delete_")) {
    _handleDeleteAction(notificationResponse.actionId!);
  }

  // handle action
}

void _handleDeleteAction(String actionId) async {
  if (actionId.startsWith("delete_")) {
    final id = actionId.split("_")[1];
    try {
      // Ensure box is open
      if (!Hive.isBoxOpen('agixtStopBox')) {
        await Hive.openLazyBox<AGiXTStopItem>('agixtStopBox');
      }

      final box = Hive.lazyBox<AGiXTStopItem>('agixtStopBox');
      debugPrint('Deleting item with id: $id');

      for (var i = 0; i < box.length; i++) {
        try {
          final item = await box.getAt(i);
          if (item?.uuid == id) {
            debugPrint('Deleting item at index: $i');
            await box.deleteAt(i);
            await box.flush();
            break;
          }
        } catch (e) {
          debugPrint('Error processing item at index $i: $e');
        }
      }

      try {
        StopsManager().reload();
      } catch (e) {
        debugPrint('Error reloading StopsManager: $e');
      }
    } catch (e) {
      debugPrint('Error in _handleDeleteAction: $e');
    }
  }
}
