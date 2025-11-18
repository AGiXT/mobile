import 'dart:async';
import 'package:flutter/material.dart';

import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/g1/battery.dart';
import 'package:agixt/screens/settings/dashboard_screen.dart';
import 'package:agixt/screens/settings/location_screen.dart';
import 'package:agixt/screens/settings/notifications_screen.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/widgets/g1_battery_widget.dart';
import 'package:agixt/widgets/glass_status.dart';

class GlassesSettingsPage extends StatefulWidget {
  const GlassesSettingsPage({super.key});

  @override
  State<GlassesSettingsPage> createState() => _GlassesSettingsPageState();
}

class _GlassesSettingsPageState extends State<GlassesSettingsPage> {
  bool _isGlassesDisplayEnabled = true;
  G1BatteryStatus _batteryStatus = G1BatteryStatus(lastUpdated: DateTime.now());
  StreamSubscription<G1BatteryStatus>? _batterySubscription;

  @override
  void initState() {
    super.initState();
    _loadGlassesDisplayPreference();
    _startBatteryStatusTracking();
  }

  Future<void> _loadGlassesDisplayPreference() async {
    final preference = await AuthService.getGlassesDisplayPreference();
    if (!mounted) {
      return;
    }
    setState(() {
      _isGlassesDisplayEnabled = preference;
    });
  }

  Future<void> _saveGlassesDisplayPreference(bool value) async {
    await AuthService.setGlassesDisplayPreference(value);

    final bluetoothManager = BluetoothManager();

    if (bluetoothManager.isConnected) {
      await bluetoothManager.setSilentMode(!value);

      if (!value) {
        await bluetoothManager.clearGlassesDisplay();
      }
    }
  }

  void _startBatteryStatusTracking() {
    try {
      final bluetoothManager = BluetoothManager();

      _batterySubscription = bluetoothManager.batteryStatusStream.listen(
        (status) {
          if (mounted) {
            setState(() {
              _batteryStatus = status;
            });
          }
        },
        onError: (error) {
          debugPrint('Battery status stream error: $error');
        },
      );

      if (mounted) {
        setState(() {
          _batteryStatus = bluetoothManager.batteryStatus;
        });
      }

      try {
        bluetoothManager.requestBatteryInfo();
      } catch (e) {
        debugPrint('Error requesting battery info in settings: $e');
      }
    } catch (e) {
      debugPrint('Error starting battery status tracking: $e');
    }
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Container(
          color: theme.colorScheme.surface,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: 24),
                _buildStatusCard(theme),
                const SizedBox(height: 16),
                _buildDisplayCard(theme),
                const SizedBox(height: 16),
                _buildActionsCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(
              theme.brightness == Brightness.dark ? 0.4 : 0.8,
            ),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Glasses Settings',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep your Even Realities G1 glasses connected and tuned to your day.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const GlassStatus(),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            G1BatteryWidget(
              batteryStatus: _batteryStatus,
              showDetails: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus & display',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: !_isGlassesDisplayEnabled,
              onChanged: (value) {
                setState(() {
                  _isGlassesDisplayEnabled = !value;
                });
                _saveGlassesDisplayPreference(!value);
              },
              title: const Text('Glasses silent mode'),
              subtitle: const Text(
                'Pause updates to the glasses display when you need fewer distractions.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.dashboard_customize_outlined,
            title: 'Dashboard preferences',
            subtitle: 'Choose what shows on your glasses timeline.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const DashboardSettingsPage()),
              );
            },
          ),
          const Divider(height: 1),
          _buildActionTile(
            icon: Icons.notifications_active_outlined,
            title: 'Notification routing',
            subtitle: 'Control which alerts reach your glasses in real time.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NotificationSettingsPage()),
              );
            },
          ),
          const Divider(height: 1),
          _buildActionTile(
            icon: Icons.location_on_outlined,
            title: 'Location & weather',
            subtitle: 'Share location data for accurate on-glasses updates.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LocationSettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          icon,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        title,
        style:
            theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
