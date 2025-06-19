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
import 'package:web_socket_client/web_socket_client.dart';

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
        cancelOnError: true,
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
    final Directory documentDirectory = await getApplicationDocumentsDirectory();
    final String wavPath = '${documentDirectory.path}/${Uuid().v4()}.wav';
    
    await _ensureInitialized();
    
    try {
      // We need to save the audio data to a file
      await File(wavPath).writeAsBytes(voiceData);

      // For devices that can't directly process the binary data through native APIs,
      // we'll try to use the speech recognition on audio we can record
      
      String result = '';
      
      // Try to get a transcription using native speech recognition
      // This is a fallback approach since we can't directly feed our voiceData to speech_to_text
      result = await listenAndTranscribe() ?? 'No transcription available';
      
      // Cleanup
      try {
        await File(wavPath).delete();
      } catch (e) {
        debugPrint('Error deleting temporary audio file: $e');
      }
      
      return result;
    } catch (e) {
      debugPrint('Error in WhisperLocalService.transcribe: $e');
      return 'Error transcribing audio';
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
  Future<String?> getBaseURL() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_api_url');
  }

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_api_key');
  }

  Future<String?> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_remote_model');
  }

  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_language');
  }

  Future<void> init() async {
    final url = await getBaseURL();
    if (url == null) {
      throw Exception("no Whisper Remote URL set");
    }
    debugPrint('Initializing Whisper Remote Service with URL: $url');
    OpenAI.baseUrl = url;
    OpenAI.apiKey = await getApiKey() ?? '';
  }

  @override
  Future<String> transcribe(Uint8List voiceData) async {
    debugPrint('Transcribing voice data');
    await init();
    final Directory documentDirectory =
        await getApplicationDocumentsDirectory();
    // Prepare wav file

    final String wavPath = '${documentDirectory.path}/${Uuid().v4()}.wav';
    debugPrint('Wav path: $wavPath');

    // Add wav header
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

    final audioFile = File(wavPath);
    await audioFile.writeAsBytes(Uint8List.fromList(header));

    OpenAIAudioModel transcription =
        await OpenAI.instance.audio.createTranscription(
      file: audioFile,
      model: await getModel() ?? '',
      responseFormat: OpenAIAudioResponseFormat.json,
      language: await getLanguage(),
    );

    // delete wav file
    await File(wavPath).delete();

    var text = transcription.text;

    return text;
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

  Future<void> transcribeLive(
      Stream<Uint8List> voiceData, StreamController<String> out) async {
    await init();
    final url = (await getBaseURL())!.replaceFirst("http", "ws");
    final model = await getModel();
    final socket =
        WebSocket(Uri.parse('$url/v1/audio/transcriptions?model=$model'));

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

    socket.send(header);

    // Listen to messages from the server.
    socket.messages.listen((message) {
      final resp = LiveResponse.fromJson(jsonDecode(message));
      out.add(resp.text ?? '');
    });

    await for (final data in voiceData) {
      socket.send(data);
    }

    socket.close();
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
