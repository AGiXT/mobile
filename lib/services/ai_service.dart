// Service for handling AI communications with AGiXT API
import 'dart:async';
import 'package:agixt/models/agixt/widgets/agixt_chat.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/services/whisper.dart';
import 'package:agixt/services/websocket_service.dart';
import 'package:agixt/services/client_commands_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Import Services

class AIService {
  // MethodChannel for button events from native code
  static const MethodChannel _buttonEventsChannel =
      MethodChannel('dev.agixt.agixt/button_events');

  static final AIService singleton = AIService._internal();
  final BluetoothManager _bluetoothManager = BluetoothManager.singleton;
  WhisperService? _whisperService;
  final AGiXTChatWidget _chatWidget = AGiXTChatWidget();
  final AGiXTWebSocketService _webSocketService = AGiXTWebSocketService();
  final ClientCommandsService _clientCommandsService = ClientCommandsService();

  bool _isProcessing = false;
  Timer? _micTimer;
  bool _isBackgroundMode = false;
  bool _methodChannelInitialized = false;

  // WebSocket streaming state
  StreamSubscription<WebSocketMessage>? _messageSubscription;
  StreamSubscription<ActivityUpdate>? _activitySubscription;
  StringBuffer _streamingResponse = StringBuffer();
  bool _isStreaming = false;

  factory AIService() {
    return singleton;
  }

  AIService._internal() {
    _initWhisperService();
    _initWebSocketService();
    // Method channel handler will be set up when needed
  }

  /// Initialize AIService for background operations
  void setBackgroundMode(bool isBackground) {
    _isBackgroundMode = isBackground;
    debugPrint('AIService: Background mode set to $isBackground');

    if (!_isBackgroundMode && !_methodChannelInitialized) {
      // Set up the method call handler for button events (only in foreground mode)
      try {
        _buttonEventsChannel.setMethodCallHandler(_handleButtonEvents);
        _methodChannelInitialized = true;
        debugPrint('AIService: Method channel handler initialized');
      } catch (e) {
        debugPrint('AIService: Failed to set method call handler: $e');
      }
    }

    // Start client commands listener when in foreground
    if (!_isBackgroundMode) {
      _clientCommandsService.startListening();
    } else {
      _clientCommandsService.stopListening();
    }
  }

  /// Initialize WebSocket service and listeners
  void _initWebSocketService() {
    // Listen for streamed messages
    _messageSubscription = _webSocketService.messageStream.listen(
      _handleStreamedMessage,
      onError: (error) {
        debugPrint('AIService: WebSocket message error: $error');
      },
    );

    // Listen for activity updates (thinking, reflection, etc.)
    _activitySubscription = _webSocketService.activityStream.listen(
      _handleActivityUpdate,
      onError: (error) {
        debugPrint('AIService: WebSocket activity error: $error');
      },
    );
  }

  /// Handle streamed message from WebSocket
  void _handleStreamedMessage(WebSocketMessage message) {
    if (message.role == 'assistant' && message.message.isNotEmpty) {
      // Check if this is part of an ongoing stream or a complete message
      final content = message.message;

      // Skip activity messages
      if (content.startsWith('[ACTIVITY]') ||
          content.startsWith('[SUBACTIVITY]')) {
        return;
      }

      if (_isStreaming) {
        _streamingResponse.write(content);
      } else {
        // Complete message received
        debugPrint('AIService: Received complete message via WebSocket');
      }
    }
  }

  /// Handle activity updates (thinking, reflection, etc.)
  void _handleActivityUpdate(ActivityUpdate activity) {
    debugPrint(
        'AIService: Activity [${activity.type}]: ${activity.content.substring(0, activity.content.length > 50 ? 50 : activity.content.length)}...');

    // Optionally show activity on glasses
    if (activity.type == 'thinking' && !activity.isComplete) {
      // Could show "Thinking..." on glasses
      // _bluetoothManager.sendAIResponse('Thinking...');
    }
  }

  /// Connect to WebSocket for real-time streaming
  Future<bool> connectWebSocket({String? conversationId}) async {
    return await _webSocketService.connect(conversationId: conversationId);
  }

  /// Disconnect from WebSocket
  Future<void> disconnectWebSocket() async {
    await _webSocketService.disconnect();
  }

  // Handle method calls from the button events channel
  Future<void> _handleButtonEvents(MethodCall call) async {
    switch (call.method) {
      case 'sideButtonPressed':
        debugPrint('Side button press event received from native code.');
        await handleSideButtonPress();
        break;
      default:
        debugPrint(
            'Unknown method call from button events channel: ${call.method}');
    }
  }

  // Initialize the WhisperService using the factory method
  Future<void> _initWhisperService() async {
    _whisperService = await WhisperService.service();
  }

  // Handle side button press to activate voice input and AI response
  Future<void> handleSideButtonPress() async {
    if (_isProcessing) {
      debugPrint('Already processing a request');
      return;
    }

    _isProcessing = true;
    try {
      // First open the microphone before showing "Listening..."
      await _bluetoothManager.setMicrophone(true);

      // Now show listening indicator since we're actually listening
      await _showListeningIndicator();

      // Set a timeout for voice recording (5 seconds)
      _micTimer = Timer(const Duration(seconds: 5), () async {
        await _processSpeechToText();
      });
    } catch (e) {
      debugPrint('Error handling side button press: $e');
      _isProcessing = false;
      await _showErrorMessage('Failed to process voice input');
    }
  }

  // Process recorded speech using Whisper service
  Future<void> _processSpeechToText() async {
    _micTimer?.cancel();

    try {
      // Show processing message before closing microphone
      // because we're still processing the audio we just captured
      await _showProcessingMessage();

      // Close microphone
      await _bluetoothManager.setMicrophone(false);

      // Initialize WhisperService if not already initialized
      if (_whisperService == null) {
        await _initWhisperService();
      }

      // Get transcription from Whisper service
      final transcription = await _whisperService?.getTranscription();

      if (transcription != null && transcription.isNotEmpty) {
        // Send message to AGiXT API
        await _sendMessageToAGiXT(transcription);
      } else {
        await _showErrorMessage('No speech detected');
      }
    } catch (e) {
      debugPrint('Error processing speech to text: $e');
      await _showErrorMessage('Error processing voice input');
    } finally {
      _isProcessing = false;
    }
  }

  // Send message to AGiXT API and display response
  Future<void> _sendMessageToAGiXT(String message) async {
    try {
      // Show sending message using AI response method
      await _bluetoothManager.sendAIResponse('Sending to AGiXT: "$message"');

      // Get response using the AGiXTChatWidget
      final response = await _chatWidget.sendChatMessage(message);

      if (response != null && response.isNotEmpty) {
        // Display response on glasses using AI response method that bypasses display checks
        await _bluetoothManager.sendAIResponse(response);
      } else {
        await _showErrorMessage('No response from AGiXT');
      }
    } catch (e) {
      debugPrint('Error sending message to AGiXT: $e');
      await _showErrorMessage('Failed to get response from AGiXT');
    }
  }

  Future<void> processVoiceCommand(String commandText) async {
    if (_isProcessing) {
      debugPrint('Already processing a request');
      return;
    }

    _isProcessing = true;
    try {
      await _bluetoothManager.sendAIResponse('Processing voice command...');

      // Send the command to AGiXT without requiring button press
      await _sendMessageToAGiXT(commandText);
    } catch (e) {
      debugPrint('Error processing voice command: $e');
      await _showErrorMessage('Error processing voice command');
    } finally {
      _isProcessing = false;
    }
  }

  /// Process voice command specifically for background mode (screen locked)
  /// This bypasses heavy context building to ensure responses work when locked
  Future<void> processVoiceCommandBackground(String commandText) async {
    if (_isProcessing) {
      debugPrint('Already processing a request');
      return;
    }

    _isProcessing = true;
    try {
      await _bluetoothManager.sendAIResponse('Processing voice command...');

      // Send the command to AGiXT without context building to avoid timeouts
      await _sendMessageToAGiXTDirect(commandText);
    } catch (e) {
      debugPrint('Error processing background voice command: $e');
      await _showErrorMessage('Error processing voice command');
    } finally {
      _isProcessing = false;
    }
  }

  /// Send message to AGiXT API directly without context (for background mode)
  Future<void> _sendMessageToAGiXTDirect(String message) async {
    try {
      // Show sending message using AI response method
      await _bluetoothManager.sendAIResponse('Sending to AGiXT: "$message"');

      // Get response using a minimal chat request (no context to avoid blocking)
      final response = await _chatWidget.sendChatMessageDirect(message);

      if (response != null && response.isNotEmpty) {
        // Display response on glasses using AI response method that bypasses display checks
        await _bluetoothManager.sendAIResponse(response);
      } else {
        await _showErrorMessage('No response from AGiXT');
      }
    } catch (e) {
      debugPrint('Error sending message to AGiXT: $e');
      await _showErrorMessage('Failed to get response from AGiXT');
    }
  }

  // Helper methods for displaying status messages
  Future<void> _showListeningIndicator() async {
    await _bluetoothManager.sendAIResponse('Listening...');
  }

  Future<void> _showProcessingMessage() async {
    await _bluetoothManager.sendAIResponse('Processing...');
  }

  Future<void> _showErrorMessage(String message) async {
    await _bluetoothManager.sendAIResponse('Error: $message');
  }

  /// Check if AIService is in background mode
  bool get isBackgroundMode => _isBackgroundMode;

  /// Check if WebSocket is connected
  bool get isWebSocketConnected => _webSocketService.isConnected;

  /// Get WebSocket connection status
  String get webSocketStatus => _webSocketService.connectionStatus;

  /// Dispose of resources
  void dispose() {
    _messageSubscription?.cancel();
    _activitySubscription?.cancel();
    _clientCommandsService.dispose();
    _webSocketService.dispose();
  }
}
