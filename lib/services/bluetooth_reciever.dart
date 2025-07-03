import 'package:agixt/models/agixt/checklist.dart';
import 'package:agixt/models/g1/glass.dart';
import 'package:agixt/models/g1/commands.dart';
import 'package:agixt/models/g1/voice_note.dart';
import 'package:agixt/models/voice/voice_commands.dart';
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
  final voiceCollectorNote = VoiceDataCollector();

  // Speech to text setup
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';
  // ---

  final rightVoiceCommands = VoiceCommandHelper(commands: [
    VoiceCommand(
        command: "open checklist",
        phrases: [
          "checklist",
          "check list",
          "open checklist",
          "open check list"
        ],
        fn: (String listName) {
          final list = AGiXTChecklist.displayChecklistFor(listName);
          final bt = BluetoothManager();
          if (list != null) {
            bt.sync();
          } else {
            bt.sendText('No checklist found for "$listName"');
          }
        }),
    VoiceCommand(
        command: "close checklist",
        phrases: [
          "close checklist",
          "close check list",
          "closed checklist",
          "closed check list"
        ],
        fn: (String listName) {
          final list = AGiXTChecklist.hideChecklistFor(listName);
          final bt = BluetoothManager();
          if (list != null) {
            bt.sync();
          } else {
            bt.sendText('No checklist found for "$listName"');
          }
        })
  ]);

  int _syncId = 0;

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
        // Use AIService to send transcription to AGiXT Chat
        await AIService.singleton.processVoiceCommand(_lastWords);
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
        debugPrint('[$side] Page ${side == 'left' ? 'up' : 'down'} control');
        await bt.setMicrophone(false);
        voiceCollectorAI.isRecording = false;
        break;
      case 23:
        debugPrint('[$side] Start AGiXT AI Chat');
        if (await _isLocalTranscriptionEnabled()) {
          debugPrint('[$side] Using local speech_to_text');
          if (!_speechEnabled) {
            debugPrint('Speech not enabled, attempting init...');
            await _initSpeech(); // Ensure initialized (now returns Future<bool>)
          }
          if (_speechEnabled) {
            // Start listening only if enabled
            _startListening();
          } else {
            debugPrint('Speech could not be enabled, cannot start listener.');
            // Optionally provide feedback to the user/device
          }
          // We might still need to enable the glasses mic for the system recognizer
          await bt.setMicrophone(true);
        } else {
          debugPrint('[$side] Using remote Whisper, starting recording buffer');
          voiceCollectorAI.reset(); // Reset buffer before starting
          voiceCollectorAI.isRecording = true;
          await bt.setMicrophone(true);
        }
        break;
      case 24:
        debugPrint('[$side] Stop AGiXT recording');
        if (await _isLocalTranscriptionEnabled()) {
          debugPrint('[$side] Stopping local speech_to_text listener');
          _stopListening();
          // Mic might be stopped automatically by speech_to_text, or we might need to stop it.
          // Let's explicitly stop it for now.
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
              '[$side] Voice data collected for remote: ${completeVoiceData.length} bytes');

          final pcm =
              await LC3.decodeLC3(Uint8List.fromList(completeVoiceData));
          debugPrint(
              '[$side] Voice data decoded for remote: ${pcm.length} bytes');

          if (pcm.isEmpty) {
            debugPrint(
                '[$side] Decoded PCM data is empty, skipping transcription.');
            return;
          }

          final startTime = DateTime.now();
          try {
            final transcription =
                await (await WhisperService.service()).transcribe(pcm);
            final endTime = DateTime.now();

            debugPrint('[$side] Remote Transcription: $transcription');
            debugPrint(
                '[$side] Remote Transcription took: ${endTime.difference(startTime).inSeconds} seconds');

            // Use AIService to send transcription to AGiXT Chat
            if (transcription.isNotEmpty) {
              await AIService.singleton.processVoiceCommand(transcription);
            } else {
              debugPrint('[$side] Remote transcription was empty.');
            }
          } catch (e) {
            debugPrint('[$side] Error during remote transcription: $e');
            // Optionally send error message back to user/device
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
          '[$side] Mic ${enable == 1 ? "enabled" : "disabled"} successfully');
    } else if (status == RESPONSE_FAILURE) {
      debugPrint('[$side] Failed to ${enable == 1 ? "enable" : "disable"} mic');
      final bt = BluetoothManager();
      bt.setMicrophone(enable == 1);
    }
  }

  // Make this function async
  Future<void> handleVoiceData(
      GlassSide side, int seq, List<int> voiceData) async {
    debugPrint(
        '[$side] Received voice data chunk: seq=$seq, length=${voiceData.length}');
    // Only add to buffer if using remote whisper (i.e., local is NOT enabled)
    if (!await _isLocalTranscriptionEnabled() && voiceCollectorAI.isRecording) {
      voiceCollectorAI.addChunk(seq, voiceData);
    } else if (await _isLocalTranscriptionEnabled()) {
      // If local, we don't buffer here, speech_to_text uses the mic directly.
      // The logic in handleEvenAICommand case 23/24 handles mic enabling/disabling.
      // No action needed here for the voice data itself when using local STT.
    }

    // This check seems redundant now as stop command (24) handles mic disabling
    // final bt = BluetoothManager();
    // if (!voiceCollectorAI.isRecording && ! _isListening) { // Check both states
    //   bt.setMicrophone(false);
    // }
  }

  void handleQuickNoteCommand(GlassSide side, List<int> data) {
    try {
      final notif = VoiceNoteNotification(Uint8List.fromList(data));
      debugPrint('Voice note notification: ${notif.entries.length} entries');
      for (VoiceNote entry in notif.entries) {
        debugPrint(
            'Voice note: index=${entry.index}, timestamp=${entry.timestamp}');
      }
      if (notif.entries.isNotEmpty) {
        // fetch newest note
        voiceCollectorNote.reset();
        final entry = notif.entries.first;
        final bt = BluetoothManager();
        bt.rightGlass!.sendData(entry.buildFetchCommand(_syncId++));
      }
    } catch (e) {
      debugPrint('Failed to parse voice note notification: $e');
    }
  }

  void handleQuickNoteAudioData(GlassSide side, List<int> data) async {
    if (data.length > 4 && data[4] != 0x02) {
      final dataStr = data.map((e) => e.toRadixString(16)).join(' ');
      debugPrint('[$side] not an audio data packet: $dataStr');
      return;
    }
    /*  audio_response_packet_buf[0] = 0x1E;
    audio_response_packet_buf[1] = audio_chunk_size + 10; // total packet length
    audio_response_packet_buf[2] = 0; // possibly packet-length extended to uint16_t
    audio_response_packet_buf[3] = audio_sync_id++;
    audio_response_packet_buf[4] = 2; // unknown, always 2
    *(uint16_t*)&audio_response_packet_buf[5] = total_number_of_packets_for_audio;
    *(uint16_t*)&audio_response_packet_buf[7] = ++current_packet_number;
    audio_response_packet_buf[9] = audio_index_in_flash + 1;
    audio_response_packet_buf[10 .. n] = <audio-data>
    */
    if (data.length < 11) {
      final dataStr = data.map((e) => e.toRadixString(16)).join(' ');
      debugPrint('[$side] Invalid audio data packet: $dataStr');
      return;
    }

    int seq = data[3];
    int totalPackets = (data[5] << 8) | data[4];
    int currentPacket = (data[7] << 8) | data[6];
    int index = data[9] - 1;
    List<int> voiceData = data.sublist(10);

    debugPrint('[$side] Note Audio data packet: seq=$seq, total=$totalPackets, '
        'current=$currentPacket, length=${voiceData.length}');
    voiceCollectorNote.addChunk(seq, voiceData);

    if (currentPacket + 2 == totalPackets) {
      debugPrint('[$side] Last packet received');
      final completeVoiceData = voiceCollectorNote.getAllData();

      final pcm = await LC3.decodeLC3(Uint8List.fromList(completeVoiceData));

      debugPrint('[$side] Voice data decoded: ${pcm.length} bytes');

      voiceCollectorNote.reset();
      final bt = BluetoothManager();
      await bt.rightGlass!
          .sendData(VoiceNote(index: index + 1).buildDeleteCommand(_syncId++));

      final startTime = DateTime.now();
      final transcription =
          await (await WhisperService.service()).transcribe(pcm);
      final endTime = DateTime.now();

      debugPrint('[$side] Transcription: $transcription');
      debugPrint(
          '[$side] Transcription took: ${endTime.difference(startTime).inSeconds} seconds');
      try {
        rightVoiceCommands.parseCommand(transcription);
      } catch (e) {
        bt.sendText(e.toString());
      }
    }
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

  void reset() {
    _chunks.clear();
    seqAdd = 0;
  }
}
