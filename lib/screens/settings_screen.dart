import 'package:agixt/widgets/glass_status.dart';
import 'package:agixt/screens/settings/dashboard_screen.dart';
import 'package:agixt/screens/settings/location_screen.dart';
import 'package:agixt/screens/settings/notifications_screen.dart';
import 'package:agixt/widgets/gravatar_image.dart';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/screens/auth/profile_screen.dart';
import 'package:agixt/screens/calendars_screen.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _userEmail;
  String? _userName;
  bool _isGlassesDisplayEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _loadGlassesDisplayPreference();
  }

  Future<void> _loadUserDetails() async {
    final email = await AuthService.getEmail();
    final userInfo = await AuthService.getUserInfo();

    setState(() {
      _userEmail = email;
      if (userInfo != null) {
        _userName = '${userInfo.firstName} ${userInfo.lastName}'.trim();
      }
    });
  }

  Future<void> _loadGlassesDisplayPreference() async {
    final preference = await AuthService.getGlassesDisplayPreference();
    setState(() {
      _isGlassesDisplayEnabled = preference;
    });
  }

  Future<void> _saveGlassesDisplayPreference(bool value) async {
    // Save the preference
    await AuthService.setGlassesDisplayPreference(value);

    // Update glasses state if connected
    final bluetoothManager = BluetoothManager();

    if (bluetoothManager.isConnected) {
      // Set silent mode (inverse of display enabled)
      await bluetoothManager.setSilentMode(!value);

      // Clear the display when silent mode is enabled
      if (!value) {
        await bluetoothManager.clearGlassesDisplay();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          GlassStatus(),

          // Profile Section
          if (_userEmail != null)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen()),
                ).then((_) => _loadUserDetails()); // Refresh on return
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    GravatarImage(
                      email: _userEmail!,
                      size: 50,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_userName != null && _userName!.isNotEmpty)
                            Text(
                              _userName!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(
                            _userEmail!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),

          const Divider(),

          ListTile(
            title: Row(
              children: [
                Icon(Icons.notifications),
                SizedBox(width: 10),
                Text('App Notifications'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => NotificationSettingsPage()),
              );
            },
          ),
          ListTile(
            title: Row(
              children: [
                Icon(Icons.dashboard),
                SizedBox(width: 10),
                Text('Dashboard Settings'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => DashboardSettingsPage()),
              );
            },
          ),
          ListTile(
            title: Row(
              children: [
                Icon(Icons.calendar_today),
                SizedBox(width: 10),
                Text('Calendar Integration'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CalendarsPage()),
              );
            },
          ),
          ListTile(
            title: Row(
              children: [
                Icon(Icons.location_on),
                SizedBox(width: 10),
                Text('Location Settings'),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => LocationSettingsScreen()),
              );
            },
          ),

          const Divider(),

          // Toggle for Even Realities Glasses
          ListTile(
            title: Row(
              children: [
                Icon(Icons.visibility_off),
                SizedBox(width: 10),
                Text('Glasses Silent Mode'),
              ],
            ),
            subtitle: Text('No content will be shown on glasses when enabled'),
            trailing: Switch(
              value: !_isGlassesDisplayEnabled,
              onChanged: (bool value) {
                setState(() {
                  _isGlassesDisplayEnabled = !value;
                });
                _saveGlassesDisplayPreference(!value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
