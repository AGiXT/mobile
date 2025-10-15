/// Imports
/// ------------------------------------------------------------------------------------------------

import '../../types.dart';
import 'association.dart';


/// Remote Association
/// ------------------------------------------------------------------------------------------------

class RemoteAssociation extends Association {

  /// Creates an [Association] to construct `remote` endpoint [Uri]s.
  RemoteAssociation({
    required this.hostAuthority,
    final int? id,
  }): id = Association.randomValue(minValue: minId, maxValue: maxId),
      super(AssociationType.remote);

  /// The address of a publicly routable web socket server implementing the reflector protocol.
  final String hostAuthority;

  /// The reflector's randomly generated unique id.
  final int id;

  /// The minimum reflector [id].
  static const int minId = 1;

  /// The maximum reflector [id] (2^32)
  /// TODO: The specification says 2^53-1, but this throws an error saying <= 2^32.
  static const int maxId = 0xFFFFFFFF; // 9007199254740991

  @override
  Uri walletUri(
    final AssociationToken associationToken, { 
    final Uri? uriPrefix,
  }) => endpointUri(
    associationToken,
    uriPrefix: uriPrefix,
    queryParameters: {
      'reflector': hostAuthority,
      'id': '$id',
    }
  );
  
  @override
  Uri sessionUri() => Uri.parse('wss://$hostAuthority/reflect?id=$id');
}