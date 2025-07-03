import 'dart:async';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/services/bluetooth_reciever.dart';
import 'package:agixt/utils/battery_optimization_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BluetoothBackgroundService {
  static const String _channelId = 'bluetooth_background_service';
  static const int _notificationId = 999;

  static Timer? _heartbeatTimer;
  static Timer? _connectionMonitorTimer;
  static BluetoothManager? _bluetoothManager;
  static BluetoothReciever? _bluetoothReceiver;
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
      importance: Importance
          .high, // Changed from low to high for better background processing
      playSound: false,
      enableVibration: false,
      showBadge: false,
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
    // Check if already running to prevent multiple instances
    if (await isRunning()) {
      debugPrint(
          'BluetoothBackgroundService: Service already running, ignoring start request');
      return;
    }

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

    // Prevent multiple instances
    if (_isRunning) {
      debugPrint(
          'BluetoothBackgroundService: Service already running, ignoring start');
      return;
    }

    _isRunning = true;

    // Initialize Bluetooth Manager and Receiver with error handling
    try {
      _bluetoothManager = BluetoothManager.singleton;
      await _bluetoothManager!.initialize();

      // Initialize Bluetooth Receiver to handle voice commands
      _bluetoothReceiver = BluetoothReciever.singleton;

      // Try to reconnect to previously connected glasses
      await _bluetoothManager!.attemptReconnectFromStorage();

      // Set external heartbeat management to prevent duplicate heartbeats
      _bluetoothManager!.setExternalHeartbeatManaged(true);
    } catch (e) {
      debugPrint(
          'BluetoothBackgroundService: Failed to initialize or reconnect: $e');
      _isRunning = false;
      service.stopSelf();
      return;
    }

    // Start heartbeat timer - send every 28 seconds as per protocol
    _startHeartbeatTimer();

    // Start connection monitoring timer - check every 60 seconds
    _startConnectionMonitorTimer();

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

      try {
        await _updateNotification(service);
      } catch (e) {
        debugPrint(
            'BluetoothBackgroundService: Error updating notification: $e');
      }
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
        // Don't attempt reconnect on every heartbeat failure to avoid cascade
        // Only try reconnect on connection monitor
      }
    });
  }

  static Future<void> _sendHeartbeat() async {
    try {
      if (_bluetoothManager?.leftGlass?.isConnected == true) {
        await _bluetoothManager!.leftGlass!.sendHeartbeat();
      }

      if (_bluetoothManager?.rightGlass?.isConnected == true) {
        await _bluetoothManager!.rightGlass!.sendHeartbeat();
      }

      debugPrint('BluetoothBackgroundService: Heartbeat sent');
    } catch (e) {
      debugPrint('BluetoothBackgroundService: Error sending heartbeat: $e');
    }
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

  static void _startConnectionMonitorTimer() {
    _connectionMonitorTimer?.cancel();

    // Monitor connection every 60 seconds and attempt reconnection if needed
    _connectionMonitorTimer =
        Timer.periodic(const Duration(seconds: 60), (timer) async {
      if (!_isRunning || _bluetoothManager == null) {
        timer.cancel();
        return;
      }

      try {
        final isConnected = _bluetoothManager!.isConnected;
        if (!isConnected) {
          debugPrint(
              'BluetoothBackgroundService: Connection lost, attempting reconnect...');
          await _attemptReconnect();
        } else {
          debugPrint('BluetoothBackgroundService: Connection status OK');
        }
      } catch (e) {
        debugPrint('BluetoothBackgroundService: Connection monitor error: $e');
      }
    });
  }

  static Future<void> _updateNotification(ServiceInstance service) async {
    try {
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
                'AGiXT Glasses Connection',
                icon: 'branding',
                ongoing: true,
                importance: Importance.high, // Changed from low to high
                priority: Priority.high, // Changed from low to high
                category: AndroidNotificationCategory.service,
                showWhen: true,
                usesChronometer: false,
                playSound: false,
                enableVibration: false,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint(
          'BluetoothBackgroundService: Error in _updateNotification: $e');
    }
  }

  static void _stopService() {
    debugPrint('BluetoothBackgroundService: Stopping service');
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;

    // Re-enable internal heartbeat management
    if (_bluetoothManager != null) {
      _bluetoothManager!.setExternalHeartbeatManaged(false);
    }

    // Clean up Bluetooth receiver
    _bluetoothReceiver?.dispose();
    _bluetoothReceiver = null;
  }

  /// Request battery optimization exemption for better background performance
  static Future<void> requestBatteryOptimizationExemption() async {
    // This will help the app stay active in the background
    try {
      final isDisabled =
          await BatteryOptimizationHelper.isBatteryOptimizationDisabled();
      if (!isDisabled) {
        debugPrint(
            'BluetoothBackgroundService: Battery optimization is enabled, performance may be limited');
        debugPrint(
            'BluetoothBackgroundService: ${BatteryOptimizationHelper.getBatteryOptimizationExplanation()}');
      } else {
        debugPrint(
            'BluetoothBackgroundService: Battery optimization is disabled, good for background performance');
      }
    } catch (e) {
      debugPrint(
          'BluetoothBackgroundService: Error checking battery optimization: $e');
    }
  }
}
