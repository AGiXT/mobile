// Service for handling AI communications with AGiXT API
import 'dart:async';
import 'dart:typed_data';
import 'package:agixt/models/agixt/widgets/agixt_chat.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/services/whisper.dart';
import 'package:agixt/services/websocket_service.dart';
import 'package:agixt/services/client_commands_service.dart';
import 'package:agixt/services/watch_service.dart';
import 'package:agixt/services/wake_word_service.dart';
import 'package:agixt/services/voice_input_service.dart';
import 'package:agixt/services/tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Import Services

class AIService {
  // MethodChannel for button events from native code
  static const MethodChannel _buttonEventsChannel =
      MethodChannel('dev.agixt.agixt/button_events');

  static final AIService singleton = AIService._internal();
  final BluetoothManager _bluetoothManager = BluetoothManager.singleton;
  final WatchService _watchService = WatchService.singleton;
  final WakeWordService _wakeWordService = WakeWordService.singleton;
  final VoiceInputService _voiceInputService = VoiceInputService.singleton;
  final TTSService _ttsService = TTSService.singleton;
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
  StreamSubscription<WakeWordEvent>? _wakeWordSubscription;
  StreamSubscription<VoiceInputState>? _voiceInputSubscription;
  StringBuffer _streamingResponse = StringBuffer();
  bool _isStreaming = false;

  factory AIService() {
    return singleton;
  }

  AIService._internal() {
    _initWhisperService();
    _initWebSocketService();
    _initNewServices();
    // Method channel handler will be set up when needed
  }

  /// Initialize new services (watch, wake word, voice input, TTS)
  Future<void> _initNewServices() async {
    try {
      // Initialize watch service
      await _watchService.initialize();

      // Initialize wake word service
      await _wakeWordService.initialize();

      // Initialize voice input service
      await _voiceInputService.initialize();

      // Initialize TTS service
      await _ttsService.initialize();

      // Set up wake word listener
      _wakeWordSubscription = _wakeWordService.eventStream.listen(
        _handleWakeWordEvent,
        onError: (error) {
          debugPrint('AIService: Wake word error: $error');
        },
      );

      // Set up voice input listener
      _voiceInputSubscription = _voiceInputService.stateStream.listen(
        _handleVoiceInputState,
        onError: (error) {
          debugPrint('AIService: Voice input error: $error');
        },
      );

      debugPrint('AIService: New services initialized');
    } catch (e) {
      debugPrint('AIService: Error initializing new services: $e');
    }
  }

  /// Handle wake word events
  void _handleWakeWordEvent(WakeWordEvent event) {
    if (event.type == WakeWordEventType.detected) {
      debugPrint('AIService: Wake word detected from ${event.source}');
      // Start voice recording when wake word is detected
      if (!_isProcessing) {
        _startVoiceRecording();
      }
    }
  }

  /// Handle voice input state changes
  void _handleVoiceInputState(VoiceInputState state) {
    debugPrint('AIService: Voice input state: ${state.status}');

    if (state.status == VoiceInputStatus.complete && state.audioData != null) {
      // Process the recorded audio
      _processRecordedAudio(state.audioData!, state.source);
    }
  }

  /// Start voice recording from the best available source
  Future<void> _startVoiceRecording() async {
    if (_isProcessing) {
      debugPrint('AIService: Already processing');
      return;
    }

    _isProcessing = true;

    // Show listening indicator
    await _showListeningIndicator();

    // Start recording from the best available source
    final success = await _voiceInputService.startRecording(
      maxDuration: const Duration(seconds: 10),
    );

    if (!success) {
      debugPrint('AIService: Failed to start recording');
      _isProcessing = false;
      await _showErrorMessage('Failed to start recording');
    }
  }

  /// Process recorded audio from any source
  Future<void> _processRecordedAudio(Uint8List audioData, VoiceInputSource? source) async {
    try {
      await _showProcessingMessage();

      // First, transcribe the audio using whisper service
      String? transcription;
      if (_whisperService != null) {
        transcription = await _whisperService!.transcribe(audioData);
      }

      if (transcription == null || transcription.isEmpty) {
        await _showErrorMessage('Could not transcribe audio');
        return;
      }

      debugPrint('AIService: Transcription: $transcription');

      // Send transcribed text to AGiXT chat
      final response = await _chatWidget.sendChatMessage(transcription);

      if (response != null && response.isNotEmpty) {
        // Output response based on connected devices
        await _outputResponse(response);
      } else {
        await _showErrorMessage('No response from AGiXT');
      }
    } catch (e) {
      debugPrint('AIService: Error processing audio: $e');
      await _showErrorMessage('Error processing voice input');
    } finally {
      _isProcessing = false;
    }
  }

  /// Output response to the appropriate device(s)
  Future<void> _outputResponse(String response) async {
    // Always display on glasses if connected
    if (_bluetoothManager.isConnected) {
      await _bluetoothManager.sendAIResponse(response);
    }

    // Also display on watch if connected
    if (_watchService.isConnected) {
      await _watchService.displayMessage(response, durationMs: 10000);
    }

    // Use TTS if appropriate (watch has speaker, glasses don't)
    if (_ttsService.shouldUseTTS()) {
      await _ttsService.speak(response);
    }
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

      // Enable wake word detection if configured
      if (_wakeWordService.isEnabled) {
        _wakeWordService.startListening();
      }
    } else {
      _clientCommandsService.stopListening();
      // Keep wake word active in background if enabled
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
      // Pause wake word detection during manual recording
      if (_wakeWordService.isEnabled) {
        await _wakeWordService.pause();
      }

      // Use the voice input service to record from best available source
      final source = _voiceInputService.getBestAvailableSource();
      debugPrint('AIService: Starting recording from $source');

      // Now show listening indicator since we're about to listen
      await _showListeningIndicator();

      // Start recording
      final success = await _voiceInputService.startRecording(
        maxDuration: const Duration(seconds: 5),
      );

      if (!success) {
        // Fall back to original method if voice input service fails
        await _fallbackToOriginalRecording();
      }
    } catch (e) {
      debugPrint('Error handling side button press: $e');
      _isProcessing = false;
      await _showErrorMessage('Failed to process voice input');
    }
  }

  /// Fallback to original glasses-only recording method
  Future<void> _fallbackToOriginalRecording() async {
    try {
      // First open the microphone before showing "Listening..."
      await _bluetoothManager.setMicrophone(true);

      // Set a timeout for voice recording (5 seconds)
      _micTimer = Timer(const Duration(seconds: 5), () async {
        await _processSpeechToText();
      });
    } catch (e) {
      debugPrint('Error in fallback recording: $e');
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
        // Output response to appropriate devices
        await _outputResponse(response);
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
      await _showProcessingMessage();

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
      await _showProcessingMessage();

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
        // Output response to appropriate devices
        await _outputResponse(response);
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
    if (_watchService.isConnected) {
      await _watchService.displayMessage('Listening...', durationMs: 3000);
    }
  }

  Future<void> _showProcessingMessage() async {
    await _bluetoothManager.sendAIResponse('Processing...');
    if (_watchService.isConnected) {
      await _watchService.displayMessage('Processing...', durationMs: 3000);
    }
  }

  Future<void> _showErrorMessage(String message) async {
    await _bluetoothManager.sendAIResponse('Error: $message');
    if (_watchService.isConnected) {
      await _watchService.displayMessage('Error: $message', durationMs: 5000);
    }
  }

  /// Check if AIService is in background mode
  bool get isBackgroundMode => _isBackgroundMode;

  /// Check if WebSocket is connected
  bool get isWebSocketConnected => _webSocketService.isConnected;

  /// Get WebSocket connection status
  String get webSocketStatus => _webSocketService.connectionStatus;

  /// Check if glasses are connected
  bool get isGlassesConnected => _bluetoothManager.isConnected;

  /// Check if watch is connected
  bool get isWatchConnected => _watchService.isConnected;

  /// Check if wake word is enabled
  bool get isWakeWordEnabled => _wakeWordService.isEnabled;

  /// Enable or disable wake word detection
  Future<void> setWakeWordEnabled(bool enabled) async {
    await _wakeWordService.setEnabled(enabled);
  }

  /// Get TTS service for configuration
  TTSService get ttsService => _ttsService;

  /// Get wake word service for configuration
  WakeWordService get wakeWordService => _wakeWordService;

  /// Get voice input service for configuration
  VoiceInputService get voiceInputService => _voiceInputService;

  /// Get watch service for configuration
  WatchService get watchService => _watchService;

  /// Dispose of resources
  void dispose() {
    _messageSubscription?.cancel();
    _activitySubscription?.cancel();
    _wakeWordSubscription?.cancel();
    _voiceInputSubscription?.cancel();
    _clientCommandsService.dispose();
    _webSocketService.dispose();
    _voiceInputService.dispose();
    _ttsService.dispose();
    _wakeWordService.dispose();
    _watchService.dispose();
  }
}
