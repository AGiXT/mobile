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
  bool _bulkRequestInFlight = false;

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
    if (_bulkRequestInFlight || _inFlight.contains(permission)) {
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

  /// The essential permissions needed for core app functionality.
  /// These are the minimum permissions to make the app usable.
  static const Set<AppPermission> _requiredPermissions = {
    AppPermission.bluetooth, // Required to connect to glasses
    AppPermission.notifications, // Required for alerts and messages
    AppPermission.microphone, // Required for voice features
  };

  Future<void> _handleEnableRequiredPermissions() async {
    if (_bulkRequestInFlight || _isLoading) {
      return;
    }

    setState(() {
      _bulkRequestInFlight = true;
    });

    var anyFailures = false;

    for (final definition in _definitions) {
      // Only request required permissions
      if (!_requiredPermissions.contains(definition.id)) {
        continue;
      }

      final summary = _summaries[definition.id];
      if (summary?.allGranted ?? false) {
        continue;
      }

      final granted = await PermissionManager.ensureGranted(definition.id);
      if (!granted) {
        anyFailures = true;
      }
      await _refreshSingle(definition.id);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _bulkRequestInFlight = false;
    });

    _showSnack(
      anyFailures
          ? 'Some permissions still need to be enabled from system settings.'
          : 'Required permissions enabled. Other permissions will be requested when needed.',
    );
  }

  Future<void> _handleEnableAllPermissions() async {
    if (_bulkRequestInFlight || _isLoading) {
      return;
    }

    setState(() {
      _bulkRequestInFlight = true;
    });

    var anyFailures = false;

    for (final definition in _definitions) {
      final summary = _summaries[definition.id];
      if (summary?.allGranted ?? false) {
        continue;
      }

      final granted = await PermissionManager.ensureGranted(definition.id);
      if (!granted) {
        anyFailures = true;
      }
      await _refreshSingle(definition.id);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _bulkRequestInFlight = false;
    });

    _showSnack(
      anyFailures
          ? 'Some permissions still need to be enabled from system settings.'
          : 'All permissions enabled.',
    );
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
                    children: [
                      _buildBulkActionCard(),
                      const SizedBox(height: 12),
                      ..._definitions.map(_buildPermissionCard),
                    ],
                  ),
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.of(context).maybePop();
                  },
            icon: const Icon(Icons.check_circle),
            label: const Text('Done'),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard(PermissionDefinition definition) {
    final summary = _summaries[definition.id];
    final granted = summary?.allGranted ?? false;
    final permanentlyDenied = summary?.anyPermanentlyDenied ?? false;
    final isWorking = _bulkRequestInFlight || _inFlight.contains(definition.id);

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

  bool get _allRequiredGranted {
    for (final permission in _requiredPermissions) {
      final summary = _summaries[permission];
      if (!(summary?.allGranted ?? false)) {
        return false;
      }
    }
    return true;
  }

  Widget _buildBulkActionCard() {
    final requiredAllGranted = _allRequiredGranted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Setup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Enable only the essential permissions to get started quickly. Other permissions will be requested when you use specific features.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: (_isLoading ||
                            _bulkRequestInFlight ||
                            requiredAllGranted)
                        ? null
                        : _handleEnableRequiredPermissions,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_bulkRequestInFlight)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        else
                          Icon(
                            requiredAllGranted ? Icons.check : Icons.bolt,
                            size: 18,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _bulkRequestInFlight
                              ? 'Requesting…'
                              : requiredAllGranted
                                  ? 'Done'
                                  : 'Required',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: (_isLoading || _bulkRequestInFlight)
                        ? null
                        : _handleEnableAllPermissions,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.done_all, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'All',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (!requiredAllGranted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Required: Bluetooth, Notifications, Microphone',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
