import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/agixt/calendar.dart';
import 'package:agixt/models/agixt/checklist.dart';
import 'package:agixt/models/agixt/daily.dart';
import 'package:agixt/models/agixt/stop.dart';
import 'package:agixt/screens/auth/login_screen.dart';
import 'package:agixt/screens/auth/profile_screen.dart';
import 'package:agixt/services/ai_service.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/services/stops_manager.dart';
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
const String APP_NAME = String.fromEnvironment('APP_NAME', defaultValue: 'AGiXT');
const String AGIXT_SERVER = String.fromEnvironment('AGIXT_SERVER', defaultValue: 'https://api.agixt.dev');
const String APP_URI = String.fromEnvironment('APP_URI', defaultValue: 'https://agixt.dev');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AuthService with environment variables
  AuthService.init(
    serverUrl: AGIXT_SERVER,
    appUri: APP_URI,
    appName: APP_NAME,
  );

  flutterLocalNotificationsPlugin.initialize(
    InitializationSettings(
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

  await _initHive();
  await initializeService();
  await UiPerfs.singleton.load();

  await BluetoothManager.singleton.initialize();
  BluetoothManager.singleton.attemptReconnectFromStorage();
  

  var channel = const MethodChannel('dev.agixt.agixt/background_service');
  var callbackHandle = PluginUtilities.getCallbackHandle(backgroundMain);
  channel.invokeMethod('startService', callbackHandle?.toRawHandle());

  runApp(const App());
}

void backgroundMain() {
  WidgetsFlutterBinding.ensureInitialized();
}

class AppRetainWidget extends StatelessWidget {
  AppRetainWidget({super.key, required this.child});

  final Widget child;

  final _channel = const MethodChannel('dev.agixt.agixt/app_retain');

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (Platform.isAndroid) {
          if (Navigator.of(context).canPop()) {
            return true;
          } else {
            _channel.invokeMethod('sendToBackground');
            return false;
          }
        } else {
          return true;
        }
      },
      child: child,
    );
  }
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  StreamSubscription? _deepLinkSubscription;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _initDeepLinkHandling();
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinkHandling() async {
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
    _deepLinkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri.toString());
    }, onError: (error) {
      debugPrint('Error handling deep link: $error');
    });
    
    // Set up the method channel for OAuth callback from native code
    const platform = MethodChannel('dev.agixt.agixt/oauth_callback');
    platform.setMethodCallHandler((call) async {
      if (call.method == 'handleOAuthCallback') {
        final args = call.arguments as Map;
        final token = args['token'] as String?;
        
        if (token != null && token.isNotEmpty) {
          debugPrint('Received JWT token via method channel from native code');
          await _processJwtToken(token);
        }
      } else if (call.method == 'checkPendingToken') {
        // This method is called by Flutter to check if there's a pending token
        // No action needed here as we already handle this in native code
        return null;
      }
      return null;
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
    // First store the JWT token
    await AuthService.storeJwt(token);
    
    try {
      // Validate the token by making a request to the server
      final response = await http.get(
        Uri.parse('${AuthService.serverUrl}/v1/user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );
      
      debugPrint('Token validation status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Token is valid, proceed to home screen
        final userData = jsonDecode(response.body);
        
        // Store user email if available
        if (userData != null && userData['email'] != null) {
          await AuthService.storeEmail(userData['email']);
        }
        
        setState(() {
          _isLoggedIn = true;
          _isLoading = false;
        });
        
        // If we're already showing the login screen, navigate to home
        if (!_isLoggedIn && mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else if (response.statusCode == 402) {
        // Payment required, open subscription page
        final Uri subscriptionUrl = Uri.parse('${AuthService.appUri}/user');
        if (await canLaunchUrl(subscriptionUrl)) {
          await launchUrl(subscriptionUrl, mode: LaunchMode.externalApplication);
        }
        
        // User is considered logged in, but needs to handle subscription
        setState(() {
          _isLoggedIn = true;
          _isLoading = false;
        });
      } else {
        // Invalid login - clear the stored token
        debugPrint('Invalid token, logging out');
        await AuthService.logout();
        
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
        
        // Show an error message if we're on the login screen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid login. Please try again.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error validating token: $e');
      // Keep the token stored but don't navigate yet
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: APP_NAME,
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
      home: _isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : AppRetainWidget(
              child: _isLoggedIn ? const HomePage() : const LoginScreen(),
            ),
      // Note: We're using HomePage which already has Gravatar implementation in the app bar
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

Future<void> _initHive() async {
  Hive.registerAdapter(AGiXTDailyItemAdapter());
  Hive.registerAdapter(AGiXTStopItemAdapter());
  Hive.registerAdapter(AGiXTCalendarAdapter());
  Hive.registerAdapter(AGiXTCheckListItemAdapter());
  Hive.registerAdapter(AGiXTChecklistAdapter());
  await Hive.initFlutter();
}

// this will be used as notification channel id
const notificationChannelId = 'my_foreground';

// this will be used for notification id, So you can update your custom notification with this id.
const notificationId = 888;

Future<void> initializeService() async {
  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId, // id
    'AGiXT', // title
    description:
        'This channel is used for AGiXT notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
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
  // Only available for flutter 3.0.0 and later
  //DartPluginRegistrant.ensureInitialized();

  // try {
  //   await Hive.initFlutter();
  //   _initHive();
  // } catch (e) {
  //   debugPrint('Hive already initialized');
  // }

  // if (!Hive.isBoxOpen('agixtDailyBox')) {
  //   await Hive.openBox<AGiXTDailyItem>('agixtDailyBox');
  // }
  // if (!Hive.isBoxOpen('agixtStopBox')) {
  //   await Hive.openLazyBox<AGiXTStopItem>('agixtStopBox');
  // }

  // final bt =
  //     BluetoothManager.singleton; // initialize bluetooth manager singleton
  // await bt.initialize();
  // if (!bt.isConnected) {
  //   bt.attemptReconnectFromStorage();
  // }
  // bring to foreground
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        flutterLocalNotificationsPlugin.show(
          notificationId,
          'AGiXT',
          'Awesome ${DateTime.now()}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannelId,
              'MY FOREGROUND SERVICE',
              icon: 'branding',
              ongoing: true,
            ),
          ),
        );
      }
    }
  });
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
      await Hive.openBox<AGiXTStopItem>('agixtStopBox');
    } catch (e) {
      debugPrint('Hive box already open');
    }
    final box = Hive.lazyBox<AGiXTStopItem>('agixtStopBox');
    debugPrint('Deleting item with id: $id');
    for (var i = 0; i < box.length; i++) {
      final item = await box.getAt(i);
      if (item!.uuid == id) {
        debugPrint('Deleting item: $i');
        await box.deleteAt(i);
        await box.flush();
        break;
      }
    }
    StopsManager().reload();
  }
}
