import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';

/// Service for streaming PCM audio playback on the phone speaker.
/// Used to play AGiXT's text-to-speech audio in real-time.
class AudioPlayerService {
  static final AudioPlayerService singleton = AudioPlayerService._internal();
  factory AudioPlayerService() => singleton;
  AudioPlayerService._internal();

  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _playerInitialized = false;
  bool _isPlaying = false;
  StreamController<Food>? _audioStreamController;
  StreamSubscription<Food>? _audioStreamSubscription;

  // Audio format info (from audio.header)
  int _sampleRate = 24000;
  int _bitsPerSample = 16;
  int _channels = 1;

  // Public getters
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _playerInitialized;

  /// Initialize the audio player
  Future<void> initialize() async {
    if (_playerInitialized) return;

    try {
      await _player.openPlayer();
      _playerInitialized = true;
      debugPrint('AudioPlayerService: Player initialized');
    } catch (e) {
      debugPrint('AudioPlayerService: Failed to initialize player: $e');
    }
  }

  /// Start streaming audio playback with the given format
  Future<bool> startStreaming({
    required int sampleRate,
    int bitsPerSample = 16,
    int channels = 1,
  }) async {
    if (!_playerInitialized) {
      await initialize();
      if (!_playerInitialized) {
        debugPrint('AudioPlayerService: Cannot start - player not initialized');
        return false;
      }
    }

    // Stop any existing playback
    await stopStreaming();

    _sampleRate = sampleRate;
    _bitsPerSample = bitsPerSample;
    _channels = channels;

    debugPrint(
      'AudioPlayerService: Starting stream - ${_sampleRate}Hz, ${_bitsPerSample}-bit, ${_channels}ch',
    );

    try {
      // Create a new stream controller for feeding audio
      _audioStreamController = StreamController<Food>();

      // Determine codec based on bits per sample
      Codec codec;
      if (_bitsPerSample == 16) {
        codec = Codec.pcm16;
      } else {
        // Default to 16-bit PCM
        codec = Codec.pcm16;
      }

      // Start the player with stream input
      // Buffer size in samples - use smaller buffer for lower latency
      // but not too small to avoid underflow
      const bufferSize = 4096;

      await _player.startPlayerFromStream(
        codec: codec,
        interleaved: false, // Mono so doesn't matter
        numChannels: _channels,
        sampleRate: _sampleRate,
        bufferSize: bufferSize,
      );

      _isPlaying = true;
      debugPrint('AudioPlayerService: Stream started successfully');
      return true;
    } catch (e) {
      debugPrint('AudioPlayerService: Failed to start stream: $e');
      _isPlaying = false;
      return false;
    }
  }

  /// Feed PCM audio data to the player
  Future<void> feedAudioChunk(Uint8List pcmData) async {
    if (!_isPlaying) {
      debugPrint('AudioPlayerService: Cannot feed - not playing');
      return;
    }

    try {
      // Feed the PCM data directly to the player
      await _player.feedFromStream(pcmData);
    } catch (e) {
      debugPrint('AudioPlayerService: Error feeding audio: $e');
    }
  }

  /// Stop streaming playback
  Future<void> stopStreaming() async {
    if (!_isPlaying) return;

    debugPrint('AudioPlayerService: Stopping stream');

    try {
      await _player.stopPlayer();
    } catch (e) {
      debugPrint('AudioPlayerService: Error stopping player: $e');
    }

    _isPlaying = false;
    await _audioStreamController?.close();
    _audioStreamController = null;
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await stopStreaming();

    if (_playerInitialized) {
      try {
        await _player.closePlayer();
      } catch (e) {
        debugPrint('AudioPlayerService: Error closing player: $e');
      }
      _playerInitialized = false;
    }
  }
}
