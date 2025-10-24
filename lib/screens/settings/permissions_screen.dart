import 'package:flutter/material.dart';
import 'package:agixt/services/permission_manager.dart';

class PermissionsSettingsPage extends StatefulWidget {
  const PermissionsSettingsPage({super.key});

  @override
  State<PermissionsSettingsPage> createState() =>
      _PermissionsSettingsPageState();
}

class _PermissionsSettingsPageState extends State<PermissionsSettingsPage> {
  final Map<AppPermission, PermissionSummary> _summaries = {};
  final Set<AppPermission> _inFlight = <AppPermission>{};
  late final List<PermissionDefinition> _definitions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _definitions = PermissionManager.availableDefinitions;
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final Map<AppPermission, PermissionSummary> next = {};
    for (final definition in _definitions) {
      next[definition.id] = await PermissionManager.getSummary(definition.id);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _summaries
        ..clear()
        ..addAll(next);
      _isLoading = false;
    });
  }

  Future<void> _refreshSingle(AppPermission permission) async {
    final summary = await PermissionManager.getSummary(permission);
    if (!mounted) {
      return;
    }
    setState(() {
      _summaries[permission] = summary;
    });
  }

  Future<void> _handleToggle(AppPermission permission, bool value) async {
    if (_inFlight.contains(permission)) {
      return;
    }

    setState(() {
      _inFlight.add(permission);
    });

    try {
      if (value) {
        final granted = await PermissionManager.ensureGranted(permission);
        if (!granted && mounted) {
          _showSnack(
              'Permission is still disabled. Please enable it from system settings.');
        }
      } else {
        final settingsOpened = await PermissionManager.openSettings();
        if (!settingsOpened && mounted) {
          _showSnack('Unable to open system settings.');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _inFlight.remove(permission);
        });
      }
    }

    await _refreshSingle(permission);
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  IconData _iconFor(AppPermission permission) {
    switch (permission) {
      case AppPermission.bluetooth:
        return Icons.bluetooth;
      case AppPermission.location:
        return Icons.location_on;
      case AppPermission.notifications:
        return Icons.notifications_active;
      case AppPermission.calendar:
        return Icons.calendar_today;
      case AppPermission.microphone:
        return Icons.mic;
      case AppPermission.storage:
        return Icons.folder;
      case AppPermission.batteryOptimization:
        return Icons.battery_alert;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _definitions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'This device does not require additional permissions.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSummaries,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: _definitions
                        .map((definition) => _buildPermissionCard(definition))
                        .toList(),
                  ),
                ),
    );
  }

  Widget _buildPermissionCard(PermissionDefinition definition) {
    final summary = _summaries[definition.id];
    final granted = summary?.allGranted ?? false;
    final permanentlyDenied = summary?.anyPermanentlyDenied ?? false;
    final isWorking = _inFlight.contains(definition.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _iconFor(definition.id),
                  color: granted
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              definition.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (definition.requiredForCoreFlow)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Chip(
                                label: const Text('Required'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        definition.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (permanentlyDenied)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Turn this back on from system settings to restore full access.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: granted,
                  onChanged: isWorking
                      ? null
                      : (value) => _handleToggle(definition.id, value),
                ),
              ],
            ),
            if (isWorking) const LinearProgressIndicator(minHeight: 2),
            if (!granted)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: isWorking
                      ? null
                      : () => _handleToggle(definition.id, false),
                  icon: const Icon(Icons.settings),
                  label: const Text('Open system settings'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
