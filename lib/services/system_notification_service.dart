import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:agixt/services/websocket_service.dart';
import 'package:agixt/services/user_notifications_websocket_service.dart';
import 'package:agixt/main.dart' show flutterLocalNotificationsPlugin;

/// Service to handle system-wide notifications from server admins
/// Shows local push notifications when system notifications are received
class SystemNotificationService {
  static final SystemNotificationService _instance =
      SystemNotificationService._internal();
  factory SystemNotificationService() => _instance;
  SystemNotificationService._internal();

  StreamSubscription<SystemNotification>? _subscription;
  bool _isInitialized = false;

  // Notification channel for system notifications
  static const AndroidNotificationChannel systemChannel =
      AndroidNotificationChannel(
        'system_notifications',
        'System Notifications',
        description: 'Server-wide announcements and alerts from administrators',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

  /// Initialize the service and start listening for system notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create the notification channel on Android
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(systemChannel);

      // Connect to user notifications WebSocket
      final userNotificationsWs = UserNotificationsWebSocketService();
      await userNotificationsWs.connect();

      // Listen for system notifications from the user notifications WebSocket
      _subscription = userNotificationsWs.systemNotificationStream.listen(
        _handleSystemNotification,
        onError: (e) => debugPrint('SystemNotificationService error: $e'),
      );

      _isInitialized = true;
      debugPrint('SystemNotificationService: Initialized');
    } catch (e) {
      debugPrint('SystemNotificationService: Failed to initialize: $e');
    }
  }

  /// Stop listening for notifications
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
  }

  /// Handle incoming system notification
  Future<void> _handleSystemNotification(
    SystemNotification notification,
  ) async {
    debugPrint(
      'SystemNotificationService: Showing notification: ${notification.title}',
    );

    // Determine notification priority based on type
    final priority = _getPriority(notification.notificationType);
    final importance = _getImportance(notification.notificationType);

    // Build the notification
    final androidDetails = AndroidNotificationDetails(
      systemChannel.id,
      systemChannel.name,
      channelDescription: systemChannel.description,
      importance: importance,
      priority: priority,
      icon: 'agixt_logo',
      color: _getColor(notification.notificationType),
      category: AndroidNotificationCategory.message,
      // Show timestamp
      showWhen: true,
      when: notification.timestamp.millisecondsSinceEpoch,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: _getInterruptionLevel(notification.notificationType),
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show the notification
    await flutterLocalNotificationsPlugin.show(
      notification.id.hashCode, // Use hash of ID as notification ID
      notification.title,
      notification.message,
      details,
      payload: notification.id, // Store notification ID for dismiss handling
    );
  }

  Priority _getPriority(String type) {
    switch (type) {
      case 'critical':
        return Priority.max;
      case 'warning':
        return Priority.high;
      default:
        return Priority.defaultPriority;
    }
  }

  Importance _getImportance(String type) {
    switch (type) {
      case 'critical':
        return Importance.max;
      case 'warning':
        return Importance.high;
      default:
        return Importance.defaultImportance;
    }
  }

  int _getColor(String type) {
    switch (type) {
      case 'critical':
        return 0xFFEF4444; // Red
      case 'warning':
        return 0xFFF59E0B; // Yellow/Orange
      default:
        return 0xFF3B82F6; // Blue
    }
  }

  InterruptionLevel _getInterruptionLevel(String type) {
    switch (type) {
      case 'critical':
        return InterruptionLevel.critical;
      case 'warning':
        return InterruptionLevel.timeSensitive;
      default:
        return InterruptionLevel.active;
    }
  }
}
