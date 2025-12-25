import 'dart:async';
import 'dart:convert';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/agixt/calendar.dart';
import 'package:agixt/models/agixt/checklist.dart';
import 'package:agixt/models/agixt/daily.dart';
import 'package:agixt/models/agixt/widgets/agixt_widget.dart';
import 'package:agixt/models/g1/note.dart';
import 'package:agixt/screens/home_screen.dart'; // Import HomePage
import 'package:agixt/services/cookie_manager.dart';
import 'package:agixt/services/session_manager.dart';
import 'package:agixt/services/secure_storage_service.dart';
import 'package:agixt/services/location_service.dart'; // Import LocationService
import 'package:agixt/services/client_commands_service.dart'; // Import ClientSideTools
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AGiXTChatWidget implements AGiXTWidget {
  static const String DEFAULT_MODEL = "XT";
  static const int DEFAULT_PRIORITY = 1;
  static const String _interactionStorageKey = 'agixt_last_interaction_v1';
  static final SecureStorageService _secureStorage = SecureStorageService();

  @override
  int getPriority() {
    return DEFAULT_PRIORITY;
  }

  // Get the agent name from cookie or use default
  Future<String> _getAgentName() async {
    final cookieManager = CookieManager();
    final agentName = await cookieManager.getAgixtAgentCookie();

    // Return the agent name from cookie or default to EVEN_REALITIES_GLASSES
    return agentName?.isNotEmpty == true ? agentName! : DEFAULT_MODEL;
  }

  @override
  Future<List<Note>> generateDashboardItems() async {
    // Get the user's last question and response if available
    final lastInteraction = await _getLastInteraction();
    if (lastInteraction != null) {
      final note = Note(
        noteNumber: 1,
        name: 'Recent AI Chat',
        text: 'Q: ${lastInteraction.question}\nA: ${lastInteraction.answer}',
      );
      return [note];
    }

    // If no previous interaction, return a welcome note
    return [
      Note(
        noteNumber: 1,
        name: 'AGiXT Chat',
        text: 'Press the side button to speak with AGiXT AI assistant.',
      ),
    ];
  }

  // Send a message to the AGiXT chat completions API
  Future<String?> sendChatMessage(String message) async {
    try {
      final jwt = await AuthService.getJwt();
      if (jwt == null) {
        return "Please login to use AGiXT chat.";
      }

      // Get the current conversation ID
      final conversationId = await _getCurrentConversationId();
      debugPrint('Using conversation ID for chat: $conversationId');

      // Create chat request with context if available
      String finalMessage = message;

      // Build context data with timeout to prevent blocking AI responses
      String contextData = '';
      try {
        contextData = await _buildContextData().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint(
              'Context building timed out, proceeding without context',
            );
            return '';
          },
        );
        if (contextData.isNotEmpty) {
          debugPrint('Adding context data to user message');
        }
      } catch (e) {
        debugPrint('Error building context data, proceeding without it: $e');
        contextData = '';
      }

      // Get available tools based on granted permissions
      final availableTools = await ClientSideTools.getToolDefinitions();

      final Map<String, dynamic> requestBody = {
        "model": await _getAgentName(),
        "messages": [
          {
            "role": "user",
            "content": finalMessage,
            if (contextData.isNotEmpty) "context": contextData,
          },
        ],
        "user": conversationId, // Use the conversation ID for the user field
        // Include client-side tools so the agent can execute commands on user's device
        // Only tools with granted permissions are included
        if (availableTools.isNotEmpty) "tools": availableTools,
        if (availableTools.isNotEmpty)
          "tool_choice": "auto", // Let the model decide when to use tools
      };

      // Send request to AGiXT API
      final response = await http.post(
        Uri.parse('${AuthService.serverUrl}/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['choices'] != null &&
            jsonResponse['choices'].isNotEmpty &&
            jsonResponse['choices'][0]['message'] != null) {
          final answer = jsonResponse['choices'][0]['message']['content'];

          // Extract the conversation ID from the response
          final responseId = jsonResponse['id'];
          if (responseId != null && responseId.toString().isNotEmpty) {
            // Save the conversation ID from the response
            final cookieManager = CookieManager();
            final newConversationId = responseId.toString();
            await cookieManager.saveAgixtConversationId(newConversationId);
            debugPrint(
              'Saved conversation ID from response: $newConversationId',
            );

            // Only navigate if we get a different ID than "-"
            if (newConversationId != "-") {
              // Navigate to the conversation after a short delay
              _navigateToConversation(newConversationId, jwt);
            }
          }

          // Save this interaction for future reference
          await _saveInteraction(message, answer);

          return answer;
        }
      } else if (response.statusCode == 401) {
        // JWT may be expired
        await SessionManager.clearSession();
        return "Authentication expired. Please login again.";
      }

      return "Sorry, I couldn't get a response at this time.";
    } catch (e) {
      debugPrint('AGiXT Chat error: $e');
      return "An error occurred while connecting to AGiXT.";
    }
  }

  /// Send chat message without context data (for background mode)
  Future<String?> sendChatMessageDirect(String message) async {
    try {
      final jwt = await AuthService.getJwt();
      if (jwt == null) {
        return "Please login to use AGiXT chat.";
      }

      // Get the current conversation ID
      final conversationId = await _getCurrentConversationId();
      debugPrint('Using conversation ID for direct chat: $conversationId');

      // Create minimal chat request without context to avoid blocking
      final Map<String, dynamic> requestBody = {
        "model": await _getAgentName(),
        "messages": [
          {"role": "user", "content": message},
        ],
        "user": conversationId, // Use the conversation ID for the user field
      };

      // Send request to AGiXT API
      final response = await http.post(
        Uri.parse('${AuthService.serverUrl}/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['choices'] != null &&
            jsonResponse['choices'].isNotEmpty &&
            jsonResponse['choices'][0]['message'] != null) {
          final answer = jsonResponse['choices'][0]['message']['content'];

          // Extract the conversation ID from the response
          final responseId = jsonResponse['id'];
          if (responseId != null && responseId.toString().isNotEmpty) {
            // Save the conversation ID from the response
            final cookieManager = CookieManager();
            final newConversationId = responseId.toString();
            await cookieManager.saveAgixtConversationId(newConversationId);
            debugPrint(
              'Saved conversation ID from direct response: $newConversationId',
            );
          }

          debugPrint('AGiXT Direct Response: $answer');
          return answer;
        }
      }

      debugPrint('AGiXT API Error: ${response.statusCode} - ${response.body}');
      return "Error: Unable to get response from AGiXT (${response.statusCode})";
    } catch (e) {
      debugPrint('Error sending direct chat message: $e');
      return "Error: Failed to communicate with AGiXT";
    }
  }

  /// Send chat message with streaming response
  /// Returns a stream of response chunks as they arrive
  Stream<String> sendChatMessageStreaming(String message) async* {
    try {
      final jwt = await AuthService.getJwt();
      if (jwt == null) {
        yield "Please login to use AGiXT chat.";
        return;
      }

      final conversationId = await _getCurrentConversationId();
      debugPrint('Using conversation ID for streaming chat: $conversationId');

      // Build context data with timeout
      String contextData = '';
      try {
        contextData = await _buildContextData().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Context building timed out');
            return '';
          },
        );
      } catch (e) {
        debugPrint('Error building context data: $e');
      }

      // Get available tools
      final availableTools = await ClientSideTools.getToolDefinitions();

      final Map<String, dynamic> requestBody = {
        "model": await _getAgentName(),
        "messages": [
          {
            "role": "user",
            "content": message,
            if (contextData.isNotEmpty) "context": contextData,
          },
        ],
        "user": conversationId,
        "stream": true, // Enable streaming!
        if (availableTools.isNotEmpty) "tools": availableTools,
        if (availableTools.isNotEmpty) "tool_choice": "auto",
      };

      // Create streaming request
      final client = http.Client();
      final request = http.Request(
        'POST',
        Uri.parse('${AuthService.serverUrl}/v1/chat/completions'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
        'Accept': 'text/event-stream',
      });
      request.body = jsonEncode(requestBody);

      debugPrint('Sending streaming chat request...');
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode == 200) {
        String buffer = '';
        String fullResponse = '';
        String? newConversationId;

        await for (final chunk in streamedResponse.stream.transform(
          utf8.decoder,
        )) {
          buffer += chunk;

          // Process complete SSE events (lines starting with "data: ")
          while (buffer.contains('\n')) {
            final newlineIndex = buffer.indexOf('\n');
            final line = buffer.substring(0, newlineIndex).trim();
            buffer = buffer.substring(newlineIndex + 1);

            if (line.isEmpty) continue;
            if (!line.startsWith('data: ')) continue;

            final data = line.substring(6); // Remove "data: " prefix

            // Check for stream end
            if (data == '[DONE]') {
              debugPrint('Stream complete');
              continue;
            }

            try {
              final jsonData = jsonDecode(data);

              // Extract conversation ID from first chunk
              if (newConversationId == null && jsonData['id'] != null) {
                newConversationId = jsonData['id'].toString();
                debugPrint(
                  'Got conversation ID from stream: $newConversationId',
                );
              }

              // Extract content delta
              if (jsonData['choices'] != null &&
                  jsonData['choices'].isNotEmpty) {
                final delta = jsonData['choices'][0]['delta'];
                if (delta != null && delta['content'] != null) {
                  final content = delta['content'].toString();
                  fullResponse += content;
                  yield content; // Yield each chunk as it arrives
                }
              }
            } catch (e) {
              // Skip malformed JSON chunks
              debugPrint('Error parsing SSE chunk: $e');
            }
          }
        }

        // Save conversation ID after stream completes
        if (newConversationId != null && newConversationId != '-') {
          final cookieManager = CookieManager();
          await cookieManager.saveAgixtConversationId(newConversationId);
          debugPrint('Saved conversation ID: $newConversationId');
          _navigateToConversation(newConversationId, jwt);
        }

        // Save the full interaction
        if (fullResponse.isNotEmpty) {
          await _saveInteraction(message, fullResponse);
        }

        client.close();
      } else if (streamedResponse.statusCode == 401) {
        await SessionManager.clearSession();
        yield "Authentication expired. Please login again.";
        client.close();
      } else {
        debugPrint('Streaming API Error: ${streamedResponse.statusCode}');
        yield "Error: Unable to get response (${streamedResponse.statusCode})";
        client.close();
      }
    } catch (e) {
      debugPrint('Streaming chat error: $e');
      yield "An error occurred while connecting to AGiXT.";
    }
  }

  /// Convenience method to collect full streaming response as a single string
  Future<String?> sendChatMessageStreamingFull(String message) async {
    final buffer = StringBuffer();
    await for (final chunk in sendChatMessageStreaming(message)) {
      buffer.write(chunk);
    }
    return buffer.isEmpty ? null : buffer.toString();
  }

  // Navigate to the conversation in the WebView
  Future<void> _navigateToConversation(
    String conversationId,
    String jwt,
  ) async {
    try {
      // Get access to the WebViewController from the HomePage static property
      final webViewController = HomePage.webViewController;

      if (webViewController != null) {
        // Wait a second before navigating to ensure the response is processed
        await Future.delayed(const Duration(seconds: 1));

        // Build the navigation URL with the conversation ID but WITHOUT the token
        final baseUrl = AuthService.appUri;
        final navigationUrl = '$baseUrl/chat/$conversationId';

        debugPrint('Navigating to conversation: $navigationUrl');

        // Plain JavaScript navigation
        final plainJsNavigation = '''
        (function() {
          console.log('Navigating to: $navigationUrl');
          window.location.href = '$navigationUrl';
          return true;
        })();
        ''';

        await webViewController.runJavaScriptReturningResult(plainJsNavigation);

        // Also use loadRequest as a fallback
        await Future.delayed(const Duration(milliseconds: 300));
        await webViewController.loadRequest(Uri.parse(navigationUrl));
      } else {
        debugPrint('WebViewController not available for navigation');
      }
    } catch (e) {
      debugPrint('Error navigating to conversation: $e');
    }
  }

  // Build context data containing today's daily items, active checklists, calendar items, and location
  Future<String> _buildContextData() async {
    List<String> contextSections = [];
    contextSections.add("The users message is transcribed from voice to text.");

    // Get today's daily items with timeout
    try {
      final dailyItems = await _getTodaysDailyItems().timeout(
        const Duration(seconds: 1),
        onTimeout: () => '',
      );
      if (dailyItems.isNotEmpty) {
        contextSections.add("### Users items for today\n\n$dailyItems");
      }
    } catch (e) {
      debugPrint('Error getting daily items: $e');
    }

    // Get user's current active checklist tasks with timeout
    try {
      final currentTasks = await _getCurrentChecklistTasks().timeout(
        const Duration(seconds: 1),
        onTimeout: () => '',
      );
      if (currentTasks.isNotEmpty) {
        contextSections.add("### Users current task\n\n$currentTasks");
      }
    } catch (e) {
      debugPrint('Error getting checklist tasks: $e');
    }

    // Get today's calendar items with timeout
    try {
      final calendarItems = await _getTodaysCalendarItems().timeout(
        const Duration(seconds: 1),
        onTimeout: () => '',
      );
      if (calendarItems.isNotEmpty) {
        contextSections.add(
          "### Users calendar items for today\n\n$calendarItems",
        );
      }
    } catch (e) {
      debugPrint('Error getting calendar items: $e');
    }

    // Get user's location if enabled with timeout
    try {
      final locationData = await _getUserLocation().timeout(
        const Duration(seconds: 1),
        onTimeout: () => '',
      );
      if (locationData.isNotEmpty) {
        contextSections.add("### User's Current Location\n\n$locationData");
      }
    } catch (e) {
      debugPrint('Error getting location data: $e');
    }

    return contextSections.join("\n\n");
  }

  // Get formatted list of today's daily items
  Future<String> _getTodaysDailyItems() async {
    try {
      final agixtDailyBox = Hive.box<AGiXTDailyItem>('agixtDailyBox');
      if (agixtDailyBox.isEmpty) return '';

      final items = agixtDailyBox.values.toList();
      items.sort((a, b) {
        if (a.hour == null || a.minute == null) return 1;
        if (b.hour == null || b.minute == null) return -1;
        return TimeOfDay(
          hour: a.hour!,
          minute: a.minute!,
        ).compareTo(TimeOfDay(hour: b.hour!, minute: b.minute!));
      });

      return items
          .map(
            (item) =>
                "${item.hour?.toString().padLeft(2, '0') ?? '--'}:${item.minute?.toString().padLeft(2, '0') ?? '--'} ${item.title}",
          )
          .join('\n');
    } catch (e) {
      debugPrint('Error fetching daily items: $e');
      return '';
    }
  }

  // Get formatted list of active checklist tasks
  Future<String> _getCurrentChecklistTasks() async {
    try {
      final checklistBox = Hive.box<AGiXTChecklist>('agixtChecklistBox');
      if (checklistBox.isEmpty) return '';

      final checklists =
          checklistBox.values.where((list) => list.isShown).toList();
      if (checklists.isEmpty) return '';

      List<String> result = [];
      for (var checklist in checklists) {
        if (checklist.items.isEmpty) continue;

        result.add("${checklist.name}:");
        for (var item in checklist.items) {
          result.add("- ${item.title}");
        }
      }

      return result.join('\n');
    } catch (e) {
      debugPrint('Error fetching checklist tasks: $e');
      return '';
    }
  }

  // Get formatted list of today's calendar items
  Future<String> _getTodaysCalendarItems() async {
    try {
      final now = DateTime.now();
      final calendarBox = Hive.box<AGiXTCalendar>('agixtCalendarBox');
      if (calendarBox.isEmpty) return '';

      final enabledCalendars =
          calendarBox.values.where((cal) => cal.enabled).toList();
      if (enabledCalendars.isEmpty) return '';

      final deviceCal = DeviceCalendarPlugin();
      List<String> calendarEvents = [];

      for (var calendar in enabledCalendars) {
        final events = await deviceCal.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(
            startDate: DateTime(now.year, now.month, now.day),
            endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
          ),
        );

        if (events.data != null && events.data!.isNotEmpty) {
          for (var event in events.data!) {
            if (event.start != null) {
              final start = event.start!.toLocal();
              final end = event.end?.toLocal();
              final timeStr =
                  end != null
                      ? "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}"
                      : "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";

              calendarEvents.add(
                "$timeStr ${event.title ?? 'Untitled event'}${event.location != null && event.location!.isNotEmpty ? ' at ${event.location}' : ''}",
              );
            }
          }
        }
      }

      // Sort events by time
      calendarEvents.sort();
      return calendarEvents.join('\n');
    } catch (e) {
      debugPrint('Error fetching calendar items: $e');
      return '';
    }
  }

  // Extract and manage the conversation ID from the URL
  Future<String> _getCurrentConversationId() async {
    try {
      // First check if we have a stored conversation ID
      final cookieManager = CookieManager();
      String? storedConversationId =
          await cookieManager.getAgixtConversationId();

      // Use "-" if we don't have one stored, instead of generating a new ID
      if (storedConversationId == null || storedConversationId.isEmpty) {
        await cookieManager.saveAgixtConversationId("-");
        debugPrint('Using default conversation ID: "-"');
        return "-";
      }

      return storedConversationId;
    } catch (e) {
      debugPrint('Error getting conversation ID: $e');
      // Return "-" as default if there's an error
      return "-";
    }
  }

  // Update the conversation ID when the URL changes
  Future<void> updateConversationIdFromUrl(String url) async {
    try {
      debugPrint('Updating conversation ID from URL: $url');

      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Check if the URL is '/chat' exactly (without a trailing segment)
      if (pathSegments.contains('chat') &&
          (pathSegments.length == 1 ||
              (pathSegments.length > 1 && pathSegments.last == 'chat'))) {
        debugPrint('URL is exactly /chat - setting conversation ID to "-"');
        final cookieManager = CookieManager();
        await cookieManager.saveAgixtConversationId("-");
        debugPrint('Set conversation ID to "-" for /chat URL');
      }
      // Check if the URL contains a chat path with conversation ID
      else if (url.contains('/chat/')) {
        // Extract the conversation ID from the URL
        final RegExp regExp = RegExp(r'/chat/([a-zA-Z0-9-_]+)');
        final match = regExp.firstMatch(url);

        if (match != null && match.groupCount >= 1) {
          final conversationId = match.group(1)!;

          debugPrint('Found conversation ID in URL pattern: $conversationId');

          // If we have a valid conversation ID, save it
          if (conversationId.isNotEmpty) {
            final cookieManager = CookieManager();
            await cookieManager.saveAgixtConversationId(conversationId);
            debugPrint('Updated conversation ID from URL: $conversationId');
          }
        } else {
          debugPrint(
            'No conversation ID found in URL pattern - ensuring default ID exists',
          );
          await _ensureConversationId();
        }
      } else {
        debugPrint(
          'URL does not contain /chat/ path - ensuring default ID exists',
        );
        await _ensureConversationId();
      }
    } catch (e) {
      debugPrint('Error updating conversation ID from URL: $e');
      // Ensure we still have a valid ID even if there was an error
      await _ensureConversationId();
    }
  }

  // Ensure a valid conversation ID exists
  Future<void> _ensureConversationId() async {
    try {
      final cookieManager = CookieManager();
      final existingId = await cookieManager.getAgixtConversationId();

      if (existingId == null || existingId.isEmpty || existingId == 'Not set') {
        // Use "-" instead of generating a new ID
        await cookieManager.saveAgixtConversationId("-");
        debugPrint('Set default conversation ID to "-"');
      } else {
        debugPrint('Using existing conversation ID: $existingId');
      }
    } catch (e) {
      debugPrint('Error ensuring conversation ID: $e');
    }
  }

  // Store the last interaction
  Future<void> _saveInteraction(String question, String answer) async {
    final payload = jsonEncode({
      'question': question,
      'answer': answer,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await _secureStorage.write(key: _interactionStorageKey, value: payload);

    // Remove legacy plaintext copies.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('agixt_last_question');
    await prefs.remove('agixt_last_answer');
    await prefs.remove('agixt_last_timestamp');
  }

  // Retrieve the last interaction if it exists and is not too old
  Future<ChatInteraction?> _getLastInteraction() async {
    try {
      final stored = await _secureStorage.read(key: _interactionStorageKey);
      Map<String, dynamic>? data;

      if (stored != null && stored.isNotEmpty) {
        data = jsonDecode(stored) as Map<String, dynamic>;
      } else {
        // Migrate legacy plaintext values if present.
        final prefs = await SharedPreferences.getInstance();
        final question = prefs.getString('agixt_last_question');
        final answer = prefs.getString('agixt_last_answer');
        final timestamp = prefs.getString('agixt_last_timestamp');
        if (question != null && answer != null && timestamp != null) {
          data = {
            'question': question,
            'answer': answer,
            'timestamp':
                DateTime.fromMillisecondsSinceEpoch(
                  int.parse(timestamp),
                ).toIso8601String(),
          };
          await _secureStorage.write(
            key: _interactionStorageKey,
            value: jsonEncode(data),
          );
          await prefs.remove('agixt_last_question');
          await prefs.remove('agixt_last_answer');
          await prefs.remove('agixt_last_timestamp');
        }
      }

      if (data == null) {
        return null;
      }

      final question = data['question'] as String?;
      final answer = data['answer'] as String?;
      final timestampRaw = data['timestamp'] as String?;

      if (question == null || answer == null || timestampRaw == null) {
        return null;
      }

      final interactionTime = DateTime.tryParse(timestampRaw);
      if (interactionTime == null) {
        return null;
      }

      if (DateTime.now().difference(interactionTime).inHours > 24) {
        return null;
      }

      return ChatInteraction(
        question: question,
        answer: answer,
        timestamp: interactionTime,
      );
    } catch (e) {
      debugPrint('Error reading last interaction: $e');
      return null;
    }
  }

  // Get user's location if enabled (with timeout for AI responses)
  Future<String> _getUserLocation() async {
    try {
      final locationService = LocationService();
      final bool isLocationEnabled = await locationService.isLocationEnabled();

      if (!isLocationEnabled) {
        return ''; // Location is disabled in settings
      }

      // Use a very short timeout (2 seconds) to prevent blocking AI responses
      // This is especially important when screen is locked or in background mode
      final currentPosition = await locationService.getCurrentPosition(
        timeout: const Duration(seconds: 2),
      );
      if (currentPosition != null) {
        return _formatLocationData(currentPosition);
      }

      // If current position is not available, try to get last known position
      final lastPosition = await locationService.getLastPosition();
      if (lastPosition.isNotEmpty) {
        final formattedCoordinates = LocationService.formatCoordinates(
          lastPosition['latitude'],
          lastPosition['longitude'],
        );

        List<String> locationInfo = [
          "Coordinates: $formattedCoordinates",
          "Latitude: ${lastPosition['latitude']}",
          "Longitude: ${lastPosition['longitude']}",
        ];

        if (lastPosition['altitude'] != null) {
          locationInfo.add(
            "Altitude: ${lastPosition['altitude'].toStringAsFixed(1)} m",
          );
        }

        if (lastPosition['timestamp'] != null) {
          locationInfo.add("Recorded: ${lastPosition['timestamp']}");
        }

        return locationInfo.join('\n');
      }

      return ''; // No location data available
    } catch (e) {
      debugPrint('Error getting location for context: $e');
      return ''; // Return empty string instead of blocking
    }
  }

  // Format position data into readable text
  String _formatLocationData(Position position) {
    final formattedCoordinates = LocationService.formatCoordinates(
      position.latitude,
      position.longitude,
    );

    return [
      "Coordinates: $formattedCoordinates",
      "Latitude: ${position.latitude}",
      "Longitude: ${position.longitude}",
      "Altitude: ${position.altitude.toStringAsFixed(1)} m",
      "Accuracy: ${position.accuracy.toStringAsFixed(1)} m",
      "Speed: ${position.speed.toStringAsFixed(1)} m/s",
      "Heading: ${position.heading.toStringAsFixed(1)}°",
    ].join('\n');
  }
}

// Simple class to store chat interactions
class ChatInteraction {
  final String question;
  final String answer;
  final DateTime timestamp;

  ChatInteraction({
    required this.question,
    required this.answer,
    required this.timestamp,
  });
}
