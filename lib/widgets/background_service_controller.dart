import 'package:agixt/services/bluetooth_background_service.dart';
import 'package:flutter/material.dart';

class BackgroundServiceController extends StatefulWidget {
  const BackgroundServiceController({super.key});

  @override
  State<BackgroundServiceController> createState() =>
      _BackgroundServiceControllerState();
}

class _BackgroundServiceControllerState
    extends State<BackgroundServiceController> {
  bool _isServiceRunning = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await BluetoothBackgroundService.isRunning();
    setState(() {
      _isServiceRunning = isRunning;
    });
  }

  Future<void> _toggleBackgroundService() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isServiceRunning) {
        await BluetoothBackgroundService.stop();
      } else {
        await BluetoothBackgroundService.start();
      }

      // Wait a moment for the service to start/stop
      await Future.delayed(const Duration(milliseconds: 1000));
      await _checkServiceStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bluetooth_connected,
                  color: _isServiceRunning ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Background Connection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isServiceRunning
                  ? 'Glasses connection is being maintained in the background. Your glasses will stay connected even when the phone is locked.'
                  : 'Background connection is disabled. Your glasses may disconnect when the phone is locked.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _toggleBackgroundService,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_isServiceRunning ? Icons.stop : Icons.play_arrow),
                label: Text(_isServiceRunning
                    ? 'Stop Background Service'
                    : 'Start Background Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isServiceRunning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (_isServiceRunning) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The background service is active and will keep your glasses connected.',
                        style:
                            TextStyle(color: Colors.green[800], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
