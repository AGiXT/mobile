import 'dart:async';

import 'package:agixt/services/bluetooth_manager.dart';
import 'package:flutter/material.dart';

class GlassStatus extends StatefulWidget {
  const GlassStatus({super.key});

  @override
  State<GlassStatus> createState() => GlassStatusState();
}

class GlassStatusState extends State<GlassStatus> {
  final BluetoothManager bluetoothManager = BluetoothManager();

  bool isConnected = false;
  bool isScanning = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshData() {
    if (!mounted) {
      return;
    }
    setState(() {
      isConnected = bluetoothManager.isConnected;
      isScanning = bluetoothManager.isScanning;
    });
  }

  Future<void> _disconnect() async {
    try {
      await bluetoothManager.disconnectFromGlasses();
      _refreshData();
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  void _scanAndConnect() {
    try {
      bluetoothManager.startScanAndConnect(
        onUpdate: (_) => _refreshData(),
      );
    } catch (e) {
      debugPrint('Error in _scanAndConnect: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = isConnected;
    final scanning = isScanning;

    final Color accent = connected
        ? theme.colorScheme.secondary
        : theme.colorScheme.error;
    final Color accentContainer = connected
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.errorContainer;

    final String statusTitle = connected
        ? 'Connected to Even Realities G1 glasses'
        : 'Disconnected from Even Realities G1 glasses';
    final String statusBody = connected
        ? 'Your glasses are synced and receiving updates.'
        : 'Tap connect to scan for your glasses and resume updates.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: accentContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                connected
                    ? Icons.check_circle_rounded
                    : Icons.portable_wifi_off_rounded,
                color: accent,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          statusBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (connected)
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Disconnect'),
              ),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: scanning ? null : _scanAndConnect,
              child: scanning
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Scanning for your glasses...'),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.link_rounded),
                        SizedBox(width: 8),
                        Text('Connect glasses'),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}
