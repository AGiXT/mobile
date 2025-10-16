import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:agixt/models/agixt/auth/auth.dart'; // Import AuthService to access getPrimaryAgentName

class CookieManager {
  static const String _agixtConversationKey = 'agixt_conversation_id';
  static const String _agixtAgentKey = 'agixt_agent_cookie';

  // Singleton instance
  static final CookieManager _instance = CookieManager._internal();

  factory CookieManager() {
    return _instance;
  }

  CookieManager._internal();

  // Save the conversation ID extracted from URL
  Future<void> saveAgixtConversationId(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_agixtConversationKey, conversationId);
      debugPrint('Saved agixt conversation ID: $conversationId');
    } catch (e) {
      debugPrint('Error saving agixt conversation ID: $e');
    }
  }

  // Retrieve the conversation ID
  Future<String?> getAgixtConversationId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_agixtConversationKey);
    } catch (e) {
      debugPrint('Error getting agixt conversation ID: $e');
      return null;
    }
  }

  // Clear the conversation ID
  Future<void> clearAgixtConversationId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_agixtConversationKey);
      debugPrint('Cleared agixt conversation ID');
    } catch (e) {
      debugPrint('Error clearing agixt conversation ID: $e');
    }
  }

  Future<void> clearAgixtAgentCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_agixtAgentKey);
      debugPrint('Cleared agixt-agent cookie');
    } catch (e) {
      debugPrint('Error clearing agixt-agent cookie: $e');
    }
  }

  // Save the agixt-agent cookie
  Future<void> saveAgixtAgentCookie(String cookieValue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_agixtAgentKey, cookieValue);
      debugPrint('Saved agixt-agent cookie: $cookieValue');
    } catch (e) {
      debugPrint('Error saving agixt-agent cookie: $e');
    }
  }

  // Retrieve the agixt-agent cookie
  Future<String?> getAgixtAgentCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedCookie = prefs.getString(_agixtAgentKey);

      // If cookie exists, return it
      if (storedCookie != null && storedCookie.isNotEmpty) {
        return storedCookie;
      }

      // If no cookie, try to get the primary agent name
      final primaryAgentName = await AuthService.getPrimaryAgentName();
      if (primaryAgentName != null && primaryAgentName.isNotEmpty) {
        // Save it as the cookie for future use
        await saveAgixtAgentCookie(primaryAgentName);
        debugPrint('Using primary agent as default: $primaryAgentName');
        return primaryAgentName;
      }

      // Fall back to default if nothing else available
      return null;
    } catch (e) {
      debugPrint('Error getting agixt-agent cookie: $e');
      return null;
    }
  }

  // Initialize agent cookie with primary agent if no cookie is set
  Future<void> initializeAgentCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedCookie = prefs.getString(_agixtAgentKey);

      // Only fetch primary agent if no cookie is set
      if (storedCookie == null || storedCookie.isEmpty) {
        final primaryAgentName = await AuthService.getPrimaryAgentName();
        if (primaryAgentName != null && primaryAgentName.isNotEmpty) {
          await saveAgixtAgentCookie(primaryAgentName);
          debugPrint(
            'Initialized agent cookie with primary agent: $primaryAgentName',
          );
        }
      }
    } catch (e) {
      debugPrint('Error initializing agent cookie: $e');
    }
  }
}
