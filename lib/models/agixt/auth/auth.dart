// Models for AGiXT authentication
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String timezone;
  final String phoneNumber;
  final List<CompanyModel> companies;
  final String inputTokens;
  final String outputTokens;
  final String? agentId;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.timezone,
    this.phoneNumber = '',
    required this.companies,
    required this.inputTokens,
    required this.outputTokens,
    this.agentId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      timezone: json['timezone'] ?? 'UTC',
      phoneNumber: json['phone_number'] ?? '',
      companies: (json['companies'] as List<dynamic>?)
              ?.map((company) => CompanyModel.fromJson(company))
              .toList() ??
          [],
      inputTokens: json['input_tokens'] ?? '0',
      outputTokens: json['output_tokens'] ?? '0',
      agentId: json['agent_id'],
    );
  }
}

class CompanyModel {
  final String id;
  final String name;
  final String agentName;
  final String? trainingData;
  final int roleId;
  final bool primary;
  final List<AgentModel> agents;

  CompanyModel({
    required this.id,
    required this.name,
    required this.agentName,
    this.trainingData,
    required this.roleId,
    required this.primary,
    required this.agents,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      agentName: json['agent_name'] ?? '',
      trainingData: json['training_data'],
      roleId: json['role_id'] ?? 0,
      primary: json['primary'] ?? false,
      agents: (json['agents'] as List<dynamic>?)
              ?.map((agent) => AgentModel.fromJson(agent))
              .toList() ??
          [],
    );
  }
}

class AgentModel {
  final String id;
  final String name;
  final bool status;
  final String companyId;

  AgentModel({
    required this.id,
    required this.name,
    required this.status,
    required this.companyId,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? false,
      companyId: json['company_id'] ?? '',
    );
  }
}

class AuthModel {
  final String email;
  final String token;

  AuthModel({
    required this.email,
    required this.token,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'token': token,
      };
}

class AuthService {
  static const String JWT_KEY = 'jwt_token';
  static const String EMAIL_KEY = 'user_email';
  static const String COOKIE_AUTH_KEY = 'cookie_authenticated';
  static String? _serverUrl;
  static String? _appUri;
  static String? _appName;

  // Initialize with environment variables
  static void init(
      {required String serverUrl,
      required String appUri,
      required String appName}) {
    _serverUrl = serverUrl;
    _appUri = appUri;
    _appName = appName;
  }

  static String get serverUrl => _serverUrl ?? 'https://api.agixt.dev';
  static String get appUri => _appUri ?? 'https://agixt.dev';
  static String get appName => _appName ?? 'AGiXT';

  // Store JWT token
  static Future<void> storeJwt(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(JWT_KEY, token);
    } catch (e) {
      debugPrint('Error storing JWT token: $e');
      rethrow;
    }
  }

  // Store user email
  static Future<void> storeEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(EMAIL_KEY, email);
    } catch (e) {
      debugPrint('Error storing email: $e');
      rethrow;
    }
  }

  // Get stored JWT token
  static Future<String?> getJwt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(JWT_KEY);
    } catch (e) {
      debugPrint('Error getting JWT token: $e');
      return null;
    }
  }

  // Get stored email
  static Future<String?> getEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(EMAIL_KEY);
    } catch (e) {
      debugPrint('Error getting email: $e');
      return null;
    }
  }

  // Clear stored JWT token and email (logout)
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(JWT_KEY);
      await prefs.remove(EMAIL_KEY);
      await prefs.remove(COOKIE_AUTH_KEY);
    } catch (e) {
      debugPrint('Error during logout: $e');
      rethrow;
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      final jwt = await getJwt();
      if (jwt != null && jwt.isNotEmpty) return true;

      // Also check if we have cookie-based authentication
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(COOKIE_AUTH_KEY) ?? false;
    } catch (e) {
      debugPrint('Error checking login status: $e');
      return false;
    }
  }

  // Mark user as authenticated via cookies (OAuth web flow)
  static Future<void> setCookieAuthenticated(bool authenticated) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (authenticated) {
        await prefs.setBool(COOKIE_AUTH_KEY, true);
      } else {
        await prefs.remove(COOKIE_AUTH_KEY);
      }
    } catch (e) {
      debugPrint('Error setting cookie auth status: $e');
    }
  }

  // Check if we have cookie-based auth (vs JWT)
  static Future<bool> isCookieAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(COOKIE_AUTH_KEY) ?? false;
    } catch (e) {
      debugPrint('Error checking cookie auth status: $e');
      return false;
    }
  }

  // Login with email and MFA token
  static Future<String?> login(String email, String mfaCode) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/v1/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'token': mfaCode,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        String? jwt;

        // Handle response as string (magic link with token)
        if (responseBody is String) {
          final loginUrl = responseBody;
          // Extract JWT from URL format "Log in at ?token=xyz"
          if (loginUrl.contains('?token=')) {
            final parts = loginUrl.split('?token=');
            if (parts.length > 1) {
              jwt = parts[1].trim();
            }
          }
        }
        // Handle response with 'detail' field containing the URL with token
        else if (responseBody is Map<String, dynamic> &&
            responseBody.containsKey('detail')) {
          final loginUrl = responseBody['detail'];
          if (loginUrl is String && loginUrl.contains('?token=')) {
            final parts = loginUrl.split('?token=');
            if (parts.length > 1) {
              jwt = parts[1].trim();
            }
          }
        }
        // Handle response as object with token field
        else if (responseBody is Map<String, dynamic> &&
            responseBody.containsKey('token')) {
          jwt = responseBody['token'];
          // Remove 'Bearer ' prefix if present
          if (jwt != null && jwt.startsWith('Bearer ')) {
            jwt = jwt.substring(7);
          }
        }

        if (jwt != null && jwt.isNotEmpty) {
          await storeJwt(jwt);
          await storeEmail(email);
          return jwt;
        } else {
          // 200 status code but couldn't extract JWT
          debugPrint(
              'Login successful but couldn\'t extract JWT token from response: $responseBody');
          return null;
        }
      } else if (response.statusCode == 401) {
        debugPrint('Login failed: Unauthorized (401) - Invalid credentials');
        return null;
      } else {
        debugPrint(
            'Login failed: ${response.statusCode} - ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return null;
    }
  }

  // Get the web URL with token for opening in browser
  static Future<String> getWebUrlWithToken() async {
    final jwt = await getJwt();
    // If we have a JWT, append it; otherwise just return the base URL
    // (for cookie-based auth, the WebView cookies will handle authentication)
    if (jwt != null && jwt.isNotEmpty) {
      return '$appUri?token=$jwt';
    }
    return appUri;
  }

  // Fetch user information from the server
  static Future<UserModel?> getUserInfo() async {
    try {
      final jwt = await getJwt();

      if (jwt == null || jwt.isEmpty) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$serverUrl/v1/user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> userData = jsonDecode(response.body);
        return UserModel.fromJson(userData);
      } else {
        debugPrint('Failed to get user info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching user info: $e');
      return null;
    }
  }

  // Get primary agent name from user info
  static Future<String?> getPrimaryAgentName() async {
    try {
      // First check if we're logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        return null;
      }

      // Get user info
      final userInfo = await getUserInfo();
      if (userInfo == null) {
        return null;
      }

      // Find the primary company
      CompanyModel? primaryCompany;
      try {
        primaryCompany =
            userInfo.companies.firstWhere((company) => company.primary);
      } catch (e) {
        // No primary company found, try to use the first one if available
        if (userInfo.companies.isNotEmpty) {
          primaryCompany = userInfo.companies.first;
        }
      }

      if (primaryCompany != null) {
        // Return the agent name from the primary company
        debugPrint(
            'Found primary company: ${primaryCompany.name} with agent: ${primaryCompany.agentName}');
        return primaryCompany.agentName;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting primary agent name: $e');
      return null;
    }
  }

  // Get preference for displaying Even Realities glasses
  static Future<bool> getGlassesDisplayPreference() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      // Default is true (enabled) if preference doesn't exist
      return prefs.getBool('display_glasses_enabled') ?? true;
    } catch (e) {
      debugPrint('Error getting glasses display preference: $e');
      // Default to true if there's an error
      return true;
    }
  }

  // Save preference for displaying Even Realities glasses
  static Future<void> setGlassesDisplayPreference(bool value) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('display_glasses_enabled', value);
    } catch (e) {
      debugPrint('Error saving glasses display preference: $e');
    }
  }
}
