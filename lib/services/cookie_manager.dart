import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CookieManager {
  static const String _agixtConversationKey = 'agixt_conversation_id';
  static const String _agixtAgentKey = 'agixt_agent_cookie';
  static const String _jwtCookieKey = 'jwt_cookie';

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
      return prefs.getString(_agixtAgentKey);
    } catch (e) {
      debugPrint('Error getting agixt-agent cookie: $e');
      return null;
    }
  }
  
  // Save the JWT cookie
  Future<void> saveJwtCookie(String jwtValue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_jwtCookieKey, jwtValue);
      debugPrint('Saved JWT cookie: ${jwtValue.substring(0, 20)}...');
    } catch (e) {
      debugPrint('Error saving JWT cookie: $e');
    }
  }
  
  // Retrieve the JWT cookie
  Future<String?> getJwtCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_jwtCookieKey);
    } catch (e) {
      debugPrint('Error getting JWT cookie: $e');
      return null;
    }
  }
  
  // Clear the JWT cookie
  Future<void> clearJwtCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_jwtCookieKey);
      debugPrint('Cleared JWT cookie');
    } catch (e) {
      debugPrint('Error clearing JWT cookie: $e');
    }
  }
}
