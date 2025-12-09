import 'dart:async';
import 'dart:convert';
import 'package:agixt/services/websocket_service.dart';
import 'package:agixt/services/contacts_service.dart';
import 'package:agixt/services/sms_service.dart';
import 'package:agixt/services/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service that handles client-side commands from the AGiXT agent
/// Similar to the CLI's execute_remote_command functionality but for mobile
class ClientCommandsService {
  static final ClientCommandsService _instance =
      ClientCommandsService._internal();
  factory ClientCommandsService() => _instance;
  ClientCommandsService._internal();

  final AGiXTWebSocketService _webSocketService = AGiXTWebSocketService();
  final ContactsService _contactsService = ContactsService();
  final SmsService _smsService = SmsService();
  final LocationService _locationService = LocationService();

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
      case 'get_contacts':
        return await _getContacts(args);
      case 'search_contacts':
        return await _searchContacts(args);
      case 'send_sms':
        return await _sendSms(args);
      case 'get_location':
        return await _getLocation(args);
      case 'open_maps':
      case 'navigate_to':
        return await _openMaps(args);
      case 'make_phone_call':
        return await _makePhoneCall(args);
      case 'open_url':
        return await _openUrl(args);
      case 'get_device_info':
        return await _getDeviceInfo(args);
      default:
        return {
          'output': 'Unknown command: $toolName. Available commands: '
              'get_contacts, search_contacts, send_sms, get_location, '
              'open_maps, navigate_to, make_phone_call, open_url, get_device_info',
          'exit_code': 1,
        };
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
      return {
        'output': 'Error getting contacts: $e',
        'exit_code': 1,
      };
    }
  }

  /// Search contacts by name
  Future<Map<String, dynamic>> _searchContacts(
      Map<String, dynamic> args) async {
    try {
      final query = args['query'] as String?;
      if (query == null || query.isEmpty) {
        return {
          'output': 'Missing required parameter: query',
          'exit_code': 1,
        };
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
      return {
        'output': 'Error searching contacts: $e',
        'exit_code': 1,
      };
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
              'ClientCommands: Resolved "$phoneNumber" to "$resolvedNumber"');
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
      return {
        'output': 'Error sending SMS: $e',
        'exit_code': 1,
      };
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
      return {
        'output': 'Error getting location: $e',
        'exit_code': 1,
      };
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
      final mode = args['mode'] as String? ?? 'd'; // d=driving, w=walking, b=bicycling

      Uri uri;

      if (destination != null && destination.isNotEmpty) {
        // Navigate to address/place name
        final encodedDest = Uri.encodeComponent(destination);
        uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$encodedDest&travelmode=$mode');
      } else if (lat != null && lng != null) {
        // Navigate to coordinates
        uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=$mode');
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
      return {
        'output': 'Error opening maps: $e',
        'exit_code': 1,
      };
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
        return {
          'output': 'Initiating call to $resolvedNumber',
          'exit_code': 0,
        };
      } else {
        return {
          'output': 'Could not initiate phone call',
          'exit_code': 1,
        };
      }
    } catch (e) {
      return {
        'output': 'Error making phone call: $e',
        'exit_code': 1,
      };
    }
  }

  /// Open a URL in the default browser
  Future<Map<String, dynamic>> _openUrl(Map<String, dynamic> args) async {
    try {
      final urlStr = args['url'] as String?;
      if (urlStr == null || urlStr.isEmpty) {
        return {
          'output': 'Missing required parameter: url',
          'exit_code': 1,
        };
      }

      Uri uri;
      try {
        uri = Uri.parse(urlStr);
        if (!uri.hasScheme) {
          uri = Uri.parse('https://$urlStr');
        }
      } catch (e) {
        return {
          'output': 'Invalid URL: $urlStr',
          'exit_code': 1,
        };
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return {
          'output': 'Opening URL: $uri',
          'exit_code': 0,
        };
      } else {
        return {
          'output': 'Could not open URL: $uri',
          'exit_code': 1,
        };
      }
    } catch (e) {
      return {
        'output': 'Error opening URL: $e',
        'exit_code': 1,
      };
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

      return {
        'output': jsonEncode(info),
        'exit_code': 0,
      };
    } catch (e) {
      return {
        'output': 'Error getting device info: $e',
        'exit_code': 1,
      };
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
/// This mirrors the CLI's cli_tools array format
class ClientSideTools {
  static List<Map<String, dynamic>> getToolDefinitions() {
    return [
      {
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
                'description': 'Maximum number of contacts to return. Default: 50',
              },
            },
            'required': [],
          },
        },
      },
      {
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
      },
      {
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
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_location',
          'description': '''Get the user's current GPS location.

Returns latitude, longitude, altitude, accuracy, speed, and heading.
Use this when the user asks where they are or needs location-based assistance.''',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'open_maps',
          'description': '''Open Google Maps and optionally navigate to a destination.

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
      },
      {
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
      },
      {
        'type': 'function',
        'function': {
          'name': 'open_url',
          'description': 'Open a URL in the device\'s default browser.',
          'parameters': {
            'type': 'object',
            'properties': {
              'url': {
                'type': 'string',
                'description': 'The URL to open',
              },
            },
            'required': ['url'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_device_info',
          'description':
              'Get information about the device and available capabilities.',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
    ];
  }
}
