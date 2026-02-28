import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:agixt/main.dart' show flutterLocalNotificationsPlugin;
import 'package:agixt/models/g1/notification.dart';
import 'package:agixt/services/bluetooth_manager.dart';

/// Bridges web app in-page notifications (chat messages, mentions, replies)
/// to native push notifications and Even Realities G1 glasses on-lens display.
///
/// The web app running inside the mobile WebView dispatches CustomEvents
/// (`chat:notification`, `channel:notification`). JavaScript injected into
/// the WebView intercepts these events and forwards them through a
/// JavaScriptChannel (`WebNotificationBridge`) to this service.
class WebNotificationBridgeService {
  static final WebNotificationBridgeService _instance =
      WebNotificationBridgeService._internal();
  factory WebNotificationBridgeService() => _instance;
  WebNotificationBridgeService._internal();

  bool _isInitialized = false;

  // Notification channel for web-bridged chat notifications
  static const AndroidNotificationChannel chatChannel =
      AndroidNotificationChannel(
    'web_chat_notifications',
    'Chat Notifications',
    description: 'Messages, mentions, and replies from conversations',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  // Notification channel for web-bridged mention/reply notifications
  static const AndroidNotificationChannel mentionChannel =
      AndroidNotificationChannel(
    'web_mention_notifications',
    'Mentions & Replies',
    description: 'When someone mentions you or replies to your message',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
  );

  // Track recently shown notifications to avoid duplicates between
  // the native UserNotificationsWebSocketService and this bridge.
  final Set<String> _recentNotificationIds = {};
  static const int _maxTrackedIds = 200;

  /// Initialize notification channels. Call once at app startup.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(chatChannel);
        await androidPlugin.createNotificationChannel(mentionChannel);
      }

      _isInitialized = true;
      debugPrint('WebNotificationBridgeService: Initialized');
    } catch (e) {
      debugPrint('WebNotificationBridgeService: Failed to initialize: $e');
    }
  }

  /// Handle an incoming message from the WebView JavaScript bridge.
  /// Called by the `WebNotificationBridge` JavaScriptChannel handler.
  Future<void> handleBridgeMessage(String rawMessage) async {
    try {
      final data = jsonDecode(rawMessage) as Map<String, dynamic>;
      final eventType = data['event'] as String?;

      switch (eventType) {
        case 'chat:notification':
          await _handleChatNotification(data['detail'] as Map<String, dynamic>);
          break;
        case 'system_notification':
          // System notifications are already handled by SystemNotificationService
          // via the native WebSocket, so we skip them here to avoid duplicates.
          debugPrint(
              'WebNotificationBridge: Ignoring system_notification (handled natively)');
          break;
        default:
          debugPrint(
              'WebNotificationBridge: Unknown event type: $eventType');
      }
    } catch (e) {
      debugPrint('WebNotificationBridge: Error handling message: $e');
    }
  }

  /// Process a chat:notification event from the web app.
  /// These include new messages, @mentions, and replies.
  Future<void> _handleChatNotification(Map<String, dynamic> detail) async {
    final notifType = detail['type'] as String? ?? 'message';
    final conversationName = detail['conversationName'] as String? ?? '';
    final senderName = detail['senderName'] as String? ?? 'Someone';
    final messagePreview = detail['messagePreview'] as String? ?? '';
    final notifId = detail['id'] as String? ?? '';

    // Deduplicate — the native UserNotificationsWebSocketService may
    // have already triggered a push for the same underlying event
    if (notifId.isNotEmpty) {
      if (_recentNotificationIds.contains(notifId)) {
        debugPrint('WebNotificationBridge: Duplicate suppressed: $notifId');
        return;
      }
      _trackNotificationId(notifId);
    }

    debugPrint(
        'WebNotificationBridge: chat:notification type=$notifType conversation=$conversationName sender=$senderName');

    // Build human-readable title & body
    String title;
    String body;
    switch (notifType) {
      case 'mention':
        title = '@$senderName mentioned you';
        body = conversationName.isNotEmpty
            ? '$conversationName: $messagePreview'
            : messagePreview;
        break;
      case 'reply':
        title = '$senderName replied';
        body = conversationName.isNotEmpty
            ? '$conversationName: $messagePreview'
            : messagePreview;
        break;
      default: // 'message'
        title = conversationName.isNotEmpty ? conversationName : senderName;
        body = messagePreview.isNotEmpty
            ? '$senderName: $messagePreview'
            : 'New message';
        break;
    }

    // 1) Show native push notification
    await _showPushNotification(
      id: notifId,
      title: title,
      body: body,
      type: notifType,
    );

    // 2) Forward to glasses as on-lens notification
    await _sendToGlasses(
      title: title,
      body: body,
      type: notifType,
      appIdentifier: 'dev.agixt.agixt',
    );
  }

  /// Show a local push notification on the device.
  Future<void> _showPushNotification({
    required String id,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final isMention = type == 'mention' || type == 'reply';
      final channel = isMention ? mentionChannel : chatChannel;

      final androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: isMention ? Importance.max : Importance.high,
        priority: isMention ? Priority.max : Priority.high,
        icon: 'agixt_logo',
        color: isMention
            ? const Color(0xFFF59E0B) // amber for mentions
            : const Color(0xFF3B82F6), // blue for messages
        category: AndroidNotificationCategory.message,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        // Group by conversation to collapse multiple messages
        groupKey: 'web_chat_$type',
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isMention
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        id.hashCode,
        title,
        body,
        details,
        payload: id,
      );
    } catch (e) {
      debugPrint('WebNotificationBridge: Error showing push notification: $e');
    }
  }

  /// Send a notification to Even Realities G1 glasses via BLE.
  Future<void> _sendToGlasses({
    required String title,
    required String body,
    required String type,
    required String appIdentifier,
  }) async {
    try {
      final bluetoothManager = BluetoothManager();

      if (!bluetoothManager.isConnected) {
        return; // No glasses connected, skip silently
      }

      final ncsNotification = NCSNotification(
        msgId: DateTime.now().millisecondsSinceEpoch,
        action: 0,
        type: 0,
        appIdentifier: appIdentifier,
        title: title,
        subtitle: type == 'mention'
            ? 'Mention'
            : type == 'reply'
                ? 'Reply'
                : '',
        message: body,
        displayName: 'AGiXT',
      );

      await bluetoothManager.sendNotification(ncsNotification);
      debugPrint('WebNotificationBridge: Sent to glasses: $title');
    } catch (e) {
      debugPrint('WebNotificationBridge: Error sending to glasses: $e');
    }
  }

  /// Track a notification ID for deduplication.
  void _trackNotificationId(String id) {
    _recentNotificationIds.add(id);
    // Evict oldest entries if the set grows too large
    if (_recentNotificationIds.length > _maxTrackedIds) {
      _recentNotificationIds.remove(_recentNotificationIds.first);
    }
  }

  /// Mark a notification ID as already handled (e.g., from the native WS).
  /// Other services can call this to prevent the bridge from duplicating.
  void markAsHandled(String id) {
    _trackNotificationId(id);
  }
}

/// The JavaScript code to inject into the WebView to intercept web app
/// notifications and forward them to the native bridge.
///
/// Listens for:
///   - `chat:notification`  → messages, mentions, replies
///
/// System notifications are intentionally NOT bridged here because the
/// mobile app already handles them through its own native WebSocket
/// connection via [SystemNotificationService].
const String webNotificationBridgeScript = '''
(function() {
  if (window._webNotificationBridgeSetup) return;

  // Intercept chat:notification events (messages, mentions, replies)
  window.addEventListener('chat:notification', function(e) {
    try {
      if (typeof WebNotificationBridge !== 'undefined') {
        WebNotificationBridge.postMessage(JSON.stringify({
          event: 'chat:notification',
          detail: e.detail
        }));
      }
    } catch (err) {
      console.error('[WebNotificationBridge] Error forwarding chat notification:', err);
    }
  });

  // Also intercept the browser Notification API so web-generated
  // notifications go through the native bridge instead of silently
  // failing inside a WebView (WebViews don't support the Notification API).
  if (typeof Notification !== 'undefined') {
    const OriginalNotification = Notification;
    window.Notification = function(title, options) {
      try {
        if (typeof WebNotificationBridge !== 'undefined') {
          WebNotificationBridge.postMessage(JSON.stringify({
            event: 'chat:notification',
            detail: {
              id: (options && options.tag) || ('browser-notif-' + Date.now()),
              type: 'message',
              conversationId: '',
              conversationName: title || '',
              messagePreview: (options && options.body) || '',
              senderName: '',
              senderUserId: '',
              timestamp: new Date().toISOString(),
              read: false
            }
          }));
        }
      } catch (err) {
        console.error('[WebNotificationBridge] Error intercepting Notification API:', err);
      }
    };
    // Preserve static properties
    window.Notification.permission = OriginalNotification.permission || 'granted';
    window.Notification.requestPermission = function(cb) {
      // Always report granted inside our WebView
      if (cb) cb('granted');
      return Promise.resolve('granted');
    };
  }

  window._webNotificationBridgeSetup = true;
  console.log('[WebNotificationBridge] Notification bridge initialized');
})();
''';
