import 'dart:async';
import 'dart:typed_data';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/services/bluetooth_reciever.dart';
import 'package:agixt/services/watch_service.dart';
import 'package:agixt/services/wake_word_service.dart';
import 'package:agixt/utils/lc3.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Enum for voice input sources
enum VoiceInputSource {
  glasses, // Even Realities G1 glasses microphone
  watch, // Pixel Watch microphone
  phone, // Phone's built-in microphone
}

/// Service that manages voice input from multiple sources
/// Priority: Glasses > Watch > Phone
class VoiceInputService {
  static final VoiceInputService singleton = VoiceInputService._internal();
  factory VoiceInputService() => singleton;
  VoiceInputService._internal();

  // Dependencies
  final BluetoothManager _bluetoothManager = BluetoothManager.singleton;
  final WatchService _watchService = WatchService.singleton;
  final WakeWordService _wakeWordService = WakeWordService.singleton;

  // Phone audio recorder
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _recorderInitialized = false;

  // Bluetooth receiver for glasses audio
  final BluetoothReciever _bluetoothReciever = BluetoothReciever.singleton;

  // State
  bool _isRecording = false;
  VoiceInputSource? _activeSource;
  String? _recordingPath;
  Timer? _recordingTimer; // Timer for auto-stop

  // Settings
  VoiceInputSource _preferredSource = VoiceInputSource.glasses;
  bool _useWakeWord = false;

  // Stream controllers
  final StreamController<VoiceInputState> _stateController =
      StreamController<VoiceInputState>.broadcast();
  final StreamController<Uint8List> _audioChunkController =
      StreamController<Uint8List>.broadcast();

  // Public getters
  bool get isRecording => _isRecording;
  VoiceInputSource? get activeSource => _activeSource;
  Stream<VoiceInputState> get stateStream => _stateController.stream;
  Stream<Uint8List> get audioChunkStream => _audioChunkController.stream;

  /// Initialize the voice input service
  Future<void> initialize() async {
    debugPrint('VoiceInputService: Initializing...');

    // Load settings
    final prefs = await SharedPreferences.getInstance();
    final sourceStr = prefs.getString('voice_input_source') ?? 'glasses';
    _preferredSource = VoiceInputSource.values.firstWhere(
      (e) => e.name == sourceStr,
      orElse: () => VoiceInputSource.glasses,
    );
    _useWakeWord = prefs.getBool('wake_word_enabled') ?? false;

    // Initialize phone recorder
    await _initializeRecorder();

    // Note: Glasses audio is handled by BluetoothReciever.voiceCollectorAI
    // No additional setup needed here

    // Note: Wake word callback is handled by AIService which coordinates
    // the full flow (recording -> transcription -> AGiXT -> response)
    // Do NOT set up a callback here to avoid race conditions

    debugPrint(
      'VoiceInputService: Initialized with preferred source: $_preferredSource',
    );
  }

  Future<void> _initializeRecorder() async {
    if (_recorderInitialized) return;

    try {
      await _recorder.openRecorder();
      _recorderInitialized = true;
      debugPrint('VoiceInputService: Phone recorder initialized');
    } catch (e) {
      debugPrint('VoiceInputService: Failed to initialize phone recorder: $e');
    }
  }

  // Note: Glasses audio is collected by BluetoothReciever.voiceCollectorAI
  // when the mic is enabled. We get the data via getAllDataAndReset() in
  // _stopGlassesRecording().

  // Note: Wake word detection is handled by AIService which listens to
  // WakeWordService.eventStream and coordinates the full voice input flow.
  // This avoids race conditions from multiple listeners.

  /// Get the best available voice input source
  VoiceInputSource getBestAvailableSource() {
    // Check glasses first (highest priority)
    if (_bluetoothManager.isConnected) {
      return VoiceInputSource.glasses;
    }

    // Check watch second (fallback)
    if (_watchService.isConnected) {
      return VoiceInputSource.watch;
    }

    // Phone is always available
    return VoiceInputSource.phone;
  }

  /// Check if a specific source is available
  bool isSourceAvailable(VoiceInputSource source) {
    switch (source) {
      case VoiceInputSource.glasses:
        return _bluetoothManager.isConnected;
      case VoiceInputSource.watch:
        return _watchService.isConnected;
      case VoiceInputSource.phone:
        return true;
    }
  }

  /// Set the preferred voice input source
  Future<void> setPreferredSource(VoiceInputSource source) async {
    _preferredSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_input_source', source.name);
    debugPrint('VoiceInputService: Preferred source set to $source');
  }

  /// Start recording audio from the best available source
  Future<bool> startRecording({
    Duration maxDuration = const Duration(seconds: 10),
    VoiceInputSource? forcedSource,
  }) async {
    if (_isRecording) {
      debugPrint('VoiceInputService: Already recording');
      return false;
    }

    // Determine which source to use
    final source = forcedSource ?? _preferredSource;
    VoiceInputSource actualSource;

    // Check if preferred source is available, otherwise fall back
    if (isSourceAvailable(source)) {
      actualSource = source;
    } else {
      actualSource = getBestAvailableSource();
      debugPrint(
        'VoiceInputService: $source not available, falling back to $actualSource',
      );
    }

    _activeSource = actualSource;
    _isRecording = true;

    _stateController.add(
      VoiceInputState(
        isRecording: true,
        source: actualSource,
        status: VoiceInputStatus.recording,
      ),
    );

    // Pause wake word detection during recording
    if (_useWakeWord) {
      await _wakeWordService.pause();
    }

    debugPrint('VoiceInputService: Starting recording from $actualSource');

    try {
      switch (actualSource) {
        case VoiceInputSource.glasses:
          return await _startGlassesRecording(maxDuration);
        case VoiceInputSource.watch:
          return await _startWatchRecording(maxDuration);
        case VoiceInputSource.phone:
          return await _startPhoneRecording(maxDuration);
      }
    } catch (e) {
      debugPrint('VoiceInputService: Error starting recording: $e');
      _isRecording = false;
      _activeSource = null;

      _stateController.add(
        VoiceInputState(
          isRecording: false,
          source: actualSource,
          status: VoiceInputStatus.error,
          error: e.toString(),
        ),
      );

      return false;
    }
  }

  /// Start recording from glasses microphone
  Future<bool> _startGlassesRecording(Duration maxDuration) async {
    try {
      // Reset voice collector buffer before starting
      _bluetoothReciever.voiceCollectorAI.reset();
      _bluetoothReciever.voiceCollectorAI.isRecording = true;
      debugPrint('VoiceInputService: voiceCollectorAI.isRecording set to true');

      // Enable microphone on glasses
      await _bluetoothManager.setMicrophone(true);
      debugPrint('VoiceInputService: Glasses mic enabled, recording started for $maxDuration');

      // Cancel any existing timer
      _recordingTimer?.cancel();
      
      // Set up auto-stop timer with proper async handling
      _recordingTimer = Timer(maxDuration, () async {
        debugPrint('VoiceInputService: Timer fired, _isRecording=$_isRecording, _activeSource=$_activeSource');
        if (_isRecording && _activeSource == VoiceInputSource.glasses) {
          debugPrint('VoiceInputService: Auto-stopping glasses recording after $maxDuration');
          await stopRecording();
        } else {
          debugPrint('VoiceInputService: Timer fired but conditions not met for stop');
        }
      });

      return true;
    } catch (e) {
      debugPrint('VoiceInputService: Error starting glasses recording: $e');
      _bluetoothReciever.voiceCollectorAI.isRecording = false;
      return false;
    }
  }

  /// Start recording from watch microphone
  Future<bool> _startWatchRecording(Duration maxDuration) async {
    try {
      final audioData = await _watchService.startRecording(
        maxDuration: maxDuration,
        sampleRate: 16000,
      );

      if (audioData != null) {
        await _handleRecordingComplete(audioData);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('VoiceInputService: Error starting watch recording: $e');
      return false;
    }
  }

  /// Start recording from phone microphone
  Future<bool> _startPhoneRecording(Duration maxDuration) async {
    if (!_recorderInitialized) {
      await _initializeRecorder();
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      _recordingPath =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );

      // Set up auto-stop timer
      Timer(maxDuration, () {
        if (_isRecording && _activeSource == VoiceInputSource.phone) {
          stopRecording();
        }
      });

      return true;
    } catch (e) {
      debugPrint('VoiceInputService: Error starting phone recording: $e');
      return false;
    }
  }

  /// Stop the current recording
  Future<Uint8List?> stopRecording() async {
    debugPrint('VoiceInputService: stopRecording called, _isRecording=$_isRecording');
    
    if (!_isRecording) {
      debugPrint('VoiceInputService: Not recording, returning null');
      return null;
    }

    // Cancel the recording timer
    _recordingTimer?.cancel();
    _recordingTimer = null;

    debugPrint('VoiceInputService: Stopping recording from $_activeSource');

    Uint8List? audioData;

    try {
      switch (_activeSource) {
        case VoiceInputSource.glasses:
          debugPrint('VoiceInputService: Calling _stopGlassesRecording');
          audioData = await _stopGlassesRecording();
          debugPrint('VoiceInputService: _stopGlassesRecording returned ${audioData?.length ?? 0} bytes');
          break;
        case VoiceInputSource.watch:
          await _watchService.stopRecording();
          // Audio data is returned via callback
          break;
        case VoiceInputSource.phone:
          audioData = await _stopPhoneRecording();
          break;
        case null:
          break;
      }
    } catch (e) {
      debugPrint('VoiceInputService: Error stopping recording: $e');
    }

    _isRecording = false;
    final source = _activeSource;
    _activeSource = null;

    final status = audioData != null
        ? VoiceInputStatus.complete
        : VoiceInputStatus.stopped;
    
    debugPrint('VoiceInputService: Emitting state - status=$status, audioData=${audioData?.length ?? 0} bytes');

    // Use 'complete' status when we have audio data so AIService processes it
    _stateController.add(
      VoiceInputState(
        isRecording: false,
        source: source,
        status: status,
        audioData: audioData,
      ),
    );

    // Resume wake word detection
    if (_useWakeWord) {
      await _wakeWordService.resume();
    }

    return audioData;
  }

  /// Stop glasses recording
  Future<Uint8List?> _stopGlassesRecording() async {
    debugPrint('VoiceInputService: _stopGlassesRecording called');
    try {
      // Stop recording and disable mic
      debugPrint('VoiceInputService: Setting voiceCollectorAI.isRecording = false');
      _bluetoothReciever.voiceCollectorAI.isRecording = false;
      
      debugPrint('VoiceInputService: Disabling glasses mic');
      await _bluetoothManager.setMicrophone(false);

      // Get all collected voice data (LC3 encoded)
      debugPrint('VoiceInputService: Getting voice data from collector');
      final lc3Data =
          await _bluetoothReciever.voiceCollectorAI.getAllDataAndReset();

      if (lc3Data.isEmpty) {
        debugPrint('VoiceInputService: No voice data collected from glasses (lc3Data is empty)');
        return null;
      }

      debugPrint(
          'VoiceInputService: Got ${lc3Data.length} bytes of LC3 data from glasses');

      // Decode LC3 to PCM
      debugPrint('VoiceInputService: Decoding LC3 to PCM');
      final pcmData = await LC3.decodeLC3(Uint8List.fromList(lc3Data));

      if (pcmData.isEmpty) {
        debugPrint('VoiceInputService: LC3 decode returned empty PCM data');
        return null;
      }

      debugPrint(
          'VoiceInputService: Decoded to ${pcmData.length} bytes of PCM audio');
      return pcmData;
    } catch (e) {
      debugPrint('VoiceInputService: Error stopping glasses recording: $e');
      _bluetoothReciever.voiceCollectorAI.isRecording = false;
      return null;
    }
  }

  /// Stop phone recording
  Future<Uint8List?> _stopPhoneRecording() async {
    try {
      await _recorder.stopRecorder();

      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          final audioData = await file.readAsBytes();
          await file.delete(); // Clean up temp file
          return audioData;
        }
      }

      return null;
    } catch (e) {
      debugPrint('VoiceInputService: Error stopping phone recording: $e');
      return null;
    }
  }

  /// Handle recording complete callback
  Future<void> _handleRecordingComplete(Uint8List? audioData) async {
    _isRecording = false;
    final source = _activeSource;
    _activeSource = null;

    _stateController.add(
      VoiceInputState(
        isRecording: false,
        source: source,
        status: VoiceInputStatus.complete,
        audioData: audioData,
      ),
    );

    // Resume wake word detection
    if (_useWakeWord) {
      await _wakeWordService.resume();
    }
  }

  /// Get the display name for a voice input source
  static String getSourceDisplayName(VoiceInputSource source) {
    switch (source) {
      case VoiceInputSource.glasses:
        return 'Even Realities Glasses';
      case VoiceInputSource.watch:
        return 'Pixel Watch';
      case VoiceInputSource.phone:
        return 'Phone Microphone';
    }
  }

  /// Dispose of the service
  void dispose() {
    _recorder.closeRecorder();
    _stateController.close();
    _audioChunkController.close();
  }
}

/// Status of voice input
enum VoiceInputStatus { idle, recording, processing, complete, stopped, error }

/// Voice input state
class VoiceInputState {
  final bool isRecording;
  final VoiceInputSource? source;
  final VoiceInputStatus status;
  final Uint8List? audioData;
  final String? error;

  VoiceInputState({
    required this.isRecording,
    this.source,
    required this.status,
    this.audioData,
    this.error,
  });
}
