// Models for AGiXT OAuth authentication
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth.dart';

class OAuthProvider {
  final String name;
  final String scopes;
  final String authorize;
  final String clientId;
  final bool pkceRequired;
  final String? iconName;

  OAuthProvider({
    required this.name,
    required this.scopes,
    required this.authorize,
    required this.clientId,
    required this.pkceRequired,
    this.iconName,
  });

  factory OAuthProvider.fromJson(Map<String, dynamic> json) {
    return OAuthProvider(
      name: json['name'],
      scopes: json['scopes'],
      authorize: json['authorize'],
      clientId: json['client_id'],
      pkceRequired: json['pkce_required'],
      iconName: json['name'].toLowerCase(),
    );
  }
}

enum OAuthFlowStatus { completed, launched, failed }

class OAuthFlowResult {
  const OAuthFlowResult(this.status, {this.message});

  final OAuthFlowStatus status;
  final String? message;

  bool get isSuccess => status == OAuthFlowStatus.completed;
}

class OAuthService {
  // Deep link URI for the callback - the app receives the JWT here
  static const String DEEP_LINK_URI = 'agixt://callback';

  // Fetch available OAuth providers
  static Future<List<OAuthProvider>> getProviders() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.serverUrl}/v1/oauth'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> providersList = data['providers'] ?? [];

        return providersList
            .map((providerJson) => OAuthProvider.fromJson(providerJson))
            .where((provider) => provider.clientId.isNotEmpty)
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error loading OAuth providers: $e');
      return [];
    }
  }

  // Perform OAuth authentication via AGiXT web app
  // Flow:
  // 1. App opens AGiXT web app's OAuth login page with mobile callback parameter
  // 2. Web app handles OAuth flow with the provider
  // 3. Web app redirects to agixt://callback?token={jwt} after successful login
  // 4. App receives deep link and stores the JWT
  static Future<OAuthFlowResult> authenticate(OAuthProvider provider) async {
    try {
      // Build the web app OAuth URL with mobile callback
      // The web app at /user/{provider} will handle the OAuth flow
      // and redirect back to agixt://callback?token={jwt} when complete
      final loginUrl = Uri.parse(AuthService.appUri).replace(
        path: '/user/${provider.name}',
        queryParameters: {
          'mobile_callback': DEEP_LINK_URI,
        },
      );

      debugPrint('OAuth: Opening ${provider.name} via web app');
      debugPrint('OAuth: URL = $loginUrl');

      if (await canLaunchUrl(loginUrl)) {
        final launched = await launchUrl(
          loginUrl,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          // The web app will handle OAuth and redirect back with token
          // The app will receive the token via deep link (handled in main.dart)
          return const OAuthFlowResult(OAuthFlowStatus.launched);
        }
        return const OAuthFlowResult(
          OAuthFlowStatus.failed,
          message: 'Unable to open the login page in a browser.',
        );
      }

      return const OAuthFlowResult(
        OAuthFlowStatus.failed,
        message: 'The login URL could not be opened.',
      );
    } catch (e) {
      debugPrint('OAuth error: $e');
      return OAuthFlowResult(OAuthFlowStatus.failed, message: e.toString());
    }
  }
}
