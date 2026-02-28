// Service for handling AI communications with AGiXT API
import 'dart:async';
import 'package:agixt/models/agixt/widgets/agixt_chat.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/services/whisper.dart';
import 'package:agixt/services/websocket_service.dart';
import 'package:agixt/services/client_commands_service.dart';
import 'package:agixt/services/watch_service.dart';
import 'package:agixt/services/wake_word_service.dart';
import 'package:agixt/services/voice_input_service.dart';
import 'package:agixt/services/tts_service.dart';
import 'package:agixt/services/audio_player_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Import Services

class AIService {
  // MethodChannel for button events from native code
  static const MethodChannel _buttonEventsChannel = MethodChannel(
    'dev.agixt.agixt/button_events',
  );

  static final AIService singleton = AIService._internal();
  final BluetoothManager _bluetoothManager = BluetoothManager.singleton;
  final WatchService _watchService = WatchService.singleton;
  final WakeWordService _wakeWordService = WakeWordService.singleton;
  final VoiceInputService _voiceInputService = VoiceInputService.singleton;
  final TTSService _ttsService = TTSService.singleton;
  final AudioPlayerService _audioPlayerService = AudioPlayerService.singleton;
  WhisperService? _whisperService;
  final AGiXTChatWidget _chatWidget = AGiXTChatWidget();
  final AGiXTWebSocketService _webSocketService = AGiXTWebSocketService();
  final ClientCommandsService _clientCommandsService = ClientCommandsService();

  bool _isProcessing = false;
  Timer? _micTimer;
  bool _isBackgroundMode = false;
  bool _methodChannelInitialized = false;
  bool _isConversationRecording = false;

  // WebSocket streaming state
  StreamSubscription<WebSocketMessage>? _messageSubscription;
  StreamSubscription<ActivityUpdate>? _activitySubscription;
  StreamSubscription<WakeWordEvent>? _wakeWordSubscription;
  StreamSubscription<VoiceInputState>? _voiceInputSubscription;
  StreamSubscription<WatchVoiceInput>? _watchVoiceInputSubscription;
  final StringBuffer _streamingResponse = StringBuffer();
  bool _isStreaming = false; // ignore: prefer_final_fields

  factory AIService() {
    return singleton;
  }

  AIService._internal() {
    _initWhisperService();
    _initWebSocketService();
    _initNewServices();
    // Method channel handler will be set up when needed
  }

  /// Initialize new services (watch, wake word, voice input, TTS, audio player)
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

      // Initialize audio player service for streaming PCM playback
      await _audioPlayerService.initialize();

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

      // Set up watch voice input listener
      _watchVoiceInputSubscription = _watchService.voiceInputStream.listen(
        _handleWatchVoiceInput,
        onError: (error) {
          debugPrint('AIService: Watch voice input error: $error');
        },
      );

      debugPrint('AIService: New services initialized');
    } catch (e) {
      debugPrint('AIService: Error initializing new services: $e');
    }
  }

  /// Handle wake word events
  void _handleWakeWordEvent(WakeWordEvent event) {
    switch (event.type) {
      case WakeWordEventType.detected:
        debugPrint('AIService: Wake word detected from ${event.source}');
        // Provide haptic feedback
        _playWakeWordFeedback();
        // Start voice recording when wake word is detected
        if (!_isProcessing) {
          _startVoiceRecording();
        }
        break;

      case WakeWordEventType.modelDownloadStarted:
        debugPrint('AIService: Wake word model download started');
        _showInfoMessage('Downloading speech model for wake word...');
        break;

      case WakeWordEventType.modelDownloadProgress:
        final progress = ((event.progress ?? 0) * 100).toInt();
        debugPrint('AIService: Wake word model download progress: $progress%');
        break;

      case WakeWordEventType.modelDownloadComplete:
        debugPrint('AIService: Wake word model download complete');
        _showInfoMessage('Wake word ready! Say "computer" to activate.');
        break;

      case WakeWordEventType.error:
        debugPrint('AIService: Wake word error: ${event.error}');
        break;

      default:
        break;
    }
  }

  /// Play feedback when wake word is detected
  Future<void> _playWakeWordFeedback() async {
    try {
      // Haptic feedback using Flutter's built-in HapticFeedback
      await HapticFeedback.mediumImpact();
      // Also play system click sound
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('AIService: Error playing wake word feedback: $e');
    }
  }

  /// Handle voice input state changes
  void _handleVoiceInputState(VoiceInputState state) {
    debugPrint(
        'AIService: Voice input state: ${state.status}, hasAudio: ${state.audioData != null}');

    // Process audio when recording completes with audio data
    if ((state.status == VoiceInputStatus.complete ||
            state.status == VoiceInputStatus.stopped) &&
        state.audioData != null) {
      if (_isConversationRecording) {
        _isConversationRecording = false;
        _processConversationRecording(state.audioData!, state.source);
      } else {
        // Process the recorded audio
        _processRecordedAudio(state.audioData!, state.source);
      }
    } else if (state.status == VoiceInputStatus.stopped &&
        state.audioData == null) {
      // Recording stopped but no audio captured
      if (_isConversationRecording) {
        _isConversationRecording = false;
      }
      debugPrint('AIService: Recording stopped with no audio data');
      _isProcessing = false;
      _showErrorMessage('No audio captured');
    }
  }

  /// Handle voice input from the Wear OS watch
  Future<void> _handleWatchVoiceInput(WatchVoiceInput input) async {
    debugPrint('AIService: Watch voice input: ${input.text}');

    if (input.text.isEmpty) {
      await _watchService.sendErrorToWatch(
        'No speech detected',
        nodeId: input.nodeId,
      );
      return;
    }

    try {
      // Use TTS streaming to send audio to the watch speaker
      await _processTextInputWithTTS(input.text, nodeId: input.nodeId);
    } catch (e) {
      debugPrint('AIService: Error processing watch input: $e');
      await _watchService.sendErrorToWatch(
        'Error processing request',
        nodeId: input.nodeId,
      );
    }
  }

  /// Process text input with TTS streaming to watch
  ///
  /// This uses the interleaved TTS mode to stream both text and audio
  /// to the watch, allowing real-time audio playback on the watch speaker.
  Future<void> _processTextInputWithTTS(String text, {String? nodeId}) async {
    try {
      final responseBuffer = StringBuffer();
      bool audioHeaderSent = false;

      await for (final event in _chatWidget.sendChatMessageStreamingWithTTS(
        text,
      )) {
        switch (event.type) {
          case ChatStreamEventType.text:
            if (event.text != null) {
              responseBuffer.write(event.text);
            }
            break;

          case ChatStreamEventType.audioHeader:
            // Send audio format to watch
            if (event.sampleRate != null &&
                event.bitsPerSample != null &&
                event.channels != null) {
              await _watchService.sendAudioHeader(
                sampleRate: event.sampleRate!,
                bitsPerSample: event.bitsPerSample!,
                channels: event.channels!,
                nodeId: nodeId,
              );
              audioHeaderSent = true;
              debugPrint('AIService: Sent audio header to watch');
            }
            break;

          case ChatStreamEventType.audioChunk:
            // Stream audio chunk to watch
            if (event.audioData != null && audioHeaderSent) {
              await _watchService.sendAudioChunk(
                event.audioData!,
                nodeId: nodeId,
              );
            }
            break;

          case ChatStreamEventType.audioEnd:
            // Signal end of audio
            await _watchService.sendAudioEnd(nodeId: nodeId);
            debugPrint('AIService: Sent audio end to watch');
            break;

          case ChatStreamEventType.done:
            // Stream complete - send text response for display
            final response = responseBuffer.toString();
            if (response.isNotEmpty) {
              await _watchService.sendChatResponse(response, nodeId: nodeId);
            }
            break;

          case ChatStreamEventType.error:
            await _watchService.sendErrorToWatch(
              event.error ?? 'Unknown error',
              nodeId: nodeId,
            );
            break;
        }
      }
    } catch (e) {
      debugPrint('AIService: Error in TTS streaming: $e');
      await _watchService.sendErrorToWatch(
        'Error processing request',
        nodeId: nodeId,
      );
    }
  }

  /// Process text input and return the response
  // ignore: unused_element
  Future<String?> _processTextInput(String text) async {
    try {
      // Use streaming for better responsiveness
      final responseBuffer = StringBuffer();
      final stream = _chatWidget.sendChatMessageStreaming(text);

      await for (final chunk in stream) {
        responseBuffer.write(chunk);
      }

      return responseBuffer.toString();
    } catch (e) {
      debugPrint('AIService: Error processing text input: $e');
      return null;
    }
  }

  /// Start voice recording from the best available source
  Future<void> _startVoiceRecording() async {
    if (_isProcessing) {
      debugPrint('AIService: Already processing');
      return;
    }

    _isProcessing = true;

    // First pause wake word detection to release the phone microphone
    // This must complete before we try to start recording
    if (_wakeWordService.isEnabled) {
      debugPrint('AIService: Pausing wake word detection...');
      await _wakeWordService.pause();
      // Give the audio system a moment to release resources
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Show listening indicator
    await _showListeningIndicator();

    // Start recording from the best available source
    debugPrint('AIService: Starting voice recording...');
    final success = await _voiceInputService.startRecording(
      maxDuration: const Duration(seconds: 10),
    );

    if (!success) {
      debugPrint('AIService: Failed to start recording');
      _isProcessing = false;
      await _showErrorMessage('Failed to start recording');
      // Resume wake word detection since recording failed
      if (_wakeWordService.isEnabled) {
        await _wakeWordService.resume();
      }
    }
  }

  /// Public method to start voice input (for assistant/external triggers)
  /// This can be called when the app is launched as a digital assistant
  Future<void> startVoiceInput() async {
    debugPrint('AIService: startVoiceInput called (external trigger)');
    await _startVoiceRecording();
  }

  /// Process recorded audio from any source
  Future<void> _processRecordedAudio(
    Uint8List audioData,
    VoiceInputSource? source,
  ) async {
    debugPrint(
        'AIService: _processRecordedAudio called with ${audioData.length} bytes from $source');
    try {
      await _showProcessingMessage();

      // First, transcribe the audio using whisper service
      debugPrint('AIService: Transcribing audio with WhisperService...');
      String? transcription;
      if (_whisperService != null) {
        transcription = await _whisperService!.transcribe(audioData);
      } else {
        debugPrint('AIService: WhisperService is null, initializing...');
        await _initWhisperService();
        if (_whisperService != null) {
          transcription = await _whisperService!.transcribe(audioData);
        }
      }

      if (transcription == null || transcription.isEmpty) {
        debugPrint('AIService: Transcription failed or empty');
        await _showErrorMessage('Could not transcribe audio');
        return;
      }

      debugPrint('AIService: Transcription: $transcription');

      // Send transcribed text to AGiXT chat with streaming TTS (like ESP32)
      // This uses tts_mode=interleaved to stream both text and audio
      final responseBuffer = StringBuffer();
      bool audioHeaderSent = false;
      bool usePhoneAudio =
          !_watchService.isConnected; // Track if we're using phone audio
      DateTime? lastGlassesUpdate;
      const glassesUpdateInterval = Duration(milliseconds: 500);

      await for (final event in _chatWidget.sendChatMessageStreamingWithTTS(
        transcription,
      )) {
        switch (event.type) {
          case ChatStreamEventType.text:
            if (event.text != null) {
              responseBuffer.write(event.text);
              // Stream accumulated text to glasses progressively (rate limited)
              if (_bluetoothManager.isConnected) {
                final now = DateTime.now();
                if (lastGlassesUpdate == null ||
                    now.difference(lastGlassesUpdate) >
                        glassesUpdateInterval) {
                  lastGlassesUpdate = now;
                  // Send full accumulated text so far
                  await _bluetoothManager.sendAIResponse(
                    responseBuffer.toString(),
                  );
                }
              }
            }
            break;

          case ChatStreamEventType.audioHeader:
            // Audio format info - start streaming playback
            if (event.sampleRate != null) {
              debugPrint(
                  'AIService: Audio header - ${event.sampleRate}Hz, ${event.bitsPerSample}bit, ${event.channels}ch');
              audioHeaderSent = true;
              // Send audio header to watch if connected, otherwise start phone playback
              if (!usePhoneAudio && _watchService.isConnected) {
                final success = await _watchService.sendAudioHeader(
                  sampleRate: event.sampleRate!,
                  bitsPerSample: event.bitsPerSample ?? 16,
                  channels: event.channels ?? 1,
                );
                if (!success) {
                  // Watch send failed - fall back to phone speaker
                  debugPrint(
                      'AIService: Watch audio header failed, falling back to phone');
                  usePhoneAudio = true;
                  await _audioPlayerService.startStreaming(
                    sampleRate: event.sampleRate!,
                    bitsPerSample: event.bitsPerSample ?? 16,
                    channels: event.channels ?? 1,
                  );
                }
              } else {
                // Start streaming audio on phone speaker
                await _audioPlayerService.startStreaming(
                  sampleRate: event.sampleRate!,
                  bitsPerSample: event.bitsPerSample ?? 16,
                  channels: event.channels ?? 1,
                );
              }
            }
            break;

          case ChatStreamEventType.audioChunk:
            // Stream audio to watch speaker or phone speaker
            if (event.audioData != null && audioHeaderSent) {
              if (!usePhoneAudio && _watchService.isConnected) {
                final success =
                    await _watchService.sendAudioChunk(event.audioData!);
                if (!success) {
                  // Watch send failed - switch to phone audio
                  debugPrint(
                      'AIService: Watch audio chunk failed, switching to phone');
                  usePhoneAudio = true;
                  // Start phone streaming (we may have missed the header, use defaults)
                  await _audioPlayerService.startStreaming(
                    sampleRate: 24000,
                    bitsPerSample: 16,
                    channels: 1,
                  );
                  await _audioPlayerService.feedAudioChunk(event.audioData!);
                }
              } else {
                // Play on phone speaker
                await _audioPlayerService.feedAudioChunk(event.audioData!);
              }
            }
            break;

          case ChatStreamEventType.audioEnd:
            // Audio streaming complete
            if (!usePhoneAudio && _watchService.isConnected) {
              await _watchService.sendAudioEnd();
            } else {
              await _audioPlayerService.stopStreaming();
            }
            debugPrint('AIService: Audio streaming complete');
            break;

          case ChatStreamEventType.done:
            debugPrint('AIService: Response complete');
            break;

          case ChatStreamEventType.error:
            debugPrint('AIService: Stream error: ${event.error}');
            break;
        }
      }

      final fullResponse = responseBuffer.toString();

      if (fullResponse.isNotEmpty) {
        // Display final complete response on glasses
        if (_bluetoothManager.isConnected) {
          await _bluetoothManager.sendAIResponse(fullResponse);
        }
        // Display on watch
        if (_watchService.isConnected) {
          await _watchService.displayMessage(fullResponse, durationMs: 10000);
        }
        // Note: Audio is streamed in real-time via audioHeader/audioChunk events
        // No need for TTS fallback - AGiXT sends audio during the stream
      } else {
        await _showErrorMessage('No response from AGiXT');
      }
    } catch (e) {
      debugPrint('AIService: Error processing audio: $e');
      await _showErrorMessage('Error processing voice input');
      // Stop any playing audio on error
      await _audioPlayerService.stopStreaming();
    } finally {
      _isProcessing = false;
      // Resume wake word listening if enabled
      if (_wakeWordService.isEnabled) {
        await _wakeWordService.resume();
      }
    }
  }

  /// Process a conversation recording: transcribe and send with summary prompt
  Future<void> _processConversationRecording(
    Uint8List audioData,
    VoiceInputSource? source,
  ) async {
    debugPrint(
        'AIService: Processing conversation recording (${audioData.length} bytes from $source)');
    try {
      await _showProcessingMessage();

      // Transcribe the audio
      debugPrint('AIService: Transcribing conversation audio...');
      String? transcription;
      if (_whisperService != null) {
        transcription = await _whisperService!.transcribe(audioData);
      } else {
        debugPrint('AIService: WhisperService is null, initializing...');
        await _initWhisperService();
        if (_whisperService != null) {
          transcription = await _whisperService!.transcribe(audioData);
        }
      }

      if (transcription == null || transcription.isEmpty) {
        debugPrint('AIService: Conversation transcription failed or empty');
        await _showErrorMessage('Could not transcribe conversation');
        return;
      }

      debugPrint('AIService: Conversation transcription: $transcription');

      // Wrap transcription in a conversation summary prompt
      final prompt = 'The following is a transcription of a recorded '
          'conversation. Please:\n'
          '1. Summarize the conversation\n'
          '2. Extract potentially important notes and highlights\n'
          '3. Identify specific goals if mentioned\n'
          '4. List any action items\n\n'
          'Transcription:\n$transcription';

      // Send to AGiXT
      await _sendMessageToAGiXT(prompt);
    } catch (e) {
      debugPrint('AIService: Error processing conversation recording: $e');
      await _showErrorMessage('Error processing conversation');
      await _audioPlayerService.stopStreaming();
    } finally {
      _isProcessing = false;
      if (_wakeWordService.isEnabled) {
        await _wakeWordService.resume();
      }
    }
  }

  /// Output response to the appropriate device(s)
  // ignore: unused_element
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
      'AIService: Activity [${activity.type}]: ${activity.content.substring(0, activity.content.length > 50 ? 50 : activity.content.length)}...',
    );

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
          'Unknown method call from button events channel: ${call.method}',
        );
    }
  }

  // Initialize the WhisperService using the factory method
  Future<void> _initWhisperService() async {
    _whisperService = await WhisperService.service();
  }

  // Handle side button press to toggle conversation recording
  Future<void> handleSideButtonPress() async {
    // Toggle: if already recording a conversation, stop and process
    if (_isConversationRecording) {
      debugPrint('AIService: Stopping conversation recording (second press)');
      await _showInfoMessage('Processing conversation...');
      await _voiceInputService.stopRecording();
      // Audio will be processed via _handleVoiceInputState callback
      return;
    }

    if (_isProcessing) {
      debugPrint('Already processing a request');
      return;
    }

    _isProcessing = true;
    _isConversationRecording = true;
    try {
      // Pause wake word detection during recording
      if (_wakeWordService.isEnabled) {
        await _wakeWordService.pause();
      }

      // Use the voice input service to record from best available source
      final source = _voiceInputService.getBestAvailableSource();
      debugPrint('AIService: Starting conversation recording from $source');

      // Show recording indicator
      await _showInfoMessage('Recording...');

      // Start recording with long duration - will be stopped manually by second press
      final success = await _voiceInputService.startRecording(
        maxDuration: const Duration(minutes: 30),
      );

      if (!success) {
        _isConversationRecording = false;
        _isProcessing = false;
        await _showErrorMessage('Failed to start recording');
      }
    } catch (e) {
      debugPrint('Error handling side button press: $e');
      _isConversationRecording = false;
      _isProcessing = false;
      await _showErrorMessage('Failed to process voice input');
    }
  }

  /// Fallback to original glasses-only recording method
  // ignore: unused_element
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

  // Send message to AGiXT API and display response (with streaming TTS for watch)
  Future<void> _sendMessageToAGiXT(String message) async {
    try {
      // Show sending message using AI response method
      await _bluetoothManager.sendAIResponse('Processing...');

      // Use streaming TTS to send audio to watch (like ESP32 does)
      final responseBuffer = StringBuffer();
      bool audioHeaderSent = false;
      bool usePhoneAudio =
          !_watchService.isConnected; // Track if we're using phone audio
      DateTime? lastGlassesUpdate;
      const glassesUpdateInterval = Duration(milliseconds: 500);

      await for (final event in _chatWidget.sendChatMessageStreamingWithTTS(
        message,
      )) {
        switch (event.type) {
          case ChatStreamEventType.text:
            if (event.text != null) {
              responseBuffer.write(event.text);
              // Stream accumulated text to glasses progressively (rate limited)
              if (_bluetoothManager.isConnected) {
                final now = DateTime.now();
                if (lastGlassesUpdate == null ||
                    now.difference(lastGlassesUpdate) >
                        glassesUpdateInterval) {
                  lastGlassesUpdate = now;
                  await _bluetoothManager.sendAIResponse(
                    responseBuffer.toString(),
                  );
                }
              }
            }
            break;

          case ChatStreamEventType.audioHeader:
            // Send audio format to watch or start phone playback
            if (event.sampleRate != null) {
              debugPrint(
                  'AIService: Audio header - ${event.sampleRate}Hz, ${event.bitsPerSample}bit, ${event.channels}ch');
              audioHeaderSent = true;
              if (!usePhoneAudio && _watchService.isConnected) {
                final success = await _watchService.sendAudioHeader(
                  sampleRate: event.sampleRate!,
                  bitsPerSample: event.bitsPerSample ?? 16,
                  channels: event.channels ?? 1,
                );
                if (!success) {
                  debugPrint(
                      'AIService: Watch audio header failed, falling back to phone');
                  usePhoneAudio = true;
                  await _audioPlayerService.startStreaming(
                    sampleRate: event.sampleRate!,
                    bitsPerSample: event.bitsPerSample ?? 16,
                    channels: event.channels ?? 1,
                  );
                }
              } else {
                // Start streaming audio on phone speaker
                await _audioPlayerService.startStreaming(
                  sampleRate: event.sampleRate!,
                  bitsPerSample: event.bitsPerSample ?? 16,
                  channels: event.channels ?? 1,
                );
              }
            }
            break;

          case ChatStreamEventType.audioChunk:
            // Stream audio to watch speaker or phone speaker
            if (event.audioData != null && audioHeaderSent) {
              if (!usePhoneAudio && _watchService.isConnected) {
                final success =
                    await _watchService.sendAudioChunk(event.audioData!);
                if (!success) {
                  debugPrint(
                      'AIService: Watch audio chunk failed, switching to phone');
                  usePhoneAudio = true;
                  await _audioPlayerService.startStreaming(
                    sampleRate: 24000,
                    bitsPerSample: 16,
                    channels: 1,
                  );
                  await _audioPlayerService.feedAudioChunk(event.audioData!);
                }
              } else {
                // Play on phone speaker
                await _audioPlayerService.feedAudioChunk(event.audioData!);
              }
            }
            break;

          case ChatStreamEventType.audioEnd:
            // Audio streaming complete
            if (!usePhoneAudio && _watchService.isConnected) {
              await _watchService.sendAudioEnd();
            } else {
              await _audioPlayerService.stopStreaming();
            }
            debugPrint('AIService: Audio streaming complete');
            break;

          case ChatStreamEventType.done:
            debugPrint('AIService: Response complete');
            break;

          case ChatStreamEventType.error:
            debugPrint('AIService: Stream error: ${event.error}');
            break;
        }
      }

      final response = responseBuffer.toString();

      if (response.isNotEmpty) {
        // Display final response on glasses
        await _bluetoothManager.sendAIResponse(response);
        // Display on watch
        if (_watchService.isConnected) {
          await _watchService.displayMessage(response, durationMs: 10000);
        }
        // Note: Audio is streamed in real-time via audioHeader/audioChunk events
      } else {
        await _showErrorMessage('No response from AGiXT');
      }
    } catch (e) {
      debugPrint('Error sending message to AGiXT: $e');
      await _showErrorMessage('Failed to get response from AGiXT');
      // Stop any playing audio on error
      await _audioPlayerService.stopStreaming();
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
  /// Uses streaming TTS for watch audio playback
  Future<void> _sendMessageToAGiXTDirect(String message) async {
    try {
      // Show processing message
      await _bluetoothManager.sendAIResponse('Processing...');

      // Use streaming TTS to send audio to watch (like foreground mode)
      final responseBuffer = StringBuffer();
      bool audioHeaderSent = false;
      bool usePhoneAudio =
          !_watchService.isConnected; // Track if we're using phone audio
      DateTime? lastGlassesUpdate;
      const glassesUpdateInterval = Duration(milliseconds: 500);

      await for (final event in _chatWidget.sendChatMessageStreamingWithTTS(
        message,
      )) {
        switch (event.type) {
          case ChatStreamEventType.text:
            if (event.text != null) {
              responseBuffer.write(event.text);
              // Stream accumulated text to glasses progressively
              if (_bluetoothManager.isConnected) {
                final now = DateTime.now();
                if (lastGlassesUpdate == null ||
                    now.difference(lastGlassesUpdate) >
                        glassesUpdateInterval) {
                  lastGlassesUpdate = now;
                  await _bluetoothManager.sendAIResponse(
                    responseBuffer.toString(),
                  );
                }
              }
            }
            break;

          case ChatStreamEventType.audioHeader:
            if (event.sampleRate != null) {
              audioHeaderSent = true;
              if (!usePhoneAudio && _watchService.isConnected) {
                final success = await _watchService.sendAudioHeader(
                  sampleRate: event.sampleRate!,
                  bitsPerSample: event.bitsPerSample ?? 16,
                  channels: event.channels ?? 1,
                );
                if (!success) {
                  debugPrint(
                      'AIService: Watch audio header failed, falling back to phone');
                  usePhoneAudio = true;
                  await _audioPlayerService.startStreaming(
                    sampleRate: event.sampleRate!,
                    bitsPerSample: event.bitsPerSample ?? 16,
                    channels: event.channels ?? 1,
                  );
                }
              } else {
                // Start streaming audio on phone speaker
                await _audioPlayerService.startStreaming(
                  sampleRate: event.sampleRate!,
                  bitsPerSample: event.bitsPerSample ?? 16,
                  channels: event.channels ?? 1,
                );
              }
            }
            break;

          case ChatStreamEventType.audioChunk:
            if (event.audioData != null && audioHeaderSent) {
              if (!usePhoneAudio && _watchService.isConnected) {
                final success =
                    await _watchService.sendAudioChunk(event.audioData!);
                if (!success) {
                  debugPrint(
                      'AIService: Watch audio chunk failed, switching to phone');
                  usePhoneAudio = true;
                  await _audioPlayerService.startStreaming(
                    sampleRate: 24000,
                    bitsPerSample: 16,
                    channels: 1,
                  );
                  await _audioPlayerService.feedAudioChunk(event.audioData!);
                }
              } else {
                // Play on phone speaker
                await _audioPlayerService.feedAudioChunk(event.audioData!);
              }
            }
            break;

          case ChatStreamEventType.audioEnd:
            if (!usePhoneAudio && _watchService.isConnected) {
              await _watchService.sendAudioEnd();
            } else {
              await _audioPlayerService.stopStreaming();
            }
            break;

          case ChatStreamEventType.done:
          case ChatStreamEventType.error:
            break;
        }
      }

      final response = responseBuffer.toString();

      if (response.isNotEmpty) {
        await _bluetoothManager.sendAIResponse(response);
        if (_watchService.isConnected) {
          await _watchService.displayMessage(response, durationMs: 10000);
        }
        // Note: Audio is streamed in real-time via audioHeader/audioChunk events
      } else {
        await _showErrorMessage('No response from AGiXT');
      }
    } catch (e) {
      debugPrint('Error sending message to AGiXT: $e');
      await _showErrorMessage('Failed to get response from AGiXT');
      // Stop any playing audio on error
      await _audioPlayerService.stopStreaming();
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

  Future<void> _showInfoMessage(String message) async {
    await _bluetoothManager.sendAIResponse(message);
    if (_watchService.isConnected) {
      await _watchService.displayMessage(message, durationMs: 5000);
    }
  }

  /// Check if AIService is in background mode
  bool get isBackgroundMode => _isBackgroundMode;

  /// Check if currently recording a conversation
  bool get isConversationRecording => _isConversationRecording;

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
    _watchVoiceInputSubscription?.cancel();
    _clientCommandsService.dispose();
    _webSocketService.dispose();
    _voiceInputService.dispose();
    _ttsService.dispose();
    _wakeWordService.dispose();
    _watchService.dispose();
  }
}
