import 'package:flutter/material.dart';
import '../../services/bluetooth_manager.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final BluetoothManager _bluetoothManager = BluetoothManager.singleton;
  
  String _currentWeatherInfo = 'Loading...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentWeather();
  }

  Future<void> _loadCurrentWeather() async {
    try {
      final weatherInfo = await _bluetoothManager.getCurrentWeatherInfo();
      setState(() {
        _currentWeatherInfo = weatherInfo;
      });
    } catch (e) {
      debugPrint('Error loading current weather: $e');
      setState(() {
        _currentWeatherInfo = 'Error loading weather';
      });
    }
  }

  Future<void> _refreshWeather() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _bluetoothManager.updateWeather();
      await _loadCurrentWeather();
      _showSnackBar('Weather refreshed');
    } catch (e) {
      debugPrint('Error refreshing weather: $e');
      _showSnackBar('Error refreshing weather');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Weather',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentWeatherInfo,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _refreshWeather,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Refresh Weather'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About Weather',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Weather information is automatically obtained from your device and displayed on your glasses when connected. '
                      'The weather data updates every few minutes when glasses are connected. '
                      'No external weather services or API keys are required.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Connection Status: ${_bluetoothManager.isConnected ? "Connected" : "Disconnected"}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _bluetoothManager.isConnected 
                            ? Colors.green 
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Weather Source: Device System',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
