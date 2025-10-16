/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:math' as math show Random;
import '../../types.dart';
import '../exceptions/solana_wallet_adapter_exception.dart';

/// Association Types
/// ------------------------------------------------------------------------------------------------

enum AssociationType {
  local,
  remote,
  ;
}

/// Association
/// ------------------------------------------------------------------------------------------------

abstract class Association {
  /// Creates an [Association] for [type] to construct endpoint [Uri]s.
  const Association(this.type);

  /// The type of association.
  final AssociationType type;

  /// The default mobile wallet adapter protocol scheme.
  static const String scheme = 'solana-wallet';

  /// The default mobile wallet adapter protocol [scheme].
  static Uri get schemeUri => Uri.parse('$scheme:/');

  /// The base path of the URI.
  static const String pathPrefix = 'v1/associate';

  /// The association token query parameter key (`[associationParameterKey]=<association_token>`).
  static const String associationParameterKey = 'association';

  /// Generates a random non-negative integer between [minValue] and [maxValue] (inclusive).
  ///
  /// ```
  /// final int value = Association.randomValue(minValue: 10, maxValue: 20);
  /// print(value); // 10 ≤ value ≤ 20
  /// ```
  static int randomValue(
      {final int minValue = 0, required final int maxValue}) {
    assert(minValue >= 0);
    assert(minValue <= maxValue);
    final int rangeLength = maxValue - minValue + 1;
    return minValue + math.Random().nextInt(rangeLength);
  }

  /// Creates a new [Uri] that's used to connect a dApp endpoint to a wallet endpoint.
  Uri walletUri(
    final AssociationToken associationToken, {
    final Uri? uriPrefix,
  });

  /// Creates a new [Uri] that's used to establish a secure web socket connection between a dApp and
  /// wallet endpoint.
  Uri sessionUri();

  /// Creates a new [Uri] for [scheme] or [uriPrefix], using the provided [associationToken] and
  /// [queryParameters].
  ///
  /// If provided, [uriPrefix] must have a `HTTPS` scheme (for security reasons, a dApp should
  /// reject a [uriPrefix] with schemes other than https).
  Uri endpointUri(
    final AssociationToken associationToken, {
    required final Map<String, String> queryParameters,
    final Uri? uriPrefix,
  }) {
    _checkUri(uriPrefix);
    final String base = uriPrefix?.toString() ?? schemeUri.toString();
    final String path = '$pathPrefix/${type.name}';
    queryParameters.addAll({associationParameterKey: associationToken});
    return _buildUri(base: base, path: path)
        .replace(queryParameters: queryParameters);
  }

  /// Creates a uri from [base] and [path].
  Uri _buildUri({required final String base, required final String path}) {
    assert(!path.startsWith('/'));
    return Uri.parse(base.endsWith('/') ? '$base$path' : '$base/$path');
  }

  /// Throws a [SolanaWalletAdapterException] if [uriPrefix] is invalid.
  void _checkUri(final Uri? uriPrefix) {
    if (uriPrefix == null) {
      return;
    }

    if (uriPrefix.isScheme('HTTPS')) {
      return;
    }

    final String scheme = uriPrefix.scheme.toLowerCase();
    const Set<String> allowedSchemes = {
      'solana-wallet',
      'solanamobilesdk',
      'solana-mobile',
      'solanamobile',
      'sms',
    };

    if (allowedSchemes.contains(scheme)) {
      return;
    }

    throw SolanaWalletAdapterException(
      'A wallet base uri prefix must start with "https://"',
      code: SolanaWalletAdapterExceptionCode.forbiddenWalletBaseUri,
    );
  }
}
