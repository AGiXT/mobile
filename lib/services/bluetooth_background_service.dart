import 'dart:async';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BluetoothBackgroundService {
  static const String _channelId = 'bluetooth_background_service';
  static const int _notificationId = 999;

  static Timer? _heartbeatTimer;
  static BluetoothManager? _bluetoothManager;
  static bool _isRunning = false;

  /// Initialize and start the background service
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Create notification channel for Android
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      'AGiXT Glasses Connection',
      description: 'Maintains connection to your glasses in the background',
      importance: Importance.low,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'AGiXT Glasses Connection',
        initialNotificationContent: 'Maintaining connection to glasses...',
        foregroundServiceNotificationId: _notificationId,
        autoStartOnBoot: true,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Start the background service
  static Future<void> start() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  /// Stop the background service
  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke("stop");
    _heartbeatTimer?.cancel();
    _isRunning = false;
  }

  /// Check if the service is running
  static Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    debugPrint('BluetoothBackgroundService: Starting background service');

    _isRunning = true;

    // Initialize Bluetooth Manager
    _bluetoothManager = BluetoothManager.singleton;
    await _bluetoothManager!.initialize();

    // Try to reconnect to previously connected glasses
    try {
      await _bluetoothManager!.attemptReconnectFromStorage();

      // Set external heartbeat management to prevent duplicate heartbeats
      _bluetoothManager!.setExternalHeartbeatManaged(true);
    } catch (e) {
      debugPrint(
          'BluetoothBackgroundService: Failed to reconnect from storage: $e');
    }

    // Start heartbeat timer - send every 28 seconds as per protocol
    _startHeartbeatTimer();

    // Listen for service stop
    service.on('stop').listen((event) {
      debugPrint('BluetoothBackgroundService: Received stop command');
      _stopService();
      service.stopSelf();
    });

    // Update notification every 60 seconds to show connection status
    Timer.periodic(const Duration(seconds: 60), (timer) async {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      await _updateNotification(service);
    });

    debugPrint(
        'BluetoothBackgroundService: Background service started successfully');
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    debugPrint('BluetoothBackgroundService: iOS background mode');
    return true;
  }

  static void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();

    // Send heartbeat every 28 seconds (protocol says disconnection happens after 32 seconds)
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 28), (timer) async {
      if (!_isRunning || _bluetoothManager == null) {
        timer.cancel();
        return;
      }

      try {
        await _sendHeartbeat();
      } catch (e) {
        debugPrint('BluetoothBackgroundService: Heartbeat failed: $e');
        // Try to reconnect if heartbeat fails
        await _attemptReconnect();
      }
    });
  }

  static Future<void> _sendHeartbeat() async {
    if (_bluetoothManager?.leftGlass?.isConnected == true) {
      await _bluetoothManager!.leftGlass!.sendHeartbeat();
    }

    if (_bluetoothManager?.rightGlass?.isConnected == true) {
      await _bluetoothManager!.rightGlass!.sendHeartbeat();
    }

    debugPrint('BluetoothBackgroundService: Heartbeat sent');
  }

  static Future<void> _attemptReconnect() async {
    debugPrint('BluetoothBackgroundService: Attempting to reconnect...');

    try {
      if (_bluetoothManager == null) {
        _bluetoothManager = BluetoothManager.singleton;
        await _bluetoothManager!.initialize();
      }

      await _bluetoothManager!.attemptReconnectFromStorage();

      // Re-enable external heartbeat management
      _bluetoothManager!.setExternalHeartbeatManaged(true);
    } catch (e) {
      debugPrint('BluetoothBackgroundService: Reconnection failed: $e');
    }
  }

  static Future<void> _updateNotification(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        final isConnected = _bluetoothManager?.isConnected ?? false;
        final leftConnected =
            _bluetoothManager?.leftGlass?.isConnected ?? false;
        final rightConnected =
            _bluetoothManager?.rightGlass?.isConnected ?? false;

        String status;
        if (isConnected) {
          status = 'Connected to glasses';
        } else if (leftConnected || rightConnected) {
          status =
              'Partially connected (${leftConnected ? 'L' : ''}${rightConnected ? 'R' : ''})';
        } else {
          status = 'Disconnected - trying to reconnect...';
        }

        final flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
        await flutterLocalNotificationsPlugin.show(
          _notificationId,
          'AGiXT Glasses Connection',
          status,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Bluetooth Background Service',
              icon: 'branding',
              ongoing: true,
              importance: Importance.low,
              priority: Priority.low,
            ),
          ),
        );
      }
    }
  }

  static void _stopService() {
    debugPrint('BluetoothBackgroundService: Stopping service');
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    // Re-enable internal heartbeat management
    if (_bluetoothManager != null) {
      _bluetoothManager!.setExternalHeartbeatManaged(false);
    }
  }
}
