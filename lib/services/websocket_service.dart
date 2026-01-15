import 'dart:async';
import 'dart:convert';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/services/cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// Message received from the AGiXT WebSocket
class WebSocketMessage {
  final String? id;
  final String role;
  final String message;
  final DateTime timestamp;
  final String?
  type; // message_added, activity.stream, remote_command.request, etc.
  final Map<String, dynamic>? rawData;

  WebSocketMessage({
    this.id,
    required this.role,
    required this.message,
    required this.timestamp,
    this.type,
    this.rawData,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return WebSocketMessage(
      id: data?['id'] ?? json['id'],
      role: data?['role'] ?? json['role'] ?? 'assistant',
      message: data?['message'] ?? json['message'] ?? '',
      timestamp:
          DateTime.tryParse(data?['timestamp'] ?? json['timestamp'] ?? '') ??
          DateTime.now(),
      type: json['type'],
      rawData: json,
    );
  }
}

/// System notification from server admin
class SystemNotification {
  final String id;
  final String title;
  final String message;
  final String notificationType; // info, warning, critical
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime timestamp;

  SystemNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.expiresAt,
    required this.createdAt,
    required this.timestamp,
  });

  factory SystemNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return SystemNotification(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      notificationType: data['notification_type'] ?? 'info',
      expiresAt: DateTime.tryParse(data['expires_at'] ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      timestamp: DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Activity update from the AGiXT agent
class ActivityUpdate {
  final String type; // thinking, reflection, activity, subactivity, info, error
  final String content;
  final bool isComplete;

  ActivityUpdate({
    required this.type,
    required this.content,
    this.isComplete = false,
  });
}

/// Remote command request from the AGiXT agent
class RemoteCommandRequest {
  final String toolName;
  final Map<String, dynamic> toolArgs;
  final String requestId;

  RemoteCommandRequest({
    required this.toolName,
    required this.toolArgs,
    required this.requestId,
  });

  factory RemoteCommandRequest.fromJson(Map<String, dynamic> json) {
    return RemoteCommandRequest(
      toolName: json['tool_name'] ?? '',
      toolArgs: json['tool_args'] ?? {},
      requestId: json['request_id'] ?? '',
    );
  }
}

/// WebSocket service for real-time AGiXT conversation streaming
class AGiXTWebSocketService {
  static final AGiXTWebSocketService _instance =
      AGiXTWebSocketService._internal();
  factory AGiXTWebSocketService() => _instance;
  AGiXTWebSocketService._internal();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isIntentionalDisconnect = false;
  String? _currentConversationId;

  // Configuration
  static const int heartbeatInterval = 30000; // 30 seconds
  static const int heartbeatTimeout = 10000; // 10 seconds
  static const int reconnectBaseDelay = 1000; // 1 second
  static const int reconnectMaxDelay = 30000; // 30 seconds
  static const int maxReconnectAttempts = 10;

  // Stream controllers
  final StreamController<WebSocketMessage> _messageController =
      StreamController<WebSocketMessage>.broadcast();
  final StreamController<ActivityUpdate> _activityController =
      StreamController<ActivityUpdate>.broadcast();
  final StreamController<RemoteCommandRequest> _commandController =
      StreamController<RemoteCommandRequest>.broadcast();
  final StreamController<SystemNotification> _systemNotificationController =
      StreamController<SystemNotification>.broadcast();
  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();

  // Public streams
  Stream<WebSocketMessage> get messageStream => _messageController.stream;
  Stream<ActivityUpdate> get activityStream => _activityController.stream;
  Stream<RemoteCommandRequest> get commandStream => _commandController.stream;
  Stream<SystemNotification> get systemNotificationStream =>
      _systemNotificationController.stream;
  Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream;

  String _connectionStatus = 'disconnected';
  String get connectionStatus => _connectionStatus;

  bool get isConnected => _connectionStatus == 'connected';

  /// Connect to the AGiXT WebSocket for a conversation
  Future<bool> connect({String? conversationId}) async {
    try {
      final jwt = await AuthService.getJwt();
      if (jwt == null) {
        debugPrint('WebSocket: No JWT available');
        return false;
      }

      // Get conversation ID if not provided
      if (conversationId == null) {
        final cookieManager = CookieManager();
        conversationId = await cookieManager.getAgixtConversationId() ?? '-';
      }

      _currentConversationId = conversationId;
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
          '$protocol://$baseUrl/v1/conversation/$conversationId/stream?authorization=${Uri.encodeComponent(jwt)}';

      debugPrint('WebSocket: Connecting to $wsUrl');

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

      debugPrint('WebSocket: Connected successfully');
      return true;
    } catch (e) {
      debugPrint('WebSocket: Connection error: $e');
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
        debugPrint('WebSocket: Error closing channel: $e');
      }
      _channel = null;
    }

    if (intentional) {
      _setConnectionStatus('disconnected');
    }
  }

  /// Send a message through the WebSocket (if needed)
  void send(Map<String, dynamic> data) {
    if (_channel != null && _connectionStatus == 'connected') {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (e) {
        debugPrint('WebSocket: Error sending message: $e');
      }
    }
  }

  /// Submit the result of a client-side command execution
  Future<bool> submitCommandResult({
    required String requestId,
    required String toolName,
    required String output,
    required int exitCode,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final jwt = await AuthService.getJwt();
      if (jwt == null) return false;

      final result = {
        'tool_name': toolName,
        'output': output,
        'exit_code': exitCode,
        'request_id': requestId,
        ...?additionalData,
      };

      // Submit via HTTP to the remote-command-result endpoint
      final serverUrl = AuthService.serverUrl;
      final conversationId = _currentConversationId ?? '-';
      final url = Uri.parse(
        '$serverUrl/v1/conversation/$conversationId/remote-command-result',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode(result),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('WebSocket: Error submitting command result: $e');
      return false;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      debugPrint('WebSocket: Received message type: $type');

      switch (type) {
        case 'message_added':
          _handleMessageAdded(data);
          break;
        case 'activity.stream':
          _handleActivityStream(data);
          break;
        case 'remote_command.request':
          _handleRemoteCommand(data);
          break;
        case 'remote_command.pending':
          // Stream is ending due to remote command - nothing special to do
          debugPrint('WebSocket: Remote command pending');
          break;
        case 'conversation_renamed':
          _handleConversationRenamed(data);
          break;
        case 'system_notification':
          _handleSystemNotification(data);
          break;
        case 'pong':
          _handlePong();
          break;
        case 'initial_data':
          _handleInitialData(data);
          break;
        default:
          // Handle SSE-style streaming data
          if (data.containsKey('object')) {
            _handleObjectMessage(data);
          }
      }
    } catch (e) {
      debugPrint('WebSocket: Error parsing message: $e');
    }
  }

  void _handleMessageAdded(Map<String, dynamic> data) {
    final message = WebSocketMessage.fromJson(data);
    final content = message.message;

    // Parse activity messages
    if (content.startsWith('[ACTIVITY]')) {
      final remaining = content.substring(10).trim();
      String activityType = 'activity';
      String activityContent = remaining;

      if (remaining.startsWith('[INFO]')) {
        activityType = 'info';
        activityContent = remaining.substring(6).trim();
      } else if (remaining.startsWith('[ERROR]')) {
        activityType = 'error';
        activityContent = remaining.substring(7).trim();
      } else if (remaining.startsWith('[') && remaining.contains(']')) {
        activityContent = remaining.split(']').skip(1).join(']').trim();
      }

      _activityController.add(
        ActivityUpdate(type: activityType, content: activityContent),
      );
    } else if (content.startsWith('[SUBACTIVITY]')) {
      final remaining = content.substring(13).trim();
      String activityType = 'subactivity';
      String activityContent = remaining;

      if (remaining.startsWith('[THOUGHT]')) {
        activityType = 'thinking';
        activityContent = remaining.substring(9).trim();
      } else if (remaining.startsWith('[REFLECTION]')) {
        activityType = 'reflection';
        activityContent = remaining.substring(12).trim();
      } else if (remaining.startsWith('[') && remaining.contains(']')) {
        activityContent = remaining.split(']').skip(1).join(']').trim();
      }

      _activityController.add(
        ActivityUpdate(type: activityType, content: activityContent),
      );
    } else {
      // Regular message
      _messageController.add(message);
    }
  }

  void _handleActivityStream(Map<String, dynamic> data) {
    final activityType = data['type'] as String? ?? 'activity';
    final content = data['content'] as String? ?? '';
    final isComplete = data['complete'] as bool? ?? false;

    _activityController.add(
      ActivityUpdate(
        type: activityType,
        content: content,
        isComplete: isComplete,
      ),
    );
  }

  void _handleRemoteCommand(Map<String, dynamic> data) {
    final command = RemoteCommandRequest.fromJson(data);
    debugPrint(
      'WebSocket: Remote command request: ${command.toolName} with args: ${command.toolArgs}',
    );
    _commandController.add(command);
  }

  void _handleConversationRenamed(Map<String, dynamic> data) {
    final convData = data['data'] as Map<String, dynamic>?;
    debugPrint('WebSocket: Conversation renamed: $convData');
  }

  void _handleSystemNotification(Map<String, dynamic> data) {
    final notification = SystemNotification.fromJson(data);
    debugPrint(
      'WebSocket: System notification received: ${notification.title}',
    );
    _systemNotificationController.add(notification);
  }

  void _handleInitialData(Map<String, dynamic> data) {
    final messages = data['messages'] as List<dynamic>?;
    if (messages != null) {
      for (final msgData in messages) {
        if (msgData is Map<String, dynamic>) {
          _messageController.add(
            WebSocketMessage.fromJson({
              'type': 'message_added',
              'data': msgData,
            }),
          );
        }
      }
    }
  }

  void _handleObjectMessage(Map<String, dynamic> data) {
    final objectType = data['object'] as String?;

    if (objectType == 'remote_command.request') {
      _handleRemoteCommand(data);
    } else if (objectType == 'activity.stream') {
      _handleActivityStream(data);
    }
  }

  void _handlePong() {
    _heartbeatTimeoutTimer?.cancel();
  }

  void _handleError(Object error) {
    debugPrint('WebSocket: Error: $error');
    _setConnectionStatus('error');
    if (!_isIntentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _handleDone() {
    debugPrint('WebSocket: Connection closed');
    _stopHeartbeat();

    if (!_isIntentionalDisconnect) {
      _setConnectionStatus('reconnecting');
      _scheduleReconnect();
    } else {
      _setConnectionStatus('disconnected');
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
      (_) => _sendHeartbeat(),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
  }

  void _sendHeartbeat() {
    if (_channel != null && _connectionStatus == 'connected') {
      try {
        _channel!.sink.add(jsonEncode({'type': 'ping'}));
        _heartbeatTimeoutTimer = Timer(
          const Duration(milliseconds: heartbeatTimeout),
          () {
            debugPrint('WebSocket: Heartbeat timeout, reconnecting...');
            _handleDone();
          },
        );
      } catch (e) {
        debugPrint('WebSocket: Error sending heartbeat: $e');
      }
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('WebSocket: Max reconnect attempts reached');
      _setConnectionStatus('error');
      return;
    }

    _cancelReconnect();

    final delay = _calculateReconnectDelay();
    debugPrint(
      'WebSocket: Scheduling reconnect in ${delay}ms (attempt ${_reconnectAttempts + 1})',
    );

    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      _reconnectAttempts++;
      connect(conversationId: _currentConversationId);
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  int _calculateReconnectDelay() {
    // Exponential backoff with jitter
    final baseDelay = reconnectBaseDelay * (1 << _reconnectAttempts);
    final delay = baseDelay.clamp(reconnectBaseDelay, reconnectMaxDelay);
    // Add some jitter (±20%)
    final jitter =
        (delay * 0.2 * (DateTime.now().millisecond / 1000 - 0.5)).round();
    return delay + jitter;
  }

  /// Dispose of resources
  void dispose() {
    disconnect();
    _messageController.close();
    _activityController.close();
    _commandController.close();
    _connectionStatusController.close();
  }
}
