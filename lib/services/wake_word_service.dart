import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for wake word detection ("computer")
/// Uses on-device speech recognition to detect the wake word
class WakeWordService {
  static final WakeWordService singleton = WakeWordService._internal();
  factory WakeWordService() => singleton;
  WakeWordService._internal();

  // Method channel for native wake word detection
  static const MethodChannel _wakeWordChannel =
      MethodChannel('dev.agixt.agixt/wake_word');
  static const EventChannel _wakeWordEventsChannel =
      EventChannel('dev.agixt.agixt/wake_word_events');

  // Settings
  bool _isEnabled = false;
  String _wakeWord = 'computer';
  double _sensitivity = 0.5; // 0.0 to 1.0

  // State
  bool _isListening = false;
  bool _isInitialized = false;

  // Callbacks
  WakeWordCallback? _onWakeWordDetected;

  // Stream subscription
  StreamSubscription? _eventSubscription;

  // Stream controller for wake word events
  final StreamController<WakeWordEvent> _eventController =
      StreamController<WakeWordEvent>.broadcast();

  // Public getters
  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  String get wakeWord => _wakeWord;
  double get sensitivity => _sensitivity;
  Stream<WakeWordEvent> get eventStream => _eventController.stream;

  /// Initialize the wake word service
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('WakeWordService: Initializing...');

    // Load settings from preferences
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('wake_word_enabled') ?? false;
    _wakeWord = prefs.getString('wake_word') ?? 'computer';
    _sensitivity = prefs.getDouble('wake_word_sensitivity') ?? 0.5;

    // Set up method call handler
    _wakeWordChannel.setMethodCallHandler(_handleMethodCall);

    // Set up event channel listener
    _eventSubscription = _wakeWordEventsChannel
        .receiveBroadcastStream()
        .listen(_handleWakeWordEvent, onError: _handleEventError);

    // Initialize native wake word detector
    try {
      final result = await _wakeWordChannel.invokeMethod('initialize', {
        'wakeWord': _wakeWord,
        'sensitivity': _sensitivity,
      });
      _isInitialized = result == true;
      debugPrint('WakeWordService: Initialized = $_isInitialized');
    } on PlatformException catch (e) {
      debugPrint('WakeWordService: Failed to initialize: $e');
      _isInitialized = false;
    } on MissingPluginException {
      debugPrint(
          'WakeWordService: Wake word detection not available on this platform');
      _isInitialized = false;
    }

    // Auto-start if enabled
    if (_isEnabled && _isInitialized) {
      await startListening();
    }
  }

  /// Handle method calls from native code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWakeWordDetected':
        final confidence = call.arguments['confidence'] as double? ?? 1.0;
        final source = call.arguments['source'] as String? ?? 'phone';
        _handleWakeWordDetection(confidence, source);
        return true;

      case 'onListeningStarted':
        _isListening = true;
        debugPrint('WakeWordService: Listening started');
        return true;

      case 'onListeningStopped':
        _isListening = false;
        debugPrint('WakeWordService: Listening stopped');
        return true;

      case 'onError':
        final error = call.arguments['error'] as String?;
        debugPrint('WakeWordService: Error - $error');
        _eventController.add(WakeWordEvent(
          type: WakeWordEventType.error,
          error: error,
        ));
        return true;

      default:
        debugPrint('WakeWordService: Unknown method call: ${call.method}');
        return null;
    }
  }

  /// Handle events from the event channel
  void _handleWakeWordEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'] as String?;
      switch (type) {
        case 'wake_word_detected':
          final confidence = (event['confidence'] as num?)?.toDouble() ?? 1.0;
          final source = event['source'] as String? ?? 'phone';
          _handleWakeWordDetection(confidence, source);
          break;

        case 'listening_state_changed':
          _isListening = event['isListening'] == true;
          debugPrint('WakeWordService: Listening state changed to $_isListening');
          break;

        case 'audio_level':
          // Can be used for visual feedback of audio input level
          break;
      }
    }
  }

  void _handleEventError(dynamic error) {
    debugPrint('WakeWordService: Event channel error: $error');
    _eventController.add(WakeWordEvent(
      type: WakeWordEventType.error,
      error: error.toString(),
    ));
  }

  /// Handle wake word detection
  void _handleWakeWordDetection(double confidence, String source) {
    debugPrint(
        'WakeWordService: Wake word detected! confidence=$confidence, source=$source');

    _eventController.add(WakeWordEvent(
      type: WakeWordEventType.detected,
      confidence: confidence,
      source: source,
    ));

    // Call the callback if set
    _onWakeWordDetected?.call(confidence, source);
  }

  /// Set the callback for wake word detection
  void setOnWakeWordDetected(WakeWordCallback? callback) {
    _onWakeWordDetected = callback;
  }

  /// Enable or disable wake word detection
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wake_word_enabled', enabled);

    debugPrint('WakeWordService: Enabled set to $enabled');

    if (enabled && _isInitialized) {
      await startListening();
    } else {
      await stopListening();
    }
  }

  /// Set the wake word (default: "computer")
  Future<void> setWakeWord(String wakeWord) async {
    _wakeWord = wakeWord.toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wake_word', _wakeWord);

    debugPrint('WakeWordService: Wake word set to "$_wakeWord"');

    // Update native detector if initialized
    if (_isInitialized) {
      try {
        await _wakeWordChannel.invokeMethod('setWakeWord', {
          'wakeWord': _wakeWord,
        });
      } on PlatformException catch (e) {
        debugPrint('WakeWordService: Error setting wake word: $e');
      }
    }
  }

  /// Set the sensitivity (0.0 to 1.0, higher = more sensitive)
  Future<void> setSensitivity(double sensitivity) async {
    _sensitivity = sensitivity.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('wake_word_sensitivity', _sensitivity);

    debugPrint('WakeWordService: Sensitivity set to $_sensitivity');

    // Update native detector if initialized
    if (_isInitialized) {
      try {
        await _wakeWordChannel.invokeMethod('setSensitivity', {
          'sensitivity': _sensitivity,
        });
      } on PlatformException catch (e) {
        debugPrint('WakeWordService: Error setting sensitivity: $e');
      }
    }
  }

  /// Start listening for the wake word
  Future<bool> startListening() async {
    if (!_isInitialized) {
      debugPrint('WakeWordService: Not initialized');
      return false;
    }

    if (_isListening) {
      debugPrint('WakeWordService: Already listening');
      return true;
    }

    try {
      final result = await _wakeWordChannel.invokeMethod('startListening');
      _isListening = result == true;
      debugPrint('WakeWordService: Started listening = $_isListening');

      _eventController.add(WakeWordEvent(
        type: _isListening
            ? WakeWordEventType.listeningStarted
            : WakeWordEventType.error,
      ));

      return _isListening;
    } on PlatformException catch (e) {
      debugPrint('WakeWordService: Error starting listening: $e');
      return false;
    }
  }

  /// Stop listening for the wake word
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _wakeWordChannel.invokeMethod('stopListening');
      _isListening = false;
      debugPrint('WakeWordService: Stopped listening');

      _eventController.add(WakeWordEvent(
        type: WakeWordEventType.listeningStopped,
      ));
    } on PlatformException catch (e) {
      debugPrint('WakeWordService: Error stopping listening: $e');
    }
  }

  /// Pause wake word detection temporarily (e.g., during voice recording)
  Future<void> pause() async {
    if (!_isListening) return;

    try {
      await _wakeWordChannel.invokeMethod('pause');
      debugPrint('WakeWordService: Paused');
    } on PlatformException catch (e) {
      debugPrint('WakeWordService: Error pausing: $e');
    }
  }

  /// Resume wake word detection after pausing
  Future<void> resume() async {
    if (!_isEnabled || !_isInitialized) return;

    try {
      await _wakeWordChannel.invokeMethod('resume');
      debugPrint('WakeWordService: Resumed');
    } on PlatformException catch (e) {
      debugPrint('WakeWordService: Error resuming: $e');
    }
  }

  /// Check if the device supports wake word detection
  Future<bool> isSupported() async {
    try {
      final result = await _wakeWordChannel.invokeMethod('isSupported');
      return result == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Dispose of the service
  void dispose() {
    stopListening();
    _eventSubscription?.cancel();
    _eventController.close();
  }
}

/// Callback type for wake word detection
typedef WakeWordCallback = void Function(double confidence, String source);

/// Types of wake word events
enum WakeWordEventType {
  detected,
  listeningStarted,
  listeningStopped,
  error,
}

/// Wake word event
class WakeWordEvent {
  final WakeWordEventType type;
  final double? confidence;
  final String? source; // 'phone', 'glasses', 'watch'
  final String? error;

  WakeWordEvent({
    required this.type,
    this.confidence,
    this.source,
    this.error,
  });
}
