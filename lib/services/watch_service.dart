import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing Pixel Watch (Wear OS) connectivity
/// Provides TTS output and microphone input capabilities
class WatchService {
  static final WatchService singleton = WatchService._internal();
  factory WatchService() => singleton;
  WatchService._internal();

  // Method channels for native Wear OS communication
  static const MethodChannel _watchChannel = MethodChannel(
    'dev.agixt.agixt/watch',
  );
  static const EventChannel _watchEventsChannel = EventChannel(
    'dev.agixt.agixt/watch_events',
  );

  // Connection state
  bool _isConnected = false;
  bool _isEnabled = true;
  String? _connectedWatchId;
  String? _connectedWatchName;

  // Audio recording state
  bool _isRecording = false;
  Completer<Uint8List?>? _audioCompleter;

  // TTS state
  bool _isSpeaking = false;

  // Stream controllers
  final StreamController<WatchConnectionState> _connectionStateController =
      StreamController<WatchConnectionState>.broadcast();
  final StreamController<WatchAudioData> _audioDataController =
      StreamController<WatchAudioData>.broadcast();
  final StreamController<WatchTTSState> _ttsStateController =
      StreamController<WatchTTSState>.broadcast();

  // Streams
  Stream<WatchConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<WatchAudioData> get audioDataStream => _audioDataController.stream;
  Stream<WatchTTSState> get ttsStateStream => _ttsStateController.stream;

  // Getters
  bool get isConnected => _isConnected && _isEnabled;
  bool get isEnabled => _isEnabled;
  bool get isRecording => _isRecording;
  bool get isSpeaking => _isSpeaking;
  String? get connectedWatchId => _connectedWatchId;
  String? get connectedWatchName => _connectedWatchName;

  StreamSubscription? _eventSubscription;

  /// Initialize the watch service
  Future<void> initialize() async {
    debugPrint('WatchService: Initializing...');

    // Load enabled state from preferences
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('watch_enabled') ?? true;

    // Set up method call handler for incoming events from watch
    _watchChannel.setMethodCallHandler(_handleMethodCall);

    // Set up event channel listener
    _eventSubscription = _watchEventsChannel.receiveBroadcastStream().listen(
      _handleWatchEvent,
      onError: _handleEventError,
    );

    // Initialize native watch handler
    try {
      await _watchChannel.invokeMethod('initialize');
    } on PlatformException catch (e) {
      debugPrint('WatchService: Error initializing native handler: $e');
    } on MissingPluginException {
      debugPrint('WatchService: Native watch handler not available');
    }

    // Check if a watch is already connected
    await _checkWatchConnection();

    debugPrint('WatchService: Initialized, enabled=$_isEnabled');
  }

  /// Handle method calls from native code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWatchConnected':
        _handleWatchConnected(
          call.arguments['watchId'] as String?,
          call.arguments['watchName'] as String?,
        );
        return true;

      case 'onWatchDisconnected':
        _handleWatchDisconnected();
        return true;

      case 'onAudioData':
        final audioData = call.arguments['audioData'] as Uint8List?;
        if (audioData != null) {
          _handleAudioData(audioData);
        }
        return true;

      case 'onAudioRecordingComplete':
        final audioData = call.arguments['audioData'] as Uint8List?;
        _handleAudioRecordingComplete(audioData);
        return true;

      case 'onTTSComplete':
        _handleTTSComplete();
        return true;

      case 'onTTSError':
        final error = call.arguments['error'] as String?;
        _handleTTSError(error);
        return true;

      case 'onWakeWordDetected':
        // Wake word detected on watch - forward to wake word service
        debugPrint('WatchService: Wake word detected on watch');
        return true;

      default:
        debugPrint('WatchService: Unknown method call: ${call.method}');
        return null;
    }
  }

  /// Handle events from the event channel
  void _handleWatchEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'] as String?;
      switch (type) {
        case 'connection_changed':
          if (event['connected'] == true) {
            _handleWatchConnected(
              event['watchId'] as String?,
              event['watchName'] as String?,
            );
          } else {
            _handleWatchDisconnected();
          }
          break;

        case 'audio_chunk':
          final data = event['data'];
          if (data is Uint8List) {
            _handleAudioData(data);
          }
          break;

        case 'battery_level':
          debugPrint('WatchService: Watch battery level: ${event['level']}%');
          break;
      }
    }
  }

  void _handleEventError(dynamic error) {
    debugPrint('WatchService: Event channel error: $error');
  }

  /// Check if a Wear OS watch is connected
  Future<void> _checkWatchConnection() async {
    try {
      final result = await _watchChannel.invokeMethod('isWatchConnected');
      if (result is Map) {
        _isConnected = result['connected'] == true;
        _connectedWatchId = result['watchId'] as String?;
        _connectedWatchName = result['watchName'] as String?;

        if (_isConnected) {
          debugPrint(
            'WatchService: Watch connected - $_connectedWatchName ($_connectedWatchId)',
          );
          _connectionStateController.add(
            WatchConnectionState(
              isConnected: true,
              watchId: _connectedWatchId,
              watchName: _connectedWatchName,
            ),
          );
        }
      }
    } on PlatformException catch (e) {
      debugPrint('WatchService: Error checking watch connection: $e');
      _isConnected = false;
    } on MissingPluginException {
      debugPrint('WatchService: Watch service not available on this platform');
      _isConnected = false;
    }
  }

  void _handleWatchConnected(String? watchId, String? watchName) {
    debugPrint('WatchService: Watch connected - $watchName ($watchId)');
    _isConnected = true;
    _connectedWatchId = watchId;
    _connectedWatchName = watchName;

    _connectionStateController.add(
      WatchConnectionState(
        isConnected: true,
        watchId: watchId,
        watchName: watchName,
      ),
    );
  }

  void _handleWatchDisconnected() {
    debugPrint('WatchService: Watch disconnected');
    _isConnected = false;
    _connectedWatchId = null;
    _connectedWatchName = null;

    // Cancel any ongoing audio recording
    if (_audioCompleter != null && !_audioCompleter!.isCompleted) {
      _audioCompleter!.complete(null);
    }
    _isRecording = false;

    _connectionStateController.add(
      WatchConnectionState(isConnected: false, watchId: null, watchName: null),
    );
  }

  void _handleAudioData(Uint8List audioData) {
    _audioDataController.add(
      WatchAudioData(data: audioData, timestamp: DateTime.now()),
    );
  }

  void _handleAudioRecordingComplete(Uint8List? audioData) {
    debugPrint(
      'WatchService: Audio recording complete, ${audioData?.length ?? 0} bytes',
    );
    _isRecording = false;

    if (_audioCompleter != null && !_audioCompleter!.isCompleted) {
      _audioCompleter!.complete(audioData);
    }
  }

  void _handleTTSComplete() {
    debugPrint('WatchService: TTS complete');
    _isSpeaking = false;
    _ttsStateController.add(WatchTTSState(isSpeaking: false, isComplete: true));
  }

  void _handleTTSError(String? error) {
    debugPrint('WatchService: TTS error: $error');
    _isSpeaking = false;
    _ttsStateController.add(
      WatchTTSState(isSpeaking: false, isComplete: true, error: error),
    );
  }

  /// Enable or disable watch connectivity
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('watch_enabled', enabled);

    debugPrint('WatchService: Enabled set to $enabled');

    // Update connection state
    _connectionStateController.add(
      WatchConnectionState(
        isConnected: _isConnected && enabled,
        watchId: enabled ? _connectedWatchId : null,
        watchName: enabled ? _connectedWatchName : null,
      ),
    );
  }

  /// Start recording audio from the watch microphone
  /// Returns the recorded audio data as WAV format
  Future<Uint8List?> startRecording({
    Duration maxDuration = const Duration(seconds: 10),
    int sampleRate = 16000,
  }) async {
    if (!isConnected) {
      debugPrint('WatchService: Cannot record - watch not connected');
      return null;
    }

    if (_isRecording) {
      debugPrint('WatchService: Already recording');
      return null;
    }

    try {
      _isRecording = true;
      _audioCompleter = Completer<Uint8List?>();

      await _watchChannel.invokeMethod('startRecording', {
        'maxDurationMs': maxDuration.inMilliseconds,
        'sampleRate': sampleRate,
      });

      debugPrint('WatchService: Started recording from watch microphone');

      // Wait for recording to complete or timeout
      final result = await _audioCompleter!.future.timeout(
        maxDuration + const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('WatchService: Recording timed out');
          stopRecording();
          return null;
        },
      );

      return result;
    } on PlatformException catch (e) {
      debugPrint('WatchService: Error starting recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Stop the current audio recording
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      await _watchChannel.invokeMethod('stopRecording');
      debugPrint('WatchService: Stopped recording');
    } on PlatformException catch (e) {
      debugPrint('WatchService: Error stopping recording: $e');
    }

    _isRecording = false;
  }

  /// Speak text using the watch's TTS engine
  Future<bool> speak(String text, {double? rate, double? pitch}) async {
    if (!isConnected) {
      debugPrint('WatchService: Cannot speak - watch not connected');
      return false;
    }

    try {
      _isSpeaking = true;
      _ttsStateController.add(WatchTTSState(isSpeaking: true));

      final result = await _watchChannel.invokeMethod('speak', {
        'text': text,
        'rate': rate ?? 1.0,
        'pitch': pitch ?? 1.0,
      });

      debugPrint('WatchService: Speaking: "$text"');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('WatchService: Error speaking: $e');
      _isSpeaking = false;
      return false;
    }
  }

  /// Stop the current TTS playback
  Future<void> stopSpeaking() async {
    if (!_isSpeaking) return;

    try {
      await _watchChannel.invokeMethod('stopSpeaking');
      _isSpeaking = false;
      _ttsStateController.add(
        WatchTTSState(isSpeaking: false, isComplete: true),
      );
    } on PlatformException catch (e) {
      debugPrint('WatchService: Error stopping TTS: $e');
    }
  }

  /// Send a message to display on the watch
  Future<bool> displayMessage(String message, {int durationMs = 5000}) async {
    if (!isConnected) {
      debugPrint('WatchService: Cannot display message - watch not connected');
      return false;
    }

    try {
      final result = await _watchChannel.invokeMethod('displayMessage', {
        'message': message,
        'durationMs': durationMs,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('WatchService: Error displaying message: $e');
      return false;
    }
  }

  /// Request the watch's current battery level
  Future<int?> getBatteryLevel() async {
    if (!isConnected) return null;

    try {
      final result = await _watchChannel.invokeMethod('getBatteryLevel');
      return result as int?;
    } on PlatformException catch (e) {
      debugPrint('WatchService: Error getting battery level: $e');
      return null;
    }
  }

  /// Check if the watch supports voice input
  Future<bool> supportsVoiceInput() async {
    if (!isConnected) return false;

    try {
      final result = await _watchChannel.invokeMethod('supportsVoiceInput');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  /// Check if the watch supports TTS output
  Future<bool> supportsTTS() async {
    if (!isConnected) return false;

    try {
      final result = await _watchChannel.invokeMethod('supportsTTS');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  /// Dispose of the service
  void dispose() {
    _eventSubscription?.cancel();
    _connectionStateController.close();
    _audioDataController.close();
    _ttsStateController.close();
  }
}

/// Watch connection state
class WatchConnectionState {
  final bool isConnected;
  final String? watchId;
  final String? watchName;

  WatchConnectionState({
    required this.isConnected,
    this.watchId,
    this.watchName,
  });
}

/// Audio data from watch recording
class WatchAudioData {
  final Uint8List data;
  final DateTime timestamp;

  WatchAudioData({required this.data, required this.timestamp});
}

/// TTS state
class WatchTTSState {
  final bool isSpeaking;
  final bool isComplete;
  final String? error;

  WatchTTSState({
    required this.isSpeaking,
    this.isComplete = false,
    this.error,
  });
}
