import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:http/http.dart' as http;

import 'package:agixt/services/secure_storage_service.dart';
import 'package:agixt/utils/url_security.dart';
import 'package:agixt/models/agixt/auth/auth.dart';

abstract class WhisperService {
  static Future<WhisperService> service() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('whisper_mode') ?? 'local';
    if (mode == "remote") {
      return WhisperRemoteService();
    }

    return WhisperLocalService();
  }

  Future<String> transcribe(Uint8List voiceData);

  /// Transcribe audio with speaker diarization.
  /// Returns a map with 'text' (speaker-attributed), 'segments' (list of
  /// segment maps with 'speaker', 'text', 'start', 'end'), and 'language'.
  /// When [sessionId] is provided, the backend persists speaker voice prints
  /// so the same physical speaker receives a consistent ID across chunks.
  Future<Map<String, dynamic>> transcribeWithDiarization(
    Uint8List voiceData, {
    int? numSpeakers,
    String? sessionId,
  }) async {
    // Default implementation falls back to plain transcription
    final text = await transcribe(voiceData);
    return {'text': text, 'segments': [], 'language': null};
  }

  // Method for AGiXT AI integration that returns a simulated transcription
  Future<String?> getTranscription() async {
    try {
      // For the initial implementation, we'll simulate a successful transcription
      // In a real implementation, we would:
      // 1. Capture audio from the glasses
      // 2. Process the audio data
      // 3. Send to a speech-to-text service (OpenAI Whisper API or AGiXT's endpoint)

      // Simulate processing time
      await Future.delayed(const Duration(seconds: 2));

      // Return dummy transcription for testing
      return "What's on my schedule for today?";

      /* 
      // Below is how you would implement the actual transcription with captured audio:
      
      final audioData = await captureAudioFromGlasses();
      if (audioData != null && audioData.isNotEmpty) {
        return await transcribe(audioData);
      }
      return null;
      */
    } catch (e) {
      debugPrint('Error in WhisperService.getTranscription: $e');
      return null;
    }
  }
}

class WhisperLocalService implements WhisperService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isInitialized = false;

  @override
  Future<Map<String, dynamic>> transcribeWithDiarization(
    Uint8List voiceData, {
    int? numSpeakers,
    String? sessionId,
  }) async {
    // Local service doesn't support diarization — fall back to plain text
    final text = await transcribe(voiceData);
    return {'text': text, 'segments': [], 'language': null};
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _recorder.openRecorder();
      bool available = await _speech.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) => debugPrint('Speech recognition status: $status'),
      );
      if (!available) {
        debugPrint('Speech recognition not available on this device');
      }
      _isInitialized = true;
    }
  }

  // This method uses the device's native speech recognition for real-time transcription
  Future<String?> listenAndTranscribe({int timeoutInSeconds = 10}) async {
    await _ensureInitialized();

    final Completer<String?> completer = Completer<String?>();
    String recognizedText = '';

    if (await _speech.initialize()) {
      await _speech.listen(
        onResult: (result) {
          recognizedText = result.recognizedWords;
          if (result.finalResult) {
            if (!completer.isCompleted) {
              completer.complete(recognizedText);
            }
          }
        },
        listenFor: Duration(seconds: timeoutInSeconds),
        pauseFor: Duration(seconds: 3),
        localeId: 'en_US', // Use the user's language preference
        listenOptions: stt.SpeechListenOptions(cancelOnError: true),
      );

      // Add a timeout
      Future.delayed(Duration(seconds: timeoutInSeconds + 5), () {
        if (!completer.isCompleted) {
          _speech.stop();
          completer.complete(recognizedText.isEmpty ? null : recognizedText);
        }
      });
    } else {
      completer.complete(null);
    }

    return completer.future;
  }

  @override
  Future<String> transcribe(Uint8List voiceData) async {
    // For pre-recorded audio (like from glasses or phone), we need to use the remote API
    // since native speech_to_text only works with live microphone input.
    // Fall back to remote transcription using the AGiXT endpoint.
    debugPrint(
        'WhisperLocalService: Transcribing ${voiceData.length} bytes of pre-recorded audio');

    try {
      // Try to use the remote service for pre-recorded audio
      final remoteService = WhisperRemoteService();
      final result = await remoteService.transcribe(voiceData);
      debugPrint('WhisperLocalService: Remote transcription result: $result');
      return result;
    } catch (e) {
      debugPrint('WhisperLocalService: Remote transcription failed: $e');
      // Propagate a message with the actual error for better debugging
      return 'Transcription failed: ${e.toString()}';
    }
  }

  @override
  Future<String?> getTranscription() async {
    try {
      await _ensureInitialized();
      return await listenAndTranscribe();
    } catch (e) {
      debugPrint('Error in WhisperLocalService.getTranscription: $e');
      return null;
    }
  }
}

class WhisperRemoteService implements WhisperService {
  static final SecureStorageService _secureStorage = SecureStorageService();

  Future<String?> getBaseURL() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('whisper_api_url');
    if (customUrl != null && customUrl.isNotEmpty) {
      return customUrl;
    }
    // Fall back to the AGiXT server URL if no separate whisper URL is configured
    return AuthService.serverUrl;
  }

  Future<String?> getApiKey() async {
    // First check for a dedicated whisper API key
    final storedKey = await _secureStorage.read(key: 'whisper_api_key');
    if (storedKey != null && storedKey.isNotEmpty) {
      return storedKey;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyKey = prefs.getString('whisper_api_key');
    if (legacyKey != null && legacyKey.isNotEmpty) {
      await _secureStorage.write(key: 'whisper_api_key', value: legacyKey);
      await prefs.remove('whisper_api_key');
      return legacyKey;
    }

    // Fall back to the AGiXT JWT token if no separate API key is configured
    return await AuthService.getJwt();
  }

  Future<String?> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_remote_model');
  }

  /// Resolve the effective model/agent name for transcription requests.
  /// AGiXT uses the `model` field as the agent name to route to the
  /// configured provider (e.g. EZLocalAI). Falls back through:
  /// custom model setting -> user's primary AGiXT agent -> 'XT'.
  Future<String> getEffectiveModel() async {
    final custom = await getModel();
    if (custom != null && custom.isNotEmpty) return custom;
    final agentName = await AuthService.getPrimaryAgentName();
    if (agentName != null && agentName.isNotEmpty) return agentName;
    return 'XT';
  }

  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_language');
  }

  Future<void> init() async {
    final url = await getBaseURL();
    if (url == null || url.isEmpty) {
      throw Exception(
          'No transcription API URL available. Please log in to AGiXT or configure Whisper API URL in settings.');
    }

    final sanitizedUrl = UrlSecurity.sanitizeBaseUrl(
      url,
      allowHttpOnLocalhost: true,
    );
    debugPrint('Initializing Whisper Remote Service with URL: $sanitizedUrl');
    OpenAI.baseUrl = sanitizedUrl;

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
          'No API key available. Please log in to AGiXT or configure Whisper API key in settings.');
    }
    OpenAI.apiKey = apiKey;
  }

  /// Check if the given bytes already start with a RIFF/WAVE header.
  static bool _hasWavHeader(Uint8List data) {
    if (data.length < 12) return false;
    // 'RIFF' at offset 0 and 'WAVE' at offset 8
    return data[0] == 0x52 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x46 &&
        data[8] == 0x57 &&
        data[9] == 0x41 &&
        data[10] == 0x56 &&
        data[11] == 0x45;
  }

  @override
  Future<String> transcribe(Uint8List voiceData) async {
    debugPrint('Transcribing voice data: ${voiceData.length} bytes');
    await init();
    final Directory documentDirectory =
        await getApplicationDocumentsDirectory();
    // Prepare wav file

    final String wavPath = '${documentDirectory.path}/${Uuid().v4()}.wav';
    debugPrint('Wav path: $wavPath');

    final File audioFile = File(wavPath);

    // If the data already has a WAV header (e.g. recorded from phone mic),
    // write it directly; otherwise wrap raw PCM in a new WAV envelope.
    if (_hasWavHeader(voiceData)) {
      debugPrint('Voice data already has WAV header, writing directly');
      await audioFile.writeAsBytes(voiceData);
    } else {
      // Add wav header for raw PCM data
      final int sampleRate = 16000;
      final int numChannels = 1;
      final int byteRate = sampleRate * numChannels * 2;
      final int blockAlign = numChannels * 2;
      final int bitsPerSample = 16;
      final int dataSize = voiceData.length;
      final int chunkSize = 36 + dataSize;

      final List<int> header = [
        // RIFF header
        ...ascii.encode('RIFF'),
        chunkSize & 0xff,
        (chunkSize >> 8) & 0xff,
        (chunkSize >> 16) & 0xff,
        (chunkSize >> 24) & 0xff,
        // WAVE header
        ...ascii.encode('WAVE'),
        // fmt subchunk
        ...ascii.encode('fmt '),
        16, 0, 0, 0, // Subchunk1Size (16 for PCM)
        1, 0, // AudioFormat (1 for PCM)
        numChannels, 0, // NumChannels
        sampleRate & 0xff,
        (sampleRate >> 8) & 0xff,
        (sampleRate >> 16) & 0xff,
        (sampleRate >> 24) & 0xff,
        byteRate & 0xff,
        (byteRate >> 8) & 0xff,
        (byteRate >> 16) & 0xff,
        (byteRate >> 24) & 0xff,
        blockAlign, 0,
        bitsPerSample, 0,
        // data subchunk
        ...ascii.encode('data'),
        dataSize & 0xff,
        (dataSize >> 8) & 0xff,
        (dataSize >> 16) & 0xff,
        (dataSize >> 24) & 0xff,
      ];
      header.addAll(voiceData.toList());

      await audioFile.writeAsBytes(Uint8List.fromList(header));
    }

    // Model is the AGiXT agent name - it routes to the configured provider (e.g. EZLocalAI)
    final model = await getEffectiveModel();
    debugPrint('Using transcription model/agent: $model');

    try {
      OpenAIAudioModel transcription =
          await OpenAI.instance.audio.createTranscription(
        file: audioFile,
        model: model,
        responseFormat: OpenAIAudioResponseFormat.json,
        language: await getLanguage(),
      );

      // delete wav file
      await File(wavPath).delete();

      var text = transcription.text;
      debugPrint('Transcription result: $text');

      return text;
    } catch (e) {
      // Clean up on error
      try {
        await File(wavPath).delete();
      } catch (_) {}
      debugPrint('Transcription error: $e');
      rethrow;
    }
  }

  /// Build a WAV file from audio data and return the file path.
  /// If the data already contains a WAV header it is written as-is;
  /// otherwise raw PCM is wrapped in a standard WAV envelope.
  Future<String> _buildWavFile(Uint8List voiceData) async {
    final Directory documentDirectory =
        await getApplicationDocumentsDirectory();
    final String wavPath = '${documentDirectory.path}/${Uuid().v4()}.wav';

    final audioFile = File(wavPath);

    if (_hasWavHeader(voiceData)) {
      await audioFile.writeAsBytes(voiceData);
      return wavPath;
    }

    final int sampleRate = 16000;
    final int numChannels = 1;
    final int byteRate = sampleRate * numChannels * 2;
    final int blockAlign = numChannels * 2;
    final int bitsPerSample = 16;
    final int dataSize = voiceData.length;
    final int chunkSize = 36 + dataSize;

    final List<int> header = [
      ...ascii.encode('RIFF'),
      chunkSize & 0xff, (chunkSize >> 8) & 0xff,
      (chunkSize >> 16) & 0xff, (chunkSize >> 24) & 0xff,
      ...ascii.encode('WAVE'),
      ...ascii.encode('fmt '),
      16, 0, 0, 0,
      1, 0,
      numChannels, 0,
      sampleRate & 0xff, (sampleRate >> 8) & 0xff,
      (sampleRate >> 16) & 0xff, (sampleRate >> 24) & 0xff,
      byteRate & 0xff, (byteRate >> 8) & 0xff,
      (byteRate >> 16) & 0xff, (byteRate >> 24) & 0xff,
      blockAlign, 0,
      bitsPerSample, 0,
      ...ascii.encode('data'),
      dataSize & 0xff, (dataSize >> 8) & 0xff,
      (dataSize >> 16) & 0xff, (dataSize >> 24) & 0xff,
    ];
    header.addAll(voiceData.toList());

    await audioFile.writeAsBytes(Uint8List.fromList(header));
    return wavPath;
  }

  @override
  Future<Map<String, dynamic>> transcribeWithDiarization(
    Uint8List voiceData, {
    int? numSpeakers,
    String? sessionId,
  }) async {
    debugPrint(
        'Transcribing with diarization: ${voiceData.length} bytes');
    await init();

    final wavPath = await _buildWavFile(voiceData);

    try {
      final url = await getBaseURL();
      final sanitizedUrl = UrlSecurity.sanitizeBaseUrl(
        url!,
        allowHttpOnLocalhost: true,
      );
      final apiKey = await getApiKey();
      final model = await getEffectiveModel();

      // Use multipart request to pass enable_diarization param
      final uri = Uri.parse('$sanitizedUrl/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer ${apiKey ?? ""}';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        wavPath,
        filename: 'audio.wav',
      ));
      request.fields['model'] = model;
      request.fields['enable_diarization'] = 'true';
      request.fields['response_format'] = 'verbose_json';
      if (numSpeakers != null) {
        request.fields['num_speakers'] = numSpeakers.toString();
      }
      if (sessionId != null) {
        request.fields['session_id'] = sessionId;
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode != 200) {
        throw Exception(
            'Diarization request failed (${streamedResponse.statusCode}): $responseBody');
      }

      final result = jsonDecode(responseBody) as Map<String, dynamic>;
      debugPrint('Diarization result: ${result['text']?.toString().substring(0, (result['text']?.toString().length ?? 0).clamp(0, 100))}...');

      // Clean up
      await File(wavPath).delete();

      return result;
    } catch (e) {
      try {
        await File(wavPath).delete();
      } catch (_) {}
      debugPrint('Diarization transcription error: $e');
      // Fall back to plain transcription
      final text = await transcribe(voiceData);
      return {'text': text, 'segments': [], 'language': null};
    }
  }

  @override
  Future<String?> getTranscription() async {
    // Call the implementation from the abstract class
    try {
      // Simulate processing time
      await Future.delayed(const Duration(seconds: 2));

      // Return dummy transcription for testing
      return "What's on my schedule for today?";
    } catch (e) {
      debugPrint('Error in WhisperRemoteService.getTranscription: $e');
      return null;
    }
  }

  /// Send a live conversation audio chunk to the AGiXT live transcription
  /// endpoint. Returns the parsed response with notes, suggestions, and
  /// action items formatted for glasses display.
  Future<Map<String, dynamic>> sendLiveChunk({
    required Uint8List audioData,
    required String sessionId,
    required int chunkIndex,
    bool isFinal = false,
    String agentName = 'XT',
    String? conversationName,
  }) async {
    debugPrint(
        'WhisperRemoteService: Sending live chunk #$chunkIndex (${audioData.length} bytes, final=$isFinal)');
    await init();

    final wavPath = await _buildWavFile(audioData);

    try {
      final url = await getBaseURL();
      final sanitizedUrl = UrlSecurity.sanitizeBaseUrl(
        url!,
        allowHttpOnLocalhost: true,
      );
      final apiKey = await getApiKey();

      final uri =
          Uri.parse('$sanitizedUrl/v1/audio/transcriptions/live');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer ${apiKey ?? ""}';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        wavPath,
        filename: 'audio.wav',
      ));
      request.fields['agent_name'] = agentName;
      request.fields['session_id'] = sessionId;
      request.fields['chunk_index'] = chunkIndex.toString();
      request.fields['is_final'] = isFinal.toString();
      if (conversationName != null) {
        request.fields['conversation_name'] = conversationName;
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode != 200) {
        throw Exception(
            'Live transcription request failed (${streamedResponse.statusCode}): $responseBody');
      }

      final result = jsonDecode(responseBody) as Map<String, dynamic>;
      debugPrint(
          'Live chunk #$chunkIndex result: notes=${result['notes']}, suggestions=${result['suggestions']}');

      await File(wavPath).delete();
      return result;
    } catch (e) {
      try {
        await File(wavPath).delete();
      } catch (_) {}
      debugPrint('Live chunk send error: $e');
      rethrow;
    }
  }

  Future<void> transcribeLive(
    Stream<Uint8List> voiceData,
    StreamController<String> out,
  ) async {
    await init();

    final rawUrl = await getBaseURL();
    if (rawUrl == null || rawUrl.isEmpty) {
      throw Exception('No Whisper Remote URL set');
    }
    final sanitizedUrl = UrlSecurity.sanitizeBaseUrl(
      rawUrl,
      allowHttpOnLocalhost: true,
    );
    final baseUri = Uri.parse(sanitizedUrl);

    final model = await getEffectiveModel();

    final socket = WebSocketChannel.connect(
      UrlSecurity.buildWebSocketUri(
        baseUri,
        path: 'v1/audio/transcriptions',
        queryParameters: {'model': model},
      ),
    );

    // Add wav header
    final int sampleRate = 16000;
    final int numChannels = 1;
    final int byteRate = sampleRate * numChannels * 2;
    final int blockAlign = numChannels * 2;
    final int bitsPerSample = 16;
    final int dataSize = 99999999999999999; // set as high as well.. we can
    final int chunkSize = 36 + dataSize;

    final List<int> header = [
      // RIFF header
      ...ascii.encode('RIFF'),
      chunkSize & 0xff,
      (chunkSize >> 8) & 0xff,
      (chunkSize >> 16) & 0xff,
      (chunkSize >> 24) & 0xff,
      // WAVE header
      ...ascii.encode('WAVE'),
      // fmt subchunk
      ...ascii.encode('fmt '),
      16, 0, 0, 0, // Subchunk1Size (16 for PCM)
      1, 0, // AudioFormat (1 for PCM)
      numChannels, 0, // NumChannels
      sampleRate & 0xff,
      (sampleRate >> 8) & 0xff,
      (sampleRate >> 16) & 0xff,
      (sampleRate >> 24) & 0xff,
      byteRate & 0xff,
      (byteRate >> 8) & 0xff,
      (byteRate >> 16) & 0xff,
      (byteRate >> 24) & 0xff,
      blockAlign, 0,
      bitsPerSample, 0,
      // data subchunk
      ...ascii.encode('data'),
      dataSize & 0xff,
      (dataSize >> 8) & 0xff,
      (dataSize >> 16) & 0xff,
      (dataSize >> 24) & 0xff,
    ];

    socket.sink.add(header);

    // Listen to messages from the server.
    socket.stream.listen((message) {
      final String payload;
      if (message is List<int>) {
        payload = utf8.decode(message);
      } else if (message is String) {
        payload = message;
      } else {
        return;
      }
      final resp = LiveResponse.fromJson(jsonDecode(payload));
      out.add(resp.text ?? '');
    });

    await for (final data in voiceData) {
      socket.sink.add(data);
    }

    await socket.sink.close();
  }
}

class LiveResponse {
  String? text;

  LiveResponse({this.text});

  LiveResponse.fromJson(Map<String, dynamic> json) {
    text = json['text'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['text'] = text;
    return data;
  }
}
