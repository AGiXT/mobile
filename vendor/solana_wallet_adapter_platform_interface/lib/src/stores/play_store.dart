/// Imports
/// ------------------------------------------------------------------------------------------------

import 'app_info.dart';
import 'store_info.dart';


/// Play Store
/// ------------------------------------------------------------------------------------------------

/// Android Play Store helper methods.
class PlayStore extends StoreInfo {
  
  /// Creates an instance of [PlayStore].
  const PlayStore._(): super('android');

  /// An instance of [PlayStore].
  static PlayStore get instance => const PlayStore._();
  
  @override
  List<AppInfo> get apps => const [ // Android Play Store ids.
    PhantomAppInfo(
      id: 'app.phantom',
    ),
    SolflareAppInfo(
      id: 'com.solflare.mobile',
    ),
  ];

  @override
  Uri uri(final AppInfo info) 
    => Uri.https('play.google.com', 'store/apps/details', { 'id': {info.id} });
}