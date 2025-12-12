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
  bool _isConnected = false;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _loadGlassesDisplayPreference();
    _startBatteryStatusTracking();
    _startConnectionStatusTracking();
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

  void _startConnectionStatusTracking() {
    final bluetoothManager = BluetoothManager();
    _isConnected = bluetoothManager.isConnected;
    _connectionSubscription =
        bluetoothManager.connectionStatusStream.listen((connected) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = connected;
      });
    });
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = _isConnected;
    final lowestBattery =
        isConnected ? _batteryStatus.lowestBatteryPercentage : null;

    return Scaffold(
      body: SafeArea(
        child: Container(
          color: theme.colorScheme.surface,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(
                  theme,
                  isConnected: isConnected,
                  batteryPercentage: lowestBattery,
                ),
                const SizedBox(height: 24),
                _buildStatusCard(theme),
                const SizedBox(height: 16),
                _buildDisplayCard(theme),
                const SizedBox(height: 16),
                _buildActionsCard(theme),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'v0.0.68',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(
    ThemeData theme, {
    required bool isConnected,
    required int? batteryPercentage,
  }) {
    final gradient = LinearGradient(
      colors: [
        theme.colorScheme.primary,
        theme.colorScheme.primaryContainer,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.filledTonal(
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                  ),
                ),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: theme.colorScheme.onPrimary,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Glasses Settings',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Keep your Even Realities G1 glasses connected and tuned to your day.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatusChip(
                icon: isConnected
                    ? Icons.check_circle_rounded
                    : Icons.portable_wifi_off_rounded,
                label: isConnected ? 'Connected' : 'Disconnected',
                tone: isConnected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.error,
                onColor: theme.colorScheme.onSecondary,
              ),
              _StatusChip(
                icon: _batteryStatus.isAnyCharging
                    ? Icons.bolt_rounded
                    : Icons.battery_5_bar_rounded,
                label: batteryPercentage != null
                    ? '$batteryPercentage%'
                        '${_batteryStatus.isAnyCharging ? ' · Charging' : ''}'
                    : 'Battery unavailable',
                tone: theme.colorScheme.surface.withValues(alpha: 0.25),
                onColor: theme.colorScheme.onPrimary,
              ),
              _StatusChip(
                icon: Icons.update_rounded,
                label:
                    'Updated ${_formatRelativeTime(_batteryStatus.lastUpdated)}',
                tone: theme.colorScheme.surface.withValues(alpha: 0.25),
                onColor: theme.colorScheme.onPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.podcasts_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Live connection',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.35 : 0.6,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: GlassStatus(),
              ),
            ),
            if (_isConnected) ...[
              const SizedBox(height: 20),
              G1BatteryWidget(
                batteryStatus: _batteryStatus,
                showDetails: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus & presence',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep your display calm during meetings or moments when you need to stay heads-up.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: !_isGlassesDisplayEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isGlassesDisplayEnabled = !value;
                    });
                    _saveGlassesDisplayPreference(!value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.25 : 0.5,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Silent mode pauses timeline updates and notifications on your glasses until you turn it back off.',
                ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.primary,
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

  String _formatRelativeTime(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onColor,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: onColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: onColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
