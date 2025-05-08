import 'dart:convert';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/agixt/calendar.dart';
import 'package:agixt/models/agixt/checklist.dart';
import 'package:agixt/models/agixt/daily.dart';
import 'package:agixt/models/agixt/widgets/agixt_widget.dart';
import 'package:agixt/models/g1/note.dart';
import 'package:agixt/services/cookie_manager.dart';
import 'package:agixt/utils/app_events.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AGiXTChatWidget implements AGiXTWidget {
  static const String DEFAULT_MODEL = "XT";
  static const int DEFAULT_PRIORITY = 1;

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
      )
    ];
  }

  // Send a message to the AGiXT chat completions API
  Future<String?> sendChatMessage(String message) async {
    try {
      final jwt = await AuthService.getJwt();
      if (jwt == null) {
        return "Please login to use AGiXT chat.";
      }

      // Get the current URL to extract conversation ID
      final conversationId = await _getCurrentConversationId();

      debugPrint('Using conversation ID: $conversationId');

      // Create chat request with context if available
      String finalMessage = message;
      final contextData = await _buildContextData();
      if (contextData.isNotEmpty) {
        debugPrint('Adding context data to user message');
      }

      final Map<String, dynamic> requestBody = {
        "model": await _getAgentName(),
        "messages": [
          {
            "role": "user", 
            "content": message,
            if (contextData.isNotEmpty) "context": contextData
          }
        ],
        "user": conversationId // Use the conversation ID from URL for the user field
      };

      // Send request to AGiXT API
      final response = await http.post(
        Uri.parse('${AuthService.serverUrl}/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': jwt,
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
            debugPrint('Extracted conversation ID from response: $responseId');
            
            // Save the conversation ID
            final cookieManager = CookieManager();
            await cookieManager.saveAgixtConversationId(responseId.toString());
            
            // Notify any listeners that we need to navigate to the chat page
            // This will be picked up by the AppEvents system
            AppEvents.fireDataChanged(data: {'type': 'navigate', 'conversation_id': responseId.toString()});
            
            // Prepare the navigation URL for the WebView
            final appUri = AuthService.serverUrl;
            debugPrint('Will navigate to: $appUri/chat/$responseId');
            // Wait 1 second to ensure the WebView is ready
            await Future.delayed(const Duration(seconds: 1));
            // Use JavaScript to navigate the WebView if possible
            _navigateWebViewToChat(responseId.toString());
          }

          // Save this interaction for future reference
          await _saveInteraction(message, answer);

          return answer;
        }
      } else if (response.statusCode == 401) {
        // JWT may be expired
        await AuthService.logout();
        return "Authentication expired. Please login again.";
      }

      return "Sorry, I couldn't get a response at this time.";
    } catch (e) {
      debugPrint('AGiXT Chat error: $e');
      return "An error occurred while connecting to AGiXT.";
    }
  }
  
  // Method to navigate the WebView to the chat page with the given ID
  void _navigateWebViewToChat(String conversationId, {Map<String, dynamic>? additionalParams}) {
    // This method doesn't directly manipulate the WebView
    // Instead, it triggers an event that will be picked up by the HomePage
    // which manages the WebView
    final eventData = {
      'type': 'navigate_to_chat',
      'conversation_id': conversationId,
      ...?additionalParams, // Merge additional parameters if provided
    };
    AppEvents.fireDataChanged(data: eventData);
  }

  // Build context data containing today's daily items, active checklists, and calendar items
  Future<String> _buildContextData() async {
    List<String> contextSections = [];
    contextSections.add("The users message is transcribed from voice to text.");

    // Get today's daily items
    final dailyItems = await _getTodaysDailyItems();
    if (dailyItems.isNotEmpty) {
      contextSections.add("### Users items for today\n\n$dailyItems");
    }

    // Get user's current active checklist tasks
    final currentTasks = await _getCurrentChecklistTasks();
    if (currentTasks.isNotEmpty) {
      contextSections.add("### Users current task\n\n$currentTasks");
    }

    // Get today's calendar items
    final calendarItems = await _getTodaysCalendarItems();
    if (calendarItems.isNotEmpty) {
      contextSections.add("### Users calendar items for today\n\n$calendarItems");
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
        return TimeOfDay(hour: a.hour!, minute: a.minute!)
            .compareTo(TimeOfDay(hour: b.hour!, minute: b.minute!));
      });

      return items.map((item) => 
        "${item.hour?.toString().padLeft(2, '0') ?? '--'}:${item.minute?.toString().padLeft(2, '0') ?? '--'} ${item.title}"
      ).join('\n');
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

      final checklists = checklistBox.values.where((list) => list.isShown).toList();
      if (checklists.isEmpty) return '';

      List<String> result = [];
      for (var checklist in checklists) {
        if (checklist.items.isEmpty) continue;
        
        result.add("${checklist.name}:");
        checklist.items.forEach((item) {
          result.add("- ${item.title}");
        });
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

      final enabledCalendars = calendarBox.values.where((cal) => cal.enabled).toList();
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
              final timeStr = end != null 
                ? "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}"
                : "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
              
              calendarEvents.add("$timeStr ${event.title ?? 'Untitled event'}${event.location != null && event.location!.isNotEmpty ? ' at ${event.location}' : ''}");
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
      String? storedConversationId = await cookieManager.getAgixtConversationId();
      
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
  
  // Generate a default conversation ID (now just returns "-")
  String _generateConversationId() {
    // No longer generating random IDs
    return "-";
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
          debugPrint('No conversation ID found in URL pattern - ensuring default ID exists');
          await _ensureConversationId();
        }
      } else {
        debugPrint('URL does not contain /chat/ path - ensuring default ID exists');
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agixt_last_question', question);
    await prefs.setString('agixt_last_answer', answer);
    await prefs.setString('agixt_last_timestamp',
        DateTime.now().millisecondsSinceEpoch.toString());
  }

  // Retrieve the last interaction if it exists and is not too old
  Future<ChatInteraction?> _getLastInteraction() async {
    final prefs = await SharedPreferences.getInstance();
    final question = prefs.getString('agixt_last_question');
    final answer = prefs.getString('agixt_last_answer');
    final timestamp = prefs.getString('agixt_last_timestamp');

    if (question == null || answer == null || timestamp == null) {
      return null;
    }

    // Check if the interaction is from the last 24 hours
    final interactionTime =
        DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
    final now = DateTime.now();
    if (now.difference(interactionTime).inHours > 24) {
      return null; // Interaction is too old
    }

    return ChatInteraction(
        question: question, answer: answer, timestamp: interactionTime);
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
