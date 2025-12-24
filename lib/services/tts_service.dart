import 'dart:async';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/services/watch_service.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TTS output modes - similar to ESP32 implementation
enum TTSMode {
  none, // No TTS output (for glasses which have no speaker)
  watch, // TTS via Pixel Watch speaker
  phone, // TTS via phone speaker
  auto, // Auto-select best available (watch if connected, else phone)
}

/// Service for text-to-speech output across multiple devices
class TTSService {
  static final TTSService singleton = TTSService._internal();
  factory TTSService() => singleton;
  TTSService._internal();

  // Dependencies
  final WatchService _watchService = WatchService.singleton;
  final BluetoothManager _bluetoothManager = BluetoothManager.singleton;

  // Phone TTS engine
  final FlutterTts _flutterTts = FlutterTts();
  bool _phoneTtsInitialized = false;

  // State
  bool _isSpeaking = false;
  TTSMode _currentMode = TTSMode.auto;
  String? _currentDevice;

  // Settings
  TTSMode _preferredMode = TTSMode.auto;
  double _rate = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;
  String _language = 'en-US';

  // Stream controllers
  final StreamController<TTSState> _stateController =
      StreamController<TTSState>.broadcast();

  // Public getters
  bool get isSpeaking => _isSpeaking;
  TTSMode get currentMode => _currentMode;
  String? get currentDevice => _currentDevice;
  TTSMode get preferredMode => _preferredMode;
  Stream<TTSState> get stateStream => _stateController.stream;

  /// Initialize the TTS service
  Future<void> initialize() async {
    debugPrint('TTSService: Initializing...');

    // Load settings
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('tts_mode') ?? 'auto';
    _preferredMode = TTSMode.values.firstWhere(
      (e) => e.name == modeStr,
      orElse: () => TTSMode.auto,
    );
    _rate = prefs.getDouble('tts_rate') ?? 1.0;
    _pitch = prefs.getDouble('tts_pitch') ?? 1.0;
    _volume = prefs.getDouble('tts_volume') ?? 1.0;
    _language = prefs.getString('tts_language') ?? 'en-US';

    // Initialize phone TTS
    await _initializePhoneTTS();

    debugPrint('TTSService: Initialized with mode: $_preferredMode');
  }

  /// Initialize the phone TTS engine
  Future<void> _initializePhoneTTS() async {
    try {
      await _flutterTts.setLanguage(_language);
      await _flutterTts.setSpeechRate(_rate);
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);

      // Set up completion handler
      _flutterTts.setCompletionHandler(() {
        _onSpeakComplete('phone');
      });

      _flutterTts.setErrorHandler((error) {
        debugPrint('TTSService: Phone TTS error: $error');
        _onSpeakError(error.toString());
      });

      _phoneTtsInitialized = true;
      debugPrint('TTSService: Phone TTS initialized');
    } catch (e) {
      debugPrint('TTSService: Failed to initialize phone TTS: $e');
      _phoneTtsInitialized = false;
    }
  }

  /// Get the effective TTS mode based on preferences and available devices
  TTSMode getEffectiveMode() {
    // Glasses never use TTS (no speaker)
    if (_bluetoothManager.isConnected && _preferredMode == TTSMode.none) {
      return TTSMode.none;
    }

    // Auto mode selects best available
    if (_preferredMode == TTSMode.auto) {
      if (_watchService.isConnected) {
        return TTSMode.watch;
      }
      return TTSMode.phone;
    }

    // Check if preferred mode is available
    switch (_preferredMode) {
      case TTSMode.watch:
        return _watchService.isConnected ? TTSMode.watch : TTSMode.phone;
      case TTSMode.phone:
        return TTSMode.phone;
      case TTSMode.none:
        return TTSMode.none;
      case TTSMode.auto:
        return TTSMode.phone;
    }
  }

  /// Determine if TTS should be used for current device configuration
  bool shouldUseTTS() {
    // When glasses are the primary output, don't use TTS (glasses have no speaker)
    // AGiXT will display text on glasses instead
    if (_bluetoothManager.isConnected && !_watchService.isConnected) {
      return false;
    }

    // When watch is connected, use TTS on watch
    if (_watchService.isConnected) {
      return true;
    }

    // When only phone is available, use phone TTS
    return _preferredMode != TTSMode.none;
  }

  /// Set the preferred TTS mode
  Future<void> setPreferredMode(TTSMode mode) async {
    _preferredMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tts_mode', mode.name);
    debugPrint('TTSService: Preferred mode set to $mode');
  }

  /// Set speech rate (0.5 to 2.0, default 1.0)
  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.5, 2.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_rate', _rate);

    if (_phoneTtsInitialized) {
      await _flutterTts.setSpeechRate(_rate);
    }

    debugPrint('TTSService: Rate set to $_rate');
  }

  /// Set speech pitch (0.5 to 2.0, default 1.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_pitch', _pitch);

    if (_phoneTtsInitialized) {
      await _flutterTts.setPitch(_pitch);
    }

    debugPrint('TTSService: Pitch set to $_pitch');
  }

  /// Set speech volume (0.0 to 1.0, default 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_volume', _volume);

    if (_phoneTtsInitialized) {
      await _flutterTts.setVolume(_volume);
    }

    debugPrint('TTSService: Volume set to $_volume');
  }

  /// Set speech language
  Future<void> setLanguage(String language) async {
    _language = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tts_language', language);

    if (_phoneTtsInitialized) {
      await _flutterTts.setLanguage(language);
    }

    debugPrint('TTSService: Language set to $language');
  }

  /// Speak text using the appropriate output device
  Future<bool> speak(String text) async {
    if (_isSpeaking) {
      debugPrint('TTSService: Already speaking, queueing text');
      await stop();
    }

    final effectiveMode = getEffectiveMode();

    if (effectiveMode == TTSMode.none) {
      debugPrint('TTSService: TTS disabled, not speaking');
      return false;
    }

    _currentMode = effectiveMode;
    _isSpeaking = true;

    _stateController.add(TTSState(
      isSpeaking: true,
      mode: effectiveMode,
      device: effectiveMode == TTSMode.watch ? 'watch' : 'phone',
      text: text,
    ));

    debugPrint('TTSService: Speaking via $effectiveMode: "$text"');

    try {
      switch (effectiveMode) {
        case TTSMode.watch:
          _currentDevice = 'watch';
          final success = await _watchService.speak(
            text,
            rate: _rate,
            pitch: _pitch,
          );
          if (!success) {
            // Fall back to phone if watch fails
            debugPrint('TTSService: Watch TTS failed, falling back to phone');
            return await _speakWithPhone(text);
          }
          return success;

        case TTSMode.phone:
          return await _speakWithPhone(text);

        case TTSMode.none:
        case TTSMode.auto:
          return false;
      }
    } catch (e) {
      debugPrint('TTSService: Error speaking: $e');
      _onSpeakError(e.toString());
      return false;
    }
  }

  /// Speak using the phone TTS engine
  Future<bool> _speakWithPhone(String text) async {
    if (!_phoneTtsInitialized) {
      await _initializePhoneTTS();
    }

    _currentDevice = 'phone';

    try {
      final result = await _flutterTts.speak(text);
      return result == 1;
    } catch (e) {
      debugPrint('TTSService: Phone TTS error: $e');
      _onSpeakError(e.toString());
      return false;
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    if (!_isSpeaking) return;

    debugPrint('TTSService: Stopping speech');

    try {
      switch (_currentMode) {
        case TTSMode.watch:
          await _watchService.stopSpeaking();
          break;
        case TTSMode.phone:
          await _flutterTts.stop();
          break;
        case TTSMode.none:
        case TTSMode.auto:
          break;
      }
    } catch (e) {
      debugPrint('TTSService: Error stopping speech: $e');
    }

    _isSpeaking = false;
    _currentDevice = null;

    _stateController.add(TTSState(
      isSpeaking: false,
      mode: _currentMode,
      isComplete: true,
    ));
  }

  /// Handle speech completion
  void _onSpeakComplete(String device) {
    debugPrint('TTSService: Speech complete on $device');
    _isSpeaking = false;
    _currentDevice = null;

    _stateController.add(TTSState(
      isSpeaking: false,
      mode: _currentMode,
      device: device,
      isComplete: true,
    ));
  }

  /// Handle speech error
  void _onSpeakError(String error) {
    debugPrint('TTSService: Speech error: $error');
    _isSpeaking = false;
    _currentDevice = null;

    _stateController.add(TTSState(
      isSpeaking: false,
      mode: _currentMode,
      error: error,
    ));
  }

  /// Get available TTS modes based on connected devices
  List<TTSMode> getAvailableModes() {
    final modes = <TTSMode>[TTSMode.none, TTSMode.phone, TTSMode.auto];

    if (_watchService.isConnected) {
      modes.insert(2, TTSMode.watch);
    }

    return modes;
  }

  /// Get display name for TTS mode
  static String getModeDisplayName(TTSMode mode) {
    switch (mode) {
      case TTSMode.none:
        return 'None (Text Only)';
      case TTSMode.watch:
        return 'Pixel Watch';
      case TTSMode.phone:
        return 'Phone Speaker';
      case TTSMode.auto:
        return 'Auto (Best Available)';
    }
  }

  /// Get available languages
  Future<List<String>> getAvailableLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return List<String>.from(languages ?? []);
    } catch (e) {
      debugPrint('TTSService: Error getting languages: $e');
      return ['en-US'];
    }
  }

  /// Dispose of the service
  void dispose() {
    _flutterTts.stop();
    _stateController.close();
  }
}

/// TTS state
class TTSState {
  final bool isSpeaking;
  final TTSMode mode;
  final String? device;
  final String? text;
  final bool isComplete;
  final String? error;

  TTSState({
    required this.isSpeaking,
    required this.mode,
    this.device,
    this.text,
    this.isComplete = false,
    this.error,
  });
}
