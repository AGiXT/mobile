import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:agixt/services/websocket_service.dart';
import 'package:agixt/services/contacts_service.dart';
import 'package:agixt/services/sms_service.dart';
import 'package:agixt/services/location_service.dart';
import 'package:agixt/services/permission_manager.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service that handles client-side commands from the AGiXT agent
/// Similar to the CLI's execute_remote_command functionality but for mobile
/// Enhanced with ESP32-style tools like capture_image
class ClientCommandsService {
  static final ClientCommandsService _instance =
      ClientCommandsService._internal();
  factory ClientCommandsService() => _instance;
  ClientCommandsService._internal();

  final AGiXTWebSocketService _webSocketService = AGiXTWebSocketService();
  final ContactsService _contactsService = ContactsService();
  final SmsService _smsService = SmsService();
  final LocationService _locationService = LocationService();
  final BluetoothManager _bluetoothManager = BluetoothManager.singleton;

  // Method channel for glasses camera access
  static const MethodChannel _cameraChannel = MethodChannel(
    'dev.agixt.agixt/glasses_camera',
  );

  StreamSubscription<RemoteCommandRequest>? _commandSubscription;
  bool _isListening = false;

  /// Start listening for remote commands from the AGiXT agent
  void startListening() {
    if (_isListening) return;

    _commandSubscription = _webSocketService.commandStream.listen(
      _handleCommand,
      onError: (error) {
        debugPrint('ClientCommands: Error in command stream: $error');
      },
    );

    _isListening = true;
    debugPrint('ClientCommands: Started listening for commands');
  }

  /// Stop listening for remote commands
  void stopListening() {
    _commandSubscription?.cancel();
    _commandSubscription = null;
    _isListening = false;
    debugPrint('ClientCommands: Stopped listening for commands');
  }

  /// Handle a remote command request
  Future<void> _handleCommand(RemoteCommandRequest command) async {
    debugPrint('ClientCommands: Received command: ${command.toolName}');
    debugPrint('ClientCommands: Args: ${command.toolArgs}');

    String output;
    int exitCode;

    try {
      final result = await _executeCommand(command.toolName, command.toolArgs);
      output = result['output'] as String;
      exitCode = result['exit_code'] as int;
    } catch (e) {
      output = 'Error executing command: $e';
      exitCode = 1;
      debugPrint('ClientCommands: Error: $e');
    }

    // Submit result back to server
    await _webSocketService.submitCommandResult(
      requestId: command.requestId,
      toolName: command.toolName,
      output: output,
      exitCode: exitCode,
    );
  }

  /// Execute a command and return the result
  Future<Map<String, dynamic>> _executeCommand(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    switch (toolName) {
      // ESP32-style tools
      case 'capture_image':
        return await _captureImage(args);
      case 'get_device_capabilities':
        return await _getDeviceCapabilities(args);

      // Contact tools
      case 'get_contacts':
        return await _getContacts(args);
      case 'search_contacts':
        return await _searchContacts(args);

      // Communication tools
      case 'send_sms':
        return await _sendSms(args);
      case 'make_phone_call':
        return await _makePhoneCall(args);
      case 'mobile_send_email':
        return await _sendEmail(args);

      // Calendar tools
      case 'get_calendar_events':
        return await _getCalendarEvents(args);
      case 'create_calendar_event':
        return await _createCalendarEvent(args);
      case 'get_calendars':
        return await _getCalendars(args);

      // Location/navigation tools
      case 'get_location':
        return await _getLocation(args);
      case 'open_maps':
      case 'navigate_to':
        return await _openMaps(args);

      // File operations (prefixed with mobile_ to avoid server-side conflicts)
      case 'mobile_read_file':
        return await _readFile(args);
      case 'mobile_write_file':
        return await _writeFile(args);
      case 'mobile_list_files':
        return await _listFiles(args);
      case 'mobile_delete_file':
        return await _deleteFile(args);
      case 'mobile_get_storage_info':
        return await _getStorageInfo(args);

      // Clipboard tools (prefixed with mobile_ for device-specific operations)
      case 'mobile_get_clipboard':
        return await _getClipboard(args);
      case 'mobile_set_clipboard':
        return await _setClipboard(args);

      // App control tools
      case 'open_app':
        return await _openApp(args);
      case 'open_settings':
        return await _openSettings(args);

      // Device control tools
      case 'set_flashlight':
        return await _setFlashlight(args);
      case 'get_battery_status':
        return await _getBatteryStatus(args);
      case 'set_alarm':
        return await _setAlarm(args);
      case 'set_timer':
        return await _setTimer(args);

      // Media control tools (digital assistant capabilities)
      case 'media_control':
        return await _mediaControl(args);
      case 'get_media_info':
        return await _getMediaInfo(args);

      // Volume control tools
      case 'set_volume':
        return await _setVolume(args);
      case 'get_volume':
        return await _getVolume(args);
      case 'adjust_volume':
        return await _adjustVolume(args);

      // Ringer mode tools
      case 'set_ringer_mode':
        return await _setRingerMode(args);
      case 'get_ringer_mode':
        return await _getRingerMode(args);

      // Brightness tools
      case 'set_brightness':
        return await _setBrightness(args);
      case 'get_brightness':
        return await _getBrightness(args);

      // Connectivity tools
      case 'toggle_wifi':
        return await _toggleWifi(args);
      case 'get_wifi_status':
        return await _getWifiStatus(args);
      case 'toggle_bluetooth':
        return await _toggleBluetooth(args);
      case 'get_bluetooth_status':
        return await _getBluetoothStatus(args);

      // Do Not Disturb tools
      case 'set_do_not_disturb':
        return await _setDoNotDisturb(args);
      case 'get_do_not_disturb_status':
        return await _getDoNotDisturbStatus(args);

      // Screen control tools
      case 'wake_screen':
        return await _wakeScreen(args);
      case 'get_screen_status':
        return await _getScreenStatus(args);

      // System info tools
      case 'get_system_info':
        return await _getSystemInfo(args);

      // Utility tools
      case 'open_url':
        return await _openUrl(args);
      case 'get_device_info':
        return await _getDeviceInfo(args);
      case 'mobile_search_web':
        return await _searchWeb(args);

      // Glasses display tools
      case 'display_on_glasses':
        return await _displayOnGlasses(args);

      // Notes/reminders (prefixed with mobile_ for device-local storage)
      case 'mobile_save_note':
        return await _saveNote(args);
      case 'mobile_get_notes':
        return await _getNotes(args);

      default:
        return {
          'output':
              'Unknown command: $toolName. Use get_device_capabilities to see available commands.',
          'exit_code': 1,
        };
    }
  }

  /// Capture an image using the smart glasses camera (ESP32-style tool)
  /// This is the primary visual capture tool for the mobile app
  Future<Map<String, dynamic>> _captureImage(Map<String, dynamic> args) async {
    try {
      final prompt = args['prompt'] as String? ?? 'Analyze this image';

      // Check if glasses are connected
      if (!_bluetoothManager.isConnected) {
        return {
          'output': jsonEncode({
            'error': 'Glasses not connected',
            'message':
                'Cannot capture image - Even Realities glasses are not connected',
          }),
          'exit_code': 1,
        };
      }

      debugPrint('ClientCommands: Capturing image with prompt: $prompt');

      // Request image capture from glasses via native channel
      try {
        final result = await _cameraChannel.invokeMethod('captureImage', {
          'prompt': prompt,
        });

        if (result is Map) {
          final imageData = result['imageData'] as Uint8List?;
          final width = result['width'] as int? ?? 0;
          final height = result['height'] as int? ?? 0;

          if (imageData != null && imageData.isNotEmpty) {
            // Convert to base64 for the response
            final base64Image = base64Encode(imageData);

            return {
              'output': jsonEncode({
                'success': true,
                'prompt': prompt,
                'image_data': base64Image,
                'image_size': imageData.length,
                'width': width,
                'height': height,
                'format': 'jpeg',
                'source': 'glasses_camera',
              }),
              'exit_code': 0,
            };
          }
        }

        return {
          'output': jsonEncode({
            'error': 'Capture failed',
            'message': 'Failed to capture image from glasses camera',
          }),
          'exit_code': 1,
        };
      } on PlatformException catch (e) {
        return {
          'output': jsonEncode({
            'error': 'Platform error',
            'message': 'Camera not available: ${e.message}',
          }),
          'exit_code': 1,
        };
      } on MissingPluginException {
        return {
          'output': jsonEncode({
            'error': 'Not implemented',
            'message':
                'Glasses camera capture not yet implemented on this platform',
          }),
          'exit_code': 1,
        };
      }
    } catch (e) {
      return {
        'output': jsonEncode({
          'error': 'Exception',
          'message': 'Error capturing image: $e',
        }),
        'exit_code': 1,
      };
    }
  }

  /// Get device capabilities (ESP32-style tool)
  /// Returns what features are available on this mobile device
  Future<Map<String, dynamic>> _getDeviceCapabilities(
    Map<String, dynamic> args,
  ) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      Map<String, dynamic> capabilities = {
        'device_type': 'mobile',
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
      };

      // Get platform-specific info
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        capabilities['manufacturer'] = androidInfo.manufacturer;
        capabilities['model'] = androidInfo.model;
        capabilities['android_version'] = androidInfo.version.release;
        capabilities['sdk_version'] = androidInfo.version.sdkInt;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        capabilities['model'] = iosInfo.model;
        capabilities['system_version'] = iosInfo.systemVersion;
      }

      // Check connected devices
      capabilities['glasses_connected'] = _bluetoothManager.isConnected;
      capabilities['glasses_type'] = 'Even Realities G1';

      // Get available tools based on permissions
      final contactsGranted = await PermissionManager.isGroupGranted(
        AppPermission.contacts,
      );
      final smsGranted = await PermissionManager.isGroupGranted(
        AppPermission.sms,
      );
      final locationGranted = await PermissionManager.isGroupGranted(
        AppPermission.location,
      );
      final phoneGranted = await PermissionManager.isGroupGranted(
        AppPermission.phone,
      );

      capabilities['available_tools'] = {
        // Visual/Glasses tools
        'capture_image': _bluetoothManager.isConnected,
        'display_on_glasses': _bluetoothManager.isConnected,

        // Contact tools
        'get_contacts': contactsGranted,
        'search_contacts': contactsGranted,

        // Communication tools
        'send_sms': smsGranted,
        'make_phone_call': phoneGranted,
        'mobile_send_email': true,

        // Calendar tools
        'get_calendar_events': true,
        'create_calendar_event': true,
        'get_calendars': true,

        // Location tools
        'get_location': locationGranted,
        'open_maps': locationGranted,
        'navigate_to': locationGranted,

        // File tools
        'mobile_read_file': true,
        'mobile_write_file': true,
        'mobile_list_files': true,
        'mobile_delete_file': true,
        'mobile_get_storage_info': true,

        // Clipboard tools
        'mobile_get_clipboard': true,
        'mobile_set_clipboard': true,

        // App control
        'open_app': true,
        'open_settings': true,
        'open_url': true,

        // Device control
        'set_flashlight': true,
        'get_battery_status': true,
        'set_alarm': true,
        'set_timer': true,

        // Media control (digital assistant)
        'media_control': true, // play, pause, next, previous, stop
        'get_media_info': true,

        // Volume control (digital assistant)
        'set_volume': true,
        'get_volume': true,
        'adjust_volume': true, // up, down, mute, unmute

        // Ringer mode
        'set_ringer_mode': true, // normal, vibrate, silent
        'get_ringer_mode': true,

        // Brightness control
        'set_brightness': true,
        'get_brightness': true,

        // Connectivity
        'toggle_wifi': true, // Opens settings panel on Android 10+
        'get_wifi_status': true,
        'toggle_bluetooth': true, // Opens settings on Android 12+
        'get_bluetooth_status': true,

        // Do Not Disturb
        'set_do_not_disturb': true,
        'get_do_not_disturb_status': true,

        // Screen control
        'wake_screen': true,
        'get_screen_status': true,

        // System info
        'get_system_info': true, // Comprehensive device status
        'get_device_info': true,

        // Notes
        'mobile_save_note': true,
        'mobile_get_notes': true,

        // Search
        'mobile_search_web': true,
      };

      return {'output': jsonEncode(capabilities), 'exit_code': 0};
    } catch (e) {
      return {
        'output': 'Error getting device capabilities: $e',
        'exit_code': 1,
      };
    }
  }

  /// Display text on the connected glasses
  Future<Map<String, dynamic>> _displayOnGlasses(
    Map<String, dynamic> args,
  ) async {
    try {
      final message = args['message'] as String? ?? args['text'] as String?;
      final durationMs = args['duration'] as int? ?? 5000;

      if (message == null || message.isEmpty) {
        return {
          'output': 'Missing required parameter: message',
          'exit_code': 1,
        };
      }

      if (!_bluetoothManager.isConnected) {
        return {'output': 'Glasses not connected', 'exit_code': 1};
      }

      await _bluetoothManager.sendAIResponse(
        message,
        delay: Duration(milliseconds: durationMs),
      );

      return {
        'output': 'Message displayed on glasses: "$message"',
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error displaying on glasses: $e', 'exit_code': 1};
    }
  }

  /// Get contacts from the device
  Future<Map<String, dynamic>> _getContacts(Map<String, dynamic> args) async {
    try {
      final limit = args['limit'] as int? ?? 50;
      final contacts = await _contactsService.getContacts(limit: limit);

      if (contacts.isEmpty) {
        return {
          'output': 'No contacts found or permission not granted.',
          'exit_code': 1,
        };
      }

      final contactList = contacts.map((c) {
        return {
          'name': c.displayName,
          'phones': c.phones,
          'emails': c.emails,
        };
      }).toList();

      return {
        'output': jsonEncode({
          'count': contactList.length,
          'contacts': contactList,
        }),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error getting contacts: $e', 'exit_code': 1};
    }
  }

  /// Search contacts by name
  Future<Map<String, dynamic>> _searchContacts(
    Map<String, dynamic> args,
  ) async {
    try {
      final query = args['query'] as String?;
      if (query == null || query.isEmpty) {
        return {'output': 'Missing required parameter: query', 'exit_code': 1};
      }

      final contacts = await _contactsService.searchContacts(query);

      if (contacts.isEmpty) {
        return {
          'output': 'No contacts found matching "$query"',
          'exit_code': 0,
        };
      }

      final contactList = contacts.map((c) {
        return {
          'name': c.displayName,
          'phones': c.phones,
          'emails': c.emails,
        };
      }).toList();

      return {
        'output': jsonEncode({
          'query': query,
          'count': contactList.length,
          'contacts': contactList,
        }),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error searching contacts: $e', 'exit_code': 1};
    }
  }

  /// Send an SMS message
  Future<Map<String, dynamic>> _sendSms(Map<String, dynamic> args) async {
    try {
      final phoneNumber = args['phone_number'] as String? ??
          args['to'] as String? ??
          args['recipient'] as String?;
      final message = args['message'] as String? ??
          args['body'] as String? ??
          args['text'] as String?;

      if (phoneNumber == null || phoneNumber.isEmpty) {
        return {
          'output': 'Missing required parameter: phone_number',
          'exit_code': 1,
        };
      }

      if (message == null || message.isEmpty) {
        return {
          'output': 'Missing required parameter: message',
          'exit_code': 1,
        };
      }

      // Check if it's a contact name instead of phone number
      String resolvedNumber = phoneNumber;
      if (!_isPhoneNumber(phoneNumber)) {
        // Try to find contact by name
        final contacts = await _contactsService.searchContacts(phoneNumber);
        if (contacts.isNotEmpty && contacts.first.phones.isNotEmpty) {
          resolvedNumber = contacts.first.phones.first;
          debugPrint(
            'ClientCommands: Resolved "$phoneNumber" to "$resolvedNumber"',
          );
        } else {
          return {
            'output':
                'Could not find phone number for contact "$phoneNumber". Please provide a valid phone number.',
            'exit_code': 1,
          };
        }
      }

      final success = await _smsService.sendSms(
        phoneNumber: resolvedNumber,
        message: message,
      );

      if (success) {
        return {
          'output': 'SMS sent successfully to $resolvedNumber',
          'exit_code': 0,
        };
      } else {
        return {
          'output': 'Failed to send SMS. Check permissions or try again.',
          'exit_code': 1,
        };
      }
    } catch (e) {
      return {'output': 'Error sending SMS: $e', 'exit_code': 1};
    }
  }

  /// Get the user's current GPS location
  Future<Map<String, dynamic>> _getLocation(Map<String, dynamic> args) async {
    try {
      final position = await _locationService.getCurrentPosition(
        timeout: const Duration(seconds: 10),
      );

      if (position == null) {
        // Try to get last known location
        final lastPosition = await _locationService.getLastPosition();
        if (lastPosition.isNotEmpty) {
          return {
            'output': jsonEncode({
              'latitude': lastPosition['latitude'],
              'longitude': lastPosition['longitude'],
              'altitude': lastPosition['altitude'],
              'accuracy': lastPosition['accuracy'],
              'timestamp': lastPosition['timestamp']?.toIso8601String(),
              'note': 'Last known location (current position unavailable)',
            }),
            'exit_code': 0,
          };
        }
        return {
          'output': 'Location not available. Please enable location services.',
          'exit_code': 1,
        };
      }

      return {
        'output': jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'altitude': position.altitude,
          'accuracy': position.accuracy,
          'speed': position.speed,
          'heading': position.heading,
          'timestamp': position.timestamp.toIso8601String(),
        }),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error getting location: $e', 'exit_code': 1};
    }
  }

  /// Open Google Maps and optionally navigate to a destination
  Future<Map<String, dynamic>> _openMaps(Map<String, dynamic> args) async {
    try {
      final destination = args['destination'] as String? ??
          args['address'] as String? ??
          args['location'] as String?;
      final lat = args['latitude'] as double?;
      final lng = args['longitude'] as double?;
      final mode =
          args['mode'] as String? ?? 'd'; // d=driving, w=walking, b=bicycling

      Uri uri;

      if (destination != null && destination.isNotEmpty) {
        // Navigate to address/place name
        final encodedDest = Uri.encodeComponent(destination);
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$encodedDest&travelmode=$mode',
        );
      } else if (lat != null && lng != null) {
        // Navigate to coordinates
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=$mode',
        );
      } else {
        return {
          'output':
              'Missing required parameter: destination (address) or latitude/longitude',
          'exit_code': 1,
        };
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return {
          'output':
              'Opening Google Maps${destination != null ? " with destination: $destination" : ""}',
          'exit_code': 0,
        };
      } else {
        return {
          'output': 'Could not open Google Maps. Is it installed?',
          'exit_code': 1,
        };
      }
    } catch (e) {
      return {'output': 'Error opening maps: $e', 'exit_code': 1};
    }
  }

  /// Make a phone call
  Future<Map<String, dynamic>> _makePhoneCall(Map<String, dynamic> args) async {
    try {
      final phoneNumber = args['phone_number'] as String? ??
          args['number'] as String? ??
          args['to'] as String?;

      if (phoneNumber == null || phoneNumber.isEmpty) {
        return {
          'output': 'Missing required parameter: phone_number',
          'exit_code': 1,
        };
      }

      // Check if it's a contact name instead of phone number
      String resolvedNumber = phoneNumber;
      if (!_isPhoneNumber(phoneNumber)) {
        final contacts = await _contactsService.searchContacts(phoneNumber);
        if (contacts.isNotEmpty && contacts.first.phones.isNotEmpty) {
          resolvedNumber = contacts.first.phones.first;
        } else {
          return {
            'output':
                'Could not find phone number for contact "$phoneNumber". Please provide a valid phone number.',
            'exit_code': 1,
          };
        }
      }

      final uri = Uri.parse('tel:$resolvedNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return {'output': 'Initiating call to $resolvedNumber', 'exit_code': 0};
      } else {
        return {'output': 'Could not initiate phone call', 'exit_code': 1};
      }
    } catch (e) {
      return {'output': 'Error making phone call: $e', 'exit_code': 1};
    }
  }

  /// Open a URL in the default browser
  Future<Map<String, dynamic>> _openUrl(Map<String, dynamic> args) async {
    try {
      final urlStr = args['url'] as String?;
      if (urlStr == null || urlStr.isEmpty) {
        return {'output': 'Missing required parameter: url', 'exit_code': 1};
      }

      Uri uri;
      try {
        uri = Uri.parse(urlStr);
        if (!uri.hasScheme) {
          uri = Uri.parse('https://$urlStr');
        }
      } catch (e) {
        return {'output': 'Invalid URL: $urlStr', 'exit_code': 1};
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return {'output': 'Opening URL: $uri', 'exit_code': 0};
      } else {
        return {'output': 'Could not open URL: $uri', 'exit_code': 1};
      }
    } catch (e) {
      return {'output': 'Error opening URL: $e', 'exit_code': 1};
    }
  }

  /// Get basic device information
  Future<Map<String, dynamic>> _getDeviceInfo(Map<String, dynamic> args) async {
    try {
      // This is a simplified version - you could expand with device_info_plus
      final info = {
        'platform': 'Android', // Could use Platform.isAndroid/isIOS
        'capabilities': [
          'get_contacts',
          'search_contacts',
          'send_sms',
          'get_location',
          'open_maps',
          'navigate_to',
          'make_phone_call',
          'open_url',
        ],
        'permissions': {
          'contacts': await _contactsService.hasPermission(),
          'sms': await _smsService.hasPermission(),
          'location': await _locationService.isLocationEnabled(),
        },
      };

      return {'output': jsonEncode(info), 'exit_code': 0};
    } catch (e) {
      return {'output': 'Error getting device info: $e', 'exit_code': 1};
    }
  }

  /// Send an email using the default email app
  Future<Map<String, dynamic>> _sendEmail(Map<String, dynamic> args) async {
    try {
      final to = args['to'] as String? ?? args['recipient'] as String?;
      final subject = args['subject'] as String? ?? '';
      final body = args['body'] as String? ?? args['message'] as String? ?? '';
      final cc = args['cc'] as String?;
      final bcc = args['bcc'] as String?;

      if (to == null || to.isEmpty) {
        return {
          'output': 'Missing required parameter: to (email address)',
          'exit_code': 1,
        };
      }

      // If 'to' looks like a contact name, try to resolve email
      String resolvedEmail = to;
      if (!to.contains('@')) {
        final contacts = await _contactsService.searchContacts(to);
        if (contacts.isNotEmpty && contacts.first.emails.isNotEmpty) {
          resolvedEmail = contacts.first.emails.first;
        } else {
          return {
            'output':
                'Could not find email for "$to". Please provide a valid email address.',
            'exit_code': 1,
          };
        }
      }

      final uri = Uri(
        scheme: 'mailto',
        path: resolvedEmail,
        queryParameters: {
          if (subject.isNotEmpty) 'subject': subject,
          if (body.isNotEmpty) 'body': body,
          if (cc != null && cc.isNotEmpty) 'cc': cc,
          if (bcc != null && bcc.isNotEmpty) 'bcc': bcc,
        },
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return {
          'output': 'Email composer opened for $resolvedEmail',
          'exit_code': 0,
        };
      }

      return {'output': 'Could not open email app', 'exit_code': 1};
    } catch (e) {
      return {'output': 'Error sending email: $e', 'exit_code': 1};
    }
  }

  /// Get calendar events
  Future<Map<String, dynamic>> _getCalendarEvents(
    Map<String, dynamic> args,
  ) async {
    try {
      final daysAhead = args['days_ahead'] as int? ?? 7;
      final daysBefore = args['days_before'] as int? ?? 0;
      final calendarId = args['calendar_id'] as String?;

      final plugin = DeviceCalendarPlugin();

      // Get permission
      var permissionsGranted = await plugin.hasPermissions();
      if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
        permissionsGranted = await plugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
          return {'output': 'Calendar permission not granted', 'exit_code': 1};
        }
      }

      // Get calendars
      final calendarsResult = await plugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null) {
        return {'output': 'Could not retrieve calendars', 'exit_code': 1};
      }

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: daysBefore));
      final endDate = now.add(Duration(days: daysAhead));

      List<Map<String, dynamic>> allEvents = [];

      for (final calendar in calendarsResult.data!) {
        if (calendarId != null && calendar.id != calendarId) continue;

        final eventsResult = await plugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(startDate: startDate, endDate: endDate),
        );

        if (eventsResult.isSuccess && eventsResult.data != null) {
          for (final event in eventsResult.data!) {
            allEvents.add({
              'id': event.eventId,
              'title': event.title,
              'description': event.description,
              'start': event.start?.toIso8601String(),
              'end': event.end?.toIso8601String(),
              'location': event.location,
              'all_day': event.allDay,
              'calendar': calendar.name,
            });
          }
        }
      }

      // Sort by start time
      allEvents.sort((a, b) {
        final aStart = a['start'] as String?;
        final bStart = b['start'] as String?;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        return aStart.compareTo(bStart);
      });

      return {
        'output': jsonEncode({
          'events': allEvents,
          'count': allEvents.length,
          'date_range': {
            'start': startDate.toIso8601String(),
            'end': endDate.toIso8601String(),
          },
        }),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error getting calendar events: $e', 'exit_code': 1};
    }
  }

  /// Create a calendar event
  Future<Map<String, dynamic>> _createCalendarEvent(
    Map<String, dynamic> args,
  ) async {
    try {
      final title = args['title'] as String?;
      final description = args['description'] as String? ?? '';
      final location = args['location'] as String?;
      final startStr = args['start'] as String?;
      final endStr = args['end'] as String?;
      final allDay = args['all_day'] as bool? ?? false;
      final calendarId = args['calendar_id'] as String?;

      if (title == null || title.isEmpty) {
        return {'output': 'Missing required parameter: title', 'exit_code': 1};
      }

      if (startStr == null) {
        return {
          'output': 'Missing required parameter: start (ISO 8601 datetime)',
          'exit_code': 1,
        };
      }

      final plugin = DeviceCalendarPlugin();

      // Get permission
      var permissionsGranted = await plugin.hasPermissions();
      if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
        permissionsGranted = await plugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
          return {'output': 'Calendar permission not granted', 'exit_code': 1};
        }
      }

      // Get calendars
      final calendarsResult = await plugin.retrieveCalendars();
      if (!calendarsResult.isSuccess ||
          calendarsResult.data == null ||
          calendarsResult.data!.isEmpty) {
        return {'output': 'No calendars available', 'exit_code': 1};
      }

      // Select calendar
      String targetCalendarId;
      if (calendarId != null) {
        targetCalendarId = calendarId;
      } else {
        // Use the first writable calendar
        final writableCalendar = calendarsResult.data!.firstWhere(
          (c) => !c.isReadOnly!,
          orElse: () => calendarsResult.data!.first,
        );
        targetCalendarId = writableCalendar.id!;
      }

      final start = DateTime.parse(startStr);
      final end = endStr != null
          ? DateTime.parse(endStr)
          : start.add(const Duration(hours: 1));

      final event = Event(
        targetCalendarId,
        title: title,
        description: description,
        start: TZDateTime.from(start, local),
        end: TZDateTime.from(end, local),
        location: location,
        allDay: allDay,
      );

      final result = await plugin.createOrUpdateEvent(event);

      if (result?.isSuccess == true && result?.data != null) {
        return {
          'output': jsonEncode({
            'success': true,
            'event_id': result!.data,
            'title': title,
            'start': start.toIso8601String(),
            'end': end.toIso8601String(),
          }),
          'exit_code': 0,
        };
      }

      return {'output': 'Failed to create calendar event', 'exit_code': 1};
    } catch (e) {
      return {'output': 'Error creating calendar event: $e', 'exit_code': 1};
    }
  }

  /// Get list of available calendars
  Future<Map<String, dynamic>> _getCalendars(Map<String, dynamic> args) async {
    try {
      final plugin = DeviceCalendarPlugin();

      var permissionsGranted = await plugin.hasPermissions();
      if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
        permissionsGranted = await plugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
          return {'output': 'Calendar permission not granted', 'exit_code': 1};
        }
      }

      final calendarsResult = await plugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null) {
        return {'output': 'Could not retrieve calendars', 'exit_code': 1};
      }

      final calendars = calendarsResult.data!
          .map(
            (c) => {
              'id': c.id,
              'name': c.name,
              'account_name': c.accountName,
              'account_type': c.accountType,
              'is_read_only': c.isReadOnly,
            },
          )
          .toList();

      return {
        'output': jsonEncode({
          'calendars': calendars,
          'count': calendars.length,
        }),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error getting calendars: $e', 'exit_code': 1};
    }
  }

  /// Read a file from device storage
  Future<Map<String, dynamic>> _readFile(Map<String, dynamic> args) async {
    try {
      final filePath = args['path'] as String?;
      final maxBytes = args['max_bytes'] as int? ?? 1024 * 100; // 100KB default

      if (filePath == null || filePath.isEmpty) {
        return {'output': 'Missing required parameter: path', 'exit_code': 1};
      }

      // Resolve path within app's allowed directories
      String resolvedPath;
      if (filePath.startsWith('/')) {
        // Absolute path - check if within allowed directories
        final appDir = await getApplicationDocumentsDirectory();
        final externalDir = await getExternalStorageDirectory();

        if (!filePath.startsWith(appDir.path) &&
            (externalDir == null || !filePath.startsWith(externalDir.path))) {
          return {
            'output': 'Access denied: Path outside allowed directories',
            'exit_code': 1,
          };
        }
        resolvedPath = filePath;
      } else {
        // Relative path - resolve to app documents
        final appDir = await getApplicationDocumentsDirectory();
        resolvedPath = '${appDir.path}/$filePath';
      }

      final file = File(resolvedPath);
      if (!await file.exists()) {
        return {'output': 'File not found: $filePath', 'exit_code': 1};
      }

      final stat = await file.stat();
      if (stat.size > maxBytes) {
        return {
          'output': jsonEncode({
            'error': 'File too large',
            'size': stat.size,
            'max_bytes': maxBytes,
            'path': filePath,
          }),
          'exit_code': 1,
        };
      }

      final content = await file.readAsString();
      return {
        'output': jsonEncode({
          'path': filePath,
          'content': content,
          'size': stat.size,
          'modified': stat.modified.toIso8601String(),
        }),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error reading file: $e', 'exit_code': 1};
    }
  }

  /// Write content to a file
  Future<Map<String, dynamic>> _writeFile(Map<String, dynamic> args) async {
    try {
      final filePath = args['path'] as String?;
      final content = args['content'] as String?;
      final append = args['append'] as bool? ?? false;

      if (filePath == null || filePath.isEmpty) {
        return {'output': 'Missing required parameter: path', 'exit_code': 1};
      }

      if (content == null) {
        return {
          'output': 'Missing required parameter: content',
          'exit_code': 1,
        };
      }

      // Resolve to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final resolvedPath =
          filePath.startsWith('/') ? filePath : '${appDir.path}/$filePath';

      // Ensure within allowed directories
      if (!resolvedPath.startsWith(appDir.path)) {
        return {
          'output': 'Access denied: Can only write to app documents directory',
          'exit_code': 1,
        };
      }

      final file = File(resolvedPath);
      await file.parent.create(recursive: true);

      if (append) {
        await file.writeAsString(content, mode: FileMode.append);
      } else {
        await file.writeAsString(content);
      }

      final stat = await file.stat();
      return {
        'output': jsonEncode({
          'success': true,
          'path': filePath,
          'size': stat.size,
          'action': append ? 'appended' : 'written',
        }),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error writing file: $e', 'exit_code': 1};
    }
  }

  /// List files in a directory
  Future<Map<String, dynamic>> _listFiles(Map<String, dynamic> args) async {
    try {
      final dirPath = args['path'] as String? ?? '';
      final recursive = args['recursive'] as bool? ?? false;

      final appDir = await getApplicationDocumentsDirectory();
      final resolvedPath = dirPath.isEmpty
          ? appDir.path
          : (dirPath.startsWith('/') ? dirPath : '${appDir.path}/$dirPath');

      final dir = Directory(resolvedPath);
      if (!await dir.exists()) {
        return {'output': 'Directory not found: $dirPath', 'exit_code': 1};
      }

      final List<Map<String, dynamic>> files = [];
      await for (final entity in dir.list(recursive: recursive)) {
        final stat = await entity.stat();
        final relativePath = entity.path.replaceFirst('${appDir.path}/', '');
        files.add({
          'path': relativePath,
          'type': entity is File ? 'file' : 'directory',
          'size': stat.size,
          'modified': stat.modified.toIso8601String(),
        });
      }

      return {
        'output': jsonEncode({
          'directory': dirPath.isEmpty ? '/' : dirPath,
          'files': files,
          'count': files.length,
        }),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error listing files: $e', 'exit_code': 1};
    }
  }

  /// Delete a file
  Future<Map<String, dynamic>> _deleteFile(Map<String, dynamic> args) async {
    try {
      final filePath = args['path'] as String?;

      if (filePath == null || filePath.isEmpty) {
        return {'output': 'Missing required parameter: path', 'exit_code': 1};
      }

      final appDir = await getApplicationDocumentsDirectory();
      final resolvedPath =
          filePath.startsWith('/') ? filePath : '${appDir.path}/$filePath';

      // Ensure within allowed directories
      if (!resolvedPath.startsWith(appDir.path)) {
        return {
          'output':
              'Access denied: Can only delete files in app documents directory',
          'exit_code': 1,
        };
      }

      final file = File(resolvedPath);
      if (!await file.exists()) {
        return {'output': 'File not found: $filePath', 'exit_code': 1};
      }

      await file.delete();
      return {
        'output': jsonEncode({'success': true, 'deleted': filePath}),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error deleting file: $e', 'exit_code': 1};
    }
  }

  /// Get storage information
  Future<Map<String, dynamic>> _getStorageInfo(
    Map<String, dynamic> args,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = await getTemporaryDirectory();
      final externalDir = await getExternalStorageDirectory();

      return {
        'output': jsonEncode({
          'app_documents': appDir.path,
          'cache': cacheDir.path,
          'external': externalDir?.path,
        }),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error getting storage info: $e', 'exit_code': 1};
    }
  }

  /// Get clipboard contents
  Future<Map<String, dynamic>> _getClipboard(Map<String, dynamic> args) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return {
        'output': jsonEncode({
          'text': data?.text ?? '',
          'has_content': data?.text != null && data!.text!.isNotEmpty,
        }),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error getting clipboard: $e', 'exit_code': 1};
    }
  }

  /// Set clipboard contents
  Future<Map<String, dynamic>> _setClipboard(Map<String, dynamic> args) async {
    try {
      final text = args['text'] as String?;

      if (text == null) {
        return {'output': 'Missing required parameter: text', 'exit_code': 1};
      }

      await Clipboard.setData(ClipboardData(text: text));
      return {
        'output': jsonEncode({'success': true, 'copied_length': text.length}),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error setting clipboard: $e', 'exit_code': 1};
    }
  }

  /// Open a specific app
  Future<Map<String, dynamic>> _openApp(Map<String, dynamic> args) async {
    try {
      final appName = args['app'] as String? ?? args['name'] as String?;
      final packageName = args['package'] as String?;

      if (appName == null && packageName == null) {
        return {
          'output': 'Missing required parameter: app or package',
          'exit_code': 1,
        };
      }

      // Common app URL schemes
      final Map<String, String> appSchemes = {
        'camera': 'intent://camera#Intent;end',
        'calculator': 'intent://calculator#Intent;end',
        'clock': 'intent://clock#Intent;end',
        'calendar': 'content://com.android.calendar/time/',
        'spotify': 'spotify:',
        'youtube': 'vnd.youtube:',
        'whatsapp': 'whatsapp://',
        'instagram': 'instagram://',
        'twitter': 'twitter://',
        'facebook': 'fb://',
        'maps': 'geo:',
        'phone': 'tel:',
        'sms': 'sms:',
        'email': 'mailto:',
        'settings': 'android.settings.SETTINGS',
      };

      String? scheme;
      final appLower = appName?.toLowerCase() ?? '';

      for (final entry in appSchemes.entries) {
        if (appLower.contains(entry.key)) {
          scheme = entry.value;
          break;
        }
      }

      if (scheme != null) {
        final uri = Uri.parse(scheme);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return {'output': 'Opening $appName', 'exit_code': 0};
        }
      }

      // Try launch by package name
      if (packageName != null) {
        final uri = Uri.parse('android-app://$packageName');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return {'output': 'Opening app: $packageName', 'exit_code': 0};
        }
      }

      return {
        'output': 'Could not open app: ${appName ?? packageName}',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error opening app: $e', 'exit_code': 1};
    }
  }

  /// Open device settings
  Future<Map<String, dynamic>> _openSettings(Map<String, dynamic> args) async {
    try {
      final settingsType = args['type'] as String? ?? 'main';

      final Map<String, String> settingsUris = {
        'main': 'android.settings.SETTINGS',
        'wifi': 'android.settings.WIFI_SETTINGS',
        'bluetooth': 'android.settings.BLUETOOTH_SETTINGS',
        'location': 'android.settings.LOCATION_SOURCE_SETTINGS',
        'display': 'android.settings.DISPLAY_SETTINGS',
        'sound': 'android.settings.SOUND_SETTINGS',
        'battery': 'android.settings.BATTERY_SAVER_SETTINGS',
        'apps': 'android.settings.APPLICATION_SETTINGS',
        'notification': 'android.settings.NOTIFICATION_SETTINGS',
        'security': 'android.settings.SECURITY_SETTINGS',
        'accessibility': 'android.settings.ACCESSIBILITY_SETTINGS',
      };

      final settingsUri =
          settingsUris[settingsType.toLowerCase()] ?? settingsUris['main']!;
      final uri = Uri.parse(
        'android-app://com.android.settings/#Intent;action=$settingsUri;end',
      );

      // Fallback for settings
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return {'output': 'Opening $settingsType settings', 'exit_code': 0};
      }

      // Try simpler approach
      final simpleUri = Uri.parse('package:com.android.settings');
      if (await canLaunchUrl(simpleUri)) {
        await launchUrl(simpleUri, mode: LaunchMode.externalApplication);
        return {'output': 'Opening settings', 'exit_code': 0};
      }

      return {'output': 'Could not open settings', 'exit_code': 1};
    } catch (e) {
      return {'output': 'Error opening settings: $e', 'exit_code': 1};
    }
  }

  /// Control the flashlight
  Future<Map<String, dynamic>> _setFlashlight(Map<String, dynamic> args) async {
    try {
      final enable = args['enable'] as bool? ?? args['on'] as bool? ?? true;

      // Method channel for flashlight control
      const channel = MethodChannel('dev.agixt.agixt/device_control');

      try {
        await channel.invokeMethod('setFlashlight', {'enable': enable});
        return {
          'output': 'Flashlight ${enable ? "on" : "off"}',
          'exit_code': 0,
        };
      } on MissingPluginException {
        return {
          'output': 'Flashlight control not implemented on this platform',
          'exit_code': 1,
        };
      }
    } catch (e) {
      return {'output': 'Error controlling flashlight: $e', 'exit_code': 1};
    }
  }

  /// Get battery status
  Future<Map<String, dynamic>> _getBatteryStatus(
    Map<String, dynamic> args,
  ) async {
    try {
      const channel = MethodChannel('dev.agixt.agixt/device_control');

      try {
        final result = await channel.invokeMethod('getBatteryStatus');
        return {'output': jsonEncode(result), 'exit_code': 0};
      } on MissingPluginException {
        // Fallback to basic info
        return {
          'output': jsonEncode({'note': 'Battery status not available'}),
          'exit_code': 0,
        };
      }
    } catch (e) {
      return {'output': 'Error getting battery status: $e', 'exit_code': 1};
    }
  }

  /// Set an alarm
  Future<Map<String, dynamic>> _setAlarm(Map<String, dynamic> args) async {
    try {
      final hour = args['hour'] as int?;
      final minute = args['minute'] as int? ?? 0;
      final message = args['message'] as String? ?? 'Alarm';

      if (hour == null) {
        return {'output': 'Missing required parameter: hour', 'exit_code': 1};
      }

      // Use Android alarm intent
      final uri = Uri.parse(
        'android-app://com.google.android.deskclock/#Intent;'
        'action=android.intent.action.SET_ALARM;'
        'S.android.intent.extra.alarm.MESSAGE=$message;'
        'i.android.intent.extra.alarm.HOUR=$hour;'
        'i.android.intent.extra.alarm.MINUTES=$minute;'
        'end',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return {
          'output':
              'Setting alarm for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
          'exit_code': 0,
        };
      }

      return {
        'output': 'Could not set alarm - clock app not available',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error setting alarm: $e', 'exit_code': 1};
    }
  }

  /// Set a timer
  Future<Map<String, dynamic>> _setTimer(Map<String, dynamic> args) async {
    try {
      final seconds = args['seconds'] as int? ?? 0;
      final minutes = args['minutes'] as int? ?? 0;
      final hours = args['hours'] as int? ?? 0;
      final message = args['message'] as String? ?? 'Timer';

      final totalSeconds = hours * 3600 + minutes * 60 + seconds;
      if (totalSeconds <= 0) {
        return {
          'output': 'Timer duration must be greater than 0',
          'exit_code': 1,
        };
      }

      // Use Android timer intent
      final uri = Uri.parse(
        'android-app://com.google.android.deskclock/#Intent;'
        'action=android.intent.action.SET_TIMER;'
        'S.android.intent.extra.alarm.MESSAGE=$message;'
        'i.android.intent.extra.alarm.LENGTH=$totalSeconds;'
        'end',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return {
          'output': 'Setting timer for ${hours}h ${minutes}m ${seconds}s',
          'exit_code': 0,
        };
      }

      return {
        'output': 'Could not set timer - clock app not available',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error setting timer: $e', 'exit_code': 1};
    }
  }

  // ==================== Media Control Tools ====================

  /// Device control method channel
  static const MethodChannel _deviceControlChannel = MethodChannel(
    'dev.agixt.agixt/device_control',
  );

  /// Control media playback (play, pause, next, previous, stop)
  Future<Map<String, dynamic>> _mediaControl(Map<String, dynamic> args) async {
    try {
      final action = args['action'] as String? ?? 'play_pause';

      final result = await _deviceControlChannel.invokeMethod('mediaControl', {
        'action': action,
      });

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {'output': 'Media control: $action', 'exit_code': 0};
    } on MissingPluginException {
      return {
        'output': 'Media control not available on this platform',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error controlling media: $e', 'exit_code': 1};
    }
  }

  /// Get information about currently playing media
  Future<Map<String, dynamic>> _getMediaInfo(Map<String, dynamic> args) async {
    try {
      final result = await _deviceControlChannel.invokeMethod('getMediaInfo');

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {
        'output': jsonEncode({'note': 'No media info available'}),
        'exit_code': 0
      };
    } on MissingPluginException {
      return {
        'output':
            jsonEncode({'note': 'Media info not available on this platform'}),
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error getting media info: $e', 'exit_code': 1};
    }
  }

  // ==================== Volume Control Tools ====================

  /// Set volume level (0-100 percentage)
  Future<Map<String, dynamic>> _setVolume(Map<String, dynamic> args) async {
    try {
      final level = args['level'] as int? ?? 50;
      final stream = args['stream'] as String? ?? 'media';

      final result = await _deviceControlChannel.invokeMethod('setVolume', {
        'level': level,
        'stream': stream,
      });

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {'output': 'Volume set to $level%', 'exit_code': 0};
    } on MissingPluginException {
      return {
        'output': 'Volume control not available on this platform',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error setting volume: $e', 'exit_code': 1};
    }
  }

  /// Get current volume level
  Future<Map<String, dynamic>> _getVolume(Map<String, dynamic> args) async {
    try {
      final stream = args['stream'] as String? ?? 'media';

      final result = await _deviceControlChannel.invokeMethod('getVolume', {
        'stream': stream,
      });

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {
        'output': jsonEncode({'note': 'Volume info not available'}),
        'exit_code': 0
      };
    } on MissingPluginException {
      return {
        'output': jsonEncode(
            {'note': 'Volume control not available on this platform'}),
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error getting volume: $e', 'exit_code': 1};
    }
  }

  /// Adjust volume up/down/mute
  Future<Map<String, dynamic>> _adjustVolume(Map<String, dynamic> args) async {
    try {
      final direction = args['direction'] as String? ?? 'up';
      final stream = args['stream'] as String? ?? 'media';

      final result = await _deviceControlChannel.invokeMethod('adjustVolume', {
        'direction': direction,
        'stream': stream,
      });

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {'output': 'Volume adjusted $direction', 'exit_code': 0};
    } on MissingPluginException {
      return {
        'output': 'Volume control not available on this platform',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error adjusting volume: $e', 'exit_code': 1};
    }
  }

  // ==================== Ringer Mode Tools ====================

  /// Set ringer mode (normal, vibrate, silent)
  Future<Map<String, dynamic>> _setRingerMode(Map<String, dynamic> args) async {
    try {
      final mode = args['mode'] as String? ?? 'normal';

      final result = await _deviceControlChannel.invokeMethod('setRingerMode', {
        'mode': mode,
      });

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {'output': 'Ringer mode set to $mode', 'exit_code': 0};
    } on MissingPluginException {
      return {
        'output': 'Ringer mode control not available on this platform',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error setting ringer mode: $e', 'exit_code': 1};
    }
  }

  /// Get current ringer mode
  Future<Map<String, dynamic>> _getRingerMode(Map<String, dynamic> args) async {
    try {
      final result = await _deviceControlChannel.invokeMethod('getRingerMode');

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {
        'output': jsonEncode({'note': 'Ringer mode not available'}),
        'exit_code': 0
      };
    } on MissingPluginException {
      return {
        'output':
            jsonEncode({'note': 'Ringer mode not available on this platform'}),
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error getting ringer mode: $e', 'exit_code': 1};
    }
  }

  // ==================== Brightness Tools ====================

  /// Set screen brightness (0-100 percentage)
  Future<Map<String, dynamic>> _setBrightness(Map<String, dynamic> args) async {
    try {
      final level = args['level'] as int? ?? 50;

      final result = await _deviceControlChannel.invokeMethod('setBrightness', {
        'level': level,
      });

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {'output': 'Brightness set to $level%', 'exit_code': 0};
    } on MissingPluginException {
      return {
        'output': 'Brightness control not available on this platform',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error setting brightness: $e', 'exit_code': 1};
    }
  }

  /// Get current brightness level
  Future<Map<String, dynamic>> _getBrightness(Map<String, dynamic> args) async {
    try {
      final result = await _deviceControlChannel.invokeMethod('getBrightness');

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {
        'output': jsonEncode({'note': 'Brightness info not available'}),
        'exit_code': 0
      };
    } on MissingPluginException {
      return {
        'output': jsonEncode(
            {'note': 'Brightness control not available on this platform'}),
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error getting brightness: $e', 'exit_code': 1};
    }
  }

  // ==================== Connectivity Tools ====================

  /// Toggle WiFi on/off
  Future<Map<String, dynamic>> _toggleWifi(Map<String, dynamic> args) async {
    try {
      final enable = args['enable'] as bool?;

      final result = await _deviceControlChannel.invokeMethod('toggleWifi', {
        'enable': enable,
      });

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {'output': 'WiFi toggled', 'exit_code': 0};
    } on MissingPluginException {
      return {
        'output': 'WiFi control not available on this platform',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error toggling WiFi: $e', 'exit_code': 1};
    }
  }

  /// Get WiFi status
  Future<Map<String, dynamic>> _getWifiStatus(Map<String, dynamic> args) async {
    try {
      final result = await _deviceControlChannel.invokeMethod('getWifiStatus');

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {
        'output': jsonEncode({'note': 'WiFi status not available'}),
        'exit_code': 0
      };
    } on MissingPluginException {
      return {
        'output':
            jsonEncode({'note': 'WiFi status not available on this platform'}),
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error getting WiFi status: $e', 'exit_code': 1};
    }
  }

  /// Toggle Bluetooth on/off
  Future<Map<String, dynamic>> _toggleBluetooth(
      Map<String, dynamic> args) async {
    try {
      final enable = args['enable'] as bool?;

      final result =
          await _deviceControlChannel.invokeMethod('toggleBluetooth', {
        'enable': enable,
      });

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {'output': 'Bluetooth toggled', 'exit_code': 0};
    } on MissingPluginException {
      return {
        'output': 'Bluetooth control not available on this platform',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error toggling Bluetooth: $e', 'exit_code': 1};
    }
  }

  /// Get Bluetooth status
  Future<Map<String, dynamic>> _getBluetoothStatus(
      Map<String, dynamic> args) async {
    try {
      final result =
          await _deviceControlChannel.invokeMethod('getBluetoothStatus');

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {
        'output': jsonEncode({'note': 'Bluetooth status not available'}),
        'exit_code': 0
      };
    } on MissingPluginException {
      return {
        'output': jsonEncode(
            {'note': 'Bluetooth status not available on this platform'}),
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error getting Bluetooth status: $e', 'exit_code': 1};
    }
  }

  // ==================== Do Not Disturb Tools ====================

  /// Set Do Not Disturb mode
  Future<Map<String, dynamic>> _setDoNotDisturb(
      Map<String, dynamic> args) async {
    try {
      final enable = args['enable'] as bool? ?? true;

      final result =
          await _deviceControlChannel.invokeMethod('setDoNotDisturb', {
        'enable': enable,
      });

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {
        'output': 'Do Not Disturb ${enable ? "enabled" : "disabled"}',
        'exit_code': 0
      };
    } on MissingPluginException {
      return {
        'output': 'Do Not Disturb control not available on this platform',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error setting Do Not Disturb: $e', 'exit_code': 1};
    }
  }

  /// Get Do Not Disturb status
  Future<Map<String, dynamic>> _getDoNotDisturbStatus(
      Map<String, dynamic> args) async {
    try {
      final result =
          await _deviceControlChannel.invokeMethod('getDoNotDisturbStatus');

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {
        'output': jsonEncode({'note': 'DND status not available'}),
        'exit_code': 0
      };
    } on MissingPluginException {
      return {
        'output': jsonEncode(
            {'note': 'Do Not Disturb not available on this platform'}),
        'exit_code': 1,
      };
    } catch (e) {
      return {
        'output': 'Error getting Do Not Disturb status: $e',
        'exit_code': 1
      };
    }
  }

  // ==================== Screen Control Tools ====================

  /// Wake the screen
  Future<Map<String, dynamic>> _wakeScreen(Map<String, dynamic> args) async {
    try {
      final result = await _deviceControlChannel.invokeMethod('wakeScreen');

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {'output': 'Screen awakened', 'exit_code': 0};
    } on MissingPluginException {
      return {
        'output': 'Screen wake not available on this platform',
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error waking screen: $e', 'exit_code': 1};
    }
  }

  /// Get screen status (on/off, locked)
  Future<Map<String, dynamic>> _getScreenStatus(
      Map<String, dynamic> args) async {
    try {
      final result = await _deviceControlChannel.invokeMethod('isScreenOn');

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {
        'output': jsonEncode({'note': 'Screen status not available'}),
        'exit_code': 0
      };
    } on MissingPluginException {
      return {
        'output': jsonEncode(
            {'note': 'Screen status not available on this platform'}),
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error getting screen status: $e', 'exit_code': 1};
    }
  }

  // ==================== System Info Tools ====================

  /// Get comprehensive system info (volumes, battery, screen, etc.)
  Future<Map<String, dynamic>> _getSystemInfo(Map<String, dynamic> args) async {
    try {
      final result = await _deviceControlChannel.invokeMethod('getSystemInfo');

      if (result is Map) {
        return {'output': jsonEncode(result), 'exit_code': 0};
      }
      return {
        'output': jsonEncode({'note': 'System info not available'}),
        'exit_code': 0
      };
    } on MissingPluginException {
      return {
        'output':
            jsonEncode({'note': 'System info not available on this platform'}),
        'exit_code': 1,
      };
    } catch (e) {
      return {'output': 'Error getting system info: $e', 'exit_code': 1};
    }
  }

  /// Search the web
  Future<Map<String, dynamic>> _searchWeb(Map<String, dynamic> args) async {
    try {
      final query = args['query'] as String?;
      final engine = args['engine'] as String? ?? 'google';

      if (query == null || query.isEmpty) {
        return {'output': 'Missing required parameter: query', 'exit_code': 1};
      }

      final encodedQuery = Uri.encodeComponent(query);
      String searchUrl;

      switch (engine.toLowerCase()) {
        case 'google':
          searchUrl = 'https://www.google.com/search?q=$encodedQuery';
          break;
        case 'bing':
          searchUrl = 'https://www.bing.com/search?q=$encodedQuery';
          break;
        case 'duckduckgo':
        case 'ddg':
          searchUrl = 'https://duckduckgo.com/?q=$encodedQuery';
          break;
        default:
          searchUrl = 'https://www.google.com/search?q=$encodedQuery';
      }

      final uri = Uri.parse(searchUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return {'output': 'Searching for: $query', 'exit_code': 0};
      }

      return {'output': 'Could not open browser for search', 'exit_code': 1};
    } catch (e) {
      return {'output': 'Error searching web: $e', 'exit_code': 1};
    }
  }

  /// Save a note to local storage
  Future<Map<String, dynamic>> _saveNote(Map<String, dynamic> args) async {
    try {
      final title = args['title'] as String?;
      final content = args['content'] as String? ?? args['text'] as String?;

      if (content == null || content.isEmpty) {
        return {
          'output': 'Missing required parameter: content',
          'exit_code': 1,
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final notes = prefs.getStringList('agixt_notes') ?? [];

      final note = jsonEncode({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title ?? 'Note',
        'content': content,
        'created': DateTime.now().toIso8601String(),
      });

      notes.add(note);
      await prefs.setStringList('agixt_notes', notes);

      return {
        'output': jsonEncode({
          'success': true,
          'message': 'Note saved',
          'title': title ?? 'Note',
        }),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error saving note: $e', 'exit_code': 1};
    }
  }

  /// Get saved notes
  Future<Map<String, dynamic>> _getNotes(Map<String, dynamic> args) async {
    try {
      final limit = args['limit'] as int? ?? 20;
      final search = args['search'] as String?;

      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getStringList('agixt_notes') ?? [];

      List<Map<String, dynamic>> notes =
          notesJson.map((n) => jsonDecode(n) as Map<String, dynamic>).toList();

      // Filter by search if provided
      if (search != null && search.isNotEmpty) {
        final searchLower = search.toLowerCase();
        notes = notes.where((n) {
          final title = (n['title'] as String? ?? '').toLowerCase();
          final content = (n['content'] as String? ?? '').toLowerCase();
          return title.contains(searchLower) || content.contains(searchLower);
        }).toList();
      }

      // Sort by created date (newest first)
      notes.sort((a, b) {
        final aCreated = a['created'] as String? ?? '';
        final bCreated = b['created'] as String? ?? '';
        return bCreated.compareTo(aCreated);
      });

      // Limit results
      if (notes.length > limit) {
        notes = notes.sublist(0, limit);
      }

      return {
        'output': jsonEncode({'notes': notes, 'count': notes.length}),
        'exit_code': 0,
      };
    } catch (e) {
      return {'output': 'Error getting notes: $e', 'exit_code': 1};
    }
  }

  /// Check if a string looks like a phone number
  bool _isPhoneNumber(String input) {
    // Simple check - contains mostly digits and common phone chars
    final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    return cleaned.isNotEmpty &&
        cleaned.length >= 7 &&
        RegExp(r'^[\d]+$').hasMatch(cleaned);
  }

  void dispose() {
    stopListening();
  }
}

/// List of available client-side tools that can be sent to the AGiXT server
/// This mirrors the ESP32's client tools format for consistency
class ClientSideTools {
  /// Get tool definitions filtered by granted permissions
  /// Only returns tools the user has actually granted access to
  static Future<List<Map<String, dynamic>>> getToolDefinitions() async {
    final List<Map<String, dynamic>> tools = [];
    final bluetoothManager = BluetoothManager.singleton;

    // Check permissions and connection states
    final contactsGranted = await PermissionManager.isGroupGranted(
      AppPermission.contacts,
    );
    final smsGranted = await PermissionManager.isGroupGranted(
      AppPermission.sms,
    );
    final locationGranted = await PermissionManager.isGroupGranted(
      AppPermission.location,
    );
    final phoneGranted = await PermissionManager.isGroupGranted(
      AppPermission.phone,
    );
    final glassesConnected = bluetoothManager.isConnected;

    // ============================================
    // ESP32-style tools for glasses capabilities
    // ============================================

    // Tool: capture_image - Only available when glasses are connected
    if (glassesConnected) {
      tools.add({
        'type': 'function',
        'function': {
          'name': 'capture_image',
          'description': '''Capture an image using the smart glasses camera.

Use this for visual tasks, taking pictures, or to see what the user is looking at.
The image will be captured from the Even Realities G1 glasses camera.
Always use this tool when you need to see something or verify visual state.''',
          'parameters': {
            'type': 'object',
            'properties': {
              'prompt': {
                'type': 'string',
                'description':
                    'What to analyze in the captured image. Be specific about what you want to observe.',
              },
            },
            'required': ['prompt'],
          },
        },
      });

      // Tool: display_on_glasses
      tools.add({
        'type': 'function',
        'function': {
          'name': 'display_on_glasses',
          'description': '''Display a message on the user's smart glasses.

Use this to show information, confirmations, or status updates on the glasses display.''',
          'parameters': {
            'type': 'object',
            'properties': {
              'message': {
                'type': 'string',
                'description': 'The message to display on the glasses',
              },
              'duration': {
                'type': 'integer',
                'description':
                    'How long to display the message in milliseconds (default: 5000)',
              },
            },
            'required': ['message'],
          },
        },
      });
    }

    // Tool: get_device_capabilities - Always available
    tools.add({
      'type': 'function',
      'function': {
        'name': 'get_device_capabilities',
        'description':
            '''Get information about the mobile device and connected accessories.

Returns details about the device, connected glasses, and available tool capabilities.
Use this to understand what features are available before attempting other operations.''',
        'parameters': {'type': 'object', 'properties': {}, 'required': []},
      },
    });

    // ============================================
    // Contact tools - require contacts permission
    // ============================================

    if (contactsGranted) {
      tools.add({
        'type': 'function',
        'function': {
          'name': 'get_contacts',
          'description': '''Get the user's contacts from their phone.

Returns a list of contacts with names, phone numbers, and email addresses.
Use this when the user asks to find a contact or needs to send a message to someone.''',
          'parameters': {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description':
                    'Maximum number of contacts to return. Default: 50',
              },
            },
            'required': [],
          },
        },
      });

      tools.add({
        'type': 'function',
        'function': {
          'name': 'search_contacts',
          'description': '''Search for contacts by name on the user's phone.

Use this to find a specific contact before sending them a message or calling them.''',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'The name or part of name to search for',
              },
            },
            'required': ['query'],
          },
        },
      });
    }

    // ============================================
    // SMS tool - requires SMS permission
    // ============================================

    if (smsGranted) {
      tools.add({
        'type': 'function',
        'function': {
          'name': 'send_sms',
          'description': '''Send an SMS text message from the user's phone.

This will send a real SMS message. You can provide either a phone number directly
or a contact name (which will be resolved to their phone number).''',
          'parameters': {
            'type': 'object',
            'properties': {
              'phone_number': {
                'type': 'string',
                'description':
                    'The phone number to send to, or the name of a contact',
              },
              'message': {
                'type': 'string',
                'description': 'The text message to send',
              },
            },
            'required': ['phone_number', 'message'],
          },
        },
      });
    }

    // ============================================
    // Location tools - require location permission
    // ============================================

    if (locationGranted) {
      tools.add({
        'type': 'function',
        'function': {
          'name': 'get_location',
          'description': '''Get the user's current GPS location.

Returns latitude, longitude, altitude, accuracy, speed, and heading.
Use this when the user asks where they are or needs location-based assistance.''',
          'parameters': {'type': 'object', 'properties': {}, 'required': []},
        },
      });

      tools.add({
        'type': 'function',
        'function': {
          'name': 'open_maps',
          'description':
              '''Open Google Maps and optionally navigate to a destination.

Can navigate to an address, place name, or specific coordinates.''',
          'parameters': {
            'type': 'object',
            'properties': {
              'destination': {
                'type': 'string',
                'description': 'The address or place name to navigate to',
              },
              'latitude': {
                'type': 'number',
                'description':
                    'Latitude of destination (alternative to address)',
              },
              'longitude': {
                'type': 'number',
                'description':
                    'Longitude of destination (alternative to address)',
              },
              'mode': {
                'type': 'string',
                'description':
                    'Travel mode: d (driving), w (walking), b (bicycling). Default: d',
                'enum': ['d', 'w', 'b'],
              },
            },
            'required': [],
          },
        },
      });
    }

    // ============================================
    // Phone call tool - requires phone permission
    // ============================================

    if (phoneGranted) {
      tools.add({
        'type': 'function',
        'function': {
          'name': 'make_phone_call',
          'description': '''Initiate a phone call.

Can call a phone number directly or find a contact by name and call them.''',
          'parameters': {
            'type': 'object',
            'properties': {
              'phone_number': {
                'type': 'string',
                'description':
                    'The phone number to call, or the name of a contact',
              },
            },
            'required': ['phone_number'],
          },
        },
      });
    }

    // ============================================
    // Utility tools - no special permissions
    // ============================================

    tools.add({
      'type': 'function',
      'function': {
        'name': 'open_url',
        'description': 'Open a URL in the device\'s default browser.',
        'parameters': {
          'type': 'object',
          'properties': {
            'url': {'type': 'string', 'description': 'The URL to open'},
          },
          'required': ['url'],
        },
      },
    });

    tools.add({
      'type': 'function',
      'function': {
        'name': 'get_device_info',
        'description':
            'Get information about the device and available capabilities.',
        'parameters': {'type': 'object', 'properties': {}, 'required': []},
      },
    });

    // ============================================
    // Calendar tools - require calendar permission
    // ============================================

    final calendarGranted = await PermissionManager.isGroupGranted(
      AppPermission.calendar,
    );

    if (calendarGranted) {
      tools.add({
        'type': 'function',
        'function': {
          'name': 'get_calendar_events',
          'description': '''Get calendar events from the user's device.

Returns upcoming events with title, time, location, and description.''',
          'parameters': {
            'type': 'object',
            'properties': {
              'days_ahead': {
                'type': 'integer',
                'description':
                    'Number of days ahead to fetch events. Default: 7',
              },
              'days_before': {
                'type': 'integer',
                'description':
                    'Number of days before today to include. Default: 0',
              },
              'calendar_id': {
                'type': 'string',
                'description': 'Specific calendar ID to query (optional)',
              },
            },
            'required': [],
          },
        },
      });

      tools.add({
        'type': 'function',
        'function': {
          'name': 'create_calendar_event',
          'description': '''Create a new calendar event.

Schedule meetings, reminders, or appointments on the user's calendar.''',
          'parameters': {
            'type': 'object',
            'properties': {
              'title': {'type': 'string', 'description': 'Event title'},
              'start': {
                'type': 'string',
                'description':
                    'Start time in ISO 8601 format (e.g., 2024-01-15T10:00:00)',
              },
              'end': {
                'type': 'string',
                'description':
                    'End time in ISO 8601 format (optional, defaults to 1 hour after start)',
              },
              'description': {
                'type': 'string',
                'description': 'Event description or notes',
              },
              'location': {'type': 'string', 'description': 'Event location'},
              'all_day': {
                'type': 'boolean',
                'description': 'Whether this is an all-day event',
              },
            },
            'required': ['title', 'start'],
          },
        },
      });

      tools.add({
        'type': 'function',
        'function': {
          'name': 'get_calendars',
          'description': 'List all calendars available on the device.',
          'parameters': {'type': 'object', 'properties': {}, 'required': []},
        },
      });
    }

    // ============================================
    // Email tool - always available (uses mailto:)
    // ============================================

    tools.add({
      'type': 'function',
      'function': {
        'name': 'mobile_send_email',
        'description': '''Compose and send an email from the mobile device.

Opens the email app with recipient, subject, and body pre-filled.
Can use a contact name instead of email address.''',
        'parameters': {
          'type': 'object',
          'properties': {
            'to': {
              'type': 'string',
              'description': 'Email address or contact name',
            },
            'subject': {'type': 'string', 'description': 'Email subject line'},
            'body': {'type': 'string', 'description': 'Email body content'},
            'cc': {
              'type': 'string',
              'description': 'CC recipients (comma-separated)',
            },
            'bcc': {
              'type': 'string',
              'description': 'BCC recipients (comma-separated)',
            },
          },
          'required': ['to'],
        },
      },
    });

    // ============================================
    // File operations - within app sandbox (prefixed with mobile_)
    // ============================================

    tools.add({
      'type': 'function',
      'function': {
        'name': 'mobile_read_file',
        'description': '''Read content from a file in mobile app storage.

Read text files, notes, or data saved by the AI assistant.''',
        'parameters': {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'File path (relative to app documents)',
            },
            'max_bytes': {
              'type': 'integer',
              'description': 'Maximum bytes to read. Default: 100KB',
            },
          },
          'required': ['path'],
        },
      },
    });

    tools.add({
      'type': 'function',
      'function': {
        'name': 'mobile_write_file',
        'description': '''Write content to a file in mobile app storage.

Save text, notes, or data for later retrieval.''',
        'parameters': {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'File path (relative to app documents)',
            },
            'content': {'type': 'string', 'description': 'Content to write'},
            'append': {
              'type': 'boolean',
              'description':
                  'Append to existing file instead of overwriting. Default: false',
            },
          },
          'required': ['path', 'content'],
        },
      },
    });

    tools.add({
      'type': 'function',
      'function': {
        'name': 'mobile_list_files',
        'description': 'List files in mobile app storage directory.',
        'parameters': {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Directory path (empty for root)',
            },
            'recursive': {
              'type': 'boolean',
              'description': 'Include subdirectories. Default: false',
            },
          },
          'required': [],
        },
      },
    });

    tools.add({
      'type': 'function',
      'function': {
        'name': 'mobile_delete_file',
        'description': 'Delete a file from mobile app storage.',
        'parameters': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'File path to delete'},
          },
          'required': ['path'],
        },
      },
    });

    // ============================================
    // Clipboard tools - device clipboard (prefixed with mobile_)
    // ============================================

    tools.add({
      'type': 'function',
      'function': {
        'name': 'mobile_get_clipboard',
        'description':
            'Get the current text content from the mobile device clipboard.',
        'parameters': {'type': 'object', 'properties': {}, 'required': []},
      },
    });

    tools.add({
      'type': 'function',
      'function': {
        'name': 'mobile_set_clipboard',
        'description': 'Copy text to the mobile device clipboard.',
        'parameters': {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'Text to copy to clipboard',
            },
          },
          'required': ['text'],
        },
      },
    });

    // ============================================
    // App control tools - always available
    // ============================================

    tools.add({
      'type': 'function',
      'function': {
        'name': 'open_app',
        'description': '''Open an app on the device.

Supports common apps: camera, calculator, calendar, spotify, youtube, etc.''',
        'parameters': {
          'type': 'object',
          'properties': {
            'app': {
              'type': 'string',
              'description': 'App name (e.g., camera, calculator, spotify)',
            },
            'package': {
              'type': 'string',
              'description':
                  'Android package name (optional, for specific apps)',
            },
          },
          'required': ['app'],
        },
      },
    });

    tools.add({
      'type': 'function',
      'function': {
        'name': 'open_settings',
        'description': '''Open device settings.

Can open specific settings panels like WiFi, Bluetooth, Display, etc.''',
        'parameters': {
          'type': 'object',
          'properties': {
            'type': {
              'type': 'string',
              'description':
                  'Settings type: main, wifi, bluetooth, location, display, sound, battery, apps, notification, security, accessibility',
              'enum': [
                'main',
                'wifi',
                'bluetooth',
                'location',
                'display',
                'sound',
                'battery',
                'apps',
                'notification',
                'security',
                'accessibility',
              ],
            },
          },
          'required': [],
        },
      },
    });

    // ============================================
    // Alarm and Timer tools - always available
    // ============================================

    tools.add({
      'type': 'function',
      'function': {
        'name': 'set_alarm',
        'description': 'Set an alarm on the device clock app.',
        'parameters': {
          'type': 'object',
          'properties': {
            'hour': {'type': 'integer', 'description': 'Hour (0-23)'},
            'minute': {
              'type': 'integer',
              'description': 'Minute (0-59). Default: 0',
            },
            'message': {'type': 'string', 'description': 'Alarm label/message'},
          },
          'required': ['hour'],
        },
      },
    });

    tools.add({
      'type': 'function',
      'function': {
        'name': 'set_timer',
        'description': 'Set a countdown timer.',
        'parameters': {
          'type': 'object',
          'properties': {
            'hours': {'type': 'integer', 'description': 'Hours. Default: 0'},
            'minutes': {
              'type': 'integer',
              'description': 'Minutes. Default: 0',
            },
            'seconds': {
              'type': 'integer',
              'description': 'Seconds. Default: 0',
            },
            'message': {'type': 'string', 'description': 'Timer label'},
          },
          'required': [],
        },
      },
    });

    // ============================================
    // Search and utility tools (some prefixed with mobile_)
    // ============================================

    tools.add({
      'type': 'function',
      'function': {
        'name': 'mobile_search_web',
        'description':
            'Search the web using a search engine from the mobile device.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': 'Search query'},
            'engine': {
              'type': 'string',
              'description':
                  'Search engine: google, bing, duckduckgo. Default: google',
              'enum': ['google', 'bing', 'duckduckgo'],
            },
          },
          'required': ['query'],
        },
      },
    });

    tools.add({
      'type': 'function',
      'function': {
        'name': 'get_battery_status',
        'description': 'Get the device battery level and charging status.',
        'parameters': {'type': 'object', 'properties': {}, 'required': []},
      },
    });

    tools.add({
      'type': 'function',
      'function': {
        'name': 'set_flashlight',
        'description': 'Turn the device flashlight on or off.',
        'parameters': {
          'type': 'object',
          'properties': {
            'enable': {
              'type': 'boolean',
              'description': 'true to turn on, false to turn off',
            },
          },
          'required': ['enable'],
        },
      },
    });

    // ============================================
    // Notes/reminders - device local storage (prefixed with mobile_)
    // ============================================

    tools.add({
      'type': 'function',
      'function': {
        'name': 'mobile_save_note',
        'description': '''Save a note on the mobile device for later retrieval.

Store quick notes, reminders, or information the user wants to remember.''',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': 'Note title'},
            'content': {'type': 'string', 'description': 'Note content'},
          },
          'required': ['content'],
        },
      },
    });

    tools.add({
      'type': 'function',
      'function': {
        'name': 'mobile_get_notes',
        'description': 'Retrieve saved notes from the mobile device.',
        'parameters': {
          'type': 'object',
          'properties': {
            'limit': {
              'type': 'integer',
              'description': 'Maximum notes to return. Default: 20',
            },
            'search': {
              'type': 'string',
              'description': 'Search term to filter notes',
            },
          },
          'required': [],
        },
      },
    });

    debugPrint(
      'ClientSideTools: Returning ${tools.length} tools based on permissions and connected devices',
    );
    return tools;
  }
}
