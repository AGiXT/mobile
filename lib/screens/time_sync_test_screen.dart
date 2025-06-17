import 'package:flutter/material.dart';
import '../services/time_sync.dart';
import '../services/bluetooth_manager.dart';

class TimeSyncTestScreen extends StatefulWidget {
  const TimeSyncTestScreen({super.key});

  @override
  State<TimeSyncTestScreen> createState() => _TimeSyncTestScreenState();
}

class _TimeSyncTestScreenState extends State<TimeSyncTestScreen> {
  final BluetoothManager _bluetoothManager = BluetoothManager();
  bool _isSyncing = false;
  String _lastSyncTime = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Sync Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _bluetoothManager.isConnected 
                          ? Icons.bluetooth_connected 
                          : Icons.bluetooth_disabled,
                      size: 48,
                      color: _bluetoothManager.isConnected 
                          ? Colors.green 
                          : Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _bluetoothManager.isConnected 
                          ? 'Connected to G1 Glasses' 
                          : 'Not Connected',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current Time',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateTime.now().toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Epoch: ${DateTime.now().millisecondsSinceEpoch}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing || !_bluetoothManager.isConnected 
                    ? null 
                    : _syncTime,
                icon: _isSyncing 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync Time with Glasses'),
              ),
            ),
            if (_lastSyncTime.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      const Text('Last Sync Successful'),
                      const SizedBox(height: 4),
                      Text(
                        _lastSyncTime,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Sync Information',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Synchronizes current system time with G1 glasses'),
                    Text('• Sends both 32-bit seconds and 64-bit milliseconds epoch'),
                    Text('• Sets placeholder weather (Sunny, 21°C, Celsius, 24H)'),
                    Text('• Uses BLE command 0x06 with subcommand 0x01'),
                    Text('• Automatically syncs when glasses connect'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncTime() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      await TimeSync.updateTimeAndWeather();
      setState(() {
        _lastSyncTime = DateTime.now().toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Time synchronized successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Time sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
}
