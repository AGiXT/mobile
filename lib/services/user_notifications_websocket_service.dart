import 'dart:async';
import 'dart:convert';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/services/websocket_service.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// WebSocket service for user-level notifications (not conversation-specific)
/// Handles system notifications, conversation events, etc.
class UserNotificationsWebSocketService {
  static final UserNotificationsWebSocketService _instance =
      UserNotificationsWebSocketService._internal();
  factory UserNotificationsWebSocketService() => _instance;
  UserNotificationsWebSocketService._internal();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isIntentionalDisconnect = false;

  // Configuration
  static const int heartbeatInterval = 30000; // 30 seconds
  static const int heartbeatTimeout = 10000; // 10 seconds
  static const int reconnectBaseDelay = 1000; // 1 second
  static const int reconnectMaxDelay = 30000; // 30 seconds
  static const int maxReconnectAttempts = 10;

  // Stream controllers
  final StreamController<SystemNotification> _systemNotificationController =
      StreamController<SystemNotification>.broadcast();
  final StreamController<Map<String, dynamic>> _conversationEventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();

  // Public streams
  Stream<SystemNotification> get systemNotificationStream =>
      _systemNotificationController.stream;
  Stream<Map<String, dynamic>> get conversationEventStream =>
      _conversationEventController.stream;
  Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream;

  String _connectionStatus = 'disconnected';
  String get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == 'connected';

  /// Connect to the user notifications WebSocket
  Future<bool> connect() async {
    try {
      final jwt = await AuthService.getJwt();
      if (jwt == null) {
        debugPrint('UserNotificationsWS: No JWT available');
        return false;
      }

      _isIntentionalDisconnect = false;

      // Disconnect any existing connection
      await disconnect(intentional: false);

      _setConnectionStatus('connecting');

      // Build WebSocket URL
      final serverUrl = AuthService.serverUrl;
      final protocol = serverUrl.startsWith('https') ? 'wss' : 'ws';
      final baseUrl = serverUrl
          .replaceFirst('http://', '')
          .replaceFirst('https://', '');
      final wsUrl =
          '$protocol://$baseUrl/v1/user/notifications?authorization=${Uri.encodeComponent(jwt)}';

      debugPrint('UserNotificationsWS: Connecting to $wsUrl');

      // Connect
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      _setConnectionStatus('connected');
      _startHeartbeat();
      _reconnectAttempts = 0;

      debugPrint('UserNotificationsWS: Connected successfully');
      return true;
    } catch (e) {
      debugPrint('UserNotificationsWS: Connection error: $e');
      _setConnectionStatus('error');
      _scheduleReconnect();
      return false;
    }
  }

  /// Disconnect from the WebSocket
  Future<void> disconnect({bool intentional = true}) async {
    _isIntentionalDisconnect = intentional;
    _stopHeartbeat();
    _cancelReconnect();

    if (_channel != null) {
      try {
        await _channel!.sink.close(ws_status.normalClosure);
      } catch (e) {
        debugPrint('UserNotificationsWS: Error closing channel: $e');
      }
      _channel = null;
    }

    if (intentional) {
      _setConnectionStatus('disconnected');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      debugPrint('UserNotificationsWS: Received message type: $type');

      switch (type) {
        case 'system_notification':
          _handleSystemNotification(data);
          break;
        case 'conversation_created':
        case 'conversation_deleted':
        case 'conversation_renamed':
        case 'message_added':
          _conversationEventController.add(data);
          break;
        case 'pong':
          _handlePong();
          break;
        case 'heartbeat':
        case 'connected':
          // Ignore these
          break;
        case 'error':
          debugPrint('UserNotificationsWS: Server error: ${data['message']}');
          break;
        default:
          debugPrint('UserNotificationsWS: Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('UserNotificationsWS: Error parsing message: $e');
    }
  }

  void _handleSystemNotification(Map<String, dynamic> data) {
    final notification = SystemNotification.fromJson(data);
    debugPrint(
      'UserNotificationsWS: System notification: ${notification.title}',
    );
    _systemNotificationController.add(notification);
  }

  void _handlePong() {
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
  }

  void _handleError(dynamic error) {
    debugPrint('UserNotificationsWS: WebSocket error: $error');
    _setConnectionStatus('error');
  }

  void _handleDone() {
    _stopHeartbeat();
    _channel = null;

    if (_isIntentionalDisconnect) {
      _setConnectionStatus('disconnected');
    } else {
      _scheduleReconnect();
    }
  }

  void _setConnectionStatus(String status) {
    _connectionStatus = status;
    _connectionStatusController.add(status);
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(milliseconds: heartbeatInterval),
      (_) {
        if (_channel != null && _connectionStatus == 'connected') {
          try {
            _channel!.sink.add(jsonEncode({'type': 'ping'}));
            _heartbeatTimeoutTimer = Timer(
              const Duration(milliseconds: heartbeatTimeout),
              () {
                debugPrint('UserNotificationsWS: Heartbeat timeout');
                _channel?.sink.close();
              },
            );
          } catch (e) {
            debugPrint('UserNotificationsWS: Error sending heartbeat: $e');
          }
        }
      },
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
  }

  void _scheduleReconnect() {
    if (_isIntentionalDisconnect) return;

    _reconnectAttempts++;
    if (_reconnectAttempts > maxReconnectAttempts) {
      _setConnectionStatus('error');
      debugPrint('UserNotificationsWS: Max reconnect attempts reached');
      return;
    }

    final delay = (reconnectBaseDelay * (1 << (_reconnectAttempts - 1))).clamp(
      reconnectBaseDelay,
      reconnectMaxDelay,
    );

    _setConnectionStatus('reconnecting');
    debugPrint('UserNotificationsWS: Reconnecting in ${delay}ms');

    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      connect();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Dispose of resources
  void dispose() {
    disconnect();
    _systemNotificationController.close();
    _conversationEventController.close();
    _connectionStatusController.close();
  }
}
