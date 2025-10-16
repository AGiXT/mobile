/// Imports
/// ------------------------------------------------------------------------------------------------

import 'app_info.dart';
import 'store_info.dart';


/// App Store
/// ------------------------------------------------------------------------------------------------

/// Apple App Store helper methods.
class AppStore extends StoreInfo {
  
  /// Creates an instance of [AppStore].
  const AppStore._(): super('ios');

  /// An instance of [AppStore].
  static AppStore get instance => const AppStore._();

  @override
  List<AppInfo> get apps => [ // Apple App Store ids.
    PhantomAppInfo(
      id: '1598432977', 
    ),
    SolflareAppInfo(
      id: '1580902717', 
    ),
  ];
  
  @override
  Uri uri(final AppInfo info) 
    => Uri(scheme: 'itms-apps', host: 'itunes.apple.com', path: 'app/id${info.id}');
}