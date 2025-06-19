// Models for AGiXT OAuth authentication
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
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

class OAuthService {
  // Deep link URI for the callback
  static const String DEEP_LINK_URI = 'agixt://callback';
  static final FlutterAppAuth _appAuth = FlutterAppAuth();

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

  // Perform OAuth authentication
  static Future<bool> authenticate(OAuthProvider provider) async {
    try {
      // Use a web-based redirect URI for the OAuth flow
      final redirectUri = '${AuthService.appUri}/user/mobile/${provider.name}';

      if (provider.pkceRequired) {
        // Handle PKCE flow
        final pkceResponse = await _appAuth.authorizeAndExchangeCode(
          AuthorizationTokenRequest(
            provider.clientId,
            redirectUri,
            serviceConfiguration: AuthorizationServiceConfiguration(
              authorizationEndpoint: provider.authorize,
              tokenEndpoint: '${AuthService.serverUrl}/v1/oauth/token',
            ),
            scopes: provider.scopes.split(' '),
          ),
        );

        if (pkceResponse?.accessToken != null) {
          await AuthService.storeJwt(pkceResponse!.accessToken!);
          return true;
        }
      } else {
        // Launch browser for standard OAuth
        final loginUrl = Uri.parse(
            '${provider.authorize}?client_id=${provider.clientId}&redirect_uri=${Uri.encodeComponent(redirectUri)}&response_type=code&scope=${Uri.encodeComponent(provider.scopes)}');

        if (await canLaunchUrl(loginUrl)) {
          await launchUrl(loginUrl, mode: LaunchMode.externalApplication);
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('OAuth error: $e');
      return false;
    }
  }
}
