import 'package:agixt/models/g1/glass.dart';
import 'package:agixt/models/g1/commands.dart';
import 'package:agixt/services/ai_service.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/services/whisper.dart';
import 'package:agixt/utils/lc3.dart';
import 'package:flutter/foundation.dart';
import 'package:mutex/mutex.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added import
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

// Command response status codes
const int RESPONSE_SUCCESS = 0xC9;
const int RESPONSE_FAILURE = 0xCA;

class BluetoothReciever {
  static final BluetoothReciever singleton = BluetoothReciever._internal();

  final voiceCollectorAI = VoiceDataCollector();

  // Speech to text setup
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';
  // ---

  factory BluetoothReciever() {
    return singleton;
  }

  BluetoothReciever._internal() {
    _initSpeech(); // Initialize speech recognition
  }

  /// This has to happen only once per app. Returns true if successful.
  Future<bool> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: _onSpeechStatus,
      );
      debugPrint("Speech recognition initialized: $_speechEnabled");
    } catch (e) {
      debugPrint("Error initializing speech recognition: $e");
      _speechEnabled = false;
    }
    return _speechEnabled;
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    if (!_speechEnabled) {
      debugPrint('Speech recognition not enabled');
      return;
    }
    if (_isListening) {
      debugPrint('Already listening');
      return;
    }
    debugPrint('Starting speech recognition listener');
    _lastWords = '';
    // TODO: Consider locale from settings? speech_to_text uses system default
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 60), // Adjust timeout as needed
      pauseFor: const Duration(seconds: 5), // Adjust pause duration
      // partialResults: true, // Enable if needed
    );
    _isListening = true; // Set listening status based on callback?
  }

  /// Stop the recognition session
  void _stopListening() async {
    if (!_isListening) {
      debugPrint('Not currently listening');
      return;
    }
    debugPrint('Stopping speech recognition listener');
    await _speechToText.stop();
    _isListening = false; // Set listening status based on callback?
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognition results.
  void _onSpeechResult(SpeechRecognitionResult result) async {
    _lastWords = result.recognizedWords;
    debugPrint('Speech Result: $_lastWords, Final: ${result.finalResult}');

    if (result.finalResult) {
      _isListening = false; // Recognition finished
      if (_lastWords.isNotEmpty) {
        debugPrint('Final transcription: $_lastWords');
        // Use appropriate AIService method based on background mode
        final aiService = AIService.singleton;
        if (aiService.isBackgroundMode) {
          await aiService.processVoiceCommandBackground(_lastWords);
        } else {
          await aiService.processVoiceCommand(_lastWords);
        }
      } else {
        debugPrint('Final transcription is empty.');
      }
    }
  }

  /// Handle status changes from the speech recognition engine
  void _onSpeechStatus(String status) {
    debugPrint('Speech Recognition Status: $status');
    // Update _isListening based on status if needed, e.g., 'listening', 'notListening', 'done'
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
    } else if (status == 'listening') {
      _isListening = true;
    }
  }

  // Helper to check if local transcription is configured
  Future<bool> _isLocalTranscriptionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final remoteUrl = prefs.getString('whisper_api_url');
    return remoteUrl == null || remoteUrl.isEmpty;
  }

  Future<void> receiveHandler(GlassSide side, List<int> data) async {
    if (data.isEmpty) return;

    int command = data[0];

    switch (command) {
      case Commands.HEARTBEAT:
        break;
      case Commands.START_AI:
        if (data.length >= 2) {
          int subcmd = data[1];
          handleEvenAICommand(side, subcmd);
        }
        break;

      case Commands.MIC_RESPONSE: // Mic Response
        if (data.length >= 3) {
          int status = data[1];
          int enable = data[2];
          handleMicResponse(side, status, enable);
        }
        break;

      case Commands.RECEIVE_MIC_DATA: // Voice Data
        if (data.length >= 2) {
          int seq = data[1];
          List<int> voiceData = data.sublist(2);
          handleVoiceData(side, seq, voiceData);
        }
        break;
      case Commands.GET_BATTERY: // Battery Response
        // Battery responses are handled directly in the Glass class
        // This case is here for completeness and potential future use
        debugPrint(
          '[$side] Battery response received in receiver: ${data.map((e) => '0x${e.toRadixString(16).padLeft(2, '0')}').join(' ')}',
        );
        break;
      case Commands.QUICK_NOTE:
        handleQuickNoteCommand(side, data);
        break;
      case Commands.QUICK_NOTE_ADD:
        handleQuickNoteAudioData(side, data);
        break;

      default:
        debugPrint('[$side] Unknown command: 0x${command.toRadixString(16)}');
    }
  }

  void handleEvenAICommand(GlassSide side, int subcmd) async {
    final bt = BluetoothManager();
    switch (subcmd) {
      case 0:
        debugPrint('[$side] Exit to dashboard manually');
        await bt.setMicrophone(false);
        voiceCollectorAI.isRecording = false;
        voiceCollectorAI.reset();
        break;
      case 1:
        debugPrint(
          '[$side] Page ${side == GlassSide.left ? 'up' : 'down'} control',
        );
        await bt.setMicrophone(false);
        voiceCollectorAI.isRecording = false;
        break;
      case 23:
        // Subcmd 23 (0x17) = TouchPad pressed and held
        if (side == GlassSide.right) {
          // Right side: toggle conversation recording with diarization
          debugPrint('[$side] Right touchpad press, toggling conversation recording');
          await AIService.singleton.handleSideButtonPress();
        } else {
          // Left side: start AI chat recording (hold-to-record)
          debugPrint('[$side] Start AGiXT AI Chat');
          if (await _isLocalTranscriptionEnabled()) {
            debugPrint('[$side] Using local speech_to_text');
            if (!_speechEnabled) {
              debugPrint('Speech not enabled, attempting init...');
              await _initSpeech();
            }
            if (_speechEnabled) {
              _startListening();
            } else {
              debugPrint('Speech could not be enabled, cannot start listener.');
            }
            await bt.setMicrophone(true);
          } else {
            debugPrint('[$side] Using remote Whisper, starting recording buffer');
            voiceCollectorAI.reset();
            voiceCollectorAI.isRecording = true;
            await bt.setMicrophone(true);
          }
        }
        break;
      case 24:
        // Subcmd 24 (0x18) = TouchPad pressed and released
        if (side == GlassSide.right) {
          // Right side: ignore release event — conversation toggle is handled
          // entirely by the press event (subcmd 23) or quick note handler.
          debugPrint('[$side] Right touchpad release, ignoring (toggle on press)');
        } else {
          // Left side: stop recording, transcribe, and send for chat completion
          debugPrint('[$side] Stop AGiXT recording');
          if (await _isLocalTranscriptionEnabled()) {
            debugPrint('[$side] Stopping local speech_to_text listener');
            _stopListening();
            await bt.setMicrophone(false);
          } else {
            debugPrint('[$side] Stopping remote Whisper recording buffer');
            voiceCollectorAI.isRecording = false;
            await bt.setMicrophone(false);

            List<int> completeVoiceData =
                await voiceCollectorAI.getAllDataAndReset();
            if (completeVoiceData.isEmpty) {
              debugPrint('[$side] No voice data collected for remote Whisper');
              return;
            }
            debugPrint(
              '[$side] Voice data collected for remote: ${completeVoiceData.length} bytes',
            );

            final pcm = await LC3.decodeLC3(
              Uint8List.fromList(completeVoiceData),
            );
            debugPrint(
              '[$side] Voice data decoded for remote: ${pcm.length} bytes',
            );

            if (pcm.isEmpty) {
              debugPrint(
                '[$side] Decoded PCM data is empty, skipping transcription.',
              );
              return;
            }

            final startTime = DateTime.now();
            try {
              final transcription =
                  await (await WhisperService.service()).transcribe(pcm);
              final endTime = DateTime.now();

              debugPrint('[$side] Remote Transcription: $transcription');
              debugPrint(
                '[$side] Remote Transcription took: ${endTime.difference(startTime).inSeconds} seconds',
              );

              if (transcription.isNotEmpty) {
                final aiService = AIService.singleton;
                if (aiService.isBackgroundMode) {
                  await aiService.processVoiceCommandBackground(transcription);
                } else {
                  await aiService.processVoiceCommand(transcription);
                }
              } else {
                debugPrint('[$side] Remote transcription was empty.');
              }
            } catch (e) {
              debugPrint('[$side] Error during remote transcription: $e');
            }
          }
        }
        break;

      default:
        debugPrint('[$side] Unknown AGiXT subcommand: $subcmd');
    }
  }

  void handleMicResponse(GlassSide side, int status, int enable) {
    if (status == RESPONSE_SUCCESS) {
      debugPrint(
        '[$side] Mic ${enable == 1 ? "enabled" : "disabled"} successfully',
      );
    } else if (status == RESPONSE_FAILURE) {
      debugPrint('[$side] Failed to ${enable == 1 ? "enable" : "disable"} mic');
      final bt = BluetoothManager();
      bt.setMicrophone(enable == 1);
    }
  }

  // Make this function async
  Future<void> handleVoiceData(
    GlassSide side,
    int seq,
    List<int> voiceData,
  ) async {
    debugPrint(
      '[$side] Received voice data chunk: seq=$seq, length=${voiceData.length}',
    );

    final isLocalEnabled = await _isLocalTranscriptionEnabled();
    final isRecording = voiceCollectorAI.isRecording;
    debugPrint(
        '[$side] Voice data: isLocalEnabled=$isLocalEnabled, voiceCollectorAI.isRecording=$isRecording');

    // Only add to buffer if using remote whisper (i.e., local is NOT enabled)
    if (!isLocalEnabled && isRecording) {
      debugPrint('[$side] Adding voice chunk to collector');
      voiceCollectorAI.addChunk(seq, voiceData);
    } else if (isLocalEnabled) {
      // If local, we don't buffer here, speech_to_text uses the mic directly.
      // The logic in handleEvenAICommand case 23/24 handles mic enabling/disabling.
      // No action needed here for the voice data itself when using local STT.
      debugPrint('[$side] Local transcription enabled, not buffering');
    } else {
      debugPrint('[$side] Not recording, discarding voice data');
    }

    // This check seems redundant now as stop command (24) handles mic disabling
    // final bt = BluetoothManager();
    // if (!voiceCollectorAI.isRecording && ! _isListening) { // Check both states
    //   bt.setMicrophone(false);
    // }
  }

  void handleQuickNoteCommand(GlassSide side, List<int> data) {
    // Right-side quick note events are used to toggle conversation recording
    // with speaker diarization and summarization instead of the built-in
    // quick notes feature.
    debugPrint('[$side] Quick note event received, toggling conversation recording');
    AIService.singleton.handleSideButtonPress();
  }

  void handleQuickNoteAudioData(GlassSide side, List<int> data) async {
    // Quick note audio data is no longer fetched — the right-side touchpad
    // now triggers conversation recording instead. Discard any stale packets.
    debugPrint('[$side] Discarding quick note audio data (conversation mode active)');
  }

  /// Dispose of all resources to prevent memory leaks
  void dispose() {
    _stopListening();
    // Note: speech_to_text doesn't require explicit disposal
  }
}

// Voice data buffer to collect chunks
class VoiceDataCollector {
  final Map<int, List<int>> _chunks = {};
  int seqAdd = 0;
  final m = Mutex();

  bool isRecording = false;

  Future<void> addChunk(int seq, List<int> data) async {
    await m.acquire();
    if (seq == 255) {
      seqAdd += 255;
    }
    _chunks[seqAdd + seq] = data;
    m.release();
  }

  List<int> getAllData() {
    List<int> complete = [];
    final keys = _chunks.keys.toList()..sort();

    for (int key in keys) {
      complete.addAll(_chunks[key]!);
    }
    return complete;
  }

  Future<List<int>> getAllDataAndReset() async {
    await m.acquire();
    final data = getAllData();
    reset();
    m.release();

    return data;
  }

  /// Get a snapshot of all buffered data without clearing the buffer.
  /// Used for periodic live transcription during ongoing recording.
  Future<List<int>> getBufferedDataSnapshot() async {
    await m.acquire();
    final data = getAllData();
    m.release();
    return data;
  }

  void reset() {
    _chunks.clear();
    seqAdd = 0;
  }
}
