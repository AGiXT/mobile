/// Imports
/// ------------------------------------------------------------------------------------------------

import '../../types.dart';
import 'association.dart';


/// Local Association
/// ------------------------------------------------------------------------------------------------

class LocalAssociation extends Association {

  /// Creates an [Association] to construct `local` endpoint [Uri]s.
  LocalAssociation({
    final int? port,
  }): port = port ?? Association.randomValue(minValue: minPort, maxValue: maxPort),
      super(AssociationType.local);

  /// The local port number.
  final int port;

  /// The minimum port number for local association URIs.
  static const int minPort = 49152;

  /// The maximum port number for local association URIs.
  static const int maxPort = 65535;

  @override
  Uri walletUri(
    final AssociationToken associationToken, { 
    final Uri? uriPrefix,
  }) => endpointUri(
    associationToken,
    uriPrefix: uriPrefix,
    queryParameters: { 'port': '$port' }
  );
  
  @override
  Uri sessionUri() => Uri.parse('ws://localhost:$port/solana-wallet');
}