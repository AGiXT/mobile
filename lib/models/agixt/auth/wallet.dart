import 'dart:convert';

import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WalletProvider {
  WalletProvider({
    required this.id,
    required this.name,
    required this.chains,
    required this.primaryChain,
    required this.icon,
  });

  final String id;
  final String name;
  final List<String> chains;
  final String primaryChain;
  final String icon;

  bool supportsChain(String chain) =>
      chains.map((value) => value.toLowerCase()).contains(chain.toLowerCase());

  factory WalletProvider.fromJson(String id, Map<String, dynamic> json) {
    final List<dynamic> chains =
        json['chains'] is List ? json['chains'] : const [];
    return WalletProvider(
      id: id,
      name: json['name'] ?? id,
      chains: chains.cast<String>(),
      primaryChain: (json['primary_chain'] ?? 'solana').toString(),
      icon: json['icon']?.toString() ?? id,
    );
  }
}

class WalletNonce {
  const WalletNonce({
    required this.nonce,
    required this.message,
    this.timestamp,
  });

  final String nonce;
  final String message;
  final String? timestamp;

  factory WalletNonce.fromJson(Map<String, dynamic> json) => WalletNonce(
    nonce: json['nonce']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    timestamp: json['timestamp']?.toString(),
  );
}

class WalletAuthResult {
  WalletAuthResult(this.raw);

  final Map<String, dynamic> raw;

  String? get _tokenField {
    final token = raw['token'];
    if (token is String && token.isNotEmpty) {
      return token.startsWith('Bearer ') ? token.substring(7) : token;
    }
    return null;
  }

  String? get _detailField => raw['detail'] as String?;

  /// Attempts to resolve the JWT token returned by the wallet verification endpoint.
  String? get jwtToken {
    final direct = _tokenField;
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final detail = _detailField;
    if (detail == null || detail.isEmpty) {
      return null;
    }

    final Uri? detailUri = Uri.tryParse(detail);
    if (detailUri != null) {
      final tokenParam = detailUri.queryParameters['token'];
      if (tokenParam != null && tokenParam.isNotEmpty) {
        return tokenParam;
      }
    }

    if (detail.contains('token=')) {
      final tokenPart = detail.split('token=').last;
      final tokenCandidate = tokenPart.split('&').first.trim();
      if (tokenCandidate.isNotEmpty) {
        return tokenCandidate;
      }
    }

    return null;
  }

  String? get email {
    final value = raw['email'];
    return value is String && value.isNotEmpty ? value : null;
  }

  bool get isWalletLinked => raw['connected'] == true;
}

class WalletAuthService {
  const WalletAuthService._();

  static Uri _buildUri(String path) =>
      Uri.parse('${AuthService.serverUrl}$path');

  static Future<List<WalletProvider>> getProviders() async {
    try {
      final response = await http.get(_buildUri('/v1/wallet/providers'));
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load wallet providers (${response.statusCode})',
        );
      }

      final decoded = jsonDecode(response.body);
      final Map<String, dynamic> providersJson =
          decoded is Map<String, dynamic> &&
                  decoded['providers'] is Map<String, dynamic>
              ? decoded['providers'] as Map<String, dynamic>
              : {};

      return providersJson.entries
          .map((entry) => WalletProvider.fromJson(entry.key, entry.value))
          .toList();
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch wallet providers: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<WalletNonce> requestNonce({
    required String walletAddress,
    required String chain,
  }) async {
    try {
      final response = await http.post(
        _buildUri('/v1/wallet/nonce'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'wallet_address': walletAddress, 'chain': chain}),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch wallet nonce (${response.statusCode})',
        );
      }

      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      return WalletNonce.fromJson(decoded);
    } catch (error, stackTrace) {
      debugPrint('Failed to request wallet nonce: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<WalletAuthResult> verifySignature({
    required String walletAddress,
    required String signature,
    required String message,
    required String nonce,
    required String walletType,
    required String chain,
    String? referrer,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final jwt = await AuthService.getJwt();
    if (jwt != null && jwt.isNotEmpty) {
      headers['Authorization'] = 'Bearer $jwt';
    }

    final payload = {
      'wallet_address': walletAddress,
      'signature': signature,
      'message': message,
      'nonce': nonce,
      'wallet_type': walletType,
      'chain': chain,
      if (referrer != null) 'referrer': referrer,
    };

    debugPrint('WalletAuthService: Sending verification request to ${_buildUri('/v1/wallet/verify')}');
    debugPrint('WalletAuthService: Payload: ${jsonEncode(payload)}');

    try {
      final response = await http.post(
        _buildUri('/v1/wallet/verify'),
        headers: headers,
        body: jsonEncode(payload),
      );

      debugPrint('WalletAuthService: Response status: ${response.statusCode}');
      debugPrint('WalletAuthService: Response body: ${response.body}');

      if (response.statusCode >= 400) {
        String message = 'Wallet verification failed (${response.statusCode})';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
            message = decoded['detail'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return WalletAuthResult(decoded);
      }

      if (decoded is String) {
        return WalletAuthResult({'detail': decoded});
      }

      return WalletAuthResult(const {});
    } catch (error, stackTrace) {
      debugPrint('Wallet signature verification failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }
}
