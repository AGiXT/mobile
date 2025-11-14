import 'dart:io';

/// Provides common URL sanitization utilities for enforcing secure network
/// access patterns across the app.
class UrlSecurity {
  const UrlSecurity._();

  /// Normalizes the provided [rawUrl] and enforces scheme restrictions.
  ///
  /// - Ensures the URL is absolute and has a host.
  /// - Strips query and fragment components.
  /// - Trims trailing slashes from the path.
  /// - Rejects insecure schemes unless [allowHttpOnLocalhost] is true and the
  ///   host is a loopback or private network address.
  static String sanitizeBaseUrl(
    String rawUrl, {
    bool allowHttpOnLocalhost = false,
  }) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('URL must not be empty.');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('Provide a valid absolute URL.');
    }

    final isLocal = _isPermittedLocalHost(uri.host);
    final allowedSchemes = <String>{'https'};
    if (allowHttpOnLocalhost && isLocal) {
      allowedSchemes.add('http');
    }

    if (!allowedSchemes.contains(uri.scheme)) {
      throw const FormatException(
        'Only HTTPS endpoints are permitted (HTTP allowed on localhost).',
      );
    }

    final sanitizedPath =
        uri.path.isEmpty ? '' : uri.path.replaceAll(RegExp(r'/+$'), '');

    final normalized = uri.replace(
      path: sanitizedPath,
      query: '',
      fragment: '',
    );

    return normalized.toString();
  }

  /// Builds a websocket URI from the provided [base] while normalizing the path
  /// and query parameters.
  static Uri buildWebSocketUri(
    Uri base, {
    required String path,
    Map<String, String>? queryParameters,
  }) {
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final fullPath = joinPaths(base.path, path);
    return base.replace(
      scheme: scheme,
      path: fullPath,
      queryParameters: queryParameters,
    );
  }

  /// Safely joins two path segments, preventing accidental duplicate slashes.
  static String joinPaths(String basePath, String additionalPath) {
    final normalizedBase =
        basePath.isEmpty ? '' : basePath.replaceAll(RegExp(r'/+$'), '');
    final normalizedAdditional = additionalPath.startsWith('/')
        ? additionalPath.substring(1)
        : additionalPath;

    if (normalizedBase.isEmpty) {
      return '/$normalizedAdditional';
    }

    final prefix =
        normalizedBase.startsWith('/') ? normalizedBase : '/$normalizedBase';

    if (normalizedAdditional.isEmpty) {
      return prefix;
    }

    return '$prefix/$normalizedAdditional';
  }

  static bool _isPermittedLocalHost(String host) {
    if (host == 'localhost' || host == '::1') {
      return true;
    }

    final parsedAddress = InternetAddress.tryParse(host);
    if (parsedAddress == null) {
      return false;
    }

    if (parsedAddress.isLoopback) {
      return true;
    }

    if (parsedAddress.type == InternetAddressType.IPv4) {
      final raw = parsedAddress.rawAddress;
      if (raw.length == 4) {
        final o1 = raw[0];
        final o2 = raw[1];
        if (o1 == 10) {
          return true;
        }
        if (o1 == 172 && o2 >= 16 && o2 <= 31) {
          return true;
        }
        if (o1 == 192 && o2 == 168) {
          return true;
        }
      }
    }

    return false;
  }
}
