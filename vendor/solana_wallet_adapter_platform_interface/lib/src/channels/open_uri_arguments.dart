/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_common/models.dart';
import 'method_names.dart';


/// Open URI Arguments
/// ------------------------------------------------------------------------------------------------

/// The method call arguments for [MethodName.openUri].
class OpenUriArguments extends Serializable {

  /// Creates an `open uri` method call arguments object.
  const OpenUriArguments(
    this.uri, {
    this.target,
  });

  /// The url.
  final Uri uri;

  /// The browser window context.
  final String? target;

  /// {@macro solana_common.Serializable.fromJson}
  factory OpenUriArguments.fromJson(
    final Map<String, dynamic> json, 
  ) => OpenUriArguments(
    Uri.parse(json['uri']),
    target: json['target'],
  );

  @override
  Map<String, dynamic> toJson() => {
    'uri': uri.toString(),
    'target': target,
  };
}