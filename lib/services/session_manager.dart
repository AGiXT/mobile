import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/screens/home_screen.dart';
import 'package:agixt/services/cookie_manager.dart' as local_cookie;
import 'package:agixt/services/secure_storage_service.dart';

class SessionManager {
  SessionManager._();

  static final local_cookie.CookieManager _cookieManager =
      local_cookie.CookieManager();
  static final WebViewCookieManager _webViewCookieManager =
      WebViewCookieManager();
  static final SecureStorageService _secureStorage = SecureStorageService();

  static Future<void> clearSession({bool clearWebCookies = true}) async {
    try {
      await AuthService.logout();
    } catch (e) {
      debugPrint('Error logging out: $e');
    }

    try {
      await _cookieManager.clearAgixtConversationId();
    } catch (e) {
      debugPrint('Error clearing conversation ID: $e');
    }

    try {
      await _cookieManager.clearAgixtAgentCookie();
    } catch (e) {
      debugPrint('Error clearing agent cookie: $e');
    }

    try {
      await _secureStorage.delete(key: 'agixt_last_interaction_v1');
    } catch (e) {
      debugPrint('Error clearing cached chat history: $e');
    }

    try {
      await _secureStorage.delete(key: 'last_location_payload_v1');
    } catch (e) {
      debugPrint('Error clearing cached location data: $e');
    }

    if (clearWebCookies) {
      try {
        await _webViewCookieManager.clearCookies();
      } catch (e) {
        debugPrint('Error clearing WebView cookies: $e');
      }
    }

    try {
      HomePage.webViewController?.clearCache();
    } catch (e) {
      debugPrint('Error clearing WebView cache: $e');
    }
  }
}
