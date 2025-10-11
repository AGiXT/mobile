import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/agixt/calendar.dart';
import 'package:agixt/models/agixt/checklist.dart';
import 'package:agixt/models/agixt/daily.dart';
import 'package:agixt/models/agixt/stop.dart';
import 'package:agixt/screens/auth/login_screen.dart';
import 'package:agixt/screens/auth/profile_screen.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/services/bluetooth_background_service.dart';
import 'package:agixt/services/stops_manager.dart';
import 'package:agixt/services/permission_manager.dart';
import 'package:agixt/services/wallet_adapter_service.dart';
import 'package:agixt/utils/ui_perfs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:app_links/app_links.dart';
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
  defaultValue: 'https://agixt.dev',
);

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize AuthService with environment variables
    AuthService.init(
      serverUrl: AGIXT_SERVER,
      appUri: APP_URI,
      appName: APP_NAME,
    );

    try {
      await WalletAdapterService.initialize(appUri: APP_URI, appName: APP_NAME);
    } catch (e) {
      debugPrint('Failed to initialize wallet adapter service: $e');
    }

    // Initialize notifications with error handling
    try {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('branding'),
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

    // Start services with error handling and delay to prevent conflicts
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      await BluetoothBackgroundService.start();
    } catch (e) {
      debugPrint('Failed to start BluetoothBackgroundService: $e');
    }

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

    // Start the app first, then request permissions asynchronously
    runApp(const AGiXTApp());

    // Request permissions after the app has started to avoid freezing
    _requestPermissionsAsync();
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

/// Request permissions asynchronously after app startup to prevent UI freezing
void _requestPermissionsAsync() {
  Future.delayed(const Duration(milliseconds: 1000), () async {
    try {
      debugPrint('Starting async permission requests...');
      final permissionsGranted =
          await PermissionManager.initializePermissions();
      if (!permissionsGranted) {
        debugPrint(
          'Some critical permissions were denied, app may have limited functionality',
        );
      } else {
        debugPrint('All critical permissions granted successfully');
      }
    } catch (e) {
      debugPrint('Failed to initialize permissions asynchronously: $e');
    }
  });
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

class AGiXTApp extends StatefulWidget {
  const AGiXTApp({super.key});

  // Global navigator key for accessing context from anywhere
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<AGiXTApp> createState() => _AGiXTAppState();
}

class _AGiXTAppState extends State<AGiXTApp> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  StreamSubscription? _deepLinkSubscription;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();

    // Initialize with proper error handling
    _safeInitialization();
  }

  Future<void> _safeInitialization() async {
    try {
      await _checkLoginStatus();
      await _initDeepLinkHandling();

      // Request permissions after a delay to ensure UI is ready
      _schedulePermissionRequest();
    } catch (e) {
      debugPrint('Error during app state initialization: $e');
      // Set safe defaults
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  void _schedulePermissionRequest() {
    // Schedule permission request after UI is fully loaded
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (mounted) {
        try {
          debugPrint('Requesting permissions after UI initialization...');
          final permissionsGranted =
              await PermissionManager.initializePermissions();
          if (!permissionsGranted) {
            debugPrint('Some critical permissions were denied');
            // Could show a snackbar or dialog here to inform the user
          }
        } catch (e) {
          debugPrint('Error requesting permissions: $e');
        }
      }
    });
  }

  @override
  void dispose() {
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
    } catch (e) {
      debugPrint('Error initializing deep link handling: $e');
    }
  }

  void _handleDeepLink(String link) {
    debugPrint('Received deep link: $link');

    // Handle the agixt://callback URL format with token
    if (link.startsWith('agixt://callback')) {
      Uri uri = Uri.parse(link);
      String? token = uri.queryParameters['token'];

      if (token != null && token.isNotEmpty) {
        debugPrint('Received JWT token from deep link');
        _processJwtToken(token);
      }
    }
  }

  Future<void> _processJwtToken(String token) async {
    try {
      // Validate the token if necessary
      bool isTokenValid = true; // Replace with actual validation if needed

      if (isTokenValid) {
        // Store JWT token and update login state
        await AuthService.storeJwt(token);

        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _isLoading = false;
          });

          // If we're already showing the login screen, navigate to home
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      }
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
        routes: {
          '/home': (context) => const HomePage(),
          '/login': (context) => const LoginScreen(),
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

      return AppRetainWidget(
        child: _isLoggedIn ? const HomePage() : const LoginScreen(),
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
                  icon: 'branding',
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
