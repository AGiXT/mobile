import 'package:agixt/models/agixt/whispermodel.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class WhisperSettingsPage extends StatefulWidget {
  const WhisperSettingsPage({super.key});

  @override
  WhisperSettingsPageState createState() => WhisperSettingsPageState();
}

class WhisperSettingsPageState extends State<WhisperSettingsPage> {
  final List<String> _models = AGiXTWhisperModel.models;
  final List<String> _languages = [
    'en',
    'es',
    'fr',
    'de',
    'it',
    'pt',
    'nl',
    'ru',
    'zh',
    'ja',
    'ko',
    'ar',
    'hi',
    'bn',
    'ur',
    'ta',
    'te',
    'mr',
    'gu',
    'kn',
    'ml',
    'pa',
    'th',
    'vi',
    'tl',
    'tr',
    'fa',
    'he',
    'sw',
  ];

  String? _selectedModel;
  String? _selectedMode;
  String? _selectedLanguage;
  bool _isRecognitionAvailable = false;

  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _remoteModelController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSelectedModel();
    _checkSpeechRecognitionAvailability();
  }

  Future<void> _checkSpeechRecognitionAvailability() async {
    final available = await _speech.initialize(
      onError: (error) => debugPrint('Speech recognition error: $error'),
      onStatus: (status) => debugPrint('Speech recognition status: $status'),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isRecognitionAvailable = available;
    });
  }

  Future<void> _loadSelectedModel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedModel = prefs.getString('whisper_model') ?? 'base';
      _selectedMode = prefs.getString('whisper_mode') ?? 'local';
      _selectedLanguage = prefs.getString('whisper_language') ?? 'en';
      _apiUrlController.text = prefs.getString('whisper_api_url') ?? '';
      _apiKeyController.text = prefs.getString('whisper_api_key') ?? '';
      _remoteModelController.text =
          prefs.getString('whisper_remote_model') ?? '';
    });
  }

  Future<void> _saveSelectedModel(String model) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('whisper_model', model);
  }

  Future<void> _saveSelectedLanguage(String lang) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('whisper_language', lang);
  }

  Future<void> _saveSelectedMode(String mode) async {
    setState(() {
      _selectedMode = mode;
    });
    if (mode == "local") {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('whisper_mode', mode);
    }
  }

  Future<void> _testSpeechRecognition() async {
    if (!_isRecognitionAvailable) {
      _showSnackBar('Speech recognition not available on this device');
      return;
    }

    bool success = await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _showSnackBar('Recognized: ${result.recognizedWords}');
          _speech.stop();
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: _selectedLanguage,
      listenOptions: stt.SpeechListenOptions(cancelOnError: true),
    );

    if (!success) {
      _showSnackBar('Failed to start speech recognition');
    } else {
      _showSnackBar('Listening...');
    }
  }

  Future<void> _saveRemote() async {
    // Implement the logic to save remote settings
    try {
      if (_apiUrlController.text.isEmpty) {
        throw Exception("API URL is required");
      }
      if (_remoteModelController.text.isEmpty) {
        throw Exception("Model is required");
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('whisper_mode', _selectedMode!);
      await prefs.setString('whisper_api_url', _apiUrlController.text);
      await prefs.setString('whisper_api_key', _apiKeyController.text);
      await prefs.setString(
        'whisper_remote_model',
        _remoteModelController.text,
      );

      _showSnackBar(
        'Whisper configuration saved!',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      _showSnackBar('Error ${e.toString()}', backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localOpts = [
      const Text('Select Model/Accuracy:', style: TextStyle(fontSize: 18)),
      const SizedBox(height: 10),
      DropdownButton<String>(
        value: _selectedModel,
        isExpanded: true,
        onChanged: (String? newValue) {
          setState(() {
            _selectedModel = newValue;
          });
          _saveSelectedModel(newValue!);
        },
        items:
            _models.map<DropdownMenuItem<String>>((String model) {
              return DropdownMenuItem<String>(value: model, child: Text(model));
            }).toList(),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _testSpeechRecognition,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 36), // Expand full width
        ),
        child: const Text('Test Speech Recognition'),
      ),
      const SizedBox(height: 10),
      _isRecognitionAvailable
          ? const Text(
            'Speech recognition is available on this device',
            style: TextStyle(color: Colors.green),
          )
          : const Text(
            'Speech recognition is NOT available on this device',
            style: TextStyle(color: Colors.red),
          ),
    ];
    final remoteOpts = [
      const Text('Whisper server details:', style: TextStyle(fontSize: 18)),
      const SizedBox(height: 10),
      TextField(
        decoration: const InputDecoration(labelText: 'API URL'),
        controller: _apiUrlController,
      ),
      const SizedBox(height: 10),
      TextField(
        decoration: const InputDecoration(labelText: 'API Key'),
        controller: _apiKeyController,
      ),
      const SizedBox(height: 20),
      TextField(
        decoration: const InputDecoration(labelText: 'Model'),
        controller: _remoteModelController,
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _saveRemote,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 36), // Expand full width
        ),
        child: const Text('Save'),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Speech Recognition Settings')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Mode:', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              DropdownButton(
                value: _selectedMode,
                onChanged: (String? newValue) => _saveSelectedMode(newValue!),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: "local", child: Text("Local")),
                  DropdownMenuItem(value: "remote", child: Text("Remote")),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Select Language:', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              DropdownButton(
                value: _selectedLanguage,
                onChanged:
                    (String? newValue) => _saveSelectedLanguage(newValue!),
                isExpanded: true,
                items:
                    _languages.map<DropdownMenuItem<String>>((String lang) {
                      return DropdownMenuItem<String>(
                        value: lang,
                        child: Text(lang),
                      );
                    }).toList(),
              ),
              ...(_selectedMode == "local" ? localOpts : remoteOpts),
            ],
          ),
        ),
      ),
    );
  }
}
