import 'package:flutter/material.dart';
import 'package:agixt/services/watch_service.dart';
import 'package:agixt/services/wake_word_service.dart';
import 'package:agixt/services/voice_input_service.dart';
import 'package:agixt/services/tts_service.dart';

/// Settings screen for voice input, wake word, watch, and TTS configuration
class VoiceWatchSettingsScreen extends StatefulWidget {
  const VoiceWatchSettingsScreen({super.key});

  @override
  State<VoiceWatchSettingsScreen> createState() =>
      _VoiceWatchSettingsScreenState();
}

class _VoiceWatchSettingsScreenState extends State<VoiceWatchSettingsScreen> {
  final WatchService _watchService = WatchService.singleton;
  final WakeWordService _wakeWordService = WakeWordService.singleton;
  final VoiceInputService _voiceInputService = VoiceInputService.singleton;
  final TTSService _ttsService = TTSService.singleton;

  // State
  bool _watchEnabled = true;
  bool _watchConnected = false;
  bool _wakeWordEnabled = false;
  String _wakeWord = 'computer';
  double _wakeWordSensitivity = 0.5;
  VoiceInputSource _preferredVoiceSource = VoiceInputSource.glasses;
  TTSMode _ttsMode = TTSMode.auto;
  double _ttsRate = 1.0;
  double _ttsPitch = 1.0;
  double _ttsVolume = 1.0;
  bool _isLoading = true;
  bool _wakeWordAvailable = true;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadSettings();
  }

  Future<void> _initializeAndLoadSettings() async {
    // Ensure services are initialized before loading settings
    try {
      await _wakeWordService.initialize();
      await _watchService.initialize();
      await _ttsService.initialize();
    } catch (e) {
      debugPrint('VoiceWatchSettings: Error initializing services: $e');
    }

    // Load settings after initialization
    if (mounted) {
      setState(() {
        _watchEnabled = _watchService.isEnabled;
        _watchConnected = _watchService.isConnected;
        _wakeWordEnabled = _wakeWordService.isEnabled;
        _wakeWordAvailable = _wakeWordService.isInitialized;
        _wakeWord = _wakeWordService.wakeWord;
        _wakeWordSensitivity = _wakeWordService.sensitivity;
        _ttsMode = _ttsService.preferredMode;
        _ttsRate = _ttsService.rate;
        _ttsPitch = _ttsService.pitch;
        _ttsVolume = _ttsService.volume;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Voice & Watch Settings'), elevation: 0),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wake Word Section
                    _buildSectionHeader(theme, 'Wake Word', Icons.mic_rounded),
                    _buildCard(
                      theme,
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Enable Wake Word'),
                            subtitle: Text(
                              _wakeWordAvailable
                                  ? 'Say "$_wakeWord" to start voice input'
                                  : 'Wake word detection not available on this device',
                            ),
                            value: _wakeWordEnabled,
                            onChanged:
                                _wakeWordAvailable
                                    ? (value) async {
                                      await _wakeWordService.setEnabled(value);
                                      setState(() => _wakeWordEnabled = value);
                                    }
                                    : null,
                          ),
                          if (!_wakeWordAvailable) ...[
                            const Divider(height: 1),
                            _buildInfoTile(
                              theme,
                              icon: Icons.warning_amber_rounded,
                              text:
                                  'Wake word requires native speech recognition support. This may need additional setup.',
                              color: theme.colorScheme.error,
                            ),
                          ],
                          if (_wakeWordEnabled && _wakeWordAvailable) ...[
                            const Divider(height: 1),
                            _buildSliderTile(
                              theme,
                              title: 'Sensitivity',
                              subtitle:
                                  _wakeWordSensitivity < 0.3
                                      ? 'Low (fewer false positives)'
                                      : _wakeWordSensitivity > 0.7
                                      ? 'High (more responsive)'
                                      : 'Medium',
                              value: _wakeWordSensitivity,
                              onChanged: (value) async {
                                await _wakeWordService.setSensitivity(value);
                                setState(() => _wakeWordSensitivity = value);
                              },
                            ),
                            const Divider(height: 1),
                            _buildInfoTile(
                              theme,
                              icon: Icons.info_outline,
                              text:
                                  'Wake word detection uses on-device processing for privacy.',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pixel Watch Section
                    _buildSectionHeader(
                      theme,
                      'Pixel Watch',
                      Icons.watch_rounded,
                    ),
                    _buildCard(
                      theme,
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            theme,
                            title: 'Enable Watch Support',
                            subtitle:
                                _watchConnected
                                    ? 'Connected: ${_watchService.connectedWatchName ?? "Pixel Watch"}'
                                    : 'Allow connection to Pixel Watch',
                            value: _watchEnabled,
                            onChanged: (value) async {
                              await _watchService.setEnabled(value);
                              setState(() => _watchEnabled = value);
                            },
                          ),
                          if (_watchEnabled && _watchConnected) ...[
                            const Divider(height: 1),
                            _buildInfoTile(
                              theme,
                              icon: Icons.check_circle_outline,
                              text:
                                  'Watch can be used as a fallback microphone and for TTS output.',
                              color: Colors.green,
                            ),
                          ] else if (_watchEnabled && !_watchConnected) ...[
                            const Divider(height: 1),
                            _buildInfoTile(
                              theme,
                              icon: Icons.watch_off_rounded,
                              text:
                                  'No watch connected. Make sure your Pixel Watch is paired.',
                              color: theme.colorScheme.error,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Voice Input Source Section
                    _buildSectionHeader(
                      theme,
                      'Voice Input Source',
                      Icons.settings_voice_rounded,
                    ),
                    _buildCard(
                      theme,
                      child: Column(
                        children: [
                          _buildRadioTile<VoiceInputSource>(
                            theme,
                            title: 'Glasses Microphone',
                            subtitle:
                                'Use Even Realities G1 glasses mic (primary)',
                            value: VoiceInputSource.glasses,
                            groupValue: _preferredVoiceSource,
                            onChanged: (value) async {
                              if (value != null) {
                                await _voiceInputService.setPreferredSource(
                                  value,
                                );
                                setState(() => _preferredVoiceSource = value);
                              }
                            },
                          ),
                          const Divider(height: 1),
                          _buildRadioTile<VoiceInputSource>(
                            theme,
                            title: 'Watch Microphone',
                            subtitle:
                                'Use Pixel Watch mic (requires watch connection)',
                            value: VoiceInputSource.watch,
                            groupValue: _preferredVoiceSource,
                            enabled: _watchEnabled && _watchConnected,
                            onChanged: (value) async {
                              if (value != null) {
                                await _voiceInputService.setPreferredSource(
                                  value,
                                );
                                setState(() => _preferredVoiceSource = value);
                              }
                            },
                          ),
                          const Divider(height: 1),
                          _buildRadioTile<VoiceInputSource>(
                            theme,
                            title: 'Phone Microphone',
                            subtitle: 'Use phone\'s built-in microphone',
                            value: VoiceInputSource.phone,
                            groupValue: _preferredVoiceSource,
                            onChanged: (value) async {
                              if (value != null) {
                                await _voiceInputService.setPreferredSource(
                                  value,
                                );
                                setState(() => _preferredVoiceSource = value);
                              }
                            },
                          ),
                          const Divider(height: 1),
                          _buildInfoTile(
                            theme,
                            icon: Icons.info_outline,
                            text:
                                'If the preferred source is unavailable, the next available source will be used automatically.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Text-to-Speech Section
                    _buildSectionHeader(
                      theme,
                      'Text-to-Speech',
                      Icons.record_voice_over_rounded,
                    ),
                    _buildCard(
                      theme,
                      child: Column(
                        children: [
                          _buildDropdownTile<TTSMode>(
                            theme,
                            title: 'TTS Output',
                            subtitle: TTSService.getModeDisplayName(_ttsMode),
                            value: _ttsMode,
                            items: _ttsService.getAvailableModes(),
                            itemLabel: TTSService.getModeDisplayName,
                            onChanged: (value) async {
                              if (value != null) {
                                await _ttsService.setPreferredMode(value);
                                setState(() => _ttsMode = value);
                              }
                            },
                          ),
                          if (_ttsMode != TTSMode.none) ...[
                            const Divider(height: 1),
                            _buildSliderTile(
                              theme,
                              title: 'Speech Rate',
                              subtitle:
                                  _ttsRate < 0.8
                                      ? 'Slow'
                                      : _ttsRate > 1.2
                                      ? 'Fast'
                                      : 'Normal',
                              value: _ttsRate,
                              min: 0.5,
                              max: 2.0,
                              onChanged: (value) async {
                                await _ttsService.setRate(value);
                                setState(() => _ttsRate = value);
                              },
                            ),
                            const Divider(height: 1),
                            _buildSliderTile(
                              theme,
                              title: 'Pitch',
                              subtitle:
                                  _ttsPitch < 0.8
                                      ? 'Lower'
                                      : _ttsPitch > 1.2
                                      ? 'Higher'
                                      : 'Normal',
                              value: _ttsPitch,
                              min: 0.5,
                              max: 2.0,
                              onChanged: (value) async {
                                await _ttsService.setPitch(value);
                                setState(() => _ttsPitch = value);
                              },
                            ),
                            const Divider(height: 1),
                            _buildSliderTile(
                              theme,
                              title: 'Volume',
                              subtitle: '${(_ttsVolume * 100).round()}%',
                              value: _ttsVolume,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (value) async {
                                await _ttsService.setVolume(value);
                                setState(() => _ttsVolume = value);
                              },
                            ),
                          ],
                          const Divider(height: 1),
                          _buildInfoTile(
                            theme,
                            icon: Icons.info_outline,
                            text:
                                'Glasses don\'t have speakers, so TTS will use watch or phone when glasses are primary.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Test Section
                    _buildSectionHeader(
                      theme,
                      'Test',
                      Icons.play_arrow_rounded,
                    ),
                    _buildCard(
                      theme,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.record_voice_over),
                            title: const Text('Test TTS'),
                            subtitle: const Text('Speak a test message'),
                            trailing: ElevatedButton(
                              onPressed: () => _testTTS(),
                              child: const Text('Test'),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.mic),
                            title: const Text('Test Voice Input'),
                            subtitle: const Text('Record and transcribe'),
                            trailing: ElevatedButton(
                              onPressed: () => _testVoiceInput(),
                              child: const Text('Test'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ThemeData theme, {required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: child,
    );
  }

  Widget _buildSwitchTile(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSliderTile(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0.0,
    double max = 1.0,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildRadioTile<T>(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    return RadioListTile<T>(
      title: Text(
        title,
        style: TextStyle(color: enabled ? null : theme.disabledColor),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: enabled ? null : theme.disabledColor),
      ),
      value: value,
      groupValue: groupValue,
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _buildDropdownTile<T>(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<T>(
        value: value,
        items:
            items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item)),
              );
            }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildInfoTile(
    ThemeData theme, {
    required IconData icon,
    required String text,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testTTS() async {
    await _ttsService.speak(
      'Hello! This is a test of the text to speech output. AGiXT is ready to assist you.',
    );
  }

  Future<void> _testVoiceInput() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting voice recording... speak now!'),
        duration: Duration(seconds: 2),
      ),
    );

    final success = await _voiceInputService.startRecording(
      maxDuration: const Duration(seconds: 5),
    );

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start recording'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
