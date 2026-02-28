import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

/// Service for wake word detection ("computer")
/// Uses Vosk for on-device, offline speech recognition
/// Apache 2.0 license - free for commercial use
class WakeWordService {
  static final WakeWordService singleton = WakeWordService._internal();
  factory WakeWordService() => singleton;
  WakeWordService._internal();

  // Vosk components
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  // Settings
  bool _isEnabled = false;
  String _wakeWord = 'computer';
  double _sensitivity = 0.5; // 0.0 to 1.0

  // State
  bool _isListening = false;
  bool _isInitialized = false;
  bool _isPaused = false;
  bool _isModelLoading = false;
  double _modelDownloadProgress = 0.0;

  // Callbacks
  WakeWordCallback? _onWakeWordDetected;

  // Stream subscriptions
  StreamSubscription? _partialSubscription;
  StreamSubscription? _resultSubscription;

  // Stream controller for wake word events
  final StreamController<WakeWordEvent> _eventController =
      StreamController<WakeWordEvent>.broadcast();

  // Cooldown to prevent multiple detections
  DateTime? _lastDetection;
  static const _detectionCooldown = Duration(seconds: 2);

  // Minimum confidence threshold for wake word detection
  // Vosk confidence ranges from 0.0 to 1.0
  static const _minConfidenceThreshold = 0.75;

  // Recent audio energy tracking for noise rejection
  // ignore: unused_field
  final List<double> _recentEnergies = [];
  // ignore: unused_field
  static const _energyWindowSize = 10;
  // ignore: unused_field
  static const _minEnergyRatio = 2.0; // Audio must be 2x above ambient noise

  // Model info - using small English model (~50MB)
  static const _modelUrl =
      'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip';
  static const _modelName = 'vosk-model-small-en-us-0.15';

  // Public getters
  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening && !_isPaused;
  bool get isInitialized => _isInitialized;
  bool get isModelLoading => _isModelLoading;
  double get modelDownloadProgress => _modelDownloadProgress;
  String get wakeWord => _wakeWord;
  double get sensitivity => _sensitivity;
  Stream<WakeWordEvent> get eventStream => _eventController.stream;

  /// Initialize the wake word service
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('WakeWordService: Initializing with Vosk...');

    // Load settings from preferences
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('wake_word_enabled') ?? false;
    _wakeWord = prefs.getString('wake_word') ?? 'computer';
    _sensitivity = prefs.getDouble('wake_word_sensitivity') ?? 0.5;

    // Check if model exists, download if needed
    final modelPath = await _getModelPath();
    if (modelPath == null) {
      debugPrint(
        'WakeWordService: Model not found, will download when enabled',
      );
      // Model will be downloaded when user enables wake word
      _isInitialized = true;
      return;
    }

    // Load the model
    await _loadModel(modelPath);

    _isInitialized = true;
    debugPrint('WakeWordService: Initialized = $_isInitialized');

    // Auto-start if enabled
    if (_isEnabled && _model != null) {
      await startListening();
    }
  }

  /// Get the path to the Vosk model, or null if not downloaded
  Future<String?> _getModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/vosk-models/$_modelName');

    if (await modelDir.exists()) {
      debugPrint('WakeWordService: Model found at ${modelDir.path}');
      return modelDir.path;
    }

    return null;
  }

  /// Download the Vosk model
  Future<String?> _downloadModel() async {
    if (_isModelLoading) return null;

    _isModelLoading = true;
    _modelDownloadProgress = 0.0;
    _eventController.add(
      WakeWordEvent(type: WakeWordEventType.modelDownloadStarted),
    );

    try {
      debugPrint('WakeWordService: Downloading model from $_modelUrl');

      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/vosk-models');
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      // Download the zip file
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(_modelUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download model: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final zipPath = '${modelsDir.path}/$_modelName.zip';
      final zipFile = File(zipPath);
      final sink = zipFile.openWrite();

      int downloaded = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          _modelDownloadProgress = downloaded / contentLength;
          _eventController.add(
            WakeWordEvent(
              type: WakeWordEventType.modelDownloadProgress,
              progress: _modelDownloadProgress,
            ),
          );
        }
      }

      await sink.close();
      client.close();

      debugPrint('WakeWordService: Download complete, extracting...');

      // Extract the zip file
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = '${modelsDir.path}/${file.name}';
        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filename).create(recursive: true);
        }
      }

      // Delete the zip file
      await zipFile.delete();

      final modelPath = '${modelsDir.path}/$_modelName';
      debugPrint('WakeWordService: Model extracted to $modelPath');

      _isModelLoading = false;
      _modelDownloadProgress = 1.0;
      _eventController.add(
        WakeWordEvent(type: WakeWordEventType.modelDownloadComplete),
      );

      return modelPath;
    } catch (e) {
      debugPrint('WakeWordService: Error downloading model: $e');
      _isModelLoading = false;
      _eventController.add(
        WakeWordEvent(
          type: WakeWordEventType.error,
          error: 'Failed to download speech model: $e',
        ),
      );
      return null;
    }
  }

  /// Load the Vosk model
  Future<bool> _loadModel(String modelPath) async {
    try {
      debugPrint('WakeWordService: Loading model from $modelPath');
      _model = await _vosk.createModel(modelPath);
      debugPrint('WakeWordService: Model loaded successfully');
      return true;
    } catch (e) {
      debugPrint('WakeWordService: Error loading model: $e');
      _eventController.add(
        WakeWordEvent(
          type: WakeWordEventType.error,
          error: 'Failed to load speech model: $e',
        ),
      );
      return false;
    }
  }

  /// Create recognizer with grammar for wake word detection
  Future<bool> _createRecognizer() async {
    if (_model == null) return false;

    try {
      // Use grammar mode for efficient wake word detection
      // Only listen for specific words, much more efficient than full speech recognition
      // Include "[unk]" to allow Vosk to classify non-matching audio as unknown
      // This prevents random noise from being forced to match "computer"
      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: 16000,
        grammar: [
          _wakeWord,
          'hey computer',
          'okay computer',
          'hi computer',
          '[unk]', // Unknown token for noise/non-matching audio
        ],
      );
      debugPrint(
        'WakeWordService: Recognizer created with grammar: [$_wakeWord, [unk]]',
      );
      return true;
    } catch (e) {
      debugPrint('WakeWordService: Error creating recognizer: $e');
      return false;
    }
  }

  /// Handle partial recognition results
  void _handlePartialResult(String partial) {
    if (_isPaused) return;

    try {
      final json = jsonDecode(partial);
      final text = (json['partial'] as String?)?.toLowerCase() ?? '';

      // Don't trigger on partial results - too prone to false positives
      // We only log partials for debugging purposes
      if (text.isNotEmpty) {
        debugPrint(
            'WakeWordService: Partial: "$text" (not triggering on partial)');
      }
    } catch (e) {
      // Ignore JSON parse errors
    }
  }

  /// Handle final recognition results
  void _handleResult(String result) {
    if (_isPaused) return;

    try {
      final json = jsonDecode(result);
      final text = (json['text'] as String?)?.toLowerCase() ?? '';

      if (text.isEmpty) return;

      // Vosk returns confidence per word in the 'result' array
      // Format: {"result":[{"conf":0.9,"word":"computer","start":0.1,"end":0.5}],"text":"computer"}
      double maxConfidence = 0.0;
      bool wakeWordFound = false;

      final resultArray = json['result'] as List<dynamic>?;
      if (resultArray != null) {
        for (final wordInfo in resultArray) {
          final word = (wordInfo['word'] as String?)?.toLowerCase() ?? '';
          final conf = (wordInfo['conf'] as num?)?.toDouble() ?? 0.0;

          debugPrint('WakeWordService: Word: "$word" conf: $conf');

          // Check if this word matches our wake word
          if (word == _wakeWord.toLowerCase() ||
              word == 'hey' ||
              word == 'okay' ||
              word == 'hi') {
            if (word == _wakeWord.toLowerCase()) {
              wakeWordFound = true;
              maxConfidence = conf > maxConfidence ? conf : maxConfidence;
            }
          }
        }
      } else {
        // Fallback: no detailed result array, use text matching with lower confidence
        debugPrint('WakeWordService: No result array, text: "$text"');
        if (_containsWakeWord(text)) {
          wakeWordFound = true;
          maxConfidence = 0.5; // Lower confidence when no detailed info
        }
      }

      if (wakeWordFound) {
        debugPrint(
            'WakeWordService: Wake word found with confidence: $maxConfidence (threshold: $_minConfidenceThreshold)');
        if (maxConfidence >= _minConfidenceThreshold) {
          _triggerWakeWord(maxConfidence);
        } else {
          debugPrint('WakeWordService: Confidence too low, ignoring');
        }
      }
    } catch (e) {
      debugPrint('WakeWordService: Error parsing result: $e');
    }
  }

  /// Check if text contains the wake word
  bool _containsWakeWord(String text) {
    final words = text.toLowerCase().split(' ');
    return words.contains(_wakeWord.toLowerCase()) ||
        text.contains('hey $_wakeWord') ||
        text.contains('okay $_wakeWord') ||
        text.contains('hi $_wakeWord');
  }

  /// Trigger wake word detection
  void _triggerWakeWord(double confidence) {
    // Check cooldown to prevent multiple triggers
    final now = DateTime.now();
    if (_lastDetection != null &&
        now.difference(_lastDetection!) < _detectionCooldown) {
      debugPrint('WakeWordService: Cooldown active, ignoring detection');
      return;
    }
    _lastDetection = now;

    // Calculate effective threshold based on sensitivity setting
    // sensitivity 0.0 = very strict (threshold 0.95)
    // sensitivity 0.5 = default (threshold 0.75)
    // sensitivity 1.0 = lenient (threshold 0.55)
    final effectiveThreshold =
        _minConfidenceThreshold + ((1.0 - _sensitivity) * 0.2);

    if (confidence < effectiveThreshold) {
      debugPrint(
        'WakeWordService: Confidence $confidence below effective threshold $effectiveThreshold (sensitivity: $_sensitivity)',
      );
      return;
    }

    debugPrint(
        'WakeWordService: Wake word detected! confidence=$confidence, threshold=$effectiveThreshold');

    _eventController.add(
      WakeWordEvent(
        type: WakeWordEventType.detected,
        confidence: confidence,
        source: 'phone',
      ),
    );

    // Call the callback if set
    _onWakeWordDetected?.call(confidence, 'phone');
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

    if (enabled) {
      // Check if model is loaded
      if (_model == null) {
        // Try to load existing model or download
        var modelPath = await _getModelPath();
        if (modelPath == null) {
          debugPrint('WakeWordService: Downloading model...');
          modelPath = await _downloadModel();
        }
        if (modelPath != null) {
          await _loadModel(modelPath);
        }
      }

      if (_model != null) {
        await startListening();
      } else {
        _eventController.add(
          WakeWordEvent(
            type: WakeWordEventType.error,
            error: 'Speech model not available. Please try again.',
          ),
        );
      }
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

    // Recreate recognizer with new grammar
    if (_isListening) {
      await stopListening();
      await startListening();
    }
  }

  /// Set the sensitivity (0.0 to 1.0, higher = more sensitive)
  Future<void> setSensitivity(double sensitivity) async {
    _sensitivity = sensitivity.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('wake_word_sensitivity', _sensitivity);

    debugPrint('WakeWordService: Sensitivity set to $_sensitivity');
  }

  /// Start listening for the wake word
  Future<bool> startListening() async {
    if (_model == null) {
      debugPrint('WakeWordService: Model not loaded');
      return false;
    }

    if (_isListening && !_isPaused) {
      debugPrint('WakeWordService: Already listening');
      return true;
    }

    try {
      // Create recognizer if needed
      if (_recognizer == null) {
        if (!await _createRecognizer()) {
          return false;
        }
      }

      // Initialize speech service
      _speechService = await _vosk.initSpeechService(_recognizer!);

      // Subscribe to results
      _partialSubscription = _speechService!.onPartial().listen(
            _handlePartialResult,
            onError: (e) => debugPrint('WakeWordService: Partial error: $e'),
          );

      _resultSubscription = _speechService!.onResult().listen(
            _handleResult,
            onError: (e) => debugPrint('WakeWordService: Result error: $e'),
          );

      // Start listening
      await _speechService!.start();
      _isListening = true;
      _isPaused = false;

      debugPrint('WakeWordService: Started listening for "$_wakeWord"');

      _eventController.add(
        WakeWordEvent(type: WakeWordEventType.listeningStarted),
      );

      return true;
    } catch (e) {
      debugPrint('WakeWordService: Error starting listening: $e');
      _eventController.add(
        WakeWordEvent(
          type: WakeWordEventType.error,
          error: 'Failed to start wake word detection: $e',
        ),
      );
      return false;
    }
  }

  /// Stop listening for the wake word
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _partialSubscription?.cancel();
      await _resultSubscription?.cancel();
      _partialSubscription = null;
      _resultSubscription = null;

      await _speechService?.stop();
      _speechService = null;

      // Keep recognizer for quick restart
      _isListening = false;
      _isPaused = false;

      debugPrint('WakeWordService: Stopped listening');

      _eventController.add(
        WakeWordEvent(type: WakeWordEventType.listeningStopped),
      );
    } catch (e) {
      debugPrint('WakeWordService: Error stopping listening: $e');
    }
  }

  /// Pause wake word detection temporarily (e.g., during voice recording)
  Future<void> pause() async {
    if (!_isListening || _isPaused) return;

    try {
      await _speechService?.stop();
      _isPaused = true;
      debugPrint('WakeWordService: Paused');
    } catch (e) {
      debugPrint('WakeWordService: Error pausing: $e');
    }
  }

  /// Resume wake word detection after pausing
  Future<void> resume() async {
    if (!_isEnabled || !_isListening || !_isPaused) return;

    try {
      await _speechService?.start();
      _isPaused = false;
      debugPrint('WakeWordService: Resumed');
    } catch (e) {
      debugPrint('WakeWordService: Error resuming: $e');
    }
  }

  /// Check if the device supports wake word detection
  Future<bool> isSupported() async {
    // Vosk supports Android (and Linux/Windows)
    return Platform.isAndroid || Platform.isLinux || Platform.isWindows;
  }

  /// Delete the downloaded model to free space
  Future<void> deleteModel() async {
    await stopListening();
    _recognizer = null;
    _model = null;

    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/vosk-models/$_modelName');
    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
      debugPrint('WakeWordService: Model deleted');
    }
  }

  /// Get the model size in bytes (for display purposes)
  Future<int> getModelSize() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/vosk-models/$_modelName');
    if (await modelDir.exists()) {
      int size = 0;
      await for (final entity in modelDir.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
      return size;
    }
    return 0;
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await stopListening();
    _recognizer = null;
    _model = null;
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
  modelDownloadStarted,
  modelDownloadProgress,
  modelDownloadComplete,
  error,
}

/// Wake word event
class WakeWordEvent {
  final WakeWordEventType type;
  final double? confidence;
  final String? source; // 'phone', 'glasses', 'watch'
  final String? error;
  final double? progress; // For download progress (0.0 to 1.0)

  WakeWordEvent({
    required this.type,
    this.confidence,
    this.source,
    this.error,
    this.progress,
  });
}
